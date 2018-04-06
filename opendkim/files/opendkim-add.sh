#!/bin/sh


dpkg -l |grep -e 'opendkim-tools' -e 'opendkim' -q

if [ "$?" -ne 0 ]; then 
    echo "Require opendkim-tools and opendkim"
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage : $0 example.com" >&2
    exit 1
fi

domain="$(echo "$1"|xargs)"

mkdir -pm 0750 "/etc/opendkim/keys/${domain}"
chown opendkim:opendkim "/etc/opendkim/keys/${domain}"

if [ ! -f "/etc/opendkim/keys/${domain}/default.private" ]; then
    cd "/etc/opendkim/keys/${domain}"
    echo "Generate DKIM keys ..."
    sudo -u opendkim opendkim-genkey -r -d "${domain}"
    chmod 640 /etc/opendkim/keys/${domain}/*
fi

grep -q "${domain}" /etc/opendkim/TrustedHosts
if [ "$?" -ne 0 ]; then
    echo "Add ${domain} to TrustedHosts ..."
    echo "${domain}" >> /etc/opendkim/TrustedHosts
fi

grep -q "${domain}" /etc/opendkim/KeyTable
if [ "$?" -ne 0 ]; then
    echo "Add ${domain} to KeyTable ..."
    echo "default._domainkey.${domain} ${domain}:default:/etc/opendkim/keys/${domain}/default.private" >> /etc/opendkim/KeyTable
fi

grep -q "${domain}" /etc/opendkim/SigningTable
if [ "$?" -ne 0 ]; then
    echo "Add ${domain} to SigningTable ..."
    echo "*@${domain} default._domainkey.${domain}" >> /etc/opendkim/SigningTable
fi

systemctl reload opendkim
if [ "$?" -eq 0 ]; then
    echo "OpenDKIM successfully reloaded"
    echo "Public key is in : /etc/opendkim/keys/${domain}/default.txt"
    exit 0
else
    echo "An error has occurred while opendkim reload, please FIX configuration !" >&2
    exit 1
fi
