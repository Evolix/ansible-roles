#!/bin/bash

# WARNING:
# This script is installed and maintained via Ansible. Don't edit directly.
# Create a fork if you need changes that can't go into the regular script.

set -e
set -u

PLUGIN_BIN=/usr/share/elasticsearch/bin/elasticsearch-plugin
NEED_RESTART=""

for plugin in $(${PLUGIN_BIN} list | grep -v WARNING); do
    "${PLUGIN_BIN}" remove "${plugin}"
    "${PLUGIN_BIN}" install "${plugin}"
    NEED_RESTART="1"
done

if [ -n "${NEED_RESTART}" ]; then
    systemctl restart elasticsearch
fi

exit 0
