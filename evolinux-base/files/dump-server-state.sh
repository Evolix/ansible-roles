#!/bin/sh

PROGNAME="dump-server-state"
REPOSITORY="https://gitea.evolix.org/evolix/dump-server-state"

VERSION="23.11"
readonly VERSION

dump_dir=
rc=0

# base functions

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2023 Evolix <info@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>,
                    Éric Morino <emorino@evolix.fr>,
                    Brice Waegeneire <bwaegeneire@evolix.fr>
                    and others.

${REPOSITORY}

${PROGNAME} comes with ABSOLUTELY NO WARRANTY. This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
END
}
show_help() {
    cat <<END
${PROGNAME} is dumping information related to the state of the server.

Usage: ${PROGNAME} --dump-dir=/path/to/dump/directory [OPTIONS]

Main options
 -d, --dump-dir         path to the directory where data will be stored
     --backup-dir       legacy option for dump directory
 -f, --force            keep existing dump directory and its content
 -v, --verbose          print details about each task
 -V, --version          print version and exit
 -h, --help             print this message and exit

Tasks options
 --all                  reset options to execute all tasks
 --none                 reset options to execute no task
 --[no-]etc             copy of /etc (default: no)
 --[no-]dpkg-full       copy of /var/lib/dpkg (default: no)
 --[no-]dpkg-status     copy of /var/lib/dpkg/status (default: yes)
 --[no-]apt-states      copy of apt extended states (default: yes)
 --[no-]apt-config      copy of apt configuration (default: yes)
 --[no-]packages        copy of dpkg selections (default: yes)
 --[no-]processes       copy of process list (default: yes)
 --[no-]uname           copy of uname value (default: yes)
 --[no-]uptime          copy of uptime value (default: yes)
 --[no-]netstat         copy of netstat (default: yes)
 --[no-]netcfg          copy of network configuration (default: yes)
 --[no-]iptables        copy of iptables (default: yes)
 --[no-]sysctl          copy of sysctl values (default: yes)
 --[no-]virsh           copy of virsh list (default: yes)
 --[no-]lxc             copy of lxc list (default: yes)
 --[no-]disks           copy of MBR and partitions (default: yes)
 --[no-]mount           copy of mount points (default: yes)
 --[no-]df              copy of disk usage (default: yes)
 --[no-]dmesg           copy of dmesg (default: yes)
 --[no-]mysql-processes copy of mysql processes (default: yes)
 --[no-]mysql-summary   copy of mysql summary (default: yes)
 --[no-]systemctl       copy of systemd services states (default: yes)

Tasks options order matters. They are evaluated from left to right.
Examples :
* "[…] --none --uname" will do only the uname task
* "[…] --all --no-etc" will do everything but the etc task
* "[…] --etc --none --mysql-summary" will do only the mysql task
END
}
debug() {
    if [ "${VERBOSE}" = "1" ]; then
        msg="${1:-$(cat /dev/stdin)}"
        echo "${msg}"
    fi
}

create_dump_dir() {
    debug "Task: Create ${dump_dir}"

    last_result=$(mkdir -p "${dump_dir}" && chmod -R 755 "${dump_dir}")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* mkdir/chmod OK"
    else
        debug "* mkdir/chmod ERROR :"
        debug "${last_result}"
        rc=10
    fi
}

task_etc() {
    debug "Task: /etc"

    rsync_bin=$(command -v rsync)

    if [ -n "${rsync_bin}" ]; then
        last_result=$(${rsync_bin} -ah --itemize-changes --exclude=.git /etc "${dump_dir}/")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* rsync OK"
        else
            debug "* rsync ERROR :"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* rsync not found"
        last_result=$(cp -r /etc "${dump_dir}/ && rm -rf ${dump_dir}/etc/.git")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* cp OK"
        else
            debug "* cp ERROR :"
            debug "${last_result}"
            rc=10
        fi
    fi
}

task_apt_states() {
    apt_dir="/"
    apt_dir_state="var/lib/apt"
    apt_dir_state_extended_states="extended_states"

    apt_config_bin=$(command -v apt-config)

    if [ -n "${apt_config_bin}" ]; then
        eval "$(${apt_config_bin} shell apt_dir Dir)"
        eval "$(${apt_config_bin} shell apt_dir_state Dir::State)"
        eval "$(${apt_config_bin} shell apt_dir_state_extended_states Dir::State::extended_states)"
    fi
    extended_states="${apt_dir}/${apt_dir_state}/${apt_dir_state_extended_states}"

    if [ -f "${extended_states}" ]; then
        debug "Task: APT states"

        last_result=$(cp -r "${extended_states}" "${dump_dir}/apt-extended-states.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* cp OK"
        else
            debug "* cp ERROR :"
            debug "${last_result}"
            rc=10
        fi
    fi
}

task_apt_config() {
    debug "Task: APT config"

    apt_config_bin=$(command -v apt-config)

    if [ -n "${apt_config_bin}" ]; then
        last_result=$(${apt_config_bin} dump > "${dump_dir}/apt-config.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* apt-config OK"
        else
            debug "* apt-config ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* apt-config is not found"
    fi
}

task_dpkg_full() {
    debug "Task: DPkg full state"

    dir_state_status="/var/lib/dpkg/status"

    apt_config_bin=$(command -v apt-config)

    if [ -n "${apt_config_bin}" ]; then
        eval "$(${apt_config_bin} shell dir_state_status Dir::State::status)"
    fi

    dpkg_dir=$(dirname "${dir_state_status}")

    last_result=$(mkdir -p "${dump_dir}${dpkg_dir}" && chmod -R 755 "${dump_dir}${dpkg_dir}")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* mkdir/chmod OK"
    else
        debug "* mkdir/chmod ERROR"
        debug "${last_result}"
        rc=10
    fi

    rsync_bin=$(command -v rsync)

    if [ -n "${rsync_bin}" ]; then
        last_result=$(${rsync_bin} -ah --itemize-changes --exclude='*-old' "${dpkg_dir}/" "${dump_dir}${dpkg_dir}/")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* rsync OK"
        else
            debug "* rsync ERROR :"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* rsync not found"

        last_result=$(cp -r "${dpkg_dir}/*" "${dump_dir}${dpkg_dir}/" && rm -rf "${dump_dir}${dpkg_dir}/*-old")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* cp OK"
        else
            debug "* cp ERROR :"
            debug "${last_result}"
            rc=10
        fi
    fi
}

task_dpkg_status() {
    debug "Task: DPkg status"

    dir_state_status="/var/lib/dpkg/status"

    apt_config_bin=$(command -v apt-config)

    if [ -n "${apt_config_bin}" ]; then
        eval "$(${apt_config_bin} shell dir_state_status Dir::State::status)"
    fi

    last_result=$(cp "${dir_state_status}" "${dump_dir}/dpkg-status.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* cp OK"
    else
        debug "* cp ERROR :"
        debug "${last_result}"
        rc=10
    fi
}

task_packages() {
    debug "Task: List of installed package"

    dpkg_bin=$(command -v dpkg)

    if [ -n "${dpkg_bin}" ]; then
        last_result=$(${dpkg_bin} --get-selections "*" > "${dump_dir}/current_packages.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* dpkg OK"
        else
            debug "* dpkg ERROR :"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* dpkg not found"
    fi
}

task_uname() {
    debug "Task: uname"

    last_result=$(uname -a > "${dump_dir}/uname.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* uname OK"
    else
        debug "* uname ERROR"
        debug "${last_result}"
        rc=10
    fi
}

task_uptime() {
    debug "Task: uptime"

    last_result=$(uptime > "${dump_dir}/uptime.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* uptime OK"
    else
        debug "* uptime ERROR"
        debug "${last_result}"
        rc=10
    fi
}

task_processes() {
    debug "Task: Process list"

    last_result=$(ps fauxw > "${dump_dir}/ps.txt")
    last_rc=$?

    if [ ${last_rc} -eq 0 ]; then
        debug "* ps OK"
    else
        debug "* ps ERROR"
        debug "${last_result}"
        rc=10
    fi

    pstree_bin=$(command -v pstree)

    if [ -n "${pstree_bin}" ]; then
        last_result=$(${pstree_bin} -pan > "${dump_dir}/pstree.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* pstree OK"
        else
            debug "* pstree ERROR"
            debug "${last_result}"
            rc=10
        fi
    fi
}

task_netstat() {
    debug "Task: Network status"

    ss_bin=$(command -v ss)

    if [ -n "${ss_bin}" ]; then
        last_result=$(${ss_bin} -tanpul > "${dump_dir}/netstat-ss.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* ss OK"
        else
            debug "* ss ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* ss not found"
    fi

    netstat_bin=$(command -v netstat)

    if [ -n "${netstat_bin}" ]; then
        last_result=$(netstat -laputen > "${dump_dir}/netstat-legacy.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* netstat OK"
        else
            debug "* netstat ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* netstat not found"
    fi
}

task_netcfg() {
    debug "Task: Network configuration"

    ip_bin=$(command -v ip)

    if [ -n "${ip_bin}" ]; then
        last_result=$(${ip_bin} address show > "${dump_dir}/ip-address.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* ip address OK"
        else
            debug "* ip address ERROR"
            debug "${last_result}"
            rc=10
        fi

        last_result=$(${ip_bin} route show > "${dump_dir}/ip-route.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* ip route OK"
        else
            debug "* ip route ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* ip not found"

        ifconfig_bin=$(command -v ifconfig)

        if [ -n "${ifconfig_bin}" ]; then
            last_result=$(${ifconfig_bin} > "${dump_dir}/ifconfig.txt")
            last_rc=$?

            if [ ${last_rc} -eq 0 ]; then
                debug "* ifconfig OK"
            else
                debug "* ifconfig ERROR"
                debug "${last_result}"
                rc=10
            fi
        else
            debug "* ifconfig not found"
        fi
    fi
}

task_iptables() {
    debug "Task: iptables"

    iptables_bin=$(command -v iptables)
    ip6tables_bin=$(command -v ip6tables)

    if [ -n "${iptables_bin}" ]; then
        last_result=$({
            printf "#### iptables --list ###############################\n"
            ${iptables_bin} --list --numeric --verbose --line-numbers
            printf "\n### iptables --table nat --list ####################\n"
            ${iptables_bin} --table nat --list --numeric --verbose --line-numbers
            printf "\n#### iptables --table mangle --list ################\n"
            ${iptables_bin} --table mangle --list --numeric --verbose --line-numbers
            if [ -n "${ip6tables_bin}" ]; then
                printf "\n#### ip6tables --list ##############################\n"
                ${ip6tables_bin} --list --numeric --verbose --line-numbers
                printf "\n#### ip6tables --table mangle --list ###############\n"
                ${ip6tables_bin} --table mangle --list --numeric --verbose --line-numbers
            fi
        } > "${dump_dir}/iptables-v.txt") 2> "${dump_dir}/iptables-v.err"
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* iptables -v OK"
        else
            debug "* iptables -v ERROR"
            debug "$(cat ${dump_dir}/iptables-v.err)"
            # Ignore errors because we don't know if this is nft related or a real error
            # rc=10
        fi

        last_result=$({
            printf "#### iptables --list ###############################\n"
            ${iptables_bin} --list --numeric
            printf "\n### iptables --table nat --list ####################\n"
            ${iptables_bin} --table nat --list --numeric
            printf "\n#### iptables --table mangle --list ################\n"
            ${iptables_bin} --table mangle --list --numeric
            if [ -n "${ip6tables_bin}" ]; then
                printf "\n#### ip6tables --list ##############################\n"
                ${ip6tables_bin} --list --numeric
                printf "\n#### ip6tables --table mangle --list ###############\n"
                ${ip6tables_bin} --table mangle --list --numeric
            fi
        } > "${dump_dir}/iptables.txt") 2> "${dump_dir}/iptables.err"
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* iptables OK"
        else
            debug "* iptables ERROR"
            debug "$(cat ${dump_dir}/iptables.err)"
            # Ignore errors because we don't know if this is nft related or a real error
            # rc=10
        fi
    else
        debug "* iptables not found"
    fi

    iptables_save_bin=$(command -v iptables-save)

    if [ -n "${iptables_save_bin}" ]; then
        ${iptables_save_bin} > "${dump_dir}/iptables-save.txt" 2> "${dump_dir}/iptables-save.err"
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* iptables-save OK"
        else
            debug "* iptables-save ERROR"
            debug "$(cat ${dump_dir}/iptables-save.err)"
            # Ignore errors because we don't know if this is nft related or a real error
            # rc=10
        fi
    else
        debug "* iptables-save not found"
    fi

    nft_bin=$(command -v nft)

    if [ -n "${nft_bin}" ]; then
        ${nft_bin} list ruleset > "${dump_dir}/nft-ruleset.txt" 2> "${dump_dir}/nft-ruleset.err"
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* nft ruleset OK"
        else
            debug "* nft ruleset ERROR"
            debug "$(cat ${dump_dir}/nft-ruleset.err)"
            rc=10
        fi
    fi
}

task_sysctl() {
    debug "Task: sysctl values"

    sysctl_bin=$(command -v sysctl)

    if [ -n "${sysctl_bin}" ]; then
        last_result=$(${sysctl_bin} -a --ignore 2>/dev/null | sort -h > "${dump_dir}/sysctl.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* sysctl OK"
        else
            debug "* sysctl ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* sysctl not found"
    fi
}

task_virsh() {
    debug "Task: virsh list"

    virsh_bin=$(command -v virsh)

    if [ -n "${virsh_bin}" ]; then
        last_result=$(${virsh_bin} list --all > "${dump_dir}/virsh-list.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* virsh list OK"
        else
            debug "* virsh list ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* virsh not found"
    fi
}

task_lxc() {
    debug "Task: lxc list"

    lxc_ls_bin=$(command -v lxc-ls)

    if [ -n "${lxc_ls_bin}" ]; then
        last_result=$(${lxc_ls_bin} --fancy > "${dump_dir}/lxc-list.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* lxc list OK"
        else
            debug "* lxc list ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* lxc-ls not found"
    fi
}

task_disks() {
    debug "Task: Disks"

    lsblk_bin=$(command -v lsblk)
    awk_bin=$(command -v awk)

    if [ -n "${lsblk_bin}" ] && [ -n "${awk_bin}" ]; then
        disks=$(${lsblk_bin} -l | grep disk | grep -v -E '(drbd|fd[0-9]+)' | ${awk_bin} '{print $1}')
        for disk in ${disks}; do
            dd_bin=$(command -v dd)
            if [ -n "${dd_bin}" ]; then
                last_result=$(${dd_bin} if="/dev/${disk}" of="${dump_dir}/MBR-${disk}" bs=512 count=1 2>&1)
                last_rc=$?

                if [ ${last_rc} -eq 0 ]; then
                    debug "* dd ${disk} OK"
                else
                    debug "* dd ${disk} ERROR"
                    debug "${last_result}"
                    rc=10
                fi
            else
                debug "* dd not found"
            fi
            fdisk_bin=$(command -v fdisk)
            if [ -n "${fdisk_bin}" ]; then
                last_result=$(${fdisk_bin} -l "/dev/${disk}" > "${dump_dir}/partitions-${disk}" 2>&1)
                last_rc=$?

                if [ ${last_rc} -eq 0 ]; then
                    debug "* fdisk ${disk} OK"
                else
                    debug "* fdisk ${disk} ERROR"
                    debug "${last_result}"
                    rc=10
                fi
            else
                debug "* fdisk not found"
            fi
        done
        cat "${dump_dir}"/partitions-* > "${dump_dir}/partitions"
    else
        if [ -n "${lsblk_bin}" ]; then
            debug "* lsblk not found"
        fi
        if [ -n "${awk_bin}" ]; then
            debug "* awk not found"
        fi
    fi
}

task_mount() {
    debug "Task: Mount points"

    findmnt_bin=$(command -v findmnt)

    if [ -n "${findmnt_bin}" ]; then
        last_result=$(${findmnt_bin} > "${dump_dir}/mount.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* mount points OK"
        else
            debug "* mount points ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* findmnt not found"

        mount_bin=$(command -v mount)

        if [ -n "${mount_bin}" ]; then
            last_result=$(${mount_bin} > "${dump_dir}/mount.txt")
            last_rc=$?

            if [ ${last_rc} -eq 0 ]; then
                debug "* mount points OK"
            else
                debug "* mount points ERROR"
                debug "${last_result}"
                rc=10
            fi
        else
            debug "* mount not found"
        fi
    fi
}

task_df() {
    debug "Task: df"

    df_bin=$(command -v df)

    if [ -n "${df_bin}" ]; then
        last_result=$(${df_bin} --portability > "${dump_dir}/df.txt" 2>&1)
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* df OK"
        else
            debug "* df ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* df not found"
    fi
}

task_dmesg() {
    debug "Task: dmesg"

    dmesg_bin=$(command -v dmesg)

    if [ -n "${dmesg_bin}" ]; then
        last_result=$(${dmesg_bin} > "${dump_dir}/dmesg.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* dmesg OK"
        else
            debug "* dmesg ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* dmesg not found"
    fi
}

task_mysql_processes() {
    debug "Task: MySQL processes"

    mysqladmin_bin=$(command -v mysqladmin)

    if [ -n "${mysqladmin_bin}" ]; then
        # Look for local MySQL or MariaDB process
        if pgrep mysqld > /dev/null || pgrep mariadbd > /dev/null; then
            if ${mysqladmin_bin} ping > /dev/null 2>&1; then
                ${mysqladmin_bin} --verbose processlist > "${dump_dir}/mysql-processlist.txt" 2> "${dump_dir}/mysql-processlist.err"
                last_rc=$?

                if [ ${last_rc} -eq 0 ]; then
                    debug "* mysqladmin OK"
                else
                    debug "* mysqladmin ERROR"
                    debug < "${dump_dir}/mysql-processlist.err"
                    rm "${dump_dir}/mysql-processlist.err"
                    rc=10
                fi
            else
                debug "* unable to ping with mysqladmin"
            fi
        else
            debug "* no mysqld or mariadbd process is running"
        fi
    else
        debug "* mysqladmin not found"
    fi
}

task_mysql_summary() {
    debug "Task: MySQL summary"

    mysqladmin_bin=$(command -v mysqladmin)
    pt_mysql_summary_bin=$(command -v pt-mysql-summary)

    if [ -n "${mysqladmin_bin}" ] && [ -n "${pt_mysql_summary_bin}" ]; then
        # Look for local MySQL or MariaDB process
        if pgrep mysqld > /dev/null || pgrep mariadbd > /dev/null; then
            if ${mysqladmin_bin} ping > /dev/null 2>&1; then
                # important to set sleep to 0
                # because we don't want to block
                # even if we lose some insight.
                ${pt_mysql_summary_bin} --sleep 0 > "${dump_dir}/mysql-summary.txt" 2> "${dump_dir}/mysql-summary.err"
                last_rc=$?

                if [ ${last_rc} -eq 0 ]; then
                    debug "* pt-mysql-summary OK"
                else
                    debug "* pt-mysql-summary ERROR"
                    debug < "${dump_dir}/mysql-summary.err"
                    rm "${dump_dir}/mysql-summary.err"
                    rc=10
                fi
            else
                debug "* unable to ping with mysqladmin"
            fi
        else
            debug "* no mysqld or mariadbd process is running"
        fi
    else
        debug "* pt-mysql-summary not found"
    fi
}

task_systemctl() {
    debug "Task: Systemd services"

    systemctl_bin=$(command -v systemctl)

    if [ -n "${systemctl_bin}" ]; then
        last_result=$(${systemctl_bin} --no-legend --state=failed --type=service > "${dump_dir}/systemctl-failed-services.txt")
        last_rc=$?

        if [ ${last_rc} -eq 0 ]; then
            debug "* failed services OK"
        else
            debug "* failed services ERROR"
            debug "${last_result}"
            rc=10
        fi
    else
        debug "* systemctl not found"
    fi
}

clean_empty_error_file() {
    find "${dump_dir}" -type f -name "*.err" -size 0 -delete
}

main() {
    if [ -z "${dump_dir}" ]; then
        echo "ERROR: You must provide the --dump-dir argument" >&2
        exit 1
    fi

    if [ -d "${dump_dir}" ]; then
        if [ "${FORCE}" != "1" ]; then
            echo "ERROR: The dump directory ${dump_dir} already exists. Delete it first." >&2
            exit 2
        fi
    else
        create_dump_dir
    fi

    if [ "${TASK_ETC}" -eq 1 ]; then
        task_etc
    fi
    if [ "${TASK_DPKG_FULL}" -eq 1 ]; then
        task_dpkg_full
    fi
    if [ "${TASK_DPKG_STATUS}" -eq 1 ]; then
        task_dpkg_status
    fi
    if [ "${TASK_APT_STATES}" -eq 1 ]; then
        task_apt_states
    fi
    if [ "${TASK_APT_CONFIG}" -eq 1 ]; then
        task_apt_config
    fi
    if [ "${TASK_PACKAGES}" -eq 1 ]; then
        task_packages
    fi
    if [ "${TASK_PROCESSES}" -eq 1 ]; then
        task_processes
    fi
    if [ "${TASK_UPTIME}" -eq 1 ]; then
        task_uptime
    fi
    if [ "${TASK_UNAME}" -eq 1 ]; then
        task_uname
    fi
    if [ "${TASK_NETSTAT}" -eq 1 ]; then
        task_netstat
    fi
    if [ "${TASK_NETCFG}" -eq 1 ]; then
        task_netcfg
    fi
    if [ "${TASK_IPTABLES}" -eq 1 ]; then
        task_iptables
    fi
    if [ "${TASK_SYSCTL}" -eq 1 ]; then
        task_sysctl
    fi
    if [ "${TASK_VIRSH}" -eq 1 ]; then
        task_virsh
    fi
    if [ "${TASK_LXC}" -eq 1 ]; then
        task_lxc
    fi
    if [ "${TASK_DISKS}" -eq 1 ]; then
        task_disks
    fi
    if [ "${TASK_MOUNT}" -eq 1 ]; then
        task_mount
    fi
    if [ "${TASK_DF}" -eq 1 ]; then
        task_df
    fi
    if [ "${TASK_DMESG}" -eq 1 ]; then
        task_dmesg
    fi
    if [ "${TASK_MYSQL_PROCESSES}" -eq 1 ]; then
        task_mysql_processes
    fi
    if [ "${TASK_MYSQL_SUMMARY}" -eq 1 ]; then
        task_mysql_summary
    fi
    if [ "${TASK_SYSTEMCTL}" -eq 1 ]; then
        task_systemctl
    fi

    clean_empty_error_file

    debug "=> Your dump is available at ${dump_dir}"
    exit ${rc}
}

# parse options
# based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 0
            ;;
        -V|--version)
            show_version
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;

        -f|--force)
            FORCE=1
            ;;

        -d|--dump-dir)
            # with value separated by space
            if [ -n "$2" ]; then
                dump_dir=$2
                shift
            else
                printf 'ERROR: "-d|--dump-dir" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --dump-dir=?*)
            # with value speparated by =
            dump_dir=${1#*=}
            ;;
        --dump-dir=)
            # without value
            printf 'ERROR: "--dump-dir" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        --backup-dir)
            printf 'WARNING: "--backup-dir" is deprecated in favor of "--dump-dir".\n'
            if [ -n "${dump_dir}" ]; then
                debug "Dump directory is already set, let's ignore this one."
            else
                debug "Dump directory is not set already, let's stay backward compatible."
                # with value separated by space
                if [ -n "$2" ]; then
                    dump_dir=$2
                    shift
                else
                    printf 'ERROR: "--backup-dir" requires a non-empty option argument.\n' >&2
                    exit 1
                fi
            fi
            ;;
        --backup-dir=?*)
            # with value speparated by =
            printf 'WARNING: "--backup-dir" is deprecated in favor of "--dump-dir".\n'
            if [ -n "${dump_dir}" ]; then
                debug "Dump directory is already set, let's ignore this one."
            else
                debug "Dump directory is not set already, let's stay backward compatible."
                dump_dir=${1#*=}
            fi
            ;;
        --backup-dir=)
            # without value
            printf 'WARNING: "--backup-dir" is deprecated in favor of "--dump-dir".\n'
            if [ -n "${dump_dir}" ]; then
                debug "Dump directory is already set, let's ignore this one."
            else
                printf 'ERROR: "--backup-dir" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;

        --all)
            for option in \
                TASK_ETC \
                TASK_DPKG_FULL \
                TASK_DPKG_STATUS \
                TASK_APT_STATES \
                TASK_APT_CONFIG \
                TASK_PACKAGES \
                TASK_PROCESSES \
                TASK_UNAME \
                TASK_UPTIME \
                TASK_NETSTAT \
                TASK_NETCFG \
                TASK_IPTABLES \
                TASK_SYSCTL \
                TASK_VIRSH \
                TASK_LXC \
                TASK_DISKS \
                TASK_MOUNT \
                TASK_DF \
                TASK_DMESG \
                TASK_MYSQL_PROCESSES \
                TASK_MYSQL_SUMMARY \
                TASK_SYSTEMCTL
            do
                eval "${option}=1"
            done
            ;;

        --none)
            for option in \
                TASK_ETC \
                TASK_DPKG_FULL \
                TASK_DPKG_STATUS \
                TASK_APT_STATES \
                TASK_APT_CONFIG \
                TASK_PACKAGES \
                TASK_PROCESSES \
                TASK_UNAME \
                TASK_UPTIME \
                TASK_NETSTAT \
                TASK_NETCFG \
                TASK_IPTABLES \
                TASK_SYSCTL \
                TASK_VIRSH \
                TASK_LXC \
                TASK_DISKS \
                TASK_MOUNT \
                TASK_DF \
                TASK_DMESG \
                TASK_MYSQL_PROCESSES \
                TASK_MYSQL_SUMMARY \
                TASK_SYSTEMCTL
            do
                eval "${option}=0"
            done
            ;;

        --etc)
            TASK_ETC=1
            ;;
        --no-etc)
            TASK_ETC=0
            ;;

        --dpkg-full)
            TASK_DPKG_FULL=1
            ;;
        --no-dpkg-full)
            TASK_DPKG_FULL=0
            ;;

        --dpkg-status)
            TASK_DPKG_STATUS=1
            ;;
        --no-dpkg-status)
            TASK_DPKG_STATUS=0
            ;;

        --apt-states)
            TASK_APT_STATES=1
            ;;
        --no-apt-states)
            TASK_APT_STATES=0
            ;;

        --apt-config)
            TASK_APT_CONFIG=1
            ;;
        --no-apt-config)
            TASK_APT_CONFIG=0
            ;;

        --packages)
            TASK_PACKAGES=1
            ;;
        --no-packages)
            TASK_PACKAGES=0
            ;;

        --processes)
            TASK_PROCESSES=1
            ;;
        --no-processes)
            TASK_PROCESSES=0
            ;;

        --uptime)
            TASK_UPTIME=1
            ;;
        --no-uptime)
            TASK_UPTIME=0
            ;;

        --uname)
            TASK_UNAME=1
            ;;
        --no-uname)
            TASK_UNAME=0
            ;;

        --netstat)
            TASK_NETSTAT=1
            ;;
        --no-netstat)
            TASK_NETSTAT=0
            ;;

        --netcfg)
            TASK_NETCFG=1
            ;;
        --no-netcfg)
            TASK_NETCFG=0
            ;;

        --iptables)
            TASK_IPTABLES=1
            ;;
        --no-iptables)
            TASK_IPTABLES=0
            ;;

        --sysctl)
            TASK_SYSCTL=1
            ;;
        --no-sysctl)
            TASK_SYSCTL=0
            ;;

        --virsh)
            TASK_VIRSH=1
            ;;
        --no-virsh)
            TASK_VIRSH=0
            ;;

        --lxc)
            TASK_LXC=1
            ;;
        --no-lxc)
            TASK_LXC=0
            ;;

        --disks)
            TASK_DISKS=1
            ;;
        --no-disks)
            TASK_DISKS=0
            ;;

        --mount)
            TASK_MOUNT=1
            ;;
        --no-mount)
            TASK_MOUNT=0
            ;;

        --df)
            TASK_DF=1
            ;;
        --no-df)
            TASK_DF=0
            ;;

        --dmesg)
            TASK_DMESG=1
            ;;
        --no-dmesg)
            TASK_DMESG=0
            ;;

        --mysql-processes)
            TASK_MYSQL_PROCESSES=1
            ;;
        --no-mysql-processes)
            TASK_MYSQL_PROCESSES=0
            ;;

        --mysql-summary)
            TASK_MYSQL_SUMMARY=1
            ;;
        --no-mysql-summary)
            TASK_MYSQL_SUMMARY=0
            ;;

        --systemctl)
            TASK_SYSTEMCTL=1
            ;;
        --no-systemctl)
            TASK_SYSTEMCTL=0
            ;;

        --)
            # End of all options.
            shift
            break
            ;;
        -?*)
            # ignore unknown options
            printf 'WARN: Unknown option : %s\n' "$1" >&2
            exit 1
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

# Default values
: "${VERBOSE:=0}"
: "${FORCE:=0}"
: "${TASK_ETC:=0}"
: "${TASK_DPKG_FULL:=0}"
: "${TASK_DPKG_STATUS:=1}"
: "${TASK_APT_STATES:=1}"
: "${TASK_APT_CONFIG:=1}"
: "${TASK_PACKAGES:=1}"
: "${TASK_PROCESSES:=1}"
: "${TASK_UNAME:=1}"
: "${TASK_UPTIME:=1}"
: "${TASK_NETSTAT:=1}"
: "${TASK_NETCFG:=1}"
: "${TASK_IPTABLES:=1}"
: "${TASK_SYSCTL:=1}"
: "${TASK_VIRSH:=1}"
: "${TASK_LXC:=1}"
: "${TASK_DISKS:=1}"
: "${TASK_MOUNT:=1}"
: "${TASK_DF:=1}"
: "${TASK_DMESG:=1}"
: "${TASK_MYSQL_PROCESSES:=1}"
: "${TASK_MYSQL_SUMMARY:=1}"
: "${TASK_SYSTEMCTL:=1}"

export LC_ALL=C

set -u

main
