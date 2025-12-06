package main

import "core:os/os2"
import "core:strconv"
import "core:math"
import "core:strings"
import "core:text/regex"
import "core:fmt"
import "core:os"
import "core:time"

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
