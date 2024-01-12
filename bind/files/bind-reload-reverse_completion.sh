#!/usr/bin/env bash

_bind_reload_reverse_dynamic_completion() {

    ipv4_list_command='grep -v -h -E '"'"'//'"'"'^[[:blank:]]*//'"'"'//'"'"' /etc/bind/named.conf* | grep -B1 "type master" | grep zone | grep arpa | grep -v ip6 | awk '"'"'//'"'"'{gsub(/"/, "", $2); gsub(/.in-addr.arpa/, "", $2); print $2}'"'"'//'"'"' | sort | uniq | awk -F"." '"'"'//'"'"'{ for (i=NF; i>1; i--) printf("%s.",$i); print $1 }'"'"'//'"'"' | sort -n'

    ipv6_list_command='grep -v -h -E '"'"'//'"'"'^[[:blank:]]*//'"'"'//'"'"' /etc/bind/named.conf* | grep -B1 "type master" | grep zone | grep arpa | grep ip6 | awk '"'"'//'"'"'{gsub(/"/, "", $2); gsub(/.ip6.arpa/, "", $2); print $2}'"'"'//'"'"' | sort | uniq | rev | awk -F"." '"'"'//'"'"'{ printf("%s", $1); for (i=2; i<NF+1; i++) { if ((i-1)%4 != 0) printf("%s",$i); else printf(".%s",$i); } printf("\n") }'"'"'//'"'"' | sort -n'

    local cur;
    cur=${COMP_WORDS[COMP_CWORD]};
    COMPREPLY=();
    COMPREPLY=( $( compgen -W "${ipv4_list_command}; ${ipv6_list_command}" -- $cur ) );
}

complete -F _bind_reload_reverse_dynamic_completion bind-reload-reverse

