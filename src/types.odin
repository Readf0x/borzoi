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

List_Sort :: enum { priority, date }
List_Filter :: struct {
	sort: List_Sort,
	reverse: bool,
	statuses: bit_set[Status],
	title, body: string,
	priority_range: [2]uint,
	date_range: [2]time.Time,
	authors, assignees, labels: []string,
}
List_Args :: struct {
	sort: List_Sort,
	reverse: bool,

	text,
	title,
	body: string,

	status: bit_set[Status],
	closed,
	all: bool,

	priority,
	min_priority,
	max_priority: uint,

	created_on,
	created_before,
	created_after: time.Time,

	author: [dynamic]string `args:"required=1"`,
	assignee: [dynamic]string `args:"required=1"`,
	label: [dynamic]string `args:"required=1"`,
}

