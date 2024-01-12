#!/bin/bash
#
# Script utilitaire pour tester et recharger facilement une zone dans Bind
# Supporte le rechargement des reverses.
#

usage() {
    echo "Usage: bind-reload-zone <DOMAIN>"
    echo "       bind-reload-zone -h|--help"
    echo "Usage: bind-reload-reverse <SUBNET>"
    echo "       bind-reload-reverse -h|--help"
}

if [ $# -ne 1 ] ; then
    usage
    exit 1
fi

while :; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            zone=$1
            break
            ;;
    esac
    shift
done

# TODO :
# - check if zone exists
# - look for zone file

#grep -v -h -E '[[:blank:]]*//' /etc/bind/named.conf.* | awk '/zone[^\n]*{/ { in_zone=1; level=0; name=$2; gsub(/"/, "", name) } { if (in_zone) { if ($0 ~ "{") level++; else if ($0 ~ "}") level--; if (!level) in_zone=0; if (name=="nrouvierephotographie.com") print $0 } }'

if ! [ -f "/etc/bind/db.${zone}" ]; then
    >&2 echo "Error: zone for ${zone} not found."
    usage
    exit 1
fi

named-checkzone "${zone}" /etc/bind/db."${zone}" && rndc reload "${zone}"

