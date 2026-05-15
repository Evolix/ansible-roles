#!/bin/bash

# EvoCheck
# Script to verify compliance of a Linux (Debian 10+) server
# powered by Evolix

#set -x

VERSION="26.05"
readonly VERSION

# base functions

show_version() {
    cat <<END
evocheck version ${VERSION}

Copyright 2009-2026 Evolix <info@evolix.fr>,
                    Romain Dessort <rdessort@evolix.fr>,
                    Benoit Série <bserie@evolix.fr>,
                    Gregory Colpart <reg@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Tristan Pilat <tpilat@evolix.fr>,
                    Victor Laborie <vlaborie@evolix.fr>,
                    Alexis Ben Miloud--Josselin <abenmiloud@evolix.fr>,
                    and others.

evocheck comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
END
}
show_help() {
    cat <<END
evocheck is a script that verifies Evolix conventions on Linux (Debian) servers.

Usage: evocheck
  or   evocheck --cron
  or   evocheck --future
  or   evocheck --quiet
  or   evocheck --verbose
  or   evocheck --min-level 2 --max-level 3

Options
     --cron                  disable a few checks
     --future                enable checks that will be enabled later
 -v, --verbose               display full documentation for fail checks
 -q, --quiet                 nothing is printed on stdout
     --min-level X           executes only checkwith level >= X
     --max-level Y           executes only checkwith level <= Y
 -h, --help                  print this message and exit
     --version               print version and exit

Check levels :
 1 : optional
 2 : standard
 3 : important
 4 : mandatory
END
}

exec_checks() {
    check_tmp_1777
    check_root_0700
    check_usrsharescripts
    check_sshpermitrootno
    check_evomaintenanceusers
    check_evomaintenanceconf
    check_privatekeyworldreadable
    check_lsbrelease
    check_dpkgwarning
    check_postfix_mydestination
    check_nrpepostfix
    check_customsudoers
    check_vartmpfs
    check_serveurbase
    check_logrotateconf
    check_syslogconf
    check_nonfree
    check_debiansecurity
    check_debiansecurity_lxc
    check_debiansecuritymirror
    check_debiansecuritymirror_lxc
    check_backports_version
    check_oldpub
    check_oldpub_lxc
    check_newpub
    check_sury
    check_sury_lxc
    check_not_deb822
    check_no_signed_by
    check_aptitude
    check_aptgetbak
    check_usrro
    check_tmpnoexec
    check_homenoexec
    check_mountfstab
    check_listchangesconf
    check_customcrontab
    check_sshallowusers
    check_sshconfsplit
    check_sshlastmatch
    check_tmoutprofile
    check_alert5boot
    check_alert5minifw
    check_minifw
    check_nrpeperms
    check_minifwperms
    check_minifw_related
    check_minifw_includes
    check_nrpepid
    check_grsecprocs
    check_apachemunin
    check_mysqlutils
    check_raidsoft
    check_awstatslogformat
    check_muninlogrotate
    check_squid
    check_evomaintenance_fw
    check_moddeflate
    check_log2mailrunning
    check_log2mailapache
    check_log2mailmysql
    check_log2mailsquid
    check_bindchroot
    check_network_interfaces
    check_autoif
    check_interfacesgw
    check_interfacesnetmask
    check_networking_service
    check_evobackup
    check_fail2ban_purge
    check_ssh_fail2ban_jail_renamed
    check_evobackup_exclude_mount
    check_userlogrotate
    check_apachectl
    check_apachesymlink
    check_apacheipinallow
    check_muninapacheconf
    check_phpmyadminapacheconf
    check_phppgadminapacheconf
    check_phpldapadminapacheconf
    check_kerneluptodate
    check_uptime
    check_muninrunning
    check_backupuptodate
    check_etcgit
    check_etcgit_lxc
    check_gitperms
    check_gitperms_lxc
    check_notupgraded
    check_tune2fs_m5
    check_evolinuxsudogroup
    check_userinadmgroup
    check_apache2evolinuxconf
    check_backportsconf
    check_bind9munin
    check_bind9logrotate
    check_drbd_two_primaries
    check_broadcomfirmware
    check_hardwareraidtool
    check_log2mailsystemdunit
    check_systemduserunit
    check_listupgrade
    check_mariadbevolinuxconf
    check_sql_backup
    check_postgres_backup
    check_mongo_backup
    check_ldap_backup
    check_redis_backup
    check_elastic_backup
    check_mariadbsystemdunit
    check_mysqlmunin
    check_mysqlnrpe
    check_phpevolinuxconf
    check_squidlogrotate
    check_squidevolinuxconf
    check_duplicate_fs_label
    check_evolix_user
    check_evolix_group
    check_evoacme_cron
    check_evoacme_livelinks
    check_apache_confenabled
    check_meltdown_spectre
    check_old_home_dir
    check_evobackup_incs
    check_osprober
    check_apt_valid_until
    check_chrooted_binary_uptodate
    check_nginx_letsencrypt_uptodate
    check_wkhtmltopdf
    check_lxc_wkhtmltopdf
    check_lxc_container_resolv_conf
    check_no_lxc_container
    check_lxc_php_fpm_service_umask_set
    check_lxc_php_bad_debian_version
    check_lxc_openssh
    check_lxc_opensmtpd
    check_versions
    check_monitoringctl
    check_nrpepressure
    check_postfix_ipv6_disabled
    check_smartmontools
}

#####################
# EXAMPLE
#####################

# If you want to create a new check funciton,
# you can copy check_example(), change variables and customize the tests
#
# Remember to add the new function to the list in "exec_checks()"

# shellcheck disable=SC2329
check_example() {
    local level default_exec cron future tags label doc rc
# level of the check, see --help for details
    level=2
# default_exec:
#   0 = runs only if enabled in configuration file
#   1 = runs unless disabled in configuration file
    default_exec=1
# cron:
#   0 = runs unless called with --cron
#   1 = always runs
    cron=0
# future:
#   0 = always runs
#   1 = runs only with --future
    future=0
# check label, used in the output. It should match the configuration variable
    label="IS_EXAMPLE"
# If you want to provide an extended documentation, add as many lines as you want between EODOC markers
# It will be printed when run with --verbose
    doc=$(cat <<EODOC
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
# Keep these 2 variables unchanged
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")

# You can have one or multiple conditions and failures (each with a different comment)
        if /bin/false; then
            fail --comment "this is the check short explanation, customize it" --level "${level}" --label "${label}" --tags "${tags}"
        fi

# Doc is shown if applicable :
# * the check has failed
# * there is something to display
# * evocheck is run in verbose mode)
        show_doc "${doc:-}"
    fi
}

#####################
# CHECK FUNCTIONS
#####################

check_lsbrelease() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=0
    future=0
    label="IS_LSBRELEASE"
    doc=$(cat <<EODOC
    /etc/lsb-release should be updated
    ~~~
    version=\$(cat /etc/debian_version)
    version=\$( echo \${version%.*} )
    sed 's/DISTRIB_RELEASE=.*/DISTRIB_RELEASE='"\${version}"'/' /etc/lsb-release > /etc/lsb-release.new
    cp /etc/lsb-release.new /etc/lsb-release
    rm /etc/lsb-release.new
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 13 lt; then
            lsb_release_bin=$(command -v lsb_release)
            if [ -x "${lsb_release_bin}" ]; then
                ## only the major version matters
                lhs=$(${lsb_release_bin} --release --short | cut -d "." -f 1)
                rhs=$(cut -d "." -f 1 < /etc/debian_version)
                if [ "$lhs" != "$rhs" ]; then
                    fail --comment "release is not consistent between lsb_release (${lhs}) and /etc/debian_version (${rhs})" --level "${level}" --label "${label}" --tags "${tags}"
                fi
            else
                fail --comment "lsb_release is missing or not executable"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi
        show_doc "${doc:-}"
    fi
}
check_dpkgwarning() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DPKGWARNING"
    doc=$(cat <<EODOC
    Fix by copying /etc/apt/apt.conf.d/z-evolinux.conf from another server.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        test -e /etc/apt/apt.conf.d/z-evolinux.conf \
            || fail --comment "/etc/apt/apt.conf.d/z-evolinux.conf is missing"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_postfix_mydestination() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_POSTFIX_MYDESTINATION"
    doc=$(cat <<EODOC
    Ensure that localhost, localhost.localdomain and localhost.\$mydomain
    are set in Postfix mydestination option.

    Fix with fix-postfix-mydestination.yml internal playbook.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # shellcheck disable=SC2016
        if ! grep mydestination /etc/postfix/main.cf | grep --quiet --extended-regexp 'localhost([[:blank:]]|$)'; then
            fail --comment "'localhost' is missing in Postfix mydestination option."  --level "${level}" --label "${label}" --tags "${tags}"
        fi
        if ! grep mydestination /etc/postfix/main.cf | grep --quiet --fixed-strings 'localhost.localdomain'; then
            fail --comment "'localhost.localdomain' is missing in Postfix mydestination option."  --level "${level}" --label "${label}" --tags "${tags}"
        fi
        if ! grep mydestination /etc/postfix/main.cf | grep --quiet --fixed-strings 'localhost.$mydomain'; then
            fail --comment "'localhost.\$mydomain' is missing in Postfix mydestination option."  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_nrpepostfix() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NRPEPOSTFIX"
    doc=$(cat <<EODOC
    check_mailq should be enabled in Nagios NRPE config file.
    Option "-M postfix" need to be set if the MTA is Postfix
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed postfix; then
            { test -e /etc/nagios/nrpe.cfg \
                && grep --quiet --recursive "^command.*check_mailq -M postfix" /etc/nagios/nrpe.*;
            } || fail --comment "NRPE \"check_mailq\" for postfix is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_customsudoers() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_CUSTOMSUDOERS"
    doc=$(cat <<EODOC
    Ensure that /etc/sudoers.d/evolinux starts with:
    ~~~
    Defaults        umask=0077
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep --extended-regexp --quiet --recursive "umask=0077" /etc/sudoers* || fail --comment "missing umask=0077 in sudoers file"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_vartmpfs() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_VARTMPFS"
    doc=$(cat <<EODOC
    If a dedicated partition exists, one can add IS_VARTMPFS=0 to /etc/evocheck.cf.

    Otherwise, fix with:
    ~~~~
    echo "tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev,size=1024m 0 0" >> /etc/fstab
    mount /var/tmp
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 13 lt; then
            findmnt_bin=$(command -v findmnt)
            if [ -x "${findmnt_bin}" ]; then
                ${findmnt_bin} /var/tmp --type tmpfs --noheadings > /dev/null || fail --comment "/var/tmp is not a tmpfs"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                df /var/tmp | grep --quiet tmpfs || fail --comment "/var/tmp is not a tmpfs"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_logrotateconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOGROTATECONF"
    doc=$(cat <<EODOC
    The logs tasks from the evolinux-base role should provide the relevant file.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        test -e /etc/logrotate.d/zsyslog || fail --comment "missing zsyslog in logrotate.d"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_syslogconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SYSLOGCONF"
    doc=$(cat <<EODOC
    Fix by copying /etc/rsyslog.conf from another server.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Test for modern servers
        if [ ! -f /etc/rsyslog.d/10-evolinux-default.conf ]; then
            # Fallback test for legacy servers
            if ! grep --quiet --ignore-case "Syslog for Pack Evolix" /etc/*syslog*/*.conf /etc/*syslog.conf; then
                fail --comment "Evolix syslog config is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_nonfree() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NONFREE"
    doc=$(cat <<EODOC
    If the non-free component is enabled, the contrib component should also
    be enabled, and the non-free-firmware component as well, for both system
    and security sources list.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList#components
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled "Debian-Security" sources from the "Debian" origin
        apt-cache policy | grep "\bl=Debian,\b" | grep "\bo=Debian\b" | grep --quiet "\bc=non-free\b"
        if [ $? -eq 0 ]; then
            apt-cache policy | grep "\bl=Debian,\b" | grep "\bo=Debian\b" | grep --quiet "\bc=contrib\b"
            test $? -eq 0 || fail --comment "missing contrib component for Debian repository"  --level "${level}" --label "${label}" --tags "${tags}"
	    # Debian-Security is rarely updated for contrib and non-free, so we can’t use such a check
	    # to verify if contrib and non-free are actually present in sources list files (we used to
	    # parse those file, but it was fragile compared to parsing the apt-cache policy output)
	    if ( evo::os-release::is_debian 12 ge ); then
                apt-cache policy | grep "\bl=Debian,\b" | grep "\bo=Debian\b" | grep --quiet "\bc=non-free-firmware\b"
                test $? -eq 0 || fail --comment "missing non-free-firmware component for Debian repository"  --level "${level}" --label "${label}" --tags "${tags}"
                apt-cache policy | grep "\bl=Debian-Security\b" | grep "\bo=Debian\b" | grep --quiet "\bc=non-free-firmware\b"
                test $? -eq 0 || fail --comment "missing non-free-firmware component for Debian-Security repository"  --level "${level}" --label "${label}" --tags "${tags}"
	    fi
	fi

        show_doc "${doc:-}"
    fi
}
check_debiansecurity() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DEBIANSECURITY"
    doc=$(cat <<EODOC
    Security source should be present for apt.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled "Debian-Security" sources from the "Debian" origin
        apt-cache policy | grep "\bl=Debian-Security\b" | grep "\bo=Debian\b" | grep --quiet "\bc=main\b"
        test $? -eq 0 || fail --comment "missing Debian-Security repository"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_debiansecurity_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DEBIANSECURITY_LXC"
    doc=$(cat <<EODOC
    Security source should be present for apt in LXC containers.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    if [ -f "${rootfs}/etc/debian_version" ]; then
                        debian_lxc_version=$(cut -d "." -f 1 < "${rootfs}/etc/debian_version")
                        if [ "${debian_lxc_version}" -ge 9 ]; then
                            lxc-attach --name "${container_name}" apt-cache policy | grep "\bl=Debian-Security\b" | grep "\bo=Debian\b" | grep --quiet "\bc=main\b"
                            test $? -eq 0 || fail --comment "missing Debian-Security repository in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                        fi
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_debiansecuritymirror() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DEBIANSECURITYMIRROR"
    doc=$(cat <<EODOC
    Security source for apt should use Evolix mirror.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled "Debian-Security" sources from mirror.evolix.org
        if evo::os-release::is_debian 11 ge; then
            apt-cache policy | grep -A1 "\bdebian-security\b" | grep --quiet "\bmirror.evolix.org\b"
            test $? -eq 0 || fail --comment "Evolix mirror should be used for Debian-Security" --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_debiansecuritymirror_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DEBIANSECURITYMIRROR_LXC"
    doc=$(cat <<EODOC
    Security source for apt should use Evolix mirror in LXC containers.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    if [ -f "${rootfs}/etc/debian_version" ]; then
                        debian_lxc_version=$(cut -d "." -f 1 < "${rootfs}/etc/debian_version")
                        if [ "${debian_lxc_version}" -ge 11 ]; then
                            lxc-attach --name "${container_name}" apt-cache policy | grep -A1 "\bl=Debian-Security\b" | grep --quiet "\bmirror.evolix.org\b"
                            test $? -eq 0 || fail --comment "Evolix mirror should be used for Debian-Security in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                        fi
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_backports_version() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BACKPORTS_VERSION"
    doc=$(cat <<EODOC
    Bacports sources use a wrong suite (should be <release>-backport).
    Cf. https://wiki.evolix.org/HowtoDebian/Backports
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local os_codename
        os_codename=$( evo::os-release::get_version_codename )

        # Look for enabled "Debian Backports" sources from the "Debian" origin
        apt-cache policy | grep "\bl=Debian Backports\b" | grep "\bo=Debian\b" | grep --quiet "\bc=main\b"
        test $? -eq 1 || ( \
            apt-cache policy | grep "\bl=Debian Backports\b" | grep --quiet "\bn=${os_codename}-backports\b" && \
            test $? -eq 0 || fail --comment "Debian Backports enabled for another release than ${os_codename}"  --level "${level}" --label "${label}" --tags "${tags}" )

        show_doc "${doc:-}"
    fi
}
check_oldpub() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_OLDPUB"
    doc=$(cat <<EODOC
    Evolix source for apt should use pub.evolix.org.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled pub.evolix.net sources (supersed by pub.evolix.org since Stretch)
        apt-cache policy | grep --quiet pub.evolix.net
        test $? -eq 1 || fail --comment "Old pub.evolix.net repository is still enabled"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_oldpub_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_OLDPUB_LXC"
    doc=$(cat <<EODOC
    Evolix source for apt should use pub.evolix.org in LXC containers.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled pub.evolix.net sources (supersed by pub.evolix.org since Buster as Sury safeguard)
        if is_installed lxc; then
            containers_list=$( lxc-ls -1 --active )
            for container_name in ${containers_list}; do
                apt_cache_bin=$(lxc-attach --name "${container_name}" -- bash -c "command -v apt-cache")
                if [ -x "${apt_cache_bin}" ]; then
                    lxc-attach --name "${container_name}" apt-cache policy | grep --quiet pub.evolix.net
                    test $? -eq 1 || fail --comment "Old pub.evolix.net repository is still enabled in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_newpub() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NEWPUB"
    doc=$(cat <<EODOC
    Evolix source for apt should enabled.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled pub.evolix.org sources
        apt-cache policy | grep "\bl=Evolix\b" | grep --quiet --invert-match php
        test $? -eq 0 || fail --comment "New pub.evolix.org repository is missing"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_serveurbase() {
    local level default_exec cron future tags label doc rc
    level=3
    default_exec=1
    cron=1
    future=0
    label="IS_SERVEURBASE"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    apt update
    apt install serveur-base
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        is_installed serveur-base || fail --comment "serveur-base package is not installed"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_sury() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SURY"
    doc=$(cat <<EODOC
    Evolix source for apt should enabled (the appropriate \$release-phpXY
    suite). Cf. https://wiki.evolix.org/HowtoPHP#php-avec-deb.sury.org
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Look for enabled packages.sury.org sources
        apt-cache policy | grep --quiet packages.sury.org
        if [ $? -eq 0 ]; then
            apt-cache policy | grep "\bl=Evolix\b" | grep --quiet php
            test $? -eq 0 || fail --comment "packages.sury.org is present but our safeguard pub.evolix.org repository is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_sury_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SURY_LXC"
    noc=$(cat <<EODOC
    Evolix source for apt should enabled (the appropriate \$release-phpXY
    suite) in LXC containers.
    Cf. https://wiki.evolix.org/HowtoPHP#php-avec-deb.sury.org
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            containers_list=$( lxc-ls -1 --active )
            for container_name in ${containers_list}; do
                apt_cache_bin=$(lxc-attach --name "${container_name}" -- bash -c "command -v apt-cache")
                if [ -x "${apt_cache_bin}" ]; then
                    lxc-attach --name "${container_name}" apt-cache policy | grep --quiet packages.sury.org
                    if [ $? -eq 0 ]; then
                        lxc-attach --name "${container_name}" apt-cache policy | grep "\bl=Evolix\b" | grep --quiet php
                        test $? -eq 0 || fail --comment "packages.sury.org is present but our safeguard pub.evolix.org repository is missing in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_not_deb822() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_NOT_DEB822"
    doc=$(cat <<EODOC
    sources.list should use deb822 format.
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            for source in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
                test -f "${source}" && grep --quiet '^deb' "${source}" && \
                    fail --comment "${source} contains a one-line style sources.list entry, and should be converted to deb822 format"  --level "${level}" --label "${label}" --tags "${tags}"
                done
        fi

        show_doc "${doc:-}"
    fi
}
check_no_signed_by() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_NO_SIGNED_BY"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    sed --in-place --follow-symlinks s/Source-by/Signed-By/ \
    /etc/apt/sources.list.d/*.sources
    ~~~
    Cf. https://wiki.evolix.org/HowtoDebian/SourcesList
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            for source in /etc/apt/sources.list.d/*.sources; do
                if [ -f "${source}" ]; then
                    ( grep --quiet '^Signed-by' "${source}" && \
                        fail --comment "${source} contains a Source-by entry that should be capitalized as Signed-By"  --level "${level}" --label "${label}" --tags "${tags}" ) || \
                    ( grep --quiet '^Signed-By' "${source}" || \
                        fail --comment "${source} has no Signed-By entry"  --level "${level}" --label "${label}" --tags "${tags}" )
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_aptitude() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APTITUDE"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    apt purge aptitude
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        test -e /usr/bin/aptitude && fail --comment "aptitude may not be installed on Debian >=8"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_aptgetbak() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APTGETBAK"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    dpkg-divert --remove --rename --divert /usr/bin/apt-get.bak /usr/bin/apt-get
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        test -e /usr/bin/apt-get.bak && fail --comment "prohibit the installation of apt-get.bak with dpkg-divert(1)"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_usrro() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_USRRO"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    vim /etc/fstab # add the ro directive to /usr
    mount -o remount,ro /usr
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep /usr /etc/fstab | grep --quiet --extended-regexp "\bro\b" || fail --comment "missing ro directive on fstab for /usr"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_tmpnoexec() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_TMPNOEXEC"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    vim /etc/fstab # add the noexec directive to /tmp
    mount -o remount,noexec /tmp
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        findmnt_bin=$(command -v findmnt)
        if [ -x "${findmnt_bin}" ]; then
            options=$(${findmnt_bin} --noheadings --first-only --output OPTIONS /tmp)
            echo "${options}" | grep --quiet --extended-regexp "\bnoexec\b" || fail --comment "/tmp is not mounted with 'noexec'"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            mount | grep "on /tmp" | grep --quiet --extended-regexp "\bnoexec\b" || fail --comment "/tmp is not mounted with 'noexec' (WARNING: findmnt(8) is not found)"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_homenoexec() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_HOMENOEXEC"
    doc=$(cat <<EODOC
    Try and find the reason for the discrepancy (was it forgotten to remount
    /home, or to update /etc/fastab?).

    Either remount /home with the proper (no)exec mode as documented in
    /etc/fstab, or edit /etc/fstab to use the proper (no)exec option for /home
    (so /home will be mounted with the proper (no)exec mode after a reboot).
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        findmnt_bin=$(command -v findmnt)
        if [ -x "${findmnt_bin}" ]; then
            options=$(${findmnt_bin} --noheadings --first-only --output OPTIONS /home)
            echo "${options}" | grep --quiet --extended-regexp "\bnoexec\b" || \
            ( grep --quiet --extended-regexp "/home.*noexec" /etc/fstab && \
            fail --comment "/home is mounted with 'exec' but /etc/fstab document it as 'noexec'"  --level "${level}" --label "${label}" --tags "${tags}" )
        else
            mount | grep "on /home" | grep --quiet --extended-regexp "\bnoexec\b" || \
            ( grep --quiet --extended-regexp "/home.*noexec" /etc/fstab && \
            fail --comment "/home is mounted with 'exec' but /etc/fstab document it as 'noexec' (WARNING: findmnt(8) is not found)"  --level "${level}" --label "${label}" --tags "${tags}" )
        fi

        show_doc "${doc:-}"
    fi
}
check_mountfstab() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MOUNT_FSTAB"
    doc=$(cat <<EODOC
    One should set the relevant partition in /etc/fstab (or unmount the temporary partition).
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Test if lsblk available, if not skip this test...
        lsblk_bin=$(command -v lsblk)
        if test -x "${lsblk_bin}"; then
            for mountPoint in $(${lsblk_bin} -o MOUNTPOINT -l -n | grep '/'); do
                grep --quiet --extended-regexp "${mountPoint}\W" /etc/fstab \
                    || fail --comment "partition(s) detected mounted but no presence in fstab"  --level "${level}" --label "${label}" --tags "${tags}"
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_listchangesconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LISTCHANGESCONF"
    doc=$(cat <<EODOC
    Fix with:
    ~~~
    apt purge apt-listchanges
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed apt-listchanges; then
            fail --comment "apt-listchanges must not be installed on Debian >=9"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_customcrontab() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_CUSTOMCRONTAB"
    doc=$(cat <<EODOC
    Ensure cron jobs run when the should. /etc/crontab should contain:

    ~~~
    SHELL=/bin/sh
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Example of job definition:
    # .---------------- minute (0 - 59)
    # |  .------------- hour (0 - 23)
    # |  |  .---------- day of month (1 - 31)
    # |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
    # |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
    # |  |  |  |  |
    # *  *  *  *  * user-name command to be executed
    16 *	* * *	root	cd / && run-parts --report /etc/cron.hourly
     8 1	* * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
    19 5	* * 7	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
    26 4	1 * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
    #
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        found_lines=$(grep --count --extended-regexp "^(17 \*|25 6|47 6|52 6)" /etc/crontab)
        test "$found_lines" = 4 && fail --comment "missing custom field in crontab"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_sshallowusers() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SSHALLOWUSERS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            if [ -d /etc/ssh/sshd_config.d/ ]; then
                # AllowUsers or AllowGroups should be in /etc/ssh/sshd_config.d/
                grep --extended-regexp --quiet --ignore-case --recursive "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config.d/ \
                    || fail --comment "missing AllowUsers or AllowGroups directive in sshd_config.d/*"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
            # AllowUsers or AllowGroups should not be in /etc/ssh/sshd_config
            grep --extended-regexp --quiet --ignore-case "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config \
                && fail --comment "AllowUsers or AllowGroups directive present in sshd_config"  --level "${level}" --label "${label}" --tags "${tags}"
            # AllowUsers or AllowGroups should not be in /etc/ssh/sshd_config.d/000-evolinux-migrated.conf
            if [ -f /etc/ssh/sshd_config.d/000-evolinux-migrated.conf ]; then
                grep --extended-regexp --quiet --ignore-case "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config.d/000-evolinux-migrated.conf \
                    && fail --comment "AllowUsers or AllowGroups directive present in sshd_config.d/000-evolinux-migrated.conf"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            # AllowUsers or AllowGroups should be in /etc/ssh/sshd_config or /etc/ssh/sshd_config.d/
            if [ -d /etc/ssh/sshd_config.d/ ]; then
                grep --extended-regexp --quiet --ignore-case --recursive "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ \
                    || fail --comment "missing AllowUsers or AllowGroups directive in sshd_config"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                grep --extended-regexp --quiet --ignore-case "(AllowUsers|AllowGroups)" /etc/ssh/sshd_config \
                    || fail --comment "missing AllowUsers or AllowGroups directive in sshd_config"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_sshconfsplit() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SSHCONFSPLIT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            ls /etc/ssh/sshd_config.d/* > /dev/null 2> /dev/null \
                || fail --comment "No files under /etc/ssh/sshd_config.d"  --level "${level}" --label "${label}" --tags "${tags}"
            diff /usr/share/openssh/sshd_config /etc/ssh/sshd_config > /dev/null 2> /dev/null \
                || fail --comment "Files /etc/ssh/sshd_config and /usr/share/openssh/sshd_config differ"  --level "${level}" --label "${label}" --tags "${tags}"
            for f in /etc/ssh/sshd_config.d/z-evolinux-defaults.conf /etc/ssh/sshd_config.d/zzz-evolinux-custom.conf; do
                test -f "${f}" || fail --comment "${f} is not a regular file"  --level "${level}" --label "${label}" --tags "${tags}"
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_sshlastmatch() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=0
    cron=1
    future=1
    label="IS_SSHLASTMATCH"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            for file in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/zzz-evolinux-custom.conf; do
                if ! test -f "${file}"; then
                    continue
                fi
                if ! awk 'BEGIN { last = "all" } tolower($1) == "match" { last = tolower($2) } END { if (last != "all") exit 1 }' "${file}"; then
                    fail --comment "last Match directive is not \"Match all\" in ${file}" --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_tmoutprofile() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_TMOUTPROFILE"
    doc=$(cat <<EODOC
    Ensure that the following directive is present in /etc/profile.

    ~~~
    export TMOUT=36000
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep --no-messages --quiet "TMOUT=" /etc/profile /etc/profile.d/evolinux.sh || fail --comment "TMOUT is not set"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_alert5boot() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ALERT5BOOT"
    doc=$(cat <<EODOC
    Ensure that /usr/share/scripts/alert5.sh script and
    /etc/systemd/system/alert5.service are present.

    Ensure that alert5 systemd unit is active.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep --quiet --no-messages "^date" /usr/share/scripts/alert5.sh || fail --comment "boot mail is not sent by alert5 init script"  --level "${level}" --label "${label}" --tags "${tags}"
        if [ -f /etc/systemd/system/alert5.service ]; then
            systemctl is-enabled alert5.service -q || fail --comment "alert5 unit is not enabled"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            fail --comment "alert5 unit file is missing" --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
is_minifirewall_native_systemd() {
    systemctl list-unit-files minifirewall.service | grep minifirewall.service | grep --quiet --invert-match generated
}
check_alert5minifw() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ALERT5MINIFW"
    doc=$(cat <<EODOC
    ~~~
    mount -o remount,rw /usr
    vim /usr/share/scripts/alert5.sh
    ~~~

    Add or uncomment the “/etc/init.d/minifirewall start” line.
    Remount /usr in read-only mode.

    ~~~
    mount -o remount,ro /usr
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if ! is_minifirewall_native_systemd; then
            grep --quiet --no-messages "^/etc/init.d/minifirewall" /usr/share/scripts/alert5.sh \
                || fail --comment "Minifirewall is not started by alert5 script or script is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_minifw() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MINIFW"
    doc=$(cat <<EODOC
    Minifirewall should be running.

    ~~~
    /etc/init.d/minifirewall restart
    ~~~

    Maybe Evolix IP is missing in TRUSTEDIPS directive.

    ~~~
    root@\$server:~## grep 31.170.8.4 /etc/default/ -R
    /etc/default/minifirewall:TRUSTEDIPS='31.170.8.4 ...
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        {
            if is_minifirewall_native_systemd; then
                systemctl is-active minifirewall.service >/dev/null 2>&1
            else
                if test -x /usr/share/scripts/minifirewall_status; then
                    /usr/share/scripts/minifirewall_status > /dev/null 2>&1
                else
                    /sbin/iptables -L -n 2> /dev/null | grep --quiet --extended-regexp "^(DROP\s+(udp|17)|ACCEPT\s+(icmp|1))\s+--\s+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0\s*$"
                fi
            fi
        } || fail --comment "minifirewall seems not started"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_minifw_includes() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MINIFWINCLUDES"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 11 ge; then
            if [ -f "/etc/default/minifirewall" ]; then
                if grep --quiet --extended-regexp --regexp '^\s*/sbin/iptables' --regexp '^\s*/sbin/ip6tables' "/etc/default/minifirewall"; then
                    fail --comment "minifirewall has direct iptables invocations in /etc/default/minifirewall that should go in /etc/minifirewall.d/"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_minifw_related() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_MINIFW_RELATED"
    doc=$(cat <<EODOC
    RELATED should be removed from iptables rules for security reasons.
    https://gist.github.com/azlux/6a70bd38bb7c525ab26efe7e3a7ea8ac
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -f "/etc/default/minifirewall" ] || [ -d "/etc/minifirewall.d/" ]; then
            if grep --no-messages --quiet --fixed-strings "RELATED" "/etc/default/minifirewall" "/etc/minifirewall.d/"*; then
                fail --comment "RELATED should not be used in minifirewall configuration"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_nrpeperms() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NRPEPERMS"
    doc=$(cat <<EODOC
    ~~~
    chmod 750 /etc/nagios
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -d /etc/nagios ]; then
            nagiosDir="/etc/nagios"
            actual=$(stat --format "%a" $nagiosDir)
            expected="750"
            test "$expected" = "$actual" || fail --comment "${nagiosDir} must be ${expected}"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_minifwperms() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MINIFWPERMS"
    doc=$(cat <<EODOC
    ~~~
    chmod 600 /etc/default/minifirewall
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -f "/etc/default/minifirewall" ]; then
            actual=$(stat --format "%a" "/etc/default/minifirewall")
            expected="600"
            test "$expected" = "$actual" || fail --comment "/etc/default/minifirewall must be ${expected}"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_nrpepid() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NRPEPID"
    doc=$(cat <<EODOC
    The configuration should contain the following.

    ~~~
    grep pid /etc/nagios/nrpe.cfg
    pid_file=/run/nagios/nrpe.pid
    ~~~

    If nagios fails to restart, check also the systemd service.

    ~~~
    systemctl cat nagios-nrpe-server.service | grep PIDFile
    PIDFile=/run/nagios/nrpe.pid
    ~~~

    If the path is still “/var/run/nagios/nrpe.pid”, then the
    nagios-nrpe-server package may be outdated.

    ~~~
    apt update
    apt upgrade nagios-nrpe-server
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 11 lt; then
            { test -e /etc/nagios/nrpe.cfg \
                && grep --quiet "^pid_file=/var/run/nagios/nrpe.pid" /etc/nagios/nrpe.cfg;
            } || fail --comment "missing or wrong pid_file directive in nrpe.cfg"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            { test -e /etc/nagios/nrpe.cfg \
                && grep --quiet "^pid_file=/run/nagios/nrpe.pid" /etc/nagios/nrpe.cfg;
            } || fail --comment "missing or wrong pid_file directive in nrpe.cfg"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_grsecprocs() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_GRSECPROCS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if uname -a | grep --quiet grsec; then
            { grep --quiet "^command.check_total_procs..sudo" /etc/nagios/nrpe.cfg \
                && grep --after-context=1 "^\[processes\]" /etc/munin/plugin-conf.d/munin-node | grep --quiet "^user root";
            } || fail --comment "missing munin's plugin processes directive for grsec"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_apachemunin() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APACHEMUNIN"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if test -e /etc/apache2/apache2.conf; then
            { test -h /etc/apache2/mods-enabled/status.load \
                && test -h /etc/munin/plugins/apache_accesses \
                && test -h /etc/munin/plugins/apache_processes \
                && test -h /etc/munin/plugins/apache_volume;
            } || fail --comment "missing munin plugins for Apache"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification mytop + Munin si MySQL
check_mysqlutils() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MYSQLUTILS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        MYSQL_ADMIN=${MYSQL_ADMIN:-mysqladmin}
        if is_installed mysql-server; then
            # With Debian 11 and later, root can connect to MariaDB with the socket
            if evo::os-release::is_debian 11 lt; then
                # You can configure MYSQL_ADMIN in evocheck.cf
                if ! grep --quiet --no-messages "^user *= *${MYSQL_ADMIN}" /root/.my.cnf; then
                    fail --comment "${MYSQL_ADMIN} missing in /root/.my.cnf"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
            if ! test -x /usr/bin/mytop; then
                if ! test -x /usr/local/bin/mytop; then
                    fail --comment "mytop binary missing"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
            if ! grep --quiet --no-messages '^user *=' /root/.mytop; then
                fail --comment "credentials missing in /root/.mytop"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de la configuration du raid soft (mdadm)
check_raidsoft() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_RAIDSOFT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if test -e /proc/mdstat && grep --quiet md /proc/mdstat; then
            { grep --quiet "^AUTOCHECK=true" /etc/default/mdadm \
                && grep --quiet "^START_DAEMON=true" /etc/default/mdadm \
                && grep --quiet --invert-match "^MAILADDR ___MAIL___" /etc/mdadm/mdadm.conf;
            } || fail --comment "missing or wrong config for mdadm"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification du LogFormat de AWStats
check_awstatslogformat() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_AWSTATSLOGFORMAT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed apache2 awstats; then
            awstatsFile="/etc/awstats/awstats.conf.local"
            grep --quiet --extended-regexp '^LogFormat=1' $awstatsFile \
                || fail --comment "missing or wrong LogFormat directive in $awstatsFile"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de la présence de la config logrotate pour Munin
check_muninlogrotate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MUNINLOGROTATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        { test -e /etc/logrotate.d/munin-node \
            && test -e /etc/logrotate.d/munin;
        } || fail --comment "missing lorotate file for munin"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
# Verification de l'activation de Squid dans le cas d'un pack mail
check_squid() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SQUID"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        squidconffile="/etc/squid/evolinux-custom.conf"
        if is_pack_web && (is_installed squid || is_installed squid3); then
            host=$(hostname -i)
            # shellcheck disable=SC2086
            http_port=$(grep --extended-regexp "^http_port\s+[0-9]+" $squidconffile | awk '{ print $2 }')
            { grep --quiet --extended-regexp "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT" "/etc/default/minifirewall" \
                && grep --quiet --extended-regexp "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -d $host -j ACCEPT" "/etc/default/minifirewall" \
                && grep --quiet --extended-regexp "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -d 127.0.0.(1|0/8) -j ACCEPT" "/etc/default/minifirewall" \
                && grep --quiet --extended-regexp "^[^#]*iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port.* $http_port" "/etc/default/minifirewall";
            } || grep --quiet --extended-regexp "^PROXY='?on'?" "/etc/default/minifirewall" \
            || fail --comment "missing squid rules in minifirewall"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_evomaintenance_fw() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOMAINTENANCE_FW"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -f "/etc/default/minifirewall" ]; then
            hook_db=$(grep --extended-regexp '^\s*HOOK_DB' /etc/evomaintenance.cf | tr -d ' ' | cut -d= -f2)
            rulesNumber=$(grep --count --extended-regexp "/sbin/iptables -A INPUT -p tcp --sport 5432 --dport 1024:65535 -s .* -m state --state ESTABLISHED(,RELATED)? -j ACCEPT" "/etc/default/minifirewall")
            if [ "$hook_db" = "1" ] && [ "$rulesNumber" -lt 2 ]; then
                fail --comment "HOOK_DB is enabled but missing evomaintenance rules in minifirewall"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de la conf et de l'activation de mod-deflate
check_moddeflate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MODDEFLATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        f=/etc/apache2/mods-enabled/deflate.conf
        if is_installed apache2.2; then
            { test -e $f && grep --quiet "AddOutputFilterByType DEFLATE text/html text/plain text/xml" $f \
                && grep --quiet "AddOutputFilterByType DEFLATE text/css" $f \
                && grep --quiet "AddOutputFilterByType DEFLATE application/x-javascript application/javascript" $f;
            } || fail --comment "missing AddOutputFilterByType directive for apache mod deflate"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de la conf log2mail
check_log2mailrunning() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOG2MAILRUNNING"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_pack_web && is_installed log2mail; then
            pgrep log2mail >/dev/null || fail --comment "log2mail is not running"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_log2mailapache() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOG2MAILAPACHE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        conf=/etc/log2mail/config/apache
        if is_pack_web && is_installed log2mail; then
            grep --no-messages --quiet "^file = /var/log/apache2/error.log" $conf \
                || fail --comment "missing log2mail directive for apache"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_log2mailmysql() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOG2MAILMYSQL"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_pack_web && is_installed log2mail; then
            grep --no-messages --quiet "^file = /var/log/syslog" /etc/log2mail/config/{default,mysql,mysql.conf} \
                || fail --comment "missing log2mail directive for mysql"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_log2mailsquid() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOG2MAILSQUID"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_pack_web && is_installed log2mail; then
            grep --no-messages --quiet "^file = /var/log/squid.*/access.log" /etc/log2mail/config/* \
                || fail --comment "missing log2mail directive for squid"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification si bind est chroote
check_bindchroot() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BINDCHROOT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed bind9; then
            if netstat -utpln | grep "/named" | grep :53 | grep --quiet --invert-match --extended-regexp "(127.0.0.1|::1)"; then
                default_conf=/etc/default/named
                if evo::os-release::is_debian 10; then
                    default_conf=/etc/default/bind9
                fi
                if grep --quiet '^OPTIONS=".*-t' "${default_conf}" && grep --quiet '^OPTIONS=".*-u' "${default_conf}"; then
                    md5_original=$(md5sum /usr/sbin/named | cut -f 1 -d ' ')
                    md5_chrooted=$(md5sum /var/chroot-bind/usr/sbin/named | cut -f 1 -d ' ')
                    if [ "$md5_original" != "$md5_chrooted" ]; then
                        fail --comment "the chrooted bind binary is different than the original binary"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                else
                    fail --comment "bind process is not chrooted"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# /etc/network/interfaces should be present, we don't manage systemd-network yet
check_network_interfaces() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NETWORK_INTERFACES"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if ! test -f /etc/network/interfaces; then
            fail --comment "systemd network configuration is not supported yet"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verify if all if are in auto
check_autoif() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_AUTOIF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if test -f /etc/network/interfaces; then
            interfaces=$(/sbin/ip address show up | grep "^[0-9]*:" | grep --extended-regexp --invert-match "(lo|vnet|docker|veth|tun|tap|macvtap|vrrp|lxcbr|wg)" | cut -d " " -f 2 | tr -d : | cut -d@ -f1 | tr "\n" " ")
            for interface in $interfaces; do
                if grep --quiet --dereference-recursive "^iface $interface" /etc/network/interfaces* && ! grep --quiet --dereference-recursive "^auto $interface" /etc/network/interfaces*; then
                    fail --comment "Network interface \`${interface}' is statically defined but not set to auto"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
# Network conf verification
check_interfacesgw() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_INTERFACESGW"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if test -f /etc/network/interfaces; then
            number=$(grep --extended-regexp --count "^[^#]*gateway [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" /etc/network/interfaces)
            test "$number" -gt 1 && fail --comment "there is more than 1 IPv4 gateway"  --level "${level}" --label "${label}" --tags "${tags}"
            number=$(grep --extended-regexp --count "^[^#]*gateway [0-9a-fA-F]+:" /etc/network/interfaces)
            test "$number" -gt 1 && fail --comment "there is more than 1 IPv6 gateway"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_interfacesnetmask() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_INTERFACESNETMASK"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if test -f /etc/network/interfaces; then
            addresses_number=$(grep "address" /etc/network/interfaces | grep -cv -e "hwaddress" -e "#")
            symbol_netmask_number=$(grep address /etc/network/interfaces | grep -v "#" | grep -c "/")
            text_netmask_number=$(grep "netmask" /etc/network/interfaces | grep -cv -e "#" -e "route add" -e "route del")
            if [ "$((symbol_netmask_number + text_netmask_number))" -ne "$addresses_number" ]; then
                fail --comment "the number of addresses configured is not equal to the number of netmask configured : one netmask is missing or duplicated"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de l’état du service networking
check_networking_service() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=0
    future=0
    label="IS_NETWORKING_SERVICE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if systemctl is-enabled networking.service > /dev/null; then
            if ! systemctl is-active networking.service > /dev/null; then
                fail --comment "networking.service is not active"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Verification de la mise en place d'evobackup
check_evobackup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOBACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local evobackup_found
        evobackup_found=$(find /etc/cron* -name '*evobackup*' | wc -l)
        test "$evobackup_found" -gt 0 || fail --comment "missing evobackup cron"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
# Vérification de la mise en place d'un cron de purge de la base SQLite de Fail2ban
check_fail2ban_purge() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_FAIL2BAN_PURGE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Nécessaire seulement en Debian 9 ou 10
        if evo::os-release::is_debian 11 lt; then
        if is_installed fail2ban; then
            test -f /etc/cron.daily/fail2ban_dbpurge || fail --comment "missing script fail2ban_dbpurge cron"  --level "${level}" --label "${label}" --tags "${tags}"
        fi
        fi

        show_doc "${doc:-}"
    fi
}
# Vérification qu'il ne reste pas des jails nommées ssh non renommées en sshd
check_ssh_fail2ban_jail_renamed() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SSH_FAIL2BAN_JAIL_RENAMED"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed fail2ban && [ -f /etc/fail2ban/jail.local ]; then
            if grep --quiet --fixed-strings "[ssh]" /etc/fail2ban/jail.local; then
                fail --comment "Jail ssh must be renamed sshd in fail2ban >= 0.9."  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Vérification de l'exclusion des montages (NFS) dans les sauvegardes
check_evobackup_exclude_mount() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOBACKUP_EXCLUDE_MOUNT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        excludes_file=$(mktemp --tmpdir "evocheck.evobackup_exclude_mount.XXXXX")
        files_to_cleanup+=("${excludes_file}")

        # shellcheck disable=SC2044
        for evobackup_file in $(find /etc/cron* -name '*evobackup*' | grep --invert-match --extended-regexp ".disabled$"); do
            # if the file seems to be a backup script, with an Rsync invocation
            if grep --quiet "^\s*rsync" "${evobackup_file}"; then
                # If rsync is not limited by "one-file-system"
                # then we verify that every mount is excluded
                if ! grep --quiet -- "^\s*--one-file-system" "${evobackup_file}"; then
                    local not_excluded
                    # old releases of evobackups don't have version
                    if grep --quiet  "^VERSION=" "${evobackup_file}" && dpkg --compare-versions "$(sed -E -n 's/VERSION="(.*)"/\1/p' "${evobackup_file}")" ge 22.12 ; then
                    sed -En '/RSYNC_EXCLUDES="/,/"/ {s/(RSYNC_EXCLUDES=|")//g;p}' "${evobackup_file}" > "${excludes_file}"
                    else
                    grep -- "--exclude " "${evobackup_file}" | grep --extended-regexp --only-matching "\"[^\"]+\"" | tr -d '"' > "${excludes_file}"
                    fi
                    not_excluded=$(findmnt --type nfs,nfs4,fuse.sshfs, -o target --noheadings | grep --invert-match --file="${excludes_file}")
                    for mount in ${not_excluded}; do
                        fail --comment "${mount} is not excluded from ${evobackup_file} backup script"  --level "${level}" --label "${label}" --tags "${tags}"
                    done
                fi
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_userlogrotate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_USERLOGROTATE"
    doc=$(cat <<EODOC
    The /etc/cron.weekly/userlogrotate script may be missing to compress
    /home/$USER/log/{php.log,access.log,error.log} log files.

    Ensure that these are not symlink to a path already under logrotate.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_pack_web; then
            test -x /etc/cron.weekly/userlogrotate || fail --comment "missing userlogrotate cron"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_apachectl() {
    local level default_exec cron future tags label doc rc
    level=4
    default_exec=1
    cron=1
    future=0
    label="IS_APACHECTL"
    doc=$(cat <<EODOC
    apache2ctl -t failed.

    Apache configuration must be fixed, otherwise it won’t be able to restart.
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed apache2; then
            /usr/sbin/apache2ctl configtest 2>&1 | grep --quiet "^Syntax OK$" \
                || fail --comment "apache errors detected, run a configtest"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_apachesymlink() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APACHESYMLINK"
    doc=$(cat <<EODOC
    Some regular files have been detected in /etc/apache2/sites-enabled.

    They should be moved to /etc/apache2/sites-available, enabled (with
    “a2ensite <vhost>”), and then Apache conf should be reloaded (with
    “systemctl reload apache2”).
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed apache2; then
            local apacheFind nbApacheFind
            apacheFind=$(find /etc/apache2/sites-enabled ! -type l -type f -print)
            nbApacheFind=$(wc -m <<< "${apacheFind}")
            if [[ ${nbApacheFind} -gt 1 ]]; then
                while read -r line; do
                    fail --comment "Not a symlink: ${line}"  --level "${level}" --label "${label}" --tags "${tags}"
                done <<< "${apacheFind}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Check if there is real IP addresses in Allow/Deny directives (no trailing space, inline comments or so).
check_apacheipinallow() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APACHEIPINALLOW"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Note: Replace "exit 1" by "print" in Perl code to debug it.
        if is_installed apache2; then
            grep -I --recursive --extended-regexp "^[^#] *(Allow|Deny) from" /etc/apache2/ \
                | grep --ignore-case --invert-match "from all" \
                | grep --ignore-case --invert-match "env=" \
                | perl -ne 'exit 1 unless (/from( [\da-f:.\/]+)+$/i)' \
                || fail --comment "bad (Allow|Deny) directives in apache"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if default Apache configuration file for munin is absent (or empty or commented).
check_muninapacheconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MUNINAPACHECONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local muninconf
        muninconf="/etc/apache2/conf-available/munin.conf"
        if is_installed apache2; then
            test -e ${muninconf} && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${muninconf}" \
                && fail --comment "default munin configuration may be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if default Apache configuration file for phpMyAdmin is absent (or empty or commented).
check_phpmyadminapacheconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_PHPMYADMINAPACHECONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local phpmyadminconf0 phpmyadminconf1
        phpmyadminconf0="/etc/apache2/conf-available/phpmyadmin.conf"
        phpmyadminconf1="/etc/apache2/conf-enabled/phpmyadmin.conf"
        if is_installed apache2; then
            test -e "${phpmyadminconf0}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phpmyadminconf0}" \
                && fail --comment "default phpmyadmin configuration (${phpmyadminconf0}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
            test -e "${phpmyadminconf1}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phpmyadminconf1}" \
                && fail --comment "default phpmyadmin configuration (${phpmyadminconf1}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if default Apache configuration file for phpPgAdmin is absent (or empty or commented).
check_phppgadminapacheconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_PHPPGADMINAPACHECONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local phppgadminconf0 phppgadminconf1
        phppgadminconf0="/etc/apache2/conf-available/phppgadmin.conf"
        phppgadminconf1="/etc/apache2/conf-enabled/phppgadmin.conf"
        if is_installed apache2; then
            test -e "${phppgadminconf0}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phppgadminconf0}" \
                && fail --comment "default phppgadmin configuration (${phppgadminconf0}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
            test -e "${phppgadminconf1}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phppgadminconf1}" \
                && fail --comment "default phppgadmin configuration (${phppgadminconf1}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if default Apache configuration file for phpMyAdmin is absent (or empty or commented).
check_phpldapadminapacheconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_PHPLDAPADMINAPACHECONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        local phpldapadminconf0 phpldapadminconf1
        phpldapadminconf0="/etc/apache2/conf-available/phpldapadmin.conf"
        phpldapadminconf1="/etc/apache2/conf-enabled/phpldapadmin.conf"
        if is_installed apache2; then
            test -e "${phpldapadminconf0}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phpldapadminconf0}" \
                && fail --comment "default phpldapadmin configuration (${phpldapadminconf0}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
            test -e "${phpldapadminconf1}" && grep --quiet --invert-match --extended-regexp "^( |\t)*#" "${phpldapadminconf1}" \
                && fail --comment "default phpldapadmin configuration (${phpldapadminconf1}) should be commented or disabled"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Verification si le système doit redémarrer suite màj kernel.
check_kerneluptodate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=0
    future=0
    label="IS_KERNELUPTODATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed linux-image*; then
            local kernel_installed_at last_reboot_at
            # shellcheck disable=SC2012
            kernel_installed_at=$(date -d "$(ls --full-time -lcrt /boot/*lin* | tail -n1 | awk '{print $6}')" +%s)
            last_reboot_at=$(($(date +%s) - $(cut -f1 -d '.' /proc/uptime)))
            if [ "${kernel_installed_at}" -gt "${last_reboot_at}" ]; then
                fail --comment "machine is running an outdated kernel, reboot advised"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Check if the server is running for more than a year.
check_uptime() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=0
    future=0
    label="IS_UPTIME"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed linux-image*; then
            local limit last_reboot_at
            limit=$(date -d "now - 2 year" +%s)
            last_reboot_at=$(($(date +%s) - $(cut -f1 -d '.' /proc/uptime)))
            if [ "${limit}" -gt "${last_reboot_at}" ]; then
                fail --comment "machine has an uptime of more than 2 years, reboot on new kernel advised"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Check if munin-node running and RRD files are up to date.
check_muninrunning() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MUNINRUNNING"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if ! pgrep munin-node >/dev/null; then
            fail --comment "Munin is not running"  --level "${level}" --label "${label}" --tags "${tags}"
        elif [ -d "/var/lib/munin/" ] && [ -d "/var/cache/munin/" ]; then
            limit=$(date +"%s" -d "now - 10 minutes")

            if [ -n "$(find /var/lib/munin/ -name '*load-g.rrd')" ]; then
                updated_at=$(stat -c "%Y" /var/lib/munin/*/*load-g.rrd |sort |tail -1)
                [ "$limit" -gt "$updated_at" ] && fail --comment "Munin load RRD has not been updated in the last 10 minutes"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                fail --comment "Munin is not installed properly (load RRD not found)"  --level "${level}" --label "${label}" --tags "${tags}"
            fi

            if [ -n "$(find  /var/cache/munin/www/ -name 'load-day.png')" ]; then
                updated_at=$(stat -c "%Y" /var/cache/munin/www/*/*/load-day.png |sort |tail -1)
                grep --no-messages --quiet "^graph_strategy cron" /etc/munin/munin.conf && [ "$limit" -gt "$updated_at" ] && fail --comment "Munin load PNG has not been updated in the last 10 minutes"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                fail --comment "Munin is not installed properly (load PNG not found)"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            fail --comment "Munin is not installed properly (main directories are missing)"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if files in /home/backup/ are up-to-date
check_backupuptodate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BACKUPUPTODATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        backup_dir="/home/backup"
        if [ -d "${backup_dir}" ]; then
            if [ -n "$(ls -A ${backup_dir})" ]; then
                find "${backup_dir}" -maxdepth 1 -type f | while read -r file; do
                    limit=$(date +"%s" -d "now - 2 day")
                    updated_at=$(stat -c "%Y" "$file")

                    if [ "$limit" -gt "$updated_at" ]; then
                        fail --comment "$file has not been backed up"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done
            else
                fail --comment "${backup_dir}/ is empty"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            fail --comment "${backup_dir}/ is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_etcgit() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ETCGIT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        export GIT_DIR="/etc/.git" GIT_WORK_TREE="/etc"
        git rev-parse --is-inside-work-tree > /dev/null 2>&1 \
            || fail --comment "/etc is not a git repository"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_etcgit_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ETCGIT_LXC"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    export GIT_DIR="${rootfs}/etc/.git"
                    export GIT_WORK_TREE="${rootfs}/etc"
                    git rev-parse --is-inside-work-tree > /dev/null 2>&1 \
                        || fail --comment "/etc is not a git repository in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
# Check if /etc/.git/ has read/write permissions for root only.
check_gitperms() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_GITPERMS"
    doc=$(cat <<EODOC
    Git repositories must have "700" permissions.

    Fix with:
    ~~~
    chmod 700 /path/to/repository/.git
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        for git_dir in "/etc/.git" "/etc/bind.git" "/usr/share/scripts/.git"; do
            if [ -d "${git_dir}" ]; then
                expected="700"
                actual=$(stat -c "%a" $git_dir)
                if [ "${expected}" != "${actual}" ]; then
                    rc=1
                    fail --comment "${git_dir} must be ${expected}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_gitperms_lxc() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_GITPERMS_LXC"
    doc=$(cat <<EODOC
    Git repositories must have "700" permissions.

    Fix with:
    ~~~
    chmod 700 /path/to/repository/.git
    ~~~
EODOC
)

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    git_dir="${rootfs}/etc/.git"
                    if test -d "${git_dir}"; then
                        expected="700"
                        actual=$(stat -c "%a" "${git_dir}")
                        if [ "${expected}" != "${actual}" ]; then
                            fail --comment "$git_dir must be $expected (in container ${container_name})"  --level "${level}" --label "${label}" --tags "${tags}"
                        fi
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
# Check if no package has been upgraded since $limit.
check_notupgraded() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NOTUPGRADED"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
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
            last_upgrade=$(date +%s -d "$(zgrep --no-filename --no-messages upgrade /var/log/dpkg.log* | sort -n | tail -1 | cut -f1 -d ' ')")
        fi
        if grep --quiet --no-messages '^mailto="listupgrade-todo@' /etc/evolinux/listupgrade.cnf \
            || grep --quiet --no-messages --extended-regexp '^[[:digit:]]+[[:space:]]+[[:digit:]]+[[:space:]]+[^\*]' /etc/cron.d/listupgrade; then
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
            [ "$install_date" -lt "$limit" ] && fail --comment "The system has never been updated"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            [ "$last_upgrade" -lt "$limit" ] && fail --comment "The system hasn't been updated for too long"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
# Check if reserved blocks for root is at least 5% on every mounted partitions.
check_tune2fs_m5() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_TUNE2FS_M5"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        min=5
        parts=$(grep --extended-regexp "ext(3|4)" /proc/mounts | cut -d ' ' -f1 | tr -s '\n' ' ')
        findmnt_bin=$(command -v findmnt)
        for part in $parts; do
            blockCount=$(dumpe2fs -h "$part" 2>/dev/null | grep --regexp "Block count:" | grep --extended-regexp --only-matching "[0-9]+")
            # If buggy partition, skip it.
            if [ -z "$blockCount" ]; then
                continue
            fi
            reservedBlockCount=$(dumpe2fs -h "$part" 2>/dev/null | grep --regexp "Reserved block count:" | grep --extended-regexp --only-matching "[0-9]+")
            # Use awk to have a rounded percentage
            # python is slow, bash is unable and bc rounds weirdly
            percentage=$(awk "BEGIN { pc=100*${reservedBlockCount}/${blockCount}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

            if [ "$percentage" -lt "${min}" ]; then
                if [ -x "${findmnt_bin}" ]; then
                    mount=$(${findmnt_bin} --noheadings --first-only --output TARGET "${part}")
                else
                    mount="unknown mount point"
                fi
                fail --comment "Partition ${part} (${mount}) has less than ${min}% reserved blocks (${percentage}%)"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_evolinuxsudogroup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOLINUXSUDOGROUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if grep --quiet "^evolinux-sudo:" /etc/group; then
            if [ -f /etc/sudoers.d/evolinux ]; then
                grep --quiet --extended-regexp '^%evolinux-sudo +ALL ?= ?\(ALL:ALL\)( EXEC:)? ALL' /etc/sudoers.d/evolinux \
                    || fail --comment "missing evolinux-sudo directive in sudoers file"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_userinadmgroup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_USERINADMGROUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        users=$(grep "^evolinux-sudo:" /etc/group | awk -F: '{print $4}' | tr ',' ' ')
        for user in $users; do
            if ! groups "$user" | grep --quiet adm; then
                fail --comment "User $user doesn't belong to \`adm' group"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_apache2evolinuxconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APACHE2EVOLINUXCONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed apache2; then
            { test -L /etc/apache2/conf-enabled/z-evolinux-defaults.conf \
                && test -L /etc/apache2/conf-enabled/zzz-evolinux-custom.conf \
                && test -f /etc/apache2/ipaddr_whitelist.conf;
            } || fail --comment "missing custom evolinux apache config"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_backportsconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BACKPORTSCONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep --quiet --no-messages --extended-regexp "^[^#].*backports" /etc/apt/sources.list \
            && fail --comment "backports can't be in main sources list"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_bind9munin() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BIND9MUNIN"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed bind9; then
            { test -L /etc/munin/plugins/bind9 \
                && test -e /etc/munin/plugin-conf.d/bind9;
            } || fail --comment "missing bind plugin for munin"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_bind9logrotate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BIND9LOGROTATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed bind9; then
            test -e /etc/logrotate.d/bind9 || fail --comment "missing bind logrotate file"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_drbd_two_primaries() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DRBDTWOPRIMARIES"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed drbd-utils; then
            if command -v drbd-overview >/dev/null; then
                if drbd-overview 2>&1 | grep --quiet "Primary/Primary"; then
                    fail --comment "Some DRBD ressources have two primaries, you risk a split brain!"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            elif command -v drbdadm >/dev/null; then
                if drbdadm role all 2>&1 | grep --quiet 'Primary/Primary'; then
                    fail --comment "Some DRBD ressources have two primaries, you risk a split brain!"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_broadcomfirmware() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_BROADCOMFIRMWARE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        lspci_bin=$(command -v lspci)
        if [ -x "${lspci_bin}" ]; then
            if ${lspci_bin} | grep --quiet 'NetXtreme II'; then
                { is_installed firmware-bnx2 \
                    && apt-cache policy | grep "\bl=Debian\b" | grep --quiet -v "\b,c=non-free\b"
                } || fail --comment "missing non-free repository"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            fail --comment "lspci not found in ${PATH}"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_hardwareraidtool() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_HARDWARERAIDTOOL"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        lspci_bin=$(command -v lspci)
        if [ -x "${lspci_bin}" ]; then
            if ${lspci_bin} | grep --quiet 'MegaRAID'; then
                if ! { command -v perccli || command -v perccli2; } >/dev/null  ; then
                    # shellcheck disable=SC2015
                    is_installed megacli && { is_installed megaclisas-status || is_installed megaraidsas-status; } \
                        || fail --comment "Mega tools not found"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
            if ${lspci_bin} | grep --quiet 'Hewlett-Packard Company Smart Array'; then
                is_installed cciss-vol-status || fail --comment "cciss-vol-status not installed"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            fail --comment "lspci not found in ${PATH}"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_log2mailsystemdunit() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LOG2MAILSYSTEMDUNIT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        systemctl -q is-active log2mail.service \
            || fail --comment "log2mail unit not running"  --level "${level}" --label "${label}" --tags "${tags}"
        test -f /etc/systemd/system/log2mail.service \
            || fail --comment "missing log2mail unit file"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_systemduserunit() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_SYSTEMDUSERUNIT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        awk 'BEGIN { FS = ":" } { print $1, $6 }' /etc/passwd | while read -r user dir; do
            if ls "${dir}"/.config/systemd/user/*.service > /dev/null 2> /dev/null; then
                fail --comment "systemd unit found for user ${user}"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_listupgrade() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LISTUPGRADE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        test -f /etc/cron.d/listupgrade \
            || fail --comment "missing listupgrade cron"  --level "${level}" --label "${label}" --tags "${tags}"
        test -x /usr/local/sbin/listupgrade.sh || test -x /usr/share/scripts/listupgrade.sh \
            || fail --comment "missing listupgrade script or not executable"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_mariadbevolinuxconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_MARIADBEVOLINUXCONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed mariadb-server; then
            { test -f /etc/mysql/mariadb.conf.d/z-evolinux-defaults.cnf \
                && test -f /etc/mysql/mariadb.conf.d/zzz-evolinux-custom.cnf;
            } || fail --comment "missing mariadb custom config"  --level "${level}" --label "${label}" --tags "${tags}"
            fi

        show_doc "${doc:-}"
    fi
}
check_sql_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SQL_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if (is_installed "mysql-server" || is_installed "mariadb-server"); then
            backup_dir="/home/backup"
            if [ -d "${backup_dir}" ]; then
                # You could change the default path in /etc/evocheck.cf
                SQL_BACKUP_PATH="${SQL_BACKUP_PATH:-$(find -H "${backup_dir}" \( -iname "mysql.bak.gz" -o -iname "mysql.sql.gz" -o -iname "mysqldump.sql.gz" \))}"
                if [ -z "${SQL_BACKUP_PATH}" ]; then
                    fail --comment "No MySQL dump found"  --level "${level}" --label "${label}" --tags "${tags}"
                    return 1
                fi
                for backup_path in ${SQL_BACKUP_PATH}; do
                    if [ ! -f "${backup_path}" ]; then
                        fail --comment "MySQL dump is missing (${backup_path})"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done
            else
                fail --comment "${backup_dir}/ is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_postgres_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_POSTGRES_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed "postgresql-9*" || is_installed "postgresql-1*"; then
            backup_dir="/home/backup"
            if [ -d "${backup_dir}" ]; then
                # If you use something like barman, you should disable this check
                # You could change the default path in /etc/evocheck.cf
                POSTGRES_BACKUP_PATH="${POSTGRES_BACKUP_PATH:-$(find -H "${backup_dir}" -iname "pg.dump.bak*")}"
                for backup_path in ${POSTGRES_BACKUP_PATH}; do
                    if [ ! -f "${backup_path}" ]; then
                        fail --comment "PostgreSQL dump is missing (${backup_path})"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done
            else
                fail --comment "${backup_dir}/ is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_mongo_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MONGO_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed "mongodb-org-server"; then
            backup_dir="/home/backup"
            if [ -d "${backup_dir}" ]; then
                # You could change the default path in /etc/evocheck.cf
                MONGO_BACKUP_PATH=${MONGO_BACKUP_PATH:-"${backup_dir}/mongodump"}
                if [ -d "$MONGO_BACKUP_PATH" ]; then
                    for file in "${MONGO_BACKUP_PATH}"/*/*.{json,bson}*; do
                        # Skip indexes file.
                        if ! [[ "$file" =~ indexes ]]; then
                            limit=$(date +"%s" -d "now - 2 day")
                            updated_at=$(stat -c "%Y" "$file")
                            if [ -f "$file" ] && [ "$limit" -gt "$updated_at"  ]; then
                                fail --comment "MongoDB hasn't been dumped for more than 2 days"  --level "${level}" --label "${label}" --tags "${tags}"
                                break
                            fi
                        fi
                    done
                else
                    fail --comment "MongoDB dump directory is missing (${MONGO_BACKUP_PATH})"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            else
                fail --comment "${backup_dir}/ is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_ldap_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LDAP_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed slapd; then
            backup_dir="/home/backup"
            if [ -d "${backup_dir}" ]; then
                # You could change the default path in /etc/evocheck.cf
                LDAP_BACKUP_PATH="${LDAP_BACKUP_PATH:-$(find -H "${backup_dir}" -iname "ldap.bak")}"
                if ! test -f "$LDAP_BACKUP_PATH"; then
                    # In newer versions of zzz_evobackup client, dumps have been split in 3 files /home/backup/ldap/{ldap-config,ldap-data}.bak
                    # Let's check for ldap/ldap-data.bak
                    LDAP_BACKUP_PATH="${backup_dir}/ldap/ldap-data.bak"
                    if ! test -f "$LDAP_BACKUP_PATH"; then
                        fail --comment "LDAP dump is missing (${LDAP_BACKUP_PATH})"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            else
                fail "${level}" "${label}"  "${backup_dir}/ is missing"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_redis_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_REDIS_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed redis-server; then
            backup_dir="/home/backup"
                if [ -d "${backup_dir}" ]; then
                # You could change the default path in /etc/evocheck.cf
                # REDIS_BACKUP_PATH may contain space-separated paths, for example:
                # REDIS_BACKUP_PATH='/home/backup/redis-instance1/dump.rdb /home/backup/redis-instance2/dump.rdb'
                # Warning : this script doesn't handle spaces in file paths !

                REDIS_BACKUP_PATH="${REDIS_BACKUP_PATH:-$(find -H "${backup_dir}" -iname "*.rdb*")}"

                # Check number of dumps
                n_instances=$(pgrep 'redis-server' | wc -l)
                n_dumps=$(echo $REDIS_BACKUP_PATH | wc -w)
                if [ ${n_dumps} -lt ${n_instances} ]; then
                    fail --comment "Missing Redis dump : ${n_instances} instance(s) found versus ${n_dumps} dump(s) found."  --level "${level}" --label "${label}" --tags "${tags}"
                fi

                # Check last dump date
                age_threshold=$(date +"%s" -d "now - 2 days")
                for dump in ${REDIS_BACKUP_PATH}; do
                    last_update=$(stat -c "%Z" $dump)
                    if [ "${last_update}" -lt "${age_threshold}" ]; then
                        fail --comment "Redis dump ${dump} is older than 2 days."  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done
            else
                fail --comment "${backup_dir}/ is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_elastic_backup() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ELASTIC_BACKUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed elasticsearch; then
            # You could change the default path in /etc/evocheck.cf
            ELASTIC_BACKUP_PATH=${ELASTIC_BACKUP_PATH:-"/home/backup-elasticsearch"}
            test -d "$ELASTIC_BACKUP_PATH" || fail --comment "Elastic snapshot is missing (${ELASTIC_BACKUP_PATH})"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_mariadbsystemdunit() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MARIADBSYSTEMDUNIT"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # TODO: check if it is still needed for bullseye
        if evo::os-release::is_debian 11 lt; then
            if is_installed mariadb-server; then
                if systemctl -q is-active mariadb.service; then
                    test -f /etc/systemd/system/mariadb.service.d/evolinux.conf \
                        || fail --comment "missing systemd override for mariadb unit"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_mysqlmunin() {
    local level default_exec cron future tags label doc rc
    level=3
    default_exec=1
    cron=0
    future=1
    label="IS_MYSQLMUNIN"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed mariadb-server; then
            for file in mysql_bytes mysql_queries mysql_slowqueries \
                mysql_threads mysql_connections mysql_files_tables \
                mysql_innodb_bpool mysql_innodb_bpool_act mysql_innodb_io \
                mysql_innodb_log mysql_innodb_rows mysql_innodb_semaphores \
                mysql_myisam_indexes mysql_qcache mysql_qcache_mem \
                mysql_sorts mysql_tmp_tables; do

                if [[ ! -L /etc/munin/plugins/${file} ]]; then
                    fail --comment "missing munin plugin '${file}'"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
            munin-run mysql_commands 2> /dev/null > /dev/null
            test $? -eq 0 || fail --comment "Munin plugin 'mysql_commands' returned an error"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_mysqlnrpe() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MYSQLNRPE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed mariadb-server; then
            nagios_file=~nagios/.my.cnf
            if ! test -f ${nagios_file}; then
                fail --comment "${nagios_file} is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            elif [ "$(stat -c %U ${nagios_file})" != "nagios" ] \
                || [ "$(stat -c %a ${nagios_file})" != "600" ]; then
                fail --comment "${nagios_file} has wrong permissions"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                grep --quiet --extended-regexp "command\[check_mysql\]=.*/usr/lib/nagios/plugins/check_mysql" /etc/nagios/nrpe.d/evolix.cfg \
                || fail --comment "check_mysql is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_phpevolinuxconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_PHPEVOLINUXCONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        evo::os-release::is_debian 10 && phpVersion="7.3"
        evo::os-release::is_debian 11 && phpVersion="7.4"
        evo::os-release::is_debian 12 && phpVersion="8.2"
        evo::os-release::is_debian 13 && phpVersion="8.4"

        if is_installed php; then
            { test -f "/etc/php/${phpVersion}/cli/conf.d/z-evolinux-defaults.ini" \
                && test -f "/etc/php/${phpVersion}/cli/conf.d/zzz-evolinux-custom.ini"
            } || fail --comment "missing php evolinux config"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_squidlogrotate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SQUIDLOGROTATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed squid; then
            grep --quiet --regexp monthly --regexp daily /etc/logrotate.d/squid \
                || fail --comment "missing squid logrotate file"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_squidevolinuxconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SQUIDEVOLINUXCONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed squid; then
            { grep --quiet --no-messages "^CONFIG=/etc/squid/evolinux-defaults.conf$" /etc/default/squid \
                && test -f /etc/squid/evolinux-defaults.conf \
                && test -f /etc/squid/evolinux-whitelist-defaults.conf \
                && test -f /etc/squid/evolinux-whitelist-custom.conf \
                && test -f /etc/squid/evolinux-acl.conf \
                && test -f /etc/squid/evolinux-httpaccess.conf \
                && test -f /etc/squid/evolinux-custom.conf;
            } || fail --comment "missing squid evolinux config"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_duplicate_fs_label() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_DUPLICATE_FS_LABEL"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Do it only if thereis blkid binary
        blkid_bin=$(command -v blkid)
        if [ -n "$blkid_bin" ]; then
            tmpFile=$(mktemp --tmpdir "evocheck.duplicate_fs_label.XXXXX")
            files_to_cleanup+=("${tmpFile}")

            parts=$($blkid_bin -c /dev/null | grep --invert-match --regexp raid_member --regexp EFI_SYSPART --regexp zfs_member --regexp '/dev/zd*' | grep --extended-regexp --only-matching ' LABEL=".*"' | cut -d'"' -f2)
            for part in $parts; do
                echo "$part" >> "$tmpFile"
            done
            tmpOutput=$(sort < "$tmpFile" | uniq -d)
            # If there is no duplicate, uniq will have no output
            # So, if $tmpOutput is not null, there is a duplicate
            if [ -n "$tmpOutput" ]; then
                # shellcheck disable=SC2086
                labels=$(echo -n $tmpOutput | tr '\n' ' ')
                fail --comment "Duplicate labels: $labels"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        else
            fail --comment "blkid not found in ${PATH}"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_evolix_user() {
    local level default_exec cron future tags label doc rc
    level=4
    default_exec=1
    cron=1
    future=0
    label="IS_EVOLIX_USER"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        grep --quiet --extended-regexp "^evolix:" /etc/passwd \
            && fail --comment "evolix user should be deleted, used only for install"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_evolix_group() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_EVOLIX_GROUP"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        users=$(grep ":20..:20..:" /etc/passwd | cut -d ":" -f 1)
        for user in ${users}; do
            grep --extended-regexp "^evolix:" /etc/group | grep --quiet --extended-regexp "\b${user}\b" \
                || fail --comment "user \`${user}' should be in \`evolix' group"  --level "${level}" --label "${label}" --tags "${tags}"
        done

        show_doc "${doc:-}"
    fi
}
check_evoacme_cron() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOACME_CRON"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -f "/usr/local/sbin/evoacme" ]; then
            # Old cron file, should be deleted
            test -f /etc/cron.daily/certbot && fail --comment "certbot cron is incompatible with evoacme"  --level "${level}" --label "${label}" --tags "${tags}"
            # evoacme cron file should be present
            test -f /etc/cron.daily/evoacme || fail --comment "evoacme cron is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_evoacme_livelinks() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOACME_LIVELINKS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        evoacme_bin=$(command -v evoacme)
        if [ -x "$evoacme_bin" ]; then
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
                        fail --comment "Certificate \`$certName' hasn't been updated"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_apache_confenabled() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APACHE_CONFENABLED"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # Starting from Jessie and Apache 2.4, /etc/apache2/conf.d/
        # must be replaced by conf-available/ and config files symlinked
        # to conf-enabled/
        if [ -f /etc/apache2/apache2.conf ]; then
            test -d /etc/apache2/conf.d/ \
                && fail --comment "apache's conf.d directory must not exists"  --level "${level}" --label "${label}" --tags "${tags}"
            grep --quiet 'Include conf.d' /etc/apache2/apache2.conf \
                && fail --comment "apache2.conf must not Include conf.d"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_meltdown_spectre() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=0
    future=0
    label="IS_MELTDOWN_SPECTRE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # /sys/devices/system/cpu/vulnerabilities/
        for vuln in meltdown spectre_v1 spectre_v2; do
            test -f "/sys/devices/system/cpu/vulnerabilities/$vuln" \
                || fail --comment "vulnerable to $vuln"  --level "${level}" --label "${label}" --tags "${tags}"
        done

        show_doc "${doc:-}"
    fi
}
check_old_home_dir() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_OLD_HOME_DIR"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        homeDir=${homeDir:-/home}
        for dir in "$homeDir"/*; do
            statResult=$(stat -c "%n has owner %u resolved as %U" "$dir" \
                | grep --invert-match --extended-regexp --regexp '.bak' --regexp '\.[0-9]{2}-[0-9]{2}-[0-9]{4}' \
                | grep "UNKNOWN")
            # There is at least one dir matching
            if [[ -n "${statResult}" ]]; then
                fail --comment "${statResult}"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_tmp_1777() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_TMP_1777"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        expected="1777"

        actual=$(stat --format "%a" /tmp)
        test "${expected}" = "${actual}" || fail --comment "/tmp must be ${expected}"  --level "${level}" --label "${label}" --tags "${tags}"

        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    if [ -d "${rootfs}/tmp" ]; then
                        actual=$(stat --format "%a" "${rootfs}/tmp")
                        test "${expected}" = "${actual}" || fail --comment "${rootfs}/tmp must be ${expected}"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_root_0700() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_ROOT_0700"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        actual=$(stat --format "%a" /root)
        expected="700"
        test "$expected" = "$actual" || fail --comment "/root must be $expected"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_usrsharescripts() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_USRSHARESCRIPTS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        actual=$(stat --format "%a" /usr/share/scripts)
        expected="700"
        test "$expected" = "$actual" || fail --comment "/usr/share/scripts must be $expected"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_sshpermitrootno() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_SSHPERMITROOTNO"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # You could change the SSH port in /etc/evocheck.cf
        sshd_args="-C addr=,user=,host=,laddr=,lport=${SSH_PORT:-22}"
        if evo::os-release::is_debian 10; then
            sshd_args="${sshd_args},rdomain="
        fi
        # shellcheck disable=SC2086
        if ! (sshd -T ${sshd_args} 2> /dev/null | grep --quiet --ignore-case 'permitrootlogin no'); then
            fail --comment "PermitRootLogin should be set to no"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_evomaintenanceusers() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOMAINTENANCEUSERS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        users=$(getent group evolinux-sudo | cut -d':' -f4 | tr ',' ' ')
        for user in $users; do
            user_home=$(getent passwd "$user" | cut -d: -f6)
            if [ -n "$user_home" ] && [ -d "$user_home" ]; then
                if ! grep --quiet --no-messages --extended-regexp "^[^#]*trap.*sudo.*evomaintenance.sh" "${user_home}"/.*profile; then
                    fail --comment "${user} doesn't have an evomaintenance trap"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_evomaintenanceconf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOMAINTENANCECONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        f=/etc/evomaintenance.cf
        if [ -e "$f" ]; then
            perms=$(stat -c "%a" $f)
            test "$perms" = "600" || fail --comment "Wrong permissions on \`$f' ($perms instead of 600)"  --level "${level}" --label "${label}" --tags "${tags}"

            { grep "^FROM" $f | grep --quiet --invert-match "jdoe@example.com" \
                && grep "^FULLFROM" $f | grep --quiet --invert-match "John Doe <jdoe@example.com>" \
                && grep "^URGENCYFROM" $f | grep --quiet --invert-match "mama.doe@example.com" \
                && grep "^URGENCYTEL" $f | grep --quiet --invert-match "06.00.00.00.00" \
                && grep "^REALM" $f | grep --quiet --invert-match "example.com"
            } || fail --comment "evomaintenance is not correctly configured"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            fail --comment "Configuration file \`$f' is missing"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_privatekeyworldreadable() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_PRIVKEYWOLRDREADABLE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # a simple globbing fails if directory is empty
        if [ -n "$(ls -A /etc/ssl/private/)" ]; then
            for f in /etc/ssl/private/*; do
                perms=$(stat -L -c "%a" "$f")
                if [ "${perms: -1}" != 0 ]; then
                    fail --comment "$f is world-readable"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_evobackup_incs() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_EVOBACKUP_INCS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed bkctld; then
            bkctld_cron_file=${bkctld_cron_file:-/etc/cron.d/bkctld}
            if [ -f "${bkctld_cron_file}" ]; then
                root_crontab=$(grep -v "^#" "${bkctld_cron_file}")
                echo "${root_crontab}" | grep --quiet "bkctld inc" || fail --comment "'bkctld inc' is missing in ${bkctld_cron_file}"  --level "${level}" --label "${label}" --tags "${tags}"
                echo "${root_crontab}" | grep --quiet --extended-regexp "(check-incs.sh|bkctld check-incs)" || fail --comment "'check-incs.sh' is missing in ${bkctld_cron_file}"  --level "${level}" --label "${label}" --tags "${tags}"
            else
                fail --comment "Crontab \`${bkctld_cron_file}' is missing"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_osprober() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_OSPROBER"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed os-prober qemu-kvm; then
            fail "${level}" "${label}" \
                "Removal of os-prober package is recommended as it can cause serious issue on KVM server"
        fi

        show_doc "${doc:-}"
    fi
}
check_apt_valid_until() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_APT_VALID_UNTIL"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        aptvalidFile="/etc/apt/apt.conf.d/99no-check-valid-until"
        aptvalidText="Acquire::Check-Valid-Until no;"
        if grep --quiet --no-messages "archive.debian.org" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            if ! grep --quiet --no-messages "$aptvalidText" /etc/apt/apt.conf.d/*; then
                fail "${level}" "${label}" \
                    "As you use archive.mirror.org you need ${aptvalidFile}: ${aptvalidText}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_chrooted_binary_uptodate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_CHROOTED_BINARY_UPTODATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        # list of processes to check
        process_list="sshd"
        for process_name in ${process_list}; do
            # what is the binary path?
            original_bin=$(command -v "${process_name}")
            for pid in $(pgrep "${process_name}"); do
                process_bin=$(realpath "/proc/${pid}/exe")
                # Is the process chrooted?
                real_root=$(realpath "/proc/${pid}/root")
                if [ "${real_root}" != "/" ]; then
                    chrooted_md5=$(md5sum "${process_bin}" | cut -f 1 -d ' ')
                    original_md5=$(md5sum "${original_bin}" | cut -f 1 -d ' ')
                    # compare md5 checksums
                    if [ "$original_md5" != "$chrooted_md5" ]; then
                        fail --comment "${process_bin} (${pid}) is different than ${original_bin}."  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            done
        done

        show_doc "${doc:-}"
    fi
}
check_nginx_letsencrypt_uptodate() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NGINX_LETSENCRYPT_UPTODATE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if [ -d /etc/nginx ]; then
            snippets=$(find /etc/nginx -type f -name "letsencrypt.conf")
            if [ -n "${snippets}" ]; then
                while read -r snippet; do
                    if grep --quiet --extended-regexp "^\s*alias\s+/.+/\.well-known/acme-challenge" "${snippet}"; then
                        fail --comment "Nginx snippet ${snippet} is not compatible with Nginx on Debian 9+."  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                done <<< "${snippets}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_wkhtmltopdf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_WKHTMLTOPDF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        is_installed wkhtmltopdf && fail --comment "wkhtmltopdf package should not be installed (cf. https://wiki.evolix.org/HowtoWkhtmltopdf)"  --level "${level}" --label "${label}" --tags "${tags}"

        show_doc "${doc:-}"
    fi
}
check_lxc_wkhtmltopdf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_WKHTMLTOPDF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    test -e "${rootfs}/usr/bin/wkhtmltopdf" && fail --comment "wkhtmltopdf should not be installed in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_lxc_container_resolv_conf() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_CONTAINER_RESOLV_CONF"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            current_resolvers=$(grep ^nameserver /etc/resolv.conf | sed 's/nameserver//g' )
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    if [ -f "${rootfs}/etc/resolv.conf" ]; then

                        while read -r resolver; do
                            if ! grep --quiet --extended-regexp "^nameserver\s+${resolver}" "${rootfs}/etc/resolv.conf"; then
                                fail --comment "resolv.conf miss-match beween host and container : missing nameserver ${resolver} in container ${container_name} resolv.conf"  --level "${level}" --label "${label}" --tags "${tags}"
                            fi
                        done <<< "${current_resolvers}"

                    else
                        fail --comment "resolv.conf missing in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
# Check that there are containers if lxc is installed.
check_no_lxc_container() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_NO_LXC_CONTAINER"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            containers_count=$(lxc-ls -1 --active | wc -l)
            if [ "${containers_count}" -eq 0 ]; then
                fail --comment "LXC is installed but have no active container. Consider removing it."  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Check that in LXC containers, phpXX-fpm services have UMask set to 0007.
check_lxc_php_fpm_service_umask_set() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_PHP_FPM_SERVICE_UMASK_SET"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            containers_list=$(lxc-ls -1 --active --filter php)
            missing_umask=""
            for container_name in ${containers_list}; do
                # Translate container name in service name
                if [ "${container_name}" = "php56" ]; then
                    service="php5-fpm"
                else
                    service="${container_name:0:4}.${container_name:4:1}-fpm"
                fi
                umask=$(lxc-attach --name "${container_name}" -- systemctl show -p UMask "$service" | cut -d "=" -f2)
                if [ "$umask" != "0007" ]; then
                    missing_umask="${missing_umask} ${container_name}"
                fi
            done
            if [ -n "${missing_umask}" ]; then
                fail --comment "UMask is not set to 0007 in PHP-FPM services of theses containers : ${missing_umask}."  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
# Check that LXC containers have the proper Debian version.
check_lxc_php_bad_debian_version() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_PHP_BAD_DEBIAN_VERSION"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active --filter php)
            missing_umask=""
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    if [ "$container_name" = "php56" ]; then
                        grep --quiet 'VERSION_ID="8"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Jessie"  --level "${level}" --label "${label}" --tags "${tags}"
                    elif [ "$container_name" = "php70" ]; then
                        grep --quiet 'VERSION_ID="9"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Stretch"  --level "${level}" --label "${label}" --tags "${tags}"
                    elif [ "$container_name" = "php73" ]; then
                        grep --quiet 'VERSION_ID="10"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Buster"  --level "${level}" --label "${label}" --tags "${tags}"
                    elif [ "$container_name" = "php74" ]; then
                        grep --quiet 'VERSION_ID="11"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Bullseye"  --level "${level}" --label "${label}" --tags "${tags}"
                    elif [ "$container_name" = "php82" ]; then
                        grep --quiet 'VERSION_ID="12"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Bookworm"  --level "${level}" --label "${label}" --tags "${tags}"
                    elif [ "$container_name" = "php84" ]; then
                        grep --quiet 'VERSION_ID="13"' "${rootfs}/etc/os-release" || fail --comment "Container ${container_name} should use Trixie"  --level "${level}" --label "${label}" --tags "${tags}"
                    fi
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_lxc_openssh() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_OPENSSH"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    test -e "${rootfs}/usr/sbin/sshd" && fail --comment "openssh-server should not be installed in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_lxc_opensmtpd() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_LXC_OPENSMTPD"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if is_installed lxc; then
            lxc_path=$(lxc-config lxc.lxcpath)
            containers_list=$(lxc-ls -1 --active --filter php)
            for container_name in ${containers_list}; do
                if lxc-info --name "${container_name}" > /dev/null; then
                    rootfs="${lxc_path}/${container_name}/rootfs"
                    test -e "${rootfs}/usr/sbin/smtpd" || test -e "${rootfs}/usr/sbin/ssmtp" || fail --comment "opensmtpd should be installed in container ${container_name}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            done
        fi

        show_doc "${doc:-}"
    fi
}
check_monitoringctl() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=0
    label="IS_MONITORINGCTL"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if ! /usr/local/bin/monitoringctl list >/dev/null 2>&1; then
            fail --comment "monitoringctl is not installed or has a problem (use 'monitoringctl list' to reproduce)."  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
check_smartmontools() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_SMARTMONTOOLS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if ( LC_ALL=C lscpu | grep "Hypervisor vendor:" | grep -q -e VMware -e KVM || lscpu | grep -q Oracle ); then
            is_installed smartmontools && fail --comment "smartmontools should not be installed on a VM"  --level "${level}" --label "${label}" --tags "${tags}"
        else
            is_installed smartmontools || fail --comment "smartmontools should be installed on barematal"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}
download_versions() {
    local file
    file=${1:-}

    local os_codename
    os_codename=$( evo::os-release::get_version_codename )

    ## The file is supposed to list programs : each on a line, then its latest version number
    ## Examples:
    # evoacme 21.06
    # evomaintenance 0.6.4

    versions_url="https://upgrades.evolix.org/versions-${os_codename}"

    # fetch timeout, in seconds
    timeout=10

    if command -v curl > /dev/null; then
        curl --max-time ${timeout} --fail --silent --output "${versions_file}" "${versions_url}"
    elif command -v wget > /dev/null; then
        wget --timeout=${timeout} --quiet "${versions_url}" -O "${versions_file}"
    elif command -v GET; then
        GET -t ${timeout}s "${versions_url}" > "${versions_file}"
    else
        >&2 echo "fail to find curl, wget or GET"
        return 1
    fi
}
get_command() {
    local program
    program=${1:-}

    case "${program}" in
        ## Special cases where the program name is different than the command name
        evocheck) echo "${0}" ;;
        evomaintenance) command -v "evomaintenance.sh" ;;
        listupgrade) command -v "evolistupgrade.sh" ;;
        old-kernel-autoremoval) command -v "old-kernel-autoremoval.sh" ;;
        mysql-queries-killer) command -v "mysql-queries-killer.sh" ;;
        minifirewall)
            if [ -f "/usr/local/sbin/minifirewall" ]; then
                echo "/usr/local/sbin/minifirewall"
            elif [ -f "/etc/init.d/minifirewall" ]; then
                echo "/etc/init.d/minifirewall"
            fi
            ;;

        ## General case, where the program name is the same as the command name
        *) command -v "${program}" ;;
    esac
}
get_version() {
    local program command
    program=${1:-}
    command=${2:-}

    case "${program}" in
        ## Special case if `command --version => 'command` is not the standard way to get the version
        # my_command)
        #    /path/to/my_command --get-version
        #    ;;

        add-vm)
            grep '^VERSION=' "${command}" | head -1 | cut -d '=' -f 2
            ;;
        minifirewall)
            if [ -n "${command}" ]; then
                result=$(${command} version)
                rc=$?
                if [ ${rc} -eq 0 ]; then
                    echo "${result}" | head -1 | cut -d ' ' -f 3
                else
                    return 2
                fi
            fi
            ;;
        ## Let's try the --version flag before falling back to grep for the constant
        kvmstats)
            result=$(${command} --version 2> /dev/null)
            rc=$?
            if [ ${rc} -eq 0 ]; then
                echo "${result}" | head -1 | cut -d ' ' -f 3
            else
                grep '^VERSION=' "${command}" | head -1 | cut -d '=' -f 2
            fi
            ;;

        ## General case to get the version
        *)
            result=$(${command} --version 2> /dev/null)
            rc=$?
            if [ ${rc} -eq 0 ]; then
                echo "${result}" | head -1 | cut -d ' ' -f 3
            else
                return 2
            fi
            ;;
    esac
}

add_to_path() {
    local new_path
    new_path=${1:-}

    echo "$PATH" | grep --quiet --fixed-strings "${new_path}" || export PATH="${PATH}:${new_path}"
}
check_versions() {
    local level default_exec cron future tags label doc rc
    level=1
    default_exec=1
    cron=0
    future=0
    label="IS_CHECK_VERSIONS"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        versions_file=$(mktemp --tmpdir "evocheck.versions.XXXXX")
        files_to_cleanup+=("${versions_file}")

        download_versions "${versions_file}"
        test "$?" -eq 0 || fail --comment "${program} version ${actual_version} is newer than expected version ${expected_version}, you should update your index."  --level "${level}" --label "${label}" --tags "${tags}"

        add_to_path "/usr/share/scripts"

        grep --invert-match '^ *#' < "${versions_file}" | while IFS= read -r line; do
            local program
            local expected_version
            program=$(echo "${line}" | cut -d ' ' -f 1)
            expected_version=$(echo "${line}" | cut -d ' ' -f 2)

            if [ -n "${program}" ]; then
                if [ -n "${expected_version}" ]; then
                    command=$(get_command "${program}")
                    if [ -n "${command}" ]; then
                        # shellcheck disable=SC2086
                        actual_version=$(get_version "${program}" "${command}")
                        # printf "program:%s expected:%s actual:%s\n" "${program}" "${expected_version}" "${actual_version}"
                        if [ -z "${actual_version}" ]; then
                            fail --comment "fail to lookup actual version of ${program}"  --level "${level}" --label "${label}" --tags "${tags}"
                        elif dpkg --compare-versions "${actual_version}" lt "${expected_version}"; then
                            fail --comment "${program} version ${actual_version} is older than expected version ${expected_version}"  --level "${level}" --label "${label}" --tags "${tags}"
                        elif dpkg --compare-versions "${actual_version}" gt "${expected_version}"; then
                            fail --comment "${program} version ${actual_version} is newer than expected version ${expected_version}, you should update your index."  --level "${level}" --label "${label}" --tags "${tags}"
                        else
                            : # Version check OK
                        fi
                    fi
                else
                    fail --comment "fail to lookup expected version for ${program}"  --level "${level}" --label "${label}" --tags "${tags}"
                fi
            fi
        done

        show_doc "${doc:-}"
    fi
}
check_nrpepressure() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_NRPEPRESSURE"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        if evo::os-release::is_debian 12 ge; then
            /usr/local/bin/monitoringctl status pressure_cpu > /dev/null 2>&1
            rc="$?"
            if [ "${rc}" -ne 0 ]; then
                fail --comment "pressure_cpu check not defined or monitoringctl not correctly installed"  --level "${level}" --label "${label}" --tags "${tags}"
            fi
        fi

        show_doc "${doc:-}"
    fi
}
check_postfix_ipv6_disabled() {
    local level default_exec cron future tags label doc rc
    level=2
    default_exec=1
    cron=1
    future=1
    label="IS_POSTFIX_IPV6_DISABLED"
#     doc=$(cat <<EODOC
# EODOC
# )

    if check_can_run --label "${label}" --level "${level}" --default-exec "${default_exec}" --cron "${cron}" --future "${future}"; then
        rc=0
        tags=$(format_tags --cron "${cron}" --future "${future}")
        postconf -n 2>/dev/null | grep --no-messages --extended-regex '^inet_protocols\>' | grep --no-messages --invert-match --fixed-strings ipv6 | grep --no-messages --invert-match --fixed-strings all | grep --no-messages --silent --fixed-strings ipv4
        rc="$?"
        if [ "${rc}" -ne 0 ]; then
            fail --comment "IPv6 must be disabled in Postfix main.cf (inet_protocols = ipv4)"  --level "${level}" --label "${label}" --tags "${tags}"
        fi

        show_doc "${doc:-}"
    fi
}

### MAIN

is_quiet() {
    test "${QUIET}" = 1
}
is_verbose() {
    test "${VERBOSE}" = 1
}
is_pack_web() {
    test -e /usr/share/scripts/web-add.sh || test -e /usr/share/scripts/evoadmin/web-add.sh
}
is_installed() {
    for pkg in "$@"; do
        dpkg -l "$pkg" 2> /dev/null | grep --quiet --extended-regexp '^(i|h)i' || return 1
    done
}

format_tags() {
    local tags all_options
    all_options=$*
    tags=""
    # Parse options
    # based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case $1 in
            --cron)
                    shift
                    case $1 in
                        0) ;;
                        1) tags="${tags} #CRON" ;;
                        *)
                            printf 'ERROR: invalid value for --cron option: %s (%s)\n' "$1" "${all_options}" >&2
                            exit 1
                            ;;
                    esac
                ;;
            --future)
                    shift
                    case $1 in
                        0) ;;
                        1) tags="${tags} #FUTURE" ;;
                        *)
                            printf 'ERROR: invalid value for --future option: %s (%s)\n' "$1" "${all_options}" >&2
                            exit 1
                            ;;
                    esac
                ;;

            -?*|[[:alnum:]]*)
                # ignore unknown options
                if ! is_quiet; then
                    printf 'WARN: Unknown option (ignored): %s (%s)\n' "$1" "${all_options}" >&2
                fi
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    echo "${tags}"
}

# logging

log() {
    local date msg
    date=$(/bin/date +"${DATE_FORMAT}")
    msg="${1:-$(cat /dev/stdin)}"

    printf "[%s] %s: %s\\n" "${date}" "${PROGNAME}" "${msg}" >> "${LOGFILE}"
}

fail() {
    local level label comment tags all_options
    all_options=$*
    rc=1
    while :; do
        case $1 in
            --level)
                shift
                case $1 in
                    1) level="${1}-OPTIONAL" ;;
                    2) level="${1}-STANDARD" ;;
                    3) level="${1}-IMPORTANT" ;;
                    4) level="${1}-MANDATORY" ;;
                    *)
                        printf 'ERROR: invalid value for level option: %s (%s)\n' "$1" "${all_options}"
                        exit 1
                        ;;
                esac
                ;;
            --label)
                shift
                label=$1
                ;;
            --comment)
                shift
                comment=$1
                ;;
            --tags)
                shift
                tags=$1
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                if ! is_quiet; then
                    printf 'WARN: Unknown option (ignored): %s (%s)\n' "$1" "${all_options}" >&2
                fi
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    GLOBAL_RC=1

    if ! is_quiet; then
        printf "[%s] %s FAILED! %s%s\n" "${level}" "${label}" "${comment}" "${tags:-}" >> "${main_output_file}"
    fi
    printf "[%s] %s FAILED! %s%s" "${level}" "${label}" "${comment}" "${tags:-}" | log
}
check_can_run() {
    local default_exec label level cron future tags all_options
    all_options=$*
    # Parse options
    # based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case $1 in
            --default-exec)
                    shift
                    case $1 in
                        0|1) default_exec=$1 ;;
                        *)
                            printf 'ERROR: invalid value for --default-exec option: %s (%s)\n' "$1" "${all_options}" >&2
                            exit 1
                            ;;
                    esac
                ;;
            --label)
                    shift
                    label=$1
                ;;
            --level)
                    shift
                    level=$1
                ;;
            --cron)
                    shift
                    case $1 in
                        0|1) cron=$1 ;;
                        *)
                            printf 'ERROR: invalid value for --cron option: %s (%s)\n' "$1" "${all_options}" >&2
                            exit 1
                            ;;
                    esac
                ;;
            --future)
                    shift
                    case $1 in
                        0|1) future=$1 ;;
                        *)
                            printf 'ERROR: invalid value for --future option: %s (%s)\n' "$1" "${all_options}" >&2
                            exit 1
                            ;;
                    esac
                ;;

            -?*|[[:alnum:]]*)
                # ignore unknown options
                if ! is_quiet; then
                    printf 'WARN: Unknown option for check_can_run (ignored): %s (%s)\n' "$1" "${all_options}" >&2
                fi
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -n "${default_exec}" ] && [  -n "${label}" ] && [ "${!label:=${default_exec}}" != "1" ]; then
        # echo "SKIP ${label}"
        return 1
    elif [ ${level} -ge ${MIN_LEVEL} ] && [ ${level} -le ${MAX_LEVEL} ] \
        && [ ${future} -le ${FUTURE} ] \
        && [ ${cron} -ge ${CRON} ]; then
        # echo "RUN ${label}"
        return 0
    else
        # echo "SKIP ${label}"
        return 1
    fi

}
show_doc() {
    local doc=$1
    # WARN: rc is read from the parent function's context
    # where it is defined as local, so it should not leak outside of it.
    # This is not perfect, but passing it as argument seems more cumbersome
    if is_verbose && test "${rc}" != 0 && [ -n "${doc}" ]; then
        printf "%s\n" "${doc}" >> "${main_output_file}"
    fi
}
is_check_enabled() {
    test "${1}" = 1
}

# shellcheck disable=SC2329
cleanup() {
    # Cleanup tmp files
    # shellcheck disable=SC2068,SC2317
    rm -f ${files_to_cleanup[@]}

    log "End of ${PROGNAME} execution."
}

PROGNAME=$(basename "$0")
# shellcheck disable=SC2034
readonly PROGNAME

# shellcheck disable=SC2124
ARGS=$@
readonly ARGS

LOGFILE="/var/log/evocheck.log"
readonly LOGFILE

CONFIGFILE="/etc/evocheck.cf"
readonly CONFIGFILE

DATE_FORMAT="%Y-%m-%d %H:%M:%S"
# shellcheck disable=SC2034
readonly DATEFORMAT

# Disable LANG*
export LANG=C
export LANGUAGE=C

CRON=0
FUTURE=0
MIN_LEVEL=0
MAX_LEVEL=9

# Source configuration file
# shellcheck disable=SC1091
test -f "${CONFIGFILE}" && . "${CONFIGFILE}"

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
            CRON=1
            ;;
        --future)
            FUTURE=1
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;
        -q|--quiet)
            QUIET=1
            VERBOSE=0
            ;;
        --min-level)
                shift
                case $1 in
                    [0-9])
                        MIN_LEVEL=$1
                        ;;
                    *)
                        printf 'ERROR: invalid value for --min-level option: %s\n' "$1" >&2
                        exit 1
                        ;;
                esac
            ;;
        --max-level)
                shift
                case $1 in
                    [0-9])
                        MAX_LEVEL=$1
                        ;;
                    *)
                        printf 'ERROR: invalid value for --max-level option: %s\n' "$1" >&2
                        exit 1
                        ;;
                esac
            ;;
        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            if ! is_quiet; then
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
readonly MIN_LEVEL MAX_LEVEL CRON FUTURE VERBOSE QUIET

: "${EVOLIBS_SHELL_LIB:=/usr/local/lib/evolibs-shell}"
. "${EVOLIBS_SHELL_LIB}/os-release.sh" || {
    >&2 echo "Unable to load ${EVOLIBS_SHELL_LIB}/os-release.sh"
    exit 1
}

# Keep this after "show_version(); exit 0" which is called by check_versions
# to avoid logging exit twice.
declare -a files_to_cleanup
files_to_cleanup=""
# shellcheck disable=SC2064
trap cleanup EXIT INT TERM

log '-----------------------------------------------'
log "Running ${PROGNAME} ${VERSION} (levels: ${MIN_LEVEL}-${MAX_LEVEL})"

# Log config file content
if [ -f "${CONFIGFILE}" ]; then
    log "Runtime configuration (${CONFIGFILE}):"
    sed -e '/^[[:blank:]]*#/d; s/#.*//; /^[[:blank:]]*$/d' "${CONFIGFILE}" | log
fi

if evo::os-release::is_debian 10 lt; then
    echo "This version of ${PROGNAME} is built for Debian 10 and later." >&2
    exit 1
fi

# Default return code : 0 = no error
GLOBAL_RC=0

main_output_file=$(mktemp --tmpdir "evocheck.main.XXXXX")
files_to_cleanup+=("${main_output_file}")

exec_checks

if [ -f "${main_output_file}" ]; then
    lines_found=$(wc -l < "${main_output_file}")
    # shellcheck disable=SC2086
    if [ ${lines_found} -gt 0 ]; then
        cat "${main_output_file}" 2>&1
    fi
fi

exit ${GLOBAL_RC}
