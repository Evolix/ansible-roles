#!/bin/sh

PROGNAME="backup-server-state"

VERSION="22.01"
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
     --apt          backup copy of apt extended states (default)
     --no-apt       no backup copy of apt extended states
     --packages     backup copy of dpkg selections (default)
     --no-packages  no backup copy of dpkg selections
     --processes    backup copy of process list (default)
     --no-processes no backup copy of process list
     --uptime       backup of uptime value (default)
     --no-uptime    no backup of uptime value
     --netstat      backup copy of netstat (default)
     --no-netstat   no backup copy of netstat
     --netcfg       backup copy of network configuration (default)
     --no-netcfg    no backup copy of network configuration
     --iptables     backup copy of iptables (default)
     --no-iptables  no backup copy of iptables
     --sysctl       backup copy of sysctl values (default)
     --no-sysctl    no backup copy of sysctl values
     --virsh        backup copy of virsh list (default)
     --no-virsh     no backup copy of virsh list
     --lxc          backup copy of lxc list (default)
     --no-lxc       no backup copy of lxc list
     --mount        backup copy of mount points (default)
     --no-mount     no backup copy of mount points
     --df           backup copy of disk usage (default)
     --no-df        no backup copy of disk usage
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

    last_result=$(uptime > "${backup_dir}/uptime.txt")
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

    last_result=$(ps fauxw > "${backup_dir}/ps.txt")
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
        last_result=$(pstree -pan > "${backup_dir}/pstree.txt")
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
        last_result=$(${ss_bin} -tanpul > "${backup_dir}/netstat-ss.txt")
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
        last_result=$(netstat -laputen > "${backup_dir}/netstat-legacy.txt")
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

backup_virsh() {
    debug "Backup virsh list"

    virsh_bin=$(command -v virsh)

    if [ -n "${virsh_bin}" ]; then
        last_result=$(${virsh_bin} list --all > "${backup_dir}/virsh-list.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* virsh list OK"
        else
            debug "* virsh list ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* virsh not installed"
    fi
}

backup_lxc() {
    debug "Backup lxc list"

    lxc_ls_bin=$(command -v lxc-ls)

    if [ -n "${lxc_ls_bin}" ]; then
        last_result=$(${lxc_ls_bin} --fancy > "${backup_dir}/lxc-list.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* lxc list OK"
        else
            debug "* lxc list ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* lxc-ls not installed"
    fi
}

backup_mount() {
    debug "Backup mount points"

    findmnt_bin=$(command -v findmnt)
    mount_bin=$(command -v mount)

    if [ -n "${findmnt_bin}" ]; then
        last_result=$(${findmnt_bin} > "${backup_dir}/mount.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* mount points OK"
        else
            debug "* mount points ERROR"
            debug "${last_result}"
            rc=10
        fi
    elif [ -n "${mount_bin}" ]; then
        last_result=$(${mount_bin} > "${backup_dir}/mount.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* mount points OK"
        else
            debug "* mount points ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* findmnt and mount not installed"
    fi
}

backup_df() {
    debug "Backup df"

    df_bin=$(command -v df)

    if [ -n "${df_bin}" ]; then
        last_result=$(${df_bin} --portability > "${backup_dir}/df.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* df OK"
        else
            debug "* df ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* df not installed"
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
    if [ "${DO_VIRSH}" -eq 1 ]; then
        backup_virsh
    fi
    if [ "${DO_LXC}" -eq 1 ]; then
        backup_lxc
    fi
    if [ "${DO_MOUNT}" -eq 1 ]; then
        backup_mount
    fi
    if [ "${DO_DF}" -eq 1 ]; then
        backup_df
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

        --apt)
            DO_APT=1
            ;;
        --no-apt)
            DO_APT=0
            ;;

        --packages)
            DO_PACKAGES=1
            ;;
        --no-packages)
            DO_PACKAGES=0
            ;;

        --processes)
            DO_PROCESSES=1
            ;;
        --no-processes)
            DO_PROCESSES=0
            ;;

        --uptime)
            DO_UPTIME=1
            ;;
        --no-uptime)
            DO_UPTIME=0
            ;;

        --netstat)
            DO_NETSTAT=1
            ;;
        --no-netstat)
            DO_NETSTAT=0
            ;;

        --netcfg)
            DO_NETCFG=1
            ;;
        --no-netcfg)
            DO_NETCFG=0
            ;;

        --iptables)
            DO_IPTABLES=1
            ;;
        --no-iptables)
            DO_IPTABLES=0
            ;;

        --sysctl)
            DO_SYSCTL=1
            ;;
        --no-sysctl)
            DO_SYSCTL=0
            ;;

        --virsh)
            DO_VIRSH=1
            ;;
        --no-virsh)
            DO_VIRSH=0
            ;;

        --lxc)
            DO_LXC=1
            ;;
        --no-lxc)
            DO_LXC=0
            ;;

        --mount)
            DO_MOUNT=1
            ;;
        --no-mount)
            DO_MOUNT=0
            ;;

        --df)
            DO_DF=1
            ;;
        --no-df)
            DO_DF=0
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
: "${DO_VIRSH:=1}"
: "${DO_LXC:=1}"
: "${DO_MOUNT:=1}"
: "${DO_DF:=1}"

export LC_ALL=C

set -u

main
