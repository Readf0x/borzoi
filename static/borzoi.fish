# Borzoi fish completion

# Main commands
complete -c borzoi -n "__fish_use_subcommand" -f -a "init list new edit cat gen close commit delete version help"

# list command options
complete -c borzoi -n "__fish_seen_subcommand_from list" -s a -d "list all issues"

# Commands that take issue IDs
for cmd in edit cat close delete
    complete -c borzoi -n "__fish_seen_subcommand_from $cmd" -f -a "(__borzoi_issues)"
end

# gen command takes files
complete -c borzoi -n "__fish_seen_subcommand_from gen" -F -d "source file"

function __borzoi_issues
    set -l dir $PWD
    while test $dir != /
        if test -d $dir/.borzoi
            ls $dir/.borzoi/*.md 2>/dev/null | sed 's|.*/\([0-9A-F]*\)\.md|\1|' | tr '[:upper:]' '[:lower:]'
            return
        end
        set dir (dirname $dir)
    end
end
