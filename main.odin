package main

import "core:os/os2"
import "core:strings"
import "core:fmt"
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
	case .close:
		close()
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
	close,
	help,
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

gen :: proc() {
}

cat :: proc() {
	data, _ := os2.read_entire_file_from_path(getIssuePath(), context.allocator)
	fmt.print(cast (string)data)
}

close :: proc() {}

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
	Ongoing,
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

