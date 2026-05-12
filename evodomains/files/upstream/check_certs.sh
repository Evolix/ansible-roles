#!/bin/bash
#
# Check certificates for NRPE using evodomains.

if ! command -v evodomains >/dev/null; then
    echo 'UNKNOWN - Missing dependency evodomains.'
    exit 3
fi

evodomains check-certs --valid-domains --output nrpe "$@"

