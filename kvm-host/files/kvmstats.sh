#!/bin/sh

# NOTE: kvmstats relies on the hxselect(1) command to parse virsh' xml
# files. On Debian, this command is provided by the 'html-xml-utils'
# package.

set -e -u

usage () {
    echo 'usage: kvmstats.sh [-a] [-u K|M|G]'
    exit 1
}

for DEP in hxselect lvs tempfile bc
do
    if [ -z "$(which $DEP)" ]
    then
        echo "kvmstats.sh: $DEP not found in \$PATH" 1>&2
        exit 1
    fi
done

POW=$(echo 1024 ^ 3 | bc)
while [ $# -ne 0 ] && echo "$1" | grep -q '^-[[:alnum:]]'
do
    case $1 in
    '-u')
        case $2 in
        'K')
            POW=$(echo 1024 ^ 1 | bc)
            ;;
        'M')
            POW=$(echo 1024 ^ 2 | bc)
            ;;
        'G')
            POW=$(echo 1024 ^ 3 | bc)
            ;;
        *)
            usage
        esac
        ;;
    '-a')
        SHOW_AVAIL=y
        ;;
    *)
        usage
    esac
    shift
done

# since libvirt seems to store memoy in KiB, POW must be lowered by 1
POW=$((POW / 1024))

TMPFILE=$(tempfile -s kvmstats)
LVSOUT=$(tempfile -s kvmstats)

lvs --units b --nosuffix >"$LVSOUT"

for VM in $(virsh list --all --name)
do
    VCPU=$(hxselect -c 'domain vcpu' </etc/libvirt/qemu/"$VM.xml")
    RAM_KIB=$(hxselect -c 'domain memory' </etc/libvirt/qemu/"$VM.xml")
    RAM=$((RAM_KIB / POW))
    for DEV in $(hxselect -s'\n' 'domain devices disk[device=disk] source' </etc/libvirt/qemu/"$VM.xml" | cut -d\" -f2)
    do
        case $DEV in
        /dev/drbd/*)
            DISK=$(awk "/$VM/ { ans += \$NF } END { print ans / 1024 ^ 3 }" <"$LVSOUT")
            break # avoid to compute DISK for each disk
            ;;
        *.qcow2)
            DISK=$(du -sBG "$DEV" | awk '{ print substr($1, 0, length($1) - 1) }')
            ;;
        *)
            DISK=0
            esac
    done
    RUNNING=$(virsh domstate "$VM" | grep -q '^running$' && echo yes || echo no)
    echo "$VM" "$VCPU" "$RAM" "$DISK" "$RUNNING"
done >"$TMPFILE"

(
    echo vm vcpu ram disk running
    cat "$TMPFILE"
    awk '/yes$/ { vcpu += $2; ram += $3; disk += $4; running++ } END { print "TOTAL(running)", vcpu, ram, disk, running }' <"$TMPFILE"
    if [ $SHOW_AVAIL ]
    then
        AV_CPU=$(awk '/^processor/ { cpu++ } END { print cpu }' /proc/cpuinfo)
        AV_MEM=$(awk '/^MemTotal:/ { print int($2 / 1024 ^ 2) }' /proc/meminfo)
        echo AVAILABLE "$AV_CPU" "$AV_MEM"
    fi
) | column -t

rm "$TMPFILE" "$LVSOUT"
