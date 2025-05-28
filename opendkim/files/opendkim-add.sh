#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage : $0 example.com" >&2
    exit 1
fi

servername="$(cat /etc/hostname)"
domain="$(echo "$1" | xargs)"
selector="dkim-${servername}"
dns_entry="${selector}._domainkey.${domain}"

genkey_output_dir="/etc/ssl/private"
private_key_file="${genkey_output_dir}/${selector}.private"
txt_file="${genkey_output_dir}/${selector}.txt"

key_table="/etc/opendkim/KeyTable"
signing_table="/etc/opendkim/SigningTable"

if [ ! -f "${private_key_file}" ]; then
    echo "Generate DKIM keys ..."
    opendkim-genkey -h sha256 -b 4096 -D "${genkey_output_dir}" -r -d "${domain}" -s "${selector}"

    chown opendkim:opendkim "${private_key_file}"
    chmod 640 "${private_key_file}"
fi

if ! grep --quiet "${domain}" "${key_table}"; then
    echo "Add ${domain} to KeyTable ..."
    echo "${dns_entry} ${domain}:${selector}:${private_key_file}" >> "${key_table}"
fi

if ! grep --quiet "${domain}" "${signing_table}"; then
    echo "Add ${domain} to SigningTable ..."
    echo "*@${domain} ${dns_entry}" >> "${signing_table}"
fi

systemctl reload opendkim
if [ "$?" -eq 0 ]; then
    echo "OpenDKIM successfully reloaded"
    echo "Public key is in: ${txt_file}"
    exit 0
else
    echo "An error has occurred while opendkim reload, please FIX configuration!" >&2
    exit 1
fi
