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
	version,
	help,
}

Issue :: struct {
	id: uint,
	title, author, body: string,
	time: Time,
	priority: uint,
	status: Status,
}

Time :: struct {
	time: time.Time,
	utc_offset: int,
}

Status :: enum {
	Open,
	Closed,
	Wontfix,
	Ongoing,
}

