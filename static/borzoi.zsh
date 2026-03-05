#compdef borzoi

__find_borzoi_dir() {
    local dir=$PWD
    while [[ $dir != / ]]; do
        if [[ -d $dir/.borzoi ]]; then
            echo $dir/.borzoi
            return 0
        fi
        dir=${dir:h}
    done
    return 1
}

_borzoi() {
    local -a commands
    commands=(
        'init:initialize repository'
        'list:list issues'
        'new:create new issue'
        'edit:edit issue'
        'cat:print issue'
        'gen:generate issue from todo'
        'close:close issue'
        'commit:commit changes'
        'delete:delete issue'
        'version:print version'
        'help:show help'
    )

    _arguments -C \
        '1: :->cmds' \
        '*:: :->args'

    case $state in
        cmds)
            _describe -t commands 'borzoi command' commands
            ;;
        args)
            case $words[2] in
                list)
                    _arguments \
                        '-a[list all issues]'
                    ;;
                edit|cat|close|delete)
                    local borzoi_dir
                    if borzoi_dir=$(__find_borzoi_dir); then
                        local -a issues
                        issues=(${${(f)"$(ls $borzoi_dir/*.md 2>/dev/null)"}##*/})
                        issues=(${issues%.md})
                        _describe -t issues 'issue ID' issues
                    fi
                    ;;
                gen)
                    _files
                    ;;
            esac
            ;;
    esac
}