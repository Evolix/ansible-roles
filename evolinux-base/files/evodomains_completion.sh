#!/usr/bin/env bash

_evodomains_dynamic_completion() {
    prev="${COMP_WORDS[$COMP_CWORD - 1]}"
    words=""
    case "${prev}" in
        evodomains)
            words="check-dns list --output --help"
            ;;
        -o|--output)
            if [[ "${COMP_LINE}" =~ list ]]; then
                words="human json"
            else
                words="nrpe json human"
            fi
            ;;
        check-dns)
            words="--output --help"
            ;;
        list)
            words="--output --help"
            ;;
        nrpe|json|human)
            if [[ ! "${COMP_LINE}" =~ (check-dns|list) ]]; then
                words="check-dns list"
            fi
            ;;
        *)
            ;;
    esac
    local current_word=${COMP_WORDS[COMP_CWORD]};
    COMPREPLY=($(compgen -W "$words" -- "$current_word"))
}

complete -F _evodomains_dynamic_completion evodomains

