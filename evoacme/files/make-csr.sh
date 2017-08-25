#!/bin/sh
#
# make-csr is a shell script designed to automatically generate a 
# certificate signing request (CSR) from an Apache or a Nginx vhost
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

get_domains() {
	echo "$vhostfile"|grep -q nginx
	if [ "$?" -eq 0 ]; then
		domains=$(grep -oE "^( )*[^#]+" "$vhostfile" |grep -oE "[^\$]server_name.*;$"|sed 's/server_name//'|tr -d ';'|sed 's/\s\{1,\}//'|sed 's/\s\{1,\}/\n/g'|sort|uniq)
	fi
	
	echo "$vhostfile" |grep -q apache2
	if [ "$?" -eq 0 ]; then
		domains=$(grep -oE "^( )*[^#]+" "$vhostfile" |grep -oE "(ServerName|ServerAlias).*"|sed 's/ServerName//'|sed 's/ServerAlias//'|sed 's/\s\{1,\}//'|sort|uniq)
	fi
	valid_domains=""
	nb=0
	
	echo "Valid Domain(s) for $vhost :"
	for domain in $domains
	do
		real_ip=$(dig +short "$domain"|grep -oE "([0-9]+\.){3}[0-9]+")
		for ip in $(echo "$SRV_IP"|xargs -n1); do
			if [ "${ip}" = "${real_ip}" ]; then
	                        valid_domains="$valid_domains $domain"
		                nb=$(( nb  + 1 ))
				echo "* $domain"
			fi
		done
	done
	
	if [ "$nb" -eq 0 ]; then
	        nb=$(echo "$domains"|wc -l)
		echo "No valid domains : $domains" >&2
		domains="$domains"
	else
		domains="$valid_domains"
	fi
	domains=$(echo "$domains"|xargs -n1)
}

make_key() {
	openssl genrsa -out "$SSL_KEY_DIR/${vhost}.key" "$SSL_KEY_SIZE" 2>/dev/null
	chown root: "$SSL_KEY_DIR/${vhost}.key"
	chmod 600 "$SSL_KEY_DIR/${vhost}.key"
}

make_csr() {
	domains="$1"
	nb=$(echo "$domains"|wc -l)
	config_file="/tmp/make-csr-${vhost}.conf"

	mkdir -p "$CSR_DIR" -m 0755
	
	if [ "$nb" -eq 1 ]; then
		cat /etc/letsencrypt/openssl.cnf - > "$config_file" <<EOF
CN=$domains
EOF
		openssl req -new -sha256 -key "$SSL_KEY_DIR/${vhost}.key" -config "$config_file" -out "$CSR_DIR/${vhost}.csr"
	elif [ "$nb" -gt 1 ]; then
		san=''
		for domain in $domains
		do
		        san="$san,DNS:$domain"
		done
		san=$(echo "$san"|sed 's/,//')
		cat /etc/letsencrypt/openssl.cnf - > "$config_file" <<EOF
[SAN]
subjectAltName=$san
EOF
		openssl req -new -sha256 -key "$SSL_KEY_DIR/${vhost}.key" -reqexts SAN -config "$config_file" > "$CSR_DIR/${vhost}.csr"
	fi
	
	if [ -f "$CSR_DIR/${vhost}.csr" ]; then
		chmod 644 "$CSR_DIR/${vhost}.csr"
		mkdir -p "$SELF_SIGNED_DIR" -m 0755
		openssl x509 -req -sha256 -days 365 -in "$CSR_DIR/${vhost}.csr" -signkey "$SSL_KEY_DIR/${vhost}.key" -out "$SELF_SIGNED_DIR/${vhost}.pem"
		[ -f "$SELF_SIGNED_DIR/${vhost}.pem" ] && chmod 644 "$SELF_SIGNED_DIR/${vhost}.pem"
	fi
}

mkconf_apache() {
	mkdir -p /etc/apache2/ssl
	if [ ! -f "/etc/apache2/ssl/${vhost}.conf" ]; then
		cat > "/etc/apache2/ssl/${vhost}.conf" <<EOF
SSLEngine On
SSLCertificateFile    $SELF_SIGNED_DIR/${vhost}.pem
SSLCertificateKeyFile $SSL_KEY_DIR/${vhost}.key
EOF
	else
		sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile $SELF_SIGNED_DIR/${vhost}.pem~" "/etc/apache2/ssl/${vhost}.conf"
	fi
}

mkconf_nginx() {
	mkdir -p /etc/nginx/ssl
	if [ ! -f "/etc/nginx/ssl/${vhost}.conf" ]; then
		"cat > /etc/nginx/ssl/${vhost}.conf" <<EOF
ssl_certificate $SELF_SIGNED_DIR/${vhost}.pem;
ssl_certificate_key $SSL_KEY_DIR/${vhost}.key;
EOF
	else
		sed -i "s~^ssl_certificate[^_].*$~ssl_certificate $SELF_SIGNED_DIR/${vhost}.pem;~" "/etc/nginx/ssl/${vhost}.conf"
	fi
}

main() {
	if [ "$#" -ne 1 ]; then
		echo "You need to provide one argument !" >&2
		exit 1
	fi
	vhost=$(basename "$1" .conf)
	local_ip=$(ip a|grep brd|cut -d'/' -f1|grep -oE "([0-9]+\.){3}[0-9]+")

	[ -f /etc/default/evoacme ] && . /etc/default/evoacme
	[ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR='/etc/ssl/private'
	[ -z "${CSR_DIR}" ] && CSR_DIR='/etc/ssl/requests'
	[ -z "${CRT_DIR}" ] && CRT_DIR='/etc/letsencrypt'
	[ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR='/etc/ssl/self-signed'
	SSL_KEY_SIZE=$(grep default_bits /etc/letsencrypt/openssl.cnf|cut -d'=' -f2|xargs)
	[ -n "${SRV_IP}" ] && SRV_IP="${SRV_IP} local_ip" || SRV_IP="$local_ip"
	
	vhostfile=$(ls "/etc/nginx/sites-enabled/${vhost}" "/etc/nginx/sites-enabled/${vhost}.conf" "/etc/apache2/sites-enabled/${vhost}" "/etc/apache2/sites-enabled/${vhost}.conf" 2>/dev/null|head -n1)
	
	if [ ! -h "$vhostfile" ]; then
		echo "$vhost is not a valid virtualhost !" >&2
		exit 1
	fi

	if [ -f "$SSL_KEY_DIR/${vhost}.key" ]; then
		echo "$vhost key already exist, overwrite it ? (y)"
		read REPLY
		[ "$REPLY" = "Y" ] || [ "$REPLY" = "y" ] || exit 0
		rm -f "/etc/apache2/ssl/${vhost}.conf /etc/nginx/ssl/${vhost}.conf"
		[ -h "${CRT_DIR}/${vhost}/live" ] && rm "${CRT_DIR}/${vhost}/live"
	fi

	get_domains
	make_key
	make_csr "$domains"
	which apache2ctl >/dev/null && mkconf_apache
        which nginx >/dev/null && mkconf_nginx
}

main "$@"
