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
    test -n "$(pidof haproxy)" && test -n "${haproxy_bin}"
}
found_renewed_lineage() {
    test -f "${RENEWED_LINEAGE}/fullchain.pem" && test -f "${RENEWED_LINEAGE}/privkey.pem"
}
config_check() {
    ${haproxy_bin} -c -f /etc/haproxy/haproxy.cfg > /dev/null 2>&1
}
concat_files() {
    # shellcheck disable=SC2174
    mkdir --mode=700 --parents "${haproxy_cert_dir}"
    chown root: "${haproxy_cert_dir}"

    debug "Concatenating certificate files to ${haproxy_cert_file}"
    cat "${RENEWED_LINEAGE}/fullchain.pem" "${RENEWED_LINEAGE}/privkey.pem" > "${haproxy_cert_file}"
    chmod 600 "${haproxy_cert_file}"
    chown root: "${haproxy_cert_file}"
}
cert_and_key_mismatch() {
    haproxy_cert_md5=$(openssl x509 -noout -modulus -in "${haproxy_cert_file}" | openssl md5)
    haproxy_key_md5=$(openssl rsa -noout -modulus -in "${haproxy_cert_file}" | openssl md5)

    test "${haproxy_cert_md5}" != "${haproxy_key_md5}"
}
main() {
    if [ -z "${RENEWED_LINEAGE}" ]; then
      error "This script must be called only by certbot!"
    fi

    if daemon_found_and_running; then
        if found_renewed_lineage; then
            haproxy_cert_file="${haproxy_cert_dir}/$(basename "${RENEWED_LINEAGE}").pem"
            failed_cert_file="/root/$(basename "${RENEWED_LINEAGE}").failed.pem"

            concat_files

            if cert_and_key_mismatch; then
                mv "${haproxy_cert_file}" "${failed_cert_file}"
                error "Key and cert don't match, we moved the file to ${failed_cert_file} for inspection"
            fi

            if config_check; then
                debug "HAProxy detected... reloading"
                systemctl reload apache2
            else
                error "HAProxy config is broken, you must fix it !"
            fi
        else
            error "Couldn't find ${RENEWED_LINEAGE}/fullchain.pem or ${RENEWED_LINEAGE}/privkey.pem"
        fi
    else
        debug "HAProxy is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly haproxy_bin=$(command -v haproxy)
readonly haproxy_cert_dir="/etc/ssl/haproxy"

main
