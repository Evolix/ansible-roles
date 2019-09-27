#!/bin/sh

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}

nginx_bin=$(command -v nginx)

if [ -n "$(pidof nginx)" ] && [ -n "${nginx_bin}" ]; then
    if grep -q --dereference-recursive -E "letsencrypt" /etc/nginx/sites-enabled; then
        if ${nginx_bin} -t > /dev/null 2>&1; then
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
