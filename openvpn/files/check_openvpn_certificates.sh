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
        echo "CRITICAL - The check exited with an error. Is the conf_file var containing the real conf file location ? On Debian, is the check executed with sudo ?"
    fi
}

SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
date_cmd=$(command -v date)

# Dates in seconds
_15_days="1296000"
_30_days="2592000"
current_date=$($date_cmd +"%s")

# Trying to define the OpenVPN conf file location - default to /etc/openvpn/server.conf
conf_file=$(ps auwwwx | grep openvpn | grep -- --config | grep -v sed | sed -e "s/.*config \(\/etc\/openvpn.*.conf\).*/\1/" | head -1)
[ "$SYSTEM" = "openbsd" ] && conf_file=${conf_file:-$(grep openvpn_flags /etc/rc.conf.local | sed -e "s/.*config \(\/etc\/openvpn.*.conf\).*/\1/")}
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

test_cert_expiration() {
    # Already expired - Cert file
    if [ $current_date -ge $1 ]; then
        CERT_ECHO="CRITICAL - The server certificate has expired on $formatted_cert_expiration_date"
        CERT_STATE=$STATE_CRITICAL
    # Expiration in 15 days or less - Cert file
    elif [ $((current_date+_15_days)) -ge $1 ]; then
        CERT_ECHO="CRITICAL - The server certificate expires in 15 days or less : $formatted_cert_expiration_date"
        CERT_STATE=$STATE_CRITICAL
    # Expiration in 30 days or less - Cert file
    elif [ $((current_date+_30_days)) -ge $1 ]; then
        CERT_ECHO="WARNING - The server certificate expires in 30 days or less : $formatted_cert_expiration_date"
        CERT_STATE=$STATE_WARNING
    # Expiration in more than 30 days - Cert file
    else
        CERT_ECHO="OK - The server certificate expires on $formatted_cert_expiration_date"
        CERT_STATE=$STATE_OK
    fi
}

test_ca_expiration() {
    # Already expired - CA file
    if [ $current_date -ge $1 ]; then
        CA_ECHO="CRITICAL - The server CA has expired on $formatted_ca_expiration_date"
        CA_STATE=$STATE_CRITICAL
    # Expiration in 15 days or less - CA file
    elif [ $((current_date+_15_days)) -ge $1 ]; then
        CA_ECHO="CRITICAL - The server CA expires in 15 days or less : $formatted_ca_expiration_date"
        CA_STATE=$STATE_CRITICAL
    # Expiration in 30 days or less - CA file
    elif [ $((current_date+_30_days)) -ge $1 ]; then
        CA_ECHO="WARNING - The server CA expires in 30 days or less : $formatted_ca_expiration_date"
        CA_STATE=$STATE_WARNING
    # Expiration in more than 30 days - CA file
    else
        CA_ECHO="OK - The server CA expires on $formatted_ca_expiration_date"
        CA_STATE=$STATE_OK
    fi
}

# Linux and BSD systems do not implement 'date' the same way
if [ "$SYSTEM" = "linux" ]; then

    # Cert expiration date human formated then in seconds
    formatted_cert_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$cert_expiration_date" +"%F %T %Z")
    seconds_cert_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$cert_expiration_date" +"%s")

    # CA expiration date human formated then in seconds
    formatted_ca_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$ca_expiration_date" +"%F %T %Z")
    seconds_ca_expiration_date=$(TZ="Europe/Paris" $date_cmd -d "$ca_expiration_date" +"%s")

    test_cert_expiration $seconds_cert_expiration_date
    test_ca_expiration $seconds_ca_expiration_date

elif [ "$SYSTEM" = "openbsd" ]; then

    # Cert expiration date for POSIX date, human formated then in seconds
    posix_cert_expiration_date=$(echo "$cert_expiration_date" | awk '{ printf $4" "(index("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3" "$2" ",split($3,time,":"); print time[1],time[2],time[3]}' | awk '{printf "%04d%02d%02d%02d%02d.%02d\n", $1, $2, $3, $4, $5, $6}')
    cert_zone=$(echo "$cert_expiration_date" | awk '{print $5}')
    formatted_cert_expiration_date=$(TZ=$cert_zone $date_cmd -j -z "Europe/Paris" "$posix_cert_expiration_date" +"%F %T %Z")
    seconds_cert_expiration_date=$(TZ=$cert_zone $date_cmd -j -z "Europe/Paris" "$posix_cert_expiration_date" +"%s")

    # CA expiration date for POSIX date, human formated then in seconds
    posix_ca_expiration_date=$(echo "$ca_expiration_date" | awk '{ printf $4" "(index("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3" "$2" ",split($3,time,":"); print time[1],time[2],time[3]}' | awk '{printf "%04d%02d%02d%02d%02d.%02d\n", $1, $2, $3, $4, $5, $6}')
    ca_zone=$(echo "$ca_expiration_date" | awk '{print $5}')
    formatted_ca_expiration_date=$(TZ=$ca_zone $date_cmd -j -z "Europe/Paris" "$posix_ca_expiration_date" +"%F %T %Z")
    seconds_ca_expiration_date=$(TZ=$ca_zone $date_cmd -j -z "Europe/Paris" "$posix_ca_expiration_date" +"%s")

    test_cert_expiration $seconds_cert_expiration_date
    test_ca_expiration $seconds_ca_expiration_date

# If neither Linux nor BSD
else

    echo "CRITICAL - OS not supported"
    STATE=$STATE_CRITICAL
    exit $STATE

fi

# Display the first one that expires first
if [ $CA_STATE -gt $CERT_STATE  ]; then
    echo $CA_ECHO
    echo $CERT_ECHO
    exit $CA_STATE
elif [ $CERT_STATE -gt $CA_STATE ]; then
    echo $CERT_ECHO
    echo $CA_ECHO
    exit $CERT_STATE
else
    echo $CERT_ECHO
    echo $CA_ECHO
    exit $CERT_STATE
fi
