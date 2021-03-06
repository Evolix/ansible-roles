#!/bin/bash

# Exit codes :
# - 30 : $skip_releases or $skip_packages is set to "all"
# - 40 : current release is in $skip_releases list
# - 50 : all upgradable packages are in the $skip_packages list
# - 60 : current release is not in the $r_releases list
# - 70 : at least an upgradable package is not in the $r_packages list

set -e

configFile="/etc/evolinux/listupgrade.cnf"

packages=$(mktemp --tmpdir=/tmp evoupdate.XXX)
packagesHold=$(mktemp --tmpdir=/tmp evoupdate.XXX)
servicesToRestart=$(mktemp --tmpdir=/tmp evoupdate.XXX)
template=$(mktemp --tmpdir=/tmp evoupdate.XXX)
clientmail=$(grep EVOMAINTMAIL /etc/evomaintenance.cf | cut -d'=' -f2)
mailto=$clientmail
date="Ce jeudi entre 18h00 et 23h00."
hostname=$(grep HOSTNAME /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
# If hostname is composed with -, remove the first part.
if [[ $hostname =~ "-" ]]; then
    hostname=$(echo $hostname | cut -d'-' -f2-)
fi
# Edit $configFile to override some variables.
[ -r $configFile ] && . $configFile

# Remove temporary files on exit.
trap "rm $packages $packagesHold $servicesToRestart $template" EXIT

# Parse line in retrieved upgrade file and ensure there is no malicious values.
get_value() {
    file="$1"
    variable="$2"
    value="$(grep "^$2:" $1 |head -n 1 |cut -d ':' -f 2 |sed 's/^ //')"
    if echo "$value" |grep -q -E '^[-.: [:alnum:]]*$'; then
        echo $value
    else
        printf >&2 "Error parsing value \"$value\" for variable $variables.\n"
    fi
}

# Fetch which packages/releases will be upgraded.
fetch_upgrade_info() {
    upgradeInfo=$(mktemp --tmpdir=/tmp evoupdate.XXX)
    wget -q -O $upgradeInfo https://upgrades.evolix.org/upgrade
    r_releases="$(get_value $upgradeInfo "releases")"
    r_skip_releases="$(get_value $upgradeInfo "skip_releases")"
    r_packages="$(get_value $upgradeInfo "packages")"
    r_skip_packages="$(get_value $upgradeInfo "skip_packages")"
    rm $upgradeInfo
}

# Check if element $element is in (space separated) list $list.
is_in() {
    list="$1"
    element="$2"

    for i in $list; do
        if [ "$element" = "$i" ]; then
            return 0
        fi
    done
    return 1
}


if [[ "$1" != "--cron" ]]; then
    echo "À quel date/heure allez vous planifier l'envoi ?"
    echo "Exemple : le jeudi 6 mars entre 18h00 et 23h00"
    echo -n ">"
    read date
    echo "À qui envoyer le mail ?"
    echo -n ">"
    read mailto
fi

# Update APT cache and get packages to upgrade and packages on hold.
aptUpdateOutput=$(apt update 2>&1 | (egrep -ve '^(Listing|WARNING|$)' -e upgraded -e 'up to date' || true ))

if (echo "$aptUpdateOutput" | egrep "^Err(:[0-9]+)? http"); then
  echo "FATAL - Not able to fetch all sources (probably a pesky (mini)firewall). Please, fix me"
  exit 100
fi

apt-mark showhold > $packagesHold
apt list --upgradable 2>&1 | grep -v -f $packagesHold | egrep -v '^(Listing|WARNING|$)' > $packages
packagesParsable=$(cut -f 1 -d / <$packages |tr '\n' ' ')

# No updates? Exit!
test ! -s $packages && exit 0
test ! -s $packagesHold && echo 'Aucun' > $packagesHold

fetch_upgrade_info
local_release=$(cut -f 1 -d . </etc/debian_version)

# Exit if skip_releases or skip_packages in upgrade info file are set to all.
([ "$r_skip_releases" = "all" ] || [ "$r_skip_packages" = "all" ]) && exit 30

# Exit if the server's release is in skip_releases.
[ -n "$r_skip_releases" ] && is_in "$r_skip_releases" "$local_release" && exit 40

# Exit if all packages to upgrade are listed in skip_packages:
# we remove each package to skip from the $packageToUpgrade list. At the end,
# if there is no additional packages to upgrade, we can exit.
if [ -n "$r_skip_packages" ]; then
    packageToUpgrade="$packagesParsable"
    for pkg in $r_skip_packages; do
        packageToUpgrade="${packageToUpgrade/$pkg}"
    done
    packageToUpgrade=$(echo $packageToUpgrade |sed 's/  \+//g')
    if [ -z "$packageToUpgrade" ]; then
        exit 50
    fi
fi

# Exit if the server's release is not in releases.
if [ -n "$r_releases" ] && [ "$r_releases" != "all" ]; then
    is_in "$r_releases" "$local_release" || exit 60
fi

# Exit if there is packages to upgrades that are not in packages list:
# we exit at the first package encountered that is not in packages list.
if [ -n "$r_packages" ] && [ "$r_packages" != "all" ]; then
    for pkg in $packagesParsable; do
        is_in "$r_packages" "$pkg" || exit 70
    done
fi

# Guess which services will be restarted.
for pkg in $packagesParsable; do
    if echo "$pkg" |grep -qE "^(lib)?apache2"; then
        echo "Apache2" >>$servicesToRestart
    elif echo "$pkg" |grep -q "^nginx"; then
        echo "Nginx" >>$servicesToRestart
    elif echo "$pkg" |grep -q "^php5-fpm"; then
        echo "PHP FPM" >>$servicesToRestart
    elif echo "$pkg" |grep -q "^mysql-server"; then
        echo "MySQL" >>$servicesToRestart
    elif echo "$pkg" |grep -q "^mariadb-server"; then
        echo "MariaDB" >>$servicesToRestart
    elif echo "$pkg" |grep -qE "^postgresql-[[:digit:]]+\.[[:digit:]]+$"; then
        echo "PostgreSQL" >>$servicesToRestart
    elif echo "$pkg" |grep -qE "^tomcat[[:digit:]]+$"; then
        echo "Tomcat" >>$servicesToRestart
    elif [ "$pkg" = "redis-server" ]; then
        echo "Redis" >>$servicesToRestart
    elif [ "$pkg" = "mongodb-server" ]; then
        echo "MondoDB" >>$servicesToRestart
    elif echo "$pkg" |grep -qE "^courier-(pop|imap)"; then
        echo "Courier POP/IMAP" >>$servicesToRestart
    elif echo "$pkg" |grep -qE "^dovecot-(pop|imap)d"; then
        echo "Dovecot POP/IMAP" >>$servicesToRestart
    elif [ "$pkg" = "samba" ]; then
        echo "Samba" >>$servicesToRestart
    elif [ "$pkg" = "slapd" ]; then
        echo "OpenLDAP" >>$servicesToRestart
    elif [ "$pkg" = "bind9" ]; then
        echo "Bind9" >>$servicesToRestart
    elif [ "$pkg" = "postfix" ]; then
        echo "Postfix" >>$servicesToRestart
    elif [ "$pkg" = "haproxy" ]; then
        echo "HAProxy" >>$servicesToRestart
    elif [ "$pkg" = "varnish" ]; then
        echo "Varnish" >>$servicesToRestart
    elif [ "$pkg" = "squid" ]; then
        echo "Squid" >>$servicesToRestart
    elif [ "$pkg" = "elasticsearch" ]; then
        echo "Elasticsearch" >>$servicesToRestart
    elif [ "$pkg" = "logstash" ]; then
        echo "Logstash" >>$servicesToRestart

    elif [ "$pkg" = "libc6" ]; then
        echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libc6)." >$servicesToRestart
        break
    elif [ "$pkg" = "libstdc++6" ]; then
        echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libstdc++6)." >$servicesToRestart
        break
    elif echo "$pkg" |grep -q "^libssl"; then
        echo "Tous les services sont susceptibles d'être redémarrés (mise à jour de libssl)." >$servicesToRestart
        break
    fi
done
test ! -s $servicesToRestart && echo "Aucun" >$servicesToRestart

cat << EOT > $template
Content-Type: text/plain; charset="utf-8"
Reply-To: equipe@evolix.fr
From: equipe@evolix.net
To: ${clientmail}
Subject: Prochain creneau pour mise a jour de votre serveur $hostname
X-Debian-Release: $local_release
X-Packages: $packagesParsable
X-Date: $date

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

$(cat $packages)

Liste des packages dont la mise-à-jour a été manuellement suspendue :

$(cat $packagesHold)

Liste des services qui seront redémarrés :

$(cat $servicesToRestart)

N'hésitez pas à nous faire toute remarque sur ce créneau d'intervention le plus
tôt possible.

Cordialement,
--
Équipe Evolix - Hébergement et Infogérance Open Source
http://evolix.com | Twitter: @Evolix @EvolixNOC | http://blog.evolix.com
EOT

<$template /usr/sbin/sendmail $mailto

# Now we try to fetch all the packages for the next update session
downloadstatus=$(apt dist-upgrade --assume-yes --download-only -q2 2>&1)
echo "$downloadstatus" | grep -q 'Download complete and in download only mode'

if [ $? -ne 0 ]; then
    echo "$downloadstatus"
fi;
