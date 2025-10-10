#!/bin/sh

# Only IPv4 (could be easily IPv6 too)

# use it with /sbin/iptables -I INPUT -m set --match-set asn-blocklist-v4 src -j DROP

rpkideny_file=/var/tmp/rpki_deny

cd /var/tmp

rm -f $rpkideny_file

GET http://antispam00.evolix.org/spam/rpki.cidr.md5 > rpki.cidr.md5
GET http://antispam00.evolix.org/spam/rpki.cidr > rpki.cidr

md5sum --status -c rpki.cidr.md5 || exit

# Examples
# AS45102 > Alibaba Cloud
# AS200373 > 3xK Tech GmbH
# AS198571 > 3xK Tech GmbH
# AS4134 > CHINANET-BACKBONE
# AS4837 > CHINA UNICOM
# AS136907 > Huawei Cloud Global 
# AS55990 > Huawei Cloud Service data center
# AS63727 > Huawei
# AS9808 > China Mobile

for i in 45102 200373 198571 4134 4837 136907 55990 63727 9808; do
    grep "^$i," rpki.cidr | grep -v '::' >> $rpkideny_file
done

/sbin/iptables -D NEEDRESTRICT -m set --match-set asn-blocklist-v4 src -j DROP >/dev/null 2>&1
/sbin/ipset destroy asn-blocklist-v4 >/dev/null 2>&1

/sbin/ipset create asn-blocklist-v4 hash:net comment

awk -F, '{print "add asn-blocklist-v4 "$2" comment "$1}' $rpkideny_file | /sbin/ipset restore

/sbin/iptables -I NEEDRESTRICT -m set --match-set asn-blocklist-v4 src -j DROP
