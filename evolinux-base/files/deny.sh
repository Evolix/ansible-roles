#!/bin/sh
banfile=/root/ban.iptables
if test "$#" -lt 1
then
	printf 'usage: deny [-t] IP…\n' >&2
	exit 1
fi
if test "$1" = '-t'
then
	banfile=/dev/null
	shift
fi
for ip
do
	if ! echo "${ip}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9])?$'
	then
		printf '%s: %s does not look like an IPv4 address\n' "$0" "${ip}" >&2
		continue
	fi
	printf '/sbin/iptables -I INPUT -s %s -j DROP\n' "${ip}"
done | tee -a "${banfile}" | sh
