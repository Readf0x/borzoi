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
	id, _ := strconv.parse_uint(idstr, 16)
	fullpath, _ := os2.get_working_directory(context.allocator)
	fullpath = strings.concatenate({ fullpath, "/", filename })

	issue: Issue

	offset := 0
	current_action : enum {
		looking_for_yaml,
		looking_for_key,
		checking_key,
		checking_value,
		looking_for_title,
	}
	current: enum {
		none,
		status,
		priori,
		assign,
		labels,
		author,
		crdate,
	} = .none
	values_filled := 0
	yaml_lines := 0
	current_line := 1
	colon_pos: int = ---

	char: byte = ---
	for pos := 0; pos < len(data); pos += 1 {
		char = data[pos]
		if char == '\n' {
			offset = pos
			current_line += 1
			continue
		}
		switch current_action {
		case .looking_for_yaml:
			if char == '-' {
				if yaml_lines == 3 do current_action = .looking_for_key
				else do yaml_lines += 1
			}
			else do handle(true, "%s:%d:%d: Invalid character: '%c'", fullpath, current_line, pos - offset, char)
		case .looking_for_key:
		case .checking_key:
			key := string(data[pos:pos + 7 - offset])
			switch key {
			case "status":
				current = .status
			case "priori":
				current = .priori
			case "assign":
				current = .assign
			case "labels":
				current = .labels
			case "author":
				current = .author
			case "crdate":
				current = .crdate
			case:
				handle(true, "%s:%d:%d: Unknown key: '%s'", fullpath, current_line, pos - offset, key)
			}
			pos += 7
		case .checking_value:
			if current != .none {
				prefix := 0
				for char, i in data[colon_pos:] {
					if char == ' ' do prefix += 1
					else do break
				}
				str := cast (string) buf[prefix:pos-offset-1]

				#partial switch current {
				case .status:
					status, ok := fmt.string_to_enum_value(Status, str)
					handle(!ok, "%s:%d:%d: Invalid status '%s'", fullpath, current_line, pos - offset, str)
				case .priori:
				case .assign:
				case .labels:
				case .author:
				case .crdate:
				}
				values_filled += 1
			}
			offset = pos
			current_line += 1
		case .looking_for_title:
		}
	}

	return issue
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
		"# %s\n%s",       // metadata[8], [9]+[10] or [9], [10]
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
