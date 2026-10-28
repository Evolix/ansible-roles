#!/bin/sh

# Repository: https://gitea.evolix.org/evolix/maj.sh/

# fork by reg from /etc/kernel/postinst.d/apt-auto-removal script

# Notes abour Proxmox kernels:
# * They are referenced as *-pve or *-pve-signed, we have to deal with it
# * We must keep "proxmox-kernel-*" meta-packages,
#   and remove only regular "proxmox-kernel-*-pve-signed" packages

VERSION="26.09"
readonly VERSION

PROGNAME=$(basename "$0")

show_version() {
    cat <<END
${PROGNAME} version ${VERSION}

Copyright 2018-2026 Evolix <info@evolix.fr>,
               Gregory Colpart <reg@evolix.fr>,
               Romain Dessort <rdessort@evolix.fr>,
               Ludovic Poujol <lpoujol@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>
               and others.

${PROGNAME} comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under
certain conditions. See the GNU General Public Licence for details.
END
}
show_help() {
    cat <<END
${PROGNAME} removes old kernels.

Options
 -h, --help                  print this message and exit
 -n, --dry-run               actions are not executed
     --version               print version and exit
END
}

# Detect which one of apt/aptitude we should use.
# shellcheck disable=SC2120
get_apt_binary() {
    root="${1:-}"
    # apt could be a Java binary...
    if [ -x "${root}/usr/bin/apt" ] && ! ${root}/usr/bin/apt --version 2>&1 | grep --quiet "javac"; then
        echo "apt"
    elif [ -x "${root}/usr/bin/aptitude" ]; then
        echo "aptitude"
    # Usually in containers
    else
        echo "apt-get"
    fi
}
is_dry_run() {
    test "${DRY_RUN}" -eq 1
}
print_kernels() {
    "${DPKG}" -l | grep --extended-regexp --regexp "(linux|kfreebsd|gnumach)-image" --regexp proxmox-kernel
}

main() {
    specific_kernel="$1"

    DPKG="/usr/bin/dpkg"
    # shellcheck disable=SC2046
    eval $(apt-config shell DPKG Dir::bin::dpkg/f)

    listupgrade_state_dir="${listupgrade_state_dir:-/var/lib/listupgrade}"

    APT=$(get_apt_binary)


    list="$( \
        "${DPKG}" -l | awk '/^[ih][^nc][ ]+((linux|kfreebsd|gnumach)-image-[0-9]+\.|(proxmox-kernel-[0-9\.-]+-pve))/ && $2 !~ /-dbg(:.*)?$/ && $2 !~ /-dbgsym(:.*)?$/ { print $2,$3; }' \
            | sed -e 's#^\(linux\|kfreebsd\|gnumach\)-image-##' -e 's#^proxmox-kernel-##' -e 's#:[^:]\+ # #'
    )"
    debverlist="$(echo "${list}" | cut -d' ' -f 2 | sort --unique --reverse --version-sort)"

    if [ -n "${specific_kernel}" ]; then
        installed_version="$(echo "$list" | awk "\$1 == \"${specific_kernel}\" || \$1 == \"${specific_kernel}-signed\" { print \$2;exit; }")"
    fi
    unamer="$(uname -r | tr '[:upper:]' '[:lower:]')"
    if [ -n "${unamer}" ]; then
        running_version="$(echo "${list}" | awk "\$1 == \"${unamer}\" || \$1 == \"${unamer}-signed\" { print \$2;exit; }")"
    fi
    # ignore the currently running version if attempting a reproducible build
    if [ -n "${SOURCE_DATE_EPOCH}" ]; then
        unamer=""
        running_version=""
    fi

    latest_version="$(echo "${debverlist}" | sed -n 1p)"
    previous_version="$(echo "${debverlist}" | sed -n 2p)"
    debkernels="$(printf "%s\n%s\n%s\n" "${latest_version}" "${installed_version}" "${running_version}" | sort -u | sed -e '/^$/ d')"
    kernels="$( \
        ( \
            printf "%s\n%s\n" "${specific_kernel}" "${unamer}"; \
            for deb in ${debkernels}; do echo "${list}" | awk "\$2 == \"${deb}\" { print \$1; }"; done; \
        ) \
            | sed -e 's#\([\.\+]\)#\\\1#g' -e '/^$/ d' | sort -u | tr '\n' '|' | sed -e 's/|$//'\
    )"


    cat << EOF
List of installed kernel packages:
$list

# Running kernel: ${running_version:-ignored} (${unamer:-ignored})
# Last kernel: ${latest_version}
# Previous kernel: ${previous_version}
# Kernel versions list to keep:
${debkernels}

# Kernel packages (version part) to protect:
${kernels}
EOF

    echo ""
    echo "BEFORE"
    print_kernels

    set +e
    to_be_removed=$( \
        "${DPKG}" --get-selections | tr '\t' ' ' | cut -d" " -f1 \
            | grep --extended-regexp --regexp '^linux-image-[0-9]' --regexp '^proxmox-kernel-[0-9\.-]+-pve' \
            | grep --invert-match --extended-regexp "(${kernels})" \
    )
    set -e

    echo ""
    if [ -n "${to_be_removed}" ]; then
        if is_dry_run; then
            echo "To be removed (DRY RUN):"
            echo "${to_be_removed}"
        else
            echo "${to_be_removed}" | xargs --no-run-if-empty "${APT}" -o Dir::State::Lists="${listupgrade_state_dir}" -y purge
        fi
    else
        echo "Nothing to remove"
    fi

    echo ""
    echo "AFTER"
    print_kernels
    echo ""

}

DRY_RUN=${DRY_RUN:-0}

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
        -n|--dry-run)
            DRY_RUN=1
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
