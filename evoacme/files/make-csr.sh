#!/bin/bash

if [ -f /etc/default/evoacme ]; then
	source /etc/default/evoacme
fi
[ -z "${SSL_KEY_DIR}" ] && SSL_KEY_DIR='/etc/ssl/private'
[ -z "${CSR_DIR}" ] && CSR_DIR='/etc/ssl/requests'
[ -z "${SELF_SIGNED_DIR}" ] && SELF_SIGNED_DIR='/etc/ssl/self-signed'

shopt -s extglob

vhost=$1
vhostfiles=$(ls -1 /etc/{nginx,apache2}/sites-enabled/${vhost}?(.conf) 2>/dev/null)

if [ $(echo "${vhostfiles}"|wc -l) -lt 1 ]; then
	echo "$vhost doesn't exist !"
	exit 1
fi

for vhostfile in "${vhostfiles}"; do
	break;
done

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
chmod 600 $SSL_KEY_DIR/${vhost}.key

nb=0

echo $vhostfile |grep -q nginx
if [ $? -eq 0 ]; then
	domains=`grep -oE "^( )*[^#]+" $vhostfile |grep -oE "[^\$]server_name.*;$"|sed 's/server_name//'|tr -d ';'|sed 's/\s\{1,\}//'|sed 's/\s\{1,\}/\n/g'|sort|uniq`
fi

echo $vhostfile |grep -q apache2
if [ $? -eq 0 ]; then
	domains=`grep -oE "^( )*[^#]+" $vhostfile |grep -oE "(ServerName|ServerAlias).*"|sed 's/ServerName//'|sed 's/ServerAlias//'|sed 's/\s\{1,\}//'|sort|uniq`
fi

valid_domains=''
srv_ip=$(ip a|grep brd|cut -d'/' -f1|grep -oE "([0-9]+\.){3}[0-9]+")

echo "Valid Domain(s) for $vhost :"
for domain in $domains
do
	real_ip=$(dig +short $domain|grep -oE "([0-9]+\.){3}[0-9]+")
	for ip in $(echo $srv_ip|xargs -n1); do
		if [ "${ip}" == "${real_ip}" ]; then
                        valid_domains="$valid_domains $domain"
	                nb=$(( nb  + 1 ))
			echo "- $domain"
		fi
	done
done

if [ $nb -eq 0 ]; then
        nb=`echo $domains|wc -l`
	echo "No valid domains : $domains" >&2
	exit 1
else
        domains=$valid_domains
fi

mkdir -p $CSR_DIR -m 0755

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
	chmod 644 $CSR_DIR/${vhost}.csr
	mkdir -p $SELF_SIGNED_DIR -m 0755
	openssl x509 -req -sha256 -days 365 -in $CSR_DIR/${vhost}.csr -signkey $SSL_KEY_DIR/${vhost}.key -out $SELF_SIGNED_DIR/${vhost}.pem
	if [ -f $SELF_SIGNED_DIR/${vhost}.pem ]; then
		chmod 644 $SELF_SIGNED_DIR/${vhost}.pem
	fi
fi
