#!/bin/bash
#
# Thin wrapper around mmdebstrap to build system portable services images.

# Definitions of terms used:
# - definition: directory containing configurations used to generate a system
# - target: the OS tree generated from a definition

# TODO write a --help
# TODO write a --keep-faild

set -u

error() {
    printf '%s: error: %s\n' "$0" "$*" 1>&2
    exit 1
}

usage() {
    printf 'usage: %s [--verbose|-v] DEFINITION\n' "$0" 1>&2
    exit 1
}

list_definitions() {
    find "$definitions_dir" -mindepth 1 -maxdepth 1 -type d
}

list_systems() {
    find "$systems_dir" -mindepth 1 -maxdepth 1 -type d
}

# FIXME Should it be configurable?
definitions_dir=/etc/evo-mmdebstrap/
systems_dir=/var/lib/portables/

timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
packages=''
variant=essential

# Declaring some variables
mmdebstrap_stdout=/dev/null
definition_name=
suite=
keep_failed=false

test "$#" -eq 0 &&  usage
for i in $(seq $#); do
#while test "$#" -ne 0; do
#    echo $i: ${@:i:1}
    # XXX Bashism to get the nth argument
    case ${@:i:1} in
## Commands of evo-mmdebstrap
    --list-definitions)
        list_definitions
        exit
        ;;
    --list-systems)
        list_systems
        exit
        ;;
## Options specific to evo-mmdebstrap, not known by mmdebstrap
    --keep-failed)
        keep_failed=true
        set -- "${@:1:i-1}" "${@:i+1}"
        i=$((i+1))
        ;;
    -v|--verbose)
        mmdebstrap_stdout=/dev/stderr
        set -- "${@:1:i-1}" "${@:i+1}"
        i=$((i+1))
        ;;
## Arguments of evo-mmdebstrap
    *)
        case "$1" in  [!-][!-]*)
            test -n "$definition_name" && error too many arguments
            definition_name=$1
            set -- "${@:1:i-1}" "${@:i+1}"
            i=$((i+1))
        esac
    esac
done
test -z "$definition_name" && error need one argument

definition_dir="$definitions_dir/$definition_name/"
# NOTE a .v directory, see systemd.v(7)
dotvdir="${systems_dir}${definition_name}.v/"
# NOTE directory name is in systemd.v(7) format
target="${dotvdir}/${definition_name}_${timestamp}"

if [ -d "$definition_dir/config.d" ]; then
    for config in "$definition_dir/config.d/"*; do
        . "$config"
    done
fi

if ! [ -d "$dotvdir" ]; then
    mkdir -p "$dotvdir"
fi

cleanup() {
    test -d "$target" && rm -r "$target"
}
trap cleanup INT

# Create OS tree
export EVO_IMAGE_NAME="$definition_name"
export EVO_IMAGE_TIMESTAMP="$timestamp"
mmdebstrap \
    --hook-dir=/usr/share/mmdebstrap/hooks/maybe-jessie-or-older \
    --hook-dir="$definition_dir/hooks.d" \
    --setup-hook="sync-in ${definition_dir}/skeleton/ /" \
    --customize-hook="${customize_special_hook:-true}" \
    --mode="${mode:-auto}" \
    --include="$packages" \
    --variant="$variant" \
    --logfile="$mmdebstrap_stdout" \
    $@ \
    "$suite" "$target" \
    2>&1 >"$mmdebstrap_stdout"

if [ $? -eq 0 ]; then
    echo "$target"
else
    test "$keep_failed" = false && cleanup
fi
