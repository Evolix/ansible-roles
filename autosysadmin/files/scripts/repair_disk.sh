#!/bin/bash

# Source functions file
# shellcheck source=./functions.sh
source /usr/share/scripts/autosysadmin/functions.sh

init_autosysadmin
load_conf

test "${repair_disk:=off}" = off && log_error_exit 'Script disabled, nothing to do here!'

# Has it recently been run?
is_too_soon

lockfile="/run/lock/repair_disk"
cleanup() {
    rm -f "${lockfile}"
}
trap 'cleanup' 0
acquire_lock_or_exit "${lockfile}"

ensure_no_active_users_or_exit

# The actual work starts below !

get_mountpoints() {
    # the $(...) get the check_disk1 command
    # the cut command selects the critical part of the check_disk1 output
    # the grep command extracts the mountpoints and available disk space
    # the last cut command selects the mountpoints
    $(grep check_disk1 /etc/nagios/nrpe.d/evolix.cfg | cut -d'=' -f2-) -e | cut -d'|' -f1 | grep -Eo '/[[:graph:]]* [0-9]+ [A-Z][A-Z]' | cut -f1 -d' '
}

is_reserved-blocks() {
    fs_type="$(findmnt -n --output=fstype "$1")"
    if [ "${fs_type}" = "ext4" ];
    then
        device="$(findmnt -n --output=source "$1")"
        reserved_block_count="$(tune2fs -l "${device}" | grep 'Reserved block count' | awk -F':' '{ gsub (" ", "", $0); print $2}')"
        block_count="$(tune2fs -l "${device}" | grep 'Block count' | awk -F':' '{ gsub (" ", "", $0); print $2}')"
        percentage=$(awk "BEGIN { pc=100*${reserved_block_count}/${block_count}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

        log "Reserved blocks for $1 is curently at $percentage%"
        if [ "${percentage}" -gt "1" ]
        then
            log "Allowing tune2fs action to reduce the number of reserved blocks"
            return 0
        else
            log "Reserved blocks already at or bellow 1%, no automatic action possible"
            return 1
        fi
    else
        log "Filesystem for $1 partition is not ext4"

        return 1
    fi
}

change_reserved-blocks() {
    # We alwasy keep some reserved blocks to avoid missing some logs
    # https://gitea.evolix.org/evolix/autosysadmin/issues/22
    tune2fs -m 1 "$(findmnt -n --output=source "$1")"
    log_action "Reserved blocks for $1 changed to 1 percent"
}

is_tmp_to_delete() {
    size="$(find /var/log/ -type f -ctime +1 -exec du {} \+ | awk '{s+=$1}END{print s / 1024}')"
    if [ -n "${size}" ]
    then
        return 0
    else
        return 1
    fi
}

is_log_to_delete() {
    size="$(find /var/log/ -type f -mtime +365 -exec du {} \+ | awk '{s+=$1}END{print s / 1024}')"
    if [ -n "${size}" ]
    then
        return 0
    else
        return 1
    fi
}

clean_apt_cache() {
    for lxc in $(du -ax /var | sort -nr | head -n10 | grep -E '/var/lib/lxc/php[0-9]+/rootfs/var/cache$' | grep -Eo 'php[0-9]+')
    do
        lxc-attach --name "${lxc}" -- apt-get clean
        log_action '[lxc/'"${lxc}"'] Clean apt cache'
    done
    case "$(du -sx /var/* | sort -rn | sed 's/^[0-9]\+[[:space:]]\+//;q')" in
    '/var/cache')
        apt-get clean
        log_action 'Clean apt cache'
        ;;
    esac
}

clean_amavis_virusmails() {
    if du --inodes /var/lib/* | sort -n | tail -n3 | grep -q 'virusmails$'
    then
        find /var/lib/amavis/virusmails/ -type f -atime +30 -delete
        log_action 'Clean /var/lib/amavis/virusmails'
    fi
}

for mountpoint in $(get_mountpoints)
do
    case "${mountpoint}" in
    /var)
        #if is_log_to_delete
        #then
        #    find /var/log/ -type f -mtime +365 -delete
        #    log_action "$size Mo of disk space freed in /var"
        #fi
        if is_reserved-blocks /var
        then
            change_reserved-blocks /var
            clean_apt_cache
            clean_amavis_virusmails
            hook_mail success
        fi
        ;;
    /tmp)
        #if is_tmp_to_delete
        #then
        #    find /tmp/ -type f -ctime +1 -delete
        #    log_action "$size Mo of disk space freed in /tmp"
        #fi
        if is_reserved-blocks /tmp
        then
            change_reserved-blocks /tmp
            hook_mail success
        fi
        ;;
    /home)
        if is_reserved-blocks /home
        then
            change_reserved-blocks /home
            hook_mail success
        fi
        ;;
    /srv)
        if is_reserved-blocks /srv
        then
            change_reserved-blocks /srv
            hook_mail success
        fi
        ;;
    /filer)
        if is_reserved-blocks /filer
        then
            change_reserved-blocks /filer
            hook_mail success
        fi
        ;;
    /)
        if is_reserved-blocks /
        then
            change_reserved-blocks /
            hook_mail success
            # Suggest remove old kernel ?
        fi
        ;;
    *)
        # unknown
        log 'Unknown partition (or weird case) or nothing to do'
        ;;
    esac
done

AUTOSYSADMIN=1 /usr/share/scripts/evomaintenance.sh -m "$0: done" --no-commit --no-mail
