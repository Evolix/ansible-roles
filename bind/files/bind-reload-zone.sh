#!/bin/bash
#
# Script utilitaire pour tester et recharger facilement une zone dans Bind
#

usage() {
    echo "Usage: bind-reload-zone <DOMAIN>"
    echo "       bind-reload-zone -h|--help"
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

if ! [ -f "/etc/bind/db.${zone}" ]; then
    >&2 echo "Error: zone for ${zone} not found."
    usage
    exit 1
fi

named-checkzone "${zone}" /etc/bind/db."${zone}" && rndc reload "${zone}"

