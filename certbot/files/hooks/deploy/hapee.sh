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
    hapee_main_pid=$(ps -u root u | grep hapee-lb | grep -v grep | awk '{print $2}')
    readonly hapee_main_pid

    if [ -n "${hapee_main_pid}" ] && [ -d "/proc/${hapee_main_pid}" ] ; then
        hapee_bin=$(readlink "/proc/${hapee_main_pid}/exe")
        readonly hapee_bin

        hapee_config_file=$(cat "/proc/${hapee_main_pid}/cmdline" | tr "\0" " " | grep --only-matching --extended-regexp -- "-f \S+" | awk '{print $2}')
        readonly hapee_config_file

        hapee_pid_file=$(cat "/proc/${hapee_main_pid}/cmdline" | tr "\0" " " | grep --only-matching --extended-regexp -- "-p \S+" | awk '{print $2}')
        readonly hapee_pid_file

        hapee_service_name="$(basename -s .pid "${hapee_pid_file}").service"
        readonly hapee_service_name

        kill -0 "${hapee_main_pid}" && test -n "${hapee_bin}" && test -f "${hapee_config_file}" && systemctl -q is-active "${hapee_service_name}"
    else
        return 1
    fi
}
found_renewed_lineage() {
    test -f "${full_chain}" && test -f "${private_key}"
}
config_check() {
    ${hapee_bin} -c -f "${hapee_config_file}" > /dev/null 2>&1
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

    hapee_cert_md5=$(openssl x509 -noout -pubkey -in "${file}" | openssl md5)
    hapee_key_md5=$(openssl pkey -pubout -in "${file}" | openssl md5)

    test "${hapee_cert_md5}" = "${hapee_key_md5}"
}
detect_hapee_cert_dir() {
    # get last field or line wich defines the crt directory
    config_cert_dir=$(grep -r -o -E -h '^\s*bind .* crt /etc/\S+' "${hapee_config_file}" | head -1 | awk '{ print $(NF)}')
    if [ -n "${config_cert_dir}" ]; then
        debug "Cert directory is configured with ${config_cert_dir}"
        realpath "${config_cert_dir}"
    else
        error "Cert directory not found."
    fi
}
main() {
    if [ -z "${RENEWED_LINEAGE}" ]; then
      error "This script must be called with RENEWED_LINEAGE env variable!"
    fi

    if daemon_found_and_running; then
        hapee_cert_dir=$(detect_hapee_cert_dir)
        readonly hapee_cert_dir

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
            hapee_cert_file="${hapee_cert_dir}/$(basename "${RENEWED_LINEAGE}").pem"
            tmp_cert_file="${RENEWED_LINEAGE}/${cert_name}.tmp.pem"

            cat "${full_chain}" "${private_key}" > "${tmp_cert_file}"

            if cert_and_key_match "${tmp_cert_file}"; then
                move_cert_file "${tmp_cert_file}" "${hapee_cert_file}"
            else
                error "Private key and certificate don't match, see ${tmp_cert_file} for inspection"
            fi

            if config_check; then
                debug "HAPEE detected... reloading"
                systemctl reload "${hapee_service_name}"
            else
                error "HAPEE config is broken, you must fix it !"
            fi
        else
            error "Couldn't find ${RENEWED_LINEAGE}/fullchain.pem or ${RENEWED_LINEAGE}/privkey.pem"
        fi
    else
        debug "HAPEE is not running or missing. Skip."
    fi
}

PROGNAME=$(basename "$0")
readonly PROGNAME
VERBOSE=${VERBOSE:-"0"}
readonly VERBOSE
QUIET=${QUIET:-"0"}
readonly QUIET

main
