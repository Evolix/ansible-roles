#!/bin/sh

ripedeny_file=/var/tmp/ripe_deny

cd /var/tmp

rm -f $ripedeny_file

GET http://antispam00.evolix.org/spam/ripe.cidr.md5 > ripe.cidr.md5
GET http://antispam00.evolix.org/spam/ripe.cidr > ripe.cidr

for i in CN KR RU; do

    grep "^$i|" ripe.cidr >> $ripedeny_file

done

/sbin/iptables -F NEEDRESTRICT

for i in $(cat $ripedeny_file); do
    BLOCK=$(echo $i | cut -d"|" -f2)
    /sbin/iptables -I NEEDRESTRICT -s $BLOCK -j DROP
done
