#!/bin/sh

VERSION="21.07.1"

show_version() {
    cat <<END
mysql-queries-killer version ${VERSION}

Copyright 2021-2021 Evolix <info@evolix.fr>,
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
Usage: mysql-queries-killer [--port <port>] --list [--time <time>]
  or   mysql-queries-killer [--port <port>] --kill [--time <time>]

Options
  --port        MySQL port (default: 3306)
  --time        query busy time, in seconds (default: 600)
  --list        list matching queries (default action)
  --kill        kill connexions related to matching queries
  --help        Print this message and exit
  --version     Print version and exit
END
}

kill_connexions() {
    cmd="${PTKILL_BIN} --host 127.0.0.1 --port ${port} --busy-time ${time} --kill --print"

    ${cmd}
}

list_queries() {
    cmd="${PTKILL_BIN} --host 127.0.0.1 --port ${port} --busy-time ${time} --print"

    ${cmd}
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
        --port)
            # with value separated by space
            if [ -n "$2" ]; then
                port=$2
                shift
            else
                printf 'ERROR: "--port" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --port=?*)
            # with value speparated by =
            port=${1#*=}
            ;;
        --port=)
            # without value
            printf 'ERROR: "--port" requires a non-empty option argument.\n' >&2
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
port=${port:-"3306"}

set -u
set -e

if [ -z "${port}" ]; then
    echo "You must provide an port name" >&2
    echo "" >&2
    show_usage >&2
    exit 1
fi

main

exit 0