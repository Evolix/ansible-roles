#!/bin/sh

umask 022

tmp_rpki_file="/var/tmp/tmp_rpki.cidr"
rpki_file="/var/tmp/rpki.cidr"

rm -f $rpki_file

YEAR_TODAY=$( date +%Y )
MONTH_TODAY=$( date +%m )
DAY_TODAY=$( date +%d )

wget -q -O- https://ftp.ripe.net/ripe/rpki/ripencc.tal/${YEAR_TODAY}/${MONTH_TODAY}/${DAY_TODAY}/roas.csv.xz | unxz | grep ^rsync > $tmp_rpki_file
wget -q -O- https://ftp.ripe.net/ripe/rpki/arin.tal/${YEAR_TODAY}/${MONTH_TODAY}/${DAY_TODAY}/roas.csv.xz | unxz | grep ^rsync >> $tmp_rpki_file
wget -q -O- https://ftp.ripe.net/ripe/rpki/afrinic.tal/${YEAR_TODAY}/${MONTH_TODAY}/${DAY_TODAY}/roas.csv.xz | unxz | grep ^rsync >> $tmp_rpki_file
wget -q -O- https://ftp.ripe.net/ripe/rpki/lacnic.tal/${YEAR_TODAY}/${MONTH_TODAY}/${DAY_TODAY}/roas.csv.xz | unxz | grep ^rsync >> $tmp_rpki_file

cat $tmp_rpki_file | cut -d, -f2,3 | sed 's/^AS//' | sort > $rpki_file

md5sum $rpki_file > /var/www/spam/rpki.cidr.md5
mv $rpki_file /var/www/spam/
