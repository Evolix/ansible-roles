#!/bin/sh

is_held() {
    package=$1
    apt-mark showhold ${package} | grep --silent ${package}
}

is_installed() {
    package=$1
    dpkg -l "${package}" 2>/dev/null | grep -q -E '^(i|h)i'
}

config_file="/etc/evolinux/apt_hold_packages.cf"
return_code=0

if [ -f ${config_file} ]; then
    packages="$(cat ${config_file})"

    if [ -n "${packages}" ]; then
        for package in ${packages}; do
            if [ -n "${package}" ]; then
                if is_installed ${package} && ! is_held ${package}; then
                    apt-mark hold ${package}
                    msg="Package \`${package}' has been marked \`hold'."
                    >&2 echo "${msg}"
                    wall_bin=$(command -v wall)
                    if [ -n "${wall_bin}" ]; then
                        "${wall_bin}" --timeout 5 "${msg}"
                    fi
                    return_code=1
                fi
            fi
        done
    fi
fi

exit ${return_code}
