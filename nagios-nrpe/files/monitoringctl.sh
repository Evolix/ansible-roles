#!/usr/bin/env bash

#set -x

VERSION="24.03.00"

readonly base_dir="/var/lib/monitoringctl"
readonly log_path="/var/log/monitoringctl.log"
readonly conf_path="/etc/nagios/nrpe.cfg"

function show_help {
    cat <<EOF
monitoringctl version ${VERSION}.

monitoringctl gives some control over NRPE checks and alerts.

Usage: monitoringctl [OPTIONS] ACTION ARGUMENTS

GENERAL OPTIONS:

    -h, --help                         Print this message and exit.
    -V, --version                      Print version number and exit.
#    -v, --verbose                      Print more informations.

ACTIONS:

    check [--bypass-nrpe] CHECK_NAME

        Ask CHECK_NAME status to NRPE as an HTTP request.
        Indicates which command NRPE has supposedly run (from its configuration).

        Options:

            -b, --bypass-nrpe          Execute directly command from NRPE configuration,
                                       without requesting to NRPE.

    status

        Print :
        - Wether alerts are enabled or not (silenced).
        - If alerts are disabled (silenced):
            - Comment.
            - Time left before automatic re-enable.

    disable [--during DURATION] 'COMMENT'

        Disable (silence) all alerts (only global for now) for DURATION and write COMMENT into the log.
        Checks output is still printed, so alerts history won't be lost.

        Options:

            -d, --during DURATION    Specify disable duration (default: 1h).

    enable 'COMMENT'

        Re-enable all alerts (only global for now)

COMMENT:

    (mandatory) Comment (string) to be written in log.

DURATION:

    (optional, default: "1h") Time (string) during which alerts will be disabled (silenced).

    Format:
        You can use 'd' (day), 'h' (hour) and 'm' (minute) , or a combination of them, to specify a duration.
        Examples: '2d', '1h', '10m', '1h10' ('m' is guessed).

Log path: ${log_path}

EOF
}

function show_version {
    echo "monitoringctl version ${VERSION}."
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

    server_address=$(echo "$conf_lines" | grep "server_address" | cut -d'=' -f2)
    if [ -z "${server_address}" ]; then server_address="127.0.0.1"; fi

    server_port=$(echo "$conf_lines" | grep "server_port" | cut -d'=' -f2)
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
        usage_error "Option --during: \"$1\" is not a valid duration."
    fi
}

# Check that NRPE commands are wrapped by alerts_wrapper script
function is_nrpe_wrapped {
    for check in $(get_checks_list); do
        cmd=$(get_check_commands "${check}" | tail -n1)
        echo "${cmd}" | grep --quiet --no-messages alerts_wrapper
        rc=$?
        if [ "${rc}" -ne 0 ]; then
            >&2 echo "Warning: check '${check}' has no alerts_wrapper, it will not be disabled:"
            >&2 echo "    ${cmd}"
        fi
    done
}

function disable_alerts {
    # $1: comment

    if ! command -v alerts_switch &> /dev/null; then
        >&2 echo "Error: script 'alerts_switch' is not installed."
        >&2 echo "Aborted."
        exit 1
    fi

    #TODO Are alerts already disabled ?
    # -> mauvais indicateur, cf. le timeout à l'intérieur + le max autorisé dans la commande alerts_wrapper
    #if [ -f "${base_dir}/all_alerts_disabled" ]; then
    #    echo "All alerts are already disabled."
    #    status
    #fi

    default_msg="."
    if [ "${default_duration}" = "True" ]; then
        default_msg=" (default value).
    Hint: use --during DURATION to change default time length."
    fi
    cat <<EOF
Alerts will be disabled for ${duration}${default_msg}
Our monitoring system will continue to gather checks outputs, so alerts history won't be lost.
To re-enable alerts before ${duration}, execute (as root or with sudo):
    monitoringctl enable
EOF
    echo -n "Confirm (y/N)? "
    read -r answer
    if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
        echo "Canceled."
        exit 0
    fi

    log "Action disable requested for ${duration} by user $(logname || echo unknown): '$1'"

    # Log a warning if a check has no wrapper
    for check in $(get_checks_list); do
        command=$(get_check_commands "${check}" | tail -n1)
        if ! echo "${command}" | grep --quiet --no-messages alerts_wrapper; then
            log "Warning: check '${check}' has no alerts_wrapper, it will not be disabled."
        fi
    done

        #wrapper_names=$(get_check_commands "${check}" | tail -n1 | awk '{match($0, /.*--name\s+([^[:space:]]+)/, arr); print arr[1]}')
        #for name in $(echo "${wrapper_names=}" | tr ',' '\n'); do
        #    log "Executing 'alerts_switch disable ${name}'"
        #    alerts_switch disable "${name}"
        #done
    #done

    log "Executing 'alerts_switch disable all --during \"${duration}\"'"
    alerts_switch disable all --during "${duration}"

    echo "All alerts are now disabled for ${duration}."
}

function enable {
    # $1: comment

    log "Action enable requested by user $(logname || echo unknown): '${1}'"
    log "Executing 'alerts_switch enable all'"
    alerts_switch enable all

    echo "All alerts are now enabled."
}


### status ACTION ##########################

# Converts human writable duration into seconds
function duration_to_seconds {
    # $1: duration (XdYhZm…)
    if echo "${1}" | grep -E -q '^([0-9]+[wdhms])+$'; then
        echo "${1}" | sed 's/w/ * 604800 + /g; s/d/ * 86400 + /g; s/h/ * 3600 + /g; s/m/ * 60 + /g; s/s/ + /g; s/+ $//' | xargs expr
    elif echo "${1}" | grep -E -q '^([0-9]+$)'; then
        echo "${1} * 3600" | xargs expr
    else
        return 1
    fi
}

# Converts seconds into human readable duration
function seconds_to_duration {
    # $1: integer (seconds)
    delay="$1"

    delay_days="$(( delay /86400 ))"
    if [ "${delay_days}" -eq 0 ]; then delay_days=""
    else delay_days="${delay_days}d "; fi

    delay_hours="$(( (delay %86400) /3600 ))"
    if [ "${delay_hours}" -eq 0 ]; then delay_hours=""
    else delay_hours="${delay_hours}h "; fi

    delay_minutes="$(( ((delay %86400) %3600) /60 ))"
    if [ "${delay_minutes}" -eq 0 ]; then delay_minutes=""
    else delay_minutes="${delay_minutes}m "; fi

    delay_seconds="$(( ((delay %86400) %3600) %60 ))"
    if [ "${delay_seconds}" -eq 0 ]; then delay_seconds=""
    else delay_seconds="${delay_seconds}s"; fi

    echo "${delay_days}${delay_hours}${delay_minutes}${delay_seconds}"
}

# Get from NRPE / alerts_wrapper options the maximum duration of disable.
# If different values are found for the same disable name, the lowest is keept.
function get_max_disable_duration {
    min_of_max_duration=""
    min_of_max_sec=""
    for check in $(get_checks_list); do
        cmd=$(get_check_commands "${check}" | tail -n1)

        max_duration=$(echo "${cmd}" | awk '{ for (i=1; i<=NF; i++) { if ($i ~ /(-m|--max|--maximum|--limit)[ =]/) print $(i+1) } }')
        if [ -z "${max_duration}" ]; then
            continue
        fi

        max_sec=$(duration_to_seconds "${max_duration}")
        if [ -z "${min_of_max_sec}" ] || [ "${max_sec}" -lt "${min_of_max_sec}" ]; then
            min_of_max_sec="${max_sec}"
            min_of_max_duration="${max_duration}"
        fi
    done
    echo "${min_of_max_duration:-"1d"}" # 1d is alerts_wrapper default --max
}

function disabled_secs_left {
    disabled_file="${base_dir}/all_alerts_disabled"
    if [ ! -e "${disabled_file}" ]; then
        echo 0
        return
    fi

    max_disable_duration="$(get_max_disable_duration)"
    max_disable_secs="$(duration_to_seconds "${max_disable_duration}")"
    disable_secs="$(grep -v -E "^\s*#" "${disabled_file}" | grep -E "[0-9]+" | head -n1 | awk '{print$1}')"

    if [ "${disable_secs}" -gt "${max_disable_secs}" ]; then
        disable_secs="${max_disable_secs}"
    fi
    disable_date=$(date --date "${disable_secs} seconds ago" +"%s")

    last_change=$(stat -c %Z "${disabled_file}")
    echo $(( last_change - disable_date ))
}

function alerts_status {
    local disabled_secs_left=$(disabled_secs_left)
    disabled_duration_left="$(seconds_to_duration "${disabled_secs_left}")"

    if [ -z "${disabled_duration_left}" ]; then
        echo "All alerts are enabled."
    else
        disable_date=$(date --date "+${disabled_secs_left} seconds" "+%d %h %Y at %H:%M:%S")
        echo "All alerts are still disabled for ${disabled_duration_left}."
        echo "They will be re-enabled the ${disable_date}."
    fi
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

debian_major_version=$(cut -d "." -f 1 < /etc/debian_version)
conf_lines=$(get_conf_from_file "${conf_path}")

# Default arguments and options
action=""
comment=""
verbose="False"
duration="1h"
bypass_nrpe="False"
default_duration="True"

# Parse arguments and options
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0;;
        -V|--version)
            show_version
            exit 0;;
        -v|--verbose)
            verbose="True"
            shift;;
        -b|--bypass-nrpe)
            bypass_nrpe="True"
            shift;;
        -d|--during)
            if [ "${default_duration}" = "False" ]; then
                 usage_error "Option --during: defined multiple times."
            fi
            if [ "$#" -gt 1 ]; then
                duration=$(filter_duration "$2")
                default_duration="False"
            else
                usage_error "Option --during: missing value."
            fi
            shift; shift;;
        check|enable|disable|status)
            action="$1"
            shift;;
        *)
            if [ "${action}" = "check" ] && [ -n "$1" ]; then
                if get_checks_list | grep --quiet -E "^$1$"; then
                    check_name=$1
                    shift
                else
                    usage_error "Action check: unknown argument '$1'."
                fi
            else
                # Other arguments are the comment
                break
            fi
            ;;
    esac
done



if [ -z "${action}" ]; then
    usage_error "Missing or invalid ACTION argument."
fi

if [ "${action}" = "check" ]; then
    if [ "$#" -gt 0 ]; then
        usage_error "Action check: too many arguments."
    fi
    if [ "${default_duration}" = "False" ]; then
        usage_error "Action check: there is no --during option."
    fi

    check "$check_name"

elif [ "${action}" = "enable" ]; then
    if [ "$#" = 0 ]; then
        usage_error "Action enable: missing COMMENT argument."
    fi
    if [ "$#" -gt 1 ]; then
        usage_error "Action enable: too many arguments."
    fi
    if [ "${default_duration}" = "False" ]; then
        usage_error "Action enable: there is no --during option."
    fi

    comment="$1"
    enable "${comment}"

elif [ "${action}" = "disable" ]; then
    if [ "$#" = 0 ]; then
        usage_error "Action disable: missing COMMENT argument."
    fi
    if [ "$#" -gt 1 ]; then
        usage_error "Action disable: too many arguments."
    fi

    is_nrpe_wrapped

    comment="$1"
    disable_alerts "${comment}"

elif [ "${action}" = "status" ]; then
    if [ "$#" -gt 0 ]; then
        usage_error "Action status: too many arguments."
    fi

    alerts_status
fi

