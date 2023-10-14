#!/bin/sh

# WARN: This script is a work in progress!
# The happy path works, but the rest is not finalized yet.

# TODO:
# * exit with error if there is no DRBD
# * logging (stdout/stderr + syslog)
# * more checks, rollback if needed…
# * different return codes for different errors
# * switch to Bash to use local and readonly variables

VERSION="23.10.1"

show_version() {
    cat <<END
migrate-vm version ${VERSION}

Copyright 2018-2023 Evolix <info@evolix.fr>,
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

Options
  --vm              VM name (from libvirt point of view)
  --resource        DRBD resource name (default to VM name)
                    and define it on the destination (default)
  --help            Print this message and exit
  --version         Print version and exit
END
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

check_drbd_sync() {
    resource=${1:-}

    set +e
    dstate=$(drbdadm dstate "${resource}" | grep -vF 'UpToDate/UpToDate')
    cstate=$(drbdadm cstate "${resource}" | grep -vF 'Connected')
    set -e

    if [ -n "${dstate}" ] || [ -n "${cstate}" ]; then
        echo "DRBD resource ${resource} is not up-to-date" >&2
        exit 1
    fi
}

drbd_interface() {
    drbd_peer=${1:-}
    ip route get "${drbd_peer}" | grep --only-matching --extended-regexp 'dev\s+\S+' | awk '{print $2}'
}

interface_speed() {
    interface=${1:-}
    fallback_speed="1000"
    speed_path="/sys/class/net/${interface}/speed"
    bridge_path="/sys/class/net/${interface}/brif"

    if [ -e "${bridge_path}" ]; then
        # echo "${interface} is a bridge" >&2
        case "$(ls "${bridge_path}" | wc -l)" in
        0)
            # echo "${interface} bridge is empty, fallback to ${fallback_speed}" >&2
            echo "${fallback_speed}"
            ;;
        1)
            bridge_iface="$(ls "${bridge_path}" | head -n 1)"
            # echo "${interface} bridge has 1 interface: ${bridge_iface}" >&2
            interface_speed "${bridge_iface}"
            ;;
        *)
            # echo "${interface} bridge has many interfaces" >&2
            min_speed=""
            for bridge_iface in $(ls "${bridge_path}"); do
                if realpath "/sys/class/net/${bridge_iface}" | grep --quiet --invert-match virtual; then
                    speed=$(head -n 1 "/sys/class/net/${bridge_iface}/speed")
                    # echo "${bridge_iface} is a physical interface, keep" >&2
                    if [ -z "${min_speed}" ] || [ "${min_speed}" -gt "${speed}" ]; then
                        # echo "new min speed with ${bridge_iface}: ${speed}" >&2
                        min_speed="${speed}"
                    fi
                else
                    # echo "${bridge_iface} is a virtual interface, skip" >&2
                    : # noop
                fi
            done
            if [ -n "${min_speed}" ] && [ "${min_speed}" -gt "0" ]; then
                echo "${min_speed}"
            else
                echo "${fallback_speed}"
            fi
            ;;
        esac
    elif [ -e "${speed_path}" ]; then
        head -n 1 "${speed_path}"
    else
        echo "${fallback_speed}"
    fi
}

drbd_peers() {
    drbd_config_file=$(drbd_config_file "${1:-}")

    awk '$1 ~ /^on$/ { host = $2 } $1 ~ /^address/ { sub(";$", "", $NF); split($NF, a, ":"); ip = a[1]; printf "%s:%s\n", host, ip }' "${drbd_config_file}"
}

is_vm_running_locally() {
    vm=${1:-}

    virsh list --state-running --name | grep --fixed-strings --line-regexp --quiet "${vm}"
}
is_vm_defined_locally() {
    vm=${1:-}

    virsh list --all --name | grep --fixed-strings --line-regexp --quiet "${vm}"
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

migrate_vm_to() {
    vm=${1:-}
    remote_ip=${2:-}

    drbd_interface=$(drbd_interface "${remote_ip}")
    interface_speed=$(interface_speed "${drbd_interface}")
    migrate_speed=$(echo "${interface_speed}*0.8/8" | bc)

    echo "Migration speed set to ${migrate_speed}MiB/s"
    virsh --quiet migrate-setspeed "${vm}" "${migrate_speed}"

    export VIRSH_DEFAULT_CONNECT_URI="qemu:///system"
    virsh migrate --live --unsafe --verbose "${vm}" "qemu+ssh://${remote_ip}/system" "tcp://${remote_ip}/"
}

# start_vm() {
#     vm=${1:-}
#     remote_ip=${2:-}

#     command="virsh start ${vm}"

#     if [ -z "${remote}" ]; then
#         retval=$(eval "${command}")
#         retcode=$?
#         if [ ${retcode} != 0 ]; then
#             echo "An error occured while starting ${vm} : ${retval}" >&2
#             exit 1
#         fi
#     else
#         retval=$(execute_remotely "${remote}" "${command}")
#         retcode=$?
#         if [ ${retcode} != 0 ]; then
#             echo "An error occured while remotely starting ${vm}: ${retval}" >&2
#             exit 1
#         fi
#     fi
# }

migrate_to() {
    vm=${1:-}
    resource=${2:-}
    remote_ip=${3:-}
    remote_host=${4:-}

    echo "Start migration of ${vm} to ${remote_ip} (${remote_host})"

    check_drbd_sync "${resource}"

    set_drbd_role primary "${resource}" "${remote_ip}"
    sleep 1

    if is_vm_running_locally "${vm}"; then
        migrate_vm_to "${vm}" "${remote_ip}"
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occured while migrating ${vm}: ${retval}" >&2
            set_drbd_role secondary "${resource}" "${remote_ip}"
            exit 1
        fi
    else
        echo "${vm} is not running locally, so it won't be started on ${remote_host}"
    fi

    define_vm "${vm}" "${remote_ip}"
    undefine_vm "${vm}"

    sleep 1
    set_drbd_role secondary "${resource}"
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

    if is_vm_defined_locally "${vm}"; then
        migrate_to "${vm}" "${resource}" "${remote_ip}" "${remote_host}"
    else
        echo "VM \"${vm}\" is not defined." >&2
        exit 1
    fi

    # if is_vm_running_locally "${vm}"; then
    #     migrate_to "${vm}" "${resource}" "${remote_ip}" "${remote_host}"
    # else
    #     echo "Migrating \"from\" is not supported yet" >&2
    #     exit 1

    #     migrate_from "${vm}" "${resource}" "${remote_ip}" "${remote_host}" "${current_ip}" "${current_host}"
    # fi
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
            printf 'WARNING: "transient" mode has been removed.\n' >&2
            exit 1
            ;;
        --persistent)
            printf 'WARNING: "persistent" mode is the only one available. You can remove this argument from your command.\n' >&2
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