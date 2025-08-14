#!/bin/sh

# Only IPv4 (could be easily IPv6 too)

# use it with /sbin/iptables -I INPUT -m set --match-set countries-blocklist-v4 src -j DROP

ripedeny_file=/var/tmp/ripe_deny

cd /var/tmp

rm -f $ripedeny_file

GET http://antispam00.evolix.org/spam/ripe.cidr.md5 > ripe.cidr.md5
GET http://antispam00.evolix.org/spam/ripe.cidr > ripe.cidr

md5sum --status -c ripe.cidr.md5 || exit

for i in CN KR RU; do
    awk -F"|" "/${i}/"'{print "add countries-blocklist-v4 "$2" comment "$1}' ripe.cidr >> $ripedeny_file
done

/sbin/iptables -D NEEDRESTRICT -m set --match-set countries-blocklist-v4 src -j DROP >/dev/null 2>&1
/sbin/ipset destroy countries-blocklist-v4 >/dev/null 2>&1

/sbin/ipset create countries-blocklist-v4 hash:net comment

/sbin/ipset restore < "$ripedeny_file"

/sbin/iptables -I NEEDRESTRICT -m set --match-set countries-blocklist-v4 src -j DROP
