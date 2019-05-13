#!/bin/sh

is_held() {
    package=$1

    apt-mark showhold ${package} | grep --silent ${package}
}

config_file="/etc/evolinux/apt_hold_packages.cf"
return_code=0

if [ -f ${config_file} ]; then
    packages="$(cat ${config_file})"

    if [ -n "${packages}" ]; then
        for package in ${packages}; do
            if [ -n "${package}" ]; then
                if ! is_held ${package}; then
                    apt-mark hold ${package}
                    >&2 echo "Package \`${package}' has been marked \`hold'."
                    return_code=1
                fi
            fi
        done
    fi
fi

exit ${return_code}
