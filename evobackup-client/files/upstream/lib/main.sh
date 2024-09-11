#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317

readonly VERSION="24.07"

# set all programs to C language (english)
export LC_ALL=C

# If expansion is attempted on an unset variable or parameter, the shell prints an
# error message, and, if not interactive, exits with a non-zero status.
set -o nounset
# The pipeline's return status is the value of the last (rightmost) command
# to exit with a non-zero status, or zero if all commands exit successfully.
set -o pipefail
# Enable trace mode if called with environment variable TRACE=1
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

source "${LIBDIR}/utilities.sh"
source "${LIBDIR}/dump/elasticsearch.sh"
source "${LIBDIR}/dump/mysql.sh"
source "${LIBDIR}/dump/postgresql.sh"
source "${LIBDIR}/dump/misc.sh"

# Called from main, it is wrapping the local_tasks function defined in the real script
local_tasks_wrapper() {
    log "START LOCAL_TASKS"

    # Remove old log directories (recursively)
    find "${LOCAL_BACKUP_DIR}/" -type d -name "${PROGNAME}.errors-*" -ctime +30 -exec rm -rf \;

    local_tasks_type="$(type -t local_tasks)"
    if [ "${local_tasks_type}" = "function" ]; then
        local_tasks
    else
        log_error "There is no 'local_tasks' function to execute"
    fi

    # TODO: check if this is still needed
    # print_error_files_content

    log "STOP LOCAL_TASKS"
}

# Called from main, it is wrapping the sync_tasks function defined in the real script
sync_tasks_wrapper() {
    declare -a SERVERS        # Indexed array for server/port values
    declare -a RSYNC_INCLUDES # Indexed array for includes
    declare -a RSYNC_EXCLUDES # Indexed array for excludes

    case "${SYSTEM}" in
        linux)
            # NOTE: remember to single-quote paths if they contain globs (*)
            #       and you want to defer expansion
            declare -a rsync_default_includes=(
                /bin
                /boot
                /lib
                /opt
                /sbin
                /usr
            )
            ;;
        *bsd)
            # NOTE: remember to single-quote paths if they contain globs (*)
            #       and you want to defer expansion
            declare -a rsync_default_includes=(
                /bin
                /bsd
                /sbin
                /usr
            )
            ;;
        *)
            echo "Unknown system '${SYSTEM}'" >&2
            exit 1
            ;;
    esac
    if [ -f "${CANARY_FILE}" ]; then
        rsync_default_includes+=("${CANARY_FILE}")
    fi
    readonly rsync_default_includes

    # NOTE: remember to single-quote paths if they contain globs (*)
    #       and you want to defer expansion
    declare -a rsync_default_excludes=(
        /dev
        /proc
        /run
        /sys
        /tmp
        /usr/doc
        /usr/obj
        /usr/share/doc
        /usr/src
        /var/apt
        /var/cache
        '/var/db/munin/*.tmp'
        /var/lib/amavis/amavisd.sock
        /var/lib/amavis/tmp
        /var/lib/amavis/virusmails
        '/var/lib/clamav/*.tmp'
        /var/lib/elasticsearch
        /var/lib/metche
        /var/lib/mongodb
        '/var/lib/munin/*tmp*'
        /var/lib/mysql
        /var/lib/php/sessions
        /var/lib/php5
        /var/lib/postgres
        /var/lib/postgresql
        /var/lib/sympa
        /var/lock
        /var/run
        /var/spool/postfix
        /var/spool/smtpd
        /var/spool/squid
        /var/state
        /var/tmp
        lost+found
        '.nfs.*'
        'lxc/*/rootfs/tmp'
        'lxc/*/rootfs/usr/doc'
        'lxc/*/rootfs/usr/obj'
        'lxc/*/rootfs/usr/share/doc'
        'lxc/*/rootfs/usr/src'
        'lxc/*/rootfs/var/apt'
        'lxc/*/rootfs/var/cache'
        'lxc/*/rootfs/var/lib/php5'
        'lxc/*/rootfs/var/lib/php/sessions'
        'lxc/*/rootfs/var/lock'
        'lxc/*/rootfs/var/run'
        'lxc/*/rootfs/var/state'
        'lxc/*/rootfs/var/tmp'
        /home/mysqltmp
    )
    readonly rsync_default_excludes

    sync_tasks_type="$(type -t sync_tasks)"
    if [ "${sync_tasks_type}" = "function" ]; then
        sync_tasks
    else
        log_error "There is no 'sync_tasks' function to execute"
    fi
}

sync() {
    local sync_name=${1}
    local -a rsync_servers=("${!2}")
    local -a rsync_includes=("${!3}")
    local -a rsync_excludes=("${!4}")

    ## Initialize variable to store SSH connection errors
    declare -a SSH_ERRORS=()

    log "START SYNC_TASKS - sync=${sync_name}"

    # echo "### sync ###"

    # for server in "${rsync_servers[@]}"; do
    #     echo "server: ${server}"
    # done

    # for include in "${rsync_includes[@]}"; do
    #     echo "include: ${include}"
    # done

    # for exclude in "${rsync_excludes[@]}"; do
    #     echo "exclude: ${exclude}"
    # done

    local -i n=0
    local server=""
    if [ "${SERVERS_FALLBACK}" = "1" ]; then
        # We try to find a suitable server
        while :; do
            server=$(pick_server ${n} "${sync_name}")
            rc=$?
            if [ ${rc} != 0 ]; then
                GLOBAL_RC=${E_NOSRVAVAIL}
            log "STOP  SYNC_TASKS - sync=${sync_name}'"
                return
            fi

            if test_server "${server}"; then
                break
            else
                server=""
                n=$(( n + 1 ))
            fi
        done
    else
        # we force the server
        server=$(pick_server "${n}" "${sync_name}")
    fi

    rsync_server=$(echo "${server}" | cut -d':' -f1)
    rsync_port=$(echo "${server}" | cut -d':' -f2)

    log "SYNC_TASKS - sync=${sync_name}: use ${server}"
    
    # Rsync complete log file for the current run
    RSYNC_LOGFILE="/var/log/${PROGNAME}.${sync_name}.rsync.log"
    # Rsync stats for the current run
    RSYNC_STATSFILE="/var/log/${PROGNAME}.${sync_name}.rsync-stats.log"

    # reset Rsync log file
    if [ -n "$(command -v truncate)" ]; then
        truncate -s 0 "${RSYNC_LOGFILE}"
        truncate -s 0 "${RSYNC_STATSFILE}"
    else
        printf "" > "${RSYNC_LOGFILE}"
        printf "" > "${RSYNC_STATSFILE}"
    fi
    
    # Initialize variable here, we need it later
    local -a mtree_files=()

    if [ "${MTREE_ENABLED}" = "1" ]; then
        mtree_bin=$(command -v mtree)

        if [ -n "${mtree_bin}" ]; then
            # Dump filesystem stats with mtree
            log "SYNC_TASKS - sync=${sync_name}: start mtree"

            # Loop over Rsync includes
            for i in "${!rsync_includes[@]}"; do
                include="${rsync_includes[i]}"

                if [ -d "${include}" ]; then
                    # … but exclude for mtree what will be excluded by Rsync
                    mtree_excludes_file="$(mktemp --tmpdir "${PROGNAME}.${sync_name}.mtree-excludes.XXXXXX")"
                    add_to_temp_files "${mtree_excludes_file}"

                    for j in "${!rsync_excludes[@]}"; do
                        echo "${rsync_excludes[j]}" | grep -E "^([^/]|${include})" | sed -e "s|^${include}|.|" >> "${mtree_excludes_file}"
                    done

                    mtree_file="/var/log/evobackup.$(basename "${include}").mtree"
                    add_to_temp_files "${mtree_file}"

                    ${mtree_bin} -x -c -p "${include}" -X "${mtree_excludes_file}" > "${mtree_file}"
                    mtree_files+=("${mtree_file}")
                fi
            done

            if [ "${#mtree_files[@]}" -le 0 ]; then
                log_error "SYNC_TASKS - ${sync_name}: ERROR: mtree didn't produce any file"
            fi

            log "SYNC_TASKS - sync=${sync_name}: stop  mtree (files: ${mtree_files[*]})"
        else
            log "SYNC_TASKS - sync=${sync_name}: skip mtree (missing)"
        fi
    else
        log "SYNC_TASKS - sync=${sync_name}: skip mtree (disabled)"
    fi

    rsync_bin=$(command -v rsync)
    # Build the final Rsync command

    # Rsync main options
    rsync_main_args=()
    rsync_main_args+=(--archive)
    rsync_main_args+=(--itemize-changes)
    rsync_main_args+=(--quiet)
    rsync_main_args+=(--stats)
    rsync_main_args+=(--human-readable)
    rsync_main_args+=(--relative)
    rsync_main_args+=(--partial)
    rsync_main_args+=(--delete)
    rsync_main_args+=(--delete-excluded)
    rsync_main_args+=(--force)
    rsync_main_args+=(--ignore-errors)
    rsync_main_args+=(--log-file "${RSYNC_LOGFILE}")
    rsync_main_args+=(--rsh "ssh -p ${rsync_port} -o 'ConnectTimeout ${SSH_CONNECT_TIMEOUT}'")

    # Rsync excludes
    for i in "${!rsync_excludes[@]}"; do
        rsync_main_args+=(--exclude "${rsync_excludes[i]}")
    done

    # Rsync local sources
    rsync_main_args+=("${rsync_includes[@]}")

    # Rsync remote destination
    rsync_main_args+=("root@${rsync_server}:${REMOTE_BACKUP_DIR}/")

    # … log it
    log "SYNC_TASKS - sync=${sync_name}: Rsync main command : ${rsync_bin} ${rsync_main_args[*]}"

    # … execute it
    ${rsync_bin} "${rsync_main_args[@]}"

    rsync_main_rc=$?

    # Copy last lines of rsync log to the main log
    tail -n 30 "${RSYNC_LOGFILE}" >> "${LOGFILE}"
    # Copy Rsync stats to special file
    tail -n 30 "${RSYNC_LOGFILE}" | grep --invert-match --extended-regexp " [\<\>ch\.\*]\S{10} " > "${RSYNC_STATSFILE}"

    # We ignore rc=24 (vanished files)
    if [ ${rsync_main_rc} -ne 0 ] && [ ${rsync_main_rc} -ne 24 ]; then
        log_error "SYNC_TASKS - sync=${sync_name}: Rsync main command returned an error ${rsync_main_rc}" "${LOGFILE}"
        GLOBAL_RC=${E_SYNCFAILED}
    else
        # Build the report Rsync command
        local -a rsync_report_args

        rsync_report_args=()

        # Rsync options
        rsync_report_args+=(--rsh "ssh -p ${rsync_port} -o 'ConnectTimeout ${SSH_CONNECT_TIMEOUT}'")

        # Rsync local sources
        if [ "${#mtree_files[@]}" -gt 0 ]; then
            # send mtree files if there is any
            rsync_report_args+=("${mtree_files[@]}")
        fi
        if [ -f "${RSYNC_LOGFILE}" ]; then
            # send rsync full log file if it exists
            rsync_report_args+=("${RSYNC_LOGFILE}")
        fi
        if [ -f "${RSYNC_STATSFILE}" ]; then
            # send rsync stats log file if it exists
            rsync_report_args+=("${RSYNC_STATSFILE}")
        fi

        # Rsync remote destination
        rsync_report_args+=("root@${rsync_server}:${REMOTE_LOG_DIR}/")

        # … log it
        log "SYNC_TASKS - sync=${sync_name}: Rsync report command : ${rsync_bin} ${rsync_report_args[*]}"

        # … execute it
        ${rsync_bin} "${rsync_report_args[@]}"
    fi

    log "STOP  SYNC_TASKS - sync=${sync_name}"
}

setup() {
    # Default return-code (0 == succes)
    GLOBAL_RC=0

    # Possible error codes
    readonly E_NOSRVAVAIL=21 # No server is available
    readonly E_SYNCFAILED=20 # Failed sync task
    readonly E_DUMPFAILED=10 # Failed dump task

    # explicit PATH
    PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin

    # System name (linux, openbsd…)
    : "${SYSTEM:=$(uname | tr '[:upper:]' '[:lower:]')}"

    # Hostname (for logs and notifications)
    : "${HOSTNAME:=$(hostname)}"

    # Store pid in a file named after this program's name
    : "${PROGNAME:=$(basename "$0")}"
    : "${PIDFILE:="/var/run/${PROGNAME}.pid"}"

    # Customize the log path if you want multiple scripts to have separate log files
    : "${LOGFILE:="/var/log/evobackup.log"}"

    # Canary file to update before executing tasks
    : "${CANARY_FILE:="/zzz_evobackup_canary"}"

    # Date format for log messages
    : "${DATE_FORMAT:="%Y-%m-%d %H:%M:%S"}"

    # Should we fallback on other servers when the first one is unreachable?
    : "${SERVERS_FALLBACK:=1}"
    # timeout (in seconds) for SSH connections
    : "${SSH_CONNECT_TIMEOUT:=90}"

    : "${LOCAL_BACKUP_DIR:="/home/backup"}"
    # shellcheck disable=SC2174
    mkdir -p -m 711 "${LOCAL_BACKUP_DIR}"

    : "${ERRORS_DIR:="${LOCAL_BACKUP_DIR}/${PROGNAME}.errors-${START_TIME}"}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${ERRORS_DIR}"

    # Backup directory on remote server
    : "${REMOTE_BACKUP_DIR:="/var/backup"}"
    # Log directory in remote server
    : "${REMOTE_LOG_DIR:="/var/log"}"

    # Email address for notifications
    : "${MAIL:="root"}"

    # Email subject for notifications
    : "${MAIL_SUBJECT:="[info] EvoBackup - Client ${HOSTNAME}"}"

    # Enable/disable local tasks (default: enabled)
    : "${LOCAL_TASKS:=1}"
    # Enable/disable sync tasks (default: enabled)
    : "${SYNC_TASKS:=1}"

    # Enable/disable mtree (default: enabled)
    : "${MTREE_ENABLED:=1}"

    # If "setup_custom" exists and is a function, let's call it
    setup_custom_type="$(type -t setup_custom)"
    if [ "${setup_custom_type}" = "function" ]; then
        setup_custom
    fi

    ## Force umask
    umask 077

    # Initialize a list of temporary files
    declare -a TEMP_FILES=()
    # Any file in this list will be deleted when the program exits
    trap "cleanup" EXIT
}


run_evobackup() {
    # Start timer
    START_EPOCH=$(/bin/date +%s)
    START_TIME=$(/bin/date +"%Y%m%d%H%M%S")

    # Configure variables and environment
    setup

    log "START GLOBAL - VERSION=${VERSION} LOCAL_TASKS=${LOCAL_TASKS} SYNC_TASKS=${SYNC_TASKS}"

    # /!\ Only one backup processus can run at the sametime /!\
    # Based on PID file, kill any running process before continuing
    enforce_single_process "${PIDFILE}"

    # Update canary to keep track of each run
    update-evobackup-canary --who "${PROGNAME}" --file "${CANARY_FILE}"

    if [ "${LOCAL_TASKS}" = "1" ]; then
        local_tasks_wrapper
    fi

    if [ "${SYNC_TASKS}" = "1" ]; then
        sync_tasks_wrapper
    fi

    STOP_EPOCH=$(/bin/date +%s)

    case "${SYSTEM}" in
        *bsd)
            start_time=$(/bin/date -f "%s" -j "${START_EPOCH}" +"${DATE_FORMAT}")
            stop_time=$(/bin/date -f "%s" -j "${STOP_EPOCH}" +"${DATE_FORMAT}")
            ;;
        *)
            start_time=$(/bin/date --date="@${START_EPOCH}" +"${DATE_FORMAT}")
            stop_time=$(/bin/date --date="@${STOP_EPOCH}" +"${DATE_FORMAT}")
            ;;
    esac
    duration=$(( STOP_EPOCH - START_EPOCH ))

    log "STOP GLOBAL - start='${start_time}' stop='${stop_time}' duration=${duration}s"

    send_mail

    exit ${GLOBAL_RC}
}
