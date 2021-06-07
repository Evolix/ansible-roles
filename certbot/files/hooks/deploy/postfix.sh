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
    test -n "$(pidof master)" && test -n "${postconf_bin}"
}
config_check() {
    ${postconf_bin} > /dev/null 2>&1
}
letsencrypt_used() {
    ${postconf_bin} | grep -E "^smtpd_tls_cert_file" | grep -q "letsencrypt"
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_used; then
            if config_check; then
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
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly postconf_bin=$(command -v postconf)

main
