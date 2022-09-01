#!/bin/sh

# {{ ansible_managed }}

set -u

return=0
nb_crit=0
nb_warn=0
nb_ok=0
nb_unchk=0
output=""

vendored_check=/usr/local/lib/nagios/plugins/check_memcached.pl

if [ -x $vendored_check ]; then
    check_bin=$vendored_check
else
    echo "UNCHK - can't find check_memcached"
    exit 3
fi

check_server() {
    name=$1
    conf_file=$2

    host=$(config_var "-l" "${conf_file}")
    port=$(config_var "-p" "${conf_file}")

    cmd="${check_bin} -H ${host} -p ${port}"

    result=$($cmd)
    ret="${?}"
    if [ "${ret}" -ge 2 ]; then
        nb_crit=$((nb_crit + 1))
        printf -v output "%s%s\n" "${output}" "${result}"
        [ "${return}" -le 2 ] && return=2
    elif [ "${ret}" -ge 1 ]; then
        nb_warn=$((nb_warn + 1))
        printf -v output "%s%s\n" "${output}" "${result}"
        [ "${return}" -le 1 ] && return=1
    else
        nb_ok=$((nb_ok + 1))
        printf -v output "%s%s\n" "${output}" "${result}"
        [ "${return}" -le 0 ] && return=0
    fi
}
config_var() {
    variable=$1
    file=$2
    test -f "${file}" && grep -E "^${variable}\s+.+$" "${file}" | awk '{ print $2 }' | sed -e "s/^[\"']//" -e "s/[\"']$//"
}

# default instance
if systemctl is-enabled -q memcached; then
    check_server "default" "/etc/memcached.conf"
fi

# additional instances
conf_files=$(ls -1 /etc/memcached_*.conf 2> /dev/null)
for conf_file in ${conf_files}; do
    name=$(basename "${conf_file}" | sed '{s|memcached_||;s|\.conf||}')
    if systemctl is-enabled -q "memcached@${name}.service"; then
        check_server "${name}" "${conf_file}"
    else
        nb_unchk=$((nb_unchk + 1))
        output="${output}UNCHK - ${name} (unit is disabled or missing)\n"
    fi
done

[ "${return}" -ge 0 ] && header="OK"
[ "${return}" -ge 1 ] && header="WARNING"
[ "${return}" -ge 2 ] && header="CRITICAL"

printf "%s - %s UNCHK / %s CRIT / %s WARN / %s OK\n\n" "${header}" "${nb_unchk}" "${nb_crit}" "${nb_warn}" "${nb_ok}"

printf "%s" "${output}" | grep -E "CRITICAL"
printf "%s" "${output}" | grep -E "WARNING"
printf "%s" "${output}" | grep -E "OK"
printf "%s" "${output}" | grep -E "UNCHK"

exit "${return}"
