#!/bin/bash

# shellcheck disable=SC2120

#######################################################################
# This set of functions helps determining the version of the OS
#######################################################################
#
# Copyright 2009-2025 Evolix <info@evolix.fr>,
#                     Jérémy Lecour <jlecour@evolix.fr>,
#                     and others.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#######################################################################

VERSION="1.0.0"

evo::os-release::version() {
    echo "${VERSION}"
}

#######################################
# Parses the os-release(5) file and adds a prefix to the variables
# Globals:
#   OS_RELEASE_PATH (read): load this instead of /etc/os-release
# Arguments:
#   none
# Outputs:
#   content of the file, with variables prefixed with "OS_RELEASE_*"
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::parse() {
    if ! command -v sed >/dev/null; then
        >&2 echo "sed: command not found"
        exit 2
    fi

    if [ -z "${OS_RELEASE_PATH}" ]; then
        # Try /etc/os-release first, then fall back to /usr/local/os-release 
        test -e /etc/os-release && OS_RELEASE_PATH='/etc/os-release' || OS_RELEASE_PATH='/usr/lib/os-release'
    fi
    if [ ! -r "${OS_RELEASE_PATH}" ]; then
        >&2 echo "${OS_RELEASE_PATH} does not exist or is not readable"
        return 1
    fi

    # According to os-release(5), the file can be sourced in a shell script.
    # To prevent variable names collisions, we prefix them with "OS_RELEASE_".
    # shellcheck disable=SC1090
    sed -e 's/^\([A-Z_]\+=\)/OS_RELEASE_\1/' "${OS_RELEASE_PATH}"
}

#######################################
# Tells if the current OS is Debian
# Globals:
#   none
# Arguments:
#   version : numeric or Debian codename (optional)
#   operator : [lt le eq ne ge gt] (optional)
# Outputs:
#   none
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::is_debian() {
    local version=
    local operator=

    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    if [ "${OS_RELEASE_ID:-}" != "debian" ]; then
        return 1
    fi

    # NOTE: DPkg discourages arithmetic operator.
    # We support them, but transform them before calling DPkg
    if [ $# -ge 2 ]; then
        version=${1}
        case ${2} in
            lt | le | eq | ne | ge | gt)
                operator=${2}
                ;;
            "<")
                operator="lt"
                ;;
            "<=")
                operator="le"
                ;;
            "=" | "==")
                operator="eq"
                ;;
            "!=")
                operator="ne"
                ;;
            ">=")
                operator="ge"
                ;;
            ">")
                operator="gt"
                ;;
            *)
                >&2 echo "operator '${2}' not in accepted values (lt, le, eq, ne, ge, gt)"
                exit 1
                ;;
        esac
    elif [ $# -eq 1 ]; then
        version=${1}
        operator="eq"
    else
        test "${OS_RELEASE_ID}" = "debian"
        return $?
    fi

    # force lowercase
    case "${version,,}" in
        wheezy)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 7
            ;;
        jessie)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 8
            ;;
        stretch)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 9
            ;;
        buster)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 10
            ;;
        bullseye)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 11
            ;;
        bookworm)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 12
            ;;
        trixie)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 13
            ;;
        forky)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 14
            ;;
        duke)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" 15
            ;;
        *)
            dpkg --compare-versions "${OS_RELEASE_VERSION_ID}" "${operator}" "${version}"
            ;;
    esac
}

#######################################
# Tells the current OS ID
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_ID
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_id() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_ID}"
}

#######################################
# Tells the current OS VERSION_ID
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_VERSION_ID
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_version_id() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_VERSION_ID}"
}

#######################################
# Tells the current OS VERSION_CODENAME
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_VERSION_CODENAME
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_version_codename() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_VERSION_CODENAME}"
}

#######################################
# Tells the current OS VERSION
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_VERSION
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_version() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_VERSION}"
}

#######################################
# Tells the current OS PRETTY_NAME
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_PRETTY_NAME
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_pretty_name() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_PRETTY_NAME}"
}

#######################################
# Tells the current OS NAME
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   OS_RELEASE_NAME
# Returns:
#   0 on success, 1 on failure 
#######################################
evo::os-release::get_name() {
    if [ -z "${OS_RELEASE_NAME:-}" ]; then
        # shellcheck disable=SC1090
        . <( evo::os-release::parse )
    fi

    echo "${OS_RELEASE_NAME}"
}
