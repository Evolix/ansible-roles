#!/bin/sh

# Move apt repository key from /etc/apt/trusted.gpg.d/ to /etc/apt/keyrings/ and add "signed-by" tag in source list
# 
# Example: move-apt-keyrings.sh http://repo.mongodb.org/apt/debian mongodb-server-[0-9\\.]+.asc

repository_pattern=$1
key=$2

found_files=$(grep --files-with-matches --recursive --extended-regexp "${repository_pattern}" "/etc/apt/sources.list.d/")

old_key_file="/etc/apt/trusted.gpg.d/${key}"
new_key_file="/etc/apt/keyrings/${key}"

for file in ${found_files}; do
    if ! grep --quiet "signed-by" "${file}"; then
        signed_by="signed-by=${new_key_file}"
        if grep --quiet "deb(-src)? \[" "${file}"; then
            sed -i "s@deb\(-src\)\? \[\([^]]\+\)\]@deb\1 [\2 ${signed_by}]@" "${file}"
        else
            sed -i "s@deb\(-src\)\? @deb\1 [${signed_by}] @" "${file}"
        fi
    fi
done

if [ -f "${old_key_file}" ] && [ ! -f "${new_key_file}" ]; then
    mv "${old_key_file}" "${new_key_file}"
fi
if [ -f "${new_key_file}" ]; then
    chmod 644 "${new_key_file}"
    chown root: "${new_key_file}"
fi
