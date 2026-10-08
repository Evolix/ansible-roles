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
move_cert_file() {
    src_file=$1
    dst_file=$2

    dst_dir=$(dirname "${dst_file}")

    # shellcheck disable=SC2174
    mkdir --mode=700 --parents "${dst_dir}"
    chown root: "${dst_dir}"

    debug "Moving certificate files to ${dst_file}"
    mv "${src_file}" "${dst_file}"
    chmod 600 "${dst_file}"
    chown root: "${dst_file}"
}
cert_and_key_match() {
    file=$1

    haproxy_cert_md5=$(openssl x509 -noout -pubkey -in "${file}" | openssl md5)
    haproxy_key_md5=$(openssl pkey -pubout -in "${file}" | openssl md5)

    test "${haproxy_cert_md5}" = "${haproxy_key_md5}"
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
      error "This script must be called with RENEWED_LINEAGE env variable!"
    fi

    if daemon_found_and_running; then
        readonly haproxy_config_file="/etc/haproxy/haproxy.cfg"
        haproxy_cert_dir="$(detect_haproxy_cert_dir)"
        readonly haproxy_cert_dir
        
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
            tmp_cert_file="${RENEWED_LINEAGE}/${cert_name}.tmp.pem"

            cat "${full_chain}" "${private_key}" > "${tmp_cert_file}"

            if cert_and_key_match "${tmp_cert_file}"; then
                move_cert_file "${tmp_cert_file}" "${haproxy_cert_file}"
            else
                error "Private key and certificate don't match, see ${tmp_cert_file} for inspection"
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

PROGNAME=$(basename "$0")
readonly PROGNAME
VERBOSE=${VERBOSE:-"0"}
readonly VERBOSE
QUIET=${QUIET:-"0"}
readonly QUIET

haproxy_bin=$(command -v haproxy)
readonly haproxy_bin

main

