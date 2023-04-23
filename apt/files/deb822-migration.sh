#!/bin/sh

deb822_migrate_script=$(command -v deb822-migration.py)

if [ -z "${deb822_migrate_script}" ]; then
    deb822_migrate_script="$(dirname "$0")/deb822-migration.py"
fi
if [ ! -x "${deb822_migrate_script}" ]; then
    >&2 echo "ERROR: '${deb822_migrate_script}' not found or not executable"
    exit 1
fi

sources_from_file() {
    grep --extended-regexp "^\s*(deb|deb-src) " $1
}

rc=0
count=0

if [ -f /etc/apt/sources.list ]; then
    sources_from_file /etc/apt/sources.list | ${deb822_migrate_script} 
    python_rc=$?

    if [ ${python_rc} -eq 0 ]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
        echo "OK: /etc/apt/sources.list"
        count=$(( count + 1 ))
    else
        >&2 echo "ERROR: failed migration for /etc/apt/sources.list"
        rc=1
    fi
fi

for file in $(find /etc/apt/sources.list.d -mindepth 1 -maxdepth 1 -type f -name '*.list'); do
    sources_from_file "${file}" | ${deb822_migrate_script}
    python_rc=$?

    if [ ${python_rc} -eq 0 ]; then
        mv "${file}" "${file}.bak"
        echo "OK: ${file}"
        count=$(( count + 1 ))
    else
        >&2 echo "ERROR: failed migration for ${file}"
        rc=1
    fi
done

echo "${count} file(s) migrated"
exit ${rc}