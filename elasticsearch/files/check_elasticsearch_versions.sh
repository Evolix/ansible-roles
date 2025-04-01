#!/bin/bash

#####
# This script will send an email if all nodes of the Elasticsearch cluster
# don't have the same version
#####

readonly VERSION="25.04"

# set all programs to C language (english)
export LC_ALL=C

# If expansion is attempted on an unset variable or parameter, the shell prints an
# error message, and, if not interactive, exits with a non-zero status.
set -o nounset
# The pipeline's return status is the value of the last (rightmost) command
# to exit with a non-zero status, or zero if all commands exit successfully.
set -o pipefail
# Enable trace mode if called with environment variable TRACE=1
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# shellcheck disable=SC2155
readonly PROGPATH=$(readlink -m "${0}")
# readonly PROGNAME=$(basename "${PROGPATH}")
# # shellcheck disable=SC2124
# readonly ARGS=$@

# Fetch values from evomaintenance configuration
get_evomaintenance_mail() {
    grep "EVOMAINTMAIL=" /etc/evomaintenance.cf | cut -d '=' -f2
}
get_fqdn() {
    hostname --fqdn
}
get_complete_hostname() {
    REAL_HOSTNAME="$(get_fqdn)"
    if [ "${HOSTNAME}" = "${REAL_HOSTNAME}" ]; then
        echo "${HOSTNAME}"
    else
        echo "${HOSTNAME} (${REAL_HOSTNAME})"
    fi
}

format_mail() {
    cat <<EOTEMPLATE
From: Evolix <${EMAIL_FROM}>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: ${PROGPATH}
X-Script-Version: ${VERSION}
To: ${EMAIL_CLIENT:-alert5@evolix.fr}
Subject: Versions Elasticsearch hétérogènes

Bonjour,

Votre cluster Elasticsearch a des versions hétérogènes :

$(cat "${versions_file}")

Pour que nous puissions aligner ces versions vous devez
nous contacter explicitement, de préférence par ticket,
en mentionnant le serveur concerné, ainsi que les modalités
de mise à jour (créneau horaire…).

Cordialement

--
Evolix
EOTEMPLATE
}

main() {
    versions_file=$(mktemp --tmpdir=/tmp elasticsearch_versions.XXXXXX)

    # shellcheck disable=SC2064
    trap "rm -f ${versions_file}" 0

    check_command=$(grep --extended-regexp "^\s*command\[check_elasticsearch\]" /etc/nagios/nrpe.d/evolix.cfg | grep --extended-regexp --only-matching "check_http .+")
   
    if [ -z "${check_command}" ]; then
        >&2 echo "ERROR: Can't find an Elasticsearch check"
        exit 1
    fi

    host=$(echo "${check_command}" | grep --extended-regexp --only-matching -- "-I\s+\S+" | sed -e "s/-I\s\+//" | tr -d "'\"")
    port=$(echo "${check_command}" | grep --extended-regexp --only-matching -- "-p\s+\S+" | sed -e "s/-p\s\+//" | tr -d "'\"")
    auth=$(echo "${check_command}" | grep --extended-regexp --only-matching -- "-a\s+\S+" | sed -e "s/-a\s\+//" | tr -d "'\"")
    ssl=$(echo "${check_command}" | grep --extended-regexp --only-matching -- "--ssl")

    declare -a curl_options
    curl_options=()

    if [ -n "${ssl}" ]; then
        curl_scheme="https:"
        curl_options+=(--insecure)
    else
        curl_scheme="http:"
    fi
    if [ -n "${auth}" ]; then
        curl_options+=(-u "${auth}")
    fi

    curl --silent "${curl_scheme}//${host}:${port}/_cat/nodes?h=name,v" ${curl_options[*]} -o "${versions_file}"
    rc=$?

    if [ ${rc} -ne 0 ]; then
        >&2 echo "ERROR: Can't fetch Elasticsearch nodes versions"
        exit 1
    fi

    lines=$(awk '{print $2}' "${versions_file}" | sort -u | wc -l | awk '{print $1}')

    if [ ${lines} -gt 1 ]; then
        HOSTNAME="$(get_fqdn)"
        HOSTNAME_TEXT="$(get_complete_hostname)"
        EMAIL_CLIENT="$(get_evomaintenance_mail)"
        EMAIL_FROM="equipe@evolix.fr"
        MAIL_CONTENT="$(format_mail)"

        SENDMAIL_BIN="$(command -v sendmail)"

        if [ -z "${SENDMAIL_BIN}" ]; then
            >&2 echo "ERROR: No \`sendmail' command has been found, can't send mail."
            exit 1
        fi
        if [ ! -x "${SENDMAIL_BIN}" ]; then
            >&2 echo "ERROR: \`${SENDMAIL_BIN}' is not executable, can't send mail."
            exit 1
        fi

        echo "${MAIL_CONTENT}" | "${SENDMAIL_BIN}" -oi -t -f "equipe@evolix.fr"
    fi
    exit 0
}

main
