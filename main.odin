package main

import "core:math"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:time"

main :: proc() {
	if len(os.args) < 2 {
		help(1)
	}
	if os.args[1] == "--help" || os.args[1] == "-h" {
		help(0)
	}
	command, exists := fmt.string_to_enum_value(Commands, os.args[1])
	if !exists {
		help(1)
	}
	switch command {
	case Commands.list:
		list()
	case Commands.help:
		help(0)
	}
}

Commands :: enum {
	list,
	help,
}

list :: proc() {
	issues := make([dynamic]Issue, 0, 128)
	filepath.walk("./.borzoi", walk, &issues)

	max_title := 0
	for issue in issues {
		max_title = math.max(max_title, len(issue.title))
	}
	fmt.println(strings.concatenate({
		BRIGHT_BLACK,
		UNDERLINE, "title", strings.repeat(" ", max_title-5), NO_UNDERLINE, "  ",
		UNDERLINE, "status ", NO_UNDERLINE, "  ",
		UNDERLINE, "uid            ", RESET
	}))
	for issue in issues {
		status_string, _ := fmt.enum_value_to_string(issue.status)
		fmt.println(
			strings.concatenate({
				issue.title, strings.repeat(" ", max_title - len(issue.title)), "  ",
				status_string, strings.repeat(" ", 3 - (len(status_string) - 4)), "  ",
				issue.uid,
			}),
		)
	}
}

walk :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	if in_err != 0 {
		fmt.println(in_err)
		os.exit(1)
	}
	pattern, _ := regex.create_by_user(`/^\d{8}-\d{6}$/`)
	if _, success := regex.match(pattern, info.name); success {
		data, err := os.read_entire_file_from_filename_or_err(strings.concatenate({ "./.borzoi/", info.name }))
		if err != 0 {
			fmt.println(err)
			os.exit(1)
		}
		metadata := strings.split_lines_n(cast(string)data, 4)

		status, ok := fmt.string_to_enum_value(Status, metadata[1][10:])
		if !ok {
			fmt.printfln("%s:2:11: Invalid status '%s", info.fullpath, metadata[1][10:])
			os.exit(1)
		}

		append(cast (^[dynamic]Issue) user_data, Issue{
			info.name,
			metadata[0][2:], metadata[2][10:], metadata[3],
			status,
		})
	}
	return
}

help :: proc(code: int) {
	fmt.print(
`usage: borzoi {list,help}

local file issue tracker

positional arguments:
  {list,help}
    list  list issues
    help  show this menu
`)
	os.exit(code)
}

format_timestamp :: proc(t: time.Time) -> string {
	b: strings.Builder = strings.builder_make()

	year, month, day := time.date(t)
	hour, minute, sec := time.clock_from_time(t)

	fmt.sbprintf(&b, "%d%d%d-%d%d%d", year, month, day, hour, minute, sec)

	return strings.to_string(b)
}

Issue :: struct {
	uid: string,
	title, author, body: string,
	status: Status,
}

Status :: enum {
	OPEN,
	CLOSED,
	WONTFIX,
}

format :: proc(str: string, codes: []string, allocator := context.allocator, loc := #caller_location) -> string {
	parts: []string = make([]string, len(codes) + 2, allocator, loc)
	for c, i in codes {
		parts[i] = c
	}
	parts[len(codes)] = str
	parts[len(codes)+1] = RESET
	return strings.concatenate(parts, allocator, loc)
}

RESET             :: "\033[0m"
BOLD              :: "\033[1m"
DIM               :: "\033[2m"
ITALIC            :: "\033[3m"
UNDERLINE         :: "\033[4m"
NO_UNDERLINE      :: "\033[24m"
BLACK             :: "\033[30m"
RED               :: "\033[31m"
GREEN             :: "\033[32m"
YELLOW            :: "\033[33m"
BLUE              :: "\033[34m"
MAGENTA           :: "\033[35m"
CYAN              :: "\033[36m"
WHITE             :: "\033[37m"
BRIGHT_BLACK      :: "\033[90m"
BRIGHT_RED        :: "\033[91m"
BRIGHT_GREEN      :: "\033[92m"
BRIGHT_YELLOW     :: "\033[93m"
BRIGHT_BLUE       :: "\033[94m"
BRIGHT_MAGENTA    :: "\033[95m"
BRIGHT_CYAN       :: "\033[96m"
BRIGHT_WHITE      :: "\033[97m"
BG_BLACK          :: "\033[40m"
BG_RED            :: "\033[41m"
BG_GREEN          :: "\033[42m"
BG_YELLOW         :: "\033[43m"
BG_BLUE           :: "\033[44m"
BG_MAGENTA        :: "\033[45m"
BG_CYAN           :: "\033[46m"
BG_WHITE          :: "\033[47m"
BG_BRIGHT_BLACK   :: "\033[100m"
BG_BRIGHT_RED     :: "\033[101m"
BG_BRIGHT_GREEN   :: "\033[102m"
BG_BRIGHT_YELLOW  :: "\033[103m"
BG_BRIGHT_BLUE    :: "\033[104m"
BG_BRIGHT_MAGENTA :: "\033[105m"
BG_BRIGHT_CYAN    :: "\033[106m"
BG_BRIGHT_WHITE   :: "\033[107m"
