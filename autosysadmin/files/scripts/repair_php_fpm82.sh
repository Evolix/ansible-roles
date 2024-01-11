#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_php_fpm82:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_http"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}" 15s

ensure_no_active_users_or_exit

# The actual work starts below !

log_system_status
log_check_php_fpm

if systemd_list_units_enabled 'lxc'
then

    if lxc-ls | grep -q php82
    then
        lxc-stop -n php82
        lxc-start --daemon -n php82
        log_action "lxc-fpm - Redémarrage container php82"

        internal_info "#### tail /var/lib/lxc/php82/rootfs/var/log/php8.2-fpm.log"
        FPM_LOG=$(tail /var/lib/lxc/php82/rootfs/var/log/php8.2-fpm.log)
        internal_info "$FPM_LOG" "$(read_log_system_status)"

        hook_mail success
        hook_mail internal_info

    else
        log 'Not possible :v'
    fi

else
    log 'Error, not a multi-php install'
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail