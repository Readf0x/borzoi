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
				'template:manage templates'
        'help:show help'
        'git-hook:deploy git hook'
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
                        '--sort=[sort by priority or date]:sort:(priority date)' \
                        '--reverse[reverse sort order]' \
                        '--text=[search in title and body]:string' \
                        '--title=[search in title]:string' \
                        '--body=[search in body]:string' \
                        '--status=[filter by status]:status:(Open Closed Wontfix Ongoing)' \
                        '--closed[show only closed issues]' \
                        '--all[show all issues]' \
                        '--priority=[exact priority]:number' \
                        '--min-priority=[minimum priority]:number' \
                        '--max-priority=[maximum priority]:number' \
                        '--created-on=[created on date]:date' \
                        '--created-before=[created before date]:date' \
                        '--created-after=[created after date]:date' \
                        '--author=[filter by author]:string' \
                        '--assignee=[filter by assignee]:string' \
                        '--label=[filter by label]:string'
                    ;;
                template)
                    _arguments \
                        'new' \
                        'cat' \
                        'list'
                    ;;
                cat)
                    # Check if this is "template cat" or just "cat"
                    local is_template_cat=0
                    for word in $words; do
                        if [[ $word == "template" ]]; then
                            is_template_cat=1
                            break
                        fi
                    done

                    if [[ $is_template_cat -eq 1 ]]; then
                        # Complete with template names
                        local borzoi_dir
                        if borzoi_dir=$(__find_borzoi_dir); then
                            local -a templates
                            templates=(${${(f)"$(ls $borzoi_dir/template.*.md 2>/dev/null | sed 's|.*/template\.\(.*\)\.md|\1|')"}##*/})
                            _describe -t templates 'template name' templates
                        fi
                    else
                        # Complete with issue IDs
                        local borzoi_dir
                        if borzoi_dir=$(__find_borzoi_dir); then
                            local -a issues
                            issues=(${${(f)"$(ls $borzoi_dir/*.md 2>/dev/null)"}##*/})
                            issues=(${issues%.md})
                            _describe -t issues 'issue ID' issues
                        fi
                    fi
                    ;;
                edit|close|delete)
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
