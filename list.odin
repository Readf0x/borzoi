package main

import "core:os/os2"
import "core:sys/posix"
import "core:slice"
import "core:strconv"
import "core:math"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

list :: proc() {
	raw := getIssues()
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
	if (posix.isatty(cast (posix.FD)os2.fd(os2.stdout))) {
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
		id := strconv.write_uint(buf, u64(issue.id), 16)
		status_string, _ := fmt.enum_value_to_string(issue.status)
		fmt.println(
			strings.concatenate({
				strings.repeat("0", 4 - len(id)), id, sep,
				issue.title, strings.repeat(" ", max_title - len(issue.title)), sep,
				status_string, strings.repeat(" ", 3 - (len(status_string) - 4)), sep,
				format_timestamp(issue.time),
			}),
		)
		buf = {0,0,0,0}
	}
}
open_only :: proc(issue: Issue) -> bool {
	return issue.status == .Open || issue.status == .Ongoing
}
all :: proc(issue: Issue) -> bool {
	return true
}
