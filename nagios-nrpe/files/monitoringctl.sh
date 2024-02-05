#!/usr/bin/env bash

#set -x

log_path="/var/log/monitoringctl.log"
conf_path="/etc/nagios/nrpe.cfg"

function show_help {
    cat <<EOF

monitoringctl gives some control over NRPE checks and alerts.

Usage: monitoringctl [OPTIONS] ACTION ARGUMENTS

GENERAL OPTIONS:

    -h, --help                         Print this message and exit.
    -v, --verbose                      Print more informations.

ACTIONS:

    check [--bypass-nrpe] CHECK_NAME

        Ask CHECK_NAME status to NRPE as an HTTP request.
        Indicates which command NRPE has supposedly run (from its configuration).

        Options:

            -b, --bypass-nrpe          Execute directly command from NRPE configuration,
                                       without requesting to NRPE.

    alerts-status

        Print :
        - Wether alerts are enabled or not (silenced).
        - If alerts are disabled (silenced):
            - Comment.
            - Time left before automatic re-enable.

    disable-alerts [--duration DURATION] 'COMMENT'

        Disable (silence) all alerts (only global for now) for DURATION and write COMMENT into the log.
        Checks output is still printed, so alerts history won't be lost.

        Options:

            -d, --duration DURATION    Specify disable-alerts duration (default: 1h).

    enable-alerts 'COMMENT'

        Re-enable all alerts (only global for now)

COMMENT:

    (mandatory) Comment (string) to be written in log.

DURATION:

    (optional, default: "1h") Duration time (string) during which alerts will be disabled (silenced).

    Format:
        You can use 'd' (day), 'h' (hour) and 'm' (minute) , or a combination of them, to specify a duration.
        Examples: '2d', '1h', '10m', '1h10' ('m' is guessed).

Log path: ${log_path}

EOF
}


function usage_error {
    >&2 echo "$1"
    >&2 echo "Execute \"monitoringctl --help\" for information on usage."
    exit 1
}

function now {
    date --iso-8601=seconds
}

function log {
    # $1: message
    echo "$(now) - $1" >> "${log_path}"
}


### FUNCTIONS FOR CONFIGURATION READING ##########################

# Print NRPE configuration, with includes, without comments
# and in the same order than NRPE does (taking account that
# order changes from Deb10)
function get_conf_from_file {
    # $1: NRPE conf file (.cfg)
    if [ ! -f "$1" ]; then return; fi

    conf_lines=$(grep -E -R -v --no-filename "^\s*#" "$1")
    while read -r line; do
        if [[ "${line}" =~ .*'include='.* ]]; then
            conf_file=$(echo "${line}" | cut -d= -f2)
            get_conf_from_file "${conf_file}"
        elif [[ "${line}" =~ .*'include_dir='.* ]]; then
            conf_dir=$(echo "${line}" | cut -d= -f2)
            get_conf_from_dir "${conf_dir}"
        else
            echo "${line}"
        fi
    done <<< "${conf_lines}"
}

# Print NRPE configuration, with includes, without comments
# and in the same order than NRPE does (taking account that
# order changes from Deb10)
function get_conf_from_dir {
    # $1: NRPE conf dir
    if [ ! -d "$1" ]; then return; fi

    if [ "${debian_major_version}" -ge 10 ]; then
        # From Deb10, NRPE use scandir() with alphasort() function
        sort_command="sort"
    else
        # Before Deb10, NRPE use loaddir(), like find utility
        sort_command="cat -"
    fi

    # Add conf files in dir to be processed recursively
    for file in $(find "$1" -maxdepth 1 -name "*.cfg" | ${sort_command}); do
        if [ -f "${file}" ]; then
            get_conf_from_file "${file}"
        elif [ -d "${file}" ]; then
            get_conf_from_dir "${file}"
        fi
    done
}

# Print the checks that are configured in NRPE
function get_checks_list {
    echo "${conf_lines}" | grep -E "command\[check_.*\]=" | awk -F"[\\\[\\\]=]" '{sub("check_", "", $2); print $2}' | sort | uniq
}

# Print the commands defined for check $1 in NRPE configuration
function get_check_commands {
    # $1: check name
    echo "$conf_lines" | grep -E "command\[check_$1\]" | cut -d'=' -f2-
}


### CHECK ACTION ##########################

function check {
    # $1: check name

    check_nrpe_bin=/usr/lib/nagios/plugins/check_nrpe

    if [ ! -f "${check_nrpe_bin}" ]; then
        >&2 echo "${check_nrpe_bin} is missing, please install nagios-nrpe-plugin package."
        exit 1
    fi

    server_address=$(echo "$conf_lines" | grep "server_address"  | cut  -d'=' -f2)
    if [ -z "${server_address}" ]; then server_address="127.0.0.1"; fi

    server_port=$(echo "$conf_lines" | grep "server_port"  | cut  -d'='  -f2)
    if [ -z "${server_port}" ]; then server_port="5666"; fi

    check_commands=$(get_check_commands "$1")

    if [ -n "${check_commands}" ]; then
        if [ "${verbose}" == "True" ]; then
            echo "Available commands (in config order, the last one overwrites the others):"
            echo "$check_commands"
        fi

        check_command=$(echo "${check_commands}" | tail -n1)

        echo "Command used by NRPE:"
        echo "    ${check_command}"
    else
        >&2 echo "Warning: no command found in NRPE configuration for check '${1}'."
        if [ "${bypass_nrpe}" = "True" ]; then
            >&2 echo "Aborted."
            exit 1
        fi
    fi

    if [ "${bypass_nrpe}" = "False" ]; then
        request_command="${check_nrpe_bin} -H ${server_address} -p ${server_port} -c check_$1 2&>1"
    else
        request_command="sudo -u nagios -- ${check_command}"
    fi

    if [ "${verbose}" == "True" ]; then
        echo "Executing:"
        echo "    ${request_command}"
    fi

    check_output=$(${request_command})
    rc=$?

    if [ "${bypass_nrpe}" = "False" ]; then
        echo "NRPE service output (on ${server_address}:${server_port}):"
    else
        echo "Direct check output (bypassing NRPE):"
    fi
    echo "${check_output}"

    exit "${rc}"
}


### (EN|DIS)ABLE-ALERTS ACTIONS ##########################

function filter_duration {
    # Format (in brief): XdYhZm
    # Minutes unit 'm' is not mandatory after Xh
    time_regex="^([0-9]+[d])?(([0-9]+[h]([0-9]+[m]?)?)|(([0-9]+[m])?)))?$"

    if [[ "$1" =~ ${time_regex} ]]; then
        echo "$1"
    else
        usage_error "Option --duration: \"$1\" is not a valid duration."
    fi
}

# Check that NRPE commands are wrapped by alerts_wrapper script
function is_nrpe_wrapped {
    for check in $(get_checks_list); do
        command=$(get_check_commands "${check}" | tail -n1)
        echo "${command}" | grep --quiet --no-messages alerts_wrapper
        rc=$?
        if [ "${rc}" -ne 0 ]; then
            >&2 echo "Warning: check '${check}' has no alerts_wrapper, it will not be disabled:"
            >&2 echo "    ${command}"
        fi
    done
}

function disable-alerts {
    # $1: comment

    if ! command -v alerts_switch &> /dev/null; then
        >&2 echo "Error: script 'alerts_switch' is not installed."
        >&2 echo "Aborted."
        exit 1
    fi

    # TODO: Check not disabled yet

    default_msg="."
    if [ "${default_duration}" = "True" ]; then
        default_msg=" (default value).
    Hint: use --duration DURATION to change default time length."
    fi
    cat <<EOF
Alerts will be disabled for ${duration}${default_msg}
Our monitoring system will continue to gather checks outputs, so alerts history won't be lost.
To re-enable alerts before ${duration}, execute (as root or with sudo):
    monitoringctl enable-alerts
EOF
    echo -n "Confirm  (y/N)? "

    read -r answer
    if [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
        log "Action disable-alerts requested for ${duration}: '${1}'"
        for check in $(get_checks_list); do
            # Log a warning if check has no wrapper
            command=$(get_check_commands "${check}" | tail -n1)
            echo "${command}" | grep --quiet --no-messages alerts_wrapper
            rc=$?
            if [ "${rc}" -ne 0 ]; then
                log "Warning: check '${check}' has no alerts_wrapper, it will not be disabled."
            fi

            wrapper_names=$(get_check_commands "${check}" | tail -n1 | awk '{match($0, /.*--name\s+([^[:space:]]+)/, arr); print arr[1]}')
            for name in $(echo "${wrapper_names=}" | tr ',' '\n'); do
                echo "$(now) - Executing 'alerts_switch disable ${name}'" >> "${log_path}"
                alerts_switch disable "${name}"
            done
        done

        #TODO remove previous units if any
        #TODO systemd-run --quiet --unit="" --on-calendar="" -- monitoringctl enable-alerts "[AUTO] ${}"
        echo "Alerts are now disabled for ${duration}."
    else
        echo "Canceled."
    fi

    exit 0
}

function enable-alerts {
    # $1: comment

    #TODO

    echo "Alerts are re-enabled (stub)."
    #echo "Alerts were already enabled."

    exit 0
}


### ALERTS-STATUS ACTION ##########################

function alerts-status {
    # TODO
    true
}


### MAIN #########################################

# No root
if [ "$(id -u)" -ne 0 ]; then
    >&2 echo "You need to be root (or use sudo) to run ${0}!"
    exit 1
fi

# No argument
if [ "$#" = "0" ]; then
    show_help
    exit 1
fi

# Default arguments and options
action=""
comment=""
verbose="False"
duration="1h"
default_duration="True"
bypass_nrpe="False"

# Parse arguments and options
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0;;
        -v|--verbose)
            verbose="True"
            shift;;
        -b|--bypass-nrpe)
            bypass_nrpe="True"
            shift;;
        -d|--duration)
            if [ "${default_duration}" = "False" ]; then
                 usage_error "Option --duration: defined multiple times."
            fi
            if [ "$#" -gt 1 ]; then
                duration=$(filter_duration "$2")
                default_duration="False"
            else
                usage_error "Option --duration: missing value."
            fi
            shift; shift;;
        check|enable-alerts|disable-alerts|alerts-status)
            action="$1"
            shift;;
        *)
            break;;
    esac
done


debian_major_version=$(cut -d "." -f 1 < /etc/debian_version)
conf_lines=$(get_conf_from_file "${conf_path}")


if [ -z "${action}" ]; then
    usage_error "Missing or invalid ACTION argument."
fi

if [ "${action}" = "check" ]; then
    if [ "$#" = 0 ]; then
        usage_error "Action check: missing CHECK_NAME argument."
    fi
    if [ "$#" -gt 1 ]; then
        usage_error "Action check: too many arguments."
    fi
    if [ "${default_duration}" = "False" ]; then
        usage_error "Action check: there is no --duration option."
    fi

    check_name="$1"
    check "$check_name"
fi

if [ "${action}" = "enable-alerts" ]; then
    if [ "$#" = 0 ]; then
        usage_error "Action enable-alerts: missing COMMENT argument."
    fi
    if [ "$#" -gt 1 ]; then
        usage_error "Action enable-alerts: too many arguments."
    fi
    if [ "${default_duration}" = "False" ]; then
        usage_error "Action enable-alerts: there is no --duration option."
    fi

    comment="$1"
    enable-alerts "${comment}"
fi

if [ "${action}" = "disable-alerts" ]; then
    if [ "$#" = 0 ]; then
        usage_error "Action disable-alerts: missing COMMENT argument."
    fi
    if [ "$#" -gt 1 ]; then
        usage_error "Action disable-alerts: too many arguments."
    fi

    is_nrpe_wrapped

    comment="$1"
    disable-alerts "${comment}"
fi

if [ "${action}" = "alerts-status" ]; then
    if [ "$#" -gt 0 ]; then
        usage_error "Action alerts-status: too many arguments."
    fi

    alerts-status
fi

