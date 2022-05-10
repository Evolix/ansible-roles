#!/bin/sh

carp=$(/sbin/ifconfig carp0 2>/dev/null | grep 'status' | cut -d' ' -f2)

if [ "$carp" = "backup" ]; then
    exit 0
fi

echo "Warning : all times are in UTC !\n"

echo "CA certificate:"
openssl x509 -enddate -noout -in /etc/shellpki/cacert.pem \
    | cut -d '=' -f 2 \
    | sed -e "s/^\(.*\)\ \(20..\).*/- \2 \1/"

echo ""

echo "Client certificates:"
cat /etc/shellpki/index.txt \
    | grep ^V \
    | awk -F "/" '{print $1,$5}' \
    | awk '{print $2,$5}' \
    | sed 's/CN=//' \
    | sed -E 's/([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})Z (.*)/- 20\1 \2 \3 \4:\5:\6 \7/' \
    | awk '{if ($3 == "01") $3="Jan"; else if ($3 == "02") $3="Feb"; else if ($3 == "03") $3="Mar"; else if ($3 == "04") $3="Apr"; else if ($3 == "05") $3="May"; else if ($3 == "06") $3="Jun"; else if ($3 == "07") $3="Jul"; else if ($3 == "08") $3="Aug"; else if ($3 == "09") $3="Sep"; else if ($3 == "10") $3="Oct"; else if ($3 == "11") $3="Nov"; else if ($3 == "12") $3="Dec"; print $0;}' \
    | sort -n -k 2 -k 3M -k 4
