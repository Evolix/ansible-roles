#!/bin/sh

set -u

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
found_renewed_lineage() {
    test -f "${RENEWED_LINEAGE}/fullchain.pem" && test -f "${RENEWED_LINEAGE}/privkey.pem"
}
main() {
    if [ -z "${RENEWED_LINEAGE:-}" ]; then
        error "Missing RENEWED_LINEAGE environment variable (usually provided by certbot)."
    fi
    if [ "${VERBOSE}" = "1" ]; then
        xargs_verbose="--verbose"
    else
        xargs_verbose=""
    fi
    if found_renewed_lineage; then
        find "${hooks_dir}" -mindepth 1 -maxdepth 1 -type f -executable -print0 | sort --zero-terminated --dictionary-order | xargs ${xargs_verbose} --no-run-if-empty --null --max-args=1 sh -c
    else
        error "Couldn't find required files in \`${RENEWED_LINEAGE}'"
    fi
    
}

PROGNAME=$(basename "$0")
VERBOSE=${VERBOSE:-"0"}
QUIET=${QUIET:-"0"}

hooks_dir="/etc/letsencrypt/renewal-hooks/deploy"

main