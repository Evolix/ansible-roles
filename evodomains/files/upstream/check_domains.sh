#!/bin/bash
#
# Check domains for NRPE using evodomains.

if ! command -v evodomains >/dev/null; then
    echo 'UNKNOWN - Missing dependency evodomains.'
    exit 3
fi

evodomains check-dns --output nrpe "$@"

