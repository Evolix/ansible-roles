#!/bin/sh
#
# make-csr is a shell script designed to automatically generate a
# certificate signing request (CSR) from an Apache or a Nginx vhost
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -u

usage() {
    cat <<EOT
Usage: ${PROGNAME} VHOST DOMAIN...
VHOST must correspond to an Apache or Nginx enabled VHost
If VHOST ends with ".conf" it is stripped,
then files are seached at those paths:
- /etc/apache2/sites-enables/VHOST.conf
- /etc/nginx/sites-enabled/VHOST.conf
- /etc/nginx/sites-enabled/VHOST
DOMAIN... is a list of domains for the CSR (passed as arguments or input)

If env variable VERBOSE=1, debug messages are sent to stderr
EOT
}
debug() {
    if [ "${VERBOSE}" = 1 ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
error() {
    >&2 echo "${PROGNAME}: $1"
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
    local crt_dir=$(dirname ${crt})

    [ -r "${csr}" ] || error "File ${csr} is not readable"
    [ -r "${key}" ] || error "File ${key} is not readable"
    [ -w "${crt_dir}" ] || error "Directory ${crt_dir} is not writable"

    "${OPENSSL_BIN}" x509 -req -sha256 -days 365 -in "${csr}" -signkey "${key}" -out "${crt}" 2> /dev/null
}
openssl_key(){
    local key="$1"
    local key_dir=$(dirname "${key}")
    local size="$2"

    [ -w "${key_dir}" ] || error "Directory ${key_dir} is not writable"

    "${OPENSSL_BIN}" genrsa -out "${key}" "${size}" 2> /dev/null
}
openssl_csr_san() {
    local csr="$1"
    local csr_dir=$(dirname "${csr}")
    local key="$2"
    local cfg="$3"

    [ -w "${csr_dir}" ] || error "Directory ${csr_dir} is not writable"

    "${OPENSSL_BIN}" req -new -sha256 -key "${key}" -reqexts SAN -config "${cfg}" -out "${csr}"
}
openssl_csr_single() {
    local csr="$1"
    local csr_dir=$(dirname "${csr}")
    local key="$2"
    local cfg="$3"

    [ -w "${csr_dir}" ] || error "Directory ${csr_dir} is not writable"

    "${OPENSSL_BIN}" req -new -sha256 -key "${key}" -config "${cfg}" -out "${csr}"
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
    local san=

    mkdir -p -m 0755 "${CSR_DIR}" || error "Unable to mkdir ${CSR_DIR}"

    if [ "${nb}" -eq 1 ]; then
        cat "${SSL_CONFIG_FILE}" - > "${config_file}" <<EOF
CN=$domains
EOF
        openssl_csr_single "${CSR_FILE}" "${SSL_KEY_FILE}" "${config_file}"
    elif [ "${nb}" -gt 1 ]; then
        for domain in $domains; do
            san="${san},DNS:${domain}"
        done
        san=$(echo "${san}" | sed 's/,//')
        cat ${SSL_CONFIG_FILE} - > "${config_file}" <<EOF
[SAN]
subjectAltName=${san}
EOF
        openssl_csr_san "${CSR_FILE}" "${SSL_KEY_FILE}" "${config_file}"
    fi
    debug "CSR stored at ${CSR_FILE}"

    if [ -r "${CSR_FILE}" ]; then
        chmod 644 "${CSR_FILE}"
        mkdir -p -m 0755 "${SELF_SIGNED_DIR}"

        openssl_selfsigned "${CSR_FILE}" "${SSL_KEY_FILE}" "${SELF_SIGNED_FILE}"

        [ -r "${SELF_SIGNED_FILE}" ] && chmod 644 "${SELF_SIGNED_FILE}"
        debug "Self-signed certificate stored at ${SELF_SIGNED_FILE}"
    fi
}

main() {
    if [ -t 0 ]; then
        # We have STDIN, so we should have at least 2 arguments
        if [ "$#" -lt 2 ]; then
            >&2 echo "invalid arguments"
            >&2 usage
            exit 1
        fi
        # read VHOST from first argument
        readonly VHOST="$1"
        # remove the first argument
        shift
        # read domains from remaining arguments
        readonly DOMAINS=$@
    else
        # We don't have STDIN, so we should have only 1 argument
        if [ "$#" != 1 ]; then
            >&2 echo "invalid arguments"
            >&2 usage
            exit 1
        fi
        # read VHOST from first argument
        readonly VHOST="$1"
        # read domains from input
        DOMAINS=
        while read -r line ; do
            DOMAINS="${DOMAINS} ${line}"
        done
        # trim the string to remove leading/trailing spaces
        DOMAINS=$(echo "${DOMAINS}" | xargs)
    fi

    [ -w "${CSR_DIR}" ]         || error "Directory ${CSR_DIR} is not writable"
    [ -w "${SELF_SIGNED_DIR}" ] || error "Directory ${SELF_SIGNED_DIR} is not writable"
    [ -w "${SSL_KEY_DIR}" ]     || error "Directory ${SSL_KEY_DIR} is not writable"
    [ -r "${SSL_CONFIG_FILE}" ] || error "File ${SSL_CONFIG_FILE} is not readable"

    # check for important programs
    readonly OPENSSL_BIN=$(command -v openssl) || error "openssl command not installed"

    SELF_SIGNED_FILE="${SELF_SIGNED_DIR}/${VHOST}.pem"
    SSL_KEY_FILE="${SSL_KEY_DIR}/${VHOST}.key"
    CSR_FILE="${CSR_DIR}/${VHOST}.csr"

    make_key "${SSL_KEY_FILE}" "${SSL_KEY_SIZE}"
    make_csr ${DOMAINS}

    command -v apache2ctl >/dev/null && sed_selfsigned_cert_path_for_apache "/etc/apache2/ssl/${VHOST}.conf"
    command -v nginx >/dev/null && sed_selfsigned_cert_path_for_nginx "/etc/nginx/ssl/${VHOST}.conf"
}

readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(readlink -m $(dirname "$0"))
readonly ARGS=$@

readonly VERBOSE=${VERBOSE:-"0"}

# Read configuration file, if it exists
[ -r /etc/default/evoacme ] && . /etc/default/evoacme

# Default value for main variables
CSR_DIR=${CSR_DIR:-'/etc/ssl/requests'}
SSL_CONFIG_FILE=${SSL_CONFIG_FILE:-"${CRT_DIR}/openssl.cnf"}
SELF_SIGNED_DIR=${SELF_SIGNED_DIR:-'/etc/ssl/self-signed'}
SSL_KEY_DIR=${SSL_KEY_DIR:-'/etc/ssl/private'}
SSL_KEY_SIZE=${SSL_KEY_SIZE:-$(default_key_size)}

main ${ARGS}
