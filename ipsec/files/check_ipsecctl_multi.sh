#!/bin/sh

CHECK_IPSECCTL="/usr/local/libexec/nagios/check_ipsecctl.sh"
STATUS=0
VPN_KO=""

default_int=$(route -n show|grep default|awk '{ print $8 }')
default_ip=$(ifconfig $default_int|grep inet|awk '{ print $2 }')

for vpn in $(ls /etc/ipsec/); do
        vpn=$(basename $vpn .conf)
        local_ip=$(grep -E "local_ip" /etc/ipsec/${vpn}.conf|grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
        ifconfig|grep -q $local_ip
        [ $? -ne 0 ] && local_ip=$default_ip
        remote_ip=$(grep -E "remote_ip" /etc/ipsec/${vpn}.conf|grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
        $CHECK_IPSECCTL $local_ip $remote_ip "$vpn" > /dev/null
        if [ $? -ne 0 ]; then
            STATUS=2
            VPN_KO="$VPN_KO $vpn"
        fi
done

if [ $STATUS -eq 0 ]; then
    echo "ALL VPN(s) UP(s)"
    exit 0
else
    echo "VPN(s) down(s) :$VPN_KO"
    exit 2
fi
