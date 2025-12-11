package main

import "core:slice"
import "base:runtime"
import "core:math/rand"
import "core:os/os2"
import "core:math"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

edit :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for issue in os.args[2:] {
		editor(issue_exists(strings.to_upper(issue)))
	}
}

gen :: proc() {
	// Issue(DE2E): Implement gen command
	fmt.println("WIP")
}

init :: proc() {
	err := os2.mkdir(".borzoi")
	handle(err != os2.ERROR_NONE, err)
}

cat :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for path in os.args[2:] {
		issue := issue_from_idstr(strings.to_upper(path))
		status, _ := color_status(issue.status)

		body := issue.body
		if body == "" {
			body = BRIGHT_BLACK + "<Empty body>" + RESET
		}

		if (intty) {
			fmt.printf(
				"\n%s%s%s %4X %s%s%s%s\n" +
				"%sStatus: %s%s%s  Author: %s%s%s  Priority: %s%d%s  Created: %s%s\n\n%s",

				BG_BLUE, BRIGHT_BLACK, BOLD, issue.id, BLACK, issue.title,
				strings.repeat(" ",
					math.max(80-len(issue.title), 0)+1
				),
				RESET,

				BRIGHT_BLACK, RESET, status, BRIGHT_BLACK,
				RESET, issue.author, BRIGHT_BLACK,
				RESET, issue.priority, BRIGHT_BLACK,
				RESET, format_timestamp(issue.time.time),

				body,
			)
		} else {
			fmt.print(issue.body)
		}
	}
}

// Issue(4BF8): Implement close command
close :: proc() {
	handle(len(os.args) < 3, "Missing id")
	buf := make([]byte, 7)
	for idstr in os.args[2:] {
		issue := issue_from_idstr(strings.to_upper(idstr))
		handle(issue.status == .Closed || issue.status == .Wontfix, "Already closed.")
		issue.status = .Closed
		str := issue_to_string(issue)
		err := os2.write_entire_file(fmt.bprintf(buf, "%4X.md", issue.id), transmute ([]byte) str)
		handle(err != os2.ERROR_NONE, err)
	}
}

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

new :: proc() {
	files, err := os2.read_directory_by_path(".", 0, context.temp_allocator)
	handle(err != os2.ERROR_NONE, err)

	now := cast (u64) time.now()._nsec
	rand.reset(now)
	rand_id := rand.uint32()

	buf := make([]byte, 7, context.temp_allocator)
	path := fmt.bprintf(buf, "%4X.md", rand_id & 0x0000FFFF)

	for os2.exists(path) {
		now += 1
		buf = { 0, 0, 0, 0, 0, 0, 0 }
		rand.reset(cast (u64) now)
		rand_id = rand.uint32()
		path = fmt.bprintf(buf, "%4X.md", rand_id & 0x0000FFFF)
	}

	username, u_err := get_username()
	handle(u_err != os2.ERROR_NONE, u_err)

	issuestr := issue_to_string(Issue{
		author = cast (string) username,
		// Issue(BE38): Local time formatting
		time = { time.now(), 0 },
		priority = 1,
	})

	file_err := os2.write_entire_file(path, transmute ([]byte) issuestr)

	editor(path)
}

commit :: proc() {
	env, _ := os2.environ(context.allocator)

	porcelain, p_err := process_out({ "git", "status", "--porcelain", "." })
	handle(p_err != os2.ERROR_NONE, p_err)

	if len(porcelain) == 0 {
		fmt.println("Nothing to commit")
		os.exit(1)
	}

	pipe_r, pipe_w, err := os2.pipe()
	handle(err != os2.ERROR_NONE, err)

	// reset DB just in case
	err = process_custom({
		".", { "git", "reset", "." }, env, os2.stderr, nil, nil
	})
	handle(err != os2.ERROR_NONE, err)

	// store staging index in pipe
	err = process_custom({
		"..", { "git", "diff", "--cached" }, env, os2.stderr, pipe_w, nil
	})
	handle(err != os2.ERROR_NONE, err)

	// reset index
	err = process_custom({
		"..", { "git", "reset" }, env, os2.stderr, nil, nil
	})
	handle(err != os2.ERROR_NONE, err)

	edited := make([dynamic]string, 0, 8)
	created := make([dynamic]string, 0, 8)
	deleted := make([dynamic]string, 0, 8)
	for status in strings.split_iterator(cast (^string) &porcelain, "\n") {
		id := status[len(status)-7:len(status)-3]
		switch status[:2] {
		case " M": fallthrough
		case "M ":
			append(&edited, id)
		case "??":
			append(&created, id)
		case " D": fallthrough
		case "D ":
			append(&deleted, id)
		case:
			handle(true, status)
		}
	}

	create_str :: proc(ids: []string, verb: string, b: ^strings.Builder) -> string {
		if len(ids) != 0 {
			strings.write_string(b, strings.concatenate({ verb, " issue" }))
			if len(ids) > 1 do strings.write_string(b, "s")
			strings.write_string(b, ": ")
			strings.write_string(b, strings.join(ids[:], ", "))
		}
		message := make([]byte, len(b.buf))
		copy(message, b.buf[:])
		strings.builder_reset(b)
		return cast (string) message
	}

	message_builder := strings.builder_make()

	list : [3]string = {
		create_str(created[:], "created", &message_builder),
		create_str(deleted[:], "deleted", &message_builder),
		create_str(edited[:],  "edited",  &message_builder),
	}
	#unroll for i in 0..<3 {
		if len(list[i]) != 0 {
			strings.write_string(&message_builder, list[i])
			// TODO: figure out how to remove first comparison at compile time
			if i < 2 && len(list[i + 1]) != 0 {
				strings.write_string(&message_builder, "; ")
			}
		}
	}

	process_start({ "git", "add", "." })
	process_start({ "git", "commit", "-m", strings.to_string(message_builder) })

	// reapply old index
	apply_pr, apply_err := os2.process_start({
		"..", { "git", "apply", "--cached", "--allow-empty" }, env, os2.stderr, nil, pipe_r
	})
	handle(apply_err != os2.ERROR_NONE, apply_err)
}

delete_issue :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for id in os.args[2:] {
		path := issue_exists(strings.to_upper(id))
		err := os2.remove(path)
		handle(err != os2.ERROR_NONE, err)
	}
}

