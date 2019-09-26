#!/bin/sh

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

if [ -n "$(pidof nginx)" ]; then
    nginx_bin=$(command -v nginx)
    if ${nginx_bin} -t > /dev/null; then
        if grep --dereference-recursive -E "^\s*ssl_certificate" /etc/nginx/sites-enabled | grep -q "letsencrypt"; then
            debug "Nginx detected... reloading"
            systemctl reload nginx
        else
            debug "Nginx doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        error "Nginx config is broken, you must fix it !"
    fi
else
    debug "Nginx is not running. Skip."
fi
