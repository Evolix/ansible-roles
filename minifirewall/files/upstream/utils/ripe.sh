#!/bin/sh

umask 022

tmp_ripe_file="/var/tmp/tmp_ripe.cidr"
ripe_file="/var/tmp/ripe.cidr"

rm -f $ripe_file

wget -q -O- ftp://ftp.ripe.net/ripe/stats/delegated-ripencc-latest | egrep '^ripencc\|..\|ipv4\|.*\|.*\|(assigned|allocated)$' > $tmp_ripe_file
wget -q -O- ftp://ftp.apnic.net/pub/stats/apnic/delegated-apnic-latest | egrep '^apnic\|..\|ipv4\|.*\|.*\|(assigned|allocated)$' >> $tmp_ripe_file
wget -q -O- ftp://ftp.arin.net/pub/stats/afrinic/delegated-afrinic-latest | egrep '^afrinic\|..\|ipv4\|.*\|.*\|(assigned|allocated)$' >> $tmp_ripe_file
wget -q -O- ftp://ftp.arin.net/pub/stats/lacnic/delegated-lacnic-latest | egrep '^lacnic\|..\|ipv4\|.*\|.*\|(assigned|allocated)$' >> $tmp_ripe_file

cat $tmp_ripe_file | cut -d"|" -f2,4,5 | sed  ' s@|1073741824$@/2@ ;s@|536870912$@/3@ ;s@|268435456$@/4@ ;s@|134217728$@/5@ ;s@|67108864$@/6@ ;s@|33554432$@/7@ ;s@|16777216$@/8@ ;s@|8388608$@/9@ ;s@|4194304$@/10@ ;s@|2097152$@/11@ ;s@|1048576$@/12@ ;s@|524288$@/13@ ;s@|262144$@/14@ ;s@|131072$@/15@ ;s@|65536$@/16@ ;s@|32768$@/17@ ;s@|16384$@/18@ ;s@|8192$@/19@ ;s@|4096$@/20@ ;s@|2048$@/21@ ;s@|1024$@/22@ ;s@|512$@/23@ ;s@|256$@/24@ ;s@|128$@/25@ ;s@|64$@/26@ ;s@|32$@/27@ ;s@|16$@/28@ ;s@|8$@/29@ ;s@|4$@/30@ ' | sort > $ripe_file

md5sum $ripe_file > /var/www/spam/ripe.cidr.md5
mv $ripe_file /var/www/spam/

