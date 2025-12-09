package main

import "core:math/rand"
import "core:os/os2"
import "core:slice"
import "core:math"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

edit :: proc() {
	if len(os.args) < 3 {
		fmt.println("Missing id")
		os.exit(1)
	}
	for issue in os.args[2:] {
		editor(issue_exists(issue))
	}
}

gen :: proc() {
	// Issue(DE2E): Implement gen command
	fmt.println("WIP")
}

init :: proc() {
	err := os2.mkdir(".borzoi")
	if err != os2.ERROR_NONE {
		fmt.println(err)
	}
}

cat :: proc() {
	if len(os.args) < 3 {
		fmt.println("Missing id")
		os.exit(1)
	}
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
	if err != os2.ERROR_NONE {
		fmt.println(err)
		os.exit(1)
	}

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
			if proc_err != os2.ERROR_NONE {
				fmt.println(proc_err)
				os.exit(1)
			}
		} else {
			fmt.println(proc_err)
			os.exit(1)
		}
	}

	time, ok := time.time_to_rfc3339(time.now(), 0)
	if !ok {
		os.exit(1)
	}

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
	// Issue(0445): Implement commit command
	fmt.println("WIP")
}

delete_issue :: proc() {
	if len(os.args) < 3 {
		fmt.println("Missing id")
		os.exit(1)
	}
	for id in os.args[2:] {
		path := issue_exists(id)
		err := os2.remove(path)
		if err != os2.ERROR_NONE {
			fmt.println(err)
			os.exit(1)
		}
	}
}

