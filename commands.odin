package main

import "core:os/os2"
import "core:sys/posix"
import "core:slice"
import "core:strconv"
import "core:math"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:os"
import "core:time"

edit :: proc() {
	editor(getIssuePath())
}

gen :: proc() {
	fmt.println("WIP")
}

init :: proc() {
	err := os2.mkdir(".borzoi")
	if err != os2.ERROR_NONE {
		fmt.println(err)
	}
}

cat :: proc() {
	data, _ := os2.read_entire_file_from_path(getIssuePath(), context.allocator)
	fmt.print(cast (string)data)
}

close :: proc() {
	fmt.println("WIP")
}

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

new :: proc() {
	files, err := os2.read_directory_by_path(".", 0, context.temp_allocator)
	if err != os2.ERROR_NONE {
		fmt.println(err)
		os.exit(1)
	}

	max_id : uint = 0
	for file in files {
		pattern, _ := regex.create_by_user(`/^[0-9a-f]{4}$/`)
		if _, success := regex.match(pattern, file.name); success {
			id, _ := strconv.parse_uint(file.name, 16)
			max_id = math.max(max_id, id)
		}
	}

	buf := make([]byte, 4, context.temp_allocator)
	idstr := strconv.write_uint(buf, u64(max_id+1), 16)

	path := strings.concatenate({
		strings.repeat("0", 4 - len(idstr)), idstr
	})

	file, errr := os2.create(path)
	if errr != os2.ERROR_NONE {
		fmt.println(errr)
		os.exit(1)
	}

	_, stdout, _, proc_err := os2.process_exec({
		".", { "git", "config", "user.name" }, nil, nil, nil, nil
	}, context.allocator)
	if proc_err != os2.ERROR_NONE {
		if proc_err == os2.General_Error.Not_Exist {
			_, stdout, _, proc_err = os2.process_exec({
				".", { "whoami" }, nil, nil, nil, nil
			}, context.allocator)
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
			cast (string)stdout,
			"- PRIORI: 1\n",
			"- CRDATE: ",
			time,
			"\n",
		})
	)

	editor(path)
}

// commit :: proc() {
// 	start_process({ "git", "add", ".borzoi" })
// 	start_process({ "git", "commit", "-m", "add issue" })
// }
