#!/bin/bash

#set -x

umask 022

tmp_file=$(mktemp)

tmp=$(mktemp -d)

if [ -f $tmp_file ] ;
  then rm $tmp_file ;
fi

sleep $[ $RANDOM / 1024 ]

# Postfix
cd $tmp

wget -q -t 3 http://antispam00.evolix.org/spam/client.access -O $tmp_file
cp $tmp_file /etc/postfix/client.access
rm $tmp_file

wget -q -t 3 http://antispam00.evolix.org/spam/sender.access -O $tmp_file
cp $tmp_file /etc/postfix/sender.access
rm $tmp_file

wget -q -t 3 http://antispam00.evolix.org/spam/recipient.access -O $tmp_file
cp $tmp_file /etc/postfix/recipient.access
rm $tmp_file

wget -q -t 3 http://antispam00.evolix.org/spam/header_kill -O $tmp_file
cp $tmp_file /etc/postfix/header_kill
rm $tmp_file

wget -q -t 3 http://antispam00.evolix.org/spam/sa-blacklist.access  -O sa-blacklist.access
wget -q -t 3 http://antispam00.evolix.org/spam/sa-blacklist.access.md5  -O $tmp_file
if md5sum -c $tmp_file > /dev/null && [ -s sa-blacklist.access ] ; then
        cp sa-blacklist.access /etc/postfix/sa-blacklist.access
fi
rm sa-blacklist.access
rm $tmp_file

/usr/sbin/postmap hash:/etc/postfix/client.access
/usr/sbin/postmap hash:/etc/postfix/sender.access
/usr/sbin/postmap hash:/etc/postfix/recipient.access
/usr/sbin/postmap -r hash:/etc/postfix/sa-blacklist.access

wget -q -t 3 http://antispam00.evolix.org/spam/spamd.cidr  -O spamd.cidr
wget -q -t 3 http://antispam00.evolix.org/spam/spamd.cidr.md5  -O $tmp_file
if md5sum -c $tmp_file > /dev/null && [ -s spamd.cidr ] ; then
        cp spamd.cidr /etc/postfix/spamd.cidr
fi
rm spamd.cidr
rm $tmp_file


# SpamAssassin
cd $tmp
wget -q -t 3 http://antispam00.evolix.org/spam/evolix_rules.cf -O evolix_rules.cf
wget -q -t 3 http://antispam00.evolix.org/spam/evolix_rules.cf.md5 -O $tmp_file
if md5sum -c $tmp_file > /dev/null && [ -s evolix_rules.cf ] ; then
        dpkg -l spamassassin 2>&1 | grep -v "no packages found matching" | grep -q ^ii && cp evolix_rules.cf /etc/spamassassin
        dpkg -l spamassassin 2>&1 | grep -v "no packages found matching" | grep -q ^ii && /etc/init.d/spamassassin reload > /dev/null
        if [ -d /etc/spamassassin/sa-update-hooks.d ]; then
                run-parts --lsbsysinit /etc/spamassassin/sa-update-hooks.d
        fi
fi

# ClamAV
cd $tmp
wget -q -t 3 http://antispam00.evolix.org/spam/evolix.ndb -O evolix.ndb
wget -q -t 3 http://antispam00.evolix.org/spam/evolix.ndb.md5 -O $tmp_file
dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && chown clamav: evolix.ndb
if md5sum -c $tmp_file > /dev/null && [ -s evolix.ndb ] ; then
        dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && cp -a evolix.ndb /var/lib/clamav/
fi
wget -q -t 3 http://antispam00.evolix.org/spam/evolix.hsb -O evolix.hsb
wget -q -t 3 http://antispam00.evolix.org/spam/evolix.hsb.md5 -O $tmp_file
dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && chown clamav: evolix.hsb
if md5sum -c $tmp_file > /dev/null && [ -s evolix.hsb ] ; then
        dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && cp -a evolix.hsb /var/lib/clamav/
fi
dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && /etc/init.d/clamav-daemon reload-database > /dev/null
rm $tmp_file

rm -rf $tmp
