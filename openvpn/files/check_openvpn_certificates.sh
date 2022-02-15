#!/bin/sh

set -eu

trap error 0

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE=$STATE_OK
CERT_STATE=$STATE
CA_STATE=$STATE
CERT_ECHO=""
CA_ECHO=""

error() {
    if [ $? -eq 2 ] && [ "X$CERT_ECHO" = "X" ] && [ "X$CA_ECHO" = "X" ] ; then
        echo "CRITICAL - The check exited with an error. Is the conf_file var containing the real conf file location ? On Debian, is the check executed with sudo ? On OpenBSD, is the check executed with doas ? Is OpenVPN running ?"
    fi
}

SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
date_cmd=$(command -v date)

# Some backup servers don't have OpenVPN running while they are backup
is_backup_not_running_openvpn="1"
if [ "$SYSTEM" = "openbsd" ]; then
    carp=$(/sbin/ifconfig carp0 2>/dev/null | grep 'status' | cut -d' ' -f2)
    if [ "$carp" = "backup" ] && ! rcctl ls on | grep -q openvpn; then
        is_backup_not_running_openvpn="0"
    fi
fi

# Dates in seconds
_15_days="1296000"
_30_days="2592000"
current_date=$($date_cmd +"%s")

# Trying to define the OpenVPN conf file location - default to /etc/openvpn/server.conf
conf_file=$(ps auwwwx | grep openvpn | grep -- --config | grep -v sed | sed -e "s/.*config \(\/etc\/openvpn.*.conf\).*/\1/" | head -1)
if [ "$SYSTEM" = "openbsd" ]; then conf_file=${conf_file:-$(grep openvpn_flags /etc/rc.conf.local | sed -e "s/.*config \(\/etc\/openvpn.*.conf\).*/\1/")}; fi
conf_file=${conf_file:-"/etc/openvpn/server.conf"}

# Get the cert and ca file location, based on the OpenVPN conf file location
# Done in 2 times because sh does not support pipefail - needed in the case where $conf_file does not exist
cert_file=$(grep -s "^cert " $conf_file)
cert_file=$(echo $cert_file | sed -e "s/^cert *\//\//")
ca_file=$(grep -s "^ca " $conf_file)
ca_file=$(echo $ca_file | sed -e "s/^ca *\//\//")

# Get expiration date of cert and ca certificates
cert_expiration_date=$(grep "Not After" $cert_file | sed -e "s/.*Not After : //")
ca_expiration_date=$(openssl x509 -enddate -noout -in $ca_file | cut -d '=' -f 2)

# Get the date of last modification of cert and ca certificates
if [ "$SYSTEM" = "openbsd" ]; then
    seconds_last_cert_modification_date=$(stat -f %m "$cert_file")
    seconds_last_ca_modification_date=$(stat -f %m "$ca_file")
else
    seconds_last_cert_modification_date=$(stat -c %Y "$cert_file")
    seconds_last_ca_modification_date=$(stat -c %Y "$ca_file")
fi

# Get the date of last OpenVPN restart
last_openvpn_restart_date=$(ps awwwx -O lstart | grep openvpn | grep -vE "grep|check_openvpn_certificates.sh" | awk '{print $3,$4,$5,$6}')

test_cert_expiration() {
    # Already expired - Cert file
    if [ $current_date -ge $1 ]; then
        CERT_ECHO="CRITICAL - The server certificate has expired on $formated_cert_expiration_date"
        CERT_STATE=$STATE_CRITICAL
    # Expiration in 15 days or less - Cert file
    elif [ $((current_date+_15_days)) -ge $1 ]; then
        CERT_ECHO="CRITICAL - The server certificate expires in 15 days or less : $formated_cert_expiration_date"
        CERT_STATE=$STATE_CRITICAL
    # Expiration in 30 days or less - Cert file
    elif [ $((current_date+_30_days)) -ge $1 ]; then
        CERT_ECHO="WARNING - The server certificate expires in 30 days or less : $formated_cert_expiration_date"
        CERT_STATE=$STATE_WARNING
    # Expiration in more than 30 days - Cert file
    else
        CERT_ECHO="OK - The server certificate expires on $formated_cert_expiration_date"
        CERT_STATE=$STATE_OK
    fi
}

test_ca_expiration() {
    # Already expired - CA file
    if [ $current_date -ge $1 ]; then
        CA_ECHO="CRITICAL - The server CA has expired on $formated_ca_expiration_date"
        CA_STATE=$STATE_CRITICAL
    # Expiration in 15 days or less - CA file
    elif [ $((current_date+_15_days)) -ge $1 ]; then
        CA_ECHO="CRITICAL - The server CA expires in 15 days or less : $formated_ca_expiration_date"
        CA_STATE=$STATE_CRITICAL
    # Expiration in 30 days or less - CA file
    elif [ $((current_date+_30_days)) -ge $1 ]; then
        CA_ECHO="WARNING - The server CA expires in 30 days or less : $formated_ca_expiration_date"
        CA_STATE=$STATE_WARNING
    # Expiration in more than 30 days - CA file
    else
        CA_ECHO="OK - The server CA expires on $formated_ca_expiration_date"
        CA_STATE=$STATE_OK
    fi
}

test_openvpn_restarted_since_last_ca_cert_modification() {
    if [ $is_backup_not_running_openvpn -eq "0" ]; then
        RESTART_ECHO="OK - OpenVPN is not running because server is backup"
        RESTART_STATE=$STATE_OK
    else
        if [ $seconds_last_cert_modification_date -ge $1 ] || [ $seconds_last_ca_modification_date -ge $1 ]; then
            RESTART_ECHO="CRITICAL - OpenVPN hasn't been restarted since the last renewal of CA or CERT certificate"
            RESTART_STATE=$STATE_CRITICAL
        else
            RESTART_ECHO="OK - OpenVPN has been restarted since the last renewal of CA and CERT certificate"
            RESTART_STATE=$STATE_OK
        fi
    fi
}

main() {
    # Linux and BSD systems do not implement 'date' the same way
    if [ "$SYSTEM" = "linux" ]; then
    
        # Cert expiration date human formated then in seconds
        formated_cert_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$cert_expiration_date" +"%F %T %Z")
        seconds_cert_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$cert_expiration_date" +"%s")
    
        # CA expiration date human formated then in seconds
        formated_ca_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$ca_expiration_date" +"%F %T %Z")
        seconds_ca_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$ca_expiration_date" +"%s")

        # Last OpenVPN restart in seconds
        seconds_last_openvpn_restart_date=$(TZ="Europe/Paris" $date_cmd -d "$last_openvpn_restart_date" +%s)
    
        test_cert_expiration $seconds_cert_expiration_date
        test_ca_expiration $seconds_ca_expiration_date
        test_openvpn_restarted_since_last_ca_cert_modification $seconds_last_openvpn_restart_date
    
    elif [ "$SYSTEM" = "openbsd" ]; then

        # Cert expiration date for POSIX date, human formated then in seconds
        posix_cert_expiration_date=$(echo "$cert_expiration_date" | awk '{ printf $4" "(index("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3" "$2" ",split($3,time,":"); print time[1],time[2],time[3]}' | awk '{printf "%04d%02d%02d%02d%02d.%02d\n", $1, $2, $3, $4, $5, $6}')
        cert_zone=$(echo "$cert_expiration_date" | awk '{print $5}')
        formated_cert_expiration_date=$(TZ=$cert_zone $date_cmd -j -z "Europe/Paris" "$posix_cert_expiration_date" +"%F %T %Z")
        seconds_cert_expiration_date=$(TZ=$cert_zone $date_cmd -j -z "Europe/Paris" "$posix_cert_expiration_date" +"%s")
    
        # CA expiration date for POSIX date, human formated then in seconds
        posix_ca_expiration_date=$(echo "$ca_expiration_date" | awk '{ printf $4" "(index("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3" "$2" ",split($3,time,":"); print time[1],time[2],time[3]}' | awk '{printf "%04d%02d%02d%02d%02d.%02d\n", $1, $2, $3, $4, $5, $6}')
        ca_zone=$(echo "$ca_expiration_date" | awk '{print $5}')
        formated_ca_expiration_date=$(TZ=$ca_zone $date_cmd -j -z "Europe/Paris" "$posix_ca_expiration_date" +"%F %T %Z")
        seconds_ca_expiration_date=$(TZ=$ca_zone $date_cmd -j -z "Europe/Paris" "$posix_ca_expiration_date" +"%s")

        test_cert_expiration $seconds_cert_expiration_date
        test_ca_expiration $seconds_ca_expiration_date

        if [ $is_backup_not_running_openvpn -eq "0" ]; then
            test_openvpn_restarted_since_last_ca_cert_modification 0
        else
            # Last OpenVPN restart in POSIX format, then in seconds
            posix_last_openvpn_restart_date=$(echo "$last_openvpn_restart_date" | awk '{ printf $4" "(index("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3" "$2" ",split($3,time,":"); print time[1],time[2],time[3]}' | awk '{printf "%04d%02d%02d%02d%02d.%02d\n", $1, $2, $3, $4, $5, $6}')
            seconds_last_openvpn_restart_date=$($date_cmd -j "$posix_last_openvpn_restart_date" +%s)

            test_openvpn_restarted_since_last_ca_cert_modification $seconds_last_openvpn_restart_date
        fi

    # If neither Linux nor BSD
    else
    
        echo "CRITICAL - OS not supported"
        STATE=$STATE_CRITICAL
        exit $STATE
    
    fi
    
    if [ $RESTART_STATE -gt $STATE_OK ]; then
        echo $RESTART_ECHO
        echo $CERT_ECHO
        echo $CA_ECHO
        exit $RESTART_STATE
    else
        # Display the first one that expires first
        if [ $CA_STATE -gt $CERT_STATE  ]; then
            echo $CA_ECHO
            echo $CERT_ECHO
            echo $RESTART_ECHO
            exit $CA_STATE
        elif [ $CERT_STATE -gt $CA_STATE ]; then
            echo $CERT_ECHO
            echo $CA_ECHO
            echo $RESTART_ECHO
            exit $CERT_STATE
        else
            echo $CERT_ECHO
            echo $CA_ECHO
            echo $RESTART_ECHO
            exit $CERT_STATE
        fi
    fi
}

main
