#!/bin/sh
if ! echo $1 | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9])?$'
then
	echo $1 does not look like an IPv4 address
	exit 1
fi
iptables -I INPUT -s $1 -j DROP
echo $1 >> /root/BLACKLIST-SSH
