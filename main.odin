package main

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
