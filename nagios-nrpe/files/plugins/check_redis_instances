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
    name=$1
    conf_file=$2

    host=$(config_var "bind" "${conf_file}")
    port=$(config_var "port" "${conf_file}")
    pass=$(config_var "requirepass" "${conf_file}")

    cmd="${check_bin} -H ${host} -p ${port}"
    if [ -n "${pass}" ]; then
        cmd="${cmd} -x ${pass}"
    fi
    result=$($cmd)
    ret="${?}"
    if [ "${ret}" -ge 2 ]; then
        nb_crit=$((nb_crit + 1))
        output="${output}${result}\n"
        [ "${return}" -le 2 ] && return=2
    elif [ "${ret}" -ge 1 ]; then
        nb_warn=$((nb_warn + 1))
        output="${output}${result}\n"
        [ "${return}" -le 1 ] && return=1
    else
        nb_ok=$((nb_ok + 1))
        output="${output}${result}\n"
        [ "${return}" -le 0 ] && return=0
    fi
}
config_var() {
    variable=$1
    file=$2
    test -f $file && grep -E "^${variable}\s+.+$" $file | awk '{ print $2 }'
}

# default instance
if systemctl is-enabled -q redis-server; then
    check_server "default" "/etc/redis/redis.conf"
fi

# additional instances
conf_files=$(ls -1 /etc/redis-*/redis.conf)
for conf_file in ${conf_files}; do
    name=$(dirname ${conf_file} | sed '{s|/etc/redis-||}')
    if systemctl is-enabled -q "redis-server@${name}.service"; then
        check_server $name $conf_file
    else
        nb_unchk=$((nb_unchk + 1))
        output="${output}UNCHK - ${name} (unit is disabled or missing)\n"
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
