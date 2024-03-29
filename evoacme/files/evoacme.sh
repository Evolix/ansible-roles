#!/bin/bash
#
# evoacme is a shell script to manage Let's Encrypt certificate with
# certbot tool but with a dedicated user (no-root) and from a csr
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -e
set -u

show_version() {
    cat <<END
evoacme version ${VERSION}

Copyright 2009-2021 Evolix <info@evolix.fr>,
                    Victor Laborie <vlaborie@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Benoit Série <bserie@evolix.fr>
                    and others.

evoacme comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}

show_help() {
    cat <<EOT
Usage: ${PROGNAME} NAME
    NAME must be correspond to :
    - a CSR in ${CSR_DIR}/NAME.csr
    - a KEY in ${SSL_KEY_DIR}/NAME.key

    If env variable TEST=1, certbot is run in staging mode
    If env variable DRY_RUN=1, certbot is run in dry-run mode
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

sed_cert_path_for_apache() {
    local vhost=$1
    local vhost_full_path="/etc/apache2/ssl/${vhost}.conf"
    local cert_path=$2

    [ ! -r "${vhost_full_path}" ] && return 0

    local search="^SSLCertificateFile.*$"
    local replace="SSLCertificateFile ${cert_path}"

    if grep -qE "${search}" "${vhost_full_path}"; then
        [ -w "${vhost_full_path}" ] || error "File ${vhost_full_path} is not writable"

        sed -i "s~${search}~${replace}~" "${vhost_full_path}"
        debug "Config in ${vhost_full_path} has been updated"
        $(command -v apache2ctl) -t 2>/dev/null
        [ "${?}" -eq 0 ] || $(command -v apache2ctl) -t
    fi
}
sed_cert_path_for_nginx() {
    local vhost=$1
    local vhost_full_path="/etc/nginx/ssl/${vhost}.conf"
    local cert_path=$2

    [ ! -r "${vhost_full_path}" ] && return 0

    local search="^ssl_certificate[^_].*$"
    local replace="ssl_certificate ${cert_path};"

    if grep -qE "${search}" "${vhost_full_path}"; then
        [ -w "${vhost_full_path}" ] || error "File ${vhost_full_path} is not writable"

        sed -i "s~${search}~${replace}~" "${vhost_full_path}"
        debug "Config in ${vhost_full_path} has been updated"
        $(command -v nginx) -t 2>/dev/null
        [ "${?}" -eq 0 ] || $(command -v nginx) -t -q
    fi
}
x509_verify() {
    local file="$1"
    [ -r "$file" ] || error "File ${file} not found"
    "${OPENSSL_BIN}" x509 -noout -modulus -in "$file" >/dev/null
}
x509_enddate() {
    local file="$1"
    [ -r "$file" ] || error "File ${file} not found"
    "${OPENSSL_BIN}" x509 -noout -enddate -in "$file"
}
csr_verify() {
    local file="$1"
    [ -r "$file" ] || error "File ${file} not found"
    "${OPENSSL_BIN}" req -noout -modulus -in "$file" >/dev/null
}

main() {
    # check arguments
    [ "$#" -eq 1 ] || error "invalid argument(s)"

    [ "$1" = "-h" ] || [ "$1" = "--help" ] && show_help && exit 0
    [ "$1" = "-V" ] || [ "$1" = "--version" ] && show_version && exit 0

    mkdir -p "${ACME_DIR}"
    chown root: "${ACME_DIR}"
    [ -w "${ACME_DIR}" ]        || error "Directory ${ACME_DIR} is not writable"

    [ -d "${CSR_DIR}" ]         || error "Directory ${CSR_DIR} is not found"

    mkdir -p "${CRT_DIR}"
    chown root: "${CRT_DIR}"
    [ -w "${CRT_DIR}" ]         || error "Directory ${CRT_DIR} is not writable"

    mkdir -p "${LOG_DIR}"
    chown root: "${LOG_DIR}"
    [ -w "${LOG_DIR}" ]         || error "Directory ${LOG_DIR} is not writable"

    mkdir -p "${HOOKS_DIR}"
    chown root: "${HOOKS_DIR}"
    [ -d "${HOOKS_DIR}" ]        || error "Directory ${HOOKS_DIR} is not found"

    readonly VHOST=$(basename "$1" .conf)

    # check for important programs
    readonly OPENSSL_BIN=$(command -v openssl) || error "openssl command not installed"
    readonly CERTBOT_BIN=$(command -v certbot) || error "certbot command not installed"

    # double check for directories
    [ -d "${ACME_DIR}" ] || error "${ACME_DIR} is not a directory"
    [ -d "${CSR_DIR}" ]  || error "${CSR_DIR} is not a directory"
    [ -d "${LOG_DIR}" ]  || error "${LOG_DIR} is not a directory"

    #### CSR VALIDATION

    # verify .csr file
    readonly CSR_FILE="${CSR_DIR}/${VHOST}.csr"
    debug "Using CSR file: ${CSR_FILE}"
    [ -f "${CSR_FILE}" ] || error "${CSR_FILE} absent"
    [ -r "${CSR_FILE}" ] || error "${CSR_FILE} is not readable"

    csr_verify "${CSR_FILE}" || error "${CSR_FILE} is invalid"

    # Hook for evoadmin-web in cluster mode : check master status
    local evoadmin_state_file="/home/${VHOST}/state"
    [ -r "${evoadmin_state_file}" ] \
      && grep -q "STATE=slave" "${evoadmin_state_file}" \
      && debug "We are slave of this evoadmin cluster. Quit!" \
      && exit 0

    #### INIT OR RENEW?

    readonly LIVE_DIR="${CRT_DIR}/${VHOST}/live"
    readonly LIVE_CERT="${LIVE_DIR}/cert.crt"
    readonly LIVE_FULLCHAIN="${LIVE_DIR}/fullchain.pem"
    readonly LIVE_CHAIN="${LIVE_DIR}/chain.pem"

    # If live symlink already exists, it's not our first time...
    if [ -h "${LIVE_DIR}" ]; then
        # we have a live symlink
        # let's see if there is a cert to renew
        x509_verify "${LIVE_CERT}" || error "${LIVE_CERT} is invalid"

        # Verify if our certificate will expire
        crt_end_date=$(x509_enddate "${LIVE_CERT}" | cut -d= -f2)
        date_renew=$(date -ud "${crt_end_date} - ${SSL_MINDAY} days" +"%s")
        date_today=$(date +'%s')
        if [ "${date_today}" -lt "${date_renew}" ]; then
            debug "Cert ${LIVE_CERT} expires at ${crt_end_date} => more than ${SSL_MINDAY} days: kthxbye."
            exit 0
        fi
    fi

    #### CERTIFICATE CREATION WITH CERTBOT

    local iteration=$(date "+%Y%m%d%H%M%S")
    [ -n "${iteration}" ] || error "invalid iteration (${iteration})"

    readonly NEW_DIR="${CRT_DIR}/${VHOST}/${iteration}"

    [ -d "${NEW_DIR}" ] && error "${NEW_DIR} directory already exists, remove it manually."
    mkdir -p "${NEW_DIR}"
    chown -R root: "${CRT_DIR}"
    chmod -R 0700 "${CRT_DIR}"
    chmod -R g+rX "${CRT_DIR}"
    debug "New cert will be created in ${NEW_DIR}"

    readonly NEW_CERT="${NEW_DIR}/cert.crt"
    readonly NEW_FULLCHAIN="${NEW_DIR}/fullchain.pem"
    readonly NEW_CHAIN="${NEW_DIR}/chain.pem"

    local CERTBOT_MODE=""
    [ "${TEST}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --test-cert"
    [ "${QUIET}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --quiet"
    [ "${DRY_RUN}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --dry-run"
    [ "${CERTBOT_SELF_UPGRADE}" = "0" ] && CERTBOT_MODE="${CERTBOT_MODE} --no-self-upgrade"

    local CERTBOT_REGISTRATION="--agree-tos"
    if [ -n "${SSL_EMAIL}" ]; then
        debug "Registering at certbot with ${SSL_EMAIL} as email"
        CERTBOT_REGISTRATION="${CERTBOT_REGISTRATION} -m ${SSL_EMAIL}"
    else
        debug "Registering at certbot without email"
        CERTBOT_REGISTRATION="${CERTBOT_REGISTRATION} --register-unsafely-without-email"
    fi

    # Permissions checks
    test -r "${CSR_FILE}" || error "File ${CSR_FILE} is not readable"
    test -w "${NEW_DIR}" || error "Directory ${NEW_DIR} is not writable"

    # create a certificate with certbot
    # we disable the set -e during the certbot call
    set +e
    "${CERTBOT_BIN}" \
        certonly \
        ${CERTBOT_MODE} \
        ${CERTBOT_REGISTRATION} \
        --non-interactive \
        --webroot \
        --csr "${CSR_FILE}" \
        --webroot-path "${ACME_DIR}" \
        --cert-path "${NEW_CERT}" \
        --fullchain-path "${NEW_FULLCHAIN}" \
        --chain-path "${NEW_CHAIN}" \
        --logs-dir "$LOG_DIR" \
        2>&1 \
            | grep -v "certbot.crypto_util"

    if [ "${PIPESTATUS[0]}" != "0" ]; then
        error "Certbot has exited with a non-zero exit code when generating ${NEW_CERT}"
    fi
    set -e

    if [ "${DRY_RUN}" = "1" ]; then
        debug "In dry-run mode, we stop here. Bye"
        exit 0
    fi

    # verify if all is right
    x509_verify "${NEW_CERT}"      || error "${NEW_CERT} is invalid"
    x509_verify "${NEW_FULLCHAIN}" || error "${NEW_FULLCHAIN} is invalid"
    x509_verify "${NEW_CHAIN}"     || error "${NEW_CHAIN} is invalid"

    log "New certificate available at ${NEW_CERT}"

    #### CERTIFICATE ACTIVATION

    # link dance
    if [ -h "${LIVE_DIR}" ]; then
        rm "${LIVE_DIR}"
        debug "Remove ${LIVE_DIR} link"
    fi
    ln -s "${NEW_DIR}" "${LIVE_DIR}"
    debug "Link ${NEW_DIR} to ${LIVE_DIR}"
    # verify final path
    x509_verify "${LIVE_CERT}" || error "${LIVE_CERT} is invalid"

    # update Apache
    sed_cert_path_for_apache "${VHOST}" "${LIVE_FULLCHAIN}"
    # update Nginx
    sed_cert_path_for_nginx "${VHOST}" "${LIVE_FULLCHAIN}"

    #### EXECUTE HOOKS
    #
    # executable scripts placed in ${HOOKS_DIR}
    # are executed, unless their name ends with ".disabled"

    export EVOACME_VHOST_NAME="${VHOST}"
    export EVOACME_CERT="${LIVE_CERT}"
    export EVOACME_CHAIN="${LIVE_CHAIN}"
    export EVOACME_FULLCHAIN="${LIVE_FULLCHAIN}"

    # emulate certbot hooks environment variables
    export RENEWED_LINEAGE="${LIVE_DIR}"
    export RENEWED_DOMAINS="${VHOST}"

    # search for files in hooks directory
    for hook in $(find ${HOOKS_DIR} -type f -executable | sort); do
        set +e
        # keep only executables files, not containing a "."
        if [ -x "${hook}" ] && (basename "${hook}" | grep -vqF ".disable"); then
            debug "Executing ${hook}"
            ${hook}
        fi
        set -e
    done
}

readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(realpath -m $(dirname "$0"))
readonly ARGS=$@

readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}
readonly TEST=${TEST:-"0"}
readonly DRY_RUN=${DRY_RUN:-"0"}

readonly VERSION="21.01"

# Read configuration file, if it exists
[ -r /etc/default/evoacme ] && . /etc/default/evoacme

# Default value for main variables
readonly SSL_KEY_DIR=${SSL_KEY_DIR:-"/etc/ssl/private"}
readonly ACME_DIR=${ACME_DIR:-"/var/lib/letsencrypt"}
readonly CSR_DIR=${CSR_DIR:-"/etc/ssl/requests"}
readonly CRT_DIR=${CRT_DIR:-"/etc/letsencrypt"}
readonly LOG_DIR=${LOG_DIR:-"/var/log/evoacme"}
readonly HOOKS_DIR=${HOOKS_DIR:-"${CRT_DIR}/renewal-hooks/deploy"}
readonly SSL_MINDAY=${SSL_MINDAY:-"30"}
readonly SSL_EMAIL=${SSL_EMAIL:-""}
readonly CERTBOT_SELF_UPGRADE=${CERTBOT_SELF_UPGRADE:-"0"}

main ${ARGS}
