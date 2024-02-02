#!/usr/bin/env bash

#set -x

log_path="/var/log/monitoringctl.log"
conf_path="/etc/nagios/nrpe.cfg"

function show_help {
    cat <<EOF

monitoringctl gives some control over NRPE checks and alerts.

Usage: monitoringctl [OPTIONS] ACTION ARGUMENTS

OPTIONS:

    -h, --help                  Print this message and exit.
    -v, --verbose               Print more informations.
    -f, --for DURATION          Specify disable-alerts duration (default: 1h).

ACTIONS:

    check CHECK_NAME

        Ask CHECK_NAME status to NRPE as an HTTP request (on 127.0.0.1:5666).
        Also show command that NRPE has supposedly run.

    alerts-status

        Print :
        - Whether alerts are enabled or not (silenced).
        - If alerts are disabled (silenced):
            - Comment.
            - Time left before automatic re-enable.

    disable-alerts [--for DURATION] 'COMMENT'

        Disable (silence) all alerts (only global for now) for DURATION and write COMMENT into the log.
        Checks output is still printed, so alerts history won't be lost.

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


### CHECK ACTION ##########################

# Print NRPE configuration without comments and in the same order
# than Nagios (taking account that order changes from Deb10)
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


function grep_conf {
    # $1: check name (load, disk1…)
    # $2: nrpe conf file (.cfg)
    grep -E -R --no-filename "^\s*(include(_dir)?=.+|command\[check_$1\])" "$2" | grep -v -E '^[[:blank:]]*#'
}

# Print check commands, in the same order as they are declared in the conf,
# with respect to the include and include_dir directives, which are
# explored recursively.
function get_config_file_checks {
    # $1: check name (load, disk1…)
    # $2: nrpe conf file (.cfg)
    conf_lines=$(grep_conf "$1" "$2")
    while read -r line; do
        if [[ "${line}" =~ .*"check_$1".* ]]; then
            echo "${line}" | cut -d'=' -f2-

        elif [[ "${line}" =~ .*'include='.* ]]; then
            conf_file=$(echo "${line}" | cut -d= -f2)
            get_config_file_checks "$1" "${conf_file}"

        elif [[ "${line}" =~ .*'include_dir='.* ]]; then
            conf_dir=$(echo "${line}" | cut -d= -f2)
            get_config_dir_checks "$1" "${conf_dir}"
        fi

    done <<< "${conf_lines}"
}

# Same as get_config_file_checks, but for a recursive search in a directory.
function get_config_dir_checks {
    # $1: check name (load, disk1…)
    # $2: nrpe conf dir
    if [ "${debian_major_version}" -ge 10 ]; then
        # From Deb10, NRPE use scandir() with alphasort() function
        sort_command="sort"
    else
        # Before Deb10, NRPE use loaddir(), like find utility
        sort_command="cat -"
    fi
    # Add conf files in dir to be processed recursively
    for file in $(find "$2" -maxdepth 1 -name "*.cfg" | ${sort_command}); do
        if [ -f "${file}" ]; then
            get_config_file_checks "$1" "${file}"
        elif [ -d "${file}" ]; then
            get_config_dir_checks "$1" "${file}"
        fi
    done
}

function check {
    check_nrpe_bin=/usr/lib/nagios/plugins/check_nrpe
    debian_major_version=$(cut -d "." -f 1 < /etc/debian_version)

    if [ ! -f "${check_nrpe_bin}" ]; then
        >&2 echo "${check_nrpe_bin} is missing, please install nagios-nrpe-plugin package."
        exit 1
    fi

    conf_lines=$(get_conf_from_file "${conf_path}")

    server_address=$(echo "$conf_lines" | grep "server_address"  | cut  -d'=' -f2)
    if [ -z "${server_address}" ]; then server_address="127.0.0.1"; fi

    server_port=$(echo "$conf_lines" | grep "server_port"  | cut  -d'='  -f2)
    if [ -z "${server_port}" ]; then server_port="5666"; fi

    found_commands=$(echo "$conf_lines" | grep -E "command\[check_$1\]" | cut -d'=' -f2-)

    if [ -n "${found_commands}" ]; then

        if [ "${verbose}" == "True" ]; then
            echo "Available commands (in config order, the last one overwrites the others):"
            echo "$found_commands"
        fi

        nrpe_command=$(echo "${found_commands}" | tail -n1)

        echo "Command used by NRPE:"
        echo "    ${nrpe_command}"

    else
        >&2 echo "No command found in NRPE configuration for this check:"
        >&2 echo "    $1"
    fi

    request_command="${check_nrpe_bin} -H ${server_address} -p ${server_port} -c check_$1 2&>1"

    if [ "${verbose}" == "True" ]; then
        echo "Executing:"
        echo "    ${request_command}"
    fi

    check_output=$(${request_command})
    rc=$?

    echo "NRPE service output (on ${server_address}:5666):"
    echo "${check_output}"

    exit "${rc}"
}


### (EN|DIS)ABLE-ALERT ACTION ##########################

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


function disable-alerts {

    #TODO

    # TODO: Check not disabled yet

    default_msg="."
    if [ "${default_duration}" = "True" ]; then
        default_msg=" (default value).
    Hint: use --duration DURATION to change default time length."
    fi
    cat <<EOF
Warning: alerts will be disabled for ${duration}${default_msg}
Check outputs will still be gathered by our monitoring system, so alerts history won't be lost.
To re-enable alerts before ${duration}, execute (as root or with sudo):
    monitoringctl enable-alerts
EOF
    echo -n "Confirm  (y/N)? "

    read -r answer
    if [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
        #systemd-run --quiet --unit="" --on-calendar="" 
        echo "Alerts are now disabled for ${duration}."
    else
        echo "Canceled."
    fi

    exit 0
}



function enable-alerts {

    #TODO

    echo "Alerts are re-enabled."
    #echo "Alerts were already enabled."

    exit 0
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

# Parse arguments and options
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0;;
        -v|--verbose)
            verbose="True"
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

    comment="$1"
    disable-alerts "${comment}"
fi

