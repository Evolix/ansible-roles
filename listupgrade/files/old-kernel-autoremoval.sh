#!/bin/sh

# Repository: https://gitea.evolix.org/evolix/maj.sh/

# fork by reg from /etc/kernel/postinst.d/apt-auto-removal script

VERSION="24.01"
readonly VERSION

PROGNAME=$(basename "$0")

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2024 Evolix <info@evolix.fr>,
               Gregory Colpart <reg@evolix.fr>,
               Romain Dessort <rdessort@evolix.fr>,
               Ludovic Poujol <lpoujol@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public Licence for details.
END
}
show_help() {
    cat <<END
${PROGNAME} removes old kernels.

Options
 -h, --help                  print this message and exit
     --version               print version and exit
END
}

# Detect which one of apt/aptitude we should use.
# shellcheck disable=SC2120
get_apt_binary() {
    root="${1:-}"
    # apt could be a Java binary...
    if [ -x "${root}/usr/bin/apt" ] && ! ${root}/usr/bin/apt --version 2>&1 | grep -q "javac"; then
        echo "apt"
    elif [ -x "${root}/usr/bin/aptitude" ]; then
        echo "aptitude"
    # Usually in containers
    else
        echo "apt-get"
    fi
}

main() {
    specifc_kernel="$1"

    # shellcheck disable=SC2046
    eval $(apt-config shell DPKG Dir::bin::dpkg/f)
    DPKG="${DPKG:-/usr/bin/dpkg}"

    listupgrade_state_dir="${listupgrade_state_dir:-/var/lib/listupgrade}"

    APT=$(get_apt_binary)

    list="$("${DPKG}" -l | awk '/^[ih][^nc][ ]+(linux|kfreebsd|gnumach)-image-[0-9]+\./ && $2 !~ /-dbg(:.*)?$/ && $2 !~ /-dbgsym(:.*)?$/ { print $2,$3; }' \
    | sed -e 's#^\(linux\|kfreebsd\|gnumach\)-image-##' -e 's#:[^:]\+ # #')"
    debverlist="$(echo "${list}" | cut -d' ' -f 2 | sort --unique --reverse --version-sort)"

    if [ -n "${specifc_kernel}" ]; then
        installed_version="$(echo "$list" | awk "\$1 == \"${specifc_kernel}\" { print \$2;exit; }")"
    fi
    unamer="$(uname -r | tr '[:upper:]' '[:lower:]')"
    if [ -n "${unamer}" ]; then
        running_version="$(echo "${list}" | awk "\$1 == \"${unamer}\" { print \$2;exit; }")"
    fi
    # ignore the currently running version if attempting a reproducible build
    if [ -n "${SOURCE_DATE_EPOCH}" ]; then
        unamer=""
        running_version=""
    fi
    latest_version="$(echo "${debverlist}" | sed -n 1p)"
    previous_version="$(echo "${debverlist}" | sed -n 2p)"

    debkernels="$(echo "${latest_version}
    ${installed_version}
    ${running_version}" | sort -u | sed -e '/^$/ d')"
    kernels="$( (echo "${specifc_kernel}
    ${unamer}"; for deb in ${debkernels}; do echo "${list}" | awk "\$2 == \"${deb}\" { print \$1; }"; done; ) \
    | sed -e 's#\([\.\+]\)#\\\1#g' -e '/^$/ d' | sort -u|tr '\n' '|' | sed -e 's/|$//')"


    echo "
    List of installed kernel packages:
    $list

    # Running kernel: ${running_version:-ignored} (${unamer:-ignored})
    # Last kernel: ${latest_version}
    # Previous kernel: ${previous_version}
    # Kernel versions list to keep:
    ${debkernels}

    # Kernel packages (version part) to protect:
    ${kernels}
    "

    echo "BEFORE"
    dpkg -l | grep linux-image

    dpkg --get-selections | tr '\t' ' ' | cut -d" " -f1 | grep '^linux-image-[0-9]' | grep -v -E "(${kernels})" | xargs --no-run-if-empty ${APT} -o Dir::State::Lists="${listupgrade_state_dir}" -y purge

    echo "
    AFTER"
    dpkg -l | grep linux-image
    echo ""

}

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

set -e


main "${@}"
