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

	issue: Issue = {
		id = id,
		priority = 1,
	}

	offset := 0
	current_action : enum {
		checking_key,
		checking_value,
	}
	keys :: enum {
		none,
		status,
		priori,
		assign,
		labels,
		author,
		crdate,
	}
	current: keys = .none
	in_yaml := false
	yaml_end := false
	current_line := 1
	colon_pos: int = ---

	values_filled : bit_set[keys] = {}
	required_values : bit_set[keys] : { .author, .crdate, .status }

	char: byte = ---
	for pos := 0; pos < len(data); pos += 1 {
		char = data[pos]
		if char == '\n' {
			offset = pos
			current_line += 1
			continue
		}
		if !yaml_end && cast (string) data[pos:pos+4] == "---\n" {
			if !in_yaml {
				in_yaml = true
				pos += 2
				continue
			} else {
				yaml_end = true
				in_yaml = false
			}
		} else if cast (string) data[pos:pos+2] == "# " {
			sb := strings.builder_make()
			pos += 2
			for char in data[pos:] {
				if char == '\n' do break
				else do strings.write_byte(&sb, char)
				pos += 1
			}
			issue.title = strings.to_string(sb)
			issue.body = cast (string) data[pos+1:]
			break
		}
		if in_yaml do switch current_action {
		case .checking_key:
			key := string(data[offset+1:offset+7])
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
				rep, _ := strings.replace_all(key, "\n", "\\n")
				handle(true, "%s:%d:%d: Unknown key: '%s'", fullpath, current_line, pos - offset, rep)
			}
			pos += 6
			current_action = .checking_value
		case .checking_value:
			if current != .none {
				prefix := 0
				eol := 0
				found := false
				for char, i in data[pos:] {
					if char == ' ' && !found do prefix += 1
					else if char == '\n' {
						eol = pos+i
						break
					}
					else do found = true
				}
				pos += prefix
				str := cast (string) data[pos:eol]

				#partial switch current {
				case .status:
					ok: bool
					issue.status, ok = fmt.string_to_enum_value(Status, str)
					handle(!ok, "%s:%d:%d: Invalid status '%s'", fullpath, current_line, pos - offset, str)
				case .priori:
					priority, atoi_ok := strconv.parse_uint(str)
					handle(!atoi_ok, "%s:%d:%d: Invalid priority '%s'", fullpath, current_line, pos - offset, str)
					issue.priority = priority
				case .assign:
					issue.assignees = strings.split(str, ", ")
				case .labels:
					issue.labels = strings.split(str, ", ")
				case .author:
					issue.author = str
				case .crdate:
					time, offset, consumed := time.rfc3339_to_time_and_offset(str)
					handle(consumed == 0, "%s:%d:%d: Invalid creation date '%s'", fullpath, current_line, pos - offset, str)
					issue.time = { time, offset }
				}
				values_filled |= { current }
				handle(current not_in values_filled, "not there??")
				current_action = .checking_key
				pos = eol-1
			}
		}
		if yaml_end {
			if values_filled >= required_values {}
			else do fmt.printfln("missing: %v", required_values &~ values_filled)
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
