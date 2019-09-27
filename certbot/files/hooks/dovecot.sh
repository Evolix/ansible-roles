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
    test -n "$(pidof dovecot)" && test -n "${doveconf_bin}"
}
config_check() {
    ${doveconf_bin} > /dev/null 2>&1
}
letsencrypt_used() {
    ${doveconf_bin} | grep -E "^ssl_cert[^_]" | grep -q "letsencrypt"
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_used; then
            if config_check; then
                debug "Dovecot detected... reloading"
                systemctl reload dovecot
            else
                error "Dovecot config is broken, you must fix it !"
            fi
        else
            debug "Dovecot doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        debug "Dovecot is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly doveconf_bin=$(command -v doveconf)

main
