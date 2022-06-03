#!/bin/sh

VERSION="22.06"

show_version() {
    cat <<END
evomariabackup version ${VERSION}

Copyright 2004-2022 Evolix <info@evolix.fr>,
                    Éric Morino <emorino@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>
                    and others.

evomariabackup comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}
show_help() {
    cat <<EOF
Usage: evomariabackup --backup-dir /path/to/mariabackup-target --compress-file /path/to/compressed.tgz
Options
    --backup-dir        mariabackup target directory
    --compress-file     File name for the compressed version
    --backup            Force backup phase
    --no-backup         Skip backup phase
    --compress          Force compress phase
    --no-compress       Skip compress phase
    --log-file          Log file to send messages
    --post-backup-hook  Script to execute after other tasks
    --verbose           Output much more information (to stdout/stderr or the log file)
    --quiet             Ouput only the most critical information
    --lock-file         Specify which lock file to use (default: /run/lock/mariabackup.lock)
    --max-age           Lock file is ignored if older than this (default: 1d)
    -h|--help|-?        Display help
    -V|--version        Display version, authors and license

Example usage for a backup then compress :
    # /usr/local/bin/evomariabackup --verbose \
        --backup-dir /backup/mariabackup/current \
        --compress-file /backup/mariabackup/compressed/$(date +\%H).tgz \
        --log-file /var/log/evomariabackup.log

max-age possible values:
    Xd = X days
    X or Xh = X hours
    Xm = X minutes
    Xs = X seconds
EOF
}

log_date() {
    date +"%Y-%m-%d %H:%M:%S"
}
is_log_file() {
    test -n "${log_file}"
}
is_verbose() {
    test "${verbose}" = "1"
}
is_quiet() {
    test "${quiet}" = "1"
}
log_line() {
    level=$1
    msg=$2
    printf "[%s] %s: %s\n" "$(log_date)" "${level}" "${msg}"
}
log_debug() {
    level="DEBUG"
    msg=$1
    if ! is_quiet && is_verbose; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_info() {
    level="INFO"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_warning() {
    level="WARNING"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_error() {
    level="ERROR"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
            if tty -s; then
                printf "%s\n" "${msg}" >&2
            fi
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_fatal() {
    level="FATAL"
    msg=$1
    if is_log_file; then
        log_line "${level}" "${msg}" >> "${log_file}"
        if tty -s; then
            printf "%s\n" "${msg}" >&2
        fi
    else
        log_line "${level}" "${msg}" >&2
    fi
}
duration_in_seconds() {
    if echo "${1}" | grep -E -q '^([0-9]+[wdhms])+$'; then
        duration=$(echo "${1}" | sed 's/w/ * 604800 + /g; s/d/ * 86400 + /g; s/h/ * 3600 + /g; s/m/ * 60 + /g; s/s/ + /g; s/+ $//' | xargs expr)
    elif echo "${1}" | grep -E -q '^[0-9]+$'; then
        duration=$(echo "${1} * 3600" | xargs expr)
    else
        return 1
    fi
    log_debug "Duration \`${1}' translated to ${duration} seconds"

    echo "${duration}"
}
lock_file_created_at() {
    created_at=$(stat -c %Z "${lock_file}")
    log_debug "Lock file ${lock_file} created at ${created_at}"

    echo "${created_at}"
}
lock_file_age() {
    last_change=$(lock_file_created_at)
    now=$(date +"%s")

    age=$(( now - last_change ))
    log_debug "Lock file ${lock_file} is ${age} seconds old"

    echo "${created_at}"
}
is_lock_file_too_old() {
    test "$(lock_file_age)" -ge "${max_age}"
}
kill_or_clean_lockfile() {
    lock_file=${1:-}

    if [ -f "${lock_file}" ]; then
        # Get Process ID from the lock file
        pid=$(cat "${lock_file}")
        if [ -n "${pid}" ]; then
            log_debug "Found pid ${pid} in ${lock_file}"

            if kill -0 "${pid}" 2> /dev/null; then
                log_debug "Found process with pid ${pid}"

                lock_file_created_at_human=$(date --date "@$(lock_file_created_at)" +"%Y-%m-%d %H:%M:%S")
                if is_lock_file_too_old ; then
                    # Kill the children
                    pkill -9 --parent "${pid}"
                    # Kill the parent
                    kill -9 "${pid}"
                    # Only one process can run in parallel
                    log_warning "Process \`${pid}' (started at ${lock_file_created_at_human}) has been killed by \`$$'"
                else
                    log_info "Process \`${pid}' (started at ${lock_file_created_at_human}) has precedence. Let's leave it work."
                    # make sure that this exit doesn't remove the existing lockfile !!
                    exit 0
                fi
            else
                log_warning "Process not found at PID \`${pid}'. Ignoring lock file \`${lock_file}'."
            fi
        else
            log_warning "Empty lockfile \`${lock_file}'. It should contain a PID."
        fi
        # Remove the lock file
        rm -f "${lock_file}"
        log_debug "Lock file ${lock_file} has been removed"
    fi
}
new_lock_file() {
    lock_file=${1:-}
    lock_dir=$(dirname "${lock_file}")

    if mkdir --parents "${lock_dir}"; then
        echo $$ > "${lock_file}"
        log_debug "Lock file '${lock_file}' has been created"
    else
        log_fatal "Failed to acquire lock file '${lock_file}'. Abort."
        exit 1
    fi
}
is_mariabackup_directory() {
    directory=${1:-}
    find "${directory}" -name 'ibdata*' -o -name 'ib_logfile*' -o -name 'xtrabackup_*' > /dev/null
}
check_backup_dir() {
    if [ -d "${backup_dir:?}" ]; then
        if [ "$(ls -A "${backup_dir:?}")" ]; then
            if is_mariabackup_directory "${backup_dir:?}"; then
                log_debug "The backup directory ${backup_dir:?} is not empty but looks like a mariabackup target. Let's clear it."
                rm -rf "${backup_dir:?}"
            else
                log_fatal "The backup directory ${backup_dir:?} is not empty and doesn't look like a mariabackup target. Please verify and clear the directory if you are sure."
                exit 1
            fi
        else
            log_debug "The backup directory ${backup_dir:?} exists but is empty. Let's proceed."
        fi
    else
        log_debug "The backup directory ${backup_dir:?} doesn't exist. Let's proceed."
    fi
    mkdir -p "${backup_dir:?}"
}
check_compress_dir() {
    if [ -d "${compress_dir:?}" ]; then
        log_debug "The compress_dir directory ${compress_dir:?} exists. Let's proceed."
    else
        log_debug "The compress_dir directory ${compress_dir:?} doesn't exist. Let's proceed."
    fi
    mkdir -p "${compress_dir:?}"
}

backup() {
    if [ -z "${backup_dir}" ]; then
        log_fatal "backup-dir option is empty"
    else
        check_backup_dir
    fi

    mariabackup_bin=$(command -v mariabackup)
    if [ -z "${mariabackup_bin}" ]; then
        log_fatal "Couldn't find mariabackup.\nUse 'apt install mariadb-backup'."
        exit 1
    fi

    backup_command="${mariabackup_bin} --backup --slave-info --target-dir=${backup_dir:?}"

    if ! is_quiet; then
        log_info "BEGIN mariabackup backup phase"
        log_debug "${backup_command}"
    fi

    if is_quiet || ! is_verbose ; then
        ${backup_command} >/dev/null 2>&1
        backup_rc=$?
    elif ! is_quiet; then
        if is_log_file; then
            ${backup_command} >>"${log_file}" 2>&1
            backup_rc=$?
        else
            ${backup_command}
            backup_rc=$?
        fi
    fi

    if [ ${backup_rc} -ne 0 ]; then
        log_fatal "Error executing mariabackup --backup"
        exit 1
    elif ! is_quiet; then
        log_info "END mariabackup backup phase"
    fi

    prepare_command="${mariabackup_bin} --prepare --target-dir=${backup_dir:?}"

    if ! is_quiet; then
        log_info "BEGIN mariabackup prepare phase"
        log_debug "${prepare_command}"
    fi

    if is_quiet || ! is_verbose ; then
        ${prepare_command} >/dev/null 2>&1
        prepare_rc=$?
    elif ! is_quiet; then
        if is_log_file; then
            ${prepare_command} >>"${log_file}" 2>&1
            prepare_rc=$?
        else
            ${prepare_command}
            prepare_rc=$?
        fi
    fi

    if [ ${prepare_rc} -ne 0 ]; then
        log_fatal "Error executing mariabackup --prepare"
        exit 1
    elif ! is_quiet; then
        log_info "END mariabackup prepare phase"
    fi
}
list_files_with_size() {
    path=$1
    find "${path}" -type f -exec du --bytes {} \; | sort -k2
}
dircheck_prepare() {
    if [ -z "${backup_dir}" ]; then
        log_fatal "backup-dir option is empty"
        exit 1
    elif [ -e "${backup_dir}" ] && [ ! -d "${backup_dir}" ]; then
        log_fatal "backup directory '${backup_dir}' exists but is not a directory"
        exit 1
    fi

    dircheck_cmd="dir-check"
    dircheck_bin=$(command -v ${dircheck_cmd})
    if [ -z "${dircheck_bin}" ]; then
        log_fatal "Couldn't find ${dircheck_cmd}."
        exit 1
    fi

    backup_parent_dir=$(dirname "${backup_dir}")
    backup_final_dir=$(basename "${backup_dir}")

    log_info "BEGIN dir-check phase"
    cwd=${PWD}
    cd "${backup_parent_dir}" || log_fatal "Impossible to change to ${backup_parent_dir}"

    "${dircheck_bin}" --prepare --dir "${backup_final_dir}"

    cd ${cwd} || log_fatal "Impossible to change back to ${cwd}"
    log_info "END dir-check phase"
}
compress() {
    compress_dir=$(dirname "${compress_file}")

    if [ -z "${backup_dir}" ]; then
        log_fatal "backup-dir option is empty"
        exit 1
    elif [ -e "${backup_dir}" ] && [ ! -d "${backup_dir}" ]; then
        log_fatal "backup directory '${backup_dir}' exists but is not a directory"
        exit 1
    fi
    if [ -z "${compress_file}" ]; then
        log_fatal "compress-file option is empty"
        exit 1
    fi
    if [ -n "${compress_dir}" ]; then
        check_compress_dir
    fi

    pigz_bin=$(command -v pigz)
    gzip_bin=$(command -v gzip)

    if [ -n "${pigz_bin}" ]; then
        compress_program="${pigz_bin} --keep -6"
    elif [ -n "${gzip_bin}" ]; then
        compress_program="${gzip_bin} -6"
    else
        log_fatal "Couldn't find pigz nor gzip.\nUse 'apt install pigz' or 'apt install gzip'."
        exit 1
    fi

    if ! is_quiet; then
        log_info "BEGIN compression phase"
        log_debug "Compression of ${backup_dir} to ${compress_file} using \`${compress_program}'"
    fi
    if is_quiet || ! is_verbose ; then
        tar --use-compress-program="${compress_program}" -cf "${compress_file}" "${backup_dir}" >/dev/null 2>&1
        tar_rc=$?
    elif ! is_quiet; then
        if is_log_file; then
            tar --use-compress-program="${compress_program}" -cf "${compress_file}" "${backup_dir}" >>"${log_file}" 2>&1
            tar_rc=$?
        else
            tar --use-compress-program="${compress_program}" -cf "${compress_file}" "${backup_dir}"
            tar_rc=$?
        fi
    fi

    if [ ${tar_rc} -ne 0 ]; then
        log_fatal "An error occured while compressing ${backup_dir} to ${compress_file}"
        exit 1
    elif ! is_quiet; then
        log_info "END compression phase"
    fi
}
post_backup_hook() {
    if [ -x "${post_backup_hook}" ]; then

        if ! is_quiet; then
            log_debug "Execution of \`${post_backup_hook}'"
            log_info "BEGIN hook phase"
        fi

        (
            export BACKUP_DIR="${backup_dir}"
            if is_log_file; then
                export LOG_FILE="${log_file}"
            fi
            "${post_backup_hook}"
        )
        hook_rc=$?

        if [ ${hook_rc} -ne 0 ]; then
            log_fatal "An error occured while executing post backup hook \`${post_backup_hook}'"
            exit 1
        elif ! is_quiet; then
            log_info "END hook phase"
        fi
    else
        log_fatal "Post backup hook \`${post_backup_hook}' is missing or not executable"
        exit 1
    fi
}

main() {
    if ! is_quiet; then
        log_info "BEGIN evomariabackup"
    fi

    kill_or_clean_lockfile "${lock_file}"
    # shellcheck disable=SC2064
    trap "rm -f ${lock_file};" 0
    new_lock_file "${lock_file}"

    if [ "${do_backup}" = "1" ] && [ -n "${backup_dir}" ]; then
        backup
    fi

    if [ "${do_dircheck}" = "1" ] && [ -n "${backup_dir}" ]; then
        dircheck_prepare
    fi

    if [ "${do_compress}" = "1" ] && [ -n "${compress_file}" ]; then
        compress
    fi

    if [ -n "${post_backup_hook}" ]; then
        post_backup_hook
    fi

    if ! is_quiet; then
        log_info "END evomariabackup"
    fi
}

# Declare variables

lock_file=""
log_file=""
verbose=""
quiet=""
max_age=""
do_backup=""
backup_dir=""
do_dircheck=""
do_compress=""
compress_file=""
post_backup_hook=""

# Parse options
# based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0
            ;;
        -V|--version)
            show_version
            exit 0
            ;;

        -m|--max-age)
            # with value separated by space
            if [ -n "$2" ]; then
                max_age=$(duration_in_seconds "$2")
                shift
            else
                log_fatal 'ERROR: "-m|--max-age" requires a non-empty option argument.'
            fi
            ;;
        --max-age=?*)
            # with value speparated by =
            max_age=$(duration_in_seconds "${1#*=}")
            ;;
        --max-age=)
            # without value
            log_fatal 'ERROR: "--max-age" requires a non-empty option argument.'
            ;;

        --backup)
            do_backup=1
            ;;

        --no-backup)
            do_backup=0
            ;;

        --backup-dir)
            # with value separated by space
            if [ -n "$2" ]; then
                backup_dir="$2"
                shift
            else
                log_fatal 'ERROR: "--backup-dir" requires a non-empty option argument.'
            fi
            ;;
        --backup-dir=?*)
            # with value speparated by =
            backup_dir=${1#*=}
            ;;
        --backup-dir=)
            # without value
            log_fatal '"--backup-dir" requires a non-empty option argument.'
            ;;

        --dir-check)
            do_dircheck=1
            ;;

        --no-dir-check)
            do_dircheck=0
            ;;

        --compress)
            do_compress=1
            ;;

        --no-compress)
            do_compress=0
            ;;

        --compress-file)
            # with value separated by space
            if [ -n "$2" ]; then
                compress_file="$2"
                if [ -z "${do_compress}" ]; then
                    do_compress=1
                fi
                shift
            else
                log_fatal '"--compress-file" requires a non-empty option argument.'
            fi
            ;;
        --compress-file=?*)
            # with value speparated by =
            compress_file=${1#*=}
            if [ -z "${do_compress}" ]; then
                do_compress=1
            fi
            ;;
        --compress-file=)
            # without value
            log_fatal '"--compress-file" requires a non-empty option argument.'
            ;;

        --lock-file)
            # with value separated by space
            if [ -n "$2" ]; then
                lock_file="$2"
                shift
            else
                log_fatal '"--lock-file" requires a non-empty option argument.'
            fi
            ;;
        --lock-file=?*)
            # with value speparated by =
            lock_file=${1#*=}
            ;;
        --lock-file=)
            # without value
            log_fatal '"--lock-file" requires a non-empty option argument.'
            ;;

        --log-file)
            # with value separated by space
            if [ -n "$2" ]; then
                log_file="$2"
                shift
            else
                log_fatal '"--log-file" requires a non-empty option argument.'
            fi
            ;;
        --log-file=?*)
            # with value speparated by =
            log_file=${1#*=}
            ;;
        --log-file=)
            # without value
            log_fatal '"--log-file" requires a non-empty option argument.'
            ;;

        --post-backup-hook)
            # with value separated by space
            if [ -n "$2" ]; then
                post_backup_hook="$2"
                shift
            else
                log_fatal '"--post-backup-hook" requires a non-empty option argument.'
            fi
            ;;
        --post-backup-hook=?*)
            # with value speparated by =
            post_backup_hook=${1#*=}
            ;;
        --post-backup-hook=)
            # without value
            log_fatal '"--post-backup-hook" requires a non-empty option argument.'
            ;;

        -v|--verbose)
            verbose=1
            ;;

        --quiet)
            quiet=1
            verbose=0
            ;;

        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            if tty -s; then
               printf 'Unknown option : %s\n' "$1" >&2
                echo "" >&2
                show_usage >&2
                exit 1
            else
                log_fatal 'Unknown option : %s\n' "$1" >&2
            fi
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# Default values

lock_file="${lock_file:-/run/lock/evomariabackup.lock}"
verbose=${verbose:-0}
quiet=${quiet:-0}
max_age="${max_age:-86400}"
do_backup="${do_backup:-1}"
do_dircheck="${do_dircheck:-0}"
do_compress="${do_compress:-0}"

main