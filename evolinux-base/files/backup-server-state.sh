#!/bin/sh

PROGNAME="backup-server-state"

VERSION="21.10"
readonly VERSION

backup_dir=
rc=0

# base functions

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2021 Evolix <info@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>
                    and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
END
}
show_help() {
    cat <<END
${PROGNAME} is making backup copies of information related to the state of the server.

Usage: ${PROGNAME} --backup-dir=/path/to/backup/directory [OPTIONS]

Options
 -d, --backup-dir   path to the directory where the backup will be stored
     --etc          backup copy of /etc
     --no-etc       no backup copy of /etc (default)
     --dpkg         backup copy of /var/lib/dpkg
     --no-dpkg      no backup copy of /var/lib/dpkg (default)
 -v, --verbose      print details about backup steps
 -V, --version      print version and exit
 -h, --help         print this message and exit
END
}
debug() {
    if [ "${VERBOSE}" = "1" ]; then
        echo "$1"
    fi
}

create_backup_dir() {
    debug "Create ${backup_dir}"

    last_result=$(mkdir -p "${backup_dir}" && chmod -R 755 "${backup_dir}")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* mkdir/chmod OK"
    else
        debug "* mkdir/chmod ERROR :"
        debug "${last_result}"
        rc=10
    fi
}

backup_etc() {
    debug "Backup /etc"

    last_result=$(rsync -ah --itemize-changes --exclude=.git /etc "${backup_dir}/")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* rsync OK"
    else
        debug "* rsync ERROR :"
        debug "${last_result}"
        rc=10
    fi
}

backup_apt() {
    if [ -f /var/lib/apt/extended_states ]; then
        debug "Backup APT states"

        last_result=$(mkdir -p "${backup_dir}/var/lib/apt" && chmod -R 755 "${backup_dir}/var/lib/apt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* mkdir/chmod OK"
        else
            debug "* mkdir/chmod ERROR"
            debug "${last_result}"
            rc=10
        fi

        last_result=$(rsync -ah /var/lib/apt/extended_states "${backup_dir}/var/lib/apt/")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* rsync OK"
        else
            debug "* rsync ERROR :"
            debug "${last_result}"
            rc=10
        fi
    fi
}

backup_dpkg() {
    debug "Backup DPkg"

    last_result=$(mkdir -p "${backup_dir}/var/lib" && chmod -R 755 "${backup_dir}/var/lib")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* mkdir/chmod OK"
    else
        debug "* mkdir/chmod ERROR"
        debug "${last_result}"
        rc=10
    fi

    last_result=$(rsync -ah --itemize-changes /var/lib/dpkg "${backup_dir}/var/lib/")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* rsync OK"
    else
        debug "* rsync ERROR"
        debug "${last_result}"
        rc=10
    fi
}

backup_packages() {
    debug "Backup list of installed package"

    last_result=$(dpkg --get-selections "*" > "${backup_dir}/current_packages.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* dpkg OK"
    else
        debug "* dpkg ERROR :"
        debug "${last_result}"
        rc=10
    fi
}

backup_uptime() {
    debug "Backup uptime"

    last_result=$(uptime > "${backup_dir}/uptime.out")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* uptime OK"
    else
        debug "* uptime ERROR"
        debug "${last_result}"
        rc=10
    fi
}

backup_processes() {
    debug "Backup process list"

    last_result=$(ps fauxw > "${backup_dir}/ps.out")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* ps OK"
    else
        debug "* ps ERROR"
        debug "${last_result}"
        rc=10
    fi

    pstree_bin=$(command -v pstree)

    if [ -z "${pstree_bin}" ]; then
        last_result=$(pstree -pan > "${backup_dir}/pstree.out")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* pstree OK"
        else
            debug "* pstree ERROR"
            debug "${last_result}"
            rc=10
        fi
    fi
}

backup_netstat() {
    debug "Backup network status"

    ss_bin=$(command -v ss)
    if [ -z "${ss_bin}" ]; then
        last_result=$(${ss_bin} -tanpul > "${backup_dir}/listen.out")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* ss OK"
        else
            debug "* ss ERROR"
            debug "${last_result}"
            rc=10
        fi
    fi

    netstat_bin=$(command -v netstat)
    if [ -z "${netstat_bin}" ]; then
        last_result=$(netstat -laputen > "${backup_dir}/netstat.out")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* netstat OK"
        else
            debug "* netstat ERROR"
            debug "${last_result}"
            rc=10
        fi
    fi
}

backup_netcfg() {
    debug "Backup network configuration"

    last_result=$(ip address show > "${backup_dir}/ip-address.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* ip address OK"
    else
        debug "* ip address ERROR"
        debug "${last_result}"
        rc=10
    fi

    last_result=$(ip route show > "${backup_dir}/ip-route.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* ip route OK"
    else
        debug "* ip route ERROR"
        debug "${last_result}"
        rc=10
    fi
}

backup_iptables() {
    debug "Backup iptables"

    last_result=$({ /sbin/iptables -L -n -v; /sbin/iptables -t filter -L -n -v; } > "${backup_dir}/iptables.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* iptables OK"
    else
        debug "* iptables ERROR"
        debug "${last_result}"
        rc=10
    fi
}

backup_sysctl() {
    debug "Backup sysctl values"

    last_result=$(sysctl -a | sort -h > "${backup_dir}/sysctl.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* sysctl OK"
    else
        debug "* sysctl ERROR"
        debug "${last_result}"
        rc=10
    fi
}

main() {
    if [ -z "${backup_dir}" ]; then
        echo "ERROR: You must provide the --backup-dir argument" >&2
        exit 1
    fi

    if [ -d "${backup_dir}" ]; then
        echo "ERROR: The backup directory ${backup_dir} already exists. Delete it first." >&2
        exit 2
    else
        create_backup_dir
    fi

    if [ "${DO_ETC}" -eq 1 ]; then
        backup_etc
    fi
    if [ "${DO_DPKG}" -eq 1 ]; then
        backup_dpkg
    fi
    if [ "${DO_APT}" -eq 1 ]; then
        backup_apt
    fi
    if [ "${DO_PACKAGES}" -eq 1 ]; then
        backup_packages
    fi
    if [ "${DO_PROCESSES}" -eq 1 ]; then
        backup_processes
    fi
    if [ "${DO_UPTIME}" -eq 1 ]; then
        backup_uptime
    fi
    if [ "${DO_NETSTAT}" -eq 1 ]; then
        backup_netstat
    fi
    if [ "${DO_NETCFG}" -eq 1 ]; then
        backup_netcfg
    fi
    if [ "${DO_IPTABLES}" -eq 1 ]; then
        backup_iptables
    fi
    if [ "${DO_SYSCTL}" -eq 1 ]; then
        backup_sysctl
    fi

    debug "=> Your backup is available at ${backup_dir}"
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

        -d|--backup-dir)
            # with value separated by space
            if [ -n "$2" ]; then
                backup_dir=$2
                shift
            else
                printf 'ERROR: "-d|--backup-dir" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --backup-dir=?*)
            # with value speparated by =
            backup_dir=${1#*=}
            ;;
        --backup-dir=)
            # without value
            printf 'ERROR: "--backup-dir" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        --etc)
            DO_ETC=1
            ;;
        --no-etc)
            DO_ETC=0
            ;;

        --dpkg)
            DO_DPKG=1
            ;;
        --no-dpkg)
            DO_DPKG=0
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
: "${DO_ETC:=0}"
: "${DO_DPKG:=0}"
: "${DO_APT:=1}"
: "${DO_PACKAGES:=1}"
: "${DO_PROCESSES:=1}"
: "${DO_UPTIME:=1}"
: "${DO_NETSTAT:=1}"
: "${DO_NETCFG:=1}"
: "${DO_IPTABLES:=1}"
: "${DO_SYSCTL:=1}"

set -u

main