package main

import "core:time/timezone"
import "base:runtime"
import "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

@(require_results)
format_timestamp :: proc(t: Time) -> string {
	b: strings.Builder = strings.builder_make()

	// Issue(BE38): Local time formatting
	post_offset: time.Time = { t.time._nsec + ( i64(t.utc_offset) * i64(time.Minute) ) }
	year, month, day := time.date(post_offset)
	hour, minute, sec := time.clock_from_time(post_offset)

	fmt.sbprintf(&b, "%4d-%2d-%2d %2d:%2d:%2d", year, month, day, hour, minute, sec)

	return strings.to_string(b)
}

@(require_results)
format :: proc(str: string, codes: []string, allocator := context.allocator, loc := #caller_location) -> string {
	parts: []string = make([]string, len(codes) + 2, allocator, loc)
	for c, i in codes {
		parts[i] = c
	}
	parts[len(codes)] = str
	parts[len(codes)+1] = RESET
	return strings.concatenate(parts, allocator, loc)
}

@(require_results)
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

process_start :: proc(command: []string, error_on_fail := true, allocator := context.allocator) -> os2.Error {
	env, _ := os2.environ(context.allocator)
	pr, err := os2.process_start(os2.Process_Desc{
		".", command, env, os2.stderr, os2.stdout, nil
	})
	if err != os2.ERROR_NONE do return err
	_, _ = os2.process_wait(pr)
	err = os2.process_close(pr)
	return os2.ERROR_NONE
}

@(require_results)
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

@(require_results)
editor :: proc(path: string) -> os2.Error {
	editor := os.get_env("VISUAL")
	if editor == "" {
		editor = os.get_env("EDITOR")
		if editor == "" {
			editor = "vim"
		}
	}
	err: os2.Error
	switch editor {
	case "vi":  fallthrough
	case "vim": fallthrough
	case "nvim":
		err = process_start({ editor, "+normal9G2l", path })
	case "emacs": fallthrough
	case "emacsclient":
		err = process_start({ editor, "+9", path })
	case:
		err = process_start({ editor, path })
	}
	return err
}

@(require_results)
idstr_to_path :: proc(issue: string) -> string {
	path := strings.concatenate({ issue, ".md" })
	_, err := os2.stat(path, context.allocator)
	handle(err != os2.ERROR_NONE, proc(err: rawptr) {
		switch (cast (^os2.Error) err)^ {
		case .Not_Exist:
			fmt.println("No such issue")
		case:
			fmt.println(err)
		}
		os.exit(1)
	}, &err)
	return path
}

@(require_results)
get_username :: proc() -> (string, os2.Error) {
	username, err := process_out({ "git", "config", "user.name" })
	if err != os2.ERROR_NONE {
		if err == os2.General_Error.Not_Exist {
			username, err = process_out({ "whoami" })
		}
	}
	username = username[:len(username) - 1]
	return cast (string) username, err
}

get_utc_offset :: proc() -> int {
	region, ok := timezone.region_load("local")
	utc_offset: i64
	if ok && len(region.records) > 0 do utc_offset = region.records[0].utc_offset
	else {
		stdout, err := process_out({ "date", "--rfc-3339=seconds" })
		handle(err != os2.ERROR_NONE, err)
		_, offset, con := time.rfc3339_to_time_and_offset(cast (string) stdout[:len(stdout) - 1])
		if con > 0 do return offset
	}
	return cast (int) utc_offset
}

handle_any :: #force_inline proc(when_this: bool, err: any, loc := #caller_location) {
	when ODIN_DEBUG {
		assert(!when_this, fmt.bprintf(make([]byte, 256), "%v", err), loc)
	} else {
		if when_this {
			fmt.printfln("%v", err)
			os.exit(1)
		}
	}
}
handle_proc_user :: #force_inline proc(when_this: bool, callback: proc(user_data: rawptr), user_data: rawptr, loc := #caller_location) {
	if when_this {
		when ODIN_DEBUG do fmt.printfln("%v", loc)
		#force_inline callback(user_data)
		when ODIN_DEBUG do runtime.trap()
		else do os.exit(1)
	}
}
handle_proc :: #force_inline proc(when_this: bool, callback: proc(), loc := #caller_location) {
	if when_this {
		when ODIN_DEBUG do fmt.printfln("%v", loc)
		#force_inline callback()
		when ODIN_DEBUG do runtime.trap()
		else do os.exit(1)
	}
}
handle_format :: #force_inline proc(when_this: bool, format: string, args: ..any, loc := #caller_location) {
	if when_this {
		when ODIN_DEBUG do fmt.printfln("%v", loc)
		fmt.printfln(format, ..args)
		when ODIN_DEBUG do runtime.trap()
		else do os.exit(1)
	}
}

handle :: proc{ handle_any, handle_proc_user, handle_proc, handle_format }

intty: bool
