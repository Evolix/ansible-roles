#!/bin/sh
#
# evoacme is a shell script to manage Let's Encrypt certificate with
# certbot tool but with a dedicated user (no-root) and from a csr
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -e
set -u

usage() {
    echo "Usage: $0 NAME"
    echo ""
    echo "NAME must be correspond to :"
    echo "- a CSR in ${CSR_DIR}/NAME.csr"
    echo "- a KEY in ${SSL_KEY_DIR}/NAME.key"
    echo ""
    echo "If env variable TEST=1, certbot is run in staging mode"
    echo "If env variable DRY_RUN=1, certbot is run in dry-run mode"
    echo "If env variable CRON=1, no message is output"
    echo ""
}

debug() {
    [ "${CRON}" = "0" ] && echo "$1"
}

error() {
    echo "error: $1" >&2
    [ "$1" = "invalid argument(s)" ] && usage
    exit 1
}

sed_cert_path_for_apache() {
    vhost=$1
    vhost_full_path="/etc/apache2/ssl/${vhost}.conf"
    cert_path=$2

    debug "Apache detected... first configuration in ${vhost_full_path}"
    [ -f "${vhost_full_path}" ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile ${cert_path}~" "${vhost_full_path}"
    $(command -v apache2ctl) -t
}

sed_cert_path_for_nginx() {
    vhost=$1
    vhost_full_path="/etc/nginx/ssl/${vhost}.conf"
    cert_path=$2

    debug "Nginx detected... first configuration in ${vhost_full_path}"
    [ -f "${vhost_full_path}" ] && sed -i "s~^ssl_certificate[^_].*$~ssl_certificate ${cert_path};~" "${vhost_full_path}"
    $(command -v nginx) -t
}

x509_verify() {
    ${OPENSSL_BIN} x509 -noout -modulus -in "$1" >/dev/null
}
csr_verify() {
    ${OPENSSL_BIN} req -noout -modulus -in "$1" >/dev/null
}
x509_enddate() {
    ${OPENSSL_BIN} x509 -noout -enddate -in "$1"
}

main() {
    # Read configuration file, if it exists
    [ -f /etc/default/evoacme ] && . /etc/default/evoacme

    # Default value for main variables
    SSL_KEY_DIR=${SSL_KEY_DIR:-"/etc/ssl/private"}
    ACME_DIR=${ACME_DIR:-"/var/lib/letsencrypt"}
    CSR_DIR=${CSR_DIR:-"/etc/ssl/requests"}
    CRT_DIR=${CRT_DIR:-"/etc/letsencrypt"}
    LOG_DIR=${LOG_DIR:-"/var/log/evoacme"}
    SSL_MINDAY=${SSL_MINDAY:-"30"}
    SELF_SIGNED_DIR=${SELF_SIGNED_DIR:-"/etc/ssl/self-signed"}
    SSL_EMAIL=${SSL_EMAIL:-""}

    CRON=${CRON:-"0"}
    TEST=${TEST:-"0"}
    DRY_RUN=${DRY_RUN:-"0"}

    [ "$1" = "-h" ] || [ "$1" = "--help" ] && usage && exit 0
    # check arguments
    [ "$#" -eq 1 ] || error "invalid argument(s)"

    VHOST=$(basename "$1" .conf)

    # check for important programs
    OPENSSL_BIN=$(command -v openssl) || error "openssl command not installed"
    CERTBOT_BIN=$(command -v certbot) || error "certbot command not installed"

    # double check for directories
    [ ! -d "${ACME_DIR}" ] && error "${ACME_DIR} is not a directory"
    [ ! -d "${CSR_DIR}" ] && error "${CSR_DIR} is not a directory"
    [ ! -d "${LOG_DIR}" ] && error "${LOG_DIR} is not a directory"

    #### CSR VALIDATION

    # verify .csr file
    CSR_FILE="${CSR_DIR}/${VHOST}.csr"
    debug "Using CSR file: ${CSR_FILE}"
    [ ! -f "${CSR_FILE}" ] && error "${CSR_FILE} absent"
    [ ! -r "${CSR_FILE}" ] && error "${CSR_FILE} is not readable"

    csr_verify "${CSR_FILE}" || error "${CSR_FILE} is invalid"

    # Hook for evoadmin-web in cluster mode : check master status
    evoadmin_state_file="/home/${VHOST}/state"
    [ -f "${evoadmin_state_file}" ] \
      && grep -q "STATE=slave" "${evoadmin_state_file}" \
      && debug "We are slave of this evoadmin cluster. Quit!" \
      && exit 0

    #### INIT OR RENEW?

    LIVE_DIR="${CRT_DIR}/${VHOST}/live"
    LIVE_CERT="${LIVE_DIR}/cert.crt"
    LIVE_FULLCHAIN="${LIVE_DIR}/fullchain.pem"
    LIVE_CHAIN="${LIVE_DIR}/chain.pem"

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
    else
        # We don't have a live symlink yet
        # Let's start from scratch and configure our web server(s)
        command -v apache2ctl && sed_cert_path_for_apache "${VHOST}" "${LIVE_FULLCHAIN}"
        command -v nginx && sed_cert_path_for_nginx "${VHOST}" "${LIVE_FULLCHAIN}"
    fi

    #### CERTIFICATE CREATION WITH CERTBOT

    ITERATION=$(date "+%Y%m%d%H%M%S")
    [ -z "${ITERATION}" ] && error "invalid iteration (${ITERATION})"

    NEW_DIR="${CRT_DIR}/${VHOST}/${ITERATION}"

    [ -d "${NEW_DIR}" ] && error "${NEW_DIR} directory already exists, remove it manually."
    mkdir -pm 755 "${NEW_DIR}"
    chown -R acme: "${NEW_DIR}"
    debug "New cert will be created in ${NEW_DIR}"

    NEW_CERT="${NEW_DIR}/cert.crt"
    NEW_FULLCHAIN="${NEW_DIR}/fullchain.pem"
    NEW_CHAIN="${NEW_DIR}/chain.pem"

    CERTBOT_MODE=""
    [ "${TEST}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --test-cert"
    [ "${CRON}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --quiet"
    [ "${DRY_RUN}" = "1" ] && CERTBOT_MODE="${CERTBOT_MODE} --dry-run"

    CERTBOT_REGISTRATION="--agree-tos"
    if [ -n "${SSL_EMAIL}" ]; then
        debug "Registering at certbot with ${SSL_EMAIL} as email"
        CERTBOT_REGISTRATION="${CERTBOT_REGISTRATION} -m ${SSL_EMAIL}"
    else
        debug "Registering at certbot without email"
        CERTBOT_REGISTRATION="${CERTBOT_REGISTRATION} --register-unsafely-without-email"
    fi

    # create a certificate with certbot
    sudo -u acme \
        ${CERTBOT_BIN} \
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

    # verify if all is right
    x509_verify "${NEW_CERT}" || error "${NEW_CERT} is invalid"
    x509_verify "${NEW_FULLCHAIN}" || error "${NEW_FULLCHAIN} is invalid"
    x509_verify "${NEW_CHAIN}" || error "${NEW_CHAIN} is invalid"

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

    # disable error catching
    # below this point anything can break
    set +e

    # reload apache if present
    if [ -n "$(pidof apache2)" ]; then
        if [ $(${APACHE2CTL_BIN} -t 2>/dev/null) ]; then
            debug "Apache detected... reloading"
            service apache2 reload
        else
            error "Apache config is broken, you must fix it !"
        fi
    fi

    # reload nginx if present
    if [ -n "$(pidof nginx)" ]; then
        if [ $(${NGINX_BIN} -t 2>/dev/null) ]; then
            debug "Nginx detected... reloading"
            service nginx reload
        else
            error "Nginx config is broken, you must fix it !"
        fi
    fi
}

main "$@"
