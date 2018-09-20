#!/bin/sh

# EvoMaintenance script
# Dependencies (all OS): git postgresql-client
# Dependencies (Debian): sudo

# version 0.3
# Copyright 2007-2018 Gregory Colpart <reg@evolix.fr>, Jérémy Lecour <jlecour@evolix.fr>, Evolix <info@evolix.fr>

test -f /etc/evomaintenance.cf && . /etc/evomaintenance.cf

[ -n "${HOSTNAME}" ]     || HOSTNAME=$(hostname --fqdn)
[ -n "${EVOMAINTMAIL}" ] || EVOMAINTMAIL=evomaintenance-$(echo "${HOSTNAME}" | cut -d- -f1)@${REALM}
[ -n "${LOGFILE}" ]      || LOGFILE=/var/log/evomaintenance.log

# Treat unset variables as an error when substituting.
# Only after this line, because some config variables might be missing.
set -u

REAL_HOSTNAME=$(hostname --fqdn)
if [ "${HOSTNAME}" = "${REAL_HOSTNAME}" ]; then
    HOSTNAME_TEXT="${HOSTNAME}"
else
    HOSTNAME_TEXT="${HOSTNAME} (${REAL_HOSTNAME})"
fi

PATH=${PATH}:/usr/sbin

SENDMAIL_BIN=$(command -v sendmail)
GIT_BIN=$(command -v git)

GIT_REPOSITORIES="/etc /etc/bind"

WHO=$(LC_ALL=C who -m)
USER=$(echo ${WHO} | cut -d" " -f1)
IP=$(echo ${WHO} | cut -d" " -f6  | sed -e "s/^(// ; s/)$//")
BEGIN_DATE="$(date "+%Y") $(echo ${WHO} | cut -d" " -f3,4,5)"
END_DATE=$(date +"%Y %b %d %H:%M")
# we can't use "date --iso8601" because this options is not available everywhere
NOW_ISO=$(date +"%Y-%m-%dT%H:%M:%S%z")

# git statuses
GIT_STATUSES=""

if test -x "${GIT_BIN}"; then
    # loop on possible directories managed by GIT
    for dir in ${GIT_REPOSITORIES}; do
        # tell Git where to find the repository and the work tree (no need to `cd …` there)
        export GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}"
        # If the repository and the work tree exist, try to commit changes
        if test -d "${GIT_DIR}" && test -d "${GIT_WORK_TREE}"; then
            CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l)
            if [ "${CHANGED_LINES}" != "0" ]; then
              STATUS=$(${GIT_BIN} status --short | tail -n 10)
              # append diff data, without empty lines
              GIT_STATUSES=$(echo "${GIT_STATUSES}\n${GIT_DIR} (last 10 lines)\n${STATUS}\n" | sed -e '/^$/d')
            fi
        fi
        # unset environment variables to prevent accidental influence on other git commands
        unset GIT_DIR GIT_WORK_TREE
    done
    if [ -n "${GIT_STATUSES}" ]; then
      echo "/!\ There are some uncommited changes. If you proceed, everything will be commited."
      echo "${GIT_STATUSES}"
      echo ""
    fi
fi

# get input from stdin
echo "> Please, enter details about your maintenance"
read TEXTE

if [ "${TEXTE}" = "" ]; then
    echo "no value..."
    exit 1
fi

# recapitulatif
BLOB=$(cat <<END
Host      : $HOSTNAME_TEXT
User      : $USER
IP        : $IP
Begin     : $BEGIN_DATE
End       : $END_DATE
Message   : $TEXTE
END
)

echo ""
echo "${BLOB}"
echo ""
echo "> Press <Enter> to submit, or <Ctrl+c> to cancel."
read enter

# write log
echo "----------- ${NOW_ISO} ---------------" >> "${LOGFILE}"
echo "${BLOB}" >> "${LOGFILE}"

# git commit
GIT_COMMITS=""

if test -x "${GIT_BIN}"; then
    # loop on possible directories managed by GIT
    for dir in ${GIT_REPOSITORIES}; do
        # tell Git where to find the repository and the work tree (no need to `cd …` there)
        export GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}"
        # If the repository and the work tree exist, try to commit changes
        if test -d "${GIT_DIR}" && test -d "${GIT_WORK_TREE}"; then
            CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l)
            if [ "${CHANGED_LINES}" != "0" ]; then
              ${GIT_BIN} add --all
              ${GIT_BIN} commit --message "${TEXTE}" --author="${USER} <${USER}@evolix.net>" --quiet
              # Add the SHA to the log file if something has been committed
              SHA=$(${GIT_BIN} rev-parse --short HEAD)
              STATS=$(${GIT_BIN} show --stat | tail -1)
              # append commit data, without empty lines
              GIT_COMMITS=$(echo "${GIT_COMMITS}\n${GIT_DIR} : ${SHA} –${STATS}" | sed -e '/^$/d')
            fi
        fi
        # unset environment variables to prevent accidental influence on other git commands
        unset GIT_DIR GIT_WORK_TREE
    done
    if [ -n "${GIT_COMMITS}" ]; then
      echo "${GIT_COMMITS}" >> "${LOGFILE}"
    fi
fi

# insert into PG
# SQL_TEXTE=`echo "${TEXTE}" | sed "s/'/\\\\\\'/g ; s@/@\\\\\/@g ; s@\\&@et@g"`
SQL_TEXTE=`echo "${TEXTE}" | sed "s/'/''/g"`

PG_QUERY="INSERT INTO evomaint(hostname,userid,ipaddress,begin_date,end_date,details) VALUES ('${HOSTNAME}','${USER}','${IP}','${BEGIN_DATE}',now(),'${SQL_TEXTE}')"
echo "${PG_QUERY}" | psql ${PGDB} ${PGTABLE} -h ${PGHOST} --quiet

# send mail
MAIL_TEXTE=$(echo "${TEXTE}" | sed -e "s@/@\\\\\/@g ; s@&@\\\\&@")
MAIL_GIT_COMMITS=$(echo "${GIT_COMMITS}" | sed -e "s@/@\\\\\/@g ; s@&@\\\\&@")

cat /usr/share/scripts/evomaintenance.tpl | \
    sed -e "s/__TO__/${EVOMAINTMAIL}/ ; s/__HOSTNAME__/${HOSTNAME_TEXT}/ ; s/__USER__/${USER}/ ; s/__BEGIN_DATE__/${BEGIN_DATE}/ ; s/__END_DATE__/${END_DATE}/ ; s/__GIT_COMMITS__/${MAIL_GIT_COMMITS}/ ; s/__TEXTE__/${MAIL_TEXTE}/ ; s/__IP__/${IP}/ ; s/__FULLFROM__/${FULLFROM}/ ; s/__FROM__/${FROM}/ ; s/__URGENCYFROM__/${URGENCYFROM}/ ; s/__URGENCYTEL__/${URGENCYTEL}/" | \
    ${SENDMAIL_BIN} -oi -t -f ${FROM}

exit 0
