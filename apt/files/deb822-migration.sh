#!/bin/sh

deb822_migrate_script=$(command -v deb822-migration.py)

if [ -z "${deb822_migrate_script}" ]; then
    deb822_migrate_script="./deb822-migration.py"
fi
if [ ! -x "${deb822_migrate_script}" ]; then
    >&2 echo "ERROR: '${deb822_migrate_script}' not found or not executable"
    exit 1
fi

dest_dir="/etc/apt/sources.list.d"
rc=0

migrate_file() {
    legacy_file=$1
    deb822_file=$2

    if [ -f "${legacy_file}" ]; then
        if [ -f "${deb822_file}" ]; then
            >&2 echo "ERROR: '${deb822_file}' already exists"
            rc=2
        else
            ${deb822_migrate_script} "${legacy_file}" > "${deb822_file}"
            if [ $? -eq 0 ] && [ -f "${deb822_file}" ]; then
                mv "${legacy_file}" "${legacy_file}.bak"
                echo "Migrated ${legacy_file} to ${deb822_file} and renamed to ${legacy_file}.bak"
            else
                >&2 echo "ERROR: failed to convert '${legacy_file}' to '${deb822_file}'"
                rc=2
            fi
        fi
    else
        >&2 echo "ERROR: '${legacy_file}' not found"
        rc=2
    fi
}

migrate_file "/etc/apt/sources.list" "${dest_dir}/system.sources"

# shellcheck disable=SC2044
for legacy_file in $(find /etc/apt/sources.list.d -mindepth 1 -maxdepth 1 -type f -name '*.list'); do
    deb822_file=$(basename "${legacy_file}" .list)
    migrate_file "${legacy_file}" "${dest_dir}/${deb822_file}.sources"
done

exit ${rc}