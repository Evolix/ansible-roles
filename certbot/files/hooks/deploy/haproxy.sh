#!/bin/sh
# /!\ MODIFIED to work with evoacme OR certbot
private_keys_dirs="/etc/ssl/private" # Only used for evoacme

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
    test -f "${full_chain}" && test -f "${private_key}"
}
config_check() {
    ${haproxy_bin} -c -f "${haproxy_config_file}" > /dev/null 2>&1
}
concat_files() {
    # shellcheck disable=SC2174
    mkdir --mode=700 --parents "${haproxy_cert_dir}"
    chown root: "${haproxy_cert_dir}"

    debug "Concatenating certificate files to ${haproxy_cert_file}"
    cat "${full_chain}" "${private_key}" > "${haproxy_cert_file}"
    chmod 600 "${haproxy_cert_file}"
    chown root: "${haproxy_cert_file}"
}
cert_and_key_mismatch() {
    haproxy_cert_md5=$(openssl x509 -noout -pubkey -in "${haproxy_cert_file}" | openssl md5)
    haproxy_key_md5=$(openssl pkey -pubout -in "${haproxy_cert_file}" | openssl md5)

    test "${haproxy_cert_md5}" != "${haproxy_key_md5}"
}
detect_haproxy_cert_dir() {
    # get last field or line wich defines the crt directory
    config_cert_dir=$(grep -r -o -E -h '^\s*bind .* crt /etc/\S+' "${haproxy_config_file}" | head -1 | awk '{ print $(NF)}')
    if [ -n "${config_cert_dir}" ]; then
        debug "Cert directory is configured with ${config_cert_dir}"
        echo "${config_cert_dir}"
    elif [ -d "/etc/haproxy/ssl" ]; then
        debug "No configured cert directory found, but /etc/haproxy/ssl exists"
        echo "/etc/haproxy/ssl"
    elif [ -d "/etc/ssl/haproxy" ]; then
        debug "No configured cert directory found, but /etc/ssl/haproxy exists"
        echo "/etc/ssl/haproxy"
    else
        error "Cert directory not found."
    fi
}
main() {
    if [ -z "${RENEWED_LINEAGE}" ]; then
      error "This script must be called only by certbot!"
    fi

    if daemon_found_and_running; then
        readonly haproxy_config_file="/etc/haproxy/haproxy.cfg"
        readonly haproxy_cert_dir=$(detect_haproxy_cert_dir)
        
        full_chain="${RENEWED_LINEAGE}/fullchain.pem"
        if  [ -n "${EVOACME_VHOST_NAME}" ]; then
            # EVOACME
            private_key=${private_keys_dirs}/$(basename "$(dirname "${RENEWED_LINEAGE}")").key
	        cert_name=$(basename "$(dirname "${RENEWED_LINEAGE}")")
        else
            # CERTBOT
            private_key=${RENEWED_LINEAGE}/privkey.pem
            cert_name=$(basename "${RENEWED_LINEAGE}")
        fi

        if found_renewed_lineage; then
            haproxy_cert_file="${haproxy_cert_dir}/${cert_name}.pem"
            failed_cert_file="/root/${cert_name}.failed.pem"

            concat_files

            if cert_and_key_mismatch; then
                mv "${haproxy_cert_file}" "${failed_cert_file}"
                error "Key and cert don't match, we moved the file to ${failed_cert_file} for inspection"
            fi

            if config_check; then
                debug "HAProxy detected... reloading"
                systemctl reload haproxy
            else
                error "HAProxy config is broken, you must fix it !"
            fi
        else
            error "Couldn't find '${full_chain}' or '${private_key}'"
        fi
    else
        debug "HAProxy is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly haproxy_bin=$(command -v haproxy)

main

