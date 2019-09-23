#!/bin/bash

# EvoCheck
# Script to verify compliance of a Debian/OpenBSD server
# powered by Evolix

# base functions

show_version() {
    cat <<END
evocheck version ${VERSION}

Copyright 2009-2019 Evolix <info@evolix.fr>,
                    Romain Dessort <rdessort@evolix.fr>,
                    Benoit Série <bserie@evolix.fr>,
                    Gregory Colpart <reg@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Tristan Pilat <tpilat@evolix.fr>,
                    Victor Laborie <vlaborie@evolix.fr>
                    and others.

evocheck comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
END
}
show_help() {
    cat <<END
evocheck is a script that verifies Evolix conventions on Debian/OpenBSD servers.

Usage: evocheck
  or   evocheck --cron
  or   evocheck --quiet
  or   evocheck --verbose

Options
     --cron                  disable a few checks
 -v, --verbose               increase verbosity of checks
 -q, --quiet                 nothing is printed on stdout nor stderr
 -h, --help                  print this message and exit
     --version               print version and exit
END
}

detect_os() {
    # OS detection
    DEBIAN_RELEASE=""
    LSB_RELEASE_BIN=$(command -v lsb_release)
    OPENBSD_RELEASE=""

    if [ -e /etc/debian_version ]; then
        DEBIAN_VERSION=$(cut -d "." -f 1 < /etc/debian_version)
        if [ -x "${LSB_RELEASE_BIN}" ]; then
            DEBIAN_RELEASE=$(${LSB_RELEASE_BIN} --codename --short)
        else
            case ${DEBIAN_VERSION} in
                5) DEBIAN_RELEASE="lenny";;
                6) DEBIAN_RELEASE="squeeze";;
                7) DEBIAN_RELEASE="wheezy";;
                8) DEBIAN_RELEASE="jessie";;
                9) DEBIAN_RELEASE="stretch";;
                10) DEBIAN_RELEASE="buster";;
            esac
        fi
    elif [ "$(uname -s)" = "OpenBSD" ]; then
        # use a better release name
        OPENBSD_RELEASE=$(uname -r)
    fi
}

is_debian() {
  test -n "${DEBIAN_RELEASE}"
}
is_debian_lenny() {
    test "${DEBIAN_RELEASE}" = "lenny"
}
is_debian_squeeze() {
    test "${DEBIAN_RELEASE}" = "squeeze"
}
is_debian_wheezy() {
    test "${DEBIAN_RELEASE}" = "wheezy"
}
is_debian_jessie() {
    test "${DEBIAN_RELEASE}" = "jessie"
}
is_debian_stretch() {
    test "${DEBIAN_RELEASE}" = "stretch"
}
is_debian_buster() {
    test "${DEBIAN_RELEASE}" = "buster"
}
debian_release() {
    printf "%s" "${DEBIAN_RELEASE}"
}
debian_version() {
    printf "%s" "${DEBIAN_VERSION}"
}
is_openbsd() {
  test -n "${OPENBSD_RELEASE}"
}

is_pack_web(){
    test -e /usr/share/scripts/web-add.sh || test -e /usr/share/scripts/evoadmin/web-add.sh
}
is_pack_samba(){
    test -e /usr/share/scripts/add.pl
}
is_installed(){
    for pkg in "$@"; do
        dpkg -l "$pkg" 2> /dev/null | grep -q -E '^(i|h)i' || return 1
    done
}
minifirewall_file() {
    case ${DEBIAN_RELEASE} in
        lenny) echo "/etc/firewall.rc" ;;
        squeeze) echo "/etc/firewall.rc" ;;
        wheezy) echo "/etc/firewall.rc" ;;
        jessie) echo "/etc/default/minifirewall" ;;
        stretch) echo "/etc/default/minifirewall" ;;
        *) echo "/etc/default/minifirewall" ;;
    esac
}

# logging

failed() {
    check_name=$1
    shift
    check_comments=$*

    RC=1
    if [ "${QUIET}" != 1 ]; then
        if [ -n "${check_comments}" ] && [ "${VERBOSE}" = 1 ]; then
            printf "%s FAILED! %s\n" "${check_name}" "${check_comments}" 2>&1
        else
            printf "%s FAILED!\n" "${check_name}" 2>&1
        fi
    fi
}

# check functions

check_lsbrelease(){
    if [ -x "${LSB_RELEASE_BIN}" ]; then
        ## only the major version matters
        lhs=$(${LSB_RELEASE_BIN} --release --short | cut -d "." -f 1)
        rhs=$(cut -d "." -f 1 < /etc/debian_version)
        test "$lhs" = "$rhs" || failed "IS_LSBRELEASE" "release is not consistent between lsb_release and /etc/debian_version"
    else
        failed "IS_LSBRELEASE" "lsb_release is missing or not executable"
    fi
}
check_dpkgwarning() {
    if is_debian_squeeze; then
        if [ "$IS_USRRO" = 1 ] || [ "$IS_TMPNOEXEC" = 1 ]; then
            count=$(grep -c -E -i "(Pre-Invoke ..echo Are you sure to have rw on|Post-Invoke ..echo Dont forget to mount -o remount)" /etc/apt/apt.conf)
            test "$count" = 2 || failed "IS_DPKGWARNING" "Pre/Post-Invoke are missing."
        fi
    elif is_debian_wheezy; then
        if [ "$IS_USRRO" = 1 ] || [ "$IS_TMPNOEXEC" = 1 ]; then
            test -e /etc/apt/apt.conf.d/80evolinux \
                || failed "IS_DPKGWARNING" "/etc/apt/apt.conf.d/80evolinux is missing"
            test -e /etc/apt/apt.conf \
                && failed "IS_DPKGWARNING" "/etc/apt/apt.conf is missing"
        fi
    elif is_debian_stretch || is_debian_buster; then
        test -e /etc/apt/apt.conf.d/z-evolinux.conf \
            || failed "IS_DPKGWARNING" "/etc/apt/apt.conf.d/z-evolinux.conf is missing"
    fi
}
check_umasksudoers(){
    if is_debian_squeeze; then
        grep -q "^Defaults.*umask=0077" /etc/sudoers \
            || failed "IS_UMASKSUDOERS" "sudoers must set umask to 0077"
    fi
}
# Verifying check_mailq in Nagios NRPE config file. (Option "-M postfix" need to be set if the MTA is Postfix)
check_nrpepostfix() {
    if is_installed postfix; then
        if is_debian_squeeze; then
            grep -q "^command.*check_mailq -M postfix" /etc/nagios/nrpe.cfg \
                || failed "IS_NRPEPOSTFIX" "NRPE \"check_mailq\" for postfix is missing"
        else
            { test -e /etc/nagios/nrpe.cfg \
                && grep -qr "^command.*check_mailq -M postfix" /etc/nagios/nrpe.*;
            } || failed "IS_NRPEPOSTFIX" "NRPE \"check_mailq\" for postfix is missing"
        fi
    fi
}
# Check if mod-security config file is present
check_modsecurity() {
    if is_debian_squeeze; then
        if is_installed libapache-mod-security; then
            test -e /etc/apache2/conf.d/mod-security2.conf || failed "IS_MODSECURITY" "missing configuration file"
        fi
    elif is_debian_wheezy; then
        if is_installed libapache2-modsecurity; then
            test -e /etc/apache2/conf.d/mod-security2.conf || failed "IS_MODSECURITY" "missing configuration file"
        fi
    fi
}
check_customsudoers() {
    grep -E -qr "umask=0077" /etc/sudoers* || failed "IS_CUSTOMSUDOERS" "missing umask=0077 in sudoers file"
}
check_vartmpfs() {
    df /var/tmp | grep -q tmpfs || failed "IS_VARTMPFS" "/var/tmp is not a tmpfs"
}
check_vartmpfs() {
    df /var/tmp | grep -q tmpfs || failed "IS_VARTMPFS" "/var/tmp is not a tmpfs"
}
check_serveurbase() {
    is_installed serveur-base || failed "IS_SERVEURBASE" "serveur-base package is not installed"
}
check_logrotateconf() {
    test -e /etc/logrotate.d/zsyslog || failed "IS_LOGROTATECONF" "missing zsyslog in logrotate.d"
}
check_syslogconf() {
    grep -q "^# Syslog for Pack Evolix serveur" /etc/*syslog.conf \
        || failed "IS_SYSLOGCONF" "syslog evolix config file missing"
}
check_debiansecurity() {
    grep -q "^deb.*security" /etc/apt/sources.list \
        || failed "IS_DEBIANSECURITY" "missing debian security repository"
}
check_aptitudeonly() {
    if is_debian_squeeze || is_debian_wheezy; then
        test -e /usr/bin/apt-get && failed "IS_APTITUDEONLY" \
            "only aptitude may be enabled on Debian <=7, apt-get should be disabled"
    fi
}
check_aptitude() {
    if is_debian_jessie || is_debian_stretch || is_debian_buster; then
        test -e /usr/bin/aptitude && failed "IS_APTITUDE" "aptitude may not be installed on Debian >=8"
    fi
}
check_aptgetbak() {
    if is_debian_jessie || is_debian_stretch || is_debian_buster; then
        test -e /usr/bin/apt-get.bak && failed "IS_APTGETBAK" "missing dpkg-divert apt-get.bak"
    fi
}
check_apticron() {
    status="OK"
    test -e /etc/cron.d/apticron || status="fail"
    test -e /etc/cron.daily/apticron && status="fail"
    test "$status" = "fail" || test -e /usr/bin/apt-get.bak || status="fail"

    if is_debian_squeeze || is_debian_wheezy; then
        test "$status" = "fail" && failed "IS_APTICRON" "apticron must be in cron.d not cron.daily"
    fi
}
check_usrro() {
    grep /usr /etc/fstab | grep -q ro || failed "IS_USRRO" "missing ro directive on fstab for /usr"
}
check_tmpnoexec() {
    mount | grep "on /tmp" | grep -q noexec || failed "IS_TMPNOEXEC" "/tmp is mounted with exec, should be noexec"
}
check_mountfstab() {
    # Test if lsblk available, if not skip this test...
    LSBLK_BIN=$(command -v lsblk)
    if test -x "${LSBLK_BIN}"; then
        for mountPoint in $(${LSBLK_BIN} -o MOUNTPOINT -l -n | grep '/'); do
            grep -Eq "$mountPoint\W" /etc/fstab \
                || failed "IS_MOUNT_FSTAB" "partition(s) detected mounted but no presence in fstab"
        done
    fi
}
check_listchangesconf() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed apt-listchanges; then
            failed "IS_LISTCHANGESCONF" "apt-listchanges must not be installed on Debian >=9"
        fi
    else
        if [ -e "/etc/apt/listchanges.conf" ]; then
            lines=$(grep -cE "(which=both|confirm=1)" /etc/apt/listchanges.conf)
            if [ "$lines" != 2 ]; then
                failed "IS_LISTCHANGESCONF" "apt-listchanges config is incorrect"
            fi
        else
            failed "IS_LISTCHANGESCONF" "apt-listchanges config is missing"
        fi
    fi
}
check_customcrontab() {
    found_lines=$(grep -c -E "^(17 \*|25 6|47 6|52 6)" /etc/crontab)
    test "$found_lines" = 4 && failed "IS_CUSTOMCRONTAB" "missing custom field in crontab"
}
check_sshallowusers() {
    grep -E -qi "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config \
        || failed "IS_SSHALLOWUSERS" "missing AllowUsers or AllowGroups directive in sshd_config"
}
check_diskperf() {
    perfFile="/root/disk-perf.txt"
    test -e $perfFile || failed "IS_DISKPERF" "missing ${perfFile}"
}
check_tmoutprofile() {
    grep -sq "TMOUT=" /etc/profile /etc/profile.d/evolinux.sh || failed "IS_TMOUTPROFILE" "TMOUT is not set"
}
check_alert5boot() {
    if is_debian_buster; then
        grep -qs "^date" /usr/share/scripts/alert5.sh || failed "IS_ALERT5BOOT" "boot mail is not sent by alert5 init script"
        test -f /etc/systemd/system/alert5.service || failed "IS_ALERT5BOOT" "alert5 unit file is missing"
        systemctl is-enabled alert5 -q || failed "IS_ALERT5BOOT" "alert5 unit is not enabled"
    else
        if [ -n "$(find /etc/rc2.d/ -name 'S*alert5')" ]; then
            grep -q "^date" /etc/rc2.d/S*alert5 || failed "IS_ALERT5BOOT" "boot mail is not sent by alert5 init script"
        else
            failed "IS_ALERT5BOOT" "alert5 init script is missing"
        fi
    fi
}
check_alert5minifw() {
    if is_debian_buster; then
        grep -qs "^/etc/init.d/minifirewall" /usr/share/scripts/alert5.sh \
            || failed "IS_ALERT5MINIFW" "Minifirewall is not started by alert5 script or script is missing"
    else
        if [ -n "$(find /etc/rc2.d/ -name 'S*alert5')" ]; then
            grep -q "^/etc/init.d/minifirewall" /etc/rc2.d/S*alert5 \
                || failed "IS_ALERT5MINIFW" "Minifirewall is not started by alert5 init script"
        else
            failed "IS_ALERT5MINIFW" "alert5 init script is missing"
        fi
    fi
}
check_minifw() {
    /sbin/iptables -L -n | grep -q -E "^ACCEPT\s*all\s*--\s*31\.170\.8\.4\s*0\.0\.0\.0/0\s*$" \
        || failed "IS_MINIFW" "minifirewall seems not starded"
}
check_nrpeperms() {
    if [ -d /etc/nagios ]; then
        nagiosDir="/etc/nagios"
        actual=$(stat --format "%a" $nagiosDir)
        expected="750"
        test "$expected" = "$actual" || failed "IS_NRPEPERMS" "${nagiosDir} must be ${expected}"
    fi
}
check_minifwperms() {
    if [ -f "$MINIFW_FILE" ]; then
        actual=$(stat --format "%a" "$MINIFW_FILE")
        expected="600"
        test "$expected" = "$actual" || failed "IS_MINIFWPERMS" "${MINIFW_FILE} must be ${expected}"
    fi
}
check_nrpedisks() {
    NRPEDISKS=$(grep command.check_disk /etc/nagios/nrpe.cfg | grep "^command.check_disk[0-9]" | sed -e "s/^command.check_disk\([0-9]\+\).*/\1/" | sort -n | tail -1)
    DFDISKS=$(df -Pl | grep -c -E -v "(^Filesystem|/lib/init/rw|/dev/shm|udev|rpc_pipefs)")
    test "$NRPEDISKS" = "$DFDISKS" || failed "IS_NRPEDISKS" "there must be $DFDISKS check_disk in nrpe.cfg"
}
check_nrpepid() {
    if ! is_debian_squeeze; then
        { test -e /etc/nagios/nrpe.cfg \
            && grep -q "^pid_file=/var/run/nagios/nrpe.pid" /etc/nagios/nrpe.cfg;
        } || failed "IS_NRPEPID" "missing or wrong pid_file directive in nrpe.cfg"
    fi
}
check_grsecprocs() {
    if uname -a | grep -q grsec; then
        { grep -q "^command.check_total_procs..sudo" /etc/nagios/nrpe.cfg \
            && grep -A1 "^\[processes\]" /etc/munin/plugin-conf.d/munin-node | grep -q "^user root";
        } || failed "IS_GRSECPROCS" "missing munin's plugin processes directive for grsec"
    fi
}
check_apachemunin() {
    if test -e /etc/apache2/apache2.conf; then
        if is_debian_stretch || is_debian_buster; then
            { test -h /etc/apache2/mods-enabled/status.load \
                && test -h /etc/munin/plugins/apache_accesses \
                && test -h /etc/munin/plugins/apache_processes \
                && test -h /etc/munin/plugins/apache_volume;
            } || failed "IS_APACHEMUNIN" "missing munin plugins for Apache"
        else
            pattern="/server-status-[[:alnum:]]{4,}"
            { grep -r -q -s -E "^env.url.*${pattern}" /etc/munin/plugin-conf.d \
                && { grep -q -s -E "${pattern}" /etc/apache2/apache2.conf \
                    || grep -q -s -E "${pattern}" /etc/apache2/mods-enabled/status.conf;
                };
            } || failed "IS_APACHEMUNIN" "server status is not properly configured"
        fi
    fi
}
# Verification mytop + Munin si MySQL
check_mysqlutils() {
    MYSQL_ADMIN=${MYSQL_ADMIN:-mysqladmin}
    if is_installed mysql-server; then
        # You can configure MYSQL_ADMIN in evocheck.cf
        if ! grep -qs "$MYSQL_ADMIN" /root/.my.cnf; then
            failed "IS_MYSQLUTILS" "mysqladmin missing in /root/.my.cnf"
        fi
        if ! test -x /usr/bin/mytop; then
            if ! test -x /usr/local/bin/mytop; then
                failed "IS_MYSQLUTILS" "mytop binary missing"
            fi
        fi
        if ! grep -qs debian-sys-maint /root/.mytop; then
            failed "IS_MYSQLUTILS" "debian-sys-maint missing in /root/.mytop"
        fi
    fi
}
# Verification de la configuration du raid soft (mdadm)
check_raidsoft() {
    if test -e /proc/mdstat && grep -q md /proc/mdstat; then
        { grep -q "^AUTOCHECK=true" /etc/default/mdadm \
            && grep -q "^START_DAEMON=true" /etc/default/mdadm \
            && grep -qv "^MAILADDR ___MAIL___" /etc/mdadm/mdadm.conf;
        } || failed "IS_RAIDSOFT" "missing or wrong config for mdadm"
    fi
}
# Verification du LogFormat de AWStats
check_awstatslogformat() {
    if is_installed apache2 awstats; then
        awstatsFile="/etc/awstats/awstats.conf.local"
        grep -qE '^LogFormat=1' $awstatsFile \
            || failed "IS_AWSTATSLOGFORMAT" "missing or wrong LogFormat directive in $awstatsFile"
    fi
}
# Verification de la présence de la config logrotate pour Munin
check_muninlogrotate() {
    { test -e /etc/logrotate.d/munin-node \
        && test -e /etc/logrotate.d/munin;
    } || failed "IS_MUNINLOGROTATE" "missing lorotate file for munin"
}
# Verification de l'activation de Squid dans le cas d'un pack mail
check_squid() {
    if is_debian_stretch || is_debian_buster; then
        squidconffile="/etc/squid/evolinux-custom.conf"
    else
        squidconffile="/etc/squid*/squid.conf"
    fi
    if is_pack_web && (is_installed squid || is_installed squid3); then
        host=$(hostname -i)
        # shellcheck disable=SC2086
        http_port=$(grep -E "^http_port\s+[0-9]+" $squidconffile | awk '{ print $2 }')
        { grep -qE "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT" "$MINIFW_FILE" \
            && grep -qE "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -d $host -j ACCEPT" "$MINIFW_FILE" \
            && grep -qE "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -d 127.0.0.(1|0/8) -j ACCEPT" "$MINIFW_FILE" \
            && grep -qE "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port.* $http_port" "$MINIFW_FILE";
        } || failed "IS_SQUID" "missing squid rules in minifirewall"
    fi
}
check_evomaintenance_fw() {
    if [ -f "$MINIFW_FILE" ]; then
        rulesNumber=$(grep -c "/sbin/iptables -A INPUT -p tcp --sport 5432 --dport 1024:65535 -s .* -m state --state ESTABLISHED,RELATED -j ACCEPT" "$MINIFW_FILE")
        if [ "$rulesNumber" -lt 2 ]; then
            failed "IS_EVOMAINTENANCE_FW" "missing evomaintenance rules in minifirewall"
        fi
    fi
}
# Verification de la conf et de l'activation de mod-deflate
check_moddeflate() {
    f=/etc/apache2/mods-enabled/deflate.conf
    if is_installed apache2.2; then
        { test -e $f && grep -q "AddOutputFilterByType DEFLATE text/html text/plain text/xml" $f \
            && grep -q "AddOutputFilterByType DEFLATE text/css" $f \
            && grep -q "AddOutputFilterByType DEFLATE application/x-javascript application/javascript" $f;
        } || failed "IS_MODDEFLATE" "missing AddOutputFilterByType directive for apache mod deflate"
    fi
}
# Verification de la conf log2mail
check_log2mailrunning() {
    if is_pack_web && is_installed log2mail; then
        pgrep log2mail >/dev/null || failed "IS_LOG2MAILRUNNING" "log2mail is not running"
    fi
}
check_log2mailapache() {
    if is_debian_stretch || is_debian_buster; then
        conf=/etc/log2mail/config/apache
    else
        conf=/etc/log2mail/config/default
    fi
    if is_pack_web && is_installed log2mail; then
        grep -s -q "^file = /var/log/apache2/error.log" $conf \
            || failed "IS_LOG2MAILAPACHE" "missing log2mail directive for apache"
    fi
}
check_log2mailmysql() {
    if is_pack_web && is_installed log2mail; then
        grep -s -q "^file = /var/log/syslog" /etc/log2mail/config/{default,mysql,mysql.conf} \
            || failed "IS_LOG2MAILMYSQL" "missing log2mail directive for mysql"
    fi
}
check_log2mailsquid() {
    if is_pack_web && is_installed log2mail; then
        grep -s -q "^file = /var/log/squid.*/access.log" /etc/log2mail/config/* \
            || failed "IS_LOG2MAILSQUID" "missing log2mail directive for squid"
    fi
}
# Verification si bind est chroote
check_bindchroot() {
    if is_installed bind9; then
        if netstat -utpln | grep "/named" | grep :53 | grep -qvE "(127.0.0.1|::1)"; then
            if grep -q '^OPTIONS=".*-t' /etc/default/bind9 && grep -q '^OPTIONS=".*-u' /etc/default/bind9; then
                md5_original=$(md5sum /usr/sbin/named | cut -f 1 -d ' ')
                md5_chrooted=$(md5sum /var/chroot-bind/usr/sbin/named | cut -f 1 -d ' ')
                if [ "$md5_original" != "$md5_chrooted" ]; then
                    failed "IS_BINDCHROOT" "the chrooted bind binary is different than the original binary"
                fi
            else
                failed "IS_BINDCHROOT" "bind process is not chrooted"
            fi
        fi
    fi
}
# Verification de la présence du depot volatile
check_repvolatile() {
    if is_debian_lenny; then
        grep -qE "^deb http://volatile.debian.org/debian-volatile" /etc/apt/sources.list \
            || failed "IS_REPVOLATILE" "missing debian-volatile repository"
    fi
    if is_debian_squeeze; then
        grep -qE "^deb.*squeeze-updates" /etc/apt/sources.list \
            || failed "IS_REPVOLATILE" "missing squeeze-updates repository"
    fi
}
# /etc/network/interfaces should be present, we don't manage systemd-network yet
check_network_interfaces() {
    if ! test -f /etc/network/interfaces; then
        IS_AUTOIF=0
        IS_INTERFACESGW=0
        failed "IS_NETWORK_INTERFACES" "systemd network configuration is not supported yet"
    fi
}
# Verify if all if are in auto
check_autoif() {
    if is_debian_stretch || is_debian_buster; then
        interfaces=$(/sbin/ip address show up | grep "^[0-9]*:" | grep -E -v "(lo|vnet|docker|veth|tun|tap|macvtap)" | cut -d " " -f 2 | tr -d : | cut -d@ -f1 | tr "\n" " ")
    else
        interfaces=$(/sbin/ifconfig -s | tail -n +2 | grep -E -v "^(lo|vnet|docker|veth|tun|tap|macvtap)" | cut -d " " -f 1 |tr "\n" " ")
    fi
    for interface in $interfaces; do
        if ! grep -q "^auto $interface" /etc/network/interfaces; then
            failed "IS_AUTOIF" "Network interface \`${interface}' is not set to auto"
            test "${VERBOSE}" = 1 || break
        fi
    done
}
# Network conf verification
check_interfacesgw() {
    number=$(grep -Ec "^[^#]*gateway [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" /etc/network/interfaces)
    test "$number" -gt 1 && failed "IS_INTERFACESGW" "there is more than 1 IPv4 gateway"
    number=$(grep -Ec "^[^#]*gateway [0-9a-fA-F]+:" /etc/network/interfaces)
    test "$number" -gt 1 && failed "IS_INTERFACESGW" "there is more than 1 IPv6 gateway"
}
# Verification de la mise en place d'evobackup
check_evobackup() {
    evobackup_found=$(find /etc/cron* -name '*evobackup*' | wc -l)
    test "$evobackup_found" -gt 0 || failed "IS_EVOBACKUP" "missing evobackup cron"
}
# Verification de la presence du userlogrotate
check_userlogrotate() {
    if is_pack_web; then
        test -x /etc/cron.weekly/userlogrotate || failed "IS_USERLOGROTATE" "missing userlogrotate cron"
    fi
}
# Verification de la syntaxe de la conf d'Apache
check_apachectl() {
    if is_installed apache2; then
        /usr/sbin/apache2ctl configtest 2>&1 | grep -q "^Syntax OK$" \
            || failed "IS_APACHECTL" "apache errors detected, run a configtest"
    fi
}
# Check if there is regular files in Apache sites-enabled.
check_apachesymlink() {
    if is_installed apache2; then
        apacheFind=$(find /etc/apache2/sites-enabled ! -type l -type f -print)
        nbApacheFind=$(wc -m <<< "$apacheFind")
        if [[ $nbApacheFind -gt 1 ]]; then
            if [[ $VERBOSE == 1 ]]; then
                while read -r line; do
                    failed "IS_APACHESYMLINK" "Not a symlink: $line"
                done <<< "$apacheFind"
            else
                failed "IS_APACHESYMLINK"
            fi
        fi
    fi
}
# Check if there is real IP addresses in Allow/Deny directives (no trailing space, inline comments or so).
check_apacheipinallow() {
    # Note: Replace "exit 1" by "print" in Perl code to debug it.
    if is_installed apache2; then
        grep -IrE "^[^#] *(Allow|Deny) from" /etc/apache2/ \
            | grep -iv "from all" \
            | grep -iv "env=" \
            | perl -ne 'exit 1 unless (/from( [\da-f:.\/]+)+$/i)' \
            || failed "IS_APACHEIPINALLOW" "bad (Allow|Deny) directives in apache"
    fi
}
# Check if default Apache configuration file for munin is absent (or empty or commented).
check_muninapacheconf() {
    if is_debian_squeeze || is_debian_wheezy; then
        muninconf="/etc/apache2/conf.d/munin"
    else
        muninconf="/etc/apache2/conf-available/munin.conf"
    fi
    if is_installed apache2; then
        test -e $muninconf && grep -vEq "^( |\t)*#" "$muninconf" \
            && failed "IS_MUNINAPACHECONF" "default munin configuration may be commented or disabled"
    fi
}
# Verification de la priorité du package samba si les backports sont utilisés
check_sambainpriority() {
    if is_debian_lenny && is_pack_samba; then
        if grep -qrE "^[^#].*backport" /etc/apt/sources.list{,.d}; then
            priority=$(grep -E -A2 "^Package:.*samba" /etc/apt/preferences | grep -A1 "^Pin: release a=lenny-backports" | grep "^Pin-Priority:" | cut -f2 -d" ")
            test "$priority" -gt 500 || failed "IS_SAMBAPINPRIORITY" "bad pinning priority for samba"
        fi
    fi
}
# Verification si le système doit redémarrer suite màj kernel.
check_kerneluptodate() {
    if is_installed linux-image*; then
        # shellcheck disable=SC2012
        kernel_installed_at=$(date -d "$(ls --full-time -lcrt /boot | tail -n1 | awk '{print $6}')" +%s)
        last_reboot_at=$(($(date +%s) - $(cut -f1 -d '.' /proc/uptime)))
        if [ "$kernel_installed_at" -gt "$last_reboot_at" ]; then
            failed "IS_KERNELUPTODATE" "machine is running an outdated kernel, reboot advised"
        fi
    fi
}
# Check if the server is running for more than a year.
check_uptime() {
    if is_installed linux-image*; then
        limit=$(date -d "now - 2 year" +%s)
        last_reboot_at=$(($(date +%s) - $(cut -f1 -d '.' /proc/uptime)))
        if [ "$limit" -gt "$last_reboot_at" ]; then
            failed "IS_UPTIME" "machine has an uptime of more thant 2 years, reboot on new kernel advised"
        fi
    fi
}
# Check if munin-node running and RRD files are up to date.
check_muninrunning() {
    if ! pgrep munin-node >/dev/null; then
        failed "IS_MUNINRUNNING" "Munin is not running"
    elif [ -d "/var/lib/munin/" ] && [ -d "/var/cache/munin/" ]; then
        limit=$(date +"%s" -d "now - 10 minutes")

        if [ -n "$(find /var/lib/munin/ -name '*load-g.rrd')" ]; then
            updated_at=$(stat -c "%Y" /var/lib/munin/*/*load-g.rrd |sort |tail -1)
            [ "$limit" -gt "$updated_at" ] && failed "IS_MUNINRUNNING" "Munin load RRD has not been updated in the last 10 minutes"
        else
            failed "IS_MUNINRUNNING" "Munin is not installed properly (load RRD not found)"
        fi

        if [ -n "$(find  /var/cache/munin/www/ -name 'load-day.png')" ]; then
            updated_at=$(stat -c "%Y" /var/cache/munin/www/*/*/load-day.png |sort |tail -1)
            grep -sq "^graph_strategy cron" /etc/munin/munin.conf && [ "$limit" -gt "$updated_at" ] && failed "IS_MUNINRUNNING" "Munin load PNG has not been updated in the last 10 minutes"
        else
            failed "IS_MUNINRUNNING" "Munin is not installed properly (load PNG not found)"
        fi
    else
        failed "IS_MUNINRUNNING" "Munin is not installed properly (main directories are missing)"
    fi
}
# Check if files in /home/backup/ are up-to-date
check_backupuptodate() {
    if [ -d /home/backup/ ]; then
        if [ -n "$(ls -A /home/backup/)" ]; then
            for file in /home/backup/*; do
                limit=$(date +"%s" -d "now - 2 day")
                updated_at=$(stat -c "%Y" "$file")

                if [ -f "$file" ] && [ "$limit" -gt "$updated_at" ]; then
                    failed "IS_BACKUPUPTODATE" "$file has not been backed up"
                    test "${VERBOSE}" = 1 || break;
                fi
            done
        else
            failed "IS_BACKUPUPTODATE" "/home/backup/ is empty"
        fi
    else
        failed "IS_BACKUPUPTODATE" "/home/backup/ is missing"
    fi
}
check_etcgit() {
    export GIT_DIR="/etc/.git" GIT_WORK_TREE="/etc"
    git rev-parse --is-inside-work-tree > /dev/null 2>&1 \
        || failed "IS_ETCGIT" "/etc is not a git repository"
}
# Check if /etc/.git/ has read/write permissions for root only.
check_gitperms() {
    GIT_DIR="/etc/.git"
    if test -d $GIT_DIR; then
        expected="700"
        actual=$(stat -c "%a" $GIT_DIR)
        [ "$expected" = "$actual" ] || failed "IS_GITPERMS" "$GIT_DIR must be $expected"
    fi
}
# Check if no package has been upgraded since $limit.
check_notupgraded() {
    last_upgrade=0
    upgraded=false
    for log in /var/log/dpkg.log*; do
        if zgrep -qsm1 upgrade "$log"; then
            # There is at least one upgrade
            upgraded=true
            break
        fi
    done
    if $upgraded; then
        last_upgrade=$(date +%s -d "$(zgrep -h upgrade /var/log/dpkg.log* | sort -n | tail -1 | cut -f1 -d ' ')")
    fi
    if grep -qs '^mailto="listupgrade-todo@' /etc/evolinux/listupgrade.cnf \
        || grep -qs -E '^[[:digit:]]+[[:space:]]+[[:digit:]]+[[:space:]]+[^\*]' /etc/cron.d/listupgrade; then
        # Manual upgrade process
        limit=$(date +%s -d "now - 180 days")
    else
        # Regular process
        limit=$(date +%s -d "now - 90 days")
    fi
    install_date=0
    if [ -d /var/log/installer ]; then
        install_date=$(stat -c %Z /var/log/installer)
    fi
    # Check install_date if the system never received an upgrade
    if [ "$last_upgrade" -eq 0 ]; then
        [ "$install_date" -lt "$limit" ] && failed "IS_NOTUPGRADED" "The system has never been updated"
    else
        [ "$last_upgrade" -lt "$limit" ] && failed "IS_NOTUPGRADED" "The system hasn't been updated for too long"
    fi
}
# Check if reserved blocks for root is at least 5% on every mounted partitions.
check_tune2fs_m5() {
    min=5
    parts=$(grep -E "ext(3|4)" /proc/mounts | cut -d ' ' -f1 | tr -s '\n' ' ')
    for part in $parts; do
        blockCount=$(dumpe2fs -h "$part" 2>/dev/null | grep -e "Block count:" | grep -Eo "[0-9]+")
        # If buggy partition, skip it.
        if [ -z "$blockCount" ]; then
            continue
        fi
        reservedBlockCount=$(dumpe2fs -h "$part" 2>/dev/null | grep -e "Reserved block count:" | grep -Eo "[0-9]+")
        # Use awk to have a rounded percentage
        # python is slow, bash is unable and bc rounds weirdly
        percentage=$(awk "BEGIN { pc=100*${reservedBlockCount}/${blockCount}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

        if [ "$percentage" -lt "${min}" ]; then
            failed "IS_TUNE2FS_M5" "Partition ${part} has less than ${min}% reserved blocks (${percentage}%)"
        fi
    done
}
check_evolinuxsudogroup() {
    if is_debian_stretch || is_debian_buster; then
        if grep -q "^evolinux-sudo:" /etc/group; then
            grep -q '^%evolinux-sudo  ALL=(ALL:ALL) ALL' /etc/sudoers.d/evolinux \
                || failed "IS_EVOLINUXSUDOGROUP" "missing evolinux-sudo directive in sudoers file"
        fi
    fi
}
check_userinadmgroup() {
    if is_debian_stretch || is_debian_buster; then
        users=$(grep "^evolinux-sudo:" /etc/group | awk -F: '{print $4}' | tr ',' ' ')
        for user in $users; do
            if ! groups "$user" | grep -q adm; then
                failed "IS_USERINADMGROUP" "User $user doesn't belong to \`adm' group"
                test "${VERBOSE}" = 1 || break
            fi
        done
    fi
}
check_apache2evolinuxconf() {
    if is_debian_stretch || is_debian_buster; then
        if test -d /etc/apache2; then
            { test -L /etc/apache2/conf-enabled/z-evolinux-defaults.conf \
                && test -L /etc/apache2/conf-enabled/zzz-evolinux-custom.conf \
                && test -f /etc/apache2/ipaddr_whitelist.conf;
            } || failed "IS_APACHE2EVOLINUXCONF" "missing custom evolinux apache config"
        fi
    fi
}
check_backportsconf() {
    if is_debian_stretch || is_debian_buster; then
        grep -qsE "^[^#].*backports" /etc/apt/sources.list \
            && failed "IS_BACKPORTSCONF" "backports can't be in main sources list"
        if grep -qsE "^[^#].*backports" /etc/apt/sources.list.d/*.list; then
            grep -qsE "^[^#].*backports" /etc/apt/preferences.d/* \
                || failed "IS_BACKPORTSCONF" "backports must have preferences"
        fi
    fi
}
check_bind9munin() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed bind9; then
            { test -L /etc/munin/plugins/bind9 \
                && test -e /etc/munin/plugin-conf.d/bind9;
            } || failed "IS_BIND9MUNIN" "missing bind plugin for munin"
        fi
    fi
}
check_bind9logrotate() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed bind9; then
            test -e /etc/logrotate.d/bind9 || failed "IS_BIND9LOGROTATE" "missing bind logrotate file"
        fi
    fi
}
check_broadcomfirmware() {
    LSPCI_BIN=$(command -v lspci)
    if [ -x "${LSPCI_BIN}" ]; then
        if ${LSPCI_BIN} | grep -q 'NetXtreme II'; then
            { is_installed firmware-bnx2 \
                && grep -q "^deb http://mirror.evolix.org/debian.* non-free" /etc/apt/sources.list;
            } || failed "IS_BROADCOMFIRMWARE" "missing non-free repository"
        fi
    else
        failed "IS_BROADCOMFIRMWARE" "lspci not found in ${PATH}"
    fi
}
check_hardwareraidtool() {
    LSPCI_BIN=$(command -v lspci)
    if [ -x "${LSPCI_BIN}" ]; then
        if ${LSPCI_BIN} | grep -q 'MegaRAID SAS'; then
            # shellcheck disable=SC2015
            is_installed megacli && { is_installed megaclisas-status || is_installed megaraidsas-status; } \
                || failed "IS_HARDWARERAIDTOOL" "Mega tools not found"
        fi
        if ${LSPCI_BIN} | grep -q 'Hewlett-Packard Company Smart Array'; then
            is_installed cciss-vol-status || failed "IS_HARDWARERAIDTOOL" "cciss-vol-status not installed"
        fi
    else
        failed "IS_HARDWARERAIDTOOL" "lspci not found in ${PATH}"
    fi
}
check_log2mailsystemdunit() {
    if is_debian_stretch || is_debian_buster; then
        systemctl -q is-active log2mail.service \
            || failed "IS_LOG2MAILSYSTEMDUNIT" "log2mail unit not running"
        test -f /etc/systemd/system/log2mail.service \
            || failed "IS_LOG2MAILSYSTEMDUNIT" "missing log2mail unit file"
        test -f /etc/init.d/log2mail \
            && failed "IS_LOG2MAILSYSTEMDUNIT" "/etc/init.d/log2mail may be deleted (use systemd unit)"
    fi
}
check_listupgrade() {
    test -f /etc/cron.d/listupgrade \
        || failed "IS_LISTUPGRADE" "missing listupgrade cron"
    test -x /usr/share/scripts/listupgrade.sh \
        || failed "IS_LISTUPGRADE" "missing listupgrade script or not executable"
}
check_mariadbevolinuxconf() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed mariadb-server; then
            { test -f /etc/mysql/mariadb.conf.d/z-evolinux-defaults.cnf \
                && test -f /etc/mysql/mariadb.conf.d/zzz-evolinux-custom.cnf;
            } || failed "IS_MARIADBEVOLINUXCONF" "missing mariadb custom config"
        fi
    fi
}
check_sql_backup() {
    if (is_installed "mysql-server" || is_installed "mariadb-server"); then
        # You could change the default path in /etc/evocheck.cf
        SQL_BACKUP_PATH=${SQL_BACKUP_PATH:-"/home/backup/mysql.bak.gz"}
        test -f "$SQL_BACKUP_PATH" || failed "IS_SQL_BACKUP" "MySQL dump is missing (${SQL_BACKUP_PATH})"
    fi
}
check_postgres_backup() {
    if is_installed "postgresql-9*"; then
        # If you use something like barman, you should disable this check
        # You could change the default path in /etc/evocheck.cf
        POSTGRES_BACKUP_PATH=${POSTGRES_BACKUP_PATH:-"/home/backup/pg.dump.bak"}
        test -f "$POSTGRES_BACKUP_PATH" || failed "IS_POSTGRES_BACKUP" "PostgreSQL dump is missing (${POSTGRES_BACKUP_PATH})"
    fi
}
check_mongo_backup() {
    if is_installed "mongodb-org-server"; then
        # You could change the default path in /etc/evocheck.cf
        MONGO_BACKUP_PATH=${MONGO_BACKUP_PATH:-"/home/backup/mongodump"}
        if [ -d "$MONGO_BACKUP_PATH" ]; then
            for file in "${MONGO_BACKUP_PATH}"/*/*.{json,bson}; do
                # Skip indexes file.
                if ! [[ "$file" =~ indexes ]]; then
                    limit=$(date +"%s" -d "now - 2 day")
                    updated_at=$(stat -c "%Y" "$file")
                    if [ -f "$file" ] && [ "$limit" -gt "$updated_at"  ]; then
                        failed "IS_MONGO_BACKUP" "MongoDB hasn't been dumped for more than 2 days"
                        break
                    fi
                fi
            done
        else
            failed "IS_MONGO_BACKUP" "MongoDB dump directory is missing (${MONGO_BACKUP_PATH})"
        fi
    fi
}
check_ldap_backup() {
    if is_installed slapd; then
        # You could change the default path in /etc/evocheck.cf
        LDAP_BACKUP_PATH=${LDAP_BACKUP_PATH:-"/home/backup/ldap.bak"}
        test -f "$LDAP_BACKUP_PATH" || failed "IS_LDAP_BACKUP" "LDAP dump is missing (${LDAP_BACKUP_PATH})"
    fi
}
check_redis_backup() {
    if is_installed redis-server; then
        # You could change the default path in /etc/evocheck.cf
        REDIS_BACKUP_PATH=${REDIS_BACKUP_PATH:-"/home/backup/dump.rdb"}
        test -f "$REDIS_BACKUP_PATH" || failed "IS_REDIS_BACKUP" "Redis dump is missing (${REDIS_BACKUP_PATH})"
    fi
}
check_elastic_backup() {
    if is_installed elasticsearch; then
        # You could change the default path in /etc/evocheck.cf
        ELASTIC_BACKUP_PATH=${ELASTIC_BACKUP_PATH:-"/home/backup-elasticsearch"}
        test -d "$ELASTIC_BACKUP_PATH" || failed "IS_ELASTIC_BACKUP" "Elastic snapshot is missing (${ELASTIC_BACKUP_PATH})"
    fi
}
check_mariadbsystemdunit() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed mariadb-server; then
            if systemctl -q is-active mariadb.service; then
                test -f /etc/systemd/system/mariadb.service.d/evolinux.conf \
                    || failed "IS_MARIADBSYSTEMDUNIT" "missing systemd override for mariadb unit"
            fi
        fi
    fi
}
check_mysqlmunin() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed mariadb-server; then
            for file in mysql_bytes mysql_queries mysql_slowqueries \
                mysql_threads mysql_connections mysql_files_tables \
                mysql_innodb_bpool mysql_innodb_bpool_act mysql_innodb_io \
                mysql_innodb_log mysql_innodb_rows mysql_innodb_semaphores \
                mysql_myisam_indexes mysql_qcache mysql_qcache_mem \
                mysql_sorts mysql_tmp_tables; do

                if [[ ! -L /etc/munin/plugins/$file ]]; then
                    failed "IS_MYSQLMUNIN" "missing munin plugin '$file'"
                    test "${VERBOSE}" = 1 || break
                fi
            done
        fi
    fi
}
check_mysqlnrpe() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed mariadb-server; then
            nagios_file=~nagios/.my.cnf
            if ! test -f ${nagios_file}; then
                failed "IS_MYSQLNRPE" "${nagios_file} is missing"
            elif [ "$(stat -c %U ${nagios_file})" != "nagios" ] \
                || [ "$(stat -c %a ${nagios_file})" != "600" ]; then
                failed "IS_MYSQLNRPE" "${nagios_file} has wrong permissions"
            else
                grep -q -F "command[check_mysql]=/usr/lib/nagios/plugins/check_mysql" /etc/nagios/nrpe.d/evolix.cfg \
                || failed "IS_MYSQLNRPE" "check_mysql is missing"
            fi
        fi
    fi
}
check_phpevolinuxconf() {
    if is_debian_stretch || is_debian_buster; then
        is_debian_stretch && phpVersion="7.0"
        is_debian_buster && phpVersion="7.3"
        if is_installed php; then
            { test -f /etc/php/${phpVersion}/cli/conf.d/z-evolinux-defaults.ini \
                && test -f /etc/php/${phpVersion}/cli/conf.d/zzz-evolinux-custom.ini
            } || failed "IS_PHPEVOLINUXCONF" "missing php evolinux config"
        fi
    fi
}
check_squidlogrotate() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed squid; then
            grep -q monthly /etc/logrotate.d/squid \
                || failed "IS_SQUIDLOGROTATE" "missing squid logrotate file"
        fi
    fi
}
check_squidevolinuxconf() {
    if is_debian_stretch || is_debian_buster; then
        if is_installed squid; then
            { grep -qs "^CONFIG=/etc/squid/evolinux-defaults.conf$" /etc/default/squid \
                && test -f /etc/squid/evolinux-defaults.conf \
                && test -f /etc/squid/evolinux-whitelist-defaults.conf \
                && test -f /etc/squid/evolinux-whitelist-custom.conf \
                && test -f /etc/squid/evolinux-acl.conf \
                && test -f /etc/squid/evolinux-httpaccess.conf \
                && test -f /etc/squid/evolinux-custom.conf;
            } || failed "IS_SQUIDEVOLINUXCONF" "missing squid evolinux config"
        fi
    fi
}
check_duplicate_fs_label() {
    # Do it only if thereis blkid binary
    BLKID_BIN=$(command -v blkid)
    if [ -x "$BLKID_BIN" ]; then
        tmpFile=$(mktemp -p /tmp)
        parts=$($BLKID_BIN | grep -ve raid_member -e EFI_SYSPART | grep -Eo ' LABEL=".*"' | cut -d'"' -f2)
        for part in $parts; do
            echo "$part" >> "$tmpFile"
        done
        tmpOutput=$(sort < "$tmpFile" | uniq -d)
        # If there is no duplicate, uniq will have no output
        # So, if $tmpOutput is not null, there is a duplicate
        if [ -n "$tmpOutput" ]; then
            # shellcheck disable=SC2086
            labels=$(echo -n $tmpOutput | tr '\n' ' ')
            failed "IS_DUPLICATE_FS_LABEL" "Duplicate labels: $labels"
        fi
        rm "$tmpFile"
    else
        failed "IS_DUPLICATE_FS_LABEL" "blkid not found in ${PATH}"
    fi
}
check_evolix_user() {
    grep -q "evolix:" /etc/passwd \
        && failed "IS_EVOLIX_USER" "evolix user should be deleted, used only for install"
}
check_evoacme_cron() {
    if [ -f "/usr/local/sbin/evoacme" ]; then
        # Old cron file, should be deleted
        test -f /etc/cron.daily/certbot && failed "IS_EVOACME_CRON" "certbot cron is incompatible with evoacme"
        # evoacme cron file should be present
        test -f /etc/cron.daily/evoacme || failed "IS_EVOACME_CRON" "evoacme cron is missing"
    fi
}
check_evoacme_livelinks() {
    EVOACME_BIN=$(command -v evoacme)
    if [ -x "$EVOACME_BIN" ]; then
        # Sometimes evoacme is installed but no certificates has been generated
        numberOfLinks=$(find /etc/letsencrypt/ -type l | wc -l)
        if [ "$numberOfLinks" -gt 0 ]; then
            for live in /etc/letsencrypt/*/live; do
                actualLink=$(readlink -f "$live")
                actualVersion=$(basename "$actualLink")

                certDir=$(dirname "$live")
                certName=$(basename "$certDir")
                # shellcheck disable=SC2012
                lastCertDir=$(ls -ds "${certDir}"/[0-9]* | tail -1)
                lastVersion=$(basename "$lastCertDir")

                if [[ "$lastVersion" != "$actualVersion" ]]; then
                    failed "IS_EVOACME_LIVELINKS" "Certificate \`$certName' hasn't been updated"
                    test "${VERBOSE}" = 1 || break
                fi
            done
        fi
    fi
}
check_apache_confenabled() {
    # Starting from Jessie and Apache 2.4, /etc/apache2/conf.d/
    # must be replaced by conf-available/ and config files symlinked
    # to conf-enabled/
    if is_debian_jessie || is_debian_stretch || is_debian_buster; then
        if [ -f /etc/apache2/apache2.conf ]; then
            test -d /etc/apache2/conf.d/ \
                && failed "IS_APACHE_CONFENABLED" "apache's conf.d directory must not exists"
            grep -q 'Include conf.d' /etc/apache2/apache2.conf \
                && failed "IS_APACHE_CONFENABLED" "apache2.conf must not Include conf.d"
        fi
    fi
}
check_meltdown_spectre() {
    # For Stretch, detection is easy as the kernel use
    # /sys/devices/system/cpu/vulnerabilities/
    if is_debian_stretch || is_debian_buster; then
        for vuln in meltdown spectre_v1 spectre_v2; do
            test -f "/sys/devices/system/cpu/vulnerabilities/$vuln" \
                || failed "IS_MELTDOWN_SPECTRE" "vulnerable to $vuln"
            test "${VERBOSE}" = 1 || break
        done
    # For Jessie this is quite complicated to verify and we need to use kernel config file
    elif is_debian_jessie; then
        if grep -q "BOOT_IMAGE=" /proc/cmdline; then
            kernelPath=$(grep -Eo 'BOOT_IMAGE=[^ ]+' /proc/cmdline | cut -d= -f2)
            kernelVer=${kernelPath##*/vmlinuz-}
            kernelConfig="config-${kernelVer}"
            # Sometimes autodetection of kernel config file fail, so we test if the file really exists.
            if [ -f "/boot/${kernelConfig}" ]; then
                grep -Eq '^CONFIG_PAGE_TABLE_ISOLATION=y' "/boot/$kernelConfig" \
                    || failed "IS_MELTDOWN_SPECTRE" \
                    "PAGE_TABLE_ISOLATION must be enabled in kernel, outdated kernel?"
                grep -Eq '^CONFIG_RETPOLINE=y' "/boot/$kernelConfig" \
                    || failed "IS_MELTDOWN_SPECTRE" \
                    "RETPOLINE must be enabled in kernel, outdated kernel?"
            fi
        fi
    fi
}
check_old_home_dir() {
    homeDir=${homeDir:-/home}
    for dir in "$homeDir"/*; do
        statResult=$(stat -c "%n has owner %u resolved as %U" "$dir" \
            | grep -Eve '.bak' -e '\.[0-9]{2}-[0-9]{2}-[0-9]{4}' \
            | grep "UNKNOWN")
        # There is at least one dir matching
        if [[ -n "$statResult" ]]; then
            failed "IS_OLD_HOME_DIR" "$statResult"
            test "${VERBOSE}" = 1 || break
        fi
    done
}
check_tmp_1777() {
    actual=$(stat --format "%a" /tmp)
    expected="1777"
    test "$expected" = "$actual" || failed "IS_TMP_1777" "/tmp must be $expected"
}
check_root_0700() {
    actual=$(stat --format "%a" /root)
    expected="700"
    test "$expected" = "$actual" || failed "IS_ROOT_0700" "/root must be $expected"
}
check_usrsharescripts() {
    actual=$(stat --format "%a" /usr/share/scripts)
    expected="700"
    test "$expected" = "$actual" || failed "IS_USRSHARESCRIPTS" "/usr/share/scripts must be $expected"
}
check_sshpermitrootno() {
    if is_debian_stretch || is_debian_buster; then
        if grep -q "^PermitRoot" /etc/ssh/sshd_config; then
            grep -E -qi "PermitRoot.*no" /etc/ssh/sshd_config \
                || failed "IS_SSHPERMITROOTNO" "PermitRoot should be set at no"
        fi
    else
        grep -E -qi "PermitRoot.*no" /etc/ssh/sshd_config \
            || failed "IS_SSHPERMITROOTNO" "PermitRoot should be set at no"
    fi
}
check_evomaintenanceusers() {
    if is_debian_stretch || is_debian_buster; then
        users=$(getent group evolinux-sudo | cut -d':' -f4 | tr ',' ' ')
    else
        if [ -f /etc/sudoers.d/evolinux ]; then
            sudoers="/etc/sudoers.d/evolinux"
        else
            sudoers="/etc/sudoers"
        fi
        # combine users from User_Alias and sudo group
        users=$({ grep "^User_Alias *ADMIN" $sudoers | cut -d= -f2 | tr -d " "; grep "^sudo" /etc/group | cut -d: -f 4; } | tr "," "\n" | sort -u)
    fi
    for user in $users; do
        user_home=$(getent passwd "$user" | cut -d: -f6)
        if [ -n "$user_home" ] && [ -d "$user_home" ]; then
            if ! grep -qs "^trap.*sudo.*evomaintenance.sh" "${user_home}"/.*profile; then
                failed "IS_EVOMAINTENANCEUSERS" "${user} doesn't have an evomaintenance trap"
                test "${VERBOSE}" = 1 || break
            fi
        fi
    done
}
check_evomaintenanceconf() {
    f=/etc/evomaintenance.cf
    if [ -e "$f" ]; then
        perms=$(stat -c "%a" $f)
        test "$perms" = "600" || failed "IS_EVOMAINTENANCECONF" "Wrong permissions on \`$f' ($perms instead of 600)"

        { grep "^export PGPASSWORD" $f | grep -qv "your-passwd" \
            && grep "^PGDB" $f | grep -qv "your-db" \
            && grep "^PGTABLE" $f | grep -qv "your-table" \
            && grep "^PGHOST" $f | grep -qv "your-pg-host" \
            && grep "^FROM" $f | grep -qv "jdoe@example.com" \
            && grep "^FULLFROM" $f | grep -qv "John Doe <jdoe@example.com>" \
            && grep "^URGENCYFROM" $f | grep -qv "mama.doe@example.com" \
            && grep "^URGENCYTEL" $f | grep -qv "06.00.00.00.00" \
            && grep "^REALM" $f | grep -qv "example.com"
        } || failed "IS_EVOMAINTENANCECONF" "evomaintenance is not correctly configured"
    else
        failed "IS_EVOMAINTENANCECONF" "Configuration file \`$f' is missing"
    fi
}
check_privatekeyworldreadable() {
    # a simple globbing fails if directory is empty
    if [ -n "$(ls -A /etc/ssl/private/)" ]; then
        for f in /etc/ssl/private/*; do
            perms=$(stat -L -c "%a" "$f")
            if [ "${perms: -1}" != 0 ]; then
                failed "IS_PRIVKEYWOLRDREADABLE" "$f is world-readable"
                test "${VERBOSE}" = 1 || break
            fi
        done
    fi
}
check_evobackup_incs() {
    if is_installed bkctld; then
        bkctld_cron_file=${bkctld_cron_file:-/etc/cron.d/bkctld}
        if [ -f "${bkctld_cron_file}" ]; then
            root_crontab=$(grep -v "^#" "${bkctld_cron_file}")
            echo "${root_crontab}" | grep -q "bkctld inc" || failed "IS_EVOBACKUP_INCS" "\`bkctld inc' is missing in ${bkctld_cron_file}"
            echo "${root_crontab}" | grep -q "check-incs.sh" || failed "IS_EVOBACKUP_INCS" "\`check-incs.sh' is missing in ${bkctld_cron_file}"
        else
            failed "IS_EVOBACKUP_INCS" "Crontab \`${bkctld_cron_file}' is missing"
        fi
    fi
}

check_osprober() {
    if is_installed os-prober qemu-kvm; then
        failed "IS_OSPROBER" \
            "Removal of os-prober package is recommended as it can cause serious issue on KVM server"
    fi
}

check_jessie_backports() {
    if is_debian_jessie; then
        jessieBackports=$(grep -hs "jessie-backports" /etc/apt/sources.list /etc/apt/sources.list.d/*)
        if test -n "$jessieBackports"; then
            if ! grep -q "archive.debian.org" <<< "$jessieBackports"; then
                failed "IS_JESSIE_BACKPORTS" "You must use deb http://archive.debian.org/debian/ jessie-backports main"
            fi
        fi
    fi
}

check_apt_valid_until() {
    aptvalidFile="/etc/apt/apt.conf.d/99no-check-valid-until"
    aptvalidText="Acquire::Check-Valid-Until no;"
    if grep -qs "archive.debian.org" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
        if ! grep -qs "$aptvalidText" /etc/apt/apt.conf.d/*; then
            failed "IS_APT_VALID_UNTIL" \
                "As you use archive.mirror.org you need ${aptvalidFile}: ${aptvalidText}"
        fi
    fi
}

main() {
    # Default return code : 0 = no error
    RC=0
    # Detect operating system name, version and release
    detect_os

    #-----------------------------------------------------------
    # Tests communs à tous les systèmes
    #-----------------------------------------------------------

    test "${IS_TMP_1777:=1}" = 1 && check_tmp_1777
    test "${IS_ROOT_0700:=1}" = 1 && check_root_0700
    test "${IS_USRSHARESCRIPTS:=1}" = 1 && check_usrsharescripts
    test "${IS_SSHPERMITROOTNO:=1}" = 1 && check_sshpermitrootno
    test "${IS_EVOMAINTENANCEUSERS:=1}" = 1 && check_evomaintenanceusers
    # Verification de la configuration d'evomaintenance
    test "${IS_EVOMAINTENANCECONF:=1}" = 1 && check_evomaintenanceconf
    test "${IS_PRIVKEYWOLRDREADABLE:=1}" = 1 && check_privatekeyworldreadable

    #-----------------------------------------------------------
    # Vérifie si c'est une debian et fait les tests appropriés.
    #-----------------------------------------------------------

    if is_debian; then
        MINIFW_FILE=$(minifirewall_file)

        test "${IS_LSBRELEASE:=1}" = 1 && check_lsbrelease
        test "${IS_DPKGWARNING:=1}" = 1 && check_dpkgwarning
        test "${IS_UMASKSUDOERS:=1}" = 1 && check_umasksudoers
        test "${IS_NRPEPOSTFIX:=1}" = 1 && check_nrpepostfix
        test "${IS_MODSECURITY:=1}" = 1 && check_modsecurity
        test "${IS_CUSTOMSUDOERS:=1}" = 1 && check_customsudoers
        test "${IS_VARTMPFS:=1}" = 1 && check_vartmpfs
        test "${IS_SERVEURBASE:=1}" = 1 && check_serveurbase
        test "${IS_LOGROTATECONF:=1}" = 1 && check_logrotateconf
        test "${IS_SYSLOGCONF:=1}" = 1 && check_syslogconf
        test "${IS_DEBIANSECURITY:=1}" = 1 && check_debiansecurity
        test "${IS_APTITUDEONLY:=1}" = 1 && check_aptitudeonly
        test "${IS_APTITUDE:=1}" = 1 && check_aptitude
        test "${IS_APTGETBAK:=1}" = 1 && check_aptgetbak
        test "${IS_APTICRON:=0}" = 1 && check_apticron
        test "${IS_USRRO:=1}" = 1 && check_usrro
        test "${IS_TMPNOEXEC:=1}" = 1 && check_tmpnoexec
        test "${IS_MOUNT_FSTAB:=1}" = 1 && check_mountfstab
        test "${IS_LISTCHANGESCONF:=1}" = 1 && check_listchangesconf
        test "${IS_CUSTOMCRONTAB:=1}" = 1 && check_customcrontab
        test "${IS_SSHALLOWUSERS:=1}" = 1 && check_sshallowusers
        test "${IS_DISKPERF:=0}" = 1 && check_diskperf
        test "${IS_TMOUTPROFILE:=1}" = 1 && check_tmoutprofile
        test "${IS_ALERT5BOOT:=1}" = 1 && check_alert5boot
        test "${IS_ALERT5MINIFW:=1}" = 1 && check_alert5minifw
        test "${IS_ALERT5MINIFW:=1}" = 1 && test "${IS_MINIFW:=1}" = 1 && check_minifw
        test "${IS_NRPEPERMS:=1}" = 1 && check_nrpeperms
        test "${IS_MINIFWPERMS:=1}" = 1 && check_minifwperms
        test "${IS_NRPEDISKS:=0}" = 1 && check_nrpedisks
        test "${IS_NRPEPID:=1}" = 1 && check_nrpepid
        test "${IS_GRSECPROCS:=1}" = 1 && check_grsecprocs
        test "${IS_APACHEMUNIN:=1}" = 1 && check_apachemunin
        test "${IS_MYSQLUTILS:=1}" = 1 && check_mysqlutils
        test "${IS_RAIDSOFT:=1}" = 1 && check_raidsoft
        test "${IS_AWSTATSLOGFORMAT:=1}" = 1 && check_awstatslogformat
        test "${IS_MUNINLOGROTATE:=1}" = 1 && check_muninlogrotate
        test "${IS_SQUID:=1}" = 1 && check_squid
        test "${IS_EVOMAINTENANCE_FW:=1}" = 1 && check_evomaintenance_fw
        test "${IS_MODDEFLATE:=1}" = 1 && check_moddeflate
        test "${IS_LOG2MAILRUNNING:=1}" = 1 && check_log2mailrunning
        test "${IS_LOG2MAILAPACHE:=1}" = 1 && check_log2mailapache
        test "${IS_LOG2MAILMYSQL:=1}" = 1 && check_log2mailmysql
        test "${IS_LOG2MAILSQUID:=1}" = 1 && check_log2mailsquid
        test "${IS_BINDCHROOT:=1}" = 1 && check_bindchroot
        test "${IS_REPVOLATILE:=1}" = 1 && check_repvolatile
        test "${IS_NETWORK_INTERFACES:=1}" = 1 && check_network_interfaces
        test "${IS_AUTOIF:=1}" = 1 && check_autoif
        test "${IS_INTERFACESGW:=1}" = 1 && check_interfacesgw
        test "${IS_EVOBACKUP:=1}" = 1 && check_evobackup
        test "${IS_USERLOGROTATE:=1}" = 1 && check_userlogrotate
        test "${IS_APACHECTL:=1}" = 1 && check_apachectl
        test "${IS_APACHESYMLINK:=1}" = 1 && check_apachesymlink
        test "${IS_APACHEIPINALLOW:=1}" = 1 && check_apacheipinallow
        test "${IS_MUNINAPACHECONF:=1}" = 1 && check_muninapacheconf
        test "${IS_SAMBAPINPRIORITY:=1}" = 1 && check_sambainpriority
        test "${IS_KERNELUPTODATE:=1}" = 1 && check_kerneluptodate
        test "${IS_UPTIME:=1}" = 1 && check_uptime
        test "${IS_MUNINRUNNING:=1}" = 1 && check_muninrunning
        test "${IS_BACKUPUPTODATE:=1}" = 1 && check_backupuptodate
        test "${IS_ETCGIT:=1}" = 1 && check_etcgit
        test "${IS_GITPERMS:=1}" = 1 && check_gitperms
        test "${IS_NOTUPGRADED:=1}" = 1 && check_notupgraded
        test "${IS_TUNE2FS_M5:=1}" = 1 && check_tune2fs_m5
        test "${IS_EVOLINUXSUDOGROUP:=1}" = 1 && check_evolinuxsudogroup
        test "${IS_USERINADMGROUP:=1}" = 1 && check_userinadmgroup
        test "${IS_APACHE2EVOLINUXCONF:=1}" = 1 && check_apache2evolinuxconf
        test "${IS_BACKPORTSCONF:=1}" = 1 && check_backportsconf
        test "${IS_BIND9MUNIN:=1}" = 1 && check_bind9munin
        test "${IS_BIND9LOGROTATE:=1}" = 1 && check_bind9logrotate
        test "${IS_BROADCOMFIRMWARE:=1}" = 1 && check_broadcomfirmware
        test "${IS_HARDWARERAIDTOOL:=1}" = 1 && check_hardwareraidtool
        test "${IS_LOG2MAILSYSTEMDUNIT:=1}" = 1 && check_log2mailsystemdunit
        test "${IS_LISTUPGRADE:=1}" = 1 && check_listupgrade
        test "${IS_MARIADBEVOLINUXCONF:=1}" = 1 && check_mariadbevolinuxconf
        test "${IS_SQL_BACKUP:=1}" = 1 && check_sql_backup
        test "${IS_POSTGRES_BACKUP:=1}" = 1 && check_postgres_backup
        test "${IS_MONGO_BACKUP:=1}" = 1 && check_mongo_backup
        test "${IS_LDAP_BACKUP:=1}" = 1 && check_ldap_backup
        test "${IS_REDIS_BACKUP:=1}" = 1 && check_redis_backup
        test "${IS_ELASTIC_BACKUP:=1}" = 1 && check_elastic_backup
        test "${IS_MARIADBSYSTEMDUNIT:=1}" = 1 && check_mariadbsystemdunit
        test "${IS_MYSQLMUNIN:=1}" = 1 && check_mysqlmunin
        test "${IS_MYSQLNRPE:=1}" = 1 && check_mysqlnrpe
        test "${IS_PHPEVOLINUXCONF:=1}" = 1 && check_phpevolinuxconf
        test "${IS_SQUIDLOGROTATE:=1}" = 1 && check_squidlogrotate
        test "${IS_SQUIDEVOLINUXCONF:=1}" = 1 && check_squidevolinuxconf
        test "${IS_DUPLICATE_FS_LABEL:=1}" = 1 && check_duplicate_fs_label
        test "${IS_EVOLIX_USER:=1}" = 1 && check_evolix_user
        test "${IS_EVOACME_CRON:=1}" = 1 && check_evoacme_cron
        test "${IS_EVOACME_LIVELINKS:=1}" = 1 && check_evoacme_livelinks
        test "${IS_APACHE_CONFENABLED:=1}" = 1 && check_apache_confenabled
        test "${IS_MELTDOWN_SPECTRE:=1}" = 1 && check_meltdown_spectre
        test "${IS_OLD_HOME_DIR:=1}" = 1 && check_old_home_dir
        test "${IS_EVOBACKUP_INCS:=1}" = 1 && check_evobackup_incs
        test "${IS_OSPROBER:=1}" = 1 && check_osprober
        test "${IS_JESSIE_BACKPORTS:=1}" = 1 && check_jessie_backports
        test "${IS_APT_VALID_UNTIL:=1}" = 1 && check_apt_valid_until
    fi

    #-----------------------------------------------------------
    # Tests spécifiques à OpenBSD
    #-----------------------------------------------------------

    if is_openbsd; then

        if [ "${IS_SOFTDEP:=1}" = 1 ]; then
            grep -q "softdep" /etc/fstab || failed "IS_SOFTDEP"
        fi

        if [ "${IS_WHEEL:=1}" = 1 ]; then
            grep -qE "^%wheel.*$" /etc/sudoers || failed "IS_WHEEL"
        fi

        if [ "${IS_SUDOADMIN:=1}" = 1 ]; then
            grep -qE "^User_Alias ADMIN=.*$" /etc/sudoers || failed "IS_SUDOADMIN"
        fi

        if [ "${IS_PKGMIRROR:=1}" = 1 ]; then
            grep -qE "^export PKG_PATH=http://ftp\.fr\.openbsd\.org/pub/OpenBSD/[0-9.]+/packages/[a-z0-9]+/$" /root/.profile \
                || failed "IS_PKGMIRROR"
        fi

        if [ "${IS_HISTORY:=1}" = 1 ]; then
            f=/root/.profile
            { grep -q "^HISTFILE=\$HOME/.histfile" $f \
                && grep -q "^export HISTFILE" $f \
                && grep -q "^HISTSIZE=1000" $f \
                && grep -q "^export HISTSIZE" $f;
            } || failed "IS_HISTORY"
        fi

        if [ "${IS_VIM:=1}" = 1 ]; then
            command -v vim > /dev/null 2>&1 || failed "IS_VIM"
        fi

        if [ "${IS_TTYC0SECURE:=1}" = 1 ]; then
            grep -Eqv "^ttyC0.*secure$" /etc/ttys || failed "IS_TTYC0SECURE"
        fi

        if [ "${IS_CUSTOMSYSLOG:=1}" = 1 ]; then
            grep -q "Evolix" /etc/newsyslog.conf || failed "IS_CUSTOMSYSLOG"
        fi

        if [ "${IS_NOINETD:=1}" = 1 ]; then
            grep -q "inetd=NO" /etc/rc.conf.local 2>/dev/null || failed "IS_NOINETD"
        fi

        if [ "${IS_SUDOMAINT:=1}" = 1 ]; then
            f=/etc/sudoers
            { grep -q "Cmnd_Alias MAINT = /usr/share/scripts/evomaintenance.sh" $f \
                && grep -q "ADMIN ALL=NOPASSWD: MAINT" $f;
            } || failed "IS_SUDOMAINT"
        fi

        if [ "${IS_POSTGRESQL:=1}" = 1 ]; then
            pkg info | grep -q postgresql-client || failed "IS_POSTGRESQL" "postgresql-client is not installed"
        fi

        if [ "${IS_NRPE:=1}" = 1 ]; then
            { pkg info | grep -qE "nagios-plugins-[0-9.]" \
                && pkg info | grep -q nagios-plugins-ntp \
                && pkg info | grep -q nrpe;
            } || failed "IS_NRPE" "NRPE is not installed"
        fi

    # if [ "${IS_NRPEDISKS:=1}" = 1 ]; then
    #     NRPEDISKS=$(grep command.check_disk /etc/nrpe.cfg 2>/dev/null | grep "^command.check_disk[0-9]" | sed -e "s/^command.check_disk\([0-9]\+\).*/\1/" | sort -n | tail -1)
    #     DFDISKS=$(df -Pl | grep -E -v "(^Filesystem|/lib/init/rw|/dev/shm|udev|rpc_pipefs)" | wc -l)
    #     [ "$NRPEDISKS" = "$DFDISKS" ] || failed "IS_NRPEDISKS"
    # fi

    # Verification du check_mailq dans nrpe.cfg (celui-ci doit avoir l'option "-M postfix" si le MTA est Postfix)
    #
    # if [ "${IS_NRPEPOSTFIX:=1}" = 1 ]; then
    #     pkg info | grep -q postfix && ( grep -q "^command.*check_mailq -M postfix" /etc/nrpe.cfg 2>/dev/null || failed "IS_NRPEPOSTFIX" )
    # fi

        if [ "${IS_NRPEDAEMON:=1}" = 1 ]; then
            grep -q "echo -n ' nrpe';        /usr/local/sbin/nrpe -d" /etc/rc.local \
                || failed "IS_NREPEDAEMON"
        fi

        if [ "${IS_ALERTBOOT:=1}" = 1 ]; then
            grep -qE "^date \| mail -sboot/reboot .*evolix.fr$" /etc/rc.local \
                || failed "IS_ALERTBOOT"
        fi

        if [ "${IS_RSYNC:=1}" = 1 ]; then
            pkg info | grep -q rsync || failed "IS_RSYNC"
        fi

        if [ "${IS_CRONPATH:=1}" = 1 ]; then
            grep -q "PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin" /var/cron/tabs/root \
                || failed "IS_CRONPATH"
        fi

        #TODO
        # - Check en profondeur de postfix
        # - NRPEDISK et NRPEPOSTFIX
    fi

    exit ${RC}
}

readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(realpath -m "$(dirname "$0")")
# shellcheck disable=2124
readonly ARGS=$@

readonly VERSION="19.09"

# Disable LANG*
export LANG=C
export LANGUAGE=C

# Source configuration file
# shellcheck disable=SC1091
test -f /etc/evocheck.cf && . /etc/evocheck.cf

# Parse options
# based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        --cron)
            IS_KERNELUPTODATE=0
            IS_UPTIME=0
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;
        -q|--quiet)
            QUIET=1
            VERBOSE=0
            ;;
        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            if [ "${QUIET}" != 1 ]; then
                printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            fi
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# shellcheck disable=SC2086
main ${ARGS}
