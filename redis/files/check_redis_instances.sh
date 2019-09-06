#!/bin/sh

# {{ ansible_managed }}

set -u

return=0
nb_crit=0
nb_warn=0
nb_ok=0
nb_unchk=0
output=""

packaged_check=/usr/lib/nagios/plugins/check_redis
vendored_check=/usr/local/lib/nagios/plugins/check_redis

if [ -x $packaged_check ]; then
    check_bin=$packaged_check
elif [ -x $vendored_check ]; then
    check_bin=$vendored_check
else
    echo "UNCHK - can't find check_redis"
    exit 3
fi

check_server() {
    host=$1
    port=$2

    ${check_bin} -H ${host} -p "${port}" >/dev/null 2>&1
    ret="${?}"
    if [ "${ret}" -ge 2 ]; then
        nb_crit=$((nb_crit + 1))
        output="${output}CRITICAL - ${name} (${host}:${port})\n"
        [ "${return}" -le 2 ] && return=2
    elif [ "${ret}" -ge 1 ]; then
        nb_warn=$((nb_warn + 1))
        output="${output}WARNING - ${name} (${host}:${port})\n"
        [ "${return}" -le 1 ] && return=1
    else
        nb_ok=$((nb_ok + 1))
        output="${output}OK - ${name} (${host}:${port})\n"
        [ "${return}" -le 0 ] && return=0
    fi
}

# default instance
conf_file="/etc/redis/redis.conf"
if systemctl is-enabled -q redis-server; then
    name="default"
    host=$(grep "bind" "${conf_file}"| awk '{ print $2 }')
    port=$(grep "port" "${conf_file}"| awk '{ print $2 }')

    check_server $host $port
fi

# additional instances
conf_files=$(ls /etc/redis-*/redis.conf)
for conf_file in ${conf_files}; do
    name=$(dirname ${conf_file} | sed '{s|/etc/redis-||}')
    if systemctl is-enabled -q "redis-server@${name}.service"; then
        host=$(grep "bind" "${conf_file}"| awk '{ print $2 }')
        port=$(grep "port" "${conf_file}"| awk '{ print $2 }')

        check_server $host $port
    else
        nb_crit=$((nb_crit + 1))
        output="${output}CRITICAL - ${name} (${port})\n"
    fi
done

[ "${return}" -ge 0 ] && header="OK"
[ "${return}" -ge 1 ] && header="WARNING"
[ "${return}" -ge 2 ] && header="CRITICAL"

printf "%s - %s UNCHK / %s CRIT / %s WARN / %s OK\n\n" "${header}" "${nb_unchk}" "${nb_crit}" "${nb_warn}" "${nb_ok}"

printf "%s" "${output}" | grep -E "^CRITICAL"
printf "%s" "${output}" | grep -E "^WARNING"
printf "%s" "${output}" | grep -E "^OK"
printf "%s" "${output}" | grep -E "^UNCHK"

exit "${return}"
