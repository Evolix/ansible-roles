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

if [ -n "$(pidof apache2)" ]; then
    apache2ctl_bin=$(command -v apache2ctl)
    if ${apache2ctl_bin} configtest > /dev/null; then
        if grep --dereference-recursive -E "^\s*SSLCertificate" /etc/apache2/sites-enabled | grep -q "letsencrypt"; then
            debug "Apache detected... reloading"
            systemctl reload apache2
        else
            debug "Apache doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        error "Apache config is broken, you must fix it !"
    fi
else
    debug "Apache is not running. Skip."
fi
