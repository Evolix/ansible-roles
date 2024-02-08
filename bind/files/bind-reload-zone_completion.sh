#!/usr/bin/env bash

_bind_reload_zone_dynamic_completion() {
    local cur;
    cur=${COMP_WORDS[COMP_CWORD]};
    COMPREPLY=();
    COMPREPLY=( $( compgen -W '$(grep -v -h '"'"'//'"'"' /etc/bind/named.conf* | grep -B1 "type master" | grep zone | grep -v arpa | awk '"'"'{gsub(/"/, "", $2); print $2}'"'"' | sort | uniq)' -- $cur ) );

    # reverse ipv4 :
    #grep -v -h '//' /etc/bind/named.conf*     | grep -B1 "type master" | grep zone | grep arpa | grep -v ip6 | awk '{gsub(/"/, "", $2); gsub(/.in-addr.arpa/, "", $2); print $2}' | sort | uniq | awk -F'.' '{ for (i=NF; i>1; i--) printf("%s.",$i); print $1 }'

    # reveres ipv6 : je bloque sur l'inversion 4 par 4
    #grep -v -h '//' /etc/bind/named.conf* | grep -B1 "type master" | grep zone | grep arpa | grep ip6 | awk '{gsub(/"/, "", $2); gsub(/.ip6.arpa/, "", $2); print $2}' | sort | uniq | awk -F'.' '{ for (i=NF; i>1; i--) { if ($i % 4 == 0) printf("%s.",$i); else printf("%s",$i); } print $1 }'

}

complete -F _bind_reload_zone_dynamic_completion bind-reload-zone

