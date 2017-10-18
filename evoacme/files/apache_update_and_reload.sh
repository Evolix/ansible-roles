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

readonly PROGNAME=$(basename "$0")

readonly VERBOSE=${VERBOSE:-"0"}

if [ -z "${EVOACME_VHOST_PATH}"]; then
    error "Missing EVOACME_VHOST_PATH environment variable"
fi
if [ -z "${EVOACME_CERT_PATH}"]; then
    error "Missing EVOACME_CERT_PATH environment variable"
fi

readonly APACHE2CTL_BIN=$(command -v apache2ctl) || error "apache2ctl command not installed"

[ -r "${EVOACME_VHOST_PATH}"] || error "File ${EVOACME_VHOST_PATH} is not readable"

local search="^SSLCertificateFile.*$"
local replace="SSLCertificateFile ${EVOACME_VHOST_PATH}"

if ! $(grep -qE "${search}" "${EVOACME_VHOST_PATH}"); then
    [ -w "${EVOACME_VHOST_PATH}" ] || error "File ${EVOACME_VHOST_PATH} is not writable"

    sed -i "s~${search}~${replace}~" "${EVOACME_VHOST_PATH}"
    debug "Config in ${EVOACME_VHOST_PATH} has been updated"
fi

if [ -n "$(pidof apache2)" ]; then
    if $(${APACHE2CTL_BIN} -t 2> /dev/null); then
        debug "Apache detected... reloading"
        service apache2 reload
    else
        error "Apache config is broken, you must fix it !"
    fi
fi

exit 0
