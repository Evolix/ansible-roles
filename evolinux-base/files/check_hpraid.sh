#!/usr/bin/env bash
set -euo pipefail

# This script is meant to be executed as a cron by executing Nagios 
# NRPE plugin check_hpraid and notify by mail any errors

TMPDIR=/tmp
md5sum=$(command -v md5sum)
awk=$(command -v awk)
check_hpraid="/usr/local/lib/nagios/plugins/check_hpraid -v"
check_hpraid_output=$(mktemp -p $TMPDIR check_hpraid_XXX)
check_hpraid_last="$TMPDIR/check_hpraid_last"
trap trapFunc EXIT ERR

testDeps() {
    
    test -x "$md5sum" || (echo "md5sum binary not found"; exit 1)
    test -x "$awk" || (echo "awk binary not found"; exit 1)
}

main() {
    
    if ! $check_hpraid > "$check_hpraid_output"; then
        error=true
    else
        error=false
    fi
    if [ ! -f $check_hpraid_last ]; then
        cp "$check_hpraid_output" $check_hpraid_last
    fi
    
    # If output and last check is different, display differences and 
    # exit
    md5_now=$(md5sum "$check_hpraid_output" | awk '{print $1}')
    md5_last=$(md5sum $check_hpraid_last | awk '{print $1}')
    if [[ "$md5_now" != "$md5_last" ]]; then
        cat << EOT
        Different RAID state detected.
        Was:
        $(cat $check_hpraid_last)
        Is now:
        $(cat $check_hpraid_output)
EOT
        cp "$check_hpraid_output" $check_hpraid_last
        exit 1
    fi
    
    # If check_hpraid returned error, display output, save status and 
    # exit
    if $error; then
        cp "$check_hpraid_output" $check_hpraid_last
        cat "$check_hpraid_output"
        exit 1
    else
        cp "$check_hpraid_output" $check_hpraid_last
        exit 0
    fi
}

trapFunc() {
    
    rm "$check_hpraid_output"
}

testDeps
main
