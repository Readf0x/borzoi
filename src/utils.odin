package main

import "base:runtime"
import "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

format_timestamp :: proc(t: time.Time) -> string {
	b: strings.Builder = strings.builder_make()

	year, month, day := time.date(t)
	hour, minute, sec := time.clock_from_time(t)

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

color_status :: proc(status: Status) -> (formatted: string, length: int) {
	str, _ := fmt.enum_value_to_string(status)
	length = len(str)

	switch status {
	case .Open:
		formatted = strings.concatenate({ GREEN, str, RESET })
	case .Closed:
		formatted = strings.concatenate({ MAGENTA, str, RESET })
	case .Wontfix:
		formatted = strings.concatenate({ BRIGHT_BLACK, str, RESET })
	case .Ongoing:
		formatted = strings.concatenate({ YELLOW, str, RESET })
	}
	return
}

start_process :: proc(command: []string, allocator := context.allocator) -> os2.Error {
	env, _ := os2.environ(context.allocator)
	pr, err := os2.process_start(os2.Process_Desc{
		".", command, env, os2.stderr, os2.stdout, nil
	})
	if err != os2.ERROR_NONE do return err
	_, _ = os2.process_wait(pr)
	err = os2.process_close(pr)
	return os2.ERROR_NONE
}

process_out :: proc(command: []string, allocator := context.allocator) -> (stdout: []byte, err: os2.Error) {
	_, stdout, _, err = os2.process_exec({
		".", command, nil, nil, nil, nil
	}, context.allocator)
	return
}

process_custom :: proc(desc: os2.Process_Desc) -> os2.Error {
	pr, err := os2.process_start(desc)
	if err != os2.ERROR_NONE do return err
	_, _ = os2.process_wait(pr)
	err = os2.process_close(pr)
	if err != os2.ERROR_NONE do return err
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

issue_exists :: proc(issue: string) -> string {
	path := strings.concatenate({ issue, ".md" })
	_, err := os2.stat(path, context.allocator)
	handle(err != os2.ERROR_NONE, proc(err: rawptr) {
		switch (cast (^os2.Error) err)^ {
		case .Not_Exist:
			fmt.println("Issue doesn't exist")
		case:
			fmt.println(err)
		}
		os.exit(1)
	}, &err)
	return path
}

handle_any :: #force_inline proc(when_this: bool, err: any, loc := #caller_location) {
	when ODIN_DEBUG {
		assert(!when_this, fmt.bprintf(make([]byte, 256), "%v", err), loc)
	}
	when !ODIN_DEBUG {
		if when_this {
			fmt.printfln("%v", err)
			os.exit(1)
		}
	}
}
handle_proc :: #force_inline proc(when_this: bool, callback: proc(user_data: rawptr), user_data: rawptr, loc := #caller_location) {
	if when_this {
		when ODIN_DEBUG do fmt.printfln("%v", loc)
		#force_inline callback(user_data)
		when ODIN_DEBUG do runtime.trap()
		when !ODIN_DEBUG do os.exit(1)
	}
}

handle :: proc{ handle_any, handle_proc }

// handlef :: proc(assertion:bool, format: string, err: any, loc := #caller_location) {
// 	assert(assertion, fmt.bprintf(make([]byte, 256), format, err), loc)
// }

intty: bool

