package main

import "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:time"

get_issues :: proc(allocator := context.allocator, loc := #caller_location) -> [dynamic]Issue {
	issues := make([dynamic]Issue, 0, 128, allocator, loc)
	filepath.walk(".", walk, &issues)
	return issues
}
walk :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	handle(in_err != 0, in_err)
	pattern, _ := regex.create_by_user(`/^[0-9A-F]{4}\.md$/`)
	if _, success := regex.match(pattern, info.name); success {
		append(cast (^[dynamic]Issue) user_data, issue_from_idstr(info.name[:4]))
	}
	return
}

issue_from_idstr :: proc(idstr: string) -> Issue {
	data, _ := os2.read_entire_file_from_path(issue_exists(idstr), context.allocator)
	metadata := strings.split_lines_n(cast (string) data, 8)

	id, ok := strconv.parse_uint(idstr[:4], 16)
	fullpath, _ := os2.get_working_directory(context.allocator)

	status, enum_ok := fmt.string_to_enum_value(Status, metadata[1][10:])
	handle(!enum_ok, "%s:2:11: Invalid status '%s'", fullpath, metadata[1][10:])

	priority, atoi_ok := strconv.parse_uint(metadata[2][10:], 10)
	handle(!atoi_ok, "%s:4:11: Invalid priority '%s'", fullpath, metadata[2][10:])

	assignees := strings.split(metadata[3][10:], ", ")
	labels := strings.split(metadata[4][10:], ", ")

	time, offset, consumed := time.rfc3339_to_time_and_offset(metadata[6][10:])
	handle(consumed == 0, "%s:4:11: Invalid creation date '%s'", fullpath, metadata[6][10:])

	body := metadata[7]
	if body == "" {
		body = BRIGHT_BLACK + "<Empty body>" + RESET
	}

	return {
		id,
		metadata[0][2:], metadata[5][10:], body,
		assignees, labels,
		{ time, offset },
		priority,
		status,
	}
}

issue_to_string :: proc(issue: Issue, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	timestr, _ := time.time_to_rfc3339(issue.time.time, issue.time.utc_offset, false)
	assignees := strings.join(issue.assignees, ", ")
	labels := strings.join(issue.labels, ", ")
	fmt.sbprintf(&b,
		"# %s\n" +          // metadata[0]
		"- STATUS: %v\n" +  // metadata[1]
		"- PRIORI: %d\n" +  // metadata[2]
		"- ASSIGN: %s\n" +  // metadata[3]
		"- LABELS: %s\n" +  // metadata[4]
		"- AUTHOR: %s\n" +  // metadata[5]
		"- CRDATE: %s\n%s", // metadata[6], [7]
		issue.title,
		issue.status,
		issue.priority,
		assignees,
		labels,
		issue.author,
		timestr,
		issue.body
	)
	return strings.to_string(b)
}
