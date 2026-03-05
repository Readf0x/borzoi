package main

import "core:slice"
import "core:os/os2"
import "core:strconv"
import "core:math"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:time"

main :: proc() {
	if len(os.args) < 2 {
		help(1)
	}
	if os.args[1] == "--help" || os.args[1] == "-h" {
		help(0)
	}
	command, exists := fmt.string_to_enum_value(Commands, os.args[1])
	if !exists {
		help(1)
	}
	switch command {
	case .list:
		list()
	case .open:
		open()
	case .new:
		new()
	case .cat:
		cat()
	case .gen:
		gen()
	case .help:
		help(0)
	}
}

Commands :: enum {
	list,
	open,
	cat,
	new,
	gen,
	help,
}

list :: proc() {
	raw := getIssues()
	issues: []Issue

	if len(os.args) > 2 && os.args[2] == "-a" {
		issues = slice.filter(raw[:], all)
	} else {
		issues = slice.filter(raw[:], open_only)
	}

	delete(raw)

	max_title := 0
	for issue in issues {
		max_title = math.max(max_title, len(issue.title))
	}
	fmt.println(strings.concatenate({
		BRIGHT_BLACK,
		UNDERLINE, "id  ", NO_UNDERLINE, "  ",
		UNDERLINE, "title", strings.repeat(" ", max_title-5), NO_UNDERLINE, "  ",
		UNDERLINE, "status ", NO_UNDERLINE, "  ",
		UNDERLINE, "creation date      ", RESET
	}))
	buf := make([]byte, 4)
	for issue in issues {
		id := strconv.write_uint(buf, u64(issue.id), 16)
		status_string, _ := fmt.enum_value_to_string(issue.status)
		fmt.println(
			strings.concatenate({
				strings.repeat("0", 4 - len(id)), id, "  ",
				issue.title, strings.repeat(" ", max_title - len(issue.title)), "  ",
				status_string, strings.repeat(" ", 3 - (len(status_string) - 4)), "  ",
				format_timestamp(issue.time),
			}),
		)
		buf = {0,0,0,0}
	}
}
open_only :: proc(issue: Issue) -> bool {
	return issue.status == .Open
}
all :: proc(issue: Issue) -> bool {
	return true
}

getIssues :: proc(sort: proc(a, b: Issue) -> bool = defaultIssueSort, allocator := context.allocator, loc := #caller_location) -> [dynamic]Issue {
	issues := make([dynamic]Issue, 0, 128, allocator, loc)
	filepath.walk("./.borzoi", walk, &issues)
	slice.sort_by(issues[:], sort)
	return issues
}

defaultIssueSort :: proc(a, b: Issue) -> bool {
		if a.priority != b.priority {
			return a.priority > b.priority
		}
		return a.id > b.id
	}

walk :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	if in_err != 0 {
		fmt.println(in_err)
		os.exit(1)
	}
	pattern, _ := regex.create_by_user(`/^[0-9a-f]{4}$/`)
	if _, success := regex.match(pattern, info.name); success {
		data, err := os.read_entire_file_from_filename_or_err(strings.concatenate({ "./.borzoi/", info.name }))
		if err != 0 {
			fmt.println(err)
			os.exit(1)
		}
		metadata := strings.split_lines_n(cast(string)data, 6)

		id, _ := strconv.parse_uint(info.name, 16)
		status, enum_ok := fmt.string_to_enum_value(Status, metadata[1][10:])
		if !enum_ok {
			fmt.printfln("%s:2:11: Invalid status '%s'", info.fullpath, metadata[1][10:])
			os.exit(1)
		}
		priority, atoi_ok := strconv.parse_uint(metadata[3][10:], 10)
		if !atoi_ok {
			fmt.printfln("%s:4:11: Invalid priority '%s'", info.fullpath, metadata[3][10:])
			os.exit(1)
		}
		time, consumed := time.rfc3339_to_time_utc(metadata[4][10:])
		if consumed == 0 {
			fmt.printfln("%s:4:11: Invalid creation date '%s'", info.fullpath, metadata[4][10:])
			os.exit(1)
		}

		append(cast (^[dynamic]Issue) user_data, Issue{
			id,
			metadata[0][2:], metadata[2][10:], metadata[5],
			{ time, 0 },
			priority,
			status,
		})
	}
	return
}

help :: proc(code: int) {
	fmt.print(
`usage: borzoi {list,new,open,cat,gen,help}
        borzoi gen [FILES...]

flat file issue tracker

positional arguments:
  {list,new,open,cat,gen,help}
    list  list issues
    new   new issue
    open  open issue in editor
    cat   print issue
    gen   generate issue from todo
    help  show this menu
`)
	os.exit(code)
}

open :: proc() {
	editor(getIssuePath())
}

getIssuePath :: proc() -> string {
	if len(os.args) < 3 {
		fmt.println("Missing id")
		os.exit(1)
	}
	issuePath := strings.concatenate({ "./.borzoi/", os.args[2] })
	_, err := os2.stat(issuePath, context.allocator)
	if err != os2.ERROR_NONE {
		switch err {
		case .Not_Exist:
			fmt.println("Issue doesn't exist")
		case:
			fmt.println(err)
		}
		os.exit(1)
	}
	return issuePath
}

editor :: proc(path: string) {
	editor := os.get_env("VISUAL")
	if editor == "" {
		editor = os.get_env("EDITOR")
	}
	env, _ := os2.environ(context.allocator)
	pr, errr := os2.process_start(os2.Process_Desc{
		".", { editor, path }, env, os2.stderr, os2.stdout, os2.stderr
	})
	if errr != os2.ERROR_NONE {
		fmt.println(errr)
		os.exit(1)
	}
	_, _ = os2.process_wait(pr)
}

new :: proc() {
	os2.change_directory("./.borzoi")
	files, err := os2.read_directory_by_path(".", 0, context.temp_allocator)
	if err != os2.ERROR_NONE {
		fmt.println(err)
		os.exit(1)
	}

	max_id : uint = 0
	for file in files {
		pattern, _ := regex.create_by_user(`/^[0-9a-f]{4}$/`)
		if _, success := regex.match(pattern, file.name); success {
			id, _ := strconv.parse_uint(file.name, 16)
			max_id = math.max(max_id, id)
		}
	}

	buf := make([]byte, 4, context.temp_allocator)
	idstr := strconv.write_uint(buf, u64(max_id+1), 16)

	path := strings.concatenate({
		strings.repeat("0", 4 - len(idstr)), idstr
	})

	file, errr := os2.create(path)
	if errr != os2.ERROR_NONE {
		fmt.println(errr)
		os.exit(1)
	}

	_, stdout, _, proc_err := os2.process_exec({
		".", { "git", "config", "user.name" }, nil, nil, nil, nil
	}, context.allocator)
	if proc_err != os2.ERROR_NONE {
		if proc_err == os2.General_Error.Not_Exist {
			_, stdout, _, proc_err = os2.process_exec({
				".", { "whoami" }, nil, nil, nil, nil
			}, context.allocator)
			if proc_err != os2.ERROR_NONE {
				fmt.println(proc_err)
				os.exit(1)
			}
		} else {
			fmt.println(proc_err)
			os.exit(1)
		}
	}

	time, ok := time.time_to_rfc3339(time.now(), 0)
	if !ok {
		os.exit(1)
	}

	file_err := os2.write_entire_file(path,
		transmute ([]byte)strings.concatenate({
			"# \n"+
			"- STATUS: Open\n"+
			"- AUTHOR: ",
			cast (string)stdout,
			"- PRIORI: 1\n",
			"- CRDATE: ",
			time,
			"\n",
		})
	)

	editor(path)
}

gen :: proc() {
}

cat :: proc() {
	data, _ := os2.read_entire_file_from_path(getIssuePath(), context.allocator)
	fmt.print(cast (string)data)
}

format_timestamp :: proc(t: Time) -> string {
	b: strings.Builder = strings.builder_make()

	year, month, day := time.date(t.time)
	hour, minute, sec := time.clock_from_time(t.time)

	fmt.sbprintf(&b, "%4d-%2d-%2d %2d:%2d:%2d", year, month, day, hour, minute, sec)

	return strings.to_string(b)
}

Issue :: struct {
	id: uint,
	title, author, body: string,
	time: Time,
	priority: uint,
	status: Status,
}

Time :: struct {
	time: time.Time,
	utc_offset: int,
}

Status :: enum {
	Open,
	Closed,
	Wontfix,
}

format :: proc(str: string, codes: []string, allocator := context.allocator, loc := #caller_location) -> string {
	parts: []string = make([]string, len(codes) + 2, allocator, loc)
	for c, i in codes {
		parts[i] = c
	}
	parts[len(codes)] = str
	parts[len(codes)+1] = RESET
	return strings.concatenate(parts, allocator, loc)
}

