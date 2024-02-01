#!/bin/bash
#
# Shortcut to show certificate content or enddate.
#

usage() {
    echo "Usage : cert [date] <CERT_PATH>"
}

if [ "$#" -eq 1 ]; then
    cert_path=$1
    if [ -f "${cert_path}" ]; then
        openssl x509 -noout -in "${cert_path}" -text
    else
        >&2 echo "Error, file ${cert_path} does not exist."
    fi

elif [ "$#" -eq 2 ]; then
    if [ "$1" = "date" ]; then
        cert_path=$2
        if [ -f "${cert_path}" ]; then
            openssl x509 -noout -in "$cert_path" -enddate
        else
            >&2 echo "Error, file ${cert_path} does not exist."
        fi
    else
        >&2 echo "Error, two arguments provided but 'date' is only allowed as first."
        usage
        exit 1
    fi

else
    >&2 echo "Error, more than two arguments provided."
    usage
    exit 1
fi
