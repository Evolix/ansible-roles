#!/bin/sh
#
# make-csr is a shell script designed to automatically generate a
# certificate signing request (CSR) from an Apache or a Nginx vhost
#
# Author: Victor Laborie <vlaborie@evolix.fr>
# Licence: AGPLv3
#

real_ip_for_domain() {
  dig +short "$1" | grep -oE "([0-9]+\.){3}[0-9]+"
}

get_domains() {
    echo "$vhostfile" | grep -q nginx
    if [ "$?" -eq 0 ]; then
        domains=$(
          grep -oE "^( )*[^#]+" "$vhostfile" \
          | grep -oE "[^\$]server_name.*;$" \
          | sed 's/server_name//' \
          | tr -d ';' \
          | sed 's/\s\{1,\}//' \
          | sed 's/\s\{1,\}/\n/g' \
          | sort \
          | uniq
        )
    fi

    echo "$vhostfile" | grep -q apache2
    if [ "$?" -eq 0 ]; then
        domains=$(
          grep -oE "^( )*[^#]+" "$vhostfile" \
          | grep -oE "(ServerName|ServerAlias).*" \
          | sed 's/ServerName//' \
          | sed 's/ServerAlias//' \
          | sed 's/\s\{1,\}//' \
          | sort \
          | uniq
        )
    fi
    valid_domains=""
    nb=0

    echo "Valid(s) domain(s) in ${VHOST} :"
    for domain in $domains; do
        real_ip=$(real_ip_for_domain "${domain}")
        for ip in $(echo "${SRV_IP}" | xargs -n1); do
            if [ "${ip}" = "${real_ip}" ]; then
                valid_domains="${valid_domains} ${domain}"
                nb=$(( nb  + 1 ))
                echo "* ${domain} -> ${real_ip}"
            fi
        done
    done

    if [ "${nb}" -eq 0 ]; then
        nb=$(echo "${domains}" | wc -l)
        echo "* No valid domain found"
        echo "All following(s) domain(s) will be used for CSR creation :"
        for domain in $domains; do
            echo "* ${domain}"
        done
    else
        domains="${valid_domains}"
    fi

    domains=$(echo "$domains" | xargs -n1)
}

make_key() {
    openssl genrsa -out "${SSL_KEY_FILE}" "${SSL_KEY_SIZE}" 2>/dev/null
    chown root: "${SSL_KEY_FILE}"
    chmod 600 "${SSL_KEY_FILE}"
}

make_csr() {
    domains="$1"
    nb=$(echo "${domains}" | wc -l)
    config_file="/tmp/make-csr-${VHOST}.conf"

    mkdir -p -m 0755 "${CSR_DIR}"

    if [ "${nb}" -eq 1 ]; then
        cat ${SSL_CONFIG_FILE} - > "${config_file}" <<EOF
CN=$domains
EOF
        openssl req -new -sha256 -key "${SSL_KEY_FILE}" -config "${config_file}" -out "${CSR_FILE}"
    elif [ "${nb}" -gt 1 ]; then
        san=""
        for domain in $domains; do
            san="${san},DNS:${domain}"
        done
        san=$(echo "${san}" | sed 's/,//')
        cat ${SSL_CONFIG_FILE} - > "${config_file}" <<EOF
[SAN]
subjectAltName=${san}
EOF
        openssl req -new -sha256 -key "${SSL_KEY_FILE}" -reqexts SAN -config "${config_file}" > "${CSR_FILE}"
    fi

    if [ -f "${CSR_FILE}" ]; then
        chmod 644 "${CSR_FILE}"
        mkdir -p -m 0755 "${SELF_SIGNED_DIR}"
        openssl x509 -req -sha256 -days 365 -in "${CSR_FILE}" -signkey "${SSL_KEY_FILE}" -out "${SELF_SIGNED_FILE}"
        [ -f "${SELF_SIGNED_FILE}" ] && chmod 644 "${SELF_SIGNED_FILE}"
    fi
}

sed_selfsigned_cert_path_for_apache() {
    apache_ssl_vhost_path=$1

    mkdir -p $(dirname "${apache_ssl_vhost_path}")
    if [ ! -f "${apache_ssl_vhost_path}" ]; then
        cat > "${apache_ssl_vhost_path}" <<EOF
SSLEngine On
SSLCertificateFile    ${SELF_SIGNED_FILE}
SSLCertificateKeyFile ${SSL_KEY_FILE}
EOF
    else
        sed -i "s~^SSLCertificateFile.*$~SSLCertificateFile ${SELF_SIGNED_FILE}~" "${apache_ssl_vhost_path}"
    fi
}

sed_selfsigned_cert_path_for_nginx() {
    nginx_ssl_vhost_path=$1

    mkdir -p $(dirname "${nginx_ssl_vhost_path}")
    if [ ! -f "${nginx_ssl_vhost_path}" ]; then
        cat > "${nginx_ssl_vhost_path}" <<EOF
ssl_certificate ${SELF_SIGNED_FILE};
ssl_certificate_key ${SSL_KEY_FILE};
EOF
    else
        sed -i "s~^ssl_certificate[^_].*$~ssl_certificate ${SELF_SIGNED_FILE};~" "${nginx_ssl_vhost_path}"
    fi
}

first_vhost_file_found() {
  vhost=$1

  ls "/etc/nginx/sites-enabled/${vhost}" \
     "/etc/nginx/sites-enabled/${vhost}.conf" \
     "/etc/apache2/sites-enabled/${vhost}.conf" 2>/dev/null \
  | head -n 1
}

default_key_size() {
  grep default_bits ${SSL_CONFIG_FILE} \
  | cut -d'=' -f2 \
  | xargs
}

main() {
    if [ "$#" -ne 1 ]; then
        echo "You need to provide one argument !" >&2
        exit 1
    fi

    # Read configuration file, if it exists
    [ -f /etc/default/evoacme ] && . /etc/default/evoacme

    # Default value for main variables
    CSR_DIR=${CSR_DIR:-'/etc/ssl/requests'}
    CRT_DIR=${CRT_DIR:-'/etc/letsencrypt'}
    SSL_CONFIG_FILE=${SSL_CONFIG_FILE:-"${CRT_DIR}/openssl.cnf"}
    SELF_SIGNED_DIR=${SELF_SIGNED_DIR:-'/etc/ssl/self-signed'}
    SSL_KEY_DIR=${SSL_KEY_DIR:-'/etc/ssl/private'}
    SSL_KEY_SIZE=${SSL_KEY_SIZE:-$(default_key_size)}
    SRV_IP=${SRV_IP:-""}

    VHOST=$(basename "$1" .conf)
    SELF_SIGNED_FILE="${SELF_SIGNED_DIR}/${VHOST}.pem"
    SSL_KEY_FILE="${SSL_KEY_DIR}/${VHOST}.key"
    LIVE_DIR="${CRT_DIR}/${VHOST}/live"
    CSR_FILE="${CSR_DIR}/${VHOST}.csr"

    local_ip=$(ip a | grep brd | cut -d'/' -f1 | grep -oE "([0-9]+\.){3}[0-9]+")
    if [ -n "${SRV_IP}" ]; then
        SRV_IP="${SRV_IP} ${local_ip}"
    else
        SRV_IP="${local_ip}"
    fi

    vhostfile=$(first_vhost_file_found "${VHOST}")

    if [ ! -h "${vhostfile}" ]; then
        echo "${VHOST} is not a valid virtualhost !" >&2
        exit 1
    fi

    if [ -f "${SSL_KEY_FILE}" ]; then
        echo "${VHOST} key already exist, overwrite it? [yN]"
        read REPLY

        [ "${REPLY}" = "Y" ] || [ "${REPLY}" = "y" ] || exit 0
        rm -f "/etc/apache2/ssl/${VHOST}.conf /etc/nginx/ssl/${VHOST}.conf"
        [ -h "${LIVE_DIR}" ] && rm "${LIVE_DIR}"
    fi

    get_domains
    make_key
    make_csr "${domains}"

    command -v apache2ctl >/dev/null && sed_selfsigned_cert_path_for_apache "/etc/apache2/ssl/${VHOST}.conf"
    command -v nginx >/dev/null && sed_selfsigned_cert_path_for_nginx "/etc/nginx/ssl/${VHOST}.conf"
}

main "$@"
