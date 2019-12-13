#!/bin/bash

set -e

DIR="/var/log/apache-status"
URL="http://127.0.0.1/server-status"
TS=`date +%Y%m%d%H%M%S`
FILE="${DIR}/${TS}.html"

if [ ! -d "${DIR}" ]; then
    mkdir -p "${DIR}"
    chown root:adm "${DIR}"
    chmod 750 "${DIR}"
fi

wget -q -U "save_apache_status" -O "${FILE}" "${URL}"
chmod 640 "${FILE}"
chown root:adm "${FILE}"

find "${DIR}" -type f -mtime +1 -delete

exit 0
