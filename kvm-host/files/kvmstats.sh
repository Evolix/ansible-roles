#!/bin/sh

VERSION="21.10"

PROGNAME=$(basename "$0")

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2021 Evolix <info@evolix.fr>,
               Alexis Ben Miloud--Josselin <abenmiloud@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}

show_help() {
    cat <<END
${PROGNAME} print stats about configured virtal servers

END
    show_usage
}
show_usage() {
    cat <<END
Usage: ${PROGNAME} --all
  or   ${PROGNAME} --output <human|html|csv>
  or   ${PROGNAME} --units <k|m|g>
END
}

error () {
    echo "$0": "$@" >&2
    exit 1
}

main() {
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
}

parse_units() {
    case "$1" in
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
        printf 'ERROR: Unknown unit value: %s. Possible values: %s\n' "$1" "k, m, g" >&2
        echo "" >&2
        show_usage >&2
        exit 1
        ;;
    esac 
}
parse_output() {
    case "$1" in
    'csv'|'html'|'human')
        FMT="$1"
        ;;
    *)
        printf 'ERROR: Unknown output value : %s. Possible values: %s\n' "$1" "csv, html, human" >&2
        echo "" >&2
        show_usage >&2
        exit 1
        ;;
    esac
}

# Check dependencies
for DEP in bc virsh
do
    command -v "$DEP" > /dev/null || error "$DEP" 'command not found'
done

# default values
POW="$(echo '1024 ^ 3' | bc)"
FMT='human'

# Parse options
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
        -a|--all)
            SHOW_AVAIL='y'
            ;;
        -u|--units)
            # with value separated by space
            if [ -n "$2" ]; then
                parse_units "$2"
                shift
            else
                printf 'ERROR: "-u|--units" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --units=?*)
            # with value speparated by =
            parse_units ${1#*=}
            ;;
        --units=)
            # without value
            printf 'ERROR: "--units" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        -o|--output)
            # with value separated by space
            if [ -n "$2" ]; then
                parse_output "$2"
                shift
            else
                printf 'ERROR: "-o|--output" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --output=?*)
            # with value speparated by =
            parse_output ${1#*=}
            ;;
        --output=)
            # without value
            printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
            exit 1
            ;;

        --)
            # End of all options.
            shift
            break
            ;;
        -?*|[[:alnum:]]*)
            # ignore unknown options
            printf 'ERROR: Unknown option : %s\n' "$1" >&2
            echo "" >&2
            show_usage >&2
            exit 1
            ;;
        *)
            # Default case: If no more options then break out of the loop.
            break
            ;;
    esac

    shift
done

main

