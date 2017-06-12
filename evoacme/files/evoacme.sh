#!/bin/bash

[ -f /etc/default/evoacme ] && . /etc/default/evoacme
[ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR='/etc/ssl/private'
[ -z "${CRT_DIR}" ] && CRT_DIR='/etc/letsencrypt'
[ -z "${CSR_DIR}" ] && CSR_DIR='/etc/ssl/requests'
[ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR='/etc/ssl/self-signed'
[ -z "${DH_DIR}" ] && DH_DIR='/etc/ssl/dhparam'

vhost=$(basename $1 .conf)
DATE=$(date "+%Y%m%d")

SSL_EMAIL=$(grep emailAddress ${CRT_DIR}/openssl.cnf|cut -d'=' -f2|xargs)
if [ -n "$SSL_EMAIL" ]; then
    emailopt="--email $SSL_EMAIL"
else
    emailopt="--register-unsafely-without-email"
fi

# Check master status for evoadmin-cluster
if [ -f /home/${vhost}/state ]; then
	grep -q "STATE=master" /home/${vhost}/state
	[ $? -ne 0 ] && exit 0
fi

if [ -h $CRT_DIR/${vhost}/live ]; then
    crt_end_date=`openssl x509 -noout -enddate -in $CRT_DIR/${vhost}/live/cert.crt|sed -e "s/.*=//"`
    date_crt=`date -ud "$crt_end_date" +"%s"`
    date_today=`date +'%s'`
    date_diff=$(( ( $date_crt - $date_today ) / (60*60*24) ))
    [ $date_diff -ge $SSL_MINDAY ] && exit 0
fi

mkdir -pm 755 $CRT_DIR/${vhost} $CRT_DIR/${vhost}/${DATE}
chown -R acme: $CRT_DIR/${vhost}
sudo -u acme certbot certonly --quiet --webroot --csr $CSR_DIR/${vhost}.csr --webroot-path $ACME_DIR -n --agree-tos --cert-path=$CRT_DIR/${vhost}/${DATE}/cert.crt --fullchain-path=$CRT_DIR/${vhost}/${DATE}/fullchain.pem --chain-path=$CRT_DIR/${vhost}/${DATE}/chain.pem $emailopt --logs-dir $LOG_DIR 2> >(grep -v certbot.crypto_util)

if [ $? -eq 0 ]; then
	ln -sf $CRT_DIR/${vhost}/${DATE} $CRT_DIR/${vhost}/live	
	which apache2ctl>/dev/null
	if [ $? -eq 0 ]; then
		[ -f /etc/apache2/ssl/${vhost}.conf ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $CRT_DIR/${vhost}/live/fullchain.pem~" /etc/apache2/ssl/${vhost}.conf
		apache2ctl -t 2>/dev/null
	        [ $? -eq 0 ] && service apache2 reload
	fi
	which nginx>/dev/null
	if [ $? -eq 0 ]; then
		[ -f /etc/nginx/ssl/${vhost}.conf ] && sed -i "s~^ssl_certificate[^_].*$~ssl_certificate $CRT_DIR/${vhost}/live/fullchain.pem;~" /etc/nginx/ssl/${vhost}.conf
	        nginx -t 2>/dev/null
	        [ $? -eq 0 ] && service nginx reload
	fi
	
	which haproxy>/dev/null
	if [ $? -eq 0 ]; then
		mkdir -p /etc/ssl/haproxy -m 700
		cat $CRT_DIR/${vhost}/live/fullchain.pem $SSL_KEY_DIR/${vhost}.key > /etc/ssl/haproxy/${vhost}.pem
		[ -f $DH_DIR/${vhost} ] && cat $DH_DIR/${vhost} >> /etc/ssl/haproxy/${vhost}.pem
		haproxy -c -f /etc/haproxy/haproxy.cfg 1>/dev/null
	        [ $? -eq 0 ] && service haproxy reload
	fi
	exit 0
fi
