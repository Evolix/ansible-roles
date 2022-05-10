#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage : $0 example.com" >&2
    exit 1
fi

servername="$(cat /etc/hostname)"
domain="$(echo "$1"|xargs)"

if [ ! -f "/etc/ssl/private/dkim-${servername}.private" ]; then
    echo "Generate DKIM keys ..."
    opendkim-genkey -h sha256 -b 4096 -D /etc/ssl/private/ -r -d "${domain}" -s "dkim-${servername}"
    chown opendkim:opendkim "/etc/ssl/private/dkim-${servername}.private"
    chmod 640 "/etc/ssl/private/dkim-${servername}.private"
    mv "/etc/ssl/private/dkim-${servername}.txt" "/etc/ssl/certs/"
fi

grep -q "${domain}" /etc/opendkim/KeyTable
if [ "$?" -ne 0 ]; then
    echo "Add ${domain} to KeyTable ..."
    echo "dkim-${servername}._domainkey.${domain} ${domain}:dkim-${servername}:/etc/ssl/private/dkim-${servername}.private" >> /etc/opendkim/KeyTable
fi

grep -q "${domain}" /etc/opendkim/SigningTable
if [ "$?" -ne 0 ]; then
    echo "Add ${domain} to SigningTable ..."
    echo "*@${domain} dkim-${servername}._domainkey.${domain}" >> /etc/opendkim/SigningTable
fi

systemctl reload opendkim
if [ "$?" -eq 0 ]; then
    echo "OpenDKIM successfully reloaded"
    echo "Public key is in : /etc/ssl/certs/dkim-${servername}.txt"
    exit 0
else
    echo "An error has occurred while opendkim reload, please FIX configuration !" >&2
    exit 1
fi
