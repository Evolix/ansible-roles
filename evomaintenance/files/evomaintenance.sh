#!/bin/sh

# EvoMaintenance script
# Dependencies (all OS): git postgresql-client
# Dependencies (Debian): sudo

# version 0.4.0
# Copyright 2007-2018 Gregory Colpart <reg@evolix.fr>, Jérémy Lecour <jlecour@evolix.fr>, Evolix <info@evolix.fr>

get_system() {
  uname -s
}

get_fqdn() {
  if [ "$(get_system)" = "Linux" ]; then
    hostname --fqdn
  elif [ "$(get_system)" = "OpenBSD" ]; then
    hostname
  else
    echo "OS not detected!"
    exit 1
  fi
}

get_tty() {
  if [ "$(get_system)" = "Linux" ]; then
    ps -o tty= | tail -1
  elif [ "$(get_system)" = "OpenBSD" ]; then
    env | grep SSH_TTY | cut -d"/" -f3
  else
    echo "OS not detected!"
    exit 1
  fi
}

get_who() {
  who=$(LC_ALL=C who -m)

  if [ -n "${who}" ]; then
    echo "${who}"
  else
    LC_ALL=C who | grep $(get_tty) | tr -s ' '
  fi
}

get_begin_date() {
  echo "$(date "+%Y") $(echo $(get_who) | cut -d" " -f3,4,5)"
}

get_ip() {
  ip=$(echo $(get_who) | cut -d" " -f6 | sed -e "s/^(// ; s/)$//")
  [ -z "${ip}" ] && ip="unknown (no tty)"
  [ "${ip}" = ":0" ] && ip="localhost"

  echo "${ip}"
}

get_end_date() {
  date +"%Y %b %d %H:%M"
}

get_now() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

test -f /etc/evomaintenance.cf && . /etc/evomaintenance.cf

[ -n "${HOSTNAME}" ]     || HOSTNAME=$(get_fqdn)
[ -n "${EVOMAINTMAIL}" ] || EVOMAINTMAIL=evomaintenance-$(echo "${HOSTNAME}" | cut -d- -f1)@${REALM}
[ -n "${LOGFILE}" ]      || LOGFILE=/var/log/evomaintenance.log

# Treat unset variables as an error when substituting.
# Only after this line, because some config variables might be missing.
set -u

REAL_HOSTNAME=$(get_fqdn)
if [ "${HOSTNAME}" = "${REAL_HOSTNAME}" ]; then
    HOSTNAME_TEXT="${HOSTNAME}"
else
    HOSTNAME_TEXT="${HOSTNAME} (${REAL_HOSTNAME})"
fi

# TTY=$(get_tty)
# WHO=$(get_who)
IP=$(get_ip)
BEGIN_DATE=$(get_begin_date)
END_DATE=$(get_end_date)
USER=$(logname)

PATH=${PATH}:/usr/sbin

SENDMAIL_BIN=$(command -v sendmail)
GIT_BIN=$(command -v git)

GIT_REPOSITORIES="/etc /etc/bind"

# git statuses
GIT_STATUSES=""

if test -x "${GIT_BIN}"; then
    # loop on possible directories managed by GIT
    for dir in ${GIT_REPOSITORIES}; do
        # tell Git where to find the repository and the work tree (no need to `cd …` there)
        export GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}"
        # If the repository and the work tree exist, try to commit changes
        if test -d "${GIT_DIR}" && test -d "${GIT_WORK_TREE}"; then
            CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l | tr -d ' ')
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
echo "----------- $(get_now) ---------------" >> "${LOGFILE}"
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
            CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l | tr -d ' ')
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
