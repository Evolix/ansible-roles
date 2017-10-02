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

mkconf_apache() {
    echo "Apache detected... first configuration"
    [ -f "/etc/apache2/ssl/${vhost}.conf" ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $CRT_DIR/${vhost}/live/fullchain.pem~" "/etc/apache2/ssl/${vhost}.conf"
    apache2ctl -t
}

mkconf_nginx() {
    echo "Nginx detected... first configuration"
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
    which openssl >/dev/null || ( echo "error: openssl command not installed" && exit 1 )
    which certbot >/dev/null || ( echo "error: certbot command not installed" && exit 1 )
    [ ! -d $ACME_DIR ] && echo "error: $ACME_DIR is not a directory" && exit 1
    [ ! -d $CSR_DIR ] && echo "error: $CSR_DIR is not a directory" && exit 1
    [ ! -d $LOG_DIR ] && echo "error: $LOG_DIR is not a directory" && exit 1
    [ "$#" -ge 3 ] || [ "$#" -le 0 ] && echo "error: invalid argument(s)" && usage && exit 1
    [ "$#" -eq 2 ] && [ "$1" != "--cron" ] && echo "error: invalid argument(s)" && usage && exit 1

    [ "$#" -eq 1 ] && vhost=$(basename "$1" .conf) && CRON=NO
    [ "$#" -eq 2 ] && vhost=$(basename "$2" .conf) && CRON=YES

    # verify .csr file
    test ! -f "$CSR_DIR/${vhost}.csr" && echo "error: $CSR_DIR/${vhost}.csr absent" && exit 1
    test ! -r "$CSR_DIR/${vhost}.csr" && echo "error: $CSR_DIR/${vhost}.csr is not readable" && exit 1
    openssl req -noout -modulus -in "$CSR_DIR/${vhost}.csr" >/dev/null || ( echo "error: $CSR_DIR/${vhost}.csr is invalid" && exit 1 )
    [ "$CRON" = "NO" ] && echo "Using CSR file: $CSR_DIR/${vhost}.csr"

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
    [ ! -n "$DATE" ] && echo "error: invalid date" && exit 1


    # If live link already exists, it's not our first time...
    if [ -h "$CRT_DIR/${vhost}/live" ]; then
        openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/live/cert.crt"  >/dev/null || ( echo "error: $CRT_DIR/${vhost}/live/cert.crt is invalid" && exit 1 )

        # Verify if our certificate will expire
        crt_end_date=$(openssl x509 -noout -enddate -in "$CRT_DIR/${vhost}/live/cert.crt" | cut -d= -f2)
        date_renew=$(date -ud "$crt_end_date - $SSL_MINDAY days" +"%s")
        date_today=$(date +'%s')
        [ "$date_today" -lt "$date_renew" ] && ( [ "$CRON" = "NO" ] && echo "Cert $CRT_DIR/${vhost}/live/cert.crt expires at $crt_end_date => more than $SSL_MINDAY days: thxbye." || true ) && exit 0
    else
        which apache2ctl >/dev/null && mkconf_apache
        which nginx >/dev/null && mkconf_nginx
    fi

    # renew certificate with certbot
    [ -d "$CRT_DIR/${vhost}/${DATE}" ] && echo "error: $CRT_DIR/${vhost}/${DATE} directory already exists, remove it manually." && exit 1
    mkdir -pm 755 "$CRT_DIR/${vhost}/${DATE}"
    chown -R acme: "$CRT_DIR/${vhost}/${DATE}"
    [ "$CRON" = "YES" ] && CERTBOT_OPTS="--quiet"
    sudo -u acme certbot certonly $CERTBOT_OPTS --webroot --csr "$CSR_DIR/${vhost}.csr" --webroot-path "$ACME_DIR" -n --agree-tos --cert-path="$CRT_DIR/${vhost}/${DATE}/cert.crt" --fullchain-path="$CRT_DIR/${vhost}/${DATE}/fullchain.pem" --chain-path="$CRT_DIR/${vhost}/${DATE}/chain.pem" "$emailopt" --logs-dir "$LOG_DIR" 2>&1 | grep -v "certbot.crypto_util"

    # verify if all is right
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/cert.crt" >/dev/null || ( echo "error: new $CRT_DIR/${vhost}/${DATE}/cert.crt is invalid" && exit 1 )
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/fullchain.pem" >/dev/null || ( echo "error: new $CRT_DIR/${vhost}/${DATE}/fullchain.pem is invalid" && exit 1 )
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/${DATE}/chain.pem" >/dev/null || ( echo "error: new $CRT_DIR/${vhost}/${DATE}/chain.pem is invalid" && exit 1 )

    # link dance
    [ -h "$CRT_DIR/${vhost}/live" ] && rm "$CRT_DIR/${vhost}/live"
    ln -s "$CRT_DIR/${vhost}/${DATE}" "$CRT_DIR/${vhost}/live"
    openssl x509 -noout -modulus -in "$CRT_DIR/${vhost}/live/cert.crt" >/dev/null || ( echo "error: new $CRT_DIR/{vhost}/live/cert.crt is invalid" && exit 1 )

    # reload apache or nginx (TODO: need improvments)
    pidof apache2 >/dev/null && apache2ctl -t 2>/dev/null && ( [ "$CRON" = "NO" ] && echo "Apache detected... reloading" || true ) && systemctl reload apache2
    pidof nginx >/dev/null && nginx -t 2>/dev/null && ( [ "$CRON" = "NO" ] && echo "Nginx detected... reloading" || true ) && systemctl reload apache2

}

main "$@"
