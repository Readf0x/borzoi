package main

import "core:flags"
import "base:runtime"
import "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

@(require_results)
format_timestamp :: proc(t: time.Time) -> string {
	b: strings.Builder = strings.builder_make()

	// Issue(BE38): Local time formatting
	year, month, day := time.date(t)
	hour, minute, sec := time.clock_from_time(t)

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

editor :: proc(path: string) {
	editor := os.get_env("VISUAL")
	if editor == "" {
		editor = os.get_env("EDITOR")
		if editor == "" {
			editor = "vim"
		}
	}
	err := process_start({ editor, path })
}

@(require_results)
issue_exists :: proc(issue: string) -> string {
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

@(require_results)
list_args_parse :: proc(args: ^List_Args) -> (List_Filter) {
	err := flags.parse(args, os.args[2:], .Unix)
	handle(err != flags.Error(nil), proc(rawerr: rawptr) {
		err := cast (^flags.Error) rawerr
		// doesn't accept files so there shouldn't be Open_File_Error
		#partial switch t in err {
		case flags.Parse_Error:
			when !ODIN_DEBUG do fmt.printfln("Parse error: %s", t.message)
			else do fmt.printfln("Parse error: %v, %s", t.reason, t.message)
		case flags.Validation_Error:
			fmt.printfln("Validation error: %s", t.message)
		case flags.Help_Request:
			fmt.println(
				"usage: borzoi list [OPTIONS]\n\n" +

				"Options:\n" +
				"  --sort <value>\n" +
				"        Set the value to sort by. Possible values: *priority*, date\n\n" +

				"  --reverse\n" +
				"        Reverse the sort order.\n\n" +

				"  --text <string>\n" +
				"        Search for issues containing <string> in title or body.\n\n" +

				"  --title <string>\n" +
				"        Search for issues containing <string> in title.\n\n" +

				"  --body <string>\n" +
				"        Search for issues containing <string> in body.\n\n" +

				"  --status <status>\n" +
				"        Filter by status. Possible values: (*Open*, Closed, Wontfix, *Ongoing*).\n" +
				"        Can be specified multiple times.\n\n" +

				"  --closed\n" +
				"        Show only closed issues (Closed and Wontfix).\n\n" +

				"  --all\n" +
				"        Show all issues regardless of status.\n\n" +

				"  --priority <NUM>\n" +
				"        Show issues with exact priority <num>.\n\n" +

				"  --min-priority <num>\n" +
				"        Show issues with priority at least <num>.\n\n" +

				"  --max-priority <num>\n" +
				"        Show issues with priority at most <num>.\n\n" +

				"  --created-on <date>\n" +
				"        Show issues created on <date> (YYYY-MM-DD format).\n\n" +

				"  --created-before <date>\n" +
				"        Show issues created before <date>.\n\n" +

				"  --created-after <date>\n" +
				"        Show issues created after <date>.\n\n" +

				"  --author <name>\n" +
				"        Filter by author.\n" +
				"        Can be specified multiple times.\n\n" +

				"  --assignee <name>\n" +
				"        Filter by assignee.\n" +
				"        Can be specified multiple times.\n\n" +

				"  --label <label>\n" +
				"        Filter by label.\n" +
				"        Can be specified multiple times."
			)
			os.exit(0)
		}
	}, &err)

	filter: List_Filter = {
		statuses = { .Open, .Ongoing },
	}

	filter.sort = args.sort
	filter.reverse = args.reverse

	if args.closed do filter.statuses = { .Closed, .Wontfix }
	else if args.all do filter.statuses = { .Open, .Ongoing, .Closed, .Wontfix }
	else if args.status != {} do filter.statuses = args.status

	if len(args.text) != 0 {
		filter.title = args.text
		filter.body = args.text
	} else {
		filter.title = args.title
		filter.body = args.body
	}

	if args.priority != 0 do filter.priority_range = { args.priority, args.priority }
	else do filter.priority_range = { args.min_priority, args.max_priority }

	if args.created_on._nsec != 0 do filter.date_range = { args.created_on, args.created_on }
	else do filter.date_range = { args.created_before, args.created_after }

	filter.authors = args.author[:]
	filter.assignees = args.assignee[:]
	filter.labels = args.label[:]

	return filter
}

// handlef :: proc(assertion:bool, format: string, err: any, loc := #caller_location) {
// 	assert(assertion, fmt.bprintf(make([]byte, 256), format, err), loc)
// }

intty: bool

