#!/bin/sh

PROGNAME="dir-check"
REPOSITORY="https://gitea.evolix.org/evolix/ansible-roles"

VERSION="22.06.1"
readonly VERSION

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2022      Evolix <info@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>

${REPOSITORY}

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}
show_help() {
    cat <<EOF
Usage: ${PROGNAME} [ACTION] [OPTIONS] --dir /path/to/directory-to-check

Action
    --prepare        Create the metadata files
    --check          Checks the data against the metadata previously stored

Options
    -h|--help|-?     Display help
    -v|--verbose     Display more informatrion
    -q|--quiet       Do not display anything on stderr/stdout
    -V|--version     Display version, authors and license
EOF
}

log_date() {
    date +"%Y-%m-%d %H:%M:%S"
}
is_log_file() {
    test -n "${log_file}"
}
is_verbose() {
    test "${verbose}" = "1"
}
is_quiet() {
    test "${quiet}" = "1"
}
log_line() {
    level=$1
    msg=$2
    # printf "[%s] %s: %s\n" "$(log_date)" "${level}" "${msg}"
    printf "%s: %s\n" "${level}" "${msg}"
}
log_debug() {
    level="DEBUG"
    msg=$1
    if ! is_quiet && is_verbose; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_info() {
    level="INFO"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_warning() {
    level="WARNING"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_error() {
    level="ERROR"
    msg=$1
    if ! is_quiet; then
        if is_log_file; then
            log_line "${level}" "${msg}" >> "${log_file}"
            if tty -s; then
                printf "%s\n" "${msg}" >&2
            fi
        else
            log_line "${level}" "${msg}" >&2
        fi
    fi
}
log_fatal() {
    level="FATAL"
    msg=$1
    if is_log_file; then
        log_line "${level}" "${msg}" >> "${log_file}"
        if tty -s; then
            printf "%s\n" "${msg}" >&2
        fi
    else
        log_line "${level}" "${msg}" >&2
    fi
}

data_command() {
    echo "du --bytes"
}
list_files_with_size() {
    path=$1
    # shellcheck disable=SC2014,SC2046
    find "${path}" -type f -exec $(data_command) {} \; | sort -k2
}
prepare_data() {
    list_files_with_size "${final_dir}" > "${data_file}"
    "${checksum_bin}" "${data_file}" > "${checksum_file}"
}
check_data() {
    if [ -f "${checksum_file}" ]; then
        # subshell to scope the commands to "parent_dir"
        "${checksum_bin}" --status --check "${checksum_file}"
        last_rc=$?
        if [ ${last_rc} -eq 0 ]; then
            log_debug "Verification succeeded with checksum file \`${checksum_file}' (inside \`${parent_dir}')."
        else
            log_error "Verification failed with checksum file \`${checksum_file}' (inside \`${parent_dir}')."
            exit 1
        fi
    else
        log_warning "Couldn't find checksum file \`${checksum_file}' (inside \`${parent_dir}'). Skip verification."
    fi
    if [ -f "${data_file}" ]; then
        while read -r data_line; do
            expected_size=$(echo "${data_line}" | cut -f1)
            file=$(echo "${data_line}" | cut -f2)

            if [ -f "${file}"  ]; then
                actual_size=$($(data_command) "${file}" | cut -f1)

                if [ "${actual_size}" = "${expected_size}" ]; then
                    log_debug "File \`${file}' has a consistent size of ${actual_size}."
                else
                    log_error "File \`${file}' has an actual size of ${actual_size} instead of ${expected_size}."
                    rc=1
                fi
            else
                log_error "Couldn't find file \`${file}'."
                rc=1
            fi
        done < "${data_file}"
        if [ ${rc} -eq 0 ]; then
            log_info "Directory \`${final_dir}' is consistent with data stored in \`${data_file}' (inside \`${parent_dir}')."
        else
            log_error "Directory \`${final_dir}' is not consistent with data stored in \`${data_file}' (inside \`${parent_dir}')."
        fi
    else
        log_fatal "Couldn't find data file \`${data_file}' (inside \`${parent_dir}')."
        exit 1
    fi
}

main() {
    if [ -z "${dir}" ]; then
        log_fatal "dir option is empty"
        exit 1
    elif [ -e "${dir}" ] && [ ! -d "${dir}" ]; then
        log_fatal "Directory \`${dir}' exists but is not a directory"
        exit 1
    fi

    checksum_cmd="sha256sum"
    checksum_bin=$(command -v ${checksum_cmd})
    if [ -z "${checksum_bin}" ]; then
        log_fatal "Couldn't find \`${checksum_cmd}'.\nUse 'apt install ${checksum_cmd}'."
        exit 1
    fi

    parent_dir=$(dirname "${dir}")
    final_dir=$(basename "${dir}")

    data_file="${final_dir}.${PROGNAME}.db"
    checksum_file="${data_file}.${checksum_cmd}"

    cwd=${PWD}
    cd "${parent_dir}" || log_error "Impossible to change to \`${parent_dir}'"

    if [ -z "${action}" ]; then
        log_fatal "Missing --check or --prepare option."
        echo "" >&2
        show_help >&2
        exit 1
    fi

    case ${action} in
        check)
            check_data
            ;;
        prepare)
            prepare_data
            ;;
        *)
            log_fatal "Unknown action \`${action}'."
            rc=1
            ;;
    esac

    if [ -d "${cwd}" ]; then
        cd "${cwd}" || log_error "Impossible to change back to \`${cwd}'"
    else
        log_error "Previous working directory \`${cwd}' is not a directory."
    fi
}

# Declare variables

verbose=""
quiet=""
action=""
dir=""
rc=0

# Parse options
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

        -d|--dir)
            # with value separated by space
            if [ -n "$2" ]; then
                dir="$2"
                shift
            else
                log_fatal 'ERROR: "--dir" requires a non-empty option argument.'
            fi
            ;;
        --dir=?*)
            # with value speparated by =
            dir=${1#*=}
            ;;
        --dir=)
            # without value
            log_fatal '"--dir" requires a non-empty option argument.'
            ;;

        -l|--log)
            # with value separated by space
            if [ -n "$2" ]; then
                log_file="$2"
                shift
            else
                log_fatal 'ERROR: "--log" requires a non-empty option argument.'
            fi
            ;;
        --log=?*)
            # with value speparated by =
            log_file=${1#*=}
            ;;
        --log=)
            # without value
            log_fatal '"--log" requires a non-empty option argument.'
            ;;

        --prepare)
            action="prepare"
            ;;

        --check)
            action="check"
            ;;

        -v|--verbose)
            verbose=1
            ;;

        --quiet)
            quiet=1
            verbose=0
            ;;

        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            if tty -s; then
                printf 'Unknown option : %s\n' "$1" >&2
                echo "" >&2
                show_usage >&2
                exit 1
            else
                log_fatal "Unknown option : $1"
            fi
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# Default values

verbose=${verbose:-0}
quiet=${quiet:-0}
action=${action:-}
log_file=${log_file:-}

set  -u

main

exit ${rc}