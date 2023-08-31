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
    test -n "$(pidof proftpd)" && test -n "${proftpd_bin}"
}
config_check() {
    ${proftpd_bin} configtest > /dev/null 2>&1
}
letsencrypt_used() {
    grep -q -r -E "letsencrypt" /etc/proftpd/
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_used; then
            if config_check; then
                debug "ProFTPD detected... reloading"
                systemctl reload proftpd
            else
                error "ProFTPD config is broken, you must fix it !"
            fi
        else
            debug "ProFTPD doesn't use Let's Encrypt certificate. Skip."
        fi
    else
        debug "ProFTPD is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly proftpd_bin=$(command -v proftpd)

main
