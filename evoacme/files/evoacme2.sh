

show_usage() {
    cat <<EOT
Usage: evoacme --cert-name NAME --domain DOMAIN1[,DOMAIN2,…]
EOT
}

issue_cert() {
    umask 022
    acme.sh --issue 
}

install_cert() {

}

deploy_cert() {

}

CHALLENGE_DIR=/var/www/html
ACME_LOGGING_OPTIONS="--log /var/log/acme.sh.log --no-color"

# Pack web

## Apache
SSL_DIR=/etc/apache2/ssl
RELOAD_CMD="systemctl reload apache2"

## Nginx
SSL_DIR=/etc/nginx/ssl
RELOAD_CMD="systemctl reload nginx"


umask 022
mkdir -p ${CHALLENGE_DIR}

ACME_ISSUE_OPTIONS="--webroot ${CHALLENGE_DIR}"
# ACME_ISSUE_OPTIONS="${ACME_ISSUE_OPTIONS} --force"

acme.sh \
    --issue \
    --domain ${DOMAINS} \
    ${ACME_ISSUE_OPTIONS} \
    ${ACME_LOGGING_OPTIONS}

case $? in
    0)
        # certificate request successful
        ;;
    1)
        # certificate request failed
        ;;
    2)
        # certificate still valid, request skipped
        ;;
    *)
        # unknown
        ;;
esac

mkdir -p ${SSL_DIR}/${VHOST_NAME}
chmod 755 ${SSL_DIR} ${SSL_DIR}/${VHOST_NAME}

KEY_PATH=${SSL_DIR}/${VHOST_NAME}/privkey.pem
FULLCHAIN_PATH=${SSL_DIR}/${VHOST}/fullchain.pem

acme.sh \
    --install-cert \
    --domain ${DOMAINS} \
    --key-file ${KEY_PATH} \
    --fullchain-file ${FULLCHAIN_PATH} \
    --reloadcmd ${RELOAD_CMD} \
    ${ACME_LOGGING_OPTIONS}

## Apache
sed -i "s~^(\s*SSLCertificateFile\s+).+~\1${FULLCHAIN_PATH}~" ${VHOST_PATH}
sed -i "s~^(\s*SSLCertificateKeyFile\s+).+~\1${KEY_PATH}~" ${VHOST_PATH}

## Nginx
sed -i "s~^(\s*ssl_certificate\s+).+~\1${FULLCHAIN_PATH};~" ${VHOST_PATH}
sed -i "s~^(\s*ssl_certificate_key\s+).+~\1${KEY_PATH};~" ${VHOST_PATH}


${RELOAD_CMD}