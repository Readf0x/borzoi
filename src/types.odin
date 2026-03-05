package main

import "core:time"

Issue :: struct {
	id                  : uint,
	title, author, body : string,
	assignees, labels   : []string,
	time                : Time,
	priority            : uint,
	status              : Status,
}

Time :: struct {
	time       : time.Time,
	utc_offset : int,
}

Status :: enum {
	Open,
	Closed,
	Wontfix,
	Ongoing,
}

