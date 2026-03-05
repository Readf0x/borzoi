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
	filename := idstr_to_path(idstr)
	data, _ := os2.read_entire_file_from_path(filename, context.allocator)
	metadata := strings.split_lines_n(cast (string) data, 10)

	id, ok := strconv.parse_uint(idstr, 16)
	fullpath, _ := os2.get_working_directory(context.allocator)
	fullpath = strings.concatenate({ fullpath, "/", filename })

	status, enum_ok := fmt.string_to_enum_value(Status, metadata[1][8:])
	handle(!enum_ok, "%s:2:11: Invalid status '%s'", fullpath, metadata[1][8:])

	priority, atoi_ok := strconv.parse_uint(metadata[2][8:], 10)
	handle(!atoi_ok, "%s:4:11: Invalid priority '%s'", fullpath, metadata[2][8:])

	assignees := strings.split(metadata[3][8:], ", ")
	labels := strings.split(metadata[4][8:], ", ")

	time, offset, consumed := time.rfc3339_to_time_and_offset(metadata[6][8:])
	handle(consumed == 0, "%s:4:11: Invalid creation date '%s'", fullpath, metadata[6][8:])

	return {
		id,
		metadata[8][2:], metadata[5][8:], metadata[9],
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
		"---\n" +         // metadata[0]
		"status: %v\n" +  // metadata[1]
		"priori: %d\n" +  // metadata[2]
		"assign: %s\n" +  // metadata[3]
		"labels: %s\n" +  // metadata[4]
		"author: %s\n" +  // metadata[5]
		"crdate: %s\n" +  // metadata[6]
		"---\n" +         // metadata[7]
		"# %s\n%s",       // metadata[8], [9]
		issue.status,
		issue.priority,
		assignees,
		labels,
		issue.author,
		timestr,
		issue.title,
		issue.body
	)
	return strings.to_string(b)
}
