#!/bin/bash

# Specific functions for "repair" scripts

is_all_repair_disabled() {
    # Fetch values from the config
    # and if it is not defined or has no value, then assign "on"

    local status=${repair_all:=on}


    test "${status}" = "off" || test "${status}" = "0"
}

is_current_repair_disabled() {
    # Fetch values from the config
    # and if it is not defined or has no value, then assign "on"

    local status=${!PROGNAME:=on}

    test "${status}" = "off" || test "${status}" = "0"
}

ensure_not_disabled_or_exit() {
    if is_all_repair_disabled; then
        log_global 'All repair scripts are disabled.'
        exit 0
    fi
    if is_current_repair_disabled; then
        log_global "Current repair script (${PROGNAME}) is disabled."
        exit 0
    fi
}

# Set of actions to do at the begining of a "repair" script
pre_repair() {
    initialize

    # Are we supposed to run?
    ensure_not_disabled_or_exit

    # Has it recently been run?
    ensure_not_too_soon_or_exit

    # Can we acquire a lock?
    acquire_lock_or_exit

    # Is there any active user?
    ensure_no_active_users_or_exit

    # Save important information
    save_server_state
}

# Set of actions to do at the end of a "repair" script
post_repair() {
    quit
}

repair_lxc_php() {
    container_name=$1

    if is_systemd_enabled 'lxc.service'; then
        lxc_path=$(lxc-config lxc.lxcpath)
        if lxc-info --name "${container_name}" > /dev/null; then
            rootfs="${lxc_path}/${container_name}/rootfs"
            case "${container_name}" in
                php56) fpm_log_file="${rootfs}/var/log/php5-fpm.log"   ;;
                php70) fpm_log_file="${rootfs}/var/log/php7.0-fpm.log" ;;
                php73) fpm_log_file="${rootfs}/var/log/php7.3-fpm.log" ;;
                php74) fpm_log_file="${rootfs}/var/log/php7.4-fpm.log" ;;
                php80) fpm_log_file="${rootfs}/var/log/php8.0-fpm.log" ;;
                php81) fpm_log_file="${rootfs}/var/log/php8.1-fpm.log" ;;
                php82) fpm_log_file="${rootfs}/var/log/php8.2-fpm.log" ;;
                php83) fpm_log_file="${rootfs}/var/log/php8.3-fpm.log" ;;
                *)
                    log_abort_and_quit "Unknown container '${container_name}'" 
                ;;
            esac

            # Determine FPM Pool path
            php_path_pool=$(find "${lxc_path}/${container_name}/" -type d -name "pool.d")

            # Save LXC info (before restart)
            lxc-info --name "${container_name}" | save_in_log_dir "lxc-${container_name}.before.status"
            # Save last lines of FPM log (before restart)
            tail "${fpm_log_file}" | save_in_log_dir "$(basename "${fpm_log_file}" | sed -e 's/.log/.before.log/')"
            # Save NRPE check (before restart)
            /usr/local/lib/nagios/plugins/check_phpfpm_multi "${php_path_pool}" | save_in_log_dir "check_fpm_${container_name}.before.out"

            lxc-stop --timeout 20 --name "${container_name}"
            lxc-start --daemon --name "${container_name}"
            rc=$?
            if [ "${rc}" -eq "0" ]; then
                log_all "Restart LXC container '${container_name}: OK"
            else
                log_all "Restart LXC container '${container_name}: failed"
            fi

            # Save LXC info (after restart)
            lxc-info --name "${container_name}" | save_in_log_dir "lxc-${container_name}.after.status"
            # Save last lines of FPM log (after restart)
            tail "${fpm_log_file}" | save_in_log_dir "$(basename "${fpm_log_file}" | sed -e 's/.log/.after.log/')"
            # Save NRPE check (after restart)
            /usr/local/lib/nagios/plugins/check_phpfpm_multi "${php_path_pool}" | save_in_log_dir "check_fpm_${container_name}.after.out"
        else
            log_abort_and_quit "LXC container '${container_name}' doesn't exist."
        fi
    else
        log_abort_and_quit 'LXC not found.'
    fi
}
