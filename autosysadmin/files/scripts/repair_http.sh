#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_http:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_http"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

log_system_status

http_detect_service() {
    # check whether nginx, apache or both are supposed to be running
    if is_debian_jessie; then
        find /etc/rc2.d/
    else
        systemctl list-unit-files --state=enabled
    fi | awk '/nginx/ { nginx = 1 } /apache2/ { apache2 = 1 } END { if (nginx && apache2) { print "both" } else if (nginx) { print "nginx" } else if (apache2) { print "apache2" } }'
    # The previous awk command looks for two patterns: "nginx"
    # and "apache2". If a line matches the patterns, a variable
    # "nginx" or "apache2" is set to 1 (true). The "END" checks
    # if one or both patterns has been found.
}

http_handle_apache() {
    # check syntax
    if ! apache2ctl -t > /dev/null 2> /dev/null
    then
        log_error_exit 'apache2 configuration syntax is not valid'
    fi

    # try restart
    if ! timeout 20 systemctl restart apache2.service > /dev/null 2> /dev/null
    then
        log_error_exit 'failed to restart apache2'
    fi

    log_action "Redémarrage de Apache"

    internal_info "#### grep $(LANG=en_US.UTF-8 date '+%b %d') /home/*/log/error.log /var/log/apache2/*error.log (avec filtrage)"
    ERROR_LOG=$(grep "$(LANG=en_US.UTF-8 date '+%b %d')" /home/*/log/error.log /var/log/apache2/*error.log | grep -v -e "Got error 'PHP message:" -e "No matching DirectoryIndex" -e "client denied by server configuration" -e "server certificate does NOT include an ID which matches the server name" )
    internal_info "$ERROR_LOG"

}

http_handle_nginx() {
    # check syntax
    if ! nginx -t > /dev/null 2> /dev/null
    then
        log_error_exit 'nginx configuration syntax is not valid'
    fi

    # try restart
    if ! timeout 20 systemctl restart nginx.service > /dev/null 2> /dev/null
    then
        log_error_exit 'failed to restart nginx'
    fi

    log_action "Redémarrage de Nginx"
}

http_handle_lxc_php() {
    # check whether containers are used for PHP and reboot them if so
    if systemd_list_units_enabled 'lxc'
    then
        for php in $(lxc-ls | grep 'php'); do
            lxc-stop -n "$php"
            lxc-start --daemon -n "$php"
            log_action "lxc-fpm - Redémarrage container ${php}"
        done

    fi
}

http_handle_fpm_php() {
    # check whether php-fpm is installed and restart it if so
    if enabled_units="$(systemd_list_units_enabled "php.*-fpm")"
    then
        systemctl restart "${enabled_units}"
        log_action 'php-fpm - Redémarrage de php-fpm'
    fi
}

case "$(http_detect_service)" in
nginx)

    http_handle_nginx

    http_handle_lxc_php
    http_handle_fpm_php

    hook_mail success
    hook_mail internal_info
    ;;

apache2)

    http_handle_apache

    http_handle_lxc_php
    http_handle_fpm_php

    hook_mail success
    hook_mail internal_info
    ;;

both)

    http_handle_nginx
    http_handle_apache

    http_handle_lxc_php
    http_handle_fpm_php

    hook_mail success
    hook_mail internal_info
    ;;

*)
    # unknown
    log 'nothing to do'
    ;;
esac

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
