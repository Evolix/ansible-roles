#!/bin/sh

set -eu

NEEDRESTART_BIN=$(command -v needrestart)

if [ -n "${NEEDRESTART_BIN}" ]; then
    NEEDRESTART_OUT=$(${NEEDRESTART_BIN} -b 2> /dev/null)

    if [ -n "${NEEDRESTART_OUT}" ]; then
        KCUR=$(echo "${NEEDRESTART_OUT}" | grep NEEDRESTART-KCUR | awk '{print $2}')
        KEXP=$(echo "${NEEDRESTART_OUT}" | grep NEEDRESTART-KEXP | awk '{print $2}')

        if [ "${KCUR}" != "${KEXP}" ]; then
            printf "\n"
            printf "W: Kernel change: %s → %s\n" "${KCUR}" "${KEXP}"
            printf "\n"
        fi
    fi
fi

exit 0
