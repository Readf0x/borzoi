#!/bin/bash

__find_borzoi_dir() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.borzoi" ]]; then
            echo "$dir/.borzoi"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

_borzoi_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    opts="init list new edit cat gen close commit delete version help git-hook"

    # Commands that take issue IDs
    issue_cmds="edit cat close delete"

    # Commands that take files
    file_cmds="gen"

    case "${prev}" in
        borzoi)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        list)
            COMPREPLY=( $(compgen -W "--sort --reverse --text --title --body --status --closed --all --priority --min-priority --max-priority --created-on --created-before --created-after --author --assignee --label" -- ${cur}) )
            return 0
            ;;
        --sort)
            COMPREPLY=( $(compgen -W "priority date" -- ${cur}) )
            return 0
            ;;
        --status)
            COMPREPLY=( $(compgen -W "Open Closed Wontfix Ongoing" -- ${cur}) )
            return 0
            ;;
        edit|cat|close|delete)
            # Complete with issue IDs from .borzoi directory (search upward)
            local borzoi_dir
            if borzoi_dir=$(__find_borzoi_dir); then
                local issues=$(ls "$borzoi_dir"/*.md 2>/dev/null | sed 's|.*/\([0-9A-F]\{4\}\)\.md|\1|' | tr '[:upper:]' '[:lower:]')
                COMPREPLY=( $(compgen -W "${issues}" -- ${cur}) )
            fi
            return 0
            ;;
        gen)
            # Complete with files
            COMPREPLY=( $(compgen -f -- ${cur}) )
            return 0
            ;;
    esac
}

complete -F _borzoi_completions borzoi
