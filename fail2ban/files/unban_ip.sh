#!/bin/bash

function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

IP="$1"
if [ "$IP" == "" ]; then
   echo
   echo -e "\033${TERM_COLOR_LIGHT_RED}Usage: $FUNCNAME <IP>\033${TERM_COLOR_NORMAL}"
   echo
   cat <<EOF
unban an IP from all fail2ban jails
EOF
   exit 1
fi
FAIL2BAN_VERSION="$(fail2ban-client --version | grep '^Fail2Ban v' | sed 's/Fail2Ban v//g')"
FAIL2BAN_RECENT="$(version_gt 0.8.8 $FAIL2BAN_VERSION; echo $?)"
for JAIL in $(fail2ban-client status | grep "Jail list" | sed -e 's/^[^:]\+:[ \t]\+//' | sed 's/,//g'); do
   if [ "$FAIL2BAN_RECENT" == "1" ]; then
      fail2ban-client set $JAIL unbanip $IP 2>&1 | grep -v "$IP is not banned";
   else
      iptables -D f2b-$JAIL -s $IP -j DROP 2>&1 | grep -v 'iptables: Bad rule' && sleep 5 || echo "$IP is not banned";
   fi
done

exit 0

