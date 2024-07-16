#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Dump a single file of all PostgreSQL databases
#
# Arguments:
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
# --compress=<gzip|pigz|bzip2|xz|none> (default: "gzip")
# Other options after -- are passed as-is to pg_dump
#######################################################################
dump_postgresql_global() {
    local option_dump_label=""
    local option_compress=""
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
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
        option_dump_label="default"
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-${option_dump_label}-global"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## example with pg_dumpall and with compression
    local error_file="${errors_dir}/pg_dumpall.err"
    local dump_file="${dump_dir}/pg_dumpall.sql${dump_ext}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    declare -a dump_options
    dump_options=()
    if [ -n "${option_others}" ]; then
        # word splitting is deliberate here
        # shellcheck disable=SC2206
        dump_options+=(${option_others})
    fi
    
    dump_cmd="(sudo -u postgres pg_dumpall ${dump_options[*]}) 2> ${error_file} | ${compress_cmd} > ${dump_file}"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
    eval "${dump_cmd}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dumpall to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"

    ## example with pg_dumpall and without compression
    ## WARNING: you need space in ~postgres
    # local error_file="${errors_dir}/pg_dumpall.err"
    # local dump_file="${dump_dir}/pg_dumpall.sql"
    # log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"
    # 
    # (su - postgres -c "pg_dumpall > ~/pg.dump.bak") 2> "${error_file}"
    # mv ~postgres/pg.dump.bak "${dump_file}"
    # 
    # log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}

#######################################################################
# Dump a compressed file per database
#
# Arguments: <none>
#######################################################################
dump_postgresql_per_base() {
    local option_dump_label=""
    local option_compress=""
    local option_others=""

    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
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
        option_dump_label="default"
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-${option_dump_label}-per-base"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    (
        # shellcheck disable=SC2164
        cd /var/lib/postgresql
        databases=$(sudo -u postgres psql -U postgres -lt | awk -F \| '{print $1}' | grep -v "template.*")
        for database in ${databases} ; do
            local error_file="${errors_dir}/${database}.err"
            local dump_file="${dump_dir}/${database}.sql${dump_ext}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            declare -a dump_options
            dump_options=()
            dump_options+=(--create)
            dump_options+=(-U postgres)
            dump_options+=(-d "${database}")
            if [ -n "${option_others}" ]; then
                # word splitting is deliberate here
                # shellcheck disable=SC2206
                dump_options+=(${option_others})
            fi

            dump_cmd="(sudo -u postgres /usr/bin/pg_dump ${dump_options[*]}) 2> ${error_file} | ${compress_cmd} > ${dump_file}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
            eval "${dump_cmd}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi
            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
        done
    )
}

#######################################################################
# Dump a compressed file per database
#
# Arguments: <none>
#
# TODO: add arguments to include/exclude tables
#######################################################################
dump_postgresql_filtered() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-filtered"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/pg-backup.err"
    local dump_file="${dump_dir}/pg-backup.tar"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    ## example with all tables from MYBASE excepts TABLE1 and TABLE2
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -t 'TABLE1' -t 'TABLE2' MYBASE 2> "${error_file}"

    ## example with only TABLE1 and TABLE2 from MYBASE
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -T 'TABLE1' -T 'TABLE2' MYBASE 2> "${error_file}"

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
