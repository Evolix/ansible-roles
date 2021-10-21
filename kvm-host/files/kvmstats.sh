#!/bin/sh

VERSION="21.10"

error () {
    echo "$0": "$@" >&2
    exit 1
}

usage () {
    echo 'usage:' "$0" '[-a] [-u k|m|g] [-o human|html|csv]' >&2
    exit 1
}

for DEP in bc virsh
do
    command -v "$DEP" > /dev/null || error "$DEP" 'command not found'
done

POW="$(echo '1024 ^ 3' | bc)"
FMT='human'
while [ "$#" -ne 0 ]
do
    case "$1" in
    '-a')
        SHOW_AVAIL='y'
        ;;
    '-o')
        case "$2" in
        'csv'|'html'|'human')
            FMT="$2"
            ;;
        *)
            usage
            ;;
        esac
        shift
        ;;
    '-u')
        case "$2" in
        'k')
            POW="$(echo '1024 ^ 1' | bc)"
            ;;
        'm')
            POW="$(echo '1024 ^ 2' | bc)"
            ;;
        'g')
            POW="$(echo '1024 ^ 3' | bc)"
            ;;
        *)
            usage
        esac
        shift
        ;;
    *)
        usage
    esac
    shift
done

for VM in $(virsh list --name --all)
do
    echo "$VM"

    # cpu
    virsh vcpucount --current "$VM"

    # mem
    # libvirt stores memory in KiB, POW must be lowered by 1
    virsh dommemstat "$VM" 2>/dev/null | awk 'BEGIN{ret=1}$1~/^actual$/{print $2 / '$((POW / 1024))';ret=0}END{exit ret}' ||
        virsh dumpxml "$VM" | awk -F'[<>]' '$2~/^memory unit/{print $3/'$((POW / 1024))'}'

    # disk
    for BLK in $(virsh domblklist "$VM" | sed '1,2d;/-$/d;/^$/d' | awk '{print $1}')
    do
        virsh domblkinfo "$VM" "$BLK" 2>/dev/null
    done | awk '/Physical:/ { size += $2 } END { print int(size / '${POW}') }'

    # state
    virsh domstate "$VM" | grep -q '^running$' && echo yes || echo no
done | xargs -n5 | {
    echo vm vcpu ram disk running
    awk '{ print } /yes$/ { vcpu += $2; ram += $3; disk += $4; running++ } END { print "TOTAL(running)", vcpu, ram, disk, running }'
    test "$SHOW_AVAIL" && {
        nproc
        awk '/^MemTotal:/ { print int($2 / '$((POW / 1024))' ) }' /proc/meminfo
    } | xargs -r printf 'AVAILABLE %s %s %s %s\n'
} | case "$FMT" in
'human')
    column -t
    ;;
'html')
    awk 'BEGIN{print "<html><body>\n<table>"}{printf "<tr>";for(i=1;i<=NF;i++)printf "<td>%s</td>", $i;print "</tr>"}END{print "</table>\n</body></html>"}'
    ;;
'csv')
    tr ' ' ','
    ;;
esac
