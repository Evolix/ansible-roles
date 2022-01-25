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

VERSION="21.10"

isDryRun() {
    test "${doDryRun}" = "true"
}

dryRun() {

    if isDryRun; then
        echo -e "\e[34mDoing:" "$*" "\e[39m"
    else
        echo -e "\e[34mDoing:" "$*" "\e[39m"
        $*
    fi
}

critical() {
    echo -ne "\e[31m${1}\e[39m\n" && exit 1
}

warn() {

    echo -ne "\e[33m${1}\e[39m\n"
}

# shellcheck disable=SC1091
[ -f "/etc/evolinux/add-vm.cnf" ] && . /etc/evolinux/add-vm.cnf
masterKVMIP="${masterKVMIP:-127.0.0.1}"
slaveKVMIP="${slaveKVMIP:-}"
disks="${disks:-}"
[ -n "${disks}" ] || disks=("ssd" "hdd")
bridgeName="${bridgeName:-br0}"
doDryRun=${doDryRun:-false}
isoImagePath="${isoImagePath:-}"
debianVersion="${debianAuto:-stable}"
preseedURL="${preseedURL:-}"
defaultVCPU="${defaultVCPU:-"2"}"
defaultRAM="${defaultRAM:-"4G"}"
defaultRootSize="${defaultRootSize:-"20G"}"
defaultHomeSize="${defaultHomeSize:-"40G"}"

DIALOGOUT=$(mktemp --tmpdir=/tmp addvm.XXX)
export DIALOGOUT
# TODO: How to replace _ with a space??
DIALOG="$(command -v dialog) --backtitle Add-VM_Press_F1_for_help"
export DIALOG
DIALOGRC=.dialogrc
export DIALOGRC
HELPFILE=$(mktemp --tmpdir=/tmp addvm.XXX)
export HELPFILE
tmpResFile=$(mktemp --tmpdir=/tmp addvm.XXX)
masterKVM="$(hostname -s)"
slaveKVM="$(ssh "${slaveKVMIP}" hostname -s)"

# Exit & Cleanup function.
clean() {
    echo -e "\nBye! Cleaning..."
    rm -f "${DIALOGOUT}"
    rm -f "${HELPFILE}"
    exit
}
trap clean EXIT SIGINT

${DIALOG} \
    --hfile "${HELPFILE}" \
    --title "KVM Config" \
    --form "Set the right config. If you do not want a type of disk, type none." 0 0 0 \
    "vCPU" 1 1 "${defaultVCPU}" 1 10 20 0 \
    "memory" 2 1 "${defaultRAM}" 2 10 20 0 \
    "volRoot" 3 1 "${disks[0]}-${defaultRootSize}" 3 10 20 0 \
    "volHome" 4 1 "${disks[1]}-${defaultHomeSize}" 4 10 20 0 \
    "vmName" 5 1 "" 5 10 20 0 \
    2> "${DIALOGOUT}"

vCPU=$(sed 1'q;d' "${DIALOGOUT}")
memory=$(sed 2'q;d' "${DIALOGOUT}" | tr -d 'G')
memory=$((memory * 1024 ))
volRoot=$(sed 3'q;d' "${DIALOGOUT}")
volHome=$(sed 4'q;d' "${DIALOGOUT}")
vmName=$(sed 5'q;d' "${DIALOGOUT}")

if [ -z "${vmName}" ]; then
    critical "You need a VM Name!!"
fi

${DIALOG} \
    --title "Continue?" \
    --clear "$@" \
    --yesno "Will create a VM named ${vmName} on ${masterKVM} with ${vCPU} vCPU, ${memory} memory, ${volRoot} for / (and /usr, ...) and ${volHome} for /home." 10 80
dialog_rc=$?

if [[ ${dialog_rc} -ne 0 ]]; then
    exit 1
fi

if ! [[ "${volRoot}" =~ ([^-]+)-([0-9]+G) ]]; then
    critical "No volume for root device (/dev/vda)?!!"
else
    volRootDisk="${BASH_REMATCH[1]}"
    volRootSize="${BASH_REMATCH[2]}"
    if [[ " ${disks[*]} " != *"${volRootDisk}"* ]]; then
        critical "Unknow disk ${volRootDisk} !"
    fi
    dryRun lvcreate -L"${volRootSize}" -n"${vmName}_root" "${volRootDisk}"
    dryRun ssh "${slaveKVMIP}" "lvcreate -L$volRootSize -n${vmName}_root ${volRootDisk}"
fi

if ! [[ "${volHome}" =~ ([^-]+)-([0-9]+G) ]]; then
    warn "No volume for home device (/dev/vdb)... Okay, not doing it!"
    volHomeDisk="none"
else
    volHomeDisk="${BASH_REMATCH[1]}"
    volHomeSize="${BASH_REMATCH[2]}"
    if [[ " ${disks[*]} " != *"${volHomeDisk}"* ]]; then
        critical "Unknow disk ${volHomeDisk} !"
    fi
    dryRun lvcreate -L"${volHomeSize}" -n"${vmName}_home" "${volHomeDisk}"
    dryRun ssh "${slaveKVMIP}" "lvcreate -L$volHomeSize -n${vmName}_home ${volHomeDisk}"
fi

if [ -f "/etc/drbd.d/${vmName}.res" ]; then
    warn "The DRBD resource file ${vmName}.res is already present! Continue? [y/N]"
    read -r
    if ! [[ "${REPLY}" =~ (Y|y) ]]; then
        exit 1
    fi
fi

# Generates drbd resource file.

# shellcheck disable=SC2012
if [ "$(ls /etc/drbd.d/ | wc -l)" -gt 1 ]; then
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

cat << EOT > "${tmpResFile}"
resource "${vmName}" {
    net {
        cram-hmac-alg "sha1";
        shared-secret "$(apg -n 1 -m 16 -M lcN)";
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
        disk /dev/${volRootDisk}/${vmName}_root;
        meta-disk internal;
    }
EOT
if [[ "${volHomeDisk}" != "none" ]]; then
    cat << EOT >> "${tmpResFile}"
    volume 1 {
        device minor ${minorvol1};
        disk /dev/${volHomeDisk}/${vmName}_home;
        meta-disk internal;
    }
EOT
fi
cat << EOT >> "${tmpResFile}"
    on ${masterKVM} {
        address ${masterKVMIP}:${drbdPort};
    }
    on ${slaveKVM} {
        address ${slaveKVMIP}:${drbdPort};
    }
}
EOT

# Create/Activate the new drbd resources.
drbdadm="$(command -v drbdadm)"
if isDryRun; then
    drbdadm="${drbdadm} --dry-run"
fi

if isDryRun; then
    # shellcheck disable=SC2064
    trap "rm /etc/drbd.d/${vmName}.res && ssh ${slaveKVMIP} rm /etc/drbd.d/${vmName}.res" 0
fi
install -m 600 "${tmpResFile}" "/etc/drbd.d/${vmName}.res"
scp "/etc/drbd.d/${vmName}.res" "${slaveKVMIP}:/etc/drbd.d/"
${drbdadm} create-md "${vmName}"
# shellcheck disable=SC2029
ssh "${slaveKVMIP}" "${drbdadm} create-md ${vmName}"
${drbdadm} adjust "${vmName}"
# shellcheck disable=SC2029
ssh "${slaveKVMIP}" "${drbdadm} adjust ${vmName}"
${drbdadm} -- --overwrite-data-of-peer primary "${vmName}"

if ! isDryRun; then
    sleep 5
    drbd-overview | tail -4

    drbdDiskPath="/dev/drbd/by-res/${vmName}/0"
    if ! [ -b "${drbdDiskPath}" ]; then
        warn "${drbdDiskPath} not found! Continue? [y/N]"
        read -r
        if ! [[ "${REPLY}" =~ (Y|y) ]]; then
            exit 1
        fi
    fi
fi

virtRootDisk="--disk path=/dev/drbd/by-disk/${volRootDisk}/${vmName}_root,bus=virtio,io=threads,cache=none,format=raw"
virtHomeDisk=""
if [ "${volHomeDisk}" != "none" ]; then
    virtHomeDisk="--disk path=/dev/drbd/by-disk/${volHomeDisk}/${vmName}_home,bus=virtio,io=threads,cache=none,format=raw"
fi
if [ -n "${preseedURL}" ]; then
    bootMode="--location https://deb.debian.org/debian/dists/${debianVersion}/main/installer-amd64/ --extra-args auto=true priority=critical url=${preseedURL} hostname=${vmName}"
fi
if [ -f "${isoImagePath}" ]; then
    bootMode="--cdrom=${isoImagePath}"
fi
bootMode=${bootMode:-"--pxe"}

dryRun virt-install \
    --connect=qemu:///system \
    --name="${vmName}" \
    --cpu "mode=host-passthrough" \
    --vcpus="${vCPU}" \
    --memory="${memory}" \
    "${virtRootDisk}" \
    "${virtHomeDisk}" \
    "${bootMode}" \
    --network="bridge:${bridgeName},model=virtio" \
    --noautoconsole \
    --graphics "vnc,listen=127.0.0.1,keymap=fr" \
    --rng /dev/random \
    --os-variant=none
virt_install_rc=$?

if [ "${virt_install_rc}" = "0" ]; then
    echo -e "\e[32mDone! Now you can install your VM with virt-manager.\e[39m"
else
    echo -e "\e[31mError! VM couldn't be created.\e[39m"
fi

if ! isDryRun && [ -x /usr/share/scripts/evomaintenance.sh ]; then
    echo "Install VM ${vmName} (add-vm.sh)" | /usr/share/scripts/evomaintenance.sh
fi


