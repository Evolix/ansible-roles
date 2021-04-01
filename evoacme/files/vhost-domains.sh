#!/bin/bash
#
# make-csr is a shell script designed to automatically generate a
# certificate signing request (CSR) from an Apache or a Nginx vhost
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

set -u

show_version() {
    cat <<END
vhost-domains version ${VERSION}

Copyright 2009-2021 Evolix <info@evolix.fr>,
                    Victor Laborie <vlaborie@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Benoit Série <bserie@evolix.fr>
                    and others.

vhost-domains comes with ABSOLUTELY NO WARRANTY. This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}

show_help() {
    cat <<EOT
Usage: ${PROGNAME} VHOST
    VHOST must correspond to an Apache or Nginx enabled VHost
    If VHOST ends with ".conf" it is stripped,
    then files are seached at those paths:
    - /etc/apache2/sites-enables/VHOST.conf
    - /etc/nginx/sites-enabled/VHOST.conf
    - /etc/nginx/sites-enabled/VHOST

    If env variable QUIET=1, no message is output
    If env variable VERBOSE=1, debug messages are output
EOT
}

log() {
    if [ "${QUIET}" != "1" ]; then
        echo "${PROGNAME}: $1"
    fi
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
error() {
    >&2 echo "${PROGNAME}: $1"
    [ "$1" = "invalid argument(s)" ] && >&2 show_help
    exit 1
}

real_ip_for_domain() {
    dig +short "$1" | grep -oE "([0-9]+\.){3}[0-9]+"
}
local_ip() {
    ip a | grep brd | cut -d'/' -f1 | grep -oE "([0-9]+\.){3}[0-9]+"
}

nginx_domains() {
    local vhost_file="$1"

    grep -oE "^( )*[^#]+" "${vhost_file}" \
        | grep -oE "[^\$]server_name.*;$" \
        | sed 's/server_name//' \
        | tr -d ';' \
        | sed 's/\s\{1,\}//' \
        | sed 's/\s\{1,\}/\n/g' \
        | sort \
        | uniq
}

apache_domains() {
    local vhost_file="$1"

    grep -oE "^( )*[^#]+" "${vhost_file}" \
        | grep -oE "(ServerName|ServerAlias).*" \
        | sed 's/ServerName//' \
        | sed 's/ServerAlias//' \
        | sed 's/\s\{1,\}//' \
        | sort \
        | uniq
}

get_domains() {
    local vhost_file="$1"
    local ips="$2"
    local domains=""
    local valid_domains=""
    local nb=0

    if $(echo "${vhost_file}" | grep -q nginx); then
        debug "Nginx vhost file used"
        domains=$(nginx_domains "${vhost_file}")
    fi
    if $(echo "${vhost_file}" | grep -q apache2); then
        debug "Apache vhost file used"
        domains=$(apache_domains "${vhost_file}")
    fi

    debug "Valid(s) domain(s) in ${vhost_file} :"
    for domain in ${domains}; do
        real_ip=$(real_ip_for_domain "${domain}")
        for ip in $(echo "${ips}" | xargs -n1); do
            if [ "${ip}" = "${real_ip}" ]; then
                valid_domains="${valid_domains} ${domain}"
                nb=$(( nb  + 1 ))
                debug "* ${domain} -> ${real_ip}"
            fi
        done
    done

    if [ "${nb}" -eq 0 ]; then
        nb=$(echo "${domains}" | wc -l)
        debug "* No valid domain found"
        debug "All following(s) domain(s) will be used for CSR creation :"
        for domain in ${domains}; do
            debug "* ${domain}"
        done
    else
        domains="${valid_domains}"
    fi

    echo "${domains}" | xargs -n 1
}

first_vhost_file_found() {
    local vhost_name="$1"

    ls "/etc/nginx/sites-enabled/${vhost_name}" \
       "/etc/nginx/sites-enabled/${vhost_name}.conf" \
       "/etc/apache2/sites-enabled/${vhost_name}.conf" \
        2>/dev/null \
        | head -n 1
}

main() {
    # check arguments
    [ "$#" -eq 1 ] || error "invalid argument(s)"

    [ "$1" = "-h" ] || [ "$1" = "--help" ] && show_help && exit 0
    [ "$1" = "-V" ] || [ "$1" = "--version" ] && show_version && exit 0

    local vhost_name=$(basename "$1" .conf)
    local vhost_file=$(first_vhost_file_found "${vhost_name}")

    if [ ! -h "${vhost_file}" ]; then
        >&2 echo "No virtualhost has been found for '${vhost_name}'."
        exit 1
    fi

    local ips=$(local_ip)
    if [ -n "${SRV_IP}" ]; then
        ips="${ips} ${SRV_IP}"
    fi

    get_domains "${vhost_file}" "${ips}"
}

readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(realpath -m $(dirname "$0"))
readonly ARGS=$@

readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

readonly VERSION="21.01"

readonly SRV_IP=${SRV_IP:-""}

main $ARGS
