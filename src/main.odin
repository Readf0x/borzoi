package main

import "core:sys/posix"
import "core:os/os2"
import "core:fmt"
import "core:os"

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

	intty = cast (bool) posix.isatty(cast (posix.FD) os2.fd(os2.stdout))

	if command != .version && command != .init && command != .help {
		for !os2.exists(".borzoi") {
			dir, err := os2.get_working_directory(context.allocator)
			handle(err != os2.ERROR_NONE, err)
			handle(dir == "/", "No DB")
			err = os2.change_directory("../")
			handle(err != os2.ERROR_NONE, err)
		}

		err := os2.change_directory(".borzoi")
		handle(err != os2.ERROR_NONE, err)
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
	case .commit:
		commit()
	case .delete:
		delete_issue()
	case .version:
		version()
	case .help:
		help(0)
	}
}

help :: proc(code: int) {
	fmt.print(
`usage: borzoi {init,list,new,commit,version,help}
       borzoi {edit,cat,close,delete} [ISSUES...]
       borzoi gen [FILES...]

flat file issue tracker

positional arguments:
  {init,list,new,edit,cat,gen,close,commit,delete,version,help}
    init     initialize repository
    list     list issues
    new      new issue
    edit     open issue in editor
    cat      print issue
    gen      generate issue from todo
    close    close issue
    commit   commit changes
    delete   delete issue
    version  print version
    help     show this menu
`)
	os.exit(code)
}

versionInfo: string : #config(VERSION, "Not defined")
version :: proc() {
	when ODIN_DEBUG do fmt.printfln("%s%s%s", RED, "debug build", RESET)
	fmt.println(versionInfo)
	os.exit(0)
}
