#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

# Comment this line to enable
repair_template=off
test "${repair_template:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_template"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

log_system_status

# Functions dedicated to this repair script

template_is_enabled() {
    systemd_list_units_enabled "template.service"

}

template_restart() {
    if ! timeout 60 systemctl restart template.service > /dev/null
    then
        log_error_exit 'failed to restart template'
    fi
}

template_test_process_present() {
    pgrep -u template > /dev/null
}


# Main logic

if template_is_enabled
then
    if ! template_test_process_present
    then
        log_action "Redémarrage de template"
        template_restart
        hook_mail success
    else
        log_error_exit "template process alive. Aborting"
    fi
else
    log_error_exit "template is not enabled. Aborting"
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
