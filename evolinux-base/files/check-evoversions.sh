#!/bin/bash

PROGNAME="check-evoversions"
# REPOSITORY="https://gitea.evolix.org/evolix/dump-server-state"

VERSION="23.07-pre"
readonly VERSION


# base functions

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2023 Evolix <info@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>.

${REPOSITORY}

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
END
}
show_help() {
    cat <<END
${PROGNAME} is checking versions of software managed by Evolix

Usage: ${PROGNAME} [OPTIONS]

Main options
 -v, --verbose         print details about each task
 -V, --version         print version and exit
 -h, --help            print this message and exit
END
}

debug() {
    if [ "${VERBOSE}" = "1" ]; then
        msg="${1:-$(cat /dev/stdin)}"
        echo "${msg}"
    fi
}
add_to_temp_files() {
    TEMP_FILES+=("${1}")
}
# Remove all temporary file created during the execution
clean_temp_files() {
    # shellcheck disable=SC2086
    rm -f "${TEMP_FILES[@]}"
}

detect_os() {
    if [ -e /etc/debian_version ]; then
        version=$(cut -d "." -f 1 < /etc/debian_version)
        return "debian${version}"
    elif uname | grep -q -i 'openbsd'; then
        return "openbsd"
    else
        echo "Unknown/unsupported OS: $(uname -a)" >&2
        exit 1
    fi
}

main() {

    # Initialize a list of temporary files
    declare -a TEMP_FILES=()
    # Any file in this list will be deleted when the program exits
    trap "clean_temp_files" EXIT

    os_release=$(detect_os)

    versions_file=$(mktemp --tmpdir "evocheck.versions.XXXXX")
    add_to_temp_files "${versions_file}"

    download_versions "${versions_file}"
    add_to_path "/usr/share/scripts"

    grep -v '^ *#' < "${versions_file}" | while IFS= read -r line; do
        local program
        local version
        program=$(echo "${line}" | cut -d ' ' -f 1)
        version=$(echo "${line}" | cut -d ' ' -f 2)

        if [ -n "${program}" ]; then
            if [ -n "${version}" ]; then
                check_version "${program}" "${version}"
            else
                failed "IS_CHECK_VERSIONS" "failed to lookup expected version for ${program}"
            fi
        fi
    done

    exit ${rc}
}

# parse options
# based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0
            ;;
        -V|--version)
            show_version
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;

        --)
            # End of all options.
            shift
            break
            ;;
        -?*)
            # ignore unknown options
            printf 'WARN: Unknown option : %s\n' "$1" >&2
            exit 1
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# Default values
: "${VERBOSE:=0}"

export LC_ALL=C

set -u

main
