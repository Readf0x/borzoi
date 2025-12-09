package main

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
		".", command, env, os2.stderr, os2.stdout, os2.stderr
	})
	if err != os2.ERROR_NONE {
		return err
	}
	_, _ = os2.process_wait(pr)
	return os2.ERROR_NONE
}

process_out :: proc(command: []string, allocator := context.allocator) -> (stdout: []byte, err: os2.Error) {
	_, stdout, _, err = os2.process_exec({
		".", { "git", "config", "user.name" }, nil, nil, nil, nil
	}, context.allocator)
	return
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
	_, err := os2.stat(issue, context.allocator)
	if err != os2.ERROR_NONE {
		switch err {
		case .Not_Exist:
			fmt.println("Issue doesn't exist")
		case:
			fmt.println(err)
		}
		os.exit(1)
	}
	return issue
}

intty: bool

