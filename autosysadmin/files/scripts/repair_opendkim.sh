#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_opendkim:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_opendkim"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

log_system_status

# Functions dedicated to this repair script

opendkim_is_enabled() {
    systemd_list_units_enabled "opendkim.service"

}

opendkim_restart() {
    if ! timeout 60 systemctl restart opendkim.service > /dev/null
    then
        log_error_exit 'failed to restart opendkim'
    fi
}

opendkim_test_process_present() {
    pgrep -u opendkim > /dev/null
}


# Main logic

if opendkim_is_enabled
then
    if ! opendkim_test_process_present
    then
        log_action "Redémarrage de opendkim"
        opendkim_restart
        hook_mail success
    else
        log_error_exit "opendkim process alive. Aborting"
    fi
else
    log_error_exit "opendkim is not enabled. Aborting"
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
