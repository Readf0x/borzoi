package main

import "base:runtime"
import "core:math/rand"
import "core:os/os2"
import "core:slice"
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
				RESET, format_timestamp(issue.time),

				issue.body,
			)
		} else {
			fmt.print(issue.body)
		}
	}
}

close :: proc() {
	// Issue(4BF8): Implement close command
	fmt.println("WIP")
}

list :: proc() {
	raw := get_issues()
	issues: []Issue

	if len(os.args) > 2 && os.args[2] == "-a" {
		issues = slice.filter(raw[:], all)
	} else {
		issues = slice.filter(raw[:], open_only)
	}

	delete(raw)

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
		status_string: string
		status_string_len: int
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
				format_timestamp(issue.time),
			}),
		)
		buf = { 0, 0, 0, 0 }
	}
}
open_only :: proc(issue: Issue) -> bool {
	return issue.status == .Open || issue.status == .Ongoing
}
all :: proc(issue: Issue) -> bool {
	return true
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

	stdout, proc_err := process_out({ "git", "config", "user.name" })
	if proc_err != os2.ERROR_NONE {
		if proc_err == os2.General_Error.Not_Exist {
			stdout, proc_err := process_out({ "whoami" })
			handle(proc_err != os2.ERROR_NONE, proc_err)
		} else {
			handle(true, proc_err)
		}
	}

	time, _ := time.time_to_rfc3339(time.now(), 0)

	file_err := os2.write_entire_file(path,
		transmute ([]byte)strings.concatenate({
			"# \n"+
			"- STATUS: Open\n"+
			"- AUTHOR: ",
			cast (string) stdout,
			"- PRIORI: 1\n",
			"- CRDATE: ",
			time,
			"\n",
		})
	)

	editor(path)
}

commit :: proc() {
	env, _ := os2.environ(context.allocator)

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

	porcelain, p_err := process_out({ "git", "status", "--porcelain", "." })
	handle(p_err != os2.ERROR_NONE, p_err)

	edited := make([dynamic]string, 0, 8)
	created := make([dynamic]string, 0, 8)
	for status in strings.split_iterator(cast (^string) &porcelain, "\n") {
		id := status[len(status)-7:len(status)-3]
		switch status[:2] {
		case " M":
			append(&edited, id)
		case "??":
			append(&created, id)
		case:
			handle(true, status)
		}
	}

	message := strings.builder_make()
	if len(created) != 0 {
		strings.write_string(&message, "created issue")
		if len(created) > 1 do strings.write_string(&message, "s")
		strings.write_string(&message, ": ")
		strings.write_string(&message, strings.join(created[:], ", "))
	}
	if len(created) != 0 && len(edited) != 0 {
		strings.write_string(&message, "; ")
	}
	if len(edited) != 0 {
		strings.write_string(&message, "edited issue")
		if len(edited) > 1 do strings.write_string(&message, "s")
		strings.write_string(&message, ": ")
		strings.write_string(&message, strings.join(edited[:], ", "))
	}

	start_process({ "git", "add", "." })
	start_process({ "git", "commit", "-m", strings.to_string(message) })

	// reapply old index
	apply_pr, apply_err := os2.process_start({
		"..", { "git", "apply", "--cached", "--allow-empty" }, env, os2.stderr, nil, pipe_r
	})
	handle(apply_err != os2.ERROR_NONE, apply_err)
}

delete_issue :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for id in os.args[2:] {
		path := issue_exists(id)
		err := os2.remove(path)
		handle(err != os2.ERROR_NONE, err)
	}
}

