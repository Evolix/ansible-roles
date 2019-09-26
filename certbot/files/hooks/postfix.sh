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

if [ -n "$(pidof master)" ]; then
    postconf_bin=$(command -v postconf)
    if ${postconf_bin} > /dev/null; then
        if ${postconf_bin} | grep -E "^smtpd_tls_cert_file" | grep -q "letsencrypt"; then
            debug "Postfix detected... reloading"
            systemctl reload postfix
        else
            debug "Postfix doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        error "Postfix config is broken, you must fix it !"
    fi
else
    debug "Postfix is not running. Skip."
fi
