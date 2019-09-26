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

if [ -n "$(pidof dovecot)" ]; then
    doveconf_bin=$(command -v doveconf)
    if ${doveconf_bin} > /dev/null; then
        if ${doveconf_bin} | grep -E "^ssl_cert[^_]" | grep -q "letsencrypt"; then
            debug "Dovecot detected... reloading"
            systemctl reload dovecot
        else
            debug "Dovecot doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        error "Dovecot config is broken, you must fix it !"
    fi
else
    debug "Dovecot is not running. Skip."
fi
