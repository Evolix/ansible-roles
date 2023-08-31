#!/bin/sh

# WARN: This script is a work in progress!
# The happy path works, but the rest is not finalized yet.

# TODO:
# * exit with error if there is no DRBD
# * logging (stdout/stderr + syslog)
# * more checks, rollback if needed…
# * different return codes for different errors
# * migrate "from"
# * switch to Bash to use local and readonly variables

VERSION="21.04.1"

show_version() {
    cat <<END
migrate-vm version ${VERSION}

Copyright 2018-2021 Evolix <info@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>,
               Victor Laborie <vlaborie@evolix.fr>
               and others.

migrate-vm comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

show_help() {
    cat <<END
migrate-vm migrates KVM/qemu virtual machines between hypervisors

END
    show_usage
}
show_usage() {
    cat <<END
Usage: migrate-vm --vm <vm-name>
  or   migrate-vm --vm <vm-name> --resource <drbd-resource-name>
  or   migrate-vm --persistent <vm-name>
  or   migrate-vm --transient <vm-name>

Options
  --vm              VM name (from libvirt point of view)
  --resource        DRBD resource name (default to VM name)
  --transient       Leave VM as defined on hosts
  --persistent      Undefine the VM on the source
                    and define it on the destination (default)
  --help            Print this message and exit
  --version         Print version and exit
END
}

persistent() {
    test "${persistent}" -eq 1
}

server_ips() {
    ip addr show | grep 'inet '| awk '{print $2}' | cut -f1 -d'/'
}

drbd_config_file() {
    echo "/etc/drbd.d/${1:-}.res"
}

is_drbd_resource() {
    resource=${1:-}
    test -f "$(drbd_config_file "${resource}")" && drbdadm role "${resource}" >/dev/null 2>&1
}

drbd_peers() {
    drbd_config_file=$(drbd_config_file "${1:-}")

    awk '$1 ~ /^on$/ { host = $2 } $1 ~ /^address/ { sub(";$", "", $NF); split($NF, a, ":"); ip = a[1]; printf "%s:%s\n", host, ip }' "${drbd_config_file}"
}

is_vm_running_locally() {
    vm=${1:-}

    virsh list --state-running --name | grep --fixed-strings --line-regexp --quiet "${vm}"
}

execute_remotely() {
    remote=${1:-}
    shift
    command=${*}

    # shellcheck disable=SC2029
    ssh -n -o BatchMode=yes "${remote}" "${command}"
}

set_drbd_role() {
    role=${1:-}
    resource=${2:-}
    remote=${3:-""}

    case "${role}" in
    primary|secondary)
        set_command="drbdadm ${role} ${resource}"
        verify_command="drbdadm role ${resource} | grep --fixed-strings --ignore-case --quiet ${role}/"
        ;;
    *)
        echo "Unknown DRBD role '${role}'" >&2
        exit 1
        ;;
    esac

    if [ -z "${remote}" ]; then
        retval=$(eval "${set_command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while setting ${resource} as ${role} : ${retval}" >&2
            exit 1
        fi

        retval=$(eval "${verify_command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "Role has not been set to ${role} on ${resource}. Abort!" >&2
            exit 1
        fi
    else
        retval=$(execute_remotely "${remote}" "${set_command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while remotely setting ${resource} as ${role} : ${retval}" >&2
            exit 1
        fi

        retval=$(execute_remotely "${remote}" "${verify_command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "Role has not been remotely set to ${role} on ${resource}. Abort!" >&2
            exit 1
        fi
    fi
}

define_vm() {
    vm=${1:-}
    remote=${2:-}

    if [ -z "${remote}" ]; then
        # retval=$(virsh define "${vm}")
        # retcode=$?
        # if [ ${retcode} != 0 ]; then
        #     >&2 echo "An error occured while defining ${vm} : ${retval}"
        #     exit 1
        # fi
        echo "Defining a VM locally is not supported yet. Let's skip this step." >&2
    else
        retval=$(virsh dumpxml "${vm}" | ssh "${remote}" virsh define /dev/stdin)
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while remotely defining ${vm} : ${retval}" >&2
            exit 1
        fi
    fi
}

undefine_vm() {
    vm=${1:-}
    remote=${2:-}

    command="virsh undefine ${vm}"

    if [ -z "${remote}" ]; then
        retval=$(eval "${command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while undefining ${vm} : ${retval}" >&2
            exit 1
        fi
    else
        retval=$(execute_remotely "${remote}" "${command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while remotely undefining ${vm}: ${retval}" >&2
            exit 1
        fi
    fi
}

migrate_vm_from() {
    vm=${1:-}
    remote_ip=${2:-}
    current_ip=${3:-}

    export VIRSH_DEFAULT_CONNECT_URI="qemu+ssh://${remote_ip}/system"
    virsh migrate --live --unsafe --verbose "${vm}" "qemu:///system" "tcp://${current_ip}/"
}

migrate_vm_to() {
    vm=${1:-}
    remote_ip=${2:-}

    export VIRSH_DEFAULT_CONNECT_URI="qemu:///system"
    virsh migrate --live --unsafe --verbose "${vm}" "qemu+ssh://${remote_ip}/system" "tcp://${remote_ip}/"
}

migrate_from() {
    vm=${1:-}
    resource=${2:-}
    remote_ip=${3:-}
    remote_host=${4:-}
    current_ip=${5:-}
    current_host=${6:-}

    echo "Start migration of ${vm} from ${remote_ip} (${remote_host})"

    set_drbd_role primary "${resource}"
    migrate_vm_from "${vm}" "${remote_ip}" "${current_ip}"
    set_drbd_role secondary "${resource}" "${remote_ip}"
    if persistent; then
        define_vm "${vm}"
        undefine_vm "${vm}" "${remote_ip}"
    fi
}

migrate_to() {
    vm=${1:-}
    resource=${2:-}
    remote_ip=${3:-}
    remote_host=${4:-}

    echo "Start migration of ${vm} to ${remote_ip} (${remote_host})"

    set_drbd_role primary "${resource}" "${remote_ip}"
    migrate_vm_to "${vm}" "${remote_ip}"
    set_drbd_role secondary "${resource}"
    if persistent; then
        define_vm "${vm}" "${remote_ip}"
        undefine_vm "${vm}"
    fi
}

main() {
    vm=${1:-}
    resource=${2:-}
    server_ips=$(server_ips)

    if ! is_drbd_resource "${resource}"; then
        echo "No DRBD resource found for '${resource}\`." >&2
        exit 1
    fi

    for peer in $(drbd_peers "${resource}"); do
        host=$(echo "${peer}" | cut -d':' -f1)
        ip=$(echo "${peer}" | cut -d':' -f2)

        # shellcheck disable=SC2086
        if echo ${server_ips} | grep --quiet "${ip}"; then
            current_ip="${ip}"
            current_host="${host}"
        else
            remote_ip="${ip}"
            remote_host="${host}"
        fi
    done

    if is_vm_running_locally "${vm}"; then
        migrate_to "${vm}" "${resource}" "${remote_ip}" "${remote_host}"
    else
        echo "Migrating \"from\" is not supported yet" >&2
        exit 1

        migrate_from "${vm}" "${resource}" "${remote_ip}" "${remote_host}" "${current_ip}" "${current_host}"
    fi
}

if [ "$(id -u)" -ne "0" ] ; then
    echo "This script must be run as root." >&2
    exit 1
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
        --transient)
            transient=1
            persistent=0
            ;;
        --persistent)
            transient=0
            persistent=1
            ;;
        --vm)
            # with value separated by space
            if [ -n "$2" ]; then
                vm=$2
                shift
            else
                printf 'ERROR: "--vm" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --vm=?*)
            # with value speparated by =
            vm=${1#*=}
            ;;
        --vm=)
            # without value
            printf 'ERROR: "--vm" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --resource)
            # with value separated by space
            if [ -n "$2" ]; then
                resource=$2
                shift
            else
                printf 'ERROR: "--resource" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --resource=?*)
            # with value speparated by =
            resource=${1#*=}
            ;;
        --resource=)
            # without value
            printf 'ERROR: "--resource" requires a non-empty option argument.\n' >&2
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
vm=${vm:-}
resource=${resource:-${vm}}
transient=${transient:-0}
persistent=${persistent:-1}

set -u
set -e

if [ -z "${vm}" ]; then
    echo "You must provide a VM name" >&2
    echo "" >&2
    show_usage >&2
    exit 1
fi

main "${vm}" "${resource}"

exit 0