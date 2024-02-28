#!/bin/bash

days=${1:-365}
log_dir="/var/log/autosysadmin/"

if [ -d "${log_dir}" ]; then
    find_run_dirs() {
        find "${log_dir}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -ctime "+${days}" \
            -print0
    }
    log() {
        /usr/bin/logger -p local0.notice -t autosysadmin "${1}"
    }

    while IFS= read -r -d '' run_dir; do
        rm --recursive --force "${run_dir}"
        log "Delete ${run_dir} (older than ${days} days)"
    done < <(find_run_dirs)
fi

exit 0
