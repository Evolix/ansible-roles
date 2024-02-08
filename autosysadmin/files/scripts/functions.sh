#!/bin/bash

get_system() {
    uname -s
}

get_fqdn() {
    if [ "$(get_system)" = "Linux" ]; then
        hostname --fqdn
    elif [ "$(get_system)" = "OpenBSD" ]; then
        hostname
    else
        log_error_exit "OS not detected!"
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

get_evomaintenance_mail() {
    email="$(grep "EVOMAINTMAIL=" /etc/evomaintenance.cf | cut -d '=' -f2)"

    if [[ -z "$email" ]]; then
        email='alert5@evolix.fr'
    fi

    echo "${email}"
}

arguments="${*}"

get_argument() {
  no_found=1
  for argument in ${arguments} ; do
    if [ "${argument}" = "${1}" ] ;
    then
      no_found=0
    fi
  done
  return ${no_found}
}

internal_info() {
    INTERNAL_INFO="$(printf '%b\n%s' "${INTERNAL_INFO}" "$*")"
}

log_action() {
    log "Action : $*"
    ACTIONS="$(printf '%s\n%s' "${ACTIONS}" "$*")"
}

log() {
    INTERNAL_LOG="$(printf '%s\n%s %s %s %s' "${INTERNAL_LOG}" "$(date -Isec)" "$(hostname)" "$(basename "$0")" "$*")"
    printf '%s %s %s %s\n' "$(date -Isec)" "$(hostname)" "$(basename "$0")" "$*" | tee -a "${LOG_DIR}/autosysadmin.log"
    echo "$*" | /usr/bin/logger -p local0.notice -t autosysadmin."$0"
}

log_error_exit() {
    log "ERROR : $*"
    AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: $*" --no-commit --no-mail
    exit 1
}

log_check_php_fpm() {

    # Extraire seulement les chiffres du nom du script exécuté
    # ./repair_php_fpm81.sh ==> 81
    PHP_VERSION="${0//[^0-9]/}"

    PHP_PATH_POOL=$(find /var/lib/lxc/php"${PHP_VERSION}"/ -type d -name "pool.d")
    /usr/local/lib/nagios/plugins/check_phpfpm_multi  "${PHP_PATH_POOL}" > "${LOG_DIR}/nrpe.txt"
}

log_system_status() {
    DUMP_SERVER_STATE_BIN="$(command -v dump-server-state || command -v backup-server-state)"

    if [ -z "${DUMP_SERVER_STATE_BIN}" ]; then
        log "Warning: dump-server-state is not present. No server state recorded...."
    fi

    if [ -x "${DUMP_SERVER_STATE_BIN}" ]; then

        # NOTE We don't want the logging to take too much time, so we kill it
        # if it take more than 20 seconds.
        timeout --signal 9 20          \
            "${DUMP_SERVER_STATE_BIN}" \
            --dump-dir="$LOG_DIR"      \
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

        log "System status logged in ${LOG_DIR}"
    fi
}

read_log_system_status(){
  files="df.txt dmesg.txt lxc-list.txt netstat-legacy.txt netstat-ss.txt pstree.txt ps.txt systemctl-failed-services.txt"
  echo -e "\n\n#### Détails de dump-server-state"
  for file in ${files} ; do
      echo -e "\n### cat ${LOG_DIR}/${file} :"
      tail -n 1000 "${LOG_DIR}"/"${file}"
  done
}

ensure_no_active_users_or_exit() {
    if is_debug; then return; fi

    # Is there any active user ?
    for user in $(LC_ALL=C who --users|awk '{print $1}'); do
        idle_time="$(LC_ALL=C who --users | grep "${user}" | awk '{ print $6}')"
        for sameusertime in $(LC_ALL=C who --users | grep "${user}" | awk '{ print $6}'); do
            if is_active_user "$sameusertime"; then
                hook_mail abort_active_users
                log_error_exit 'At least one user was recently active. That requires human intervention. Nothing to do here!'
            fi
        done
    done
}

is_active_user() {
    # Check if a user was active in the last 30 minutes
    idle_time="$1"

    if [ "${idle_time}" = "old" ];
    then
        return 1
    elif [ "${idle_time}" = "." ];
    then
        return 0
    else
        hh="$(echo "${idle_time}" | awk -F':' '{print $1}')"
        mm="$(echo "${idle_time}" | awk -F':' '{print $2}')"
        idle_minutes="$(( 60 * "${hh}" + "${mm}" ))"
        if [ "${idle_minutes}" -ge 30 ];
        then
            return 1
        else
            return 0
        fi
    fi
}

is_debug() {
    debug_file="/etc/evolinux/autosysadmin.debug"

    if [ -e "${debug_file}" ]; then
        last_change=$(stat -c %Z "${debug_file}")
        limit_date=$(date --date "14400 seconds ago" +"%s")

        if [ $(( last_change - limit_date )) -le "0" ]; then
            rm "${debug_file}"
        else
            return 0
        fi
    fi

    return 1
}

check_nrpe() {
    check="$1"
    list_command_nrpe=$( grep --exclude=*~ -E "\[${check}\]" -r /etc/nagios/ | grep -v '#command' )
    command_nrpe_primary=$( echo "${list_command_nrpe}" | grep "/etc/nagios/nrpe.d/evolix.cfg" | cut -d'=' -f2- )
    command_nrpe_secondary=$( echo "${list_command_nrpe}" | head -n1 | cut -d'=' -f2- )

    if [ -z "${command_nrpe_primary}" ] && [ -z "${command_nrpe_secondary}" ]
    then
        return 1
    else
        if [ -n "${command_nrpe_primary}" ]
        then
            ${command_nrpe_primary}
        else
            ${command_nrpe_secondary}
        fi
    fi
}

acquire_lock_or_exit() {
    lockfile="$1"
    waittime="$2"

    # si le temps d’attente n’est pas compréhensible par sleep(1), il vaut 0
    if ! echo "${waittime}" | grep -Eq '^[0-9]+[smhd]?$'
    then
        waittime=0
    fi

    # si le temps d’attente est supérieur à 0 et si le lock existe, on attend
    if test "${waittime}" -gt 0 && test -f "${lockfile}"
    then
        sleep "${waittime}"
    fi

    # si le lock existe, on s’arrête
    if test -f "${lockfile}"
    then
        log_error_exit "lock file ${lockfile} exists"
    fi
    touch "${lockfile}"
}

is_too_soon() {
    if is_debug; then return; fi

    witness="/tmp/autosysadmin_witness_$(basename "$0")"
    if test -f "${witness}"
    then
        compare="$(($(date +%s)-$(stat -c "%Y" "${witness}")))"
        if [ "${compare}" -lt 1800 ];
        then
            log_error_exit 'already executed less than 30 minutes ago'
        fi
        rm "${witness}"
    fi
    touch "${witness}"
}

init_autosysadmin() {
    PATH="${PATH}":/usr/sbin:/sbin↩
    unset ACTIONS

    SCRIPTNAME=$(basename "$0")
    PROGNAME=${SCRIPTNAME%.sh}

    RUN_ID="$(date +"%Y-%m-%d_%H-%M")_${SCRIPTNAME}_$(openssl rand -hex 6)"
    LOG_DIR="/var/log/autosysadmin/${RUN_ID}"
    mkdir -p "${LOG_DIR}"

    log "Autosysadmin : Script ${SCRIPTNAME} triggered"

    # Detect operating system name, version and release↩
    detect_os
}

load_conf() {
    # Load conf and enable script by default.
    # To disable script locally, set "$PROGNAME"=off in /etc/evolinux/autosysadmin.
    # To disable script globally, set "$PROGNAME"=off in the script, after load_conf() call.
    declare -g "$PROGNAME"=on  # dynamic variable assignment ($PROGNAME == repair_*)

    # Source configuration file
    # shellcheck source=../roles/deploy_autosysadmin/templates/autosysadmin.cfg.j2
    test -f /etc/evolinux/autosysadmin && source /etc/evolinux/autosysadmin
}

detect_os() {
    # OS detection
    DEBIAN_RELEASE=""
    LSB_RELEASE_BIN="$(command -v lsb_release)"

    if [ -e /etc/debian_version ]; then
        DEBIAN_VERSION="$(cut -d "." -f 1 < /etc/debian_version)"
        if [ -x "${LSB_RELEASE_BIN}" ]; then
            DEBIAN_RELEASE="$("${LSB_RELEASE_BIN}" --codename --short)"
        else
            case "${DEBIAN_VERSION}" in
                8) DEBIAN_RELEASE="jessie";;
                9) DEBIAN_RELEASE="stretch";;
                10) DEBIAN_RELEASE="buster";;
                11) DEBIAN_RELEASE="bullseye";;
            esac
        fi
    fi
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

systemd_list_service_failed() {
    systemctl list-units --failed --no-legend --full --type=service "$1" |
        awk '{print $1}'
}

systemd_list_units_enabled() {
    list_units_enabled=$(systemctl list-unit-files --state=enabled --no-legend | awk "/$1/{print \$1}")
    if [ -z "${list_units_enabled}" ]
    then
        return 1
    else
        echo "${list_units_enabled}"
    fi
}

format_mail_success() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <equipe+autosysadmin@evolix.net>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: $(basename "$0")
X-RunId: ${RUN_ID}
To: ${EMAIL_CLIENT:-alert5@evolix.fr}
Cc: autosysadmin@evolix.fr
Subject: [autosysadmin] Intervention sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatique vient de se terminer.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)

### Renseignements sur l'intervention

${ACTIONS}

### Réagir à cette intervention

Vous pouvez répondre à ce message (sur l'adresse mail equipe@evolix.net).
En cas d'urgence, utilisez l'adresse maintenance@evolix.fr ou
notre téléphone portable d'astreinte (04.26.99.99.26)

--
Votre AutoSysadmin
EOTEMPLATE
}

format_mail_abort_active_users() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <equipe+autosysadmin@evolix.net>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: $(basename "$0")
X-RunId: ${RUN_ID}
To: ${EMAIL_CLIENT:-alert5@evolix.fr}
Cc: autosysadmin@evolix.fr
Subject: [autosysadmin] Intervention interrompue sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatique a été interrompue en raison
d'un utilisateur actuellement actif sur le serveur.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)

### Utilisateur(s) connecté(s)
$(w)

--
Votre AutoSysadmin
EOTEMPLATE
}

format_mail_internal_info() {
    cat <<EOTEMPLATE
From: AutoSysadmin Evolix <equipe+autosysadmin@evolix.net>
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
X-Script: $(basename "$0")
X-RunId: ${RUN_ID}
To: autosysadmin@evolix.fr
Subject: [autosysadmin] Complements (interne) - Intervention sur ${HOSTNAME_TEXT}

Bonjour,

Une intervention automatique vient de se terminer.

Nom du serveur : ${HOSTNAME_TEXT}
Heure d'intervention : $(LC_ALL=fr_FR.utf8 date)
Script déclenché : $(basename "$0")

### Actions effectuées

${ACTIONS}

### Logs autosysadmin

${INTERNAL_LOG}

### Utilisateur(s) connecté(s)

$(w)

### Informations additionnelles données par le script $(basename "$0")

${INTERNAL_INFO}

--
Votre AutoSysadmin
EOTEMPLATE
}

hook_mail() {
    if is_debug; then return; fi

    HOSTNAME="${HOSTNAME:-"$(get_fqdn)"}"
    HOSTNAME_TEXT="$(get_complete_hostname)"
    EMAIL_CLIENT="$(get_evomaintenance_mail)"

    MAIL_CONTENT="$(format_mail_"$1")"

    SENDMAIL_BIN="$(command -v sendmail)"

    if [ -z "${SENDMAIL_BIN}" ]; then
        log "No \`sendmail' command has been found, can't send mail."
    fi

    if [ -x "${SENDMAIL_BIN}" ]; then
        echo "${MAIL_CONTENT}" | "${SENDMAIL_BIN}" -oi -t -f "equipe@evolix.net"
    fi
}



# We need stable output for gcal, so we force some language environment variables
export TZ=Europe/Paris
export LANGUAGE=fr_FR.UTF-8

is_holiday() {
    # gcal mark today as a holiday by surrounding with < and > the day
    # of the month of that holiday line.  For exemple if today is 2022-05-01 we'll
    # get among other lines:
    # Fête du Travail (FR)                    + Di, < 1>Mai 2022
    # Jour de la Victoire (FR)                 + Di, : 8:Mai 2022 =   +7 jours
    gcal --cc-holidays=fr --holiday-list=short | grep -E '<[0-9 ]{2}>' --quiet
}

is_weekend() {
    day_of_week=$(date +%u)
    if [ "$day_of_week" != 6 ] && [ "$day_of_week" != 7 ]; then
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
