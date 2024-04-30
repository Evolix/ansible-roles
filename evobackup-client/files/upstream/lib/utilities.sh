#!/usr/bin/env bash

# Output a message to the log file
log() {
    local msg="${1:-$(cat /dev/stdin)}"
    local pid=$$

    printf "[%s] %s[%s]: %s\\n" \
        "$(/bin/date +"${DATE_FORMAT}")" "${PROGNAME}" "${pid}" "${msg}" \
        >> "${LOGFILE}"
}
log_error() {
    local error_msg=${1}
    local error_file=${2:-""}

    if [ -n "${error_file}" ] && [ -f "${error_file}" ]; then
        printf "\n### %s\n" "${error_msg}" >&2
        # shellcheck disable=SC2046
        if [ $(wc -l "${error_file}" | cut -d " " -f 1) -gt 30 ]; then
            printf "~~~{%s (tail -30)}\n" "${error_file}" >&2
            tail -n 30 "${error_file}" >&2
        else
            printf "~~~{%s}\n" "${error_file}" >&2
            cat "${error_file}" >&2
        fi
        printf "~~~\n" >&2

        log "${error_msg}, check ${error_file}"
    else
        printf "\n### %s\n" "${error_msg}" >&2

        log "${error_msg}"
    fi

}
add_to_temp_files() {
    TEMP_FILES+=("${1}")
}
# Remove all temporary file created during the execution
cleanup() {
    # shellcheck disable=SC2086
    rm -f "${TEMP_FILES[@]}"
    find "${ERRORS_DIR}" -type d -empty -delete
}
enforce_single_process() {
    local pidfile=$1

    if [ -e "${pidfile}" ]; then
        pid=$(cat "${pidfile}")
        # Does process still exist?
        if kill -0 "${pid}" 2> /dev/null; then
            # Killing the childs of evobackup.
            for ppid in $(pgrep -P "${pid}"); do
                kill -9 "${ppid}";
            done
            # Then kill the main PID.
            kill -9 "${pid}"
            printf "%s is still running (PID %s). Process has been killed" "$0" "${pid}\\n" >&2
        else
            rm -f "${pidfile}"
        fi
    fi
    add_to_temp_files "${pidfile}"

    echo "$$" > "${pidfile}"
}

# Build the error directory (inside ERRORS_DIR) based on the dump directory path
errors_dir_from_dump_dir() {
    local dump_dir=$1
    local relative_path=$(realpath --relative-to="${LOCAL_BACKUP_DIR}" "${dump_dir}")

    # return absolute path
    realpath --canonicalize-missing "${ERRORS_DIR}/${relative_path}"
}

# Call test_server with "HOST:PORT" string
# It will return with 0 if the server is reachable.
# It will return with 1 and a message on stderr if not.
test_server() {
    local item=$1
    # split HOST and PORT from the input string
    local host=$(echo "${item}" | cut -d':' -f1)
    local port=$(echo "${item}" | cut -d':' -f2)

    local new_error

    # Test if the server is accepting connections
    ssh -q -o "ConnectTimeout ${SSH_CONNECT_TIMEOUT}" "${host}" -p "${port}" -t "exit"
    # shellcheck disable=SC2181
    if [ $? = 0 ]; then
        # SSH connection is OK
        return 0
    else
        # SSH connection failed
        new_error=$(printf "Failed to connect to \`%s' within %s seconds" "${item}" "${SSH_CONNECT_TIMEOUT}")
        log "${new_error}"
        SSH_ERRORS+=("${new_error}")

        return 1
    fi
}

# Call pick_server with an optional positive integer to get the nth server in the list.
pick_server() {
    local -i increment=${1:-0}
    local -i list_length=${#SERVERS[@]}
    local sync_name=${2:""}

    if (( increment >= list_length )); then
        # We've reached the end of the list
        new_error="No more server available"
        new_error="${new_error} for sync '${sync_name}'"
        log "${new_error}"
        SSH_ERRORS+=("${new_error}")

        # Log errors to stderr
        for i in "${!SSH_ERRORS[@]}"; do
            printf "%s\n" "${SSH_ERRORS[i]}" >&2
        done

        return 1
    fi

    # Extract the day of month, without leading 0 (which would give an octal based number)
    today=$(/bin/date +%e)
    # A salt is useful to randomize the starting point in the list
    # but stay identical each time it's called for a server (based on hostname).
    salt=$(hostname | cksum | cut -d' ' -f1)
    # Pick an integer between 0 and the length of the SERVERS list
    # It changes each day
    n=$(( (today + salt + increment) % list_length ))

    echo "${SERVERS[n]}"
}

send_mail() {
    tail -20 "${LOGFILE}" | mail -s "${MAIL_SUBJECT}" "${MAIL}"
}

path_to_str() {
    echo "${1}" | sed -e 's|^/||; s|/$||; s|/|:|g'
}
