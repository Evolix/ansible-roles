#!/usr/bin/env bash

_evodomains_dynamic_completion() {
    local action=""
    for w in "${COMP_WORDS[@]}"; do
        case "$w" in
            list|check-dns|check-certs|check-ssl|http-challenge)
                action="${w}"
                ;;
        esac
    done

    local prev="${COMP_WORDS[$COMP_CWORD - 1]}"
    local cur=${COMP_WORDS[COMP_CWORD]};
    local words="--output --location --numeric --verbose --no-warnings --no-pager --no-header --color --non-interactive --help --version"

    if [ -z "${action}" ]; then
        words="list check-dns http-challenge check-certs ${words}"
    else
        if [ "${action}" == "check-certs" ] || [ "${action}" == "check-ssl" ]; then
            words="${words} --valid-domains --expiration-warn --expiration-crit"
        elif [ "${action}" == "list" ]; then
            words="${words} --valid-domains"
        fi
    fi

    if [ "${prev}" == "--output" ] || [ "${prev}" == "-o" ]; then
        if [ "${action}" == "list" ]; then
            words="table json"
        else
            words="table json nrpe"
        fi
    fi

    if [ "${prev}" == "--location" ] || [ "${prev}" == "-l" ]; then
        words="apache nginx haproxy certificates extra-domains extra-certs"
        # Add vhost names
        vhosts=""
        if [ "${cur:0:1}" != '/' ]; then
            vhosts="$(find /etc/{apache2,nginx}/sites-enabled/ -type l 2>/dev/null | xargs -n1 basename | sed -E 's/(.*)\.(conf|cfg)/\1/')"
        fi
        # Add directories and *.crt|pem
        compopt -o filenames -o plusdirs
        files="$(compgen -f -X '!(*.crt|*.pem)' -- ${cur})"
        words="${words} ${vhosts} ${files}"
    fi

    # Avoid double
    opts=();
    for i in ${words}; do
        for j in "${COMP_WORDS[@]}"; do
            if [[ "$i" == "$j" ]]; then
                continue 2
            fi
        done
        opts+=("$i")
    done

    COMPREPLY=($(compgen -W "${opts[*]}" -- "${cur}"))
}

complete -F _evodomains_dynamic_completion evodomains
complete -F _evodomains_dynamic_completion evodomains.py

