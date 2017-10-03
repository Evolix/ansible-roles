#!/bin/sh
#
# evoacme is a shell script to manage Let's Encrypt certificate with
# certbot tool but with a dedicated user (no-root) and from a csr
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -e

usage() {
    echo "Usage: $0 [ --cron ] NAME"
    echo ""
    echo "NAME must be correspond to :"
    echo "- a CSR in ${CSR_DIR}/NAME.csr"
    echo "- a KEY in ${SSL_KEY_DIR}/NAME.key"
    echo ""
}

debug() {
    [ "$CRON" = "NO" ] && echo "$1"
}

error() {
    echo "error: $1" >&2
    [ "$1" = "invalid argument(s)" ] && usage
    exit 1
}

mkconf_apache() {
    debug "Apache detected... first configuration"
    [ -f "/etc/apache2/ssl/${vhost}.conf" ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $CRT_DIR/${vhost}/live/fullchain.pem~" "/etc/apache2/ssl/${vhost}.conf"
    apache2ctl -t
}

mkconf_nginx() {
    debug "Nginx detected... first configuration"
    [ -f "/etc/nginx/ssl/${vhost}.conf" ] && sed -i "s~^ssl_certificate[^_].*$~ssl_certificate $CRT_DIR/${vhost}/live/fullchain.pem;~" "/etc/nginx/ssl/${vhost}.conf"
    nginx -t
}

main() {
    [ -f /etc/default/evoacme ] && . /etc/default/evoacme
    [ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR=/etc/ssl/private
    [ -z "${ACME_DIR}" ] && ACME_DIR=/var/lib/letsencrypt
    [ -z "${CSR_DIR}" ] && CSR_DIR=/etc/ssl/requests
    [ -z "${CRT_DIR}" ] && CRT_DIR=/etc/letsencrypt
    [ -z "${LOG_DIR}" ] && LOG_DIR=/var/log/evoacme
    [ -z "${SSL_MINDAY}" ] && SSL_MINDAY=30
    [ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR=/etc/ssl/self-signed
    [ -z "${DH_DIR}" ] && DH_DIR=etc/ssl/dhparam

    # misc verifications
    [ "$1" = "-h" ] || [ "$1" = "--help" ] && usage && exit 0
    which openssl >/dev/null || error "openssl command not installed"
    which certbot >/dev/null || error "certbot command not installed"
    [ ! -d $ACME_DIR ] && error "$ACME_DIR is not a directory"
    [ ! -d $CSR_DIR ] && error "$CSR_DIR is not a directory"
    [ ! -d $LOG_DIR ] && error "$LOG_DIR is not a directory"
    [ "$#" -ge 3 ] || [ "$#" -le 0 ] && error "invalid argument(s)"
    [ "$#" -eq 2 ] && [ "$1" != "--cron" ] && error "invalid argument(s)"

    [ "$#" -eq 1 ] && vhost=$(basename "$1" .conf) && CRON=NO
    [ "$#" -eq 2 ] && vhost=$(basename "$2" .conf) && CRON=YES

    # verify .csr file
    [ ! -f "$CSR_DIR/${vhost}.csr" ] && error "$CSR_DIR/${vhost}.csr absent"
    [ ! -r "$CSR_DIR/${vhost}.csr" ] && error "$C´SR_DIR/${vhost}.csr is not readable"
    openssl req -noout -modulus -in "$CSR_DIR/${vhost}.csr" >/dev/null || error "$CSR_DIR/${vhost}.csr is invalid"
    debug "Using CSR file: $CSR_DIR/${vhost}.csr"

    # Hook for evoadmin-web in cluster mode : check master status
    if [ -f "/home/${vhost}/state" ]; then
        grep -q "STATE=master" "/home/${vhost}/state" || exit 0
    fi

    if [ -n "$SSL_EMAIL" ]; then
        emailopt="-m $SSL_EMAIL"
    else
        emailopt="--register-unsafely-without-email"
    fi

    DATE=$(date "+%Y%m%d")
    [ ! -n "$DATE" ] && error "invalid date"


    # If live link already exists, it's not our first time...
    if [ -h "$CRT_DIR/${vhost}/live" ]; then
        openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/live/cert.crt"  >/dev/null || error "$CRT_DIR/${vhost}/live/cert.crt is invalid"

        # Verify if our certificate will expire
        crt_end_date=$(openssl x509 -noout -enddate -in "$CRT_DIR/${vhost}/live/cert.crt" | cut -d= -f2)
        date_renew=$(date -ud "$crt_end_date - $SSL_MINDAY days" +"%s")
        date_today=$(date +'%s')
        [ "$date_today" -lt "$date_renew" ] && debug "Cert $CRT_DIR/${vhost}/live/cert.crt expires at $crt_end_date => more than $SSL_MINDAY days: thxbye." && exit 0
    else
        which apache2ctl >/dev/null && mkconf_apache
        which nginx >/dev/null && mkconf_nginx
    fi

    # renew certificate with certbot
    [ -d "$CRT_DIR/${vhost}/${DATE}" ] && error "$CRT_DIR/${vhost}/${DATE} directory already exists, remove it manually."
    mkdir -pm 755 "$CRT_DIR/${vhost}/${DATE}"
    chown -R acme: "$CRT_DIR/${vhost}/${DATE}"
    [ "$CRON" = "YES" ] && CERTBOT_OPTS="--quiet"
    sudo -u acme certbot certonly $CERTBOT_OPTS --webroot --csr "$CSR_DIR/${vhost}.csr" --webroot-path "$ACME_DIR" -n --agree-tos --cert-path="$CRT_DIR/${vhost}/${DATE}/cert.crt" --fullchain-path="$CRT_DIR/${vhost}/${DATE}/fullchain.pem" --chain-path="$CRT_DIR/${vhost}/${DATE}/chain.pem" "$emailopt" --logs-dir "$LOG_DIR" 2>&1 | grep -v "certbot.crypto_util"

    # verify if all is right
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/cert.crt" >/dev/null || error "new $CRT_DIR/${vhost}/${DATE}/cert.crt is invalid"
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/fullchain.pem" >/dev/null || error "new $CRT_DIR/${vhost}/${DATE}/fullchain.pem is invalid"
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/chain.pem" >/dev/null || error "new $CRT_DIR/${vhost}/${DATE}/chain.pem is invalid"

    # link dance
    [ -h "$CRT_DIR/${vhost}/live" ] && rm "$CRT_DIR/${vhost}/live"
    ln -s "$CRT_DIR/${vhost}/${DATE}" "$CRT_DIR/${vhost}/live"
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/live/cert.crt" >/dev/null || error "new $CRT_DIR/{vhost}/live/cert.crt is invalid"

    # reload apache or nginx
    set +e
    pidof apache2 >/dev/null
    if [ "$?" -eq 0 ]; then
        apache2ctl -t 2>/dev/null
        if [ "$?" -eq 0 ]; then
            debug "Apache detected... reloading" && service apache2 reload
        else
            error "Apache config is broken, you must fix it !"
        fi
    fi
    pidof nginx >/dev/null
    if [ "$?" -eq 0 ]; then
        nginx -t 2>/dev/null
        if [ "$?" -eq 0 ]; then
            debug "Nginx detected... reloading" && service nginx reload
        else
            error "Nginx config is broken, you must fix it !"
        fi
    fi
}

main "$@"
