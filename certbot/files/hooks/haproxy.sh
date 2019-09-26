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

if [ -z "${RENEWED_LINEAGE}" ]; then
  error "This script must be called only by certbot!"
fi

if [ -n "$(pidof haproxy)" ]; then
    haproxy_bin=$(command -v haproxy)
    if ${haproxy_bin} -c -f /etc/haproxy/haproxy.cfg > /dev/null; then
        if [ -f "${RENEWED_LINEAGE}/fullchain.pem" ] && [ -f "${RENEWED_LINEAGE}/privkey.pem" ]; then
            haproxy_cert_file="/etc/ssl/haproxy/$(basename "${RENEWED_LINEAGE}").pem"

            debug "Concatenating certificate files to ${haproxy_cert_file}"
            cat "${RENEWED_LINEAGE}/fullchain.pem" "${RENEWED_LINEAGE}/privkey.pem" > "${haproxy_cert_file}"
            chmod 600 "${haproxy_cert_file}"
            chown root: "${haproxy_cert_file}"

            debug "HAProxy detected... reloading"
            systemctl reload apache2
        else
            error "Couldn't find ${RENEWED_LINEAGE}/fullchain.pem or ${RENEWED_LINEAGE}/privkey.pem"
        fi
    else
        error "HAProxy config is broken, you must fix it !"
    fi
else
    debug "HAProxy is not running. Skip."
fi
