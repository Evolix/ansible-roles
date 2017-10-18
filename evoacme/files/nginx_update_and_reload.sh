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

readonly NGINX_BIN=$(command -v nginx) || error "nginx command not installed"

[ -r "${EVOACME_VHOST_PATH}"] || error "File ${EVOACME_VHOST_PATH} is not readable"

readonly search="^ssl_certificate[^_].*$"
readonly replace="ssl_certificate ${EVOACME_CERT_PATH};"

if ! $(grep -qE "${search}" "${EVOACME_VHOST_PATH}"); then
    [ -w "${EVOACME_VHOST_PATH}" ] || error "File ${EVOACME_VHOST_PATH} is not writable"

    sed -i "s~${search}~${replace}~" "${EVOACME_VHOST_PATH}"
    debug "Config in ${EVOACME_VHOST_PATH} has been updated"
fi

if [ -n "$(pidof nginx)" ]; then
    if $(${NGINX_BIN} -t 2> /dev/null); then
        debug "Nginx detected... reloading"
        service nginx reload
    else
        error "Nginx config is broken, you must fix it !"
    fi
fi

exit 0
