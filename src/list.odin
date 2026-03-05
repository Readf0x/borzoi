package main

import "core:flags"
import "core:slice"
import "core:math"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

list_filter: List_Filter
list :: proc() {
	args: List_Args = {
		max_priority = max(uint),
		created_after = {max(i64)},
	}

	list_filter = list_args_parse(&args)

	raw := get_issues()

	issues := slice.filter(raw[:], proc(issue: Issue) -> bool {
		if issue.status not_in list_filter.statuses do return false
		if len(list_filter.title) != 0 {
			if !strings.contains(issue.title, list_filter.title) do return false
		}
		if len(list_filter.body) != 0 {
			if !strings.contains(issue.body, list_filter.body) do return false
		}
		if issue.priority < list_filter.priority_range[0] ||
			 issue.priority > list_filter.priority_range[1] { return false }

		if issue.time.time._nsec < list_filter.date_range[0]._nsec ||
			 issue.time.time._nsec > list_filter.date_range[1]._nsec { return false }

		if len(list_filter.authors) != 0 {
			if !slice.contains(list_filter.authors, issue.author) do return false
		}
		// side effect of splitting and leaving the empty string, length is never zero.
		if len(list_filter.assignees) != 0 {
			for assignee in list_filter.assignees {
				if !slice.contains(issue.assignees, assignee) do return false
			}
		}
		if len(list_filter.labels) != 0 {
			for label in list_filter.labels {
				if !slice.contains(issue.labels, label) do return false
			}
		}
		return true
	})

	// this code is ugly, but unfortunately it's the most efficient way I can think of...
	sortproc: proc(a, b: Issue) -> bool
	if list_filter.reverse {
		switch list_filter.sort {
		case .priority:
			sortproc = proc(a, b: Issue) -> bool {
				if a.priority == b.priority do return a.time.time._nsec < b.time.time._nsec
				return a.priority < b.priority
			}
		case .date:
			sortproc = proc(a, b: Issue) -> bool {
				return a.time.time._nsec < b.time.time._nsec
			}
		}
	} else {
		switch list_filter.sort {
		case .priority:
			sortproc = proc(a, b: Issue) -> bool {
				if a.priority == b.priority do return a.time.time._nsec > b.time.time._nsec
				return a.priority > b.priority
			}
		case .date:
			sortproc = proc(a, b: Issue) -> bool {
				return a.time.time._nsec > b.time.time._nsec
			}
		}
	}
	slice.sort_by(issues, sortproc)

	// delete(raw)

	if len(issues) == 0 {
		fmt.println("No issues.")
		os.exit(0)
	}

	max_title := 0
	for issue in issues {
		max_title = math.max(max_title, len(issue.title))
	}

	sep := "  "
	if (intty) {
		fmt.println(strings.concatenate({
			BRIGHT_BLACK,
			UNDERLINE, "id  ", NO_UNDERLINE, "  ",
			UNDERLINE, "title", strings.repeat(" ", max_title-5), NO_UNDERLINE, "  ",
			UNDERLINE, "status ", NO_UNDERLINE, "  ",
			UNDERLINE, "creation date      ", RESET
		}))
	} else {
		sep = "\t"
	}
	buf := make([]byte, 4)
	for issue in issues {
		id := fmt.bprintf(buf, "%4X", issue.id)
		status_string     : string = ---
		status_string_len : int    = ---
		if (intty) {
			status_string, status_string_len = color_status(issue.status)
			id = strings.concatenate({ YELLOW, id, RESET })
		} else {
			status_string, _ = fmt.enum_value_to_string(issue.status)
			status_string_len = len(status_string)
		}
		fmt.println(
			strings.concatenate({
				id, sep,
				issue.title, strings.repeat(" ", max_title - len(issue.title)), sep,
				status_string, strings.repeat(" ", 3 - (status_string_len - 4)), sep,
				format_timestamp(issue.time.time),
			}),
		)
		buf = { 0, 0, 0, 0 }
	}
}

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
			list_help()
			os.exit(0)
		}
	}, &err)

	filter: List_Filter = { statuses = { .Open, .Ongoing } }

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
		filter.body = args.body }
	if args.priority != 0 do filter.priority_range = { args.priority, args.priority }
	else do filter.priority_range = { args.min_priority, args.max_priority }

	if args.created_on._nsec != 0 do filter.date_range = { args.created_on, args.created_on }
	else do filter.date_range = { args.created_before, args.created_after }

	filter.authors = args.author[:]
	filter.assignees = args.assignee[:]
	filter.labels = args.label[:]

	return filter
}

list_help :: #force_inline proc() {
	fmt.println(
		"Usage: borzoi list [OPTIONS]\n\n" +

		"Options:\n" +
		"  --sort <value>\n" +
		"\tSet the value to sort by. Possible values: *priority*, date\n\n" +

		"  --reverse\n" +
		"\tReverse the sort order.\n\n" +

		"  --text <string>\n" +
		"\tSearch for issues containing <string> in title or body.\n\n" +

		"  --title <string>\n" +
		"\tSearch for issues containing <string> in title.\n\n" +

		"  --body <string>\n" +
		"\tSearch for issues containing <string> in body.\n\n" +

		"  --status <status>\n" +
		"\tFilter by status. Possible values: (*Open*, Closed, Wontfix, *Ongoing*).\n" +
		"\tCan be specified multiple times.\n\n" +

		"  --closed\n" +
		"\tShow only closed issues (Closed and Wontfix).\n\n" +

		"  --all\n" +
		"\tShow all issues regardless of status.\n\n" +

		"  --priority <NUM>\n" +
		"\tShow issues with exact priority <num>.\n\n" +

		"  --min-priority <num>\n" +
		"\tShow issues with priority at least <num>.\n\n" +

		"  --max-priority <num>\n" +
		"\tShow issues with priority at most <num>.\n\n" +

		"  --created-on <date>\n" +
		"\tShow issues created on <date> (YYYY-MM-DD format).\n\n" +

		"  --created-before <date>\n" +
		"\tShow issues created before <date>.\n\n" +

		"  --created-after <date>\n" +
		"\tShow issues created after <date>.\n\n" +

		"  --author <name>\n" +
		"\tFilter by author.\n" +
		"\tCan be specified multiple times.\n\n" +

		"  --assignee <name>\n" +
		"\tFilter by assignee.\n" +
		"\tCan be specified multiple times.\n\n" +

		"  --label <label>\n" +
		"\tFilter by label.\n" +
		"\tCan be specified multiple times."
	)
}
