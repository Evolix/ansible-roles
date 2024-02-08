#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_mysql:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_mysql"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

log_system_status

mysql_is_enabled() {
    if is_debian_jessie
    then
        find /etc/rc2.d/ -name '*mysql*' > /dev/null
    else
        systemd_list_units_enabled "mysql.service"
    fi
}

mysql_restart() {
    if is_debian_jessie
    then
        if ! timeout 60 /etc/init.d/mysql restart > /dev/null
        then
            log_error_exit 'failed to restart mysql'
        fi
    else
        if ! timeout 60 systemctl restart mysql.service > /dev/null
        then
           log_error_exit 'failed to restart mysql'
        fi
    fi
}

# Test functions
test_mysql_process_present() {
    pgrep -u mysql mysqld > /dev/null
}

if mysql_is_enabled
then
    if ! test_mysql_process_present
    then
        log_action "Redémarrage de MySQL"
        mysql_restart
        hook_mail success
    else
        log_error_exit "mysqld process alive. Aborting"
    fi
else
    log_error_exit "MySQL/MariaDB not enabled. Aborting"
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
