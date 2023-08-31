#!/bin/sh

readonly PROGNAME=$(basename "$0")
readonly ARGS=$@

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

if [ -n "$(pidof proftpd)" ]; then
    if $($(command -v proftpd) -t 2> /dev/null); then
        debug "ProFTPD detected... reloading"
        service proftpd reload
    else
        error "ProFTPD config is broken, you must fix it !"
    fi
else
    debug "ProFTPD is not running. Skip."
fi
