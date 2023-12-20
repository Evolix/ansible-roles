#!/bin/sh

set -u
set -e

# Input values
STATE=$1
VRID=$2
VIRTUAL_IP=$3
INTERFACE_NAME=$4
LABEL=$5
PRIORITY=$6
ADVERT_INT=$7
PREEMPT=$8
OTHER=${9:-}

LOG_DIR=/var/log/vrrpd/
[ ! -d "${LOG_DIR}" ] && mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/state.${VRID}"

STATE_DIR=/var/run/vrrpd/
[ ! -d "${STATE_DIR}" ] && mkdir -p "${STATE_DIR}"
STATE_FILE="${STATE_DIR}/vrrp-${LABEL}"

# Log state change to file
printf "%s %s %s %s %s %s %s %s : %s\n" \
    "${STATE}" \
    "${VIRTUAL_IP}" \
    "${INTERFACE_NAME}" \
    "${LABEL}" \
    "${PRIORITY}" \
    "${ADVERT_INT}" \
    "${PREEMPT}" \
    "${OTHER}" \
    "$(date)" \
    >> "${LOG_FILE}"

# Replace information in state file
{
    echo "VRRP - ${LABEL}"
    echo "Group ${VRID}"
    echo "State is ${STATE}"
    echo "Virtual IP address is ${VIRTUAL_IP}"
} > "${STATE_FILE}"

# Choose virtual interface name (limited in size)
INTERFACE_PREFIX="vrrp_${VRID}_"
INTERFACE_PREFIX_LEN=${#INTERFACE_PREFIX}
INTERFACE_LEN=$(( ${#INTERFACE_PREFIX} + ${#INTERFACE_NAME} ))
INTERFACE_MAX_LEN=15

if [ ${INTERFACE_LEN} -gt ${INTERFACE_MAX_LEN} ]; then
    INTERFACE_SUFFIX=$(echo "${INTERFACE_NAME}" | tail -c $(( INTERFACE_MAX_LEN + 1 - INTERFACE_PREFIX_LEN )))
else
    INTERFACE_SUFFIX="${INTERFACE_NAME}"
fi
VIRTUAL_INTERFACE_NAME="${INTERFACE_PREFIX}${INTERFACE_SUFFIX}"

# Apply state
case "${STATE}" in

    "master" )
        # Choose a MAC address
        MAC_SUFFIX=$(printf %02x "${VRID}")
        MAC="00:00:5e:00:01:${MAC_SUFFIX})"
        # Create macvlan interface
        ip link add link "${INTERFACE_NAME}" address "${MAC}" "${VIRTUAL_INTERFACE_NAME}" type macvlan
        # Add IP to interface
        ip address add "${VIRTUAL_IP}" dev "${VIRTUAL_INTERFACE_NAME}"
        # Enable interface
        ip link set dev "${VIRTUAL_INTERFACE_NAME}" up
    ;;
    
    "slave" )
        # Delete interface if it exists
        if ip link show "${VIRTUAL_INTERFACE_NAME}" >/dev/null 2>&1; then
            ip link delete "${VIRTUAL_INTERFACE_NAME}"
        fi
    ;; 
    
    * )
        # Error on unknown value for state
        echo "Unknown state '${STATE}'" >&2
        exit 1
    ;; 

esac

exit 0
