package main

import "core:sys/posix"
import "core:os/os2"
import "core:fmt"
import "core:os"

Command :: enum { init, list, edit, cat, new, gen, close, commit, delete, template, version, help }
no_db_needed : bit_set[Command] : { .version, .init, .help }

main :: proc() {
	if len(os.args) < 2 do help(1)
	if os.args[1] == "--help" || os.args[1] == "-h" do help(0)
	// I wanted this to be in the command enum but names can't contain dashes
	if os.args[1] == "git-hook" {
		git_hooks()
		os.exit(0)
	}

	command, exists := fmt.string_to_enum_value(Command, os.args[1])
	if !exists do help(1)

	intty = cast (bool) posix.isatty(cast (posix.FD) os2.fd(os2.stdout))

	if command not_in no_db_needed {
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
		case .init:     init()
		case .list:     list()
		case .edit:     edit()
		case .new:      new()
		case .cat:      cat()
		case .gen:      gen()
		case .close:    close()
		case .commit:   commit()
		case .delete:   delete_issue()
		case .template: template()
		case .version:  version()
		case .help:     help(0)
	}
}

help :: proc(code: int) {
	fmt.println(
		"flat file issue tracker\n\n" +

		"Usage: borzoi {init,list,new,commit,version,help}\n" +
		"       borzoi {edit,cat,close,delete} [ISSUES...]\n" +
		"       borzoi gen [FILES...]\n\n" +

		"Positional arguments:\n" +
		"  {init,list,new,edit,cat,gen,close,commit,delete,version,help}\n" +
		"    init      initialize repository\n" +
		"    list      list issues\n" +
		"    new       new issue\n" +
		"    edit      open issue in editor\n" +
		"    cat       print issue\n" +
		"    gen       generate issue from todo\n" +
		"    close     close issue\n" +
		"    commit    commit changes\n" +
		"    delete    delete issue\n" +
		"    version   print version\n" +
		"    template  template management\n" +
		"    help      show this menu\n" +
		"    git-hook  deploy post commit hook"
	)
	os.exit(code)
}

versionInfo: string : #config(VERSION, "Not defined")
version :: proc() {
	when ODIN_DEBUG do fmt.printfln("%s%s%s", RED, "debug build", RESET)
	fmt.println(versionInfo)
	os.exit(0)
}
