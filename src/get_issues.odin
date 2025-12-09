package main

import "core:os/os2"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:time"

get_issues :: proc(sort: proc(a, b: Issue) -> bool = default_issue_sort, allocator := context.allocator, loc := #caller_location) -> [dynamic]Issue {
	issues := make([dynamic]Issue, 0, 128, allocator, loc)
	filepath.walk(".", walk, &issues)
	slice.sort_by(issues[:], sort)
	return issues
}
default_issue_sort :: proc(a, b: Issue) -> bool {
	if a.priority != b.priority {
		return a.priority > b.priority
	}
	return a.time._nsec > b.time._nsec
}
walk :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	if in_err != 0 {
		fmt.println(in_err)
		os.exit(1)
	}
	pattern, _ := regex.create_by_user(`/^[0-9A-F]{4}$/`)
	if _, success := regex.match(pattern, info.name); success {
		append(cast (^[dynamic]Issue) user_data, issue_from_path(info.name))
	}
	return
}
issue_from_path :: proc(path: string) -> Issue {
	data, _ := os2.read_entire_file_from_path(issue_exists(path), context.allocator)
	metadata := strings.split_lines_n(cast (string) data, 6)

	id, ok := strconv.parse_uint(path, 16)
	fullpath, _ := os2.get_working_directory(context.allocator)

	status, enum_ok := fmt.string_to_enum_value(Status, metadata[1][10:])
	if !enum_ok {
		fmt.printfln("%s:2:11: Invalid status '%s'", fullpath, metadata[1][10:])
		os.exit(1)
	}
	priority, atoi_ok := strconv.parse_uint(metadata[3][10:], 10)
	if !atoi_ok {
		fmt.printfln("%s:4:11: Invalid priority '%s'", fullpath, metadata[3][10:])
		os.exit(1)
	}
	time, consumed := time.rfc3339_to_time_utc(metadata[4][10:])
	if consumed == 0 {
		fmt.printfln("%s:4:11: Invalid creation date '%s'", fullpath, metadata[4][10:])
		os.exit(1)
	}

	body := metadata[5]
	if body == "" {
		body = BRIGHT_BLACK + "<Empty body>" + RESET
	}

	return {
		id,
		metadata[0][2:], metadata[2][10:], body,
		time,
		priority,
		status,
	}
}
