#!/bin/sh

# Only IPv4 (could be easily IPv6 too)

# use it with /sbin/iptables -I INPUT -m set --match-set apnic-blocklist-v4 src -j DROP

apnicdeny_file=/var/tmp/apnic_deny

cd /var/tmp

rm -f $apnicdeny_file

GET http://antispam00.evolix.org/spam/apnic.cidr.md5 > apnic.cidr.md5
GET http://antispam00.evolix.org/spam/apnic.cidr > apnic.cidr

md5sum --status -c apnic.cidr.md5 || exit

mv apnic.cidr $apnicdeny_file

/sbin/iptables -D NEEDRESTRICT -m set --match-set apnic-blocklist-v4 src -j DROP >/dev/null 2>&1
/sbin/ipset destroy apnic-blocklist-v4 >/dev/null 2>&1

/sbin/ipset create apnic-blocklist-v4 hash:net comment

awk -F"|" '{print "add apnic-blocklist-v4  "$2" comment "$1}' $apnicdeny_file | /sbin/ipset restore

/sbin/iptables -I NEEDRESTRICT -m set --match-set apnic-blocklist-v4 src -j DROP
