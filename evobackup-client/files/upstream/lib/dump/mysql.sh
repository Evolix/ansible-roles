#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Dump complete summary of an instance (using pt-mysql-summary)
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_summary() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
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
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
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
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        elif [ -n "${option_socket}" ]; then
            option_dump_label=$(path_to_str "${option_socket}")
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}-summary"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## Dump all grants (requires 'percona-toolkit' package)
    if command -v pt-mysql-summary > /dev/null; then
        local error_file="${errors_dir}/mysql-summary.err"
        local dump_file="${dump_dir}/mysql-summary.out"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        ## Connection options
        declare -a connect_options
        connect_options=()
        if [ -n "${option_defaults_file}" ]; then
            connect_options+=(--defaults-file="${option_defaults_file}")
        fi
        if [ -n "${option_defaults_extra_file}" ]; then
            connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
        fi
        if [ -n "${option_defaults_group_suffix}" ]; then
            connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
        fi
        if [ -n "${option_port}" ]; then
            connect_options+=(--protocol=tcp)
            connect_options+=(--port="${option_port}")
        fi
        if [ -n "${option_socket}" ]; then
            connect_options+=(--protocol=socket)
            connect_options+=(--socket="${option_socket}")
        fi
        if [ -n "${option_user}" ]; then
            connect_options+=(--user="${option_user}")
        fi
        if [ -n "${option_password}" ]; then
            connect_options+=(--password="${option_password}")
        fi

        declare -a options
        options=()
        options+=(--sleep=0)

        dump_cmd="pt-mysql-summary ${options[*]} -- ${connect_options[*]}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pt-mysql-summary to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'pt-mysql-summary' not found, unable to dump summary"
    fi
}

#######################################################################
# Dump grants of an instance
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_grants() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_user=""
    local option_password=""
    local option_dump_label=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
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
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
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
        elif [ -n "${option_socket}" ]; then
            option_dump_label=$(path_to_str "${option_socket}")
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}-grants"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## Dump all grants (requires 'percona-toolkit' package)
    if command -v pt-show-grants > /dev/null; then
        local error_file="${errors_dir}/all_grants.err"
        local dump_file="${dump_dir}/all_grants.sql"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        declare -a options
        options=()
        if [ -n "${option_defaults_file}" ]; then
            options+=(--defaults-file="${option_defaults_file}")
        fi
        if [ -n "${option_port}" ]; then
            options+=(--port="${option_port}")
        fi
        if [ -n "${option_socket}" ]; then
            options+=(--socket="${option_socket}")
        fi
        if [ -n "${option_user}" ]; then
            options+=(--user="${option_user}")
        fi
        if [ -n "${option_password}" ]; then
            options+=(--password="${option_password}")
        fi
        options+=(--flush)
        options+=(--no-header)

        dump_cmd="pt-show-grants ${options[*]}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pt-show-grants to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'pt-show-grants' not found, unable to dump grants"
    fi
}

#######################################################################
# Dump a single compressed file of all databases of an instance
# and a file containing only the schema.
#
# Arguments:
# --master-data (default: <absent>)
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
# --compress=<gzip|pigz|bzip2|xz|none> (default: "gzip")
# --dump-slave=[1|2]
# Other options after -- are passed as-is to mysqldump
#######################################################################
dump_mysql_global() {
    local option_masterdata=""
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    local option_compress=""
    local option_others=""
    local option_dump_slave=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --master-data|--masterdata)
                option_masterdata="--master-data"
                ;;
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
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
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
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
            --compress)
                # compress options, with value separated by space
                if [ -n "$2" ]; then
                    option_compress="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --compress=?*)
                # compress options, with value separated by =
                option_compress="${1#*=}"
                ;;
            --compress=)
                # compress options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
                exit 1
                ;;
            --dump-slave)
                # dump-slave options, require value "1" or "2"
                if [ "$2" = "1" ]; then
                    option_dump_slave="--dump-slave=${2}"
                    shift
                elif [ "$2" = "2" ]; then
                    option_dump_slave="--dump-slave=${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-slave' requires a non-empty option argument is \"1\" or \"2\"."
                    exit 1
                fi
                ;;
            --dump-slave=?*)
                value="${1#*=}"
                if [ ${value} = "1" ]; then
                    option_dump_slave="${1}"
                    shift
                elif [ ${value} = "2" ]; then
                    option_dump_slave="${1}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-slave' require value \"1\" or \"2\"."
                    exit 1
                fi
                ;;
            --dump-slave=)
                # dump-slave options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-slave' requires a non-empty option argument, value is \"1\" or \"2\"."
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

    case "${option_compress}" in
        none)
            compress_cmd="cat"
            dump_ext=""
            ;;
        bzip2|bz|bz2)
            compress_cmd="bzip2 --best"
            dump_ext=".bz"
            ;;
        xz)
            compress_cmd="xz --best"
            dump_ext=".xz"
            ;;
        pigz)
            compress_cmd="pigz --best"
            dump_ext=".gz"
            ;;
        gz|gzip|*)
            compress_cmd="gzip --best"
            dump_ext=".gz"
            ;;
    esac

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        elif [ -n "${option_socket}" ]; then
            option_dump_label=$(path_to_str "${option_socket}")
        else
            option_dump_label="default"
        fi
    fi

    ## Connection options
    declare -a connect_options
    connect_options=()
    if [ -n "${option_defaults_file}" ]; then
        connect_options+=(--defaults-file="${option_defaults_file}")
    fi
    if [ -n "${option_defaults_extra_file}" ]; then
        connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
    fi
    if [ -n "${option_defaults_group_suffix}" ]; then
        connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
    fi
    if [ -n "${option_port}" ]; then
        connect_options+=(--protocol=tcp)
        connect_options+=(--port="${option_port}")
    fi
    if [ -n "${option_socket}" ]; then
        connect_options+=(--protocol=socket)
        connect_options+=(--socket="${option_socket}")
    fi
    if [ -n "${option_user}" ]; then
        connect_options+=(--user="${option_user}")
    fi
    if [ -n "${option_password}" ]; then
        connect_options+=(--password="${option_password}")
    fi

    ## Global all databases in one file

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/mysqldump.err"
    local dump_file="${dump_dir}/mysqldump.sql${dump_ext}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    declare -a dump_options
    dump_options=()
    dump_options+=(--opt)
    dump_options+=(--force)
    dump_options+=(--events)
    dump_options+=(--hex-blob)
    dump_options+=(--all-databases)
    if [ -n "${option_masterdata}" ]; then
        dump_options+=("${option_masterdata}")
    fi
    if [ -n "${option_dump_slave}" ]; then
        dump_options+=("${option_dump_slave}")
    fi
    if [ -n "${option_others}" ]; then
        # word splitting is deliberate here
        # shellcheck disable=SC2206
        dump_options+=(${option_others})
    fi

    ## WARNING : logging and executing the command must be separate
    ## because otherwise Bash would interpret | and > as strings and not syntax.

    dump_cmd="mysqldump ${connect_options[*]} ${dump_options[*]} 2> ${error_file} | ${compress_cmd} > ${dump_file}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    mysqldump "${connect_options[@]}" "${dump_options[@]}" 2> "${error_file}" | ${compress_cmd} > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"


    ## Schema only (no data) for each databases

    local error_file="${errors_dir}/mysqldump.schema.err"
    local dump_file="${dump_dir}/mysqldump.schema.sql"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    declare -a dump_options
    dump_options=()
    dump_options+=(--force)
    dump_options+=(--no-data)
    dump_options+=(--all-databases)
    if [ -n "${option_others}" ]; then
        # word splitting is deliberate here
        # shellcheck disable=SC2206
        dump_options+=(${option_others})
    fi

    dump_cmd="mysqldump ${connect_options[*]} ${dump_options[*]}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd} 2> "${error_file}" > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}

#######################################################################
# Dump a file of each databases of an instance
# and a file containing only the schema.
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
# --compress=<gzip|pigz|bzip2|xz|none> (default: "gzip")
# Other options after -- are passed as-is to mysqldump
#######################################################################
dump_mysql_per_base() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    local option_compress=""
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
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
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
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
            --compress)
                # compress options, with value separated by space
                if [ -n "$2" ]; then
                    option_compress="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --compress=?*)
                # compress options, with value separated by =
                option_compress="${1#*=}"
                ;;
            --compress=)
                # compress options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
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

    case "${option_compress}" in
        none)
            compress_cmd="cat"
            dump_ext=""
            ;;
        bzip2|bz|bz2)
            compress_cmd="bzip2 --best"
            dump_ext=".bz"
            ;;
        xz)
            compress_cmd="xz --best"
            dump_ext=".xz"
            ;;
        pigz)
            compress_cmd="pigz --best"
            dump_ext=".gz"
            ;;
        gz|gzip|*)
            compress_cmd="gzip --best"
            dump_ext=".gz"
            ;;
    esac

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        elif [ -n "${option_socket}" ]; then
            option_dump_label=$(path_to_str "${option_socket}")
        else
            option_dump_label="default"
        fi
    fi

    ## Connection options
    declare -a connect_options
    connect_options=()
    if [ -n "${option_defaults_file}" ]; then
        connect_options+=(--defaults-file="${option_defaults_file}")
    fi
    if [ -n "${option_defaults_extra_file}" ]; then
        connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
    fi
    if [ -n "${option_defaults_group_suffix}" ]; then
        connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
    fi
    if [ -n "${option_port}" ]; then
        connect_options+=(--protocol=tcp)
        connect_options+=(--port="${option_port}")
    fi
    if [ -n "${option_socket}" ]; then
        connect_options+=(--protocol=socket)
        connect_options+=(--socket="${option_socket}")
    fi
    if [ -n "${option_user}" ]; then
        connect_options+=(--user="${option_user}")
    fi
    if [ -n "${option_password}" ]; then
        connect_options+=(--password="${option_password}")
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}-per-base"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    databases=$(mysql "${connect_options[@]}" --execute="show databases" --silent --skip-column-names \
        | grep --extended-regexp --invert-match "^(Database|information_schema|performance_schema|sys)")

    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.err"
        local dump_file="${dump_dir}/${database}.sql${dump_ext}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        declare -a dump_options
        dump_options=()
        dump_options+=(--opt)
        dump_options+=(--force)
        dump_options+=(--events)
        dump_options+=(--hex-blob)
        dump_options+=(--databases "${database}")
        if [ -n "${option_others}" ]; then
            # word splitting is deliberate here
            # shellcheck disable=SC2206
            dump_options+=(${option_others})
        fi

        ## WARNING : logging and executing the command must be separate
        ## because otherwise Bash would interpret | and > as strings and not syntax.

        log "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump ${connect_options[*]} ${dump_options[*]} | ${compress_cmd} > ${dump_file}"
        mysqldump "${connect_options[@]}" "${dump_options[@]}" 2> "${error_file}" | ${compress_cmd} > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"


        ## Schema only (no data) for each databases

        local error_file="${errors_dir}/${database}.schema.err"
        local dump_file="${dump_dir}/${database}.schema.sql"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        declare -a dump_options
        dump_options=()
        dump_options+=(--force)
        dump_options+=(--no-data)
        dump_options+=(--databases "${database}")
        if [ -n "${option_others}" ]; then
            # word splitting is deliberate here
            # shellcheck disable=SC2206
            dump_options+=(${option_others})
        fi

        dump_cmd="mysqldump ${connect_options[*]} ${dump_options[*]}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    done
}

#######################################################################
# Dump "tabs style" separate schema/data for each database of an instance
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
# --compress=<gzip|pigz|bzip2|xz|none> (default: "gzip")
# Other options after -- are passed as-is to mysqldump
#######################################################################
dump_mysql_tabs() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    local option_compress=""
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
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
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
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
            --compress)
                # compress options, with value separated by space
                if [ -n "$2" ]; then
                    option_compress="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --compress=?*)
                # compress options, with value separated by =
                option_compress="${1#*=}"
                ;;
            --compress=)
                # compress options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--compress' requires a non-empty option argument."
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

    case "${option_compress}" in
        none)
            compress_cmd="cat"
            dump_ext=""
            ;;
        bzip2|bz|bz2)
            compress_cmd="bzip2 --best"
            dump_ext=".bz"
            ;;
        xz)
            compress_cmd="xz --best"
            dump_ext=".xz"
            ;;
        pigz)
            compress_cmd="pigz --best"
            dump_ext=".gz"
            ;;
        gz|gzip|*)
            compress_cmd="gzip --best"
            dump_ext=".gz"
            ;;
    esac

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        elif [ -n "${option_socket}" ]; then
            option_dump_label=$(path_to_str "${option_socket}")
        else
            option_dump_label="default"
        fi
    fi

    ## Connection options
    declare -a connect_options
    connect_options=()
    if [ -n "${option_defaults_file}" ]; then
        connect_options+=(--defaults-file="${option_defaults_file}")
    fi
    if [ -n "${option_defaults_extra_file}" ]; then
        connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
    fi
    if [ -n "${option_defaults_group_suffix}" ]; then
        connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
    fi
    if [ -n "${option_port}" ]; then
        connect_options+=(--protocol=tcp)
        connect_options+=(--port="${option_port}")
    fi
    if [ -n "${option_socket}" ]; then
        connect_options+=(--protocol=socket)
        connect_options+=(--socket="${option_socket}")
    fi
    if [ -n "${option_user}" ]; then
        connect_options+=(--user="${option_user}")
    fi
    if [ -n "${option_password}" ]; then
        connect_options+=(--password="${option_password}")
    fi

    databases=$(mysql "${connect_options[@]}" --execute="show databases" --silent --skip-column-names \
        | grep --extended-regexp --invert-match "^(Database|information_schema|performance_schema|sys)")

    for database in ${databases}; do
        local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}-tabs/${database}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        mkdir -p "${dump_dir}" "${errors_dir}"
        # No need to change recursively, the top directory is enough
        chmod 750 "$(dirname "${dump_dir}")" "${errors_dir}"
        chown -RL mysql:mysql "$(dirname "${dump_dir}")"

        local error_file="${errors_dir}.err"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

        declare -a dump_options
        dump_options=()
        dump_options+=(--force)
        dump_options+=(--quote-names)
        dump_options+=(--opt)
        dump_options+=(--events)
        dump_options+=(--hex-blob)
        dump_options+=(--skip-comments)
        dump_options+=(--fields-enclosed-by='\"')
        dump_options+=(--fields-terminated-by=',')
        dump_options+=(--tab="${dump_dir}")
        if [ -n "${option_others}" ]; then
            # word splitting is deliberate here
            # shellcheck disable=SC2206
            dump_options+=(${option_others})
        fi
        dump_options+=("${database}")

        dump_cmd="mysqldump ${connect_options[*]} ${dump_options[*]}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} 2> "${error_file}"
 
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
    done
}
