# Borzoi fish completion

# Main commands
complete -c borzoi -n "__fish_use_subcommand" -f -a "init list new edit cat gen close commit delete version help git-hook"

# list command options
complete -c borzoi -n "__fish_seen_subcommand_from list" -l sort -r -d "Sort by priority or date"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l reverse -d "Reverse sort order"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l text -r -d "Search in title and body"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l title -r -d "Search in title"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l body -r -d "Search in body"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l status -r -d "Filter by status"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l closed -d "Show only closed issues"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l all -d "Show all issues"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l priority -r -d "Exact priority"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l min-priority -r -d "Minimum priority"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l max-priority -r -d "Maximum priority"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l created-on -r -d "Created on date"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l created-before -r -d "Created before date"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l created-after -r -d "Created after date"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l author -r -d "Filter by author"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l assignee -r -d "Filter by assignee"
complete -c borzoi -n "__fish_seen_subcommand_from list" -l label -r -d "Filter by label"

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
            ls $dir/.borzoi/*.md 2>/dev/null | sed 's|.*/\([0-9A-F]*\)\.md|\1|'
            return
        end
        set dir (dirname $dir)
    end
end
