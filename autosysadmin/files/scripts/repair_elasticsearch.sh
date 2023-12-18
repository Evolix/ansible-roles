#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_elasticsearch:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_elasticsearch"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

elasticsearch_is_enabled() {
    systemd_list_units_enabled "elasticsearch.service"

}

elasticsearch_restart() {
    if ! timeout 60 systemctl restart elasticsearch.service > /dev/null
    then
        log_error_exit 'failed to restart elasticsearch'
    fi
}

# Test functions
test_elasticsearch_process_present() {
    pgrep -u elasticsearch > /dev/null
}

if elasticsearch_is_enabled
then
    if ! test_elasticsearch_process_present
    then
        log_action "Redémarrage de elasticsearch"
        elasticsearch_restart
        hook_mail success
    else
        log_error_exit "Elasticsearch process alive. Aborting"
    fi
else
    log_error_exit "Elasticsearch is not enabled. Aborting"
fi

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
