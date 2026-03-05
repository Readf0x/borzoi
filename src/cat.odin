#+feature dynamic-literals
package main

import "core:os/os2"
import "base:runtime"
import "core:math"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"
import "core:c"
import "md4c"

cat :: proc() {
	handle(len(os.args) < 3, "Missing id")
	for path, i in os.args[2:] {
		issue := issue_from_idstr(strings.to_upper(path))
		status, _ := color_status(issue.status)

		body := issue.body
		if body == "" {
			body = BRIGHT_BLACK + "<Empty body>" + RESET + "\n"
		} else do body = parse_markdown(body)

		assign_str: string
		if len(issue.assignees[0]) != 0 {
			assign_str = fmt.bprintf(make([]byte, 512),
				"  Assigned to: %s%s%s",
				RESET, strings.join(issue.assignees, BRIGHT_BLACK + ", " + RESET), BRIGHT_BLACK
			)
		}
		label_str: string
		if len(issue.labels[0]) != 0 {
			label_str = fmt.bprintf(make([]byte, 512),
				"  Labels: %s%s%s",
				YELLOW, strings.join(issue.labels, BRIGHT_BLACK + ", " + YELLOW), BRIGHT_BLACK
			)
		}

		// Naive implementation, works for now but we need do actual wrapping eventually.
		both := len(assign_str) != 0 && len(label_str) != 0
		single := len(assign_str) + len(label_str) != 0 && !both

		if (intty) {
			if i > 0 do fmt.print("\n")
			fmt.printf(
				"%s%s%s %4X %s%s%s%s\n" +
				"%sStatus: %s%s%s  Priority: %s%d%s%s%s%sAuthor: %s%s%s%sCreated: %s%s\n%s",

				BG_BLUE, BRIGHT_BLACK, BOLD, issue.id, BLACK, issue.title,
				strings.repeat(" ",
					math.max(73-len(issue.title), 0)+1
				),
				RESET,

				BRIGHT_BLACK, RESET, status, BRIGHT_BLACK,
				RESET, issue.priority, BRIGHT_BLACK,
				assign_str, label_str,
				both ? "\n" : "  ",
				RESET, issue.author, BRIGHT_BLACK,
				single ? "\n" : "  ",
				RESET, format_timestamp(issue.time),

				body,
			)
		} else {
			if i > 0 do fmt.print("\n")
			fmt.printf("# %s\n\n", issue.title)
			fmt.print(issue.body)
		}
	}
}

@(require_results)
parse_markdown :: proc(text: string) -> string {
	Info :: struct {
		sb: ^strings.Builder,
		new_block: bool,
		currently_in: union { md4c.Block_Type, md4c.Span_Type },
		detail: rawptr,
		li_count: u32,
		ctx: runtime.Context,
	}
	builder := strings.builder_make()
	md4c.parse(text, &{
		flags = md4c.FLAG_COLLAPSEWHITESPACE |
						md4c.FLAG_NOHTML |
						md4c.FLAG_PERMISSIVEAUTOLINKS |
						md4c.FLAG_STRIKETHROUGH |
						md4c.FLAG_TASKLISTS |
						md4c.FLAG_UNDERLINE,

		enter_block = proc "c" (type: md4c.Block_Type, rawdetail: rawptr, userdata: rawptr) -> c.int {
			ud := cast (^Info) userdata
			sb := ud.sb
			context = ud.ctx
			ud.new_block = true
			switch type {
			case .block_doc:
			case .block_quote:
				strings.write_string(sb, BRIGHT_BLACK)
				ud.currently_in = type
			case .block_ul:
				detail := cast (^md4c.Block_Ul_Detail) rawdetail
				ud.currently_in = type
			case .block_ol:
				detail := cast (^md4c.Block_Ol_Detail) rawdetail
				ud.currently_in = type
				ud.li_count = 1
			case .block_li:
				detail := cast (^md4c.Block_Li_Detail) rawdetail
				switch ud.currently_in {
				case .block_ul:
					strings.write_string(sb, "● ")
				case .block_ol:
					fmt.sbprintf(sb, "%d. ",  + ud.li_count)
					ud.li_count += 1
				}
			case .block_hr:
			case .block_h:
				detail := cast (^md4c.Block_H_Detail) rawdetail
				strings.write_string(sb, HEADER_COLORS[detail.level])
				ud.currently_in = type
				ud.detail = rawdetail
			case .block_code:
				detail := cast (^md4c.Block_Code_Detail) rawdetail
				ud.currently_in = type
				ud.detail = rawdetail
			case .block_html:
			case .block_p:
			case .block_table:
			case .block_thead:
			case .block_tbody:
			case .block_tr:
			case .block_th:
			case .block_td:
				detail := cast (^md4c.Block_Td_Detail) rawdetail
			}
			return 0
		},
		leave_block = proc "c" (type: md4c.Block_Type, rawdetail: rawptr, userdata: rawptr) -> c.int {
			ud := cast (^Info) userdata
			sb := ud.sb
			context = ud.ctx
			switch type {
			case .block_doc:
			case .block_quote:
				strings.write_string(sb, RESET)
			case .block_ul:
				detail := cast (^md4c.Block_Ul_Detail) rawdetail
				strings.write_byte(sb, '\n')
			case .block_ol:
				detail := cast (^md4c.Block_Ol_Detail) rawdetail
				strings.write_byte(sb, '\n')
			case .block_li:
				detail := cast (^md4c.Block_Li_Detail) rawdetail
				strings.write_byte(sb, '\n')
			case .block_hr:
			case .block_h:
				detail := cast (^md4c.Block_H_Detail) rawdetail
				strings.write_string(sb, RESET+"\n")
			case .block_code:
				detail := cast (^md4c.Block_Code_Detail) rawdetail
				strings.write_byte(sb, '\n')
				ud.currently_in = .block_html
			case .block_html:
			case .block_p:
				strings.write_bytes(sb, { '\n', '\n' })
			case .block_table:
			case .block_thead:
			case .block_tbody:
			case .block_tr:
			case .block_th:
			case .block_td:
				detail := cast (^md4c.Block_Td_Detail) rawdetail
			}
			return 0
		},
		enter_span = proc "c" (type: md4c.Span_Type, rawdetail: rawptr, userdata: rawptr) -> c.int {
			ud := cast (^Info) userdata
			sb := ud.sb
			context = ud.ctx
			switch type {
			case .span_em:
				strings.write_string(sb, ITALIC)
			case .span_strong:
			case .span_a:
				detail := cast (^md4c.Span_A_Detail) rawdetail
				fmt.sbprintf(sb,
					"\e]8;;%s\e\\" + YELLOW,
					strings.clone_from_cstring_bounded(detail.href.text, cast (int) detail.href.size)
				)
			case .span_img:
				detail := cast (^md4c.Span_Img_Detail) rawdetail
			case .span_code:
			case .span_del:
				strings.write_string(sb, STRIKETHROUGH)
			case .span_latexmath:
			case .span_latexmath_display:
			case .span_wikilink:
				detail := cast (^md4c.Span_Wikilink_Detail) rawdetail
			case .span_u:
			}
			return 0
		},
		leave_span = proc "c" (type: md4c.Span_Type, rawdetail: rawptr, userdata: rawptr) -> c.int {
			ud := cast (^Info) userdata
			sb := ud.sb
			context = ud.ctx
			switch type {
			case .span_em:
				strings.write_string(sb, NO_ITALIC)
			case .span_strong:
			case .span_a:
				detail := cast (^md4c.Span_A_Detail) rawdetail
				strings.write_string(sb, "\e]8;;\e\\" + RESET)
			case .span_img:
				detail := cast (^md4c.Span_Img_Detail) rawdetail
			case .span_code:
			case .span_del:
				strings.write_string(sb, NO_STRIKETHROUGH)
			case .span_latexmath:
			case .span_latexmath_display:
			case .span_wikilink:
				detail := cast (^md4c.Span_Wikilink_Detail) rawdetail
			case .span_u:
			}
			return 0
		},
		text = proc "c" (type: md4c.Text_Type, cstr: cstring, size: c.uint, userdata: rawptr) -> c.int {
			ud := cast (^Info) userdata
			sb := ud.sb
			context = ud.ctx
			text := strings.clone_from_cstring_bounded(cstr, int(size))
			if text == "\n" do strings.write_string(sb, text)
			else do switch ud.currently_in {
			case .block_h:
				strings.write_string(sb, strings.clone_from_cstring_bounded(cstr, int(size)))
				if (^md4c.Block_H_Detail)(ud.detail).level == 1 {
					strings.write_string(sb, strings.repeat(" ", math.max(int(size), 78 - int(size))))
				}
			case .block_code:
				detail := cast (^md4c.Block_Code_Detail) ud.detail
				lang := strings.clone_from_cstring_bounded(detail.lang.text, cast (int) detail.lang.size)

				bat_input, raw_str, _ := os2.pipe()
				format_str, bat_output, _ := os2.pipe()

				os2.write_string(raw_str, text)
				os2.close(raw_str)

				process, err := os2.process_start({
					command = {"bat", strings.concatenate({"-pl", lang}), "--color=always"},
					stdin = bat_input,
					stdout = bat_output,
				})

				os2.close(bat_input)
				state, _ := os2.process_wait(process)
				os2.close(bat_output)

				if ud.new_block {
					fmt.sbprintf(sb, "%s %s"+RESET+"\n",
						lang_icons[lang], lang
					)
					ud.new_block = false
				}
				if err != os2.ERROR_NONE || state.exit_code != 0 {
					strings.write_string(sb, text)
				} else {
					buf := make([]byte, 1024)
					for {
						n, _ := os2.read(format_str, buf)
						if n == 0 do break
						strings.write_bytes(sb, buf[:n])
					}
					delete(buf)
				}
				os2.close(format_str)
			case .block_quote:
				strings.write_string(sb, "▋ ")
				strings.write_string(sb, text)
			case: strings.write_string(sb, text)
			}
			return 0
		},
	}, &Info{ sb = &builder, ctx = context })
	return strings.to_string(builder)
}

lang_icons : map[string]string = {
	"js"         = YELLOW  + "󰌞",
	"ts"         = BLUE    + "󰛦",
	"py"         = GREEN   + "󰌠",
	"java"       = RED     + "󰬷",
	"cpp"        = BLUE    + "󰙲",
	"c"          = BLUE    + "󰙱",
	"cs"         = MAGENTA + "󰌛",
	"go"         = CYAN    + "󰟓",
	"rs"         = YELLOW  + "",
	"php"        = MAGENTA + "󰌟",
	"rb"         = RED     + "󰴭",
	"swift"      = YELLOW  + "󰛥",
	"kt"         = BLUE    + "",
	"html"       = RED     + "󰌝",
	"css"        = BLUE    + "󰌜",
	"sh"         = GREEN   + "$",
	"md"         = BLUE    + "󰍔",
	"json"       = YELLOW  + "󰘦",
	"xml"        = YELLOW  + "󰗀",
	"yaml"       = MAGENTA + "",
	"toml"       = BLUE    + "",
	"sql"        = GREEN   + "",
	"dockerfile" = BLUE    + "",
}

