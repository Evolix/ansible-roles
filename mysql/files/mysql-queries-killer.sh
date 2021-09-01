#!/bin/sh

VERSION="21.08"

show_version() {
    cat <<END
mysql-queries-killer version ${VERSION}

Copyright 2018-2021 Evolix <info@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>
               and others.

mysql-queries-killer comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

show_help() {
    cat <<END
mysql-queries-killer can list/kill SQL queries

END
    show_usage
}
show_usage() {
    cat <<END
Usage: mysql-queries-killer [--instance <instance>] --list [--time <time>]
  or   mysql-queries-killer [--instance <instance>] --kill [--time <time>]

Options
  --instance    MySQL instance name (see below)
  --time        query busy time, in seconds (default: 600)
  --list        list matching queries (default action)
  --kill        kill connexions related to matching queries
  --help        Print this message and exit
  --version     Print version and exit

If an instance parameter is provided, pt-kill will look for a configuration
file at ~/.pt-kill.<instance>.cnf
If no instance parameter is provided, pt-kill will use the conventional
configuration files.
END
}

error() {
    >&2 echo "mysql-queries-killer: $1"
    exit 
}

kill_connexions() {
    cmd="${PTKILL_BIN}"

    if [ -n "${config_file}" ]; then
        cmd="${cmd} --config ${config_file}"
    fi

    cmd="${cmd} --busy-time ${time} --run-time 1 --interval 1 --victims all --print --kill"

    ${cmd}
}

list_queries() {
    cmd="${PTKILL_BIN}"

    if [ -n "${config_file}" ]; then
        cmd="${cmd} --config ${config_file}"
    fi

    cmd="${cmd} --busy-time ${time} --run-time 1 --interval 1 --victims all --print"

    ${cmd}
}

set_config_file() {
    config_file=""

    if [ -n "${instance}" ]; then
        file="${HOME}/.pt-kill.${instance}.cnf"
        if [ ! -f "${file}" ]; then
            error "The config file \`${file}' doesn't exist." 2
        else
            config_file="${file}"
        fi
    fi
}

main() {
    case ${action} in
    kill)
        kill_connexions
        ;;
    list)
        list_queries
        ;;
    *)
        list_queries
        ;;
    esac
}

if command -v pt-kill >/dev/null; then
    PTKILL_BIN=$(command -v pt-kill)
else
    error "The command \`pt-kill' couldn't be found. It is available in the \`percona-toolkit' package." 1
fi

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
        --kill)
            action="kill"
            ;;
        --list)
            action="list"
            ;;
        --instance)
            # with value separated by space
            if [ -n "$2" ]; then
                instance=$2
                shift
            else
                printf 'ERROR: "--instance" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --instance=?*)
            # with value speparated by =
            instance=${1#*=}
            ;;
        --instance=)
            # without value
            printf 'ERROR: "--instance" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --time)
            # with value separated by space
            if [ -n "$2" ]; then
                time=$2
                shift
            else
                printf 'ERROR: "--time" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --time=?*)
            # with value speparated by =
            time=${1#*=}
            ;;
        --time=)
            # without value
            printf 'ERROR: "--time" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            printf 'ERROR: Unknown option : %s\n' "$1" >&2
            echo "" >&2
            show_usage >&2
            exit 1
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# Initial values
action=${action:-}
time=${time:-"600"}
instance=${instance:-""}

set_config_file

set -u
set -e

main

exit 0