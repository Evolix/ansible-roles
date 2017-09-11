#!/bin/sh
#
# evoacme is a shell script to manage Let's Encrypt certificate with
# certbot tool but with a dedicated user (no-root) and from a csr
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

mkconf_apache() {
        [ -f "/etc/apache2/ssl/${vhost}.conf" ] && sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $CRT_DIR/${vhost}/live/fullchain.pem~" "/etc/apache2/ssl/${vhost}.conf"
        apache2ctl -t 2>/dev/null && service apache2 reload
}

mkconf_nginx() {
        [ -f "/etc/nginx/ssl/${vhost}.conf" ] && sed -i "s~^ssl_certificate[^_].*$~ssl_certificate $CRT_DIR/${vhost}/live/fullchain.pem;~" "/etc/nginx/ssl/${vhost}.conf"
        nginx -t 2>/dev/null && service nginx reload
}

mkconf_haproxy() {
	mkdir -p /etc/ssl/haproxy -m 700
	cat "$CRT_DIR/${vhost}/live/fullchain.pem" "$SSL_KEY_DIR/${vhost}.key" > "/etc/ssl/haproxy/${vhost}.pem"
	[ -f "$DH_DIR/${vhost}.pem" ] && cat "$DH_DIR/${vhost}.pem" >> "/etc/ssl/haproxy/${vhost}.pem"
	haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null && service haproxy reload
}

main() {
	vhost=$(basename "$1" .conf)

	# Check master status for evoadmin-cluster
	if [ -f "/home/${vhost}/state" ]; then
		grep -q "STATE=master" "/home/${vhost}/state" || exit 0
	fi

	[ -f /etc/default/evoacme ] && . /etc/default/evoacme
	[ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR='/etc/ssl/private'
	[ -z "${CRT_DIR}" ] && CRT_DIR='/etc/letsencrypt'
	[ -z "${CSR_DIR}" ] && CSR_DIR='/etc/ssl/requests'
	[ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR='/etc/ssl/self-signed'
	[ -z "${DH_DIR}" ] && DH_DIR='/etc/ssl/dhparam'
	[ -z "${LOG_DIR}" ] && LOG_DIR='/var/log/evoacme'
	
	SSL_EMAIL=$(grep emailAddress "${CRT_DIR}/openssl.cnf"|cut -d'=' -f2|xargs)
	if [ -n "$SSL_EMAIL" ]; then
	    emailopt="-m $SSL_EMAIL"
	else
	    emailopt="--register-unsafely-without-email"
	fi
	DATE=$(date "+%Y%m%d")
	
	if [ -h "$CRT_DIR/${vhost}/live" ]; then
	    crt_end_date=$(openssl x509 -noout -enddate -in "$CRT_DIR/${vhost}/live/cert.crt"|sed -e "s/.*=//")
	    date_crt=$(date -ud "$crt_end_date" +"%s")
	    date_today=$(date +'%s')
	    date_diff=$(((date_crt - date_today) / (60*60*24)))
	    [ "$date_diff" -ge "$SSL_MINDAY" ] && exit 0
	fi
	rm -rf "$CRT_DIR/${vhost}/${DATE}"
	mkdir -pm 755 "$CRT_DIR/${vhost}/${DATE}"
	chown -R acme: "$CRT_DIR/${vhost}"
	sudo -u acme certbot certonly --quiet --webroot --csr "$CSR_DIR/${vhost}.csr" --webroot-path "$ACME_DIR" -n --agree-tos --cert-path="$CRT_DIR/${vhost}/${DATE}/cert.crt" --fullchain-path="$CRT_DIR/${vhost}/${DATE}/fullchain.pem" --chain-path="$CRT_DIR/${vhost}/${DATE}/chain.pem" "$emailopt" --logs-dir "$LOG_DIR" 2>&1 | grep -v "certbot.crypto_util"
	if [ -f "$CRT_DIR/${vhost}/${DATE}/fullchain.pem" ]; then
		rm -f "$CRT_DIR/${vhost}/live"
		ln -s "$CRT_DIR/${vhost}/${DATE}" "$CRT_DIR/${vhost}/live"
		which apache2ctl >/dev/null && mkconf_apache
		which nginx >/dev/null && mkconf_nginx
		which haproxy >/dev/null && mkconf_haproxy
	else
		rmdir "$CRT_DIR/${vhost}/${DATE}"
	fi
}

main "$@"
