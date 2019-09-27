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

postconf_bin=$(command -v postconf)

if [ -n "$(pidof master)" ] && [ -n "${postconf_bin}" ]; then
    if ${postconf_bin} | grep -E "^smtpd_tls_cert_file" | grep -q "letsencrypt"; then
        if ${postconf_bin} > /dev/null; then
            debug "Postfix detected... reloading"
            systemctl reload postfix
        else
            error "Postfix config is broken, you must fix it !"
        fi
    else
        debug "Postfix doesn't use Let's Encrypt certificate. Skip."
    fi
else
    debug "Postfix is not running or missing. Skip."
fi
