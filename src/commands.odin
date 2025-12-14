package main

import "core:math/rand"
import "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"

edit :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for issue in os.args[2:] {
		err := editor(idstr_to_path(strings.to_upper(issue)))
		handle(err != os2.ERROR_NONE, "Failed to open editor: %v", err)
	}
}

gen :: proc() {
	// Issue(DE2E): Implement gen command
	fmt.println("WIP")
}

init :: proc() {
	err := os2.mkdir(".borzoi")
	handle(err != os2.ERROR_NONE, err)
}

close :: proc() {
	handle(len(os.args) < 3, "Missing id")
	buf := make([]byte, 7)
	for idstr in os.args[2:] {
		issue := issue_from_idstr(strings.to_upper(idstr))
		handle(issue.status == .Closed || issue.status == .Wontfix, "Already closed.")
		issue.status = .Closed
		str := issue_to_string(issue)
		err := os2.write_entire_file(fmt.bprintf(buf, "%4X.md", issue.id), transmute ([]byte) str)
		handle(err != os2.ERROR_NONE, err)
	}
}

new :: proc() {
	files, err := os2.read_directory_by_path(".", 0, context.temp_allocator)
	handle(err != os2.ERROR_NONE, err)

	now := cast (u64) time.now()._nsec
	rand.reset(now)
	rand_id := rand.uint32()

	buf := make([]byte, 7, context.temp_allocator)
	path := fmt.bprintf(buf, "%4X.md", rand_id & 0x0000FFFF)

	for os2.exists(path) {
		now += 1
		buf = { 0, 0, 0, 0, 0, 0, 0 }
		rand.reset(cast (u64) now)
		rand_id = rand.uint32()
		path = fmt.bprintf(buf, "%4X.md", rand_id & 0x0000FFFF)
	}

	username, u_err := get_username()
	handle(u_err != os2.ERROR_NONE, u_err)

	utc_offset := get_utc_offset()
	issuestr := issue_to_string(Issue{
		author = cast (string) username,
		time = { time.now(), utc_offset },
		priority = 1,
	})

	file_err := os2.write_entire_file(path, transmute ([]byte) issuestr)

	err = editor(path)
	handle(err != os2.ERROR_NONE, "Failed to open editor: %v", err)
}

commit :: proc() {
	env, _ := os2.environ(context.allocator)

	porcelain, p_err := process_out({ "git", "status", "--porcelain", "." })
	handle(p_err != os2.ERROR_NONE, p_err)

	if len(porcelain) == 0 {
		fmt.println("Nothing to commit")
		os.exit(1)
	}

	pipe_r, pipe_w, err := os2.pipe()
	handle(err != os2.ERROR_NONE, err)

	// reset DB just in case
	err = process_custom({
		".", { "git", "reset", "." }, env, os2.stderr, nil, nil
	})
	handle(err != os2.ERROR_NONE, err)

	// store staging index in pipe
	err = process_custom({
		"..", { "git", "diff", "--cached" }, env, os2.stderr, pipe_w, nil
	})
	handle(err != os2.ERROR_NONE, err)

	// reset index
	err = process_custom({
		"..", { "git", "reset" }, env, os2.stderr, nil, nil
	})
	handle(err != os2.ERROR_NONE, err)

	edited := make([dynamic]string, 0, 8)
	created := make([dynamic]string, 0, 8)
	deleted := make([dynamic]string, 0, 8)
	for status in strings.split_iterator(cast (^string) &porcelain, "\n") {
		id := status[len(status)-7:len(status)-3]
		switch status[:2] {
		case " M": fallthrough
		case "M ": fallthrough
		case "MM":
			append(&edited, id)
		case "??": fallthrough
		case " A":
			append(&created, id)
		case " D": fallthrough
		case "D ":
			append(&deleted, id)
		case:
			// reapply staging since we're aborting early
			apply_pr, apply_err := os2.process_start({
				"..", { "git", "apply", "--cached", "--allow-empty" }, env, os2.stderr, nil, pipe_r
			})
			handle(apply_err != os2.ERROR_NONE, apply_err)
			handle(true, "Unhandled porcelain status:\n%s\nTry calling `borzoi commit` again now that the DB has been removed from the staging area.", status)
		}
	}

	create_str :: proc(ids: []string, verb: string, b: ^strings.Builder) -> string {
		if len(ids) != 0 {
			strings.write_string(b, strings.concatenate({ verb, " issue" }))
			if len(ids) > 1 do strings.write_string(b, "s")
			strings.write_string(b, ": ")
			strings.write_string(b, strings.join(ids[:], ", "))
		}
		message := make([]byte, len(b.buf))
		copy(message, b.buf[:])
		strings.builder_reset(b)
		return cast (string) message
	}

	message_builder := strings.builder_make()

	list : [3]string = {
		create_str(created[:], "created", &message_builder),
		create_str(deleted[:], "deleted", &message_builder),
		create_str(edited[:],  "edited",  &message_builder),
	}
	strings.builder_destroy(&message_builder)

	messages := make([dynamic]string, 0, 3)
	for msg in list {
		if len(msg) != 0 {
			append(&messages, msg)
		}
	}
	joined := strings.join(messages[:], "; ")

	process_start({ "git", "add", "." })
	process_start({ "git", "commit", "-m", joined })

	// reapply old index
	apply_pr, apply_err := os2.process_start({
		"..", { "git", "apply", "--cached", "--allow-empty" }, env, os2.stderr, nil, pipe_r
	})
	handle(apply_err != os2.ERROR_NONE, apply_err)
}

delete_issue :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for id in os.args[2:] {
		path := idstr_to_path(strings.to_upper(id))
		err := os2.remove(path)
		handle(err != os2.ERROR_NONE, err)
	}
}

git_hooks :: proc() {
	stdout, err := process_out({ "git", "rev-parse", "--show-toplevel" })
	handle(err != os2.ERROR_NONE, err)
	os2.change_directory(strings.concatenate({ cast (string) stdout[:len(stdout) - 1], "/.git" }))
	// LSP complains about error here, ignore it it will compile.
	err = os2.write_entire_file("hooks/post-commit", #load("../static/post-commit.bash", []byte), os2.Permissions_Read_All + os2.Permissions_Execute_All + { .Write_User })
	handle(err != os2.ERROR_NONE, err)
}

