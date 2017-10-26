#!/bin/bash
# Add-VM script to add a VM on evoKVM.
#     _    ____  ____     __     ____  __
#    / \  |  _ \|  _ \    \ \   / /  \/  |
#   / _ \ | | | | | | |____\ \ / /| |\/| |
#  / ___ \| |_| | |_| |_____\ V / | |  | |
# /_/   \_\____/|____/       \_/  |_|  |_|
#
# Need packages: dialog
# Bash strict mode
set -euo pipefail

dryRun() {

    if ($doDryRun); then
        echo -e "\e[34mDoing:" $* "\e[39m"
    else
        echo -e "\e[34mDoing:" $* "\e[39m"
        $*
    fi
}

critical() {
    echo -ne "\e[31m${1}\e[39m\n" && exit 1
}

warn() {

    echo -ne "\e[33m${1}\e[39m\n"
}

masterKVMIP=""
slaveKVMIP=""
[ -f "/etc/evolinux/add-vm.cnf" ] && . /etc/evolinux/add-vm.cnf
[ -z "$masterKVMIP" ] && critical "You must define masterKVMIP in /etc/evolinux/add-vm.cnf!!" 
[ -z "$slaveKVMIP" ] && critical "You must define slaveKVMIP in /etc/evolinux/add-vm.cnf!!"

export DIALOGOUT=$(mktemp --tmpdir=/tmp addvm.XXX)
# TODO: How to replace _ with a space??
export DIALOG="$(which dialog) --backtitle Add-VM_Press_F1_for_help"
export DIALOGRC=.dialogrc
export HELPFILE=$(mktemp --tmpdir=/tmp addvm.XXX)
tmpResFile=$(mktemp --tmpdir=/tmp addvm.XXX)
xmlVM=$(mktemp --tmpdir=/tmp addvm.XXX)
masterKVM="$(hostname -s)"
slaveKVM="$(ssh $slaveKVMIP hostname -s)"
doDryRun=false

# Exit & Cleanup function.
clean() {

    echo -e "\nBye! Cleaning..."
    [ -f $DIALOGOUT ] && rm $DIALOGOUT
    [ -f $HELPFILE ] && rm $HELPFILE
#     [ -f $tmpResFile ] && rm $tmpResFile
#     [ -f $xmlVM ] && rm $xmlVM
    exit
}
trap clean EXIT SIGINT

$DIALOG --hfile $HELPFILE --title "KVM Config" --form "Set the right config. "\
"If you do not want a type of disk, type none." 0 0 0 \
  "vCPU" 1 1 "2" 1 10 20 0 \
  "memory" 2 1 "4G" 2 10 20 0 \
  "volroot" 3 1 "ssd-20G" 3 10 20 0 \
  "volhome" 4 1 "hdd-40G" 4 10 20 0 \
  "vmName" 5 1 "" 5 10 20 0 \
  2>$DIALOGOUT
vCPU=$(sed 1'q;d' $DIALOGOUT)
memory=$(sed 2'q;d' $DIALOGOUT)
volroot=$(sed 3'q;d' $DIALOGOUT)
volhome=$(sed 4'q;d' $DIALOGOUT)
vmName=$(sed 5'q;d' $DIALOGOUT)

[ -z "$vmName" ] && critical "You need a VM Name!!"

$DIALOG --title "Continue?" --clear "$@" \
  --yesno "Will create a VM named $vmName on $masterKVM with $vCPU vCPU, "\
"$memory memory, $volroot for / (and /usr, ...) and $volhome for /home." 10 80
if [[ $? -ne 0 ]]; then
    exit 1
fi

if ! [[ "$volroot" =~ (ssd|hdd)-([0-9]+G) ]]; then
    critical "No volume for root device (/dev/vda)?!!"
else
    volrootDisk="${BASH_REMATCH[1]}"
    volrootSize="${BASH_REMATCH[2]}"
    dryRun lvcreate -L$volrootSize -n${vmName}_root $volrootDisk
    dryRun ssh $slaveKVMIP lvcreate -L$volrootSize -n${vmName}_root $volrootDisk
fi

if ! [[ "$volhome" =~ (ssd|hdd)-([0-9]+G) ]]; then
    warn "No volume for home device (/dev/vdb)... Okay, not doing it!"
    volhomeDisk="none"
else
    volhomeDisk="${BASH_REMATCH[1]}"
    volhomeSize="${BASH_REMATCH[2]}"
    dryRun lvcreate -L$volhomeSize -n${vmName}_home $volhomeDisk
    dryRun ssh $slaveKVMIP lvcreate -L$volhomeSize -n${vmName}_home $volhomeDisk
fi

if [[ -f "/etc/drbd.d/${vmName}.res" ]]; then
    warn "The DRBD resource file ${vmName}.res is already present! Continue? [y/N]"
    read
    if ! [[ "$REPLY" =~ (Y|y) ]]; then
        exit 1
    fi
fi

# Generates drbd resource file.

if [ $(ls /etc/drbd.d/|wc -l) -gt 1 ]; then
    lastdrbdPort=$(grep -hEo ':[0-9]{4}' /etc/drbd.d/*.res | sort | uniq | tail -1 | sed 's/://')
    drbdPort=$((lastdrbdPort+1))
    lastMinor=$(grep -hEo 'minor [0-9]{1,}' /etc/drbd.d/*.res | sed 's/minor //' | sort -n | tail -1)
    minorvol0=$((lastMinor+1))
    minorvol1=$((lastMinor+2))
else
    drbdPort=7900
    minorvol0=0
    minorvol1=1
fi

cat << EOT > $tmpResFile
resource "${vmName}" {
    net {
        cram-hmac-alg "sha1";
        shared-secret "$(apg -m21 -n1)";
        # Si pas de lien dedié 10G, passer en protocol A
        # Et desactiver allow-two-primaries;
        protocol C;
        allow-two-primaries;
        # Tuning perf.
        max-buffers 8000;
        max-epoch-size 8000;
        sndbuf-size 0;
    }
    # A utiliser si RAID HW avec cache + batterie
    disk {
        disk-barrier no;
        disk-flushes no;
    }
    volume 0 {
        device minor ${minorvol0};
        disk /dev/${volrootDisk}/${vmName}_root;
        meta-disk internal;
    }
EOT
if [[ "$volhomeDisk" != "none" ]]; then
    cat << EOT >> $tmpResFile
    volume 1 {
        device minor ${minorvol1};
        disk /dev/${volhomeDisk}/${vmName}_home;
        meta-disk internal;
    }
EOT
fi
cat << EOT >> $tmpResFile
    on $masterKVM {
        address ${masterKVMIP}:${drbdPort};
    }
    on $slaveKVM {
        address ${slaveKVMIP}:${drbdPort};
    }
}
EOT

# Create/Activate the new drbd resources.
dryRun install -m 600 $tmpResFile /etc/drbd.d/${vmName}.res
dryRun scp /etc/drbd.d/${vmName}.res ${slaveKVMIP}:/etc/drbd.d/
dryRun drbdadm create-md "$vmName"
dryRun ssh $slaveKVMIP drbdadm create-md "$vmName"
($doDryRun) && drbdadm -d adjust "$vmName"
($doDryRun) || drbdadm adjust "$vmName"
($doDryRun) && ssh $slaveKVMIP drbdadm -d adjust "$vmName"
($doDryRun) || ssh $slaveKVMIP drbdadm adjust "$vmName"
dryRun drbdadm -- --overwrite-data-of-peer primary "$vmName"
sleep 5 && drbd-overview | tail -4

drbdDiskPath="/dev/drbd/by-res/${vmName}/0"
if ! [[ -b "$drbdDiskPath" ]]; then
    warn "$drbdDiskPath not found! Continue? [y/N]"
    read
    if ! [[ "$REPLY" =~ (Y|y) ]]; then
        exit 1
    fi
fi

virtHome=""
[ "$volhomeDisk" != "none" ] && virtHome="--disk path=/dev/drbd/by-disk/${volhomeDisk}/${vmName}_home,bus=virtio,io=threads,cache=none,format=raw"

dryRun virt-install --connect=qemu:///system \
  --name=${vmName} \
  --cpu mode=host-passthrough --vcpus=${vCPU} \
  --ram=${memory%%G} \
  --disk path=/dev/drbd/by-disk/${volrootDisk}/${vmName}_root,bus=virtio,io=threads,cache=none,format=raw \
  $virtHome \
  --network=bridge:br0,model=virtio \
  --noautoconsole --graphics vnc,listen=127.0.0.1,keymap=fr \
  --rng /dev/random \
  --os-variant=none \
  --pxe

echo -e "\e[32mDone! Now you can install your VM with virt-manager.\e[39m"
