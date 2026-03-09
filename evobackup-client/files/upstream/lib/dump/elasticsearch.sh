#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Snapshot Elasticsearch data
# 
# Arguments:
# --protocol=<http|https> (default: http)
# --cacert=[String] (default: <none>)
#   path to the CA certificate to use when using https
# --host=[String] (default: localhost)
# --port=[Integer] (default: 9200)
# --user=[String] (default: <none>)
# --password=[String] (default: <none>)
# --repository=[String] (default: snaprepo)
# --snapshot=[String] (default: snapshot.daily)
#######################################################################
dump_elasticsearch() {
    local option_protocol="http"
    local option_cacert=""
    local option_host="localhost"
    local option_port="9200"
    local option_user=""
    local option_password=""
    local option_repository="snaprepo"
    local option_snapshot="snapshot.daily"
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --protocol)
                # protocol options, with value separated by space
                if [ -n "$2" ]; then
                    option_protocol="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --protocol=?*)
                # protocol options, with value separated by =
                option_protocol="${1#*=}"
                ;;
            --protocol=)
                # protocol options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                exit 1
                ;;
            --cacert)
                # cacert options, with value separated by space
                if [ -n "$2" ]; then
                    option_cacert="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--cacert' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --cacert=?*)
                # cacert options, with value separated by =
                option_cacert="${1#*=}"
                ;;
            --cacert=)
                # cacert options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--cacert' requires a non-empty option argument."
                exit 1
                ;;
            --host)
                # host options, with value separated by space
                if [ -n "$2" ]; then
                    option_host="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --host=?*)
                # host options, with value separated by =
                option_host="${1#*=}"
                ;;
            --host=)
                # host options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
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
            --repository)
                # repository options, with value separated by space
                if [ -n "$2" ]; then
                    option_repository="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --repository=?*)
                # repository options, with value separated by =
                option_repository="${1#*=}"
                ;;
            --repository=)
                # repository options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                exit 1
                ;;
            --snapshot)
                # snapshot options, with value separated by space
                if [ -n "$2" ]; then
                    option_snapshot="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --snapshot=?*)
                # snapshot options, with value separated by =
                option_snapshot="${1#*=}"
                ;;
            --snapshot=)
                # snapshot options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
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

    #  Use the default Elasticsearch CA certificate when using HTTPS, if not specified directly 
    local default_cacert="/etc/elasticsearch/certs/http_ca.crt"
    if [ "${option_protocol}" = "https" ] && [ -z "${option_cacert}" ] && [ -f "${default_cacert}" ]; then
        option_cacert="${default_cacert}"
    fi

    local errors_dir=$(errors_dir_from_dump_dir "${LOCAL_BACKUP_DIR}/elasticsearch-${option_repository}-${option_snapshot}") 
    rm -rf "${errors_dir}"
    mkdir -p "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${errors_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${option_snapshot}"

    ## Take a snapshot as a backup.
    ## Warning: You need to have a path.repo configured.
    ## See: https://wiki.evolix.org/HowtoElasticsearch#snapshots-et-sauvegardes

    local base_url="${option_protocol}://${option_host}:${option_port}"
    local repository_url="${base_url}/_snapshot/${option_repository}"
    local snapshot_url="${repository_url}/${option_snapshot}"

    # Verify snapshot repository

    local error_file="${errors_dir}/verify.err"

    declare -a connect_options
    connect_options=()
    if [ -n "${option_cacert}" ]; then
        connect_options+=(--cacert "${option_cacert}")
    fi
    if [ -n "${option_user}" ] || [ -n "${option_password}" ]; then
        local connect_options+=("--user ${option_user}:${option_password}")
    fi
    if [ -n "${option_others}" ]; then
        # word splitting is deliberate here
        # shellcheck disable=SC2206
        connect_options+=(${option_others})
    fi
    # Add the http return code at the end of the output
    connect_options+=(--write-out '\n%{http_code}\n')
    connect_options+=(--silent)

    declare -a dump_options
    dump_options=()
    dump_options+=(--request POST)

    dump_cmd="curl ${connect_options[*]} ${dump_options[*]} ${repository_url}/_verify?pretty"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    ${dump_cmd} > "${error_file}"

    # test if the last line of the log file is "200"
    tail -n 1 "${error_file}" | grep "^200$" >/dev/null 2>&1

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: repository verification returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"

        # Delete snapshot
        
        declare -a dump_options
        dump_options=()
        dump_options+=(--request DELETE)

        dump_cmd="curl ${connect_options[*]} ${dump_options[*]} ${snapshot_url}"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} > /dev/null

        # Create snapshot

        local error_file="${errors_dir}/create.err"
        
        declare -a dump_options
        dump_options=()
        dump_options+=(--request PUT)

        dump_cmd="curl ${connect_options[*]} ${dump_options[*]} ${snapshot_url}?wait_for_completion=true"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
        ${dump_cmd} > "${error_file}"

        # test if the last line of the log file is "200"
        tail -n 1 "${error_file}" | grep "^200$" >/dev/null 2>&1

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: curl returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
    fi

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${option_snapshot}"
}
