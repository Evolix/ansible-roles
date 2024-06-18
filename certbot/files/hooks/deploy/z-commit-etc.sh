#!/bin/sh

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
domain_from_cert() {
    if [ -f "${RENEWED_LINEAGE}/fullchain.pem" ]; then
        openssl x509 -noout -subject -in "${RENEWED_LINEAGE}/fullchain.pem" | sed 's/^.*CN\ *=\ *//'
    else
        debug "Unable to find \`${RENEWED_LINEAGE}/fullchain.pem', skip domain detection."
    fi
}
main() {
    export GIT_DIR="/etc/.git"
    export GIT_WORK_TREE="/etc"

    if test -x "${git_bin}" && test -d "${GIT_DIR}" && test -d "${GIT_WORK_TREE}"; then
      changed_lines=$(${git_bin} status --porcelain -- letsencrypt | wc -l | tr -d ' ')

      if [ "${changed_lines}" != "0" ]; then
          if [ -z "${RENEWED_DOMAINS}" ] && [ -n "${RENEWED_LINEAGE}" ]; then
              RENEWED_DOMAINS=$(domain_from_cert)
          fi
          debug "Committing for ${RENEWED_DOMAINS}"
          ${git_bin} add letsencrypt
          message="[letsencrypt] certificates renewal (${RENEWED_DOMAINS})"
          ${git_bin} commit --message "${message}" --quiet --only letsencrypt
      else
          debug "Weird, nothing has changed in /etc/letsencrypt but the hook has been executed for '${RENEWED_DOMAINS}'"
      fi
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly git_bin=$(command -v git)

main
