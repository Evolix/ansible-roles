#!/bin/sh

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
daemon_found_and_running() {
    test -n "$(pidof nginx)" && test -n "${nginx_bin}"
}
config_check() {
    ${nginx_bin} -t > /dev/null 2>&1
}
letsencrypt_used() {
    grep -q --dereference-recursive -E "letsencrypt" /etc/nginx/sites-enabled
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_used; then
            if config_check; then
                debug "Nginx detected... reloading"
                systemctl reload nginx
            else
                error "Nginx config is broken, you must fix it !"
            fi
        else
            debug "Nginx doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        debug "Nginx is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly nginx_bin=$(command -v nginx)

main
