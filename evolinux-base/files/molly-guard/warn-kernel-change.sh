#!/bin/sh

# If not interactive, exit immediately if any untested command fails
set -o errexit
# If expansion is attempted on an unset variable or parameter, the shell prints an
# error message, and, if not interactive, exits with a non-zero status.
set -o nounset
# Enable trace mode if called with environment variable TRACE=1
if [ "${TRACE-0}" -eq "1" ]; then
    set -o xtrace
fi

NEEDRESTART_BIN=$(command -v needrestart)

if [ -n "${NEEDRESTART_BIN}" ]; then
    NEEDRESTART_OUT=$(${NEEDRESTART_BIN} -b 2> /dev/null | grep "NEEDRESTART-K")

    if [ -n "${NEEDRESTART_OUT}" ]; then
        KSTA=$(echo "${NEEDRESTART_OUT}" | grep NEEDRESTART-KSTA | cut -d ' ' -f 2)

        KCUR=$(echo "${NEEDRESTART_OUT}" | grep NEEDRESTART-KCUR | cut -d ' ' -f 2)
        KCUR_MAIN=$(echo "${KCUR}" | cut -d . -f1,2)

        KEXP=$(echo "${NEEDRESTART_OUT}" | grep NEEDRESTART-KEXP | cut -d ' ' -f 2)
        KEXP_MAIN=$(echo "${KEXP}" | cut -d . -f1,2)

        # https://github.com/liske/needrestart/blob/master/README.batch.md
        # The kernel status (NEEDRESTART-KSTA) value has the following meaning:
        #     0: unknown or failed to detect
        #     1: no pending upgrade
        #     2: ABI compatible upgrade pending
        #     3: version upgrade pending

        case "${KSTA}" in
            0)
                printf "E: needrestart: failed to detect kernel version\n"
                ;;
            1)
                :
                ;;
            2|3)
                if [ "${KCUR_MAIN}" = "${KEXP_MAIN}" ]; then
                    printf "W: needrestart: minor kernel change %s → %s\n" "${KCUR}" "${KEXP}"
                else
                    printf "W: needrestart: major kernel change %s → %s\n" "${KCUR}" "${KEXP}"
                fi
                ;;
            *)
                printf "E: needrestart: unknown kernel status (%s)\n" "${KSTA}"
                ;;
        esac
    fi
fi

exit 0
