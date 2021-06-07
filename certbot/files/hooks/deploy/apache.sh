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
    test -n "$(pidof apache2)" && test -n "${apache2ctl_bin}"
}
config_check() {
    ${apache2ctl_bin} configtest > /dev/null 2>&1
}
letsencrypt_used() {
    grep -q -r -E "letsencrypt" /etc/apache2/
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_used; then
            if config_check; then
                debug "Apache detected... reloading"
                systemctl reload apache2
            else
                error "Apache config is broken, you must fix it !"
            fi
        else
            debug "Apache doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        debug "Apache is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly apache2ctl_bin=$(command -v apache2ctl)

main
