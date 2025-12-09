package main

import "core:time"

Commands :: enum {
	init,
	list,
	edit,
	cat,
	new,
	gen,
	close,
	commit,
	delete,
	version,
	help,
}

Issue :: struct {
	id: uint,
	title, author, body: string,
	time: time.Time,
	priority: uint,
	status: Status,
}

// Why are we storing the original utc offset??
// Time :: struct {
// 	time: time.Time,
// 	utc_offset: int,
// }

Status :: enum {
	Open,
	Closed,
	Wontfix,
	Ongoing,
}

