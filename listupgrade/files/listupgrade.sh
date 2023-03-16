#!/bin/bash

# Repository: https://gitea.evolix.org/evolix/maj.sh/

# Exit codes :
# - 30 : $skip_releases or $skip_packages is set to "all"
# - 40 : current release is in $skip_releases list
# - 50 : all upgradable packages are in the $skip_packages list
# - 60 : current release is not in the $r_releases list
# - 70 : at least an upgradable package is not in the $r_packages list

VERSION="23.03.3"

show_version() {
    cat <<END
listupgrade.sh version ${VERSION}

Copyright 2018-2023 Evolix <info@evolix.fr>,
               Gregory Colpart <reg@evolix.fr>,
               Romain Dessort <rdessort@evolix.fr>,
               Ludovic Poujol <lpoujol@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>
               and others.

listupgrade.sh comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

# Parse line in retrieved upgrade file and ensure there is no malicious values.
get_value() {
    file="$1"
    variable="$2"
    value="$(grep "^${variable}:" "${file}" | head -n 1 | cut -d ':' -f 2 | sed 's/^ //')"

    if echo "${value}" | grep -q -E '^[-.: [:alnum:]]*$'; then
        echo "${value}"
    else
        printf >&2 "Error parsing value \"%s\" for variable %s.\n" "${value}" "${variable}"
    fi
}

# Fetch which packages/releases will be upgraded.
fetch_upgrade_info() {
    upgradeInfo=$(mktemp --tmpdir=/tmp listupgrade.XXX)
    wget --no-check-certificate --quiet --output-document="${upgradeInfo}" https://upgrades.evolix.org/upgrade

    # shellcheck disable=SC2181
    if [ "$?" != "0" ]; then
        printf >&2 "Error fetching upgrade directives.\n"
    fi

    r_releases="$(get_value "${upgradeInfo}" "releases")"
    r_skip_releases="$(get_value "${upgradeInfo}" "skip_releases")"
    r_packages="$(get_value "${upgradeInfo}" "packages")"
    r_skip_packages="$(get_value "${upgradeInfo}" "skip_packages")"

    rm "${upgradeInfo}"
}

# Check if element $element is in (space separated) list $list.
is_in() {
    list="$1"
    element="$2"

    for i in ${list}; do
        if [ "${element}" = "${i}" ]; then
            return 0
        fi
    done

    return 1
}

render_mail_template() {
    local template_file=$1
    cat <<EOT >"${template_file}"
Content-Type: text/plain; charset="utf-8"
Reply-To: equipe@evolix.fr
From: equipe@evolix.net
To: ${clientmail}
Subject: Prochain creneau pour mise a jour de votre serveur ${hostname}
X-Debian-Release: ${local_release}
X-Packages: ${packagesParsable}
X-Date: ${date}
X-Listupgrade-Version: ${VERSION}

Bonjour,

Des mises-à-jour de sécurité ou mineures sont à réaliser sur votre serveur
${hostname}.
Sauf indication contraire de votre part, le prochain créneau prévu pour
intervenir manuellement pour réaliser ces mises-à-jour est :
${date}

Si nous intervenons, un redémarrage des éventuels services concernés sera
réalisé, entraînant a priori quelques secondes de coupure.  Si nous ne sommes
pas intervenus sur ce créneau, vous recevrez une nouvelle notification la
semaine prochaine.

Voici la listes de packages qui seront mis à jour :

$(sort -h "${packages}" | uniq)

Liste des packages dont la mise-à-jour a été manuellement suspendue :

$(sort -h "${packagesHold}" | uniq)

Liste des services qui seront redémarrés :

$(sort -h "${servicesToRestart}" | uniq)

N'hésitez pas à nous faire toute remarque sur ce créneau d'intervention le plus
tôt possible.

Cordialement,
--
Équipe Evolix - Hébergement et Infogérance Open Source
http://evolix.com | Twitter: @Evolix @EvolixNOC | http://blog.evolix.com
EOT
}
# Files found in the directory passed as 1st argument
# are executed if they are executable
# and if their name doesn't contain a dot
exec_hooks_in_dir() {
    hooks=$(find "${1}" -type f -executable -not -name '*.* -print0 | sort --zero-terminated --dictionary-order | xargs --no-run-if-empty --null --max-args=1')
    for hook in ${hooks}; do
        if ! cron_mode; then
            printf "Running '%s\`\n" "${hook}"
        fi
        ${hook}
    done
}
pre_hooks() {
    if [ -d "${hooksDir}/pre" ]; then
        exec_hooks_in_dir "${hooksDir}/pre"
    fi
}
post_hooks_and_exit() {
    status=${1:-0}
    if [ -d "${hooksDir}/post" ]; then
        exec_hooks_in_dir "${hooksDir}/post"
    fi
    exit ${status}
}

cron_mode() {
    test "${cron_mode}" = "1"
}

force_mode() {
    test "${force_mode}" = "1"
}

main() {
    if ! cron_mode; then
        echo "Updating lists..."
    fi
    # Update APT cache and get packages to upgrade and packages on hold.
    aptUpdateOutput=$(apt -o Dir::State::Lists="${listupgrade_state_dir}"  update 2>&1 | (grep -E -ve '^(Listing|WARNING|$)' -e upgraded -e 'up to date' || true))

    if echo "${aptUpdateOutput}" | grep -E "^Err(:[0-9]+)? http"; then
        echo "FATAL - Not able to fetch all sources (probably a pesky (mini)firewall). Please, fix me" >&2
        post_hooks_and_exit 100
    fi

    apt-mark showhold | sed -e 's/\(.\+\)/^\1\//' >"${packagesHold}"
    apt -o Dir::State::Lists="${listupgrade_state_dir}" list --upgradable 2>&1 | grep -v -f "${packagesHold}" | grep -v -E '^(Listing|WARNING|$)' >"${packages}"
    packagesParsable=$(cut -f 1 -d / <"${packages}" | tr '\n' ' ')

    # No updates? Exit!
    if [ ! -s "${packages}" ]; then
        if ! cron_mode; then
            echo "There is nothing to upgrade. Bye." >&2
        fi
        post_hooks_and_exit 0
    fi

    if [ ! -s "${packagesHold}" ]; then
        echo 'Aucun' >"${packagesHold}"
    fi

    local_release=$(cut -f 1 -d . </etc/debian_version)
    # In case the version is a release name and not a number
    case "${local_release}" in
        *jessie*) 
            local_release=8
            ;;
        *stretch*) 
            local_release=9
            ;;
        *buster*) 
            local_release=10
            ;;
        *bullseye*) 
            local_release=11
            ;;
        *bookworm*)
            local_release=12
            ;;
        *trixie*) 
            local_release=13
            ;;
    esac


    if force_mode; then
        if ! cron_mode; then
            echo "Force mode is enabled, as if every release/package is available for upgrade."
        fi
    else
        fetch_upgrade_info

        # Exit if skip_releases or skip_packages in upgrade info file are set to all.
        if [ "${r_skip_releases}" = "all" ] || [ "${r_skip_packages}" = "all" ]; then
            post_hooks_and_exit 30
        fi

        # Exit if the server's release is in skip_releases.
        if [ -n "${r_skip_releases}" ] && is_in "${r_skip_releases}" "${local_release}"; then
            post_hooks_and_exit 40
        fi

        # Exit if all packages to upgrade are listed in skip_packages:
        # we remove each package to skip from the $packageToUpgrade list. At the end,
        # if there is no additional packages to upgrade, we can exit.
        if [ -n "${r_skip_packages}" ]; then
            packageToUpgrade="${packagesParsable}"
            for pkg in ${r_skip_packages}; do
                packageToUpgrade="${packageToUpgrade}/${pkg}"
            done
            # shellcheck disable=SC2001
            packageToUpgrade=$(echo "${packageToUpgrade}" | sed 's/  \+//g')
            if [ -z "${packageToUpgrade}" ]; then
                post_hooks_and_exit 50
            fi
        fi

        # Exit if the server's release is not in releases.
        if [ -n "${r_releases}" ] && [ "${r_releases}" != "all" ]; then
            is_in "${r_releases}" "${local_release}" || post_hooks_and_exit 60
        fi

        # Exit if there is packages to upgrades that are not in packages list:
        # we exit at the first package encountered that is not in packages list.
        if [ -n "${r_packages}" ] && [ "${r_packages}" != "all" ]; then
            for pkg in ${packagesParsable}; do
                is_in "${r_packages}" "${pkg}" || post_hooks_and_exit 70
            done
        fi
    fi

    # Guess which services will be restarted.
    for pkg in ${packagesParsable}; do
        if echo "${pkg}" | grep -qE "^(lib)?apache2"; then
            echo "Apache2" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -q "^nginx"; then
            echo "Nginx" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -q "^php5-fpm"; then
            echo "PHP FPM" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -q "^mysql-server"; then
            echo "MySQL" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -q "^mariadb-server"; then
            echo "MariaDB" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -qE "^postgresql-[[:digit:]]+(\.[[:digit:]]+)?$"; then
            echo "PostgreSQL" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -qE "^tomcat[[:digit:]]+$"; then
            echo "Tomcat" >>"${servicesToRestart}"
        elif [ "${pkg}" = "redis-server" ]; then
            echo "Redis" >>"${servicesToRestart}"
        elif [ "${pkg}" = "mongodb-server" ]; then
            echo "MondoDB" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -qE "^courier-(pop|imap)"; then
            echo "Courier POP/IMAP" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep -qE "^dovecot-(pop|imap)d"; then
            echo "Dovecot POP/IMAP" >>"${servicesToRestart}"
        elif [ "${pkg}" = "samba" ]; then
            echo "Samba" >>"${servicesToRestart}"
        elif [ "${pkg}" = "slapd" ]; then
            echo "OpenLDAP" >>"${servicesToRestart}"
        elif [ "${pkg}" = "bind9" ]; then
            echo "Bind9" >>"${servicesToRestart}"
        elif [ "${pkg}" = "postfix" ]; then
            echo "Postfix" >>"${servicesToRestart}"
        elif [ "${pkg}" = "haproxy" ]; then
            echo "HAProxy" >>"${servicesToRestart}"
        elif [ "${pkg}" = "varnish" ]; then
            echo "Varnish" >>"${servicesToRestart}"
        elif [ "${pkg}" = "squid" ]; then
            echo "Squid" >>"${servicesToRestart}"
        elif [ "${pkg}" = "elasticsearch" ]; then
            echo "Elasticsearch" >>"${servicesToRestart}"
        elif [ "${pkg}" = "logstash" ]; then
            echo "Logstash" >>"${servicesToRestart}"
        elif [ "${pkg}" = "kibana" ]; then
            echo "Kibana" >>"${servicesToRestart}"
        elif [ "${pkg}" = "libc6" ]; then
            echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libc6)." >"${servicesToRestart}"
            break
        elif [ "${pkg}" = "libstdc++6" ]; then
            echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libstdc++6)." >"${servicesToRestart}"
            break
        elif echo "${pkg}" | grep -q "^libssl"; then
            echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libssl)." >"${servicesToRestart}"
            break
        fi
    done
    test ! -s "${servicesToRestart}" && echo "Aucun" >"${servicesToRestart}"

    render_mail_template "${template}"
    /usr/sbin/sendmail "${mailto}" <"${template}"

    if ! cron_mode; then
        echo "Dowloading packages..."
    fi
    # Now we try to fetch all the packages for the next update session
    downloadstatus=$(apt -o Dir::State::Lists="${listupgrade_state_dir}" dist-upgrade --assume-yes --download-only -q2 2>&1)
    echo "${downloadstatus}" | grep -q 'Download complete and in download only mode'

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "${downloadstatus}"
    fi

    # Also, we try to update each container apt sources
    if which lxc-ls >/dev/null; then
        for container in $(lxc-ls); do

            aptUpdateOutput=$(lxc-attach -n "${container}" -- apt -o Dir::State::Lists="${listupgrade_state_dir}" update 2>&1 | (grep -Eve '^(Listing|WARNING|$)' -e upgraded -e 'up to date' || true))

            if (echo "${aptUpdateOutput}" | grep -E "^Err(:[0-9]+)? http"); then
                echo "FATAL CONTAINER - Not able to fetch all sources (probably a pesky (mini)firewall). Please, fix me" >&2
                post_hooks_and_exit 150
            fi

            # Now we try to fetch all the packages for the next update session
            downloadstatus=$(lxc-attach -n "${container}" -- apt -o Dir::State::Lists="${listupgrade_state_dir}" dist-upgrade --assume-yes --download-only -q2 2>&1)

            if echo "${downloadstatus}" | grep -q 'Download complete and in download only mode'; then
                echo "${downloadstatus}"
            fi

        done
    fi
}

# Options parsing.
while :; do
    case ${1} in
    -V | --version)
        show_version
        exit 0
        ;;
    --cron)
        cron_mode=1
        ;;
    -f | --force)
        # Ignore exclusions from "upgrade info" and do as if all releases and packages are to be upgraded
        force_mode=1
        ;;
    -?* | [[:alnum:]]*)
        # ignore unknown options
        printf 'ERROR: Unknown option : %s\n' "$1" >&2
        exit 1
        ;;
    *)
        # Default case: If no more options then break out of the loop.
        break
        ;;
    esac

    shift
done

## Do not stop on error. Instead we should catch them manually
# set -e
## Error on unassigned variables
set -u

export LC_ALL=C

configFile="/etc/evolinux/listupgrade.cnf"

cron_mode=${cron_mode:-0}
force_mode=${force_mode:-0}
clientmail=$(grep EVOMAINTMAIL /etc/evomaintenance.cf | cut -d'=' -f2)
mailto="${clientmail}"
date="Ce jeudi entre 18h00 et 23h00."
hostname=$(grep HOSTNAME /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
listupgrade_state_dir="${listupgrade_state_dir:-/var/lib/listupgrade}"
hooksDir="/etc/evolinux/listupgrade-hooks"

# If hostname is composed with -, remove the first part.
if [[ "${hostname}" =~ "-" ]]; then
    hostname=$(echo "${hostname}" | cut -d'-' -f2-)
fi
# Edit $configFile to override some variables.
# shellcheck disable=SC1090,SC1091
[ -r "${configFile}" ] && . "${configFile}"

# Create temporary files
packages=$(mktemp --tmpdir=/tmp listupgrade.XXX)
packagesHold=$(mktemp --tmpdir=/tmp listupgrade.XXX)
servicesToRestart=$(mktemp --tmpdir=/tmp listupgrade.XXX)
template=$(mktemp --tmpdir=/tmp listupgrade.XXX)
# Remove temporary files on exit.
# shellcheck disable=SC2064
trap "rm ${packages} ${packagesHold} ${servicesToRestart} ${template}" EXIT

if ! cron_mode; then
    echo "À quelle date/heure allez vous planifier les mises à jour ?"
    echo "Exemple : le jeudi 6 mars entre 18h00 et 23h00"
    echo -n "> "
    read -r date
    echo "À qui envoyer le mail ?"
    echo -n "> "
    read -r mailto
fi

# Execute pre hooks
pre_hooks

# call main function
main

# Execute post hooks and exit
post_hooks_and_exit 0
