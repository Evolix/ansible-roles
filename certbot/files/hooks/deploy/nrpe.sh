#!/bin/sh

error() {
    >&2 echo "${PROGNAME}: $1"
    exit 1
}
debug() {
    if [ "${VERBOSE}" = "1" ] && [ "${QUIET}" != "1" ]; then
        >&2 echo "${PROGNAME}: $1"
    fi
}
daemon_found_and_running() {
    test -n "$(pidof nrpe)"
}
letsencrypt_lineaged_used() {
    grep -r "^ssl_cert_file" /etc/nagios/ | grep "letsencrypt" | grep -q "$(basename "${RENEWED_LINEAGE}")"
}
copy_letsencrypt_cert() {
    DEST_CERTIFICATE=$(grep -r "^ssl_cert_file" /etc/nagios/ | awk -F'=' '{print $2}')
    DEST_PRIVATE_KEY=$(grep -r "^ssl_privatekey_file" /etc/nagios/ | awk -F'=' '{print $2}')

    install --mode 440 --group nagios ${RENEWED_LINEAGE}/fullchain.pem ${DEST_CERTIFICATE}
    install --mode 440 --group nagios ${RENEWED_LINEAGE}/privkey.pem ${DEST_PRIVATE_KEY}
}
main() {
    if daemon_found_and_running; then
        if letsencrypt_lineaged_used; then
            debug "NRPE detected... Copying certificates to the right place & permissions"
            copy_letsencrypt_cert
            debug "Restarting NRPE"
            systemctl restart nagios-nrpe-server
        else
            debug "NRPE doesn't use the given Let's Encrypt certificate. Skip."
        fi
    else
        debug "NRPE is not running or missing. Skip."
    fi
}

readonly PROGNAME=$(basename "$0")
readonly VERBOSE=${VERBOSE:-"0"}
readonly QUIET=${QUIET:-"0"}

main