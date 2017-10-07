#!/bin/bash

set -e

DIR="/var/log/apache-status"
URL="http://127.0.0.1/server-status"
TS=`date +%Y%m%d%H%M%S`
FILE="${DIR}/${TS}.html"

mkdir -p "${DIR}"

wget -q -O "${FILE}" "${URL}"

chmod 640 "${FILE}"

find "${DIR}" -type f -mtime +1 -delete

exit 0
