#!/bin/sh

VERSION="22.12.1"

show_version() {
    cat <<END
cert-expirations.sh version ${VERSION}

Copyright 2020-2022 Evolix <info@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Jérémy Dubois <jdubois@evolix.fr>
                    and others.

cert-expirations.sh comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the MIT Licence for details.
END
}

show_usage() {
    cat <<END
Usage: ${0} [--version]
END
}

check_carp_state() {
    if [ "${SYSTEM}" = "openbsd" ]; then
        carp=$(/sbin/ifconfig carp0 2>/dev/null | grep 'status' | cut -d' ' -f2)

        if [ "$carp" = "backup" ]; then
            exit 0
        fi
    fi
}

check_ca_expiration() {
    echo "CA certificate:"
    openssl x509 -enddate -noout -in ${cacert_path} \
        | cut -d '=' -f 2 \
        | sed -e "s/^\(.*\)\ \(20..\).*/- \2 \1/"
}

check_certs_expiration() {
    # Syntax "cmd | { while read line; do var="foo"; done echo $var }" needed, otherwise $var is empty at the end of while loop
    grep ^V ${index_path} \
        | awk -F "/" '{print $1,$5}' \
        | awk '{print $2,$5}' \
        | sed 's/CN=//' \
        | sed -E 's/([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})Z (.*)/- 20\1 \2 \3 \4:\5:\6 \7/' \
        | awk '{if ($3 == "01") $3="Jan"; else if ($3 == "02") $3="Feb"; else if ($3 == "03") $3="Mar"; else if ($3 == "04") $3="Apr"; else if ($3 == "05") $3="May"; else if ($3 == "06") $3="Jun"; else if ($3 == "07") $3="Jul"; else if ($3 == "08") $3="Aug"; else if ($3 == "09") $3="Sep"; else if ($3 == "10") $3="Oct"; else if ($3 == "11") $3="Nov"; else if ($3 == "12") $3="Dec"; print $0;}' \
        | sort -n -k 2 -k 3M -k 4 | { 
            while read -r line; do
    
            # Predicting expirations - OpenBSD case (date is not the same than in Linux)
            if [ "${SYSTEM}" = "openbsd" ]; then
                # Already expired if expiration date is before now
                if [ "$(TZ=:Zulu date -jf "%Y %b %d %H:%M:%S" "$(echo "$line" | awk '{print $2,$3,$4,$5}')" +%s)" -le "$(date +%s)" ]; then
                    expired_certs="${expired_certs}$line\n"
                # Expiring soon if expiration date is after now and before now + $somedays days
                elif [ "$(TZ=:Zulu date -jf "%Y %b %d %H:%M:%S" "$(echo "$line" | awk '{print $2,$3,$4,$5}')" +%s)" -gt "$(date +%s)" ] && [ "$(TZ=:Zulu date -jf "%Y %b %d %H:%M:%S" "$(echo "$line" | awk '{print $2,$3,$4,$5}')" +%s)" -lt "$(($(date +%s) + somedays))" ]; then
                    expiring_soon_certs="${expiring_soon_certs}$line\n"
                # Still valid for a time if expiration date is after now + $somedays days
                elif [ "$(TZ=:Zulu date -jf "%Y %b %d %H:%M:%S" "$(echo "$line" | awk '{print $2,$3,$4,$5}')" +%s)" -ge "$(($(date +%s) + somedays))" ]; then
                    still_valid_certs="${still_valid_certs}$line\n"
                fi
            # Non OpenBSD cases
            else
                # Already expired if expiration date is before now
                if [ "$(TZ=:Zulu date -d "$(echo "$line" | awk '{print $3,$4,$2,$5}')" +%s)" -le "$(date +%s)" ]; then
                    expired_certs="${expired_certs}$line\n"
                # Expiring soon if expiration date is after now and before now + $somedays days
                elif [ "$(TZ=:Zulu date -d "$(echo "$line" | awk '{print $3,$4,$2,$5}')" +%s)" -gt "$(date +%s)" ] && [ "$(TZ=:Zulu date -d "$(echo "$line" | awk '{print $3,$4,$2,$5}')" +%s)" -lt "$(($(date +%s) + somedays))" ]; then
                    expiring_soon_certs="${expiring_soon_certs}$line\n"
                # Still valid for a time if expiration date is after now + $somedays days
                elif [ "$(TZ=:Zulu date -d "$(echo "$line" | awk '{print $3,$4,$2,$5}')" +%s)" -ge "$(($(date +%s) + somedays))" ]; then
                    still_valid_certs="${still_valid_certs}$line\n"
                fi
            fi
        done
        
        echo "Expired client certificates:"
        echo "${expired_certs}"
        echo "Valid client certificates expiring soon (in less than $((somedays / 60 / 60 / 24)) days):"
        echo "${expiring_soon_certs}"
        echo "Valid client certificates expiring later (in more than $((somedays / 60 / 60 / 24)) days):"
        echo "${still_valid_certs}"
    }
}

main() {
    SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
    cacert_path="/etc/shellpki/cacert.pem"
    index_path="/etc/shellpki/index.txt"
    somedays="3456000" # 40 days currently
    expired_certs=""
    expiring_soon_certs=""
    still_valid_certs=""

    case "$1" in
        version|--version)
            show_version
            exit 0
        ;;

        help|--help)
            show_usage
            exit 0
        ;;

        "")
            check_carp_state
            echo "Warning : all times are in UTC !"
            echo ""
            check_ca_expiration
            echo ""
            check_certs_expiration
        ;;

        *)
            show_usage >&2
            exit 1
        ;;
    esac
}

main "$@"
