package main

import "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

format_timestamp :: proc(t: Time) -> string {
	b: strings.Builder = strings.builder_make()

	year, month, day := time.date(t.time)
	hour, minute, sec := time.clock_from_time(t.time)

	fmt.sbprintf(&b, "%4d-%2d-%2d %2d:%2d:%2d", year, month, day, hour, minute, sec)

	return strings.to_string(b)
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

