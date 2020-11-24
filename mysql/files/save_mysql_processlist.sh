#!/bin/sh

set -e

processlist() {
    mysqladmin --verbose --vertical processlist
}

DIR="/var/log/mysql-processlist"
TS=`date +%Y%m%d%H%M%S`
FILE="${DIR}/${TS}"

if [ ! -d "${DIR}" ]; then
    mkdir -p "${DIR}"
    chown root:adm "${DIR}"
    chmod 750 "${DIR}"
fi

processlist > "${FILE}"
chmod 640 "${FILE}"
chown root:adm "${FILE}"

find "${DIR}" -type f -mtime +1 -delete

exit 0
