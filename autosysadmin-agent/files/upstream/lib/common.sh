#!/bin/bash

VERSION="24.03.2"

# Common functions for "repair" and "restart" scripts

set -u

# Initializes the program, context, configuration…
initialize() {
    PATH="${PATH}":/usr/sbin:/sbin

    # Used in many places to refer to the program name.
    # Examples: repair_mysql, restart_nrpe…
    PROGNAME=$(basename "${0}")

    # find out if running in interactive mode, or not
    if [ -t 0 ]; then
        INTERACTIVE=1
    else
        INTERACTIVE=0
    fi
    readonly INTERACTIVE

    # Default empty value for Debug mode
    DEBUG="${DEBUG:-""}"

    # Repair scripts obey to the value of a variable named after the script
    # You can set the value ("on" or "off") in /etc/evolinux/autosysadmin
    # Here we set the default value to "on".
    declare -g "${PROGNAME}"=on  # dynamic variable assignment ($PROGNAME == repair_*)

    PID=$$
    readonly PID

    # Each execution (run) gets a unique ID
    RUN_ID="$(date +"%Y-%m-%d_%H-%M")_${PROGNAME}_${PID}"
    readonly RUN_ID

    # Main log directory
    MAIN_LOG_DIR="/var/log/autosysadmin"
    readonly MAIN_LOG_DIR
    # shellcheck disable=SC2174
    mkdir --mode=750 --parents "${MAIN_LOG_DIR}"
    chgrp adm "${MAIN_LOG_DIR}"

    # Each execution store some information
    # in a unique directory based on the RUN_ID
    RUN_LOG_DIR="${MAIN_LOG_DIR}/${RUN_ID}"
    readonly RUN_LOG_DIR
    # shellcheck disable=SC2174
    mkdir --mode=750 --parents "${RUN_LOG_DIR}"
    chgrp adm "${RUN_LOG_DIR}"

    # This log file contains all events
    RUN_LOG_FILE="${RUN_LOG_DIR}/autosysadmin.log"
    readonly RUN_LOG_FILE

    # This log file contains notable actions
    ACTIONS_FILE="${RUN_LOG_DIR}/actions.log"
    readonly ACTIONS_FILE
    touch "${ACTIONS_FILE}"
    # This log file contains abort reasons (if any)
    ABORT_FILE="${RUN_LOG_DIR}/abort.log"
    readonly ABORT_FILE
    # touch "${ABORT_FILE}"

    # Date format for log messages
    DATE_FORMAT="%Y-%m-%d %H:%M:%S"

    # This will contain lock, last-run markers…
    # It's ok to lose the content after a reboot
    RUN_DIR="/run/autosysadmin"
    readonly RUN_DIR
    mkdir -p "${RUN_DIR}"

    # Only a singe instace of each script can run simultaneously
    # We use a customizable lock name for this.
    # By default it's the script's name
    LOCK_NAME=${LOCK_NAME:-${PROGNAME}}
    # If a lock is found, we can wait for it to disappear.
    # The value must be understood by sleep(1)
    LOCK_WAIT="0"

    # Default values for email headers
    EMAIL_FROM="equipe+autosysadmin@evolix.net"
    EMAIL_INTERNAL="autosysadmin@evolix.fr"

    LOCK_FILE="${RUN_DIR}/${LOCK_NAME}.lock"
    readonly LOCK_FILE
    # Remove lock file at exit
    cleanup() {
        # shellcheck disable=SC2317
        rm -f "${LOCK_FILE}"
    }
    trap 'cleanup' 0

    # Load configuration
    # shellcheck disable=SC1091
    test -f /etc/evolinux/autosysadmin && source /etc/evolinux/autosysadmin

    log_all "Begin ${PROGNAME} RUN_ID: ${RUN_ID}"
    log_all "Log directory is ${RUN_LOG_DIR}"
}

# Executes a list of tasks before exiting:
# * prepare a summary of actions and possible abort reasons
# * send emails
# * do some cleanup
quit() {
    log_all "End ${PROGNAME} RUN_ID: ${RUN_ID}"

    summary="RUN_ID: ${RUN_ID}"
    if [ -s "${ABORT_FILE}" ]; then
        # Add abort reasons to summary
        summary="${summary}\n$(print_abort_reasons)"
        hook_mail "abort"

        return_code=1
    else
        if [ -s "${ACTIONS_FILE}" ]; then
            # Add notable actions to summary
            summary="${summary}\n$(print_actions "Aucune action")"
            hook_mail "success"
        fi

        return_code=0
    fi

    hook_mail "internal"

    if is_interactive; then
        # shellcheck disable=SC2001
        echo "${summary}" | sed -e 's/\\n/\n/g'
    else
        /usr/share/scripts/evomaintenance.sh --auto --user autosysadmin --message "${summary}" --no-commit --no-mail
    fi

    teardown

    # shellcheck disable=SC2086
    exit ${return_code}
}

teardown() {
    :
}

# Return true/false
is_interactive() {
    test "${INTERACTIVE}" -eq "1"
}

save_server_state() {
    DUMP_SERVER_STATE_BIN="$(command -v dump-server-state || command -v backup-server-state)"

    if [ -z "${DUMP_SERVER_STATE_BIN}" ]; then
        log_all "Warning: dump-server-state is not present. No server state recorded."
    fi

    if [ -x "${DUMP_SERVER_STATE_BIN}" ]; then
        DUMP_DIR=$(file_path_in_log_dir "server-state")
        # We don't want the logging to take too much time,
        # so we kill it if it takes more than 20 seconds.
        timeout --signal 9 20          \
            "${DUMP_SERVER_STATE_BIN}" \
            --dump-dir="${DUMP_DIR}"   \
            --df                       \
            --dmesg                    \
            --iptables                 \
            --lxc                      \
            --netcfg                   \
            --netstat                  \
            --uname                    \
            --processes                \
            --systemctl                \
            --uptime                   \
            --virsh                    \
            --disks                    \
            --mysql-processes          \
            --no-apt-states            \
            --no-apt-config            \
            --no-dpkg-full             \
            --no-dpkg-status           \
            --no-mount                 \
            --no-packages              \
            --no-sysctl                \
            --no-etc

        log_run "Server state saved in \`server-state' directory."
    fi
}

is_debug() {
    # first time: do the check…
    # other times: pass
    if [ -z "${DEBUG:-""}" ]; then
        debug_file="/etc/evolinux/autosysadmin.debug"

        if [ -e "${debug_file}" ]; then
            last_change=$(stat -c %Z "${debug_file}")
            limit_date=$(date --date "14400 seconds ago" +"%s")

            if [ $(( last_change - limit_date )) -le "0" ]; then
                log_run "Debug mode disabled; file is too old (%{last_change} seconds)."
                rm "${debug_file}"
                # Debug mode disabled
                DEBUG="0"
            else
                log_run "Debug mode enabled."
                # Debug mode enabled
                DEBUG="1"
            fi
        else
            # log_run "Debug mode disabled; file is absent."
            # Debug mode disabled
            DEBUG="0"
        fi
    fi
    # return the value
    test "${DEBUG}" -eq "1"
}

# Uses the who(1) definition of "active"
currently_active_users() {
    LC_ALL=C who --users | grep --extended-regexp "\s+\.\s+" | awk '{print $1}' | sort --human-numeric-sort | uniq
}
# Users active in the last 29 minutes
recently_active_users() {
    LC_ALL=C who --users | grep --extended-regexp "\s+00:(0|1|2)[0-9]\s+" | awk --field-separator ' ' '{print $1,$6}'
}
# Save the list of users to a file in the log directory
save_active_users() {
    LC_ALL=C who --users | save_in_log_dir "who-users"
}

# An autosysadmin must not perform actions if a user is active or was active recently.
#
# This can by bypassed in interactive mode.
# It's OK to lose this data after a reboot.
ensure_no_active_users_or_exit() {
    # Save all active users
    save_active_users

    if is_debug; then
        log_run "Debug mode enabled: continue without checking active users."
        return 0;
    fi

    # Is there any currently active user?
    currently_active_users=$(currently_active_users)
    if [ -n "${currently_active_users}" ]; then
        # shellcheck disable=SC2001
        users_oneliner=$(echo "${currently_active_users}" | sed -e 's/\n/ /')
        log_run "Currently active users: ${users_oneliner}"
        if is_interactive; then
            echo "Some users are currently active:"
            # shellcheck disable=SC2001
            echo "${currently_active_users}" | sed -e 's/\(.\+\)/* \1/'
            answer=""
            while :; do
                printf "> Continue? [Y,n,?] "
                read -r answer
                case ${answer} in
                    [Yy]|"" )
                        log_run "Active users check bypassed manually in interactive mode."
                        return
                        ;;
                    [Nn] )
                        log_run "Active users check confirmed manually in interactive mode."
                        log_abort_and_quit "Active users detected: ${users_oneliner}"
                        ;;
                    * )
                        printf "y - yes, continue\n"
                        printf "n - no, exit\n"
                        printf "? - print this help\n"
                        ;;
                esac
            done
        else
            log_abort_and_quit "Currently active users detected: ${users_oneliner}."
        fi
    else
        # or recently (the last 30 minutes) active user?
        recently_active_users=$(recently_active_users)
        if [ -n "${recently_active_users}" ]; then
            # shellcheck disable=SC2001
            users_oneliner=$(echo "${recently_active_users}" | sed -e 's/\n/ /')
            log_run "Recently active users: ${users_oneliner}"
            if is_interactive; then
                echo "Some users were recently active:"
                # shellcheck disable=SC2001
                echo "${recently_active_users}" | sed -e 's/\(.\+\)/* \1/'
                answer=""
                while :; do
                    printf "> Continue? [Y,n,?] "
                    read -r answer
                    case ${answer} in
                        [Yy]|"" )
                            log_run "Active users check bypassed manually in interactive mode."
                            return
                            ;;
                        [Nn] )
                            log_run "Active users check confirmed manually in interactive mode."
                            log_abort_and_quit "Recently active users detected: ${users_oneliner}."
                            ;;
                        * )
                            printf "y - yes, continue\n"
                            printf "n - no, exit\n"
                            printf "? - print this help\n"
                            ;;
                    esac
                done
            else
                log_abort_and_quit "Recently active users detected: ${users_oneliner}."
            fi
        fi
    fi
}

# Takes an NRPE command name as 1st parameter,
# and executes the full command if found in the configuration.
# Return the result and the return code of the command.
check_nrpe() {
    check="$1"

    nrpe_files=""

    # Check if NRPE config is found
    if [ -f "/etc/nagios/nrpe.cfg" ]; then
        nrpe_files="${nrpe_files} /etc/nagios/nrpe.cfg"
    else
        msg="NRPE configuration not found: /etc/nagios/nrpe.cfg"
        log_run "${msg}"
        echo "${msg}"
        return 3
    fi

    # Search for included files
    # shellcheck disable=SC2086
    while IFS= read -r include_file; do
        nrpe_files="${nrpe_files} ${include_file}"
    done < <(grep --extended-regexp '^\s*include=.+' ${nrpe_files} | cut -d = -f 2)

    # Search for files in included directories
    # shellcheck disable=SC2086
    while IFS= read -r include_dir; do
        nrpe_files="${nrpe_files} ${include_dir}/*.cfg"
    done < <(grep --extended-regexp '^\s*include_dir=.+' ${nrpe_files} | cut -d = -f 2)

    # Fetch uncommented commands in (sorted) config files
    # shellcheck disable=SC2086
    nrpe_commands=$(grep --no-filename --exclude=*~ --fixed-strings "[${check}]" ${nrpe_files} | grep --invert-match --extended-regexp '^\s*#\s*command' | cut -d = -f 2)
    nrpe_commands_count=$(echo "${nrpe_commands}" | wc -l)

    if is_debian_version "9" "<=" && [ "${nrpe_commands_count}" -gt "1" ]; then
        # On Debian <= 9, NRPE loading was not sorted
        # we need to raise an error if we have multiple defined commands
        msg="Unable to determine which NRPE command to run"
        log_run "${msg}"
        echo "${msg}"
        return 3
    else
        # On Debian > 9, use the last command
        nrpe_command=$(echo "${nrpe_commands}" | tail -n 1)

        nrpe_result=$(${nrpe_command})
        nrpe_rc=$?

        log_run "NRPE command (exited with ${nrpe_rc}): ${nrpe_command}"
        log_run "${nrpe_result}"

        echo "${nrpe_result}"
        return "${nrpe_rc}"
    fi
}

# An autosysadmin script must not run twice (or more) simultaneously.
# We use a customizable (with LOCK_NAME) lock file to keep track of this.
# A wait time can be configured.
#
# This can by bypassed in interactive mode.
# It's OK to lose this data after a reboot.
acquire_lock_or_exit() {
    lock_file="${1:-${LOCK_FILE}}"
    lock_wait="${2:-${LOCK_WAIT}}"

    # lock_wait must be compatible with sleep(1), otherwise fallback to 0
    if ! echo "${lock_wait}" | grep -Eq '^[0-9]+[smhd]?$'; then
        log_run "Lock wait: incorrect value '${lock_wait}', fallback to 0."
        lock_wait=0
    fi

    if [ "${lock_wait}" != "0" ] && [ -f "${lock_file}" ]; then
        log_run "Lock file present. Let's wait ${lock_wait} and check again."
        sleep "${lock_wait}"
    fi

    if [ -f "${lock_file}" ]; then
        log_abort_and_quit "Lock file still present."
    else
        log_run "Lock file absent. Let's put one."
        touch "${lock_file}"
    fi
}

# If a script has been run in the ast 30 minutes, running it again won't fix the issue.
# We use a /run/ausosysadmin/${PROGNAME}_lastrun file to keep track of this.
# 
# This can by bypassed in interactive mode.
# This is bypassed in debug mode.
# It's OK to lose this data after a reboot.
ensure_not_too_soon_or_exit() {
    if is_debug; then
        log_run "Debug mode enabled: continue without checking when was the last run."
        return 0;
    fi

    lastrun_file="${RUN_DIR}/${PROGNAME}_lastrun"
    if [ -f "${lastrun_file}" ]; then
        lastrun_age="$(($(date +%s)-$(stat -c "%Y" "${lastrun_file}")))"
        log_run "Last run was ${lastrun_age} seconds ago."
        if [ "${lastrun_age}" -lt 1800 ]; then
            if is_interactive; then
                echo "${PROGNAME} was run ${lastrun_age} seconds ago."
                answer=""
                while :; do
                    printf "> Continue? [Y,n,?] "
                    read -r answer
                    case ${answer} in
                        [Yy]|"" )
                            log_run "Last run check bypassed manually in interactive mode."
                            break
                            ;;
                        [Nn] )
                            log_run "Last run check confirmed manually in interactive mode."
                            log_abort_and_quit 'Last run too recent.'
                            ;;
                        * )
                            printf "y - yes, continue\n"
                            printf "n - no, exit\n"
                            printf "? - print this help\n"
                            ;;
                    esac
                done
            else
                log_abort_and_quit "Last run too recent."
            fi
        fi
    fi
    touch "${lastrun_file}"
}

# Populate DEBIAN_VERSION and DEBIAN_RELEASE variables
# based on gathered information about the operating system
detect_os() {
    DEBIAN_RELEASE="unknown"
    DEBIAN_VERSION="unknown"
    LSB_RELEASE_BIN="$(command -v lsb_release)"

    if [ -e /etc/debian_version ]; then
        DEBIAN_VERSION="$(cut -d "." -f 1 < /etc/debian_version)"
        if [ -x "${LSB_RELEASE_BIN}" ]; then
            DEBIAN_RELEASE="$("${LSB_RELEASE_BIN}" --codename --short)"
        else
            case "${DEBIAN_VERSION}" in
                 7) DEBIAN_RELEASE="wheezy"   ;;
                 8) DEBIAN_RELEASE="jessie"   ;;
                 9) DEBIAN_RELEASE="stretch"  ;;
                10) DEBIAN_RELEASE="buster"   ;;
                11) DEBIAN_RELEASE="bullseye" ;;
                12) DEBIAN_RELEASE="bookworm" ;;
                13) DEBIAN_RELEASE="trixie"   ;;
            esac
        fi
    #    log_run "Detected OS: Debian version=${DEBIAN_VERSION} release=${DEBIAN_RELEASE}"
    # else
    #    log_run "Detected OS: unknown (missing /etc/debian_version)"
    fi
}

is_debian_wheezy() {
    test "${DEBIAN_RELEASE}" = "wheezy"
}
is_debian_jessie() {
    test "${DEBIAN_RELEASE}" = "jessie"
}
is_debian_stretch() {
    test "${DEBIAN_RELEASE}" = "stretch"
}
is_debian_buster() {
    test "${DEBIAN_RELEASE}" = "buster"
}
is_debian_bullseye() {
    test "${DEBIAN_RELEASE}" = "bullseye"
}
is_debian_bookworm() {
    test "${DEBIAN_RELEASE}" = "bookworm"
}
is_debian_trixie() {
    test "${DEBIAN_RELEASE}" = "trixie"
}
is_debian_version() {
    local version=$1
    local relation=${2:-"eq"}

    if [ -z "${DEBIAN_VERSION:-""}" ]; then
        detect_os
    fi

    dpkg --compare-versions "${DEBIAN_VERSION}" "${relation}" "${version}"
}

# List systemd services (only names), even if stopped
systemd_list_services() {
    pattern=$1

    systemctl list-units --all --no-legend --type=service "${pattern}" | grep --only-matching --extended-regexp '\S+\.service'
}

is_systemd_enabled() {
    systemctl --quiet is-enabled "$1" 2> /dev/null
}

is_systemd_active() {
    systemctl --quiet is-active "$1" 2> /dev/null
}

is_sysvinit_enabled() {
    find /etc/rc2.d/ -name "$1" > /dev/null
}

get_fqdn() {
    # shellcheck disable=SC2155
    local system=$(uname -s)

    if [ "${system}" = "Linux" ]; then
        hostname --fqdn
    elif [ "${system}" = "OpenBSD" ]; then
        hostname
    else
        log_abort_and_quit "System '${system}' not recognized."
    fi
}

get_complete_hostname() {
    REAL_HOSTNAME="$(get_fqdn)"
    if [ "${HOSTNAME}" = "${REAL_HOSTNAME}" ]; then
        echo "${HOSTNAME}"
    else
        echo "${HOSTNAME} (${REAL_HOSTNAME})"
    fi
}
# Fetch values from evomaintenance configuration
get_evomaintenance_mail() {
    grep "EVOMAINTMAIL=" /etc/evomaintenance.cf | cut -d '=' -f2
}
get_evomaintenance_emergency_mail() {
    grep "URGENCYFROM=" /etc/evomaintenance.cf | cut -d '=' -f2
}
get_evomaintenance_emergency_tel() {
    grep "URGENCYTEL=" /etc/evomaintenance.cf | cut -d '=' -f2
}

# Log a message to the log file in the log directory
log_run() {
    local msg="${1:-$(cat /dev/stdin)}"
    # shellcheck disable=SC2155
    local date=$(/bin/date +"${DATE_FORMAT}")

    printf "[%s] %s[%s]: %s\\n" \
        "${date}" "${PROGNAME}" "${PID}" "${msg}" \
        >> "${RUN_LOG_FILE}"
}
# Log a message in the system log file (syslog or journald)
log_global() {
    local msg="${1:-$(cat /dev/stdin)}"

    echo "${msg}" \
        | /usr/bin/logger -p local0.notice -t autosysadmin
}
# Log a message in both places
log_all() {
    local msg="${1:-$(cat /dev/stdin)}"

    log_global "${msg}"
    log_run "${msg}"
}
# Log a notable action in regular places
# and append it to the dedicated list
log_action() {
    log_all "$*"
    append_action "$*"
}
# Append a line in the actions.log file in the log directory
append_action() {
    echo "$*" >> "${ACTIONS_FILE}"
}
# Print the content of the actions.log file
# or a fallback content (1st parameter) if empty
# shellcheck disable=SC2120
print_actions() {
    local fallback=${1:-""}
    if [ -s "${ACTIONS_FILE}" ]; then
        cat "${ACTIONS_FILE}"
    elif [ -n "${fallback}" ]; then
        echo "${fallback}"
    fi
}

# Log a an abort reason in regular places
# and append it to the dedicated list
log_abort() {
    log_all "$*"
    append_abort_reason "$*"
}
# Append a line in the abort.log file in the log directory
append_abort_reason() {
    echo "$*" >> "${ABORT_FILE}"
}
# Print the content of the abort.log file
# or a fallback content (1st parameter) if empty
# shellcheck disable=SC2120
print_abort_reasons() {
    local fallback=${1:-""}
    if [ -s "${ABORT_FILE}" ]; then
        cat "${ABORT_FILE}"
    elif [ -n "${fallback}" ]; then
        echo "${fallback}"
    fi
}
# Print the content of the main log from the log directory
print_main_log() {
    cat "${RUN_LOG_FILE}"
}
# Log an abort reason and quit the script
log_abort_and_quit() {
    log_abort "$*"
    quit
}

# Store the content from standard inpu
# into a file in the log directory named after the 1st parameter
save_in_log_dir() {
    local file_name=$1
    local file_path="${RUN_LOG_DIR}/${file_name}"

    cat /dev/stdin > "${file_path}"

    log_run "Saved \`${file_name}' file."
}
# Return the full path of the file in log directory
# based on the name in the 1st parameter
file_path_in_log_dir() {
    echo "${RUN_LOG_DIR}/${1}"
}

format_mail_success() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <${EMAIL_FROM}>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: ${PROGNAME}
X-RunId: ${RUN_ID}
To: ${EMAIL_CLIENT:-alert5@evolix.fr}
Cc: ${EMAIL_INTERNAL}
Subject: [autosysadmin] Intervention automatisée sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatisée vient de se terminer.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)
Script déclenché : ${PROGNAME}

### Actions réalisées

$(print_actions "Aucune")

### Réagir à cette intervention

Vous pouvez répondre à ce message (${EMAIL_FROM}).

En cas d'urgence, utilisez l'adresse ${EMERGENCY_MAIL}
ou notre ligne d'astreinte (${EMERGENCY_TEL})

--
Votre AutoSysadmin
EOTEMPLATE
}

format_mail_abort() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <${EMAIL_FROM}>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: ${PROGNAME}
X-RunId: ${RUN_ID}
To: ${EMAIL_CLIENT:-alert5@evolix.fr}
Cc: ${EMAIL_INTERNAL}
Subject: [autosysadmin] Intervention automatisée interrompue sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatisée a été déclenchée mais s'est interrompue.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)
Script déclenché : ${PROGNAME}

### Actions réalisées

$(print_actions "Aucune")

### Raison(s) de l'interruption

$(print_abort_reasons "Inconnue")

### Réagir à cette intervention

Vous pouvez répondre à ce message (${EMAIL_FROM}).

En cas d'urgence, utilisez l'adresse ${EMERGENCY_MAIL}
ou notre ligne d'astreinte (${EMERGENCY_TEL})

--
Votre AutoSysadmin
EOTEMPLATE
}

# shellcheck disable=SC2028
print_report_information() {
    echo "**Uptime**"
    echo ""
    uptime
    
    echo ""
    echo "**Utilisateurs récents**"
    echo ""
    who_file=$(file_path_in_log_dir "who-users")
    if [ -s "${who_file}" ]; then
        cat "${who_file}"
    else
        who --users
    fi
    
    echo ""
    echo "**Espace disque**"
    echo ""
    df_file=$(file_path_in_log_dir "server-state/df.txt")
    if [ -s "${df_file}" ]; then
        cat "${df_file}"
    else
        df -h
    fi
    
    echo ""
    echo "**Dmesg**"
    echo ""
    dmesg_file=$(file_path_in_log_dir "server-state/dmesg.txt")
    if [ -s "${dmesg_file}" ]; then
        tail -n 5 "${dmesg_file}"
    else
        dmesg | tail -n 5
    fi
    
    echo ""
    echo "**systemd failed services**"
    echo ""
    failed_services_file=$(file_path_in_log_dir "server-state/systemctl-failed-services.txt")
    if [ -s "${failed_services_file}" ]; then
        cat "${failed_services_file}"
    else
        systemctl --no-legend --state=failed --type=service
    fi

    if command -v lxc-ls > /dev/null 2>&1; then
        echo ""
        echo "**LXC containers**"
        echo ""
        lxc_ls_file=$(file_path_in_log_dir "server-state/lxc-list.txt")
        if [ -s "${lxc_ls_file}" ]; then
            cat "${lxc_ls_file}"
        else
            lxc-ls --fancy
        fi
    fi

    apache_errors_file=$(file_path_in_log_dir "apache-errors.log")
    if [ -f "${apache_errors_file}" ]; then
        echo ""
        echo "**Apache errors**"
        echo ""
        cat "${apache_errors_file}"
    fi

    nginx_errors_file=$(file_path_in_log_dir "nginx-errors.log")
    if [ -f "${nginx_errors_file}" ]; then
        echo ""
        echo "**Nginx errors**"
        echo ""
        cat "${nginx_errors_file}"
    fi
}

format_mail_internal() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <${EMAIL_FROM}>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: ${PROGNAME}
X-RunId: ${RUN_ID}
To: ${EMAIL_INTERNAL}
Subject: [autosysadmin] Rapport interne d'intervention sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatique vient de se terminer.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)
Script déclenché : ${PROGNAME}

### Actions réalisées

$(print_actions "Aucune")

### Raison(s) de l'interruption

$(print_abort_reasons "Aucune")

### Log autosysadmin

$(print_main_log)

### Informations additionnelles

$(print_report_information)

--
Votre AutoSysadmin
EOTEMPLATE
}

# Generic function to send emails at the end of the script.
# Takes a template as 1st parameter
hook_mail() {
    if is_debug; then
        log_run "Debug mode enabled: continue without sending mail."
        return 0;
    fi

    HOSTNAME="${HOSTNAME:-"$(get_fqdn)"}"
    HOSTNAME_TEXT="$(get_complete_hostname)"
    EMAIL_CLIENT="$(get_evomaintenance_mail)"
    EMERGENCY_MAIL="$(get_evomaintenance_emergency_mail)"
    EMERGENCY_TEL="$(get_evomaintenance_emergency_tel)"

    MAIL_CONTENT="$(format_mail_"$1")"

    SENDMAIL_BIN="$(command -v sendmail)"

    if [ -z "${SENDMAIL_BIN}" ]; then
        log_global "ERROR: No \`sendmail' command has been found, can't send mail."
    fi
    if [ -x "${SENDMAIL_BIN}" ]; then
        echo "${MAIL_CONTENT}" | "${SENDMAIL_BIN}" -oi -t -f "equipe@evolix.fr"
        log_global "Sent '$1' mail for RUN_ID: ${RUN_ID}"
    fi
}

is_holiday() {
    # gcal mark today as a holiday by surrounding with < and > the day
    # of the month of that holiday line.  For example if today is 2022-05-01 we'll
    # get among other lines:
    # Fête du Travail (FR)                    + Di, < 1>Mai 2022
    # Jour de la Victoire (FR)                + Di, : 8:Mai 2022 =   +7 jours
    LANGUAGE=fr_FR.UTF-8 TZ=Europe/Paris gcal --cc-holidays=fr --holiday-list=short | grep -E '<[0-9 ]{2}>' --quiet
}

is_weekend() {
    day_of_week=$(date +%u)
    if [ "${day_of_week}" != 6 ] && [ "${day_of_week}" != 7 ]; then
        return 1
    fi
}

is_workday() {
    if is_holiday || is_weekend; then
        return 1
    fi
}

is_worktime() {
    if ! is_workday; then
        return 1
    fi

    hour=$(date +%H)
    if [ "${hour}" -lt 9 ] || { [ "${hour}" -ge 12 ] && [ "${hour}" -lt 14 ] ; } || [ "${hour}" -ge 18 ]; then
        return 1
    fi
}
