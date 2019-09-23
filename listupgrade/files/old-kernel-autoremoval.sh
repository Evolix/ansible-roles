#!/bin/sh

# fork by reg from /etc/kernel/postinst.d/apt-auto-removal script

set -e

eval $(apt-config shell DPKG Dir::bin::dpkg/f)
test -n "$DPKG" || DPKG="/usr/bin/dpkg"

# Detect which one of apt/aptitude we should use.
get_apt_binary() {
    root="$1"
    # apt could be a Java binary...
    if [ -x $root/usr/bin/apt ] && ! $root/usr/bin/apt --version 2>&1 |grep -q "javac"; then
        echo "apt"
    elif [ -x $root/usr/bin/aptitude ]; then
        echo "aptitude"
    # Usually in containers
    else
        echo "apt-get"
    fi
}
APT=$(get_apt_binary)

list="$("${DPKG}" -l | awk '/^[ih][^nc][ ]+(linux|kfreebsd|gnumach)-image-[0-9]+\./ && $2 !~ /-dbg(:.*)?$/ && $2 !~ /-dbgsym(:.*)?$/ { print $2,$3; }' \
   | sed -e 's#^\(linux\|kfreebsd\|gnumach\)-image-##' -e 's#:[^:]\+ # #')"
debverlist="$(echo "$list" | cut -d' ' -f 2 | sort --unique --reverse --version-sort)"

if [ -n "$1" ]; then
    installed_version="$(echo "$list" | awk "\$1 == \"$1\" { print \$2;exit; }")"
fi
unamer="$(uname -r | tr '[A-Z]' '[a-z]')"
if [ -n "$unamer" ]; then
    running_version="$(echo "$list" | awk "\$1 == \"$unamer\" { print \$2;exit; }")"
fi
# ignore the currently running version if attempting a reproducible build
if [ -n "${SOURCE_DATE_EPOCH}" ]; then
    unamer=""
    running_version=""
fi
latest_version="$(echo "$debverlist" | sed -n 1p)"
previous_version="$(echo "$debverlist" | sed -n 2p)"

debkernels="$(echo "$latest_version
$installed_version
$running_version" | sort -u | sed -e '/^$/ d')"
kernels="$( (echo "$1
$unamer"; for deb in $debkernels; do echo "$list" | awk "\$2 == \"$deb\" { print \$1; }"; done; ) \
   | sed -e 's#\([\.\+]\)#\\\1#g' -e '/^$/ d' | sort -u|tr '\n' '|' | sed -e 's/|$//')"


echo "
List of installed kernel packages:
$list

# Running kernel: ${running_version:-ignored} (${unamer:-ignored})
# Last kernel: $latest_version
# Previous kernel: $previous_version
# Kernel versions list to keep:
$debkernels

# Kernel packages (version part) to protect:
$kernels
"

echo "BEFORE"
dpkg -l | grep linux-image

dpkg --get-selections | tr '\t' ' ' | cut -d" " -f1 | grep ^linux-image-[234] | egrep -v  "($kernels)" | xargs --no-run-if-empty $APT -y purge

echo "
AFTER"
dpkg -l | grep linux-image
echo ""
