#!/bin/bash

source /etc/default/evoacme

vhost=$1

SSL_EMAIL=$(grep emailAddress /etc/letsencrypt/openssl.cnf|cut -d'=' -f2|xargs)
if [ -n "$SSL_EMAIL" ]; then
    emailopt="--email $SSL_EMAIL"
else
    emailopt="--register-unsafely-without-email"
fi

if [ -f $CRT_DIR/${vhost}.crt ]; then
    renew=true
    crt_end_date=`openssl x509 -noout -enddate -in $CRT_DIR/${vhost}.crt|sed -e "s/.*=//"`
    date_crt=`date -ud "$crt_end_date" +"%s"`
    date_today=`date +'%s'`
    date_diff=$(( ( $date_crt - $date_today ) / (60*60*24) ))
    if [ $date_diff -ge $SSL_MINDAY ]; then
        exit 0
    fi
fi

rm -f $CRT_DIR/${vhost}.crt $CRT_DIR/${vhost}-fullchain.pem $CRT_DIR/${vhost}-chain.pem

sudo -u acme certbot certonly --quiet --webroot --csr $CSR_DIR/${vhost}.csr --webroot-path $ACME_DIR -n --agree-tos --cert-path=$CRT_DIR/${vhost}.crt --fullchain-path=$CRT_DIR/${vhost}-fullchain.pem --chain-path=$CRT_DIR/${vhost}-chain.pem $emailopt --logs-dir $LOG_DIR 2> >(grep -v certbot.crypto_util)

if [ $? != 0 ]; then
	exit 1
fi

which apache2ctl>/dev/null
if [ $? == 0 ]; then
        apache2ctl -t 2>/dev/null
        if [ $? == 0 ]; then
                service apache2 reload
        fi
fi
which nginx>/dev/null
if [ $? == 0 ]; then
        nginx -t 2>/dev/null
        if [ $? == 0 ]; then
                service nginx reload
        fi
fi

if [ -z "$renew" ]; then

cat <<EOF

- Nginx configuration :

ssl_certificate $CRT_DIR/${vhost}-fullchain.pem;
ssl_certificate_key /etc/ssl/private/${vhost}.key;

- Apache configuration :

SSLEngine On
SSLCertificateFile    $CRT_DIR/${vhost}-fullchain.pem
SSLCertificateKeyFile /etc/ssl/private/${vhost}.key

EOF

fi

exit 0
