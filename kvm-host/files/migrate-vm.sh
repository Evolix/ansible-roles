#!/bin/bash

# WARN: This script is a work in progress!
# The happy path works, but the rest is not finalized yet.

# TODO:
# * logging (stdout/stderr + syslog)
# * more checks, rollback if needed…
# * different return codes for different errors
# * use local and readonly variables

VERSION="26.06"

# If expansion is attempted on an unset variable or parameter, the shell prints an
# error message, and, if not interactive, exits with a non-zero status.
set -o nounset

### disabled, it breaks "grep --quiet"
# The pipeline's return status is the value of the last (rightmost) command
# to exit with a non-zero status, or zero if all commands exit successfully.
# set -o pipefail

# Enable trace mode if called with environment variable TRACE=1
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

PROGPATH=$(readlink -m "${0}")
readonly PROGPATH
PROGNAME=$(basename "${PROGPATH}")
readonly PROGNAME
# # shellcheck disable=SC2124
# ARGS=$@
# readonly ARGS

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2026 Evolix <info@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>,
               Victor Laborie <vlaborie@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

show_help() {
    cat <<END
${PROGNAME} migrates KVM/qemu virtual machines between hypervisors

END
    show_usage
}
show_usage() {
    cat <<END
Usage: ${PROGNAME} --vms <vm1-name>[,<vm2-name>]
  or   ${PROGNAME} --vms <vm-name>:<drbd-resource-name>
  or   ${PROGNAME} --vms /path/to/list
  or   printf "vm1-name\nvm2-name\n" | ${PROGNAME} --vms -
  or   ${PROGNAME} --all

Options
  --vms          Migrate this list of VMs
  --all          Migrate all running VMs
  --[no-]report  Store remotely the list of migrated VMs
  --report-path  Remote path for the report
  --hot          Migrate VMs as they are (default)
  --cold         Stop before and start after migration
  --[no-]stop-before Stop VMs before migration
  --[no-]start-after Start VMs after migration
  --stop-timeout Seconds to wait for the VM to stop
                 default: 300 seconds
                  >0 integer: abort if VM is still up
                 <=0 integer: wait infinitely
  --speed        Force migration speed (in Mbits)
  --help         Print this message and exit
  --version      Print version and exit

For multi-line inputs, a line beginning with # is ignored.

If the DRBD resource name defaults to VM name.
Otherwise it can be specified by joining the VM name
and the resource name with a colon : "vm-name:drbd-res".
It is applicable to the inline parameter and to multi-line inputs.

A list of migrated VM is built during the process.
If more than 1 VM or if "--report" was passed, then the file is saved
on the remote server.
If only 1 VM or if "--no-report" is passed, then the file is not saved.
The file path is "/root/migrate-vm.<hostname>.<date>" by default,
but it can be customized with "--report-path <PATH>"

For backward compatibility, "--vm" and "--resource" can be passed.
Their value will be used to make a list with a single VM.
These options are ignored if "--all" or "--vms" is used.

Hot migrations are the default behavior (equivalent of "--hot").
Use cold migrations when hot migrations are impossible.
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

    bonding_speed_path="/sys/class/net/${interface}/bonding/speed"
    if [ -e "${bonding_speed_path}" ]; then
        speed_path="${bonding_speed_path}"
    fi

    if [ -e "${speed_path}" ]; then
        speed=$(head -n 1 "${speed_path}" 2> /dev/null)
        if [ -n "${speed}" ] || [ "${speed}" -gt "0" ]; then
            echo "${speed}"
            return 0
        fi
    fi

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
                speed=$(head -n 1 "/sys/class/net/${bridge_iface}/speed" 2> /dev/null)
                if realpath "/sys/class/net/${bridge_iface}" | grep --quiet virtual; then
                    if [ -n "${speed}" ]; then
                        # echo "${bridge_iface} is a virtual interface (with detected speed of ${speed}), keep" >&2
                        # echo "min_speed: '${min_speed}', speed: '${speed}'" >&2
                        if [ -z "${min_speed}" ] || [ "${min_speed}" -lt "${speed}" ]; then
                            # echo "new min speed with ${bridge_iface}: ${speed}" >&2
                            min_speed="${speed}"
                        fi
                    else
                        # echo "${bridge_iface} is a virtual interface (with no detected speed), skip" >&2
                        : # noop
                    fi
                else
                    if [ -n "${speed}" ]; then
                        # echo "${bridge_iface} is a physical interface, keep" >&2
                        # echo "min_speed: '${min_speed}', speed: '${speed}'" >&2
                        if [ -z "${min_speed}" ] || [ "${min_speed}" -lt "${speed}" ]; then
                            # echo "new min speed with ${bridge_iface}: ${speed}" >&2
                            min_speed="${speed}"
                        fi
                    else
                        # echo "${bridge_iface} is a physical interface (with no detected speed), skip" >&2
                        : # noop
                    fi
                fi
            done
            if [ -n "${min_speed}" ] && [ "${min_speed}" -gt "0" ]; then
                echo "${min_speed}"
            else
                echo "${fallback_speed}"
            fi
            ;;
        esac
    elif realpath "/sys/class/net/${interface}" | grep --quiet --fixed-strings '/virtual/'; then
        # echo "${interface} is a virtual interface" >&2
        # Check if speed is available
        speed=$(head -n 1 "/sys/class/net/${interface}/speed" 2> /dev/null)
        if [ -n "${speed}" ]; then
            # echo "${interface} has speed of ${speed}" >&2
            echo "${speed}"
        else
            # echo "${interface} has no speed" >&2
            # If interface is virtual and speed is not available, try to find the real interface
            lower_ifaces="$(ls -d /sys/class/net/${interface}/lower_* | wc -l)"
            if [ -n "${lower_ifaces}" ] && [ "${lower_ifaces}" -eq "1" ]; then
                # Take the first parent interface
                first_lower_iface="$(ls -d /sys/class/net/${interface}/lower_* | head -n 1)"
                new_iface=$(basename "$(realpath "${first_lower_iface}")")
                # echo "${interface} is in fact ${new_iface}" >&2
                # recursice call to self, but with the real interface
                interface_speed "${new_iface}"
            else
                echo "${fallback_speed}"
            fi
        fi
    else
        echo "${fallback_speed}"
    fi
}

drbd_peers() {
    drbd_config_file=$(drbd_config_file "${1:-}")

    awk '$1 ~ /^on$/ { host = $2 } $1 ~ /^address/ { sub(";$", "", $NF); split($NF, a, ":"); ip = a[1]; printf "%s:%s\n", host, ip }' "${drbd_config_file}"
}

is_old_virsh() {
    if [ -z "${is_old_virsh:-}" ]; then
        dpkg --compare-versions "$(virsh --version)" lt '3.0.0'
        is_old_virsh=$?
    fi
    return ${is_old_virsh}
}
is_vm_running_locally() {
    local vm
    local vm_list

    vm=${1:-}
    vm_list=$(virsh list --state-running --name)

    echo "${vm_list}" | grep --fixed-strings --line-regexp --quiet "${vm}"
}
is_vm_shutoff_locally() {
    local vm
    local vm_list

    vm=${1:-}
    # There is a bug in virsh on Debian 8
    # We need to use --all on top of --state-XXXX
    if is_old_virsh; then
        vm_list=$(virsh list --all --state-shutoff --name)
    else
        vm_list=$(virsh list --state-shutoff --name)
    fi

    echo "${vm_list}" | grep --fixed-strings --line-regexp --quiet "${vm}"
}
is_vm_defined_locally() {
    local vm
    local vm_list

    vm=${1:-}
    vm_list=$(virsh list --all --name)

    echo "${vm_list}" | grep --fixed-strings --line-regexp --quiet "${vm}"
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
            echo "An error occurred while setting ${resource} as ${role} : ${retval}" >&2
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
            echo "An error occurred while remotely setting ${resource} as ${role} : ${retval}" >&2
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
        #     >&2 echo "An error occurred while defining ${vm} : ${retval}"
        #     exit 1
        # fi
        echo "Defining a VM locally is not supported yet. Let's skip this step." >&2
    else
        retval=$(virsh dumpxml "${vm}" | ssh "${remote}" virsh define /dev/stdin)
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occurred while remotely defining ${vm} : ${retval}" >&2
            exit 1
        fi
    fi
}

undefine_vm() {
    vm=${1:-}
    remote=${2:-}

    command="virsh undefine --nvram ${vm}"

    if [ -z "${remote}" ]; then
        retval=$(eval "${command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occurred while undefining ${vm} : ${retval}" >&2
            exit 1
        fi
    else
        retval=$(execute_remotely "${remote}" "${command}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occurred while remotely undefining ${vm}: ${retval}" >&2
            exit 1
        fi
    fi
}

start_vm() {
    vm=${1:-}
    remote=${2:-}

    if [ -z "${remote}" ]; then
        echo "Starting a VM locally is not supported yet. Let's skip this step." >&2
    else
        if is_vm_running_locally "${vm}"; then
            echo "VM ${vm} is already started. Let's skip this step." >&2
        else
            retval=$(ssh "${remote}" virsh start "${vm}")
            retcode=$?
            if [ ${retcode} != 0 ]; then
                echo "An error occurred while remotely starting ${vm} : ${retval}" >&2
                exit 1
            else
                echo "VM ${vm} is started" >&2
            fi
        fi
    fi
}

stop_vm() {
    vm=${1:-}
    remote=${2:-}

    if [ -z "${remote}" ]; then
        retval=$(virsh shutdown "${vm}")
        retcode=$?
        if [ ${retcode} != 0 ]; then
            echo "An error occurred while stopping ${vm} : ${retval}" >&2
            exit 1
        fi

        local timeout
        timeout=${option_stop_timeout}

        local timeout_word
        if [ ${option_stop_timeout} -le 0 ]; then
            timeout_word="infinitely"
        else
            timeout_word="${option_stop_timeout}s"
        fi

        if ! is_vm_shutoff_locally "${vm}"; then
            printf "Waiting %s for VM %s to shutoff " "${timeout_word}" "${vm}" >&2
            shutoff=0
            start=$(date +%s)
            elapsed=$(( $(date +%s) - start ))
            # wait for the shutoff, with a positive timeout or infinitely (timeout <= 0)
            while [ ${shutoff} -eq 0 ] && { [ ${elapsed} -le ${timeout} ] || [ ${timeout} -le 0 ] ; } ; do
                if is_vm_shutoff_locally "${vm}"; then
                    shutoff=1
                else
                    sleep 1
                    printf "."
                fi
                elapsed=$(( $(date +%s) - start ))
            done
            printf "\n"
            if ! is_vm_shutoff_locally "${vm}"; then
                echo "Stopping ${vm} timed-out after ${elapsed} seconds" >&2
                exit 1
            # else
            #     echo "VM ${vm} stopped after ${elapsed} seconds"
            fi
        fi
    else
        echo "Stopping a VM remotely is not supported yet. Let's skip this step." >&2
    fi
}

migrate_vm_to() {
    vm=${1:-}
    remote_ip=${2:-}
    speed=${3:-}

    drbd_interface=$(drbd_interface "${remote_ip}")

    if [ -n "${speed}" ]; then
        migrate_speed="${speed}"
    else
        interface_speed=$(interface_speed "${drbd_interface}")
        migrate_speed=$(echo "${interface_speed}*0.8/8" | bc)
    fi

    echo "Migration speed set to ${migrate_speed}MiB/s"
    virsh --quiet migrate-setspeed "${vm}" "${migrate_speed}"

    export VIRSH_DEFAULT_CONNECT_URI="qemu:///system"
    virsh migrate --live --unsafe --verbose "${vm}" "qemu+ssh://${remote_ip}/system" "tcp://${remote_ip}/"
}

migrate_to() {
    vm=${1:-}
    resource=${2:-}
    remote_ip=${3:-}
    remote_host=${4:-}
    speed=${5:-}

    echo "Start migration of ${vm} to ${remote_ip} (${remote_host})"

    check_drbd_sync "${resource}"

    set_drbd_role primary "${resource}" "${remote_ip}"
    sleep 1

    if is_vm_running_locally "${vm}" && [ ${option_stop_before} -eq 1 ]; then
        stop_vm "${vm}"
    fi

    if is_vm_running_locally "${vm}"; then
        migrate_vm_to "${vm}" "${remote_ip}" "${speed}"
    else
        if [ ${option_start_after} -eq 0 ]; then
            echo "${vm} is not running locally, so it won't be started on ${remote_host}"
        fi
    fi

    define_vm "${vm}" "${remote_ip}"

    if [ ${option_start_after} -eq 1 ]; then
        start_vm "${vm}" "${remote_ip}"
    fi

    undefine_vm "${vm}"

    sleep 1
    set_drbd_role secondary "${resource}"

    # When the report is enabled, the VM name is added when the migration finishes.
    # If the DRBD resource name is different than the VM name, it is also added on the same line.
    if [ "${option_report}" -eq 1 ] && [ -n "${option_report_path}" ]; then
        if [ "${vm}" = "${resource}" ]; then
            execute_remotely "${remote_ip}" "echo \"${vm}\" >> ${option_report_path}"
        else
            execute_remotely "${remote_ip}" "echo \"${vm}:${resource}\" >> ${option_report_path}"
        fi
    fi
}

migrate() {
    vm=${1:-}
    resource=${2:-}
    speed=${3:-}
    server_ips=$(server_ips)

    if ! is_drbd_resource "${resource}"; then
        echo "No DRBD resource found for '${resource}\`." >&2
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
        migrate_to "${vm}" "${resource}" "${remote_ip}" "${remote_host}" "${speed}"
    else
        echo "VM \"${vm}\" is not defined." >&2
    fi

    # if is_vm_running_locally "${vm}"; then
    #     migrate_to "${vm}" "${resource}" "${remote_ip}" "${remote_host}"
    # else
    #     echo "Migrating \"from\" is not supported yet" >&2
    #     exit 1

    #     migrate_from "${vm}" "${resource}" "${remote_ip}" "${remote_host}" "${current_ip}" "${current_host}"
    # fi
}

main() {
    # Temp file to store the list of VMs to migrate, destroyed at exit.
    vm_list_tmp=$(mktemp --tmpdir "migrate-vm.XXXXX")
    # shellcheck disable=SC2064
    trap "rm -f \"${vm_list_tmp}\"" 0

    # Prepare a temp file with list of VM to migrate

    # If "--all" option is passed, ignore other options
    if [ "${option_all}" -eq 1 ]; then
        running_vm_list=$(virsh list --name --state-running)
        echo "${running_vm_list}" | grep -vE "^$" > "${vm_list_tmp}"
    else
        # Look for an existing path or stdin or a comma-separated list.
        # Lines starting with # (comments) are ignored
        vm_list_file=$(realpath "${option_vms}" 2> /dev/null)
        if [ -n "${vm_list_file}" ] && [ -f "${vm_list_file}" ]; then
            # echo "Using ${vm_list_file} as input."
            grep --invert-match --extended-regexp "^#" < "${vm_list_file}" > "${vm_list_tmp}"
        elif [ "${option_vms}" = "-" ]; then
            # echo "Using stdin as input."
            read -rd '' vm_list
            echo "${vm_list}" | grep --invert-match --extended-regexp "^#" > "${vm_list_tmp}"
        else
            # echo "Using option as input."
            echo "${option_vms}" | tr ',' '\n' > "${vm_list_tmp}"
        fi
    fi

    # Initialize counters
    count_total=$(wc -l "${vm_list_tmp}" | cut -d ' ' -f 1)
    count_current=0

    # If report is not explicitely enabled or disabled
    if [ -z "${option_report}" ] ; then
        # it is disabled for 1 VM, and enabled for more than 1 VM
        if [ "${count_total}" -le 1 ]; then
            option_report=0
        else
            option_report=1
        fi
    fi

    # Default value for report path.
    if [ -z "${option_report_path}" ]; then
        option_report_path="/root/migrate-vm.$(hostname).$(date +'%Y%m%d%H%M%S')"
    fi

    # Migrate each VM in the list
    while IFS= read -r line; do
        count_current=$((count_current + 1))
        vm=$(echo "${line}" | cut -d: -f1)
        resource=$(echo "${line}" | cut -d: -f2)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] VM ${count_current}/${count_total}: ${vm} (resource: ${resource})"
        migrate "${vm}" "${resource}" "${option_speed}"
    done < "${vm_list_tmp}"

    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Finish"

    # if report is enabled, print instructions on how to use it.
    if [ "${option_report}" -eq 1 ]; then
        echo ""
        echo "The list of migrated VMs has been saved remotely to '${option_report_path}'."
        echo "You can migrate them back (from remote server) with:"
        echo "# migrate-vm --vms ${option_report_path}"
    fi
}

if [ "$(id -u)" -ne "0" ] ; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Show usage when executed with 0 arguments
if [ $# -eq 0 ] ; then
    show_usage
    exit 1
fi

# Default values for options
option_all=0
option_report=""
option_report_path=""
option_stop_before=0
option_start_after=0
option_stop_timeout=300
option_vms=""
option_vm=""
option_resource=""
option_speed=""

# Parse options
# based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
while :; do
    case ${1:-} in
        -h|-\?|--help)
            show_help
            exit 0
            ;;
        -V|--version)
            show_version
            exit 0
            ;;
        --all)
            option_all=1
            ;;
        --report)
            option_report=1
            ;;
        --no-report)
            option_report=0
            ;;
        --report-path)
            # with value separated by space
            if [ -n "$2" ]; then
                option_report_path=$2
                shift
            else
                printf 'ERROR: "--report-path" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --report-path=?*)
            # with value speparated by =
            option_report_path=${1#*=}
            ;;
        --report-path=)
            # without value
            printf 'ERROR: "--report-path" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        --stop-before)
            option_stop_before=1
            ;;
        --no-stop-before)
            option_stop_before=0
            ;;
        --stop-timeout)
            # with value separated by space
            value=$2
            [ -n "${value}" ] && [ "${value}" -eq "${value}" ] 2>/dev/null
            if [ $? -ne 0 ]; then
                printf 'ERROR: "--stop-timeout" requires an integer option argument.\n' >&2
                exit 1
            else
                option_stop_timeout="${value}"
                shift
            fi
            ;;
        --stop-timeout=?*)
            # with value speparated by =
            value=${1#*=}
            [ -n "${value}" ] && [ "${value}" -eq "${value}" ] 2>/dev/null
            if [ $? -ne 0 ]; then
                printf 'ERROR: "--stop-timeout" requires an integer option argument.\n' >&2
                exit 1
            else
                option_stop_timeout="${value}"
                shift
            fi
            ;;
        --stop-timeout=)
            # without value
            printf 'ERROR: "--stop-timeout" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --start-after)
            option_start_after=1
            ;;
        --no-start-after)
            option_start_after=0
            ;;
        --cold)
            option_stop_before=1
            option_start_after=1
            ;;
        --hot)
            option_stop_before=0
            option_start_after=0
            ;;

        --vms)
            # with value separated by space
            if [ -n "$2" ]; then
                option_vms=$2
                shift
            else
                printf 'ERROR: "--vms" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --vms=?*)
            # with value speparated by =
            option_vms=${1#*=}
            ;;
        --vms=)
            # without value
            printf 'ERROR: "--vms" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --speed)
            # with value separated by space
            if [ -n "$2" ]; then
                option_speed=$2
                shift
            else
                printf 'ERROR: "--speed" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --speed=?*)
            # with value speparated by =
            option_speed=${1#*=}
            ;;
        --speed=)
            # without value
            printf 'ERROR: "--speed" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        # Backward compatibility and deprecations
        --vm)
            # with value separated by space
            if [ -n "$2" ]; then
                option_vm=$2
                shift
            else
                printf 'ERROR: "--vm" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --vm=?*)
            # with value speparated by =
            option_vm=${1#*=}
            ;;
        --vm=)
            # without value
            printf 'ERROR: "--vm" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --resource)
            # with value separated by space
            if [ -n "$2" ]; then
                option_resource=$2
                shift
            else
                printf 'ERROR: "--resource" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --resource=?*)
            # with value speparated by =
            option_resource=${1#*=}
            ;;
        --resource=)
            # without value
            printf 'ERROR: "--resource" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --transient)
            printf 'WARNING: "transient" mode has been removed.\n' >&2
            exit 1
            ;;
        --persistent)
            printf 'WARNING: "persistent" mode is the only one available. You can remove this argument from your command.\n' >&2
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

# Check if speed is an integer
if [ -n "${option_speed}" ] && ! [[ "${option_speed}" =~ ^[0-9]+$ ]] ; then
    printf 'ERROR: "--speed" requires a integer value.\n' >&2
    exit 1
fi

# Backward compatibility
if [ -z "${option_vms}" ] && [ -n "${option_vm}" ]; then
    if [ -n "${option_resource}" ]; then
        option_vms="${option_vm}:${option_resource}"
    else
        option_vms="${option_vm}"
    fi
    unset option_vm
    unset option_resource
fi

main

exit 0
