#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_tomcat_instance:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_tomcat_instance"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

log_system_status

repair_tomcat_instance_handle_tomcat() {

    if /bin/su - "${1}" -c "/bin/systemctl --quiet --user is-active tomcat.service" ; then
        if ! /bin/su - "${1}" -c "/usr/bin/timeout 20 /bin/systemctl --quiet --user restart tomcat.service"
        then
            log_error_exit "Echec de redémarrage instance tomcat utilisateur ${1}"
        else
            log_action "Redémarrage instance tomcat utilisateur ${1}"
        fi
    elif /bin/systemctl --quiet is-active "${1}".service ; then
        if ! /usr/bin/timeout 20 systemctl --quiet restart "${1}".service
        then
            log_error_exit "Echec de redémarrage instance tomcat ${1}"
        else
            log_action "Redémarrage instance tomcat ${1}"
        fi
    fi

}

for instance in $( /usr/local/lib/nagios/plugins/check_tomcat_instance.sh |grep CRITICAL |awk '{print $3}' |sed '1d') ;
do
    repair_tomcat_instance_handle_tomcat "${instance}"
done

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
