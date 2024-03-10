#!/bin/bash

#set -x
umask 022

tmp_dir="/tmp/spam_sh"
mkdir -p "${tmp_dir}"
data_url="http://antispam00.evolix.org/spam"
rc=0

function is_installed {
    dpkg -l "${1}" 2>&1 | grep -v "no packages found matching" | grep -q ^ii
}

function is_new {
    # Check whether a file name provided as argument has been changed remotely
    cd "${tmp_dir}"
    wget -q -t 3 "${data_url}/${1}.md5" -O "${1}.md5.new"
    if ! [ -e "${1}.md5" ] || ! cmp -s "$1.md5" "${1}.md5.new"; then
        return 0
    fi
    return 1
}

function download {
    cd "${tmp_dir}"
    wget -q -t 3 "${data_url}/${1}" -O "${1}"
    wget -q -t 3 "${data_url}/${1}.md5" -O "${1}.md5"
}

function check_integrity {
    cd "$tmp_dir"
    md5sum -c "${1}.md5" > /dev/null && [ -e "${1}" ]
}

function cleanup {
    rm -f /etc/postfix/header_kill.db
    rm -f /etc/postfix/header_kill_local.db
    rm -f "$tmp_dir"/*.md5.new
}

# Postfix
postfix_dbs="client.access sender.access recipient.access header_kill"
for db in ${postfix_dbs}; do
    if is_new "${db}"; then
        download "${db}"
        if check_integrity "${db}"; then
            cp "${tmp_dir}/${db}" /etc/postfix/
            if [ "${db}" != "header_kill" ]; then
                /usr/sbin/postmap -r "/etc/postfix/${db}"
            fi
        else
            >&2 echo "Integrity check failed for new ${db}."
            rc=1
        fi
    fi
done

# SpamAssassin
sa_db="evolix_rules.cf"
if is_installed spamassassin; then
    if is_new "${sa_db}"; then
        download "${sa_db}"
        if check_integrity "${sa_db}"; then
            cp "${tmp_dir}/${sa_db}" /etc/spamassassin/
            /etc/init.d/spamassassin reload > /dev/null
            if [ -d /etc/spamassassin/sa-update-hooks.d ]; then
                run-parts --lsbsysinit /etc/spamassassin/sa-update-hooks.d
            fi
        else
            >&2 echo "Integrity check failed for ${sa_db}."
            rc=1
        fi
    fi
fi

cleanup

exit "${rc}"

# Commenté car fichiers plus maintenus (cf. Reg)
## ClamAV
#cd $tmp
#wget -q -t 3 http://antispam00.evolix.org/spam/evolix.ndb -O evolix.ndb
#wget -q -t 3 http://antispam00.evolix.org/spam/evolix.ndb.md5 -O $tmp_file
#dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && chown clamav: evolix.ndb
#if md5sum -c $tmp_file > /dev/null && [ -s evolix.ndb ] ; then
#        dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && cp -a evolix.ndb /var/lib/clamav/
#fi
#wget -q -t 3 http://antispam00.evolix.org/spam/evolix.hsb -O evolix.hsb
#wget -q -t 3 http://antispam00.evolix.org/spam/evolix.hsb.md5 -O $tmp_file
#dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && chown clamav: evolix.hsb
#if md5sum -c $tmp_file > /dev/null && [ -s evolix.hsb ] ; then
#        dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && cp -a evolix.hsb /var/lib/clamav/
#fi
#dpkg -l clamav-daemon 2>&1 | grep -v "no packages found matching" | grep -q ^ii && /etc/init.d/clamav-daemon reload-database > /dev/null
#rm $tmp_file
#
#rm -rf $tmp
