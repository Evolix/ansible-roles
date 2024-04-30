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
    readonly hapee_main_pid=$(ps -u root u | grep hapee-lb | grep -v grep | awk '{print $2}')
    if [ -n "${hapee_main_pid}" ] && [ -d "/proc/${hapee_main_pid}" ] ; then
        readonly hapee_bin=$(readlink "/proc/${hapee_main_pid}/exe")
        readonly hapee_config_file=$(cat "/proc/${hapee_main_pid}/cmdline" | tr "\0" " " | grep --only-matching --extended-regexp -- "-f \S+" | awk '{print $2}')
        readonly hapee_pid_file=$(cat "/proc/${hapee_main_pid}/cmdline" | tr "\0" " " | grep --only-matching --extended-regexp -- "-p \S+" | awk '{print $2}')
        readonly hapee_service_name="$(basename -s .pid "${hapee_pid_file}").service"

        kill -0 "${hapee_main_pid}" && test -n "${hapee_bin}" && test -f "${hapee_config_file}" && systemctl -q is-active "${hapee_service_name}"
    else
        return 1
    fi
}
found_renewed_lineage() {
    test -f "${RENEWED_LINEAGE}/fullchain.pem" && test -f "${RENEWED_LINEAGE}/privkey.pem"
}
config_check() {
    ${hapee_bin} -c -f "${hapee_config_file}" > /dev/null 2>&1
}
concat_files() {
    # shellcheck disable=SC2174
    mkdir --mode=700 --parents "${hapee_cert_dir}"
    chown root: "${hapee_cert_dir}"

    debug "Concatenating certificate files to ${hapee_cert_file}"
    cat "${RENEWED_LINEAGE}/fullchain.pem" "${RENEWED_LINEAGE}/privkey.pem" > "${hapee_cert_file}"
    chmod 600 "${hapee_cert_file}"
    chown root: "${hapee_cert_file}"
}
cert_and_key_mismatch() {
    hapee_cert_md5=$(openssl x509 -noout -pubkey -in "${hapee_cert_file}" | openssl md5)
    hapee_key_md5=$(openssl pkey -pubout -in "${hapee_cert_file}" | openssl md5)

    test "${hapee_cert_md5}" != "${hapee_key_md5}"
}
detect_hapee_cert_dir() {
    # get last field or line wich defines the crt directory
    config_cert_dir=$(grep -r -o -E -h '^\s*bind .* crt /etc/\S+' "${hapee_config_file}" | head -1 | awk '{ print $(NF)}')
    if [ -n "${config_cert_dir}" ]; then
        debug "Cert directory is configured with ${config_cert_dir}"
        echo "${config_cert_dir}"
    else
        error "Cert directory not found."
    fi
}
main() {
    if [ -z "${RENEWED_LINEAGE}" ]; then
      error "This script must be called only by certbot!"
    fi

    if daemon_found_and_running; then
        readonly hapee_cert_dir=$(detect_hapee_cert_dir)

        if found_renewed_lineage; then
            hapee_cert_file="${hapee_cert_dir}/$(basename "${RENEWED_LINEAGE}").pem"
            failed_cert_file="/root/$(basename "${RENEWED_LINEAGE}").failed.pem"

            concat_files

            if cert_and_key_mismatch; then
                mv "${hapee_cert_file}" "${failed_cert_file}"
                error "Key and cert don't match, we moved the file to ${failed_cert_file} for inspection"
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

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

main
