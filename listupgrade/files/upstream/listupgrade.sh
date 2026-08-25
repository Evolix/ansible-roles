#!/bin/bash

# Repository: https://forge.evolix.net/evolix/maj.sh/

# Exit codes :
# - 10 : Failure to fetch upgrade informations
# - 20 : hostname does not match $ext_hosts (external mode)
# - 30 : $skip_releases or $skip_packages is set to "all"
# - 40 : current release is in $skip_releases list
# - 50 : all upgradable packages are in the $skip_packages list
# - 60 : current release is not in the $r_releases list
# - 70 : at least an upgradable package is not in the $r_packages list
# - 100 : Failure to apt update
# - 110 : Failure to apt upgrade --download only
# - 150 : Inside an LXC container: Failure to apt update
# - 160 : Inside an LXC container: Failure to apt upgrade --download only

VERSION="26.05"
readonly VERSION

PROGNAME=$(basename "$0")
readonly PROGNAME

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2026 Evolix <info@evolix.fr>,
               Gregory Colpart <reg@evolix.fr>,
               Romain Dessort <rdessort@evolix.fr>,
               Ludovic Poujol <lpoujol@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>,
               David Prevot <dprevot@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under
certain conditions. See the GNU General Public Licence for details.
END
}

# Parse line in retrieved upgrade file and ensure there is no malicious values.
get_value() {
    file="$1"
    variable="$2"
    value="$(grep "^${variable}:" "${file}" | head -n 1 | cut -d ':' -f 2 | sed 's/^ //')"

    if echo "${value}" | grep --quiet --extended-regexp '^[-.: [:alnum:]]*$'; then
        echo "${value}"
    else
        printf >&2 "Error parsing value \"%s\" for variable %s.\n" "${value}" "${variable}"
    fi
}

# Fetch which packages/releases will be upgraded.
fetch_upgrade_info() {
    wget --no-check-certificate --quiet --output-document="${upgradeInfo}" https://upgrades.evolix.org/upgrade

    # shellcheck disable=SC2181
    if [ "$?" != "0" ]; then
        printf >&2 "Error fetching upgrade directives.\n"
        post_hooks_and_exit 10
    fi

    r_releases="$(get_value "${upgradeInfo}" "releases")"
    r_skip_releases="$(get_value "${upgradeInfo}" "skip_releases")"
    r_packages="$(get_value "${upgradeInfo}" "packages")"
    r_skip_packages="$(get_value "${upgradeInfo}" "skip_packages")"
    r_ext_hosts="$(get_value "${upgradeInfo}" "ext_hosts")"
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
From: ${from}
To: ${clientmail}
Subject: Prochain creneau pour mise a jour de votre serveur ${hostname}
X-Debian-Release: ${local_release}
X-Packages: $(echo "${packagesParsable}" | cut -c 1-900)
X-Date: ${date}
X-Listupgrade-Version: ${VERSION}
X-External: ${ext_mode}
Auto-Submitted: auto-generated

Bonjour,

Des mises-à-jour de sécurité ou mineures sont à réaliser sur votre serveur
${hostname}.
Sauf indication contraire de votre part, le prochain créneau prévu pour
intervenir manuellement pour réaliser ces mises à jour est :
${date}

Voici la listes de packages qui seront mis à jour :

$(sort -h "${packages}" | uniq)

Liste des packages dont la mise-à-jour a été manuellement suspendue :

$(sort -h "${packagesHold}" | uniq)

Liste des services qui seront redémarrés (entraînant a priori
quelques secondes de coupure) :

$(sort -h "${servicesToRestart}" | uniq)

N'hésitez pas à nous faire toute remarque sur ce créneau d'intervention
le plus tôt possible.

Cordialement,
--
Équipe Evolix - Hébergement et Infogérance Open Source
https://evolix.com | mastodon.evolix.org/@evolix | blog.evolix.com
EOT
}
# Files found in the directory passed as 1st argument
# are executed if they are executable
# and if their name doesn't contain a dot
exec_hooks_in_dir() {
    hooks=$(find "${1}" -follow -type f -executable -not -name '*.*' -print0 | sort --zero-terminated --dictionary-order | xargs --no-run-if-empty --null --max-args=1)
    for hook in ${hooks}; do
        if ! cron_mode; then
            printf "Running '%s\`\n" "${hook}"
        fi
        ${hook}
    done
}
pre_hooks() {
    if [ -d "${hooks_dir}/pre" ]; then
        exec_hooks_in_dir "${hooks_dir}/pre"
    fi
}
post_hooks_and_exit() {
    status=${1:-0}
    if [ -d "${hooks_dir}/post" ]; then
        exec_hooks_in_dir "${hooks_dir}/post"
    fi
    exit ${status}
}

cron_mode() {
    test "${cron_mode}" = "1"
}

ext_mode() {
    test "${ext_mode}" = "1"
}

force_mode() {
    test "${force_mode}" = "1"
}

main() {
    # TODO: Use evolibs ?
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
        *forky*) 
            local_release=14
            ;;
        *duke*) 
            local_release=15
            ;;
    esac


    if force_mode; then
        if ! cron_mode; then
            echo "Force mode is enabled, as if every release/package is available for upgrade."
        fi
    elif ext_mode; then
        fetch_upgrade_info

        # Exit if hostname does not match the expected ^[ext_hosts] regex
        if echo ${hostname} | grep --quiet --invert-match "^[${r_ext_hosts}]"; then
            post_hooks_and_exit 20
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

    ### Update cache and build lists

    if ! cron_mode; then
        echo "Updating lists..."
    fi
    # Update APT cache and get packages to upgrade and packages on hold.
    aptUpdateOutput=$(apt-get -o Dir::State::Lists="${listupgrade_state_dir}" -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" update 2>&1 | (grep --extended-regexp --invert-match --regexp '^(Listing|WARNING|$)' --regexp upgraded --regexp 'up to date' || true))

    if echo "${aptUpdateOutput}" | grep --extended-regexp "^Err(:[0-9]+)? http"; then
        echo "FATAL - Not able to fetch all sources (probably a pesky (mini)firewall). Please, fix me" >&2
        post_hooks_and_exit 100
    fi

    apt-mark showhold | sed -e 's/\(.\+\)/^\1\//' >"${packagesHold}"
    apt -o Dir::State::Lists="${listupgrade_state_dir}" -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" list --upgradable 2>&1 | grep --invert-match --file "${packagesHold}" | grep --invert-match --extended-regexp '^(Listing|WARNING|$)' >"${packages}"
    packagesParsable=$(cut -f 1 -d / <"${packages}" | xargs)

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


    # Guess which services will be restarted.
    for pkg in ${packagesParsable}; do
        if echo "${pkg}" | grep --quiet --extended-regexp "^(lib)?apache2"; then
            echo "Apache2" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet "^nginx"; then
            echo "Nginx" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet "^php5-fpm"; then
            echo "PHP FPM" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet "^mysql-server"; then
            echo "MySQL" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet "^mariadb-server"; then
            echo "MariaDB" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet --extended-regexp "^postgresql-[[:digit:]]+(\.[[:digit:]]+)?$"; then
            echo "PostgreSQL" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet --extended-regexp "^tomcat[[:digit:]]+$"; then
            echo "Tomcat" >>"${servicesToRestart}"
        elif [ "${pkg}" = "redis-server" ]; then
            echo "Redis" >>"${servicesToRestart}"
        elif [ "${pkg}" = "mongodb-server" ]; then
            echo "MondoDB" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet --extended-regexp "^courier-(pop|imap)"; then
            echo "Courier POP/IMAP" >>"${servicesToRestart}"
        elif echo "${pkg}" | grep --quiet --extended-regexp "^dovecot-(pop|imap)d"; then
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
        elif echo "${pkg}" | grep --quiet "^libssl"; then
            echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libssl)." >"${servicesToRestart}"
            break
        fi
    done
    test ! -s "${servicesToRestart}" && echo "Aucun" >"${servicesToRestart}"

    render_mail_template "${template}"
    /usr/sbin/sendmail -oi -t -f "${from}" "${mailto}" <"${template}"

    ### Download packages

    if ! cron_mode; then
        echo "Dowloading packages..."
    fi
    # Now we try to fetch all the packages for the next update session
    downloadstatus=$(apt-get -o Dir::State::Lists="${listupgrade_state_dir}" -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" dist-upgrade --assume-yes --download-only -q 2>&1)
    apt_rc=$?
    echo "${downloadstatus}" | grep --quiet -e 'Download complete and in download only mode' -e '0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.'
    download_rc=$?

    # shellcheck disable=SC2181
    if [ ${apt_rc} -ne 0 ] || [ ${download_rc} -ne 0 ]; then
        echo "${downloadstatus}"
        post_hooks_and_exit 110
    fi

    # Also, we try to update each container apt sources
    if which lxc-ls >/dev/null; then
        for container in $( lxc-ls -1 --active | grep --invert-match --regexp php56 --regexp php70 ); do

            aptUpdateOutput=$(lxc-attach -n "${container}" -- apt-get -o Dir::State::Lists="${listupgrade_state_dir}" update 2>&1 | (grep --extended-regexp --invert-match --regexp '^(Listing|WARNING|$)' --regexp upgraded --regexp 'up to date' || true))

            if (echo "${aptUpdateOutput}" | grep --extended-regexp "^Err(:[0-9]+)? http"); then
                echo "FATAL CONTAINER - Not able to fetch all sources (probably a pesky (mini)firewall). Please, fix me" >&2
                post_hooks_and_exit 150
            fi

            # Now we try to fetch all the packages for the next update session
            downloadstatus=$(lxc-attach -n "${container}" -- apt-get -o Dir::State::Lists="${listupgrade_state_dir}" dist-upgrade --assume-yes --download-only -q 2>&1)
            apt_rc=$?
            echo "${downloadstatus}" | grep --quiet -e 'Download complete and in download only mode' -e '0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.'
            download_rc=$?

            # shellcheck disable=SC2181
            if [ ${apt_rc} -ne 0 ] || [ ${download_rc} -ne 0 ]; then
                echo "${downloadstatus}"
                post_hooks_and_exit 160
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
    -e | --external | --ext )
        ext_mode=1
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

config_file="/etc/evolinux/listupgrade.cnf"

cron_mode=${cron_mode:-0}
ext_mode=${ext_mode:-0}
force_mode=${force_mode:-0}
clientmail=$(grep "^\s*EVOMAINTMAIL=" /etc/evomaintenance.cf | cut -d'=' -f2)
from=$(grep "^\s*FROM=" /etc/evomaintenance.cf | cut -d'=' -f2)
mailto="${clientmail}"
date="Ce jeudi entre 18h00 et 23h00."
hostname=$(grep "^\s*HOSTNAME=" /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
listupgrade_state_dir="${listupgrade_state_dir:-/var/lib/listupgrade}"
hooks_dir="/etc/evolinux/listupgrade-hooks"
listupgrade_sources_dir="${listupgrade_sources_dir:-/etc/apt/listupgrade-sources.list.d}"
listupgrade_sources_file="${listupgrade_sources_file:-/etc/apt/sources.list}"
if ext_mode; then
    config_file="/etc/evolinux/listupgrade-ext.cnf"
    date="Ce mercredi entre 8h00 et 10h00."
    listupgrade_state_dir="/var/lib/listupgrade-external"
    listupgrade_sources_dir="/etc/apt/listupgrade-external-sources.list.d"
    listupgrade_sources_file="/dev/null"
fi

# If hostname is composed with -, remove the first part.
if [[ "${hostname}" =~ "-" ]]; then
    hostname=$(echo "${hostname}" | cut -d'-' -f2-)
fi
# Edit $config_file to override some variables.
# shellcheck disable=SC1090,SC1091
[ -r "${config_file}" ] && . "${config_file}"
# Enable force mode if the upgrade should happen on Tuesday
if $(echo ${date} | grep -q mardi);
    then force_mode=1
fi

# Create temporary files
packages=$(mktemp --tmpdir=/tmp listupgrade.XXX)
packagesHold=$(mktemp --tmpdir=/tmp listupgrade.XXX)
servicesToRestart=$(mktemp --tmpdir=/tmp listupgrade.XXX)
template=$(mktemp --tmpdir=/tmp listupgrade.XXX)
upgradeInfo=$(mktemp --tmpdir=/tmp listupgrade.XXX)
# Remove temporary files on exit.
# shellcheck disable=SC2064
trap "rm ${packages} ${packagesHold} ${servicesToRestart} ${template} ${upgradeInfo}" EXIT

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
