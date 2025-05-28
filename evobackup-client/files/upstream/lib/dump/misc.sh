#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Dump LDAP files (config, data, all)
#
# Arguments: <none>
#######################################################################
dump_ldap() {
    ## OpenLDAP : example with slapcat
    local dump_dir="${LOCAL_BACKUP_DIR}/ldap"
    rm -rf "${dump_dir}"
    mkdir -p "${dump_dir}"
    chmod 700 "${dump_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${FUNCNAME[0]} to ${dump_dir}"

    dump_cmd="slapcat -n 0 -l ${dump_dir}/ldap-config.bak"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    dump_cmd="slapcat -n 1 -l ${dump_dir}/ldap-data.bak"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${FUNCNAME[0]}"
}

#######################################################################
# Copy dump file of Redis instances
#
# Arguments:
# --instances=[String,String] (default: all)
#######################################################################
dump_redis() {
    all_instances=$( find /etc/redis*/redis.conf -print0 | xargs -0 -n 1 dirname  | xargs -n 1 basename | sort -h | xargs )

    declare -a option_instances

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --instances)
                # instances options, with key and value separated by space
                if [ -n "$2" ]; then
                    if [ "${2}" == "all" ]; then
                        read -a option_instances <<< "${all_instances}"
                    else
                        IFS="," read -a option_instances <<< "${2}"
                    fi
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--instances' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --instances=?*)
                # instances options, with key and value separated by =
                if [ "${1#*=}" == "all" ]; then
                    read -a option_instances <<< "${all_instances}"
                else
                    IFS="," read -a option_instances <<< "${1#*=}"
                fi
                ;;
            --instances=)
                # instances options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--instances' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    # If no instance has been give, use every instance found
    if [ -z "${option_instances[*]}" ]; then
        read -a option_instances <<< "${all_instances}"
    fi

    for instance in "${option_instances[@]}"; do
        # Look for the config file for this instance
        config_file="/etc/${instance}/redis.conf"
        if [ -n "${instance}" ] && [ -f "${config_file}" ]; then
            # Parse the config for he data dir and dump file
            local instance_data_dir
            local instance_data_file
            local instance_dump_path

            instance_data_dir=$( grep --extended-regexp "^\s*dir " "${config_file}" | cut -d ' ' -f 2 | tr -d "'" | tr -d '"' )
            instance_data_file=$( grep --extended-regexp "^\s*dbfilename " "${config_file}" | cut -d ' ' -f 2 | tr -d "'" | tr -d '"' )
            instance_dump_path="${instance_data_dir}/${instance_data_file}"

            if [ -n "${instance_dump_path}" ]; then
                local dump_dir="${LOCAL_BACKUP_DIR}/${instance}"
                local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
                rm -rf "${dump_dir}" "${errors_dir}"
                mkdir -p "${dump_dir}" "${errors_dir}"
                # No need to change recursively, the top directory is enough
                chmod 700 "${dump_dir}" "${errors_dir}"

                local error_file="${errors_dir}/${instance}.err"
                log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

                # Copy the Redis database
                dump_cmd="cp -a ${instance_dump_path} ${dump_dir}/${instance_data_file}"
                log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
                ${dump_cmd} 2> "${error_file}"

                local last_rc=$?
                # shellcheck disable=SC2086
                if [ ${last_rc} -ne 0 ]; then
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: cp ${instance_dump_path} to ${dump_dir} returned an error ${last_rc}" "${error_file}"
                    GLOBAL_RC=${E_DUMPFAILED}
                else
                    rm -f "${error_file}"
                fi

                # Compress the Redis database
                dump_cmd="gzip ${dump_dir}/${instance_data_file}"
                log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
                ${dump_cmd}

                local last_rc=$?
                # shellcheck disable=SC2086
                if [ ${last_rc} -ne 0 ]; then
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: gzip ${dump_dir}/${instance_data_file} returned an error ${last_rc}" "${error_file}"
                    GLOBAL_RC=${E_DUMPFAILED}
                else
                    rm -f "${error_file}"
                fi

                log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
            else
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '${dump_file}' not found."
            fi
        else
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '${config_file}' not found."
        fi
    done
}

#######################################################################
# Dump all collections of a MongoDB database
# using a custom authentication, instead of /etc/mysql/debian.cnf
#
# Arguments:
# --port=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
# Other options after -- are passed as-is to mongodump
#
# don't forget to create use with read-only access
# > use admin
# > db.createUser( { user: "mongobackup", pwd: "PASS", roles: [ "backup", ] } )
#######################################################################
dump_mongodb() {
    local option_port=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                exit 1
                ;;
            --dump-label)
                # dump-label options, with value separated by space
                if [ -n "$2" ]; then
                    option_dump_label="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --dump-label=?*)
                # dump-label options, with value separated by =
                option_dump_label="${1#*=}"
                ;;
            --dump-label=)
                # dump-label options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                option_others=${*}
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mongodb-${option_dump_label}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

    declare -a dump_options
    dump_options=()
    if [ -n "${option_port}" ]; then
        dump_options+=(--port="${option_port}")
    fi
    if [ -n "${option_user}" ]; then
        dump_options+=(--username="${option_user}")
    fi
    if [ -n "${option_password}" ]; then
        dump_options+=(--password="${option_password}")
    fi
    dump_options+=(--out="${dump_dir}/")
    if [ -n "${option_others}" ]; then
        # word splitting is deliberate here
        # shellcheck disable=SC2206
        dump_options+=(${option_others})
    fi

    dump_cmd="mongodump ${dump_options[*]}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd} > /dev/null"
    ${dump_cmd} 2> "${error_file}" > /dev/null

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mongodump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${FUNCNAME[0]}: ${dump_dir}"
}

#######################################################################
# Dump RAID configuration
#
# Arguments: <none>
#######################################################################
dump_raid_config() {
    local dump_dir="${LOCAL_BACKUP_DIR}/raid"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    if command -v megacli > /dev/null; then
        local error_file="${errors_dir}/megacli.cfg"
        local dump_file="${dump_dir}/megacli.err"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        dump_cmd="megacli -CfgSave -f ${dump_file} -a0"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} 2> "${error_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: megacli to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    elif command -v perccli > /dev/null; then
        local error_file="${errors_dir}/perccli.cfg"
        local dump_file="${dump_dir}/perccli.err"
        # log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        # TODO: find out what the correct command is

        # dump_cmd="perccli XXXX"
        # log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        # ${dump_cmd} 2> ${error_file}

        # local last_rc=$?
        # # shellcheck disable=SC2086
        # if [ ${last_rc} -ne 0 ]; then
        #     log_error "LOCAL_TASKS - ${FUNCNAME[0]}: perccli to ${dump_file} returned an error ${last_rc}" "${error_file}"
        #     GLOBAL_RC=${E_DUMPFAILED}
        # else
        #     rm -f "${error_file}"
        # fi
        # log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'megacli' and 'perccli' not found, unable to dump RAID configuration"
    fi
}

#######################################################################
# Save some traceroute/mtr results
#
# Arguments:
# --targets=[IP,HOST] (default: <none>)
#######################################################################
dump_traceroute() {
    declare -a option_targets

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --targets)
                # targets options, with key and value separated by space
                if [ -n "$2" ]; then
                    IFS="," read -a option_targets <<< "${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--targets' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --targets=?*)
                # targets options, with key and value separated by =
                IFS="," read -a option_targets <<< "${1#*=}"
                ;;
            --targets=)
                # targets options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--targets' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    local dump_dir="${LOCAL_BACKUP_DIR}/traceroute"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"


    mtr_bin=$(command -v mtr)
    if [ -n "${mtr_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/mtr-${target}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            ${mtr_bin} -r "${target}" > "${dump_file}"

            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
        done
    fi

    traceroute_bin=$(command -v traceroute)
    if [ -n "${traceroute_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/traceroute-${target}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            ${traceroute_bin} -n "${target}" > "${dump_file}" 2>&1

            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
        done
    fi
}

#######################################################################
# Save many system information, using dump_server_state
#
# Arguments:
# any option for dump-server-state (except --dump-dir) is usable
# (default: --all)
#######################################################################
dump_server_state() {
    local dump_dir="${LOCAL_BACKUP_DIR}/server-state"
    rm -rf "${dump_dir}"
    # Do not create the directory
    # mkdir -p -m 700 "${dump_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

    # pass all options
    read -a options <<< "${@}"
    # if no option is given, use "--all" as fallback
    if [ ${#options[@]} -le 0 ]; then
        options=(--all)
    fi
    # add "--dump-dir" in case it is missing (as it should)
    options+=(--dump-dir "${dump_dir}")

    dump_server_state_bin=$(command -v dump-server-state)
    if [ -z "${dump_server_state_bin}" ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: dump-server-state is missing"
        rc=1
    else
        dump_cmd="${dump_server_state_bin} ${options[*]}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd}

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: dump-server-state returned an error ${last_rc}, check ${dump_dir}"
            GLOBAL_RC=${E_DUMPFAILED}
        fi
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
}

#######################################################################
# Save RabbitMQ data
# 
# Arguments: <none>
# 
# Warning: This has been poorly tested
#######################################################################
dump_rabbitmq() {
    local dump_dir="${LOCAL_BACKUP_DIR}/rabbitmq"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    local dump_file="${dump_dir}/config"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    dump_cmd="rabbitmqadmin export ${dump_file}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd} 2> "${error_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}

#######################################################################
# Save Files ACL on various partitions.
# 
# Arguments: <none>
#######################################################################
dump_facl() {
    local dump_dir="${LOCAL_BACKUP_DIR}/facl"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

    dump_cmd="getfacl -R /etc  > ${dump_dir}/etc.txt"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    dump_cmd="getfacl -R /home  > ${dump_dir}/home.txt"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    dump_cmd="getfacl -R /usr  > ${dump_dir}/usr.txt"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    dump_cmd="getfacl -R /var  > ${dump_dir}/var.txt"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd}

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
}
#######################################################################
# Dump Linstor Database
# 
# Arguments: <none>
#######################################################################
dump_linstordb() {
    # Set dump and errors directories and files
    local dump_dir="${LOCAL_BACKUP_DIR}/linstor"
    local dump_file="${dump_dir}/dump_linstor_db"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    local error_file="${errors_dir}/dump.err"

    # Reset dump and errors directories
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    # Log the start of the function
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"
        
    # Stop linstor-controller process before backup
    linstorctrl_stop="/usr/bin/systemctl stop linstor-controller.service"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${linstorctrl_stop}"
        
    # Execute stop linstor-controller
    ${linstorctrl_stop}
    local last_rc=$?
    if [ "${last_rc}" -ne "0" ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: linstor stopping service failed"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        # Prepare the dump command (errors go to the error file and the data to the dump file)
        dump_cmd="/usr/share/linstor-server/bin/linstor-database export-db ${dump_file}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"

        # Execute the dump command
        ${dump_cmd} 2> ${error_file}

        # Check result and deal with potential errors
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: linstor database export to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi

        # Start linstor-controller process after backup
        linstorctrl_start="/usr/bin/systemctl start linstor-controller.service"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${linstorctrl_start}"

        # Execute start linstor-controller
        ${linstorctrl_start}

        # Check result and deal with potential errors
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: linstor starting service failed"
            GLOBAL_RC=${E_DUMPFAILED}
        fi
    fi

    # Log the end of the function
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop ${dump_file}"
}
