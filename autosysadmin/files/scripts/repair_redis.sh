#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_redis:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_redis"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

handle_redis() {
    for service in $(systemd_list_service_failed redis*)
    do
        # ne rien faire si le service est désactivé
        if ! systemctl is-enabled  --quiet "${service}"
        then
            continue
        fi

        # ne rien faire si le service est actif
        if systemctl is-active --quiet "${service}"
        then
            continue
        fi

        if ! timeout 20 systemctl restart redis.service > /dev/null 2> /dev/null
        then
            log_error_exit "failed to restart redis ${service}"
        fi

        log_action "Redémarrer service ${service}"
    done
}

if ( systemd_list_units_enabled 'redis.*\.service$' ) > /dev/null
then
    handle_redis
    hook_mail success
else
    log 'Error: redis service is not enabled'
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
