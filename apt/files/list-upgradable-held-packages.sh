#!/bin/bash

#####
# This script will send an email if some packages are on hold
# but have available updates.
#####

readonly VERSION="24.05"

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
Subject: Mise a jour manuelle disponible

Bonjour,

Un ou plusieurs paquets dont la mise à jour automatique a été
explicitement bloquée ont une nouvelle version disponible.

Nom du serveur :
${HOSTNAME_TEXT}

Liste des paquets :
${upgradable_held_packages}

Pour que nous appliquions ces mises à jour vous devez
nous contacter explicitement, de préférence par ticket,
en mentionnant le serveur et les paquets concernés,
ainsi que les modalités de mise à jour (créneau horaire,
procédure technique…).

Cordialement

--
Evolix
EOTEMPLATE
}

main() {
    held_packages=$(apt-mark showhold)
    upgradable_packages=$(apt list --upgradable 2> /dev/null)

    if [ -z "${held_packages}" ]; then
        # No packages are on hold
        exit 0
    elif [ -z "${upgradable_packages}" ]; then
        # No packages are upgradable
        exit 0
    fi

    kept_back_output=$(LC_ALL=C apt-get upgrade --dry-run | grep -A 1 'The following packages have been kept back:')
    if [ -z "${kept_back_output}" ]; then
        # No packages are kept back
        exit 0
    fi

    upgradable_held_packages=$(apt list --upgradable 2> /dev/null | grep -f <(echo "${kept_back_output}" | tail -1 | tr ' ' '\n' | sed -e '/^$/d'))

    if [ -z "${upgradable_held_packages}" ]; then
        # No held packages are upgradable
        exit 0
    fi

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
    exit 0
}

main
