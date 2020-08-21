#!/bin/bash
#
# make-csr is a shell script designed to automatically generate a
# certificate signing request (CSR) from an Apache or a Nginx vhost
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -u

show_version() {
    cat <<END
make-csr version ${VERSION}

Copyright 2009-2019 Evolix <info@evolix.fr>,
                    Victor Laborie <vlaborie@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Benoit Série <bserie@evolix.fr>
                    and others.

make-csr comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}

show_help() {
    cat <<EOT
Usage: ${PROGNAME} VHOST DOMAIN [DOMAIN]
    VHOST must correspond to an Apache or Nginx enabled VHost
    If VHOST ends with ".conf" it is stripped,
    then files are seached at those paths:
    - /etc/apache2/sites-enables/VHOST.conf
    - /etc/nginx/sites-enabled/VHOST.conf
    - /etc/nginx/sites-enabled/VHOST

    DOMAIN is a list of domains for the CSR (passed as arguments or input)

    If env variable QUIET=1, no message is output
    If env variable VERBOSE=1, debug messages are output
EOT
}

log() {
    if [ "${QUIET}" != "1" ]; then
        echo "${PROGNAME}: $1"
    fi
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
error() {
    >&2 echo "${PROGNAME}: $1"
    [ "$1" = "invalid argument(s)" ] && >&2 show_help
    exit 1
}

default_key_size() {
    grep default_bits "${SSL_CONFIG_FILE}" | cut -d'=' -f2 | xargs
}

sed_selfsigned_cert_path_for_apache() {
    local apache_ssl_vhost_path="$1"

    mkdir -p $(dirname "${apache_ssl_vhost_path}")
    if [ ! -f "${apache_ssl_vhost_path}" ]; then
        cat > "${apache_ssl_vhost_path}" <<EOF
SSLEngine On
SSLCertificateFile    ${SELF_SIGNED_FILE}
SSLCertificateKeyFile ${SSL_KEY_FILE}
EOF
        debug "SSL config added in ${apache_ssl_vhost_path}"
    else
        local search="^SSLCertificateFile.*$"
        local replace="SSLCertificateFile ${SELF_SIGNED_FILE}"

        sed -i "s~${search}~${replace}~" "${apache_ssl_vhost_path}"
        debug "SSL config updated in ${apache_ssl_vhost_path}"
    fi
}

sed_selfsigned_cert_path_for_nginx() {
    local nginx_ssl_vhost_path="$1"

    mkdir -p $(dirname "${nginx_ssl_vhost_path}")
    if [ ! -f "${nginx_ssl_vhost_path}" ]; then
        cat > "${nginx_ssl_vhost_path}" <<EOF
ssl_certificate ${SELF_SIGNED_FILE};
ssl_certificate_key ${SSL_KEY_FILE};
EOF
        debug "SSL config added in ${nginx_ssl_vhost_path}"
    else
        local search="^ssl_certificate[^_].*$"
        local replace="ssl_certificate ${SELF_SIGNED_FILE};"

        sed -i "s~${search}~${replace}~" "${nginx_ssl_vhost_path}"
        debug "SSL config updated in ${nginx_ssl_vhost_path}"
    fi
}

openssl_selfsigned() {
    local csr="$1"
    local key="$2"
    local crt="$3"
    local cfg="$4"
    local crt_dir=$(dirname ${crt})

    [ -r "${csr}" ] || error "File ${csr} is not readable"
    [ -r "${key}" ] || error "File ${key} is not readable"
    [ -w "${crt_dir}" ] || error "Directory ${crt_dir} is not writable"
    if grep -q SAN "${cfg}"; then
        "${OPENSSL_BIN}" x509 -req -sha256 -days 365 -in "${csr}" -extensions SAN -extfile "${cfg}" -signkey "${key}" -out "${crt}" 2> /dev/null
    else
        "${OPENSSL_BIN}" x509 -req -sha256 -days 365 -in "${csr}" -signkey "${key}" -out "${crt}" 2> /dev/null
    fi

    [ -r "${crt}" ] || error "Something went wrong, ${crt} has not been generated"
}
openssl_key(){
    local key="$1"
    local key_dir=$(dirname "${key}")
    local size="$2"

    [ -w "${key_dir}" ] || error "Directory ${key_dir} is not writable"

    "${OPENSSL_BIN}" genrsa -out "${key}" "${size}" 2> /dev/null

    [ -r "${key}" ] || error "Something went wrong, ${key} has not been generated"
}
openssl_csr() {
    local csr="$1"
    local csr_dir=$(dirname "${csr}")
    local key="$2"
    local cfg="$3"

    [ -w "${csr_dir}" ] || error "Directory ${csr_dir} is not writable"

    if $(grep -q "DNS:" "${cfg}"); then
        # CSR with SAN
        "${OPENSSL_BIN}" req -new -sha256 -key "${key}" -reqexts SAN -config "${cfg}" -out "${csr}"
    else
        # Single domain CSR
        "${OPENSSL_BIN}" req -new -sha256 -key "${key}" -config "${cfg}" -out "${csr}"
    fi

    [ -r "${csr}" ] || error "Something went wrong, ${csr} has not been generated"
}

make_key() {
    local key="$1"
    local size="$2"

    openssl_key "${key}" "${size}"
    debug "Private key stored at ${key}"

    chown root: "${key}"
    chmod 600 "${key}"
}

make_csr() {
    local domains=$@
    local nb=$#
    local config_file="/tmp/make-csr-${VHOST}.conf"
    local san=""

    mkdir -p -m 0755 "${CSR_DIR}" || error "Unable to mkdir ${CSR_DIR}"

    if [ "${nb}" -eq 1 ]; then
        cat "${SSL_CONFIG_FILE}" - > "${config_file}" <<EOF
CN=$domains
EOF
    elif [ "${nb}" -gt 1 ]; then
        for domain in ${domains}; do
            san="${san},DNS:${domain}"
        done
        san=$(echo "${san}" | sed 's/^,//')
        cat "${SSL_CONFIG_FILE}" - > "${config_file}" <<EOF
CN=${domains%% *}
[SAN]
subjectAltName=${san}
EOF
    fi
    openssl_csr "${CSR_FILE}" "${SSL_KEY_FILE}" "${config_file}"
    debug "CSR stored at ${CSR_FILE}"

    if [ -r "${CSR_FILE}" ]; then
        chmod 644 "${CSR_FILE}"
        mkdir -p -m 0755 "${SELF_SIGNED_DIR}"

        openssl_selfsigned "${CSR_FILE}" "${SSL_KEY_FILE}" "${SELF_SIGNED_FILE}" "${config_file}"

        [ -r "${SELF_SIGNED_FILE}" ] && chmod 644 "${SELF_SIGNED_FILE}"
        debug "Self-signed certificate stored at ${SELF_SIGNED_FILE}"
    fi
}

main() {
    # We must have at least 1 argument
    [ "$#" -ge 1 ] || error "invalid argument(s)"
    [ "$1" = "-h" ] || [ "$1" = "--help" ] && show_help && exit 0
    [ "$1" = "-V" ] || [ "$1" = "--version" ] && show_version && exit 0

    if [ -t 0 ]; then
        # We have STDIN, so we should at least 2 arguments
        [ "$#" -ge 2 ] || error "invalid argument(s)"

        # read VHOST from first argument
        VHOST="$1"
        # remove the first argument
        shift
        # read domains from remaining arguments
        DOMAINS=$@
    else
        # We don't have STDIN, so we should have 1 argument
        [ "$#" -eq 1 ] || error "invalid argument(s)"

        # read VHOST from first argument
        VHOST="$1"
        # read domains from input
        DOMAINS=
        while read -r line ; do
            DOMAINS="${DOMAINS} ${line}"
        done
        # trim the string to remove leading/trailing spaces
        DOMAINS=$(echo "${DOMAINS}" | xargs)
    fi
    readonly VHOST
    readonly DOMAINS

    mkdir -p "${CSR_DIR}"
    chown root: "${CSR_DIR}"
    [ -w "${CSR_DIR}" ]         || error "Directory ${CSR_DIR} is not writable"

    mkdir -p "${SELF_SIGNED_DIR}"
    chown root: "${SELF_SIGNED_DIR}"
    [ -w "${SELF_SIGNED_DIR}" ] || error "Directory ${SELF_SIGNED_DIR} is not writable"

    mkdir -p "${SSL_KEY_DIR}"
    [ -w "${SSL_KEY_DIR}" ]     || error "Directory ${SSL_KEY_DIR} is not writable"

    [ -r "${SSL_CONFIG_FILE}" ] || error "File ${SSL_CONFIG_FILE} is not readable"

    # check for important programs
    readonly OPENSSL_BIN=$(command -v openssl) || error "openssl command not installed"

    readonly SELF_SIGNED_FILE="${SELF_SIGNED_DIR}/${VHOST}.pem"
    readonly SSL_KEY_FILE="${SSL_KEY_DIR}/${VHOST}.key"
    readonly CSR_FILE="${CSR_DIR}/${VHOST}.csr"

    make_key "${SSL_KEY_FILE}" "${SSL_KEY_SIZE}"
    make_csr ${DOMAINS}

    command -v apache2ctl >/dev/null && sed_selfsigned_cert_path_for_apache "/etc/apache2/ssl/${VHOST}.conf"
    command -v nginx >/dev/null && sed_selfsigned_cert_path_for_nginx "/etc/nginx/ssl/${VHOST}.conf"
    exit 0
}

readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(realpath -m $(dirname "$0"))
readonly ARGS=$@

readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly VERSION="20.08"

# Read configuration file, if it exists
[ -r /etc/default/evoacme ] && . /etc/default/evoacme

# Default value for main variables
readonly CSR_DIR=${CSR_DIR:-'/etc/ssl/requests'}
readonly SSL_CONFIG_FILE=${SSL_CONFIG_FILE:-"/etc/letsencrypt/openssl.cnf"}
readonly SELF_SIGNED_DIR=${SELF_SIGNED_DIR:-'/etc/ssl/self-signed'}
readonly SSL_KEY_DIR=${SSL_KEY_DIR:-'/etc/ssl/private'}
readonly SSL_KEY_SIZE=${SSL_KEY_SIZE:-$(default_key_size)}

main ${ARGS}
