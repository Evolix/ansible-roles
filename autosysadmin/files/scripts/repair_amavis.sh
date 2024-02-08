#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh
# shellcheck source=./restart_amavis.sh
source /usr/share/scripts/autosysadmin/restart_amavis.sh

init_autosysadmin
load_conf

test "${repair_amavis:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Verify if check_nrpe are not OK
check_nrpe "check_amavis" && log_error_exit 'check_amavis is OK, nothing to do here!'

# Has it recently been run?
get_argument "--no-delay" || is_too_soon

lockfile="/run/lock/repair_amavis"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !
restart_amavis

hook_mail success
AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
