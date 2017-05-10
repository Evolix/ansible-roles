#!/bin/bash

[ -f /etc/default/evoacme ] && source /etc/default/evoacme
[ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR='/etc/ssl/private'
[ -z "${CSR_DIR}" ] && CSR_DIR='/etc/ssl/requests'
[ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR='/etc/ssl/self-signed'

vhost=$(basename $1 .conf)

SSL_EMAIL=$(grep emailAddress /etc/letsencrypt/openssl.cnf|cut -d'=' -f2|xargs)
if [ -n "$SSL_EMAIL" ]; then
    emailopt="--email $SSL_EMAIL"
else
    emailopt="--register-unsafely-without-email"
fi

# Check master status for evoadmin-cluster
if [ -f /home/${vhost}/state ]; then
	grep -q "STATE=master" /home/${vhost}/state
	if [ $? -ne 0 ]; then
		exit 0
	fi
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
	if [ -d /etc/apache2 ]; then
		[ -f /etc/apache2/ssl/${vhost}.conf ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $SELF_SIGNED_DIR/${vhost}.pem~" /etc/apache2/ssl/${vhost}.conf
	fi
	if [ -d /etc/nginx ]; then
		[ -f /etc/nginx/ssl/${vhost}.conf ] && sed -i "s~^ssl_certificate[^_]*$~ssl_certificate $SELF_SIGNED_DIR/${vhost}.pem;~" /etc/nginx/ssl/${vhost}.conf
	fi
	exit 1
fi

which apache2ctl>/dev/null
if [ $? == 0 ]; then
	[ -f /etc/apache2/ssl/${vhost}.conf ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $CRT_DIR/${vhost}-fullchain.pem~" /etc/apache2/ssl/${vhost}.conf
	apache2ctl -t 2>/dev/null
        if [ $? == 0 ]; then
                service apache2 reload
        fi
fi
which nginx>/dev/null
if [ $? == 0 ]; then
	[ -f /etc/nginx/ssl/${vhost}.conf ] && sed -i "s~^ssl_certificate[^_].*$~ssl_certificate $CRT_DIR/${vhost}-fullchain.pem;~" /etc/nginx/ssl/${vhost}.conf
        nginx -t 2>/dev/null
        if [ $? == 0 ]; then
                service nginx reload
        fi
fi

which haproxy>/dev/null
if [ $? == 0 ]; then
	mkdir -p /etc/ssl/haproxy -m 700
	cat $CRT_DIR/${vhost}-fullchain.pem $SSL_KEY_DIR/${vhost}.key > /etc/ssl/haproxy/${vhost}.pem
	haproxy -c -f /etc/haproxy/haproxy.cfg 1>/dev/null
        if [ $? == 0 ]; then
                service haproxy reload
        fi
fi
exit 0
