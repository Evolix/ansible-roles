#!/bin/sh

# File containing error messages to skip (one per line).
error_messages="/etc/mysql_skip.conf"

# Sleep interval between 2 check.
sleep_interval="1"

# Exit when Seconds_Behind_Master reached 0.
exit_when_uptodate="false"

# Options to pass to mysql.
#mysql_opt="-P 3307"

# File to log skipped queries to (leave empty for no logs).
log_file="/var/log/mysql_skip.log"

mysql_skip_error() {
    error="$1"

    error="$(date --iso-8601=seconds) Skiping: $error"
    printf "Skipping: $error\n"
    mysql $mysql_opt -e 'SET GLOBAL SQL_SLAVE_SKIP_COUNTER=1; START SLAVE;'

    [ -n "$log_file" ] && echo "$error" >>"$log_file"
}

while true; do
    slave_status="$(mysql $mysql_opt -e 'SHOW SLAVE STATUS\G')"
    seconds_behind_master=$(echo "$slave_status" |grep 'Seconds_Behind_Master: ' |awk -F ' ' '{print $2}')
    last_SQL_error="$(echo "$slave_status" |grep 'Last_SQL_Error: ' |sed 's/^.\+Last_SQL_Error: //')"

    if [ "$seconds_behind_master" = "0" ]; then
        #printf 'Replication is up to date!\n' 
        if [ "$exit_when_uptodate" = "true" ]; then
            exit 0
        fi

    elif [ -z "$last_SQL_error" ]; then
        sleep $sleep_interval

    elif echo "$last_SQL_error" |grep -q -f $error_messages; then
        mysql_skip_error "$last_SQL_error"

    fi
    sleep 1
done
