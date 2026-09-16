#!/bin/sh
# shellcheck disable=SC2059

# Repository: https://forge.evolix.net/evolix/maj.sh/

set -u
# Do not "set -e", many subcommands can fail

VERSION="26.02.1"
readonly VERSION

PROGNAME=$(basename "$0")
readonly PROGNAME

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2026 Evolix <info@evolix.fr>,
               Gregory Colpart <reg@evolix.fr>,
               Romain Dessort <rdessort@evolix.fr>,
               Ludovic Poujol <lpoujol@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>,
               David Prevot <dprevot@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under
certain conditions. See the GNU General Public Licence for details.
END
}
is_dry_run() {
    test ${dry_run} -eq 1
}
is_ext_mode() {
    test ${ext_mode} -eq 1
}
# Generate pretty list of packages to upgrade
get_upgradable_packages() {
    file=$(upgrade_tmp_file "upgradable_packages.stdout" "main.")
    # shellcheck disable=SC2024
    apt -o Dir::State::Lists="${listupgrade_state_dir}" -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" list --upgradable 2>&1 | grep --extended-regexp --invert-match '^(Listing|WARNING|$)' > "${file}"

    echo "${file}"
}
get_upgradable_packages_container() {
    container=${1-}
    file=$(upgrade_tmp_file "upgradable_packages.stdout" "${container}.")
    # shellcheck disable=SC2024
    lxc-attach --name "${container}" -- apt list --upgradable 2>&1 | grep --extended-regexp --invert-match '^(Listing|WARNING|$)' > "${file}"

    echo "${file}"
}
upgrade_tmp_file() {
    basename=${1}
    prefix=${2:-}
    suffix=${3:-}

    echo "${upgrade_tmp_dir}/${prefix}${basename}${suffix}"
}

fix_logs_permissions() {
    chown -R "root:root" "${upgrade_tmp_dir}"
    chmod -R u+rwX,g-rwx,o-rwx "${upgrade_tmp_dir}"
}
save_apt_logs() {
    lxc_container=${1:-}
    today=$(date +%Y-%m-%d)

    APT_LOG_TERM_FILE="/var/log/apt/term.log"
    APT_LOG_HIST_FILE="/var/log/apt/history.log"

    if [ -n "${lxc_container}" ]; then
        lxc_path=$(lxc-config lxc.lxcpath)
        if lxc-info --name "${container_name}" > /dev/null; then
            # shellcheck disable=SC2046
            eval $(lxc-attach --name "${container_name}" apt-config shell APT_LOG_TERM_FILE "Dir::Log::Terminal/f" APT_LOG_HIST_FILE "Dir::Log::History/f")

            container_rootfs="${lxc_path}/${container_name}/rootfs"

            term_path="${container_rootfs}${APT_LOG_TERM_FILE}"
            history_path="${container_rootfs}${APT_LOG_HIST_FILE}"
            prefix="${container_name}"
        fi
    else
        # shellcheck disable=SC2046
        eval $(apt-config shell APT_LOG_TERM_FILE "Dir::Log::Terminal/f" APT_LOG_HIST_FILE "Dir::Log::History/f")

        term_path="${APT_LOG_TERM_FILE}"
        history_path="${APT_LOG_HIST_FILE}"
        prefix="main"
    fi

    if [ -f "${term_path}" ]; then
        sed -n "/${today}/,\$p" "${term_path}" > "$(upgrade_tmp_file "apt_term.log" "${prefix}.")"
    fi
    if [ -f "${history_path}" ]; then
        sed -n "/${today}/,\$p" "${history_path}" > "$(upgrade_tmp_file "apt_history.log" "${prefix}.")"
    fi
}

apt_summary() {
    file=${1-}
    if is_dry_run; then
        echo "DRY_RUN: nothing has been upgraded"
    else
        grep --extended-regexp "^[[:digit:]]+ upgraded" "${file}"
    fi
}
apt_fetch_archives_error() {
    file=${1-}
    grep --fixed-strings "E: Unable to fetch some archives" "${file}"
}
render_system_summary() {
    header=${1-}
    log_base=${2-}
    result=""
    if [ "${apt_exit_code}" = "0" ]; then
        if [ "${updated}" = "1" ]; then
            result="${result}\n${GREEN}${header}: Upgrade OK${RESET}\n"
        else
            result="${result}\n${header}: Nothing done\n"
        fi
        apt_summary=$(apt_summary "${log_base}.stdout")
        apt_summary_rc=$?
        if [ "${apt_summary_rc}" -eq "0" ]; then
            result="${result}${apt_summary}\n"
        fi
    else
        apt_fetch_archives_error=$(apt_fetch_archives_error "${log_base}.stderr")
        apt_fetch_archives_rc=$?
        if [ "${apt_fetch_archives_rc}" -eq "0" ]; then
            result="${result}\n${YELLOW}${header}: Error${RESET}\n"
            result="${result}${apt_fetch_archives_error}\n"
        else
            result="${result}\n${RED}${header}: Error${RESET}\n"
            result="${result}See ${log_base}.stderr for details\n"
        fi
    fi
    echo "${result}"
}

# Grab the nrpe check, run it and display a short result
display_check_status() {
    check="${1-}"
    name="${2-}"

    grep "${check}" -r /etc/nagios | awk -F"=" '{print $2}' | head -n1 | sh >/dev/null
    status=${?}

    case "${status}" in
    0)
        status_color=2
        status_name="   OK   "
        ;;
    1)
        status_color=3
        status_name=" WARNING"
        ;;
    2)
        status_color=1
        status_name="CRITICAL"
        ;;
    3)
        status_color=5
        status_name=" UNKNOWN"
        ;;
    esac

    tput setab ${status_color}
    tput setaf 7
    tput bold

    printf "%s - %s" "${name}" "${status_name}"

    tput sgr0

    printf '   '
}
check_alternate_apt_state() {
    if [ -d "${listupgrade_state_dir}" ]; then
        listupgrade_state_dir_age=$(stat -c %Y "${listupgrade_state_dir}/partial")
        a_week_ago=$(date -d "-8 days" +%s)
        if [ "${listupgrade_state_dir_age}" -lt "${a_week_ago}" ]; then
            printf "${RED}Error: alternate APT state directory '${listupgrade_state_dir}\` hasn't been updated in the last 8 days.${RESET}\n"
            printf "${RED}listupgrade.sh is probably outdated.${RESET}\n"
            exit 1
        fi
    else
        printf "${RED}Error: alternate APT state directory '${listupgrade_state_dir}\` not found.${RESET}\n"
        printf "${RED}listupgrade.sh is probably outdated.${RESET}\n"
        exit 1
    fi
}
line_sep() {
    char=${1:-'='}
    cols=$(tput cols)
    #shellcheck disable=SC2034,SC2086
    for i in $(seq 1 ${cols}); do
        printf "${char}"
    done
    printf "\n"
}
head_or_cat() {
    file=${1:-}
    line_sep "-"
    if [ "$(wc -l "${file}" | cut -d ' ' -f 1)" -ge 10 ]; then
        head -n 10 "${file}"
        printf "[…]\n"
        printf "see '${file}\` for details\n"
    else
        cat "${file}"
    fi
    line_sep "-"
}
# Files found in the directory passed as 1st argument
# are executed if they are executable
# and if their name doesn't contain a dot
exec_hooks_in_dir() {
    hooks=$(find "${1}" -follow -type f -executable -not -name '*.*' -print0 | sort --zero-terminated --dictionary-order | xargs --no-run-if-empty --null --max-args=1)
    for hook in ${hooks}; do
        # printf "${CYAN}Executing '%s\`${RESET}\n" "${hook}"
        ${hook}
    done
}
pre_hooks() {
    prefix=${1}

    if [ -d "${hooks_dir}/pre" ]; then
        file=$(upgrade_tmp_file "upgradable_packages.stdout" "${prefix}.")
        if [ -f "${file}" ]; then
            export UPGRADABLE_PACKAGES_FILE="${file}"
        fi

        exec_hooks_in_dir "${hooks_dir}/pre"
    fi
}
post_hooks() {
    prefix=${1}

    if [ -d "${hooks_dir}/post" ]; then
        file=$(upgrade_tmp_file "upgradable_packages.stdout" "${prefix}.")
        if [ -f "${file}" ]; then
            export UPGRADABLE_PACKAGES_FILE="${file}"
        fi

        exec_hooks_in_dir "${hooks_dir}/post"
    fi
}
is_dependent_lib_upgraded() {
    grep --quiet --extended-regexp "$(date +"%Y-%m-%d") .+ upgrade (libssl|libc6)" /var/log/dpkg.log
}
is_kernel_changed() {
    grep --quiet --extended-regexp "$(date +"%Y-%m-%d") .+ (upgrade|install|configure) linux-image" /var/log/dpkg.log
}
old_kernel_autoremoval() {
    old_kernel_autoremoval_command="/usr/local/sbin/old-kernel-autoremoval"
    # Don't use "-x" because /home is often mounted with "noexec" option
    if [ -e "${old_kernel_autoremoval_command}" ]; then
        if [ "${nosudopasswd}" -eq "0" ]; then
            printf "${CYAN}Trying to remove old kernels...${RESET}\n"
            # shellcheck disable=SC2086
            old_kernel_autoremoval_stdout="${upgrade_tmp_dir}/kernel.autoremoval.stdout"
            old_kernel_autoremoval_stderr="${upgrade_tmp_dir}/kernel.autoremoval.stderr"

            if is_dry_run; then
                printf "DRY RUN: %s\n" "${old_kernel_autoremoval_command}"
                apt_exit_code=0
                old_kernel_autoremoval_exit_code=0
            else
                bash "${old_kernel_autoremoval_command}" 1>"${old_kernel_autoremoval_stdout}" 2>"${old_kernel_autoremoval_stderr}"
                old_kernel_autoremoval_exit_code=$?

                if [ "${old_kernel_autoremoval_exit_code}" -ne "0" ]; then
                    printf "\n${RED}Error removing old kernel: \n"
                    printf "${old_kernel_autoremoval_command}\n"
                    head_or_cat "${old_kernel_autoremoval_stderr}"
                    printf "${RESET}"
                fi
            fi
            apt_exit_code="$((apt_exit_code | old_kernel_autoremoval_exit_code))"
        else
            printf "\n${YELLOW}running without sudo, skip kernel cleanup${RESET}\n"
        fi
    else
        printf "\n${YELLOW}${old_kernel_autoremoval_command} is missing, skip kernel cleanup${RESET}\n"
    fi
}

if [ "$(id -u)" -ne "0" ] ; then
    echo "This script must be run as root." >&2
    exit 1
fi

export LC_ALL=C

## Default settings
# summary string to display at the end
summary=""
# has any package has been updated?
updated="0"
# should we force update packages that are on hold?
update="0"
# should we clean kernels?
cleankernels="1"
# execute without sudo?
nosudopasswd="0"
# dry-run mode?
dry_run="0"
# external mode?
ext_mode="0"
# use needrestart after upgrade?
needrestart="0"
# should we reinstall the kernel?
reinstall_kernel_meta_package="0"
# alternate APT state directory
if [ -z "${listupgrade_state_dir:-""}" ]; then
    # If variable is not already defined
    if dpkg --compare-versions "$(cat /etc/debian_version)" lt 8; then
        # With Debian < 8 we use the regular state directory
        listupgrade_state_dir="/var/lib/apt/lists/"
    else
        # Otherwise we use a custom directory
        listupgrade_state_dir="/var/lib/listupgrade"
    fi
fi
# alternate APT sourcepart directory
listupgrade_sources_dir="${listupgrade_sources_dir:-/etc/apt/listupgrade-sources.list.d}"
listupgrade_sources_file="${listupgrade_sources_file:-/etc/apt/sources.list}"
### Disabled (temporary ?)
# warning_packages_pattern="^(linux-image-|apache|nginx|mysql-server|postgresql-[[:digit:]]|tomcat|redis|courier-|dovecot|postfix|bind9$|samba$|php|haproxy|elasticsearch|kibana)"
warning_packages_pattern=""

hooks_dir="/etc/evolinux/minor-upgrade-hooks"

# Terminal colors
# shellcheck disable=SC2034
RED='\e[0;31m'
# shellcheck disable=SC2034
GREEN='\e[0;32m'
# shellcheck disable=SC2034
YELLOW='\e[0;33m'
# shellcheck disable=SC2034
BLUE='\e[0;34m'
# shellcheck disable=SC2034
MAGENTA='\e[0;35m'
# shellcheck disable=SC2034
CYAN='\e[0;36m'
# shellcheck disable=SC2034
RESET='\e[m'

# Options parsing.
while :; do
    case ${1:-} in
    -V | --version)
        show_version
        exit 0
        ;;
    -u | --update)
        update=1
        ;;
    -k | --no-kernel)
        cleankernels=0
        ;;
    -n | --no-sudo)
        nosudopasswd=1
        ;;
    -d | --dry-run)
        dry_run=1
        ;;
    -e | --external | --ext )
        ext_mode=1
        ;;
    -r | --restart-services)
        needrestart=1
        ;;
    -?* | [[:alnum:]]*)
        # ignore unknown options
        printf "${RED}ERROR: Unknown option : %s${RESET}\n" "$1" >&2
        exit 1
        ;;
    *)
        # Default case: If no more options then break out of the loop.
        break
        ;;
    esac

    shift
done

# Before printing anything else, show the version
printf "Running ${PROGNAME} version ${VERSION}\n"

minimum_debian_version=9
if dpkg --compare-versions "$(cat /etc/debian_version)" lt "${minimum_debian_version}"; then
    echo "This script is not compatible with Debian < ${minimum_debian_version}" >&2
    exit 1
fi

# External mode: overwrite config
if is_ext_mode; then
    listupgrade_state_dir="/var/lib/listupgrade-external"
    listupgrade_sources_dir="/etc/apt/listupgrade-external-sources.list.d"
    listupgrade_sources_file="/dev/null"
fi

# Cleanup commit, without notification
evomaintenance_msg="Broom commit ${PROGNAME}"
if is_dry_run; then
    printf "DRY RUN: %s\n" "evomaintenance '${evomaintenance_msg}'"
else
    printf "${evomaintenance_msg}" | /usr/share/scripts/evomaintenance.sh --no-mail --no-api --no-evocheck >/dev/null
fi

check_alternate_apt_state

upgrade_tmp_dir="/var/log/minor-upgrade/$(date +"%Y%m%d%H%M%S")"
mkdir --parents "${upgrade_tmp_dir}"
chown "root:root" "${upgrade_tmp_dir}"
chmod "0700" "${upgrade_tmp_dir}"

if command -v realpath >/dev/null; then
    upgrade_tmp_dir="$(realpath "${upgrade_tmp_dir}")"
fi
printf "Logs will be stored in '${upgrade_tmp_dir}\`\n"
fix_logs_permissions

system_header="Main system"
# store last update time for later comparison
dpkg_log_updated_at_old=$(stat -c %Y /var/log/dpkg.log)

printf "\n${BLUE}[[[ ${system_header} ]]]${RESET}\n"

# initialize value
apt_exit_code=0

# Try to reclaim disk space by cleaning kernels
old_kernel_autoremoval

# If check_held_packages.sh, launch it to be sure to have hard held packages
if [ -x "/usr/share/scripts/check_held_packages.sh" ] && [ "${nosudopasswd}" -eq "0" ]; then
    /usr/share/scripts/check_held_packages.sh
fi

# Update if wanted.
if [ "${update}" -eq "1" ]; then
    "apt-get" -o Dir::State::Lists="${listupgrade_state_dir}" -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" update
fi

# Print packages to upgrade, with colors
printf "${CYAN}Fetching upgradable packages...${RESET}\n"
upgradable_packages_file=$(get_upgradable_packages)
column -t "${upgradable_packages_file}" | while read -r line; do
    if [ -n "${warning_packages_pattern}" ] && echo "${line}" | grep --quiet --extended-regexp "${warning_packages_pattern}"; then
        printf "${YELLOW}${line}${RESET}\n"
    else
        printf "${line}\n"
    fi
done

pre_hooks "main"

mount -o remount,rw /usr 2>/dev/null
mount -o remount,exec /tmp 2>/dev/null

# Match installed package (ii) without hold (hi)
if dpkg -l "linux-image-amd64" 2>/dev/null | grep --quiet --extended-regexp '^ii'; then
    kernel_meta_package="linux-image-amd64"
    rootfs_free_space_min="250"
elif dpkg -l "linux-image-cloud-amd64" 2>/dev/null | grep --quiet --extended-regexp '^ii'; then
    kernel_meta_package="linux-image-cloud-amd64"
    rootfs_free_space_min="100"
else
    kernel_meta_package=""
    rootfs_free_space_min="0"
fi

# Plan to reinstall kernel if it is upgradable
if [ -n "${kernel_meta_package}" ] && grep --quiet "${kernel_meta_package}" "${upgradable_packages_file}"; then
    reinstall_kernel_meta_package=1
fi

#  Clean linux kernels first (ensure that we won't have disk issues)
if [ "${reinstall_kernel_meta_package}" -eq "1" ]; then
    current_kernel=$(uname --kernel-release)
    all_kernels=$(dpkg --get-selections | tr '\t' ' ' | cut -d" " -f1 | grep '^linux-image-[234567]')
    all_kernels_except_current=$(echo "${all_kernels}" | grep --invert-match "${current_kernel}" | tr '\n' ' ')

    printf "${CYAN}Purging kernel '${current_kernel}\`...${RESET}\n"

    # shellcheck disable=SC2086
    kernel_purge_command="DEBIAN_FRONTEND=noninteractive apt-get -o Dir::State::Lists=${listupgrade_state_dir} -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" --quiet=2 --assume-yes purge ${kernel_meta_package} ${all_kernels_except_current}"
    kernel_purge_stdout="${upgrade_tmp_dir}/kernel.purge.stdout"
    kernel_purge_stderr="${upgrade_tmp_dir}/kernel.purge.stderr"

    if is_dry_run; then
        printf "DRY RUN: %s\n" "${kernel_purge_command}"
        apt_exit_code=0
        kernel_purge_exit_code=0
    else
        eval "${kernel_purge_command} 1>${kernel_purge_stdout} 2>${kernel_purge_stderr}"
        kernel_purge_exit_code=$?

        if [ "${kernel_purge_exit_code}" -ne "0" ]; then
            printf "\n${RED}Error purging kernel: \n"
            printf "${kernel_purge_command}\n"
            head_or_cat "${kernel_purge_stderr}"
            printf "${RESET}"
        fi
    fi
    apt_exit_code="$((apt_exit_code | kernel_purge_exit_code))"
fi

# Upgrade packages

printf "${CYAN}Upgrading packages...${RESET}\n"

main_upgrade_stdout="${upgrade_tmp_dir}/main.upgrade.stdout"
main_upgrade_stderr="${upgrade_tmp_dir}/main.upgrade.stderr"


# shellcheck disable=SC2089
main_upgrade_command="DEBIAN_FRONTEND=noninteractive apt-get -o Dir::State::Lists=${listupgrade_state_dir} -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" -o Dpkg::Options::='--force-confold' --no-download --no-remove upgrade --with-new-pkgs --quiet=2 --assume-yes"

if is_dry_run; then
    printf "DRY RUN: %s\n" "${main_upgrade_command}"
    apt_exit_code="0"
else
    # shellcheck disable=SC2090
    eval "${main_upgrade_command} 1>${main_upgrade_stdout} 2>${main_upgrade_stderr}"
    apt_exit_code="$?"
fi

if [ "${apt_exit_code}" -ne "0" ]; then
    printf "\n${RED}Error upgrading packages: \n"
    printf "${main_upgrade_command}\n"
    head_or_cat "${main_upgrade_stderr}"
    printf "${RESET}"
fi


fix_logs_permissions

# Re-install linux-image-amd64 if previously removed
if [ "${reinstall_kernel_meta_package}" -eq "1" ]; then

    # Install only if we're on an usr-merged system or with more than 250M free on /
    available_space=$(df --block-size=1M --output=avail / | grep --invert-match Avail)
    if [ -L "/lib" ] || [ "${available_space}" -gt "${rootfs_free_space_min}" ]; then
        printf "${CYAN}Reinstalling kernel...${RESET}\n"

        # shellcheck disable=SC2089
        kernel_install_command="DEBIAN_FRONTEND=noninteractive apt-get -o Dir::State::Lists=${listupgrade_state_dir} -o Dir::Etc::sourceparts="${listupgrade_sources_dir}" -o Dir::Etc::sourcelist="${listupgrade_sources_file}" -o Dpkg::Options::='--force-confold' --quiet=2 --assume-yes install ${kernel_meta_package}"
        kernel_install_stdout="${upgrade_tmp_dir}/kernel.install.stdout"
        kernel_install_stderr="${upgrade_tmp_dir}/kernel.install.stderr"

        if is_dry_run; then
            printf "DRY RUN: %s\n" "${kernel_install_command}"
            kernel_install_exit_code="0"
        else
            # shellcheck disable=SC2090
            eval "${kernel_install_command} 1>${kernel_install_stdout} 2>${kernel_install_stderr}"
            kernel_install_exit_code=$?
        fi

        if [ "${kernel_install_exit_code}" -ne "0" ]; then
            printf "\n${RED}Error installing kernel: \n"
            printf "${kernel_install_command}\n"
            head_or_cat "${kernel_install_stderr}"
            printf "${RESET}"
        fi
        apt_exit_code="$((apt_exit_code | kernel_install_exit_code))"
    else
        printf "${RED}WARNING: NOT ENOUGH SPACE FOR NEW KERNELS IN /${RESET}\n"
    fi
    fix_logs_permissions
fi

# Try to reclaim disk space by cleaning kernels, if a kernel has been installed
if is_kernel_changed; then
    old_kernel_autoremoval
fi

# Check if something has been upgraded
dpkg_log_updated_at=$(stat -c %Y /var/log/dpkg.log)
if [ "${dpkg_log_updated_at}" -gt "${dpkg_log_updated_at_old}" ]; then
    updated="1"
fi

# Append to summary
summary="${summary}$(render_system_summary "${system_header}" "${upgrade_tmp_dir}/main.upgrade")"

mount -o remount /usr >/dev/null 2>/dev/null
mount -o remount /tmp >/dev/null 2>/dev/null

# Re-chroot bind if upgraded and if the script is present.
if grep --quiet --extended-regexp "$(date +"%Y-%m-%d") .+ upgrade bind9:amd64 " /var/log/dpkg.log && [ -d /var/chroot-bind/ ]; then
    rechrooted="0"
    for script in /usr/share/scripts/chroot-bind.sh /root/chroot-bind.sh; do
        if [ -x ${script} ]; then
            printf "${CYAN}Re-chrooting bind...${RESET}\n"
            if ${script}; then
                rechrooted="1"
                break
            fi
        fi
    done
    if [ "${rechrooted}" -eq "0" ]; then
        printf "${RED}Chrooting bind failed: no script found!${RESET}\n"
    else
        printf "${GREEN}Chrooting bind done.${RESET}\n"
    fi
fi

# Let's see if some services need to be restarted
# Warning: This is only compatible with systemd
if command -v systemctl > /dev/null; then
    # Only this subset of services are OK to be restarted
    restartable_services="apache2.service nginx.service haproxy.service dovecot.service bind9.service postfix.service postfix@-.service cron.service ssh.service proftpd.service log2mail.service"

    if ! command -v needrestart > /dev/null; then
        printf "${CYAN}Installing needrestart...${RESET}\n"
        if is_dry_run; then
            :
        else
            # Install needrestart
            DEBIAN_FRONTEND=noninteractive apt-get install -y needrestart
            # Disable the DPkg hook if missing
            sed -i "s/^DPkg/#DPkg/" /etc/apt/apt.conf.d/99needrestart
        fi
    fi

    # Use needrestart (in batch mode)
    if command -v needrestart > /dev/null; then
        printf "${CYAN}Checking for services to be restarted...${RESET}\n"
        # Collect services that need to be restarted
        needrestart_services=$(needrestart -bl | grep "NEEDRESTART-SVC:" | awk '{print $2}')
        if [ -n "${needrestart_services}" ]; then
            for service in ${restartable_services}; do
                # Is there any whitelisted service?
                if echo "${needrestart_services}" | grep --quiet "${service}"; then
                    if is_dry_run; then
                        printf "DRY RUN: %s\n" "systemctl restart ${service}"
                    else
                        # Restart the service
                        systemctl restart "${service}"
                        # Display the status
                        SYSTEMD_COLORS=1 systemctl --no-pager status "${service}"
                    fi
                fi
            done
        fi
    elif is_dependent_lib_upgraded && [ "${cleankernels}" -eq "1" ]; then
        # Without needrestart(1), fallback to simpler method
        for service in ${restartable_services}; do
            # Restart the service if active for more than 5 minutes (300s)
            active_timestamp=$(systemctl show "${service}" | grep ActiveEnterTimestampMonotonic | cut -d"=" -f2)
            # shellcheck disable=SC2086
            if [ ${active_timestamp} -ge 300 ]; then
                if is_dry_run; then
                    printf "DRY RUN: %s\n" "systemctl restart ${service}"
                else
                    # Restart the service
                    systemctl restart "${service}"
                    # Display the status
                    SYSTEMD_COLORS=1 systemctl status --no-pager "${service}"
                fi
            fi
        done
    fi
else
    printf "${RED}%s${RESET}\n" "systemctl not found, services won't be restarted"
fi

post_hooks "main"

# Save APT logs for main system
save_apt_logs
fix_logs_permissions

## If server has LXC containers, upgrade them
if which lxc-ls >/dev/null; then
    lxc_path=$(lxc-config lxc.lxcpath)
    if [ "${nosudopasswd}" -eq "0" ]; then
        container_list=$( lxc-ls -1 --active | grep --invert-match --regexp php56 --regexp php70 )
        for container_name in ${container_list}; do
            if lxc-info --name "${container_name}" > /dev/null; then
                system_header="LXC ${container_name}"

                container_rootfs="${lxc_path}/${container_name}/rootfs"

                # store last update time for later comparison
                if [ -f "${container_rootfs}/var/log/dpkg.log" ]; then
                    dpkg_log_updated_at_old=$(stat -c %Y "${container_rootfs}/var/log/dpkg.log")
                fi

                printf "\n${BLUE}[[[ ${system_header} ]]]${RESET}\n"

                # Print packages to upgrade, with colors
                printf "${CYAN}Fetching upgradable packages...${RESET}\n"
                upgradable_packages_file=$(get_upgradable_packages_container "${container_name}")
                cat "${upgradable_packages_file}" | column -t | while read -r line; do
                    if [ -n "${warning_packages_pattern}" ] && echo "${line}" | grep --quiet --extended-regexp "${warning_packages_pattern}"; then
                        printf "${YELLOW}${line}${RESET}\n"
                    else
                        printf "${line}\n"
                    fi
                done

                printf "${CYAN}Upgrading packages...${RESET}\n"

                # shellcheck disable=SC2089
                lxc_command="lxc-attach --name ${container_name} --set-var DEBIAN_FRONTEND=noninteractive -- apt-get -o Dir::State::Lists=${listupgrade_state_dir} -o Dpkg::Options::='--force-confold' --no-download --no-remove upgrade --with-new-pkgs --quiet=2 --assume-yes"
                lxc_stdout="${upgrade_tmp_dir}/lxc-${container_name}.stdout"
                lxc_stderr="${upgrade_tmp_dir}/lxc-${container_name}.stderr"


                if is_dry_run; then
                    printf "DRY RUN: %s\n" "${lxc_command}"
                    apt_exit_code="0"
                else
                    # shellcheck disable=SC2090
                    eval "${lxc_command} 1>${lxc_stdout} 2>${lxc_stderr}"
                    apt_exit_code=$?
                fi

                if [ "${apt_exit_code}" -ne "0" ]; then
                    printf "\n${RED}Error upgrading packages: \n"
                    printf "${lxc_command}\n"
                    head_or_cat "${lxc_stderr}"
                    printf "${RESET}"
                fi

                # Save APT logs for LXC container
                save_apt_logs "${container_name}"
                fix_logs_permissions

                # Check if something has been upgraded
                if [ -f "/var/lib/lxc/${container_name}/rootfs/var/log/dpkg.log" ]; then
                    dpkg_log_updated_at=$(stat -c %Y "/var/lib/lxc/${container_name}/rootfs/var/log/dpkg.log")
                    if [ "${dpkg_log_updated_at}" -gt "${dpkg_log_updated_at_old}" ]; then
                        updated="1"
                    fi
                fi

                # Append to summary
                summary="${summary}$(render_system_summary "${system_header}" "${upgrade_tmp_dir}/lxc-${container_name}")"
            fi
        done
    else
        summary="${summary}${RED}Containers detected\tCan't update them without sudo${RESET}\n"
    fi
fi

if [ "${updated}" -gt "0" ]; then
    evomaintenance_msg="Mise à jour de sécurité"
    if is_dry_run; then
        printf "DRY RUN: %s\n" "evomaintenance '${evomaintenance_msg}'"
    else
        printf "${evomaintenance_msg}" | /usr/share/scripts/evomaintenance.sh --no-evocheck >/dev/null
    fi
fi


printf "\n${MAGENTA}##### Summary #####${RESET}\n"
printf "${summary}"

# Quick view of some monitoring checks
if [ "${nosudopasswd}" -eq "0" ]; then
    printf "\n"

    #display_check_status "check_disk1" "DISK "
    #display_check_status "check_mailq" "MAILQ"
    #[ -e "/usr/sbin/mysqld" ] && display_check_status "check_mysql" "MYSQL"
    #[ -e "/usr/bin/pg_ctlcluster" ] && display_check_status "check_pgsql" "PGSQL"

    #printf "\n"

    #([ -e "/usr/sbin/nginx" ] || [ -e "/usr/sbin/apachectl" ]) && display_check_status "_http]" "HTTP "
    #[ -e "/usr/share/elasticsearch/bin/elasticsearch" ] && display_check_status "check_elasticsearch" "ELAST"
    #[ -e "/usr/bin/redis-server" ] && display_check_status "redis]" "REDIS"

    #printf "\n"
fi

# Cleanup commit, without notification
evomaintenance_msg="Broom commit after ${PROGNAME}"
if is_dry_run; then
    printf "DRY RUN: %s\n" "evomaintenance '${evomaintenance_msg}'"
else
    printf "${evomaintenance_msg}" | /usr/share/scripts/evomaintenance.sh --no-mail --no-api --no-evocheck >/dev/null
fi
