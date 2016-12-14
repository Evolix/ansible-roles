#!/bin/bash

source /etc/default/evoacme

vhost=$1

if [ ! -f /etc/nginx/sites-enabled/$vhost ]; then
	if [ ! -f /etc/apache2/sites-enabled/${vhost}.conf ]; then
		echo "$vhost doesn't exist !"
		exit 1
	fi
fi

if [ -f $SSL_KEY_DIR/${vhost}.key ]; then
	read -p "$vhost key already exist, overwrite it ? (y)" -n 1 -r
	echo ""
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi

SSL_KEY_SIZE=$(grep default_bits /etc/letsencrypt/openssl.cnf|cut -d'=' -f2|xargs)
openssl genrsa -out $SSL_KEY_DIR/${vhost}.key $SSL_KEY_SIZE
chown root: $SSL_KEY_DIR/${vhost}.key
chmod 640 $SSL_KEY_DIR/${vhost}.key

nb=0

if [ -f /etc/nginx/sites-enabled/$vhost ]; then
	domains=`grep -oE "^( )*[^#]+" /etc/nginx/sites-enabled/$vhost|grep -oE "[^\$]server_name.*;$"|sed 's/server_name//'|tr -d ';'|sed 's/\s\{1,\}//'|sed 's/\s\{1,\}/\n/g'|sort|uniq`
fi

if [ -f /etc/apache2/sites-enabled/${vhost}.conf ]; then
	domains=`grep -oE "^( )*[^#]+" /etc/apache2/sites-enabled/${vhost}.conf|grep -oE "(ServerName|ServerAlias).*"|sed 's/ServerName//'|sed 's/ServerAlias//'|sed 's/\s\{1,\}//'|sort|uniq`
fi

echo "Domain(s) for $vhost :"
for domain in $domains
do
	# TODO : vérifier si domaine pointe sur localhost
	echo "- $domain"
	nb=$(( nb  + 1 ))
done

mkdir -p /etc/ssl/requests -m 755
chown root: /etc/ssl/requests

if [ $nb -eq 1 ]; then
    openssl req -new -sha256 -key $SSL_KEY_DIR/${vhost}.key -config <(cat /etc/letsencrypt/openssl.cnf <(printf "CN=$domain")) -out $CSR_DIR/${vhost}.csr
elif [ $nb -gt 1 ]; then
	san=''
	for domain in $domains
	do
	        san="$san,DNS:$domain"
	done
	san=`echo $san|sed 's/,//'`
    openssl req -new -sha256 -key $SSL_KEY_DIR/${vhost}.key -reqexts SAN -config <(cat /etc/letsencrypt/openssl.cnf <(printf "[SAN]\nsubjectAltName=$san")) > $CSR_DIR/${vhost}.csr
fi

if [ -f $CSR_DIR/${vhost}.csr ]; then
	chown root: $CSR_DIR/${vhost}.csr
	chmod 644 $CSR_DIR/${vhost}.csr
	if [ ! -f $CRT_DIR/${vhost}-fullchain.pem ]; then
		echo "Generate autosigned cert"
		openssl x509 -req -sha256 -days 365 -in $CSR_DIR/${vhost}.csr -signkey $SSL_KEY_DIR/${vhost}.key -out $CRT_DIR/${vhost}-fullchain.pem
	fi
fi
