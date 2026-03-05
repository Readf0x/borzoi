package main

import "core:slice"
import "core:strconv"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:time"

getIssues :: proc(sort: proc(a, b: Issue) -> bool = defaultIssueSort, allocator := context.allocator, loc := #caller_location) -> [dynamic]Issue {
	issues := make([dynamic]Issue, 0, 128, allocator, loc)
	filepath.walk("./.borzoi", walk, &issues)
	slice.sort_by(issues[:], sort)
	return issues
}
defaultIssueSort :: proc(a, b: Issue) -> bool {
	if a.priority != b.priority {
		return a.priority > b.priority
	}
	return a.id > b.id
}
walk :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	if in_err != 0 {
		fmt.println(in_err)
		os.exit(1)
	}
	pattern, _ := regex.create_by_user(`/^[0-9a-f]{4}$/`)
	if _, success := regex.match(pattern, info.name); success {
		data, err := os.read_entire_file_from_filename_or_err(strings.concatenate({ "./.borzoi/", info.name }))
		if err != 0 {
			fmt.println(err)
			os.exit(1)
		}
		metadata := strings.split_lines_n(cast(string)data, 6)

		id, _ := strconv.parse_uint(info.name, 16)
		status, enum_ok := fmt.string_to_enum_value(Status, metadata[1][10:])
		if !enum_ok {
			fmt.printfln("%s:2:11: Invalid status '%s'", info.fullpath, metadata[1][10:])
			os.exit(1)
		}
		priority, atoi_ok := strconv.parse_uint(metadata[3][10:], 10)
		if !atoi_ok {
			fmt.printfln("%s:4:11: Invalid priority '%s'", info.fullpath, metadata[3][10:])
			os.exit(1)
		}
		time, consumed := time.rfc3339_to_time_utc(metadata[4][10:])
		if consumed == 0 {
			fmt.printfln("%s:4:11: Invalid creation date '%s'", info.fullpath, metadata[4][10:])
			os.exit(1)
		}

		append(cast (^[dynamic]Issue) user_data, Issue{
			id,
			metadata[0][2:], metadata[2][10:], metadata[5],
			{ time, 0 },
			priority,
			status,
		})
	}
	return
}
