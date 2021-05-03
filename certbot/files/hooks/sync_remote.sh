#!/bin/sh

set -u

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
found_renewed_lineage() {
    test -f "${RENEWED_LINEAGE}/fullchain.pem" && test -f "${RENEWED_LINEAGE}/privkey.pem"
}
domain_from_cert() {
    openssl x509 -noout -subject -in "${RENEWED_LINEAGE}/fullchain.pem" | sed 's/^.*CN\ *=\ *//'
}
main() {
    if [ -z "${RENEWED_LINEAGE}" ]; then
        error "Missing RENEWED_LINEAGE environment variable (usually provided by certbot)."
    fi
    if [ -z "${servers}" ]; then
        debug "Empty server list, skip."
        exit 0
    fi

    if found_renewed_lineage; then
        RENEWED_DOMAINS=${RENEWED_DOMAINS:-$(domain_from_cert)}

        remote_lineage=${remote_dir}/renewed_lineage/$(basename "${RENEWED_LINEAGE}")

        for server in ${servers}; do
            remote_host="root@${server}"
            # shellcheck disable=SC2029
            ssh "${remote_host}" "mkdir -p ${remote_dir}" \
                || error "Couldn't create ${remote_dir} directory ${server}"

            rsync --archive --copy-links --delete "${RENEWED_LINEAGE}/" "${remote_host}:${remote_lineage}/" \
                || error "Couldn't sync certificate on ${server}"

            rsync --archive --copy-links --delete --exclude $0 --delete-excluded "${hooks_dir}/" "${remote_host}:${remote_dir}/hooks/" \
                || error "Couldn't sync hooks on ${server}"

            # shellcheck disable=SC2029
            ssh "${remote_host}" "export RENEWED_LINEAGE=\"${remote_lineage}/\" RENEWED_DOMAINS=${RENEWED_DOMAINS}; find ${remote_dir}/hooks/ -mindepth 1 -maxdepth 1 -type f -executable -exec {} \;" \
                || error "Something went wrong on ${server} for deploy hooks"
        done
    else
        error "Couldn't find required files in \`${RENEWED_LINEAGE}'"
    fi
}

PROGNAME=$(basename "$0")
VERBOSE=${VERBOSE:-"0"}
QUIET=${QUIET:-"0"}

hooks_dir="/etc/letsencrypt/renewal-hooks/deploy"
# The config file lust have the same name as the script, with a different extension (.cf instead of .sh)
config_file="${0%.*}.cf"
remote_dir="/root/cert_sync"

if [ -f "${config_file}" ]; then
    . "${config_file}"
fi
servers=${servers:-""}

if [ -z "${servers}" ]; then
    echo "${PROGNAME}: No server provided. Skip." >&2
    exit 0
fi

main
