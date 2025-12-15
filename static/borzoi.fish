# Borzoi fish completion

# Main commands
complete -c borzoi -n 'test (count (commandline -poc)) -eq 1' -f -a "init list new edit cat gen close commit delete version template help git-hook"

# list command options
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l sort -r -a "priority date" -d "Sort by priority or date"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l reverse -d "Reverse sort order"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l text -r -d "Search in title and body"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l title -r -d "Search in title"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l body -r -d "Search in body"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l status -r -a "Open Closed Wontfix Ongoing" -d "Filter by status"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l closed -d "Show only closed issues"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l all -d "Show all issues"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l priority -r -d "Exact priority"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l min-priority -r -d "Minimum priority"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l max-priority -r -d "Maximum priority"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l created-on -r -d "Created on date"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l created-before -r -d "Created before date"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l created-after -r -d "Created after date"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l author -r -d "Filter by author"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l assignee -r -d "Filter by assignee"
complete -c borzoi -f -n "__fish_seen_subcommand_from list" -l label -r -d "Filter by label"

# template options
complete -c borzoi -n '__fish_seen_subcommand_from template; and test (count (commandline -poc)) -eq 2' -f -a "new cat list"

# Commands that take issue IDs (but not when used as template subcommands)
for cmd in edit close delete
    complete -c borzoi -n "__fish_seen_subcommand_from $cmd" -f -a "(__borzoi_issues)"
end

# cat command takes issue IDs (only when cat is a top-level command)
complete -c borzoi -n '__fish_seen_subcommand_from cat; and not __fish_seen_subcommand_from template' -a "(__borzoi_issues)"

# template cat takes template names
complete -c borzoi -n "__fish_seen_subcommand_from template; and __fish_seen_subcommand_from cat" -a "(__borzoi_templates)"

# gen command takes files
complete -c borzoi -n "__fish_seen_subcommand_from gen" -F -d "source file"

function __borzoi_issues
    set -l dir $PWD
    while test $dir != /
        if test -d $dir/.borzoi
            ls $dir/.borzoi/*.md 2>/dev/null | grep -E '/[0-9A-F]{4}\.md$' | sed 's|.*/\([0-9A-F]\{4\}\)\.md|\1|'
            return
        end
        set dir (dirname $dir)
    end
end

function __borzoi_template_no_subcommand
    __fish_seen_subcommand_from template
    and not __fish_seen_subcommand_from new
    and not __fish_seen_subcommand_from cat
    and not __fish_seen_subcommand_from list
end

function __borzoi_cat_top_level
    __fish_seen_subcommand_from cat
    and not __fish_seen_subcommand_from template
end

function __borzoi_templates
    set -l dir $PWD
    while test $dir != /
        if test -d $dir/.borzoi
            ls $dir/.borzoi/template.*.md 2>/dev/null | sed 's|.*/template\.\(.*\)\.md|\1|'
            return
        end
        set dir (dirname $dir)
    end
end
