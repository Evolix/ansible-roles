#!/bin/sh
IPSECCTL="/sbin/ipsecctl -s sa"
STATUS=0

LINE1=`$IPSECCTL | grep "from $1 to $2" `
if [ $? -eq 1 ]; then
        STATUS=2;
        OUTPUT1="No VPN from $1 to $2 "
fi

LINE2=`$IPSECCTL | grep "from $2 to $1" `
if [ $? -eq 1 ]; then
        STATUS=2;
        OUTPUT2="No VPN from $2 to $1"
fi

if [ $STATUS -eq 0 ]; then
        echo "VPN OK - $3 is up"
        exit $STATUS
else
        echo "VPN DOWN - $3 is down ($OUTPUT1 $OUTPUT2)"
        exit $STATUS
fi
