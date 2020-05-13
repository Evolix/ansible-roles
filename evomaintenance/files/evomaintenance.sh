#!/bin/sh

# EvoMaintenance script
# Dependencies (all OS): git postgresql-client
# Dependencies (Debian): sudo

# Copyright 2007-2019 Evolix <info@evolix.fr>, Gregory Colpart <reg@evolix.fr>,
#                     Jérémy Lecour <jlecour@evolix.fr> and others.

VERSION="0.6.3"

show_version() {
    cat <<END
evomaintenance version ${VERSION}

Copyright 2007-2019 Evolix <info@evolix.fr>,
                    Gregory Colpart <reg@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>
                    and others.

evomaintenance comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

show_help() {
    cat <<END
evomaintenance is a program that helps reporting what you've done on a server

Usage: evomaintenance
  or   evomaintenance --message="add new host"
  or   evomaintenance --no-api --no-mail --no-commit
  or   echo "add new vhost" | evomaintenance

Options
 -m, --message=MESSAGE       set the message from the command line
     --mail                  enable the mail hook (default)
     --no-mail               disable the mail hook
     --db                    enable the database hook
     --no-db                 disable the database hook (default)
     --api                   enable the API hook (default)
     --no-api                disable the API hook
     --commit                enable the commit hook (default)
     --no-commit             disable the commit hook
     --evocheck              enable evocheck execution (default)
     --no-evocheck           disable evocheck execution
     --auto                  use "auto" mode
     --no-auto               use "manual" mode (default)
 -v, --verbose               increase verbosity
 -n, --dry-run               actions are not executed
     --help                  print this message and exit
     --version               print version and exit
END
}

syslog() {
    if [ -x "${LOGGER_BIN}" ]; then
        ${LOGGER_BIN} -t "evomaintenance" "$1"
    fi
}

get_system() {
    uname -s
}

get_fqdn() {
    if [ "$(get_system)" = "Linux" ]; then
        hostname --fqdn
    elif [ "$(get_system)" = "OpenBSD" ]; then
        hostname
    else
        echo "OS not detected!"
        exit 1
    fi
}

get_tty() {
    if [ "$(get_system)" = "Linux" ]; then
        ps -o tty= | tail -1
    elif [ "$(get_system)" = "OpenBSD" ]; then
        env | grep SSH_TTY | cut -d"/" -f3
    else
        echo "OS not detected!"
        exit 1
    fi
}

get_who() {
    who=$(LC_ALL=C who -m | tr -s ' ')

    if [ -n "${who}" ]; then
        echo "${who}"
    else
        LC_ALL=C who | grep "$(get_tty)" | tr -s ' '
    fi
}

get_begin_date() {
    printf "%s %s" "$(date "+%Y")" "$(get_who | cut -d" " -f3,4,5)"
}

get_ip() {
    ip=$(get_who | cut -d" " -f6 | sed -e "s/^(// ; s/)$//")
    [ -z "${ip}" ] && ip="unknown (no tty)"
    [ "${ip}" = ":0" ] && ip="localhost"

    echo "${ip}"
}

get_end_date() {
    date +"%Y %b %d %H:%M"
}

get_now() {
    date +"%Y-%m-%dT%H:%M:%S%z"
}

get_complete_hostname() {
    REAL_HOSTNAME=$(get_fqdn)
    if [ "${HOSTNAME}" = "${REAL_HOSTNAME}" ]; then
        echo "${HOSTNAME}"
    else
        echo "${HOSTNAME} (${REAL_HOSTNAME})"
    fi
}

get_repository_status() {
    dir=$1
    # tell Git where to find the repository and the work tree (no need to `cd …` there)
    export GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}"
    # If the repository and the work tree exist, try to commit changes
    if [ -d "${GIT_DIR}" ] && [ -d "${GIT_WORK_TREE}" ]; then
        CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l | tr -d ' ')
        if [ "${CHANGED_LINES}" != "0" ]; then
            STATUS=$(${GIT_BIN} status --short | tail -n ${GIT_STATUS_MAX_LINES})
            printf "%s\n%s\n" "${GIT_DIR} (last ${GIT_STATUS_MAX_LINES} lines)" "${STATUS}" | sed -e '/^$/d'
        fi
    fi
    # unset environment variables to prevent accidental influence on other git commands
    unset GIT_DIR GIT_WORK_TREE
}

get_evocheck() {
    if [ -x "${EVOCHECK_BIN}" ]; then
        printf "Evocheck status :"
        EVOCHECK_OUT=$(${EVOCHECK_BIN})
        EVOCHECK_RC=$?

        if [ "${EVOCHECK_RC}" = "0" ] && [ -z "${EVOCHECK_OUT}" ]; then
            printf " OK\n\n"
        else
            printf " ERROR\n%s\n\n" "${EVOCHECK_OUT}"
        fi
    fi
}

print_log() {
    printf "*********** %s ***************\n" "$(get_now)"
    print_session_data
    printf "Hooks     : commit=%s db=%s api=%s mail=%s\n"\
           "${HOOK_COMMIT}" "${HOOK_DB}" "${HOOK_API}" "${HOOK_MAIL}"
    if [ "${HOOK_MAIL}" = "1" ]; then
        printf "Mailto    : %s\n" "${EVOMAINTMAIL}"
    fi
}

print_session_data() {
    printf "Host      : %s\n" "${HOSTNAME_TEXT}"
    printf "User      : %s\n" "${USER}"
    printf "IP        : %s\n" "${IP}"
    printf "Begin     : %s\n" "${BEGIN_DATE}"
    printf "End       : %s\n" "${END_DATE}"
    printf "Message   : %s\n" "${MESSAGE}"
}

is_repository_readonly() {
    if [ "$(get_system)" = "OpenBSD" ]; then
        partition=$(stat -f '%Sd' $1)
        mount | grep ${partition} | grep -q "read-only"
    else
        mountpoint=$(stat -c '%m' $1)
        findmnt ${mountpoint} --noheadings --output OPTIONS -O ro
    fi
}
remount_repository_readwrite() {
    if [ "$(get_system)" = "OpenBSD" ]; then
        partition=$(stat -f '%Sd' $1)
        mount -u -w /dev/${partition} 2>/dev/null
    else
        mountpoint=$(stat -c '%m' $1)
        mount -o remount,rw ${mountpoint}
        syslog "Re-mount ${mountpoint} as read-write to commit in repository $1"
    fi
}
remount_repository_readonly() {
    if [ "$(get_system)" = "OpenBSD" ]; then
        partition=$(stat -f '%Sd' $1)
        mount -u -r /dev/${partition} 2>/dev/null
    else
        mountpoint=$(stat -c '%m' $1)
        mount -o remount,ro ${mountpoint} 2>/dev/null
        syslog "Re-mount ${mountpoint} as read-only after commit to repository $1"
    fi
}

hook_commit() {
    if [ -x "${GIT_BIN}" ]; then
        # loop on possible directories managed by GIT
        for dir in ${GIT_REPOSITORIES}; do
            # tell Git where to find the repository and the work tree (no need to `cd …` there)
            export GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}"
            # reset variable used to track if a mount point is readonly
            READONLY_ORIG=0
            # If the repository and the work tree exist, try to commit changes
            if [ -d "${GIT_DIR}" ] && [ -d "${GIT_WORK_TREE}" ]; then
                CHANGED_LINES=$(${GIT_BIN} status --porcelain | wc -l | tr -d ' ')
                if [ "${CHANGED_LINES}" != "0" ]; then
                    if [ "${DRY_RUN}" = "1" ]; then
                        # STATS_SHORT=$(${GIT_BIN} diff --stat | tail -1)
                        STATS=$(${GIT_BIN} diff --stat | tail -n ${GIT_STATUS_MAX_LINES})
                        # GIT_COMMITS_SHORT=$(printf "%s\n%s : %s" "${GIT_COMMITS_SHORT}" "${GIT_DIR}" "${STATS_SHORT}" | sed -e '/^$/d')
                        GIT_COMMITS=$(printf "%s\n%s\n%s" "${GIT_COMMITS}" "${GIT_DIR}" "${STATS}" | sed -e '/^$/d')
                    else
                        # remount mount point read-write if currently readonly
                        is_repository_readonly ${dir} && { READONLY_ORIG=1; remount_repository_readwrite ${dir}; }
                        # commit changes
                        ${GIT_BIN} add --all
                        ${GIT_BIN} commit --message "${MESSAGE}" --author="${USER} <${USER}@evolix.net>" --quiet
                        # remount mount point read-only if it was before
                        test "$READONLY_ORIG" = "1" && remount_repository_readonly ${dir}
                        # Add the SHA to the log file if something has been committed
                        SHA=$(${GIT_BIN} rev-parse --short HEAD)
                        # STATS_SHORT=$(${GIT_BIN} show --stat | tail -1)
                        STATS=$(${GIT_BIN} show --stat --pretty=format:"" | tail -n ${GIT_STATUS_MAX_LINES})
                        # append commit data, without empty lines
                        # GIT_COMMITS_SHORT=$(printf "%s\n%s : %s –%s" "${GIT_COMMITS_SHORT}" "${GIT_DIR}" "${SHA}" "${STATS_SHORT}" | sed -e '/^$/d')
                        GIT_COMMITS=$(printf "%s\n%s : %s\n%s" "${GIT_COMMITS}" "${GIT_DIR}" "${SHA}" "${STATS}" | sed -e '/^$/d')
                    fi
                fi
            fi
            # unset environment variables to prevent accidental influence on other git commands
            unset GIT_DIR GIT_WORK_TREE
        done

        if [ -n "${GIT_COMMITS}" ]; then
            # if [ "${VERBOSE}" = "1" ]; then
                printf "\n********** Commits ****************\n%s\n***********************************\n" "${GIT_COMMITS}"
            # fi
            if [ "${DRY_RUN}" != "1" ]; then
                echo "${GIT_COMMITS}" >> "${LOGFILE}"
            fi
        fi
    fi
}

hook_db() {
    SQL_DETAILS=$(echo "${MESSAGE}" | sed "s/'/''/g")
    PG_QUERY="INSERT INTO evomaint(hostname,userid,ipaddress,begin_date,end_date,details) VALUES ('${HOSTNAME}','${USER}','${IP}','${BEGIN_DATE}',now(),'${SQL_DETAILS}')"

    if [ "${VERBOSE}" = "1" ]; then
        printf "\n********** DB query **************\n%s\n***********************************\n" "${PG_QUERY}"
    fi
    if [ "${DRY_RUN}" != "1" ] && [ -x "${PSQL_BIN}" ]; then
        echo "${PG_QUERY}" | ${PSQL_BIN} "${PGDB}" "${PGTABLE}" -h "${PGHOST}"
    fi
}

hook_api() {
    if [ "${VERBOSE}" = "1" ]; then
        printf "\n********** API call **************\n"
        printf "curl -f -s -S -X POST [REDACTED] -k -F api_key=[REDACTED] -F action=insertEvoMaintenance -F hostname=%s -F userid=%s -F ipaddress=%s -F begin_date=%s -F end_date='now()' -F details=%s" \
                    "${HOSTNAME}" "${USER}" "${IP}" "${BEGIN_DATE}" "${MESSAGE}"
        printf "\n***********************************\n"
    fi

    if [ "${DRY_RUN}" != "1" ] && [ -x "${CURL_BIN}" ]; then
        API_RETURN_STATUS=$(curl -f -s -S -X POST \
        "${API_ENDPOINT}" -k \
        -F api_key="${API_KEY}" \
        -F action=insertEvoMaintenance \
        -F hostname="${HOSTNAME}" \
        -F userid="${USER}" \
        -F ipaddress="${IP}" \
        -F begin_date="${BEGIN_DATE}" \
        -F end_date='now()' \
        -F details="${MESSAGE}")

        # either cURL or the API backend can throw an error, otherwise it returns this JSON response
        if [ "$API_RETURN_STATUS" = '{"status":"Ok"}' ]; then
            echo "API call OK."
        else
            echo "API call FAILED."
        fi
    fi
}

format_mail() {
    cat <<EOTEMPLATE
From: ${FULLFROM}
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
To: ${EVOMAINTMAIL}
Subject: [evomaintenance] Intervention sur ${HOSTNAME_TEXT} (${USER})

Bonjour,

Une intervention vient de se terminer sur votre serveur.

Nom du serveur : ${HOSTNAME_TEXT}
Personne ayant réalisée l'intervention : ${USER}
Intervention réalisée depuis : ${IP}
Début de l'intervention : ${BEGIN_DATE}
Fin de l'intervention : ${END_DATE}

### Renseignements sur l'intervention
${MESSAGE}
###

EOTEMPLATE

    if [ -n "${GIT_COMMITS}" ]; then
        cat << EOTEMPLATE
### Commits
${GIT_COMMITS}
###

EOTEMPLATE
    fi

    cat <<EOTEMPLATE
Pour réagir à cette intervention, vous pouvez répondre à ce message
(sur l'adresse mail ${FROM}). En cas d'urgence, utilisez
l'adresse ${URGENCYFROM} ou notre téléphone portable d'astreinte
(${URGENCYTEL})

Cordialement,
--
${FULLFROM}
EOTEMPLATE
}

hook_mail() {
    MAIL_CONTENT=$(format_mail)

    if [ "${VERBOSE}" = "1" ]; then
        printf "\n********** Mail *******************\n%s\n***********************************\n" "${MAIL_CONTENT}"
    fi
    if [ "${DRY_RUN}" != "1" ] && [ -x "${SENDMAIL_BIN}" ]; then
        echo "${MAIL_CONTENT}" | ${SENDMAIL_BIN} -oi -t -f "${FROM}"
    fi
}

hook_log() {
  if [ "${VERBOSE}" = "1" ]; then
      print_log
  fi
  if [ "${DRY_RUN}" != "1" ]; then
      print_log >> "${LOGFILE}"
  fi
}

# load configuration if present.
test -f /etc/evomaintenance.cf && . /etc/evomaintenance.cf

HOSTNAME=${HOSTNAME:-$(get_fqdn)}
EVOMAINTMAIL=${EVOMAINTMAIL:-"evomaintenance-$(echo "${HOSTNAME}" | cut -d- -f1)@${REALM}"}
LOGFILE=${LOGFILE:-"/var/log/evomaintenance.log"}
HOOK_COMMIT=${HOOK_COMMIT:-"1"}
HOOK_DB=${HOOK_DB:-"0"}
HOOK_API=${HOOK_API:-"1"}
HOOK_MAIL=${HOOK_MAIL:-"1"}
DRY_RUN=${DRY_RUN:-"0"}
VERBOSE=${VERBOSE:-"0"}
AUTO=${AUTO:-"0"}
EVOCHECK=${EVOCHECK:-"0"}
GIT_STATUS_MAX_LINES=${GIT_STATUS_MAX_LINES:-20}
API_ENDPOINT=${API_ENDPOINT:-""}

# initialize variables
MESSAGE=""
# GIT_COMMITS_SHORT=""
GIT_COMMITS=""

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
        -m|--message)
            # message options, with value speparated by space
            if [ -n "$2" ]; then
                MESSAGE=$2
                shift
            else
                printf 'ERROR: "--message" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --message=?*)
            # message options, with value speparated by =
            MESSAGE=${1#*=}
            ;;
        --message=)
            # message options, without value
            printf 'ERROR: "--message" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        --no-commit)
            # disable commit hook
            HOOK_COMMIT=0
            ;;
        --commit)
            # enable commit hook
            HOOK_COMMIT=1
            ;;
        --no-db)
            # disable DB hook
            HOOK_DB=0
            ;;
        --db)
            # enable DB hook
            HOOK_DB=1
            ;;
        --no-api)
            # disable API hook
            HOOK_API=0
            ;;
        --api)
            # enable API hook
            HOOK_API=1
            ;;
        --no-mail)
            # disable mail hook
            HOOK_MAIL=0
            ;;
        --mail)
            # enable mail hook
            HOOK_MAIL=1
            ;;
        --no-auto)
            # use "manual" mode
            AUTO=0
            ;;
        --auto)
            # use "auto" mode
            AUTO=1
            ;;
        -n|--dry-run)
            # disable actual commands
            DRY_RUN=1
            ;;
        -v|--verbose)
            # print verbose information
            VERBOSE=1
            ;;
        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done


# Treat unset variables as an error when substituting.
# Only after this line, because some config variables might be missing.
set -u

# Gather information
HOSTNAME_TEXT=$(get_complete_hostname)
# TTY=$(get_tty)
# WHO=$(get_who)
IP=$(get_ip)
BEGIN_DATE=$(get_begin_date)
END_DATE=$(get_end_date)
USER=$(logname)

PATH=${PATH}:/usr/sbin

SENDMAIL_BIN=$(command -v sendmail)
readonly SENDMAIL_BIN
if [ "${HOOK_MAIL}" = "1" ] && [ -z "${SENDMAIL_BIN}" ]; then
    echo "No \`sendmail' command has been found, can't send mail." 2>&1
fi

GIT_BIN=$(command -v git)
readonly GIT_BIN
if [ "${HOOK_COMMIT}" = "1" ] && [ -z "${GIT_BIN}" ]; then
    echo "No \`git' command has been found, can't commit changes" 2>&1
fi

PSQL_BIN=$(command -v psql)
readonly PSQL_BIN
if [ "${HOOK_DB}" = "1" ] && [ -z "${PSQL_BIN}" ]; then
    echo "No \`psql' command has been found, can't save to the database." 2>&1
fi

CURL_BIN=$(command -v curl)
readonly CURL_BIN
if [ "${HOOK_API}" = "1" ] && [ -z "${CURL_BIN}" ]; then
    echo "No \`curl' command has been found, can't call the API." 2>&1
fi

LOGGER_BIN=$(command -v logger)
readonly LOGGER_BIN

if [ "${HOOK_API}" = "1" ] && [ -z "${API_ENDPOINT}" ]; then
    echo "No API endpoint specified, can't call the API." 2>&1
fi

EVOCHECK_BIN="/usr/share/scripts/evocheck.sh"

GIT_REPOSITORIES="/etc /etc/bind /usr/share/scripts"

# initialize variable
GIT_STATUSES=""
# git statuses
if [ -x "${GIT_BIN}" ]; then
    # loop on possible directories managed by GIT
    for dir in ${GIT_REPOSITORIES}; do
        RESULT=$(get_repository_status "${dir}")
        if [ -n "${RESULT}" ]; then
            # append diff data, without empty lines
            GIT_STATUSES=$(printf "%s\n%s\n" "${GIT_STATUSES}" "${RESULT}" | sed -e '/^$/d')
        fi
        unset RESULT
    done
fi

# find out if running in interactive mode, or not
if [ -t 0 ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
fi
readonly INTERACTIVE

if [ "${INTERACTIVE}" = "1" ] && [ "${EVOCHECK}" = "1" ]; then
    get_evocheck
fi
if [ -n "${GIT_STATUSES}" ] && [ "${INTERACTIVE}" = "1" ]; then
    printf "/!\\\ There are some uncommited changes.\n%s\n\n" "${GIT_STATUSES}"
fi

if [ -z "${MESSAGE}" ]; then
    if [ "${INTERACTIVE}" = "1" ]; then
        printf "> Please, enter details about your maintenance:\n"
    fi
    read -r MESSAGE
fi

if [ -z "${MESSAGE}" ]; then
    echo "no value..."
    exit 1
fi

print_session_data

if [ "${INTERACTIVE}" = "1" ] && [ "${AUTO}" = "0" ]; then
    if  [ "${HOOK_COMMIT}" = "1" ] || [ "${HOOK_MAIL}" = "1" ] || [ "${HOOK_DB}" = "1" ]; then
        printf "\nActions to execute:\n"
        if [ "${HOOK_COMMIT}" = "1" ]; then
            printf "* commit changes in repositories\n"
        fi
        if [ "${HOOK_MAIL}" = "1" ]; then
            printf "* send mail to %s\n" "${EVOMAINTMAIL}"
        fi
        if [ "${HOOK_DB}" = "1" ]; then
            printf "* save metadata to the database\n"
        fi
        if [ "${HOOK_API}" = "1" ]; then
            printf "* send metadata to the API\n"
        fi
        echo ""

        answer=""
        while :; do
            printf "> Let's continue? [Y,n,i,?] "
            read -r answer
            case $answer in
                [Yy]|"" )
                    # force "auto" mode, but keep hooks settings
                    AUTO=1
                    break
                    ;;
                [Nn] )
                    # force "auto" mode, and disable all hooks
                    HOOK_COMMIT=0
                    HOOK_MAIL=0
                    HOOK_DB=0
                    HOOK_API=0
                    AUTO=1
                    break
                    ;;
                [Ii] )
                    # force "manual" mode
                    AUTO=0
                    break
                    ;;
                * )
                    printf "y - yes, execute actions and exit\n"
                    printf "n - no, don't execute actions and exit\n"
                    printf "i - switch to interactive mode\n"
                    printf "? - print this help\n"
                    ;;
            esac
        done
    fi
fi

if [ "${INTERACTIVE}" = "1" ] && [ "${AUTO}" = "0" ]; then
    # Commit hook
    if [ -n "${GIT_STATUSES}" ] && [ "${HOOK_COMMIT}" = "1" ]; then
        printf "/!\ There are some uncommited changes.\n%s\n\n" "${GIT_STATUSES}"

        y="Y"; n="n"
        answer=""
        while :; do
            printf "> Do you want to commit the changes? [%s] " "${y},${n}"
            read -r answer
            case $answer in
                [Yy] )
                    hook_commit;
                    break
                    ;;
                [Nn] )
                    break
                    ;;
                "" )
                    if [ "${HOOK_COMMIT}" = "1" ]; then
                      hook_commit
                    fi
                    break
                    ;;
                * )
                    echo "answer with a valid choice"
                    ;;
            esac
        done
    fi

    # Mail hook
    if [ "${HOOK_MAIL}" = "1" ]; then
        y="Y"; n="n"
    else
        y="y"; n="N"
    fi
    answer=""
    while :; do
        printf "> Do you want to send an email to <%s>? [%s] " "${EVOMAINTMAIL}" "${y},${n},e"
        read -r answer
        case $answer in
            [Yy] )
                hook_mail;
                break
                ;;
            [Nn] )
                break
                ;;
            [Ee] )
                printf "> To: [%s] " "${EVOMAINTMAIL}"
                read -r mail_recipient
                if [ -n "${mail_recipient}" ]; then
                    EVOMAINTMAIL="${mail_recipient}"
                fi
                ;;
            "" )
                if [ "${HOOK_MAIL}" = "1" ]; then
                    hook_mail
                fi
                break
                ;;
            * )
                echo "answer with a valid choice"
                ;;
        esac
    done

    # Database hook
    if [ "${HOOK_DB}" = "1" ]; then
        y="Y"; n="n"
    else
        y="y"; n="N"
    fi
    answer=""
    while :; do
        printf "> Do you want to insert your message into the database? [%s] " "${y},${n}"
        read -r answer
        case $answer in
            [Yy] )
                hook_db;
                break
                ;;
            [Nn] )
                break
                ;;
            "" )
                if [ "${HOOK_DB}" = "1" ]; then
                  hook_db
                fi
                break
                ;;
            * )
                echo "answer with a valid choice"
                ;;
        esac
    done

    # API hook
    if [ "${HOOK_API}" = "1" ]; then
        y="Y"; n="n"
    else
        y="y"; n="N"
    fi
    answer=""
    while :; do
        printf "> Do you want to send the metadata to the API? [%s] " "${y},${n}"
        read -r answer
        case $answer in
            [Yy] )
                hook_api;
                break
                ;;
            [Nn] )
                break
                ;;
            "" )
                if [ "${HOOK_API}" = "1" ]; then
                    hook_api
                fi
                break
                ;;
            * )
                echo "answer with a valid choice"
                ;;
        esac
    done
fi

# Log hook
hook_log

if [ "${INTERACTIVE}" = "0" ] || [ "${AUTO}" = "1" ]; then
    if [ "${HOOK_COMMIT}" = "1" ]; then
        hook_commit
    fi
    if [ "${HOOK_MAIL}" = "1" ]; then
        hook_mail
    fi
    if [ "${HOOK_DB}" = "1" ]; then
        hook_db
    fi
    if [ "${HOOK_API}" = "1" ]; then
        hook_api
    fi
fi

exit 0
