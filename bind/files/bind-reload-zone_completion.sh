#!/usr/bin/env bash

_bind_reload_zone_dynamic_completion() {
    local cur;
    cur=${COMP_WORDS[COMP_CWORD]};
    COMPREPLY=();
    COMPREPLY=( $( compgen -W '$(grep -v -h -E '"'"'^[[:blank:]]*//'"'"' /etc/bind/named.conf* | grep -B1 "type master" | grep zone | grep -v arpa | awk '"'"'{gsub(/"/, "", $2); print $2}'"'"' | sort | uniq)' -- $cur ) );
}

complete -F _bind_reload_zone_dynamic_completion bind-reload-zone

