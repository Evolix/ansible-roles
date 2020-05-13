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
main() {
    export GIT_DIR="/etc/.git"
    export GIT_WORK_TREE="/etc"

    if test -x "${git_bin}" && test -d "${GIT_DIR}" && test -d "${GIT_WORK_TREE}"; then
      changed_lines=$(${git_bin} status --porcelain | wc -l | tr -d ' ')

      if [ "${changed_lines}" != "0" ]; then
          debug "Committing for ${RENEWED_DOMAINS}"
          ${git_bin} add --all
          message="[letsencrypt] certificates renewal (${RENEWED_DOMAINS})"
          ${git_bin} commit --message "${message}" --quiet
      else
          error "Weird, nothing has changed but the hook has been executed for '${RENEWED_DOMAINS}'"
      fi
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly git_bin=$(command -v git)
readonly letsencrypt_dir=/etc/letsencrypt

main
