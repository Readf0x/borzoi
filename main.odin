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

	for !os2.exists(".borzoi") {
		dir, err := os2.get_working_directory(context.allocator)
		if err != os2.ERROR_NONE {
			fmt.println(err)
			os.exit(1)
		}
		if dir == "/" {
			fmt.println("No DB")
		}
		err = os2.change_directory("../")
		if err != os2.ERROR_NONE {
			fmt.println(err)
			os.exit(1)
		}
	}
	err := os2.change_directory(".borzoi")
	if err != os2.ERROR_NONE {
		fmt.println(err)
		os.exit(1)
	}

	switch command {
	case .init:
		init()
	case .list:
		list()
	case .edit:
		edit()
	case .new:
		new()
	case .cat:
		cat()
	case .gen:
		gen()
	case .close:
		close()
	// case .commit:
	// 	commit()
	case .version:
		version()
	case .help:
		help(0)
	}
}

Commands :: enum {
	init,
	list,
	edit,
	cat,
	new,
	gen,
	close,
	// commit,
	version,
	help,
}

help :: proc(code: int) {
	fmt.print(
`usage: borzoi {list,new,version,help}
       borzoi {edit,cat,close} <ISSUE>
       borzoi gen [FILES...]

flat file issue tracker

positional arguments:
  {list,new,edit,cat,gen,close,version,help}
    list     list issues
    new      new issue
    edit     open issue in editor
    cat      print issue
    gen      generate issue from todo
    close    close issue
    version  print version
    help     show this menu
`)
	os.exit(code)
}

versionInfo: string : #config(VERSION, "Not defined")
version :: proc() {
	fmt.println(versionInfo)
	os.exit(0)
}

edit :: proc() {
	editor(getIssuePath())
}

getIssuePath :: proc() -> string {
	if len(os.args) < 3 {
		fmt.println("Missing id")
		os.exit(1)
	}
	issuePath := os.args[2]
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
		if editor == "" {
			editor = "vim"
		}
	}
	err := start_process({ editor, path })
}

gen :: proc() {
	fmt.println("WIP")
}

init :: proc() {
	err := os2.mkdir(".borzoi")
	if err != os2.ERROR_NONE {
		fmt.println(err)
	}
}

cat :: proc() {
	data, _ := os2.read_entire_file_from_path(getIssuePath(), context.allocator)
	fmt.print(cast (string)data)
}

close :: proc() {
	fmt.println("WIP")
}

start_process :: proc(command: []string, allocator := context.allocator) -> os2.Error {
	env, _ := os2.environ(context.allocator)
	pr, err := os2.process_start(os2.Process_Desc{
		".", command, env, os2.stderr, os2.stdout, os2.stderr
	})
	if err != os2.ERROR_NONE {
		return err
	}
	_, _ = os2.process_wait(pr)
	return os2.ERROR_NONE
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

