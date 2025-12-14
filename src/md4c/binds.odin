package md4c_odin

import "core:strings"
import "core:c"

foreign import md4c "system:md4c"

// Block represents a part of document hierarchy structure like a paragraph
// or list item.
Block_Type :: enum c.int {
	// <body>...</body>
	block_doc = 0,

	// <blockquote>...</blockquote>
	block_quote,

	// <ul>...</ul>
	// Detail: Structure Block_Ul_Detail.
	block_ul,

	// <ol>...</ol>
	// Detail: Structure Block_Ol_Detail.
	block_ol,

	// <li>...</li>
	// Detail: Structure Block_Li_Detail.
	block_li,

	// <hr>
	block_hr,

	// <h1>...</h1> (for levels up to 6)
	// Detail: Structure Block_H_Detail.
	block_h,

	// <pre><code>...</code></pre>
	// Note the text lines within code blocks are terminated with '\n'
	// instead of explicit text_br.
	block_code,

	// Raw HTML block. This itself does not correspond to any particular HTML
	// tag. The contents of it _is_ raw HTML source intended to be put
	// in verbatim form to the HTML output.
	block_html,

	// <p>...</p>
	block_p,

	// <table>...</table> and its contents.
	// Detail: Structure Block_Table_Detail (for block_table),
	//         structure Block_Td_Detail (for block_th and block_td)
	// Note all of these are used only if extension flag_tables is enabled.
	block_table,
	block_thead,
	block_tbody,
	block_tr,
	block_th,
	block_td
}

// Span represents an in-line piece of a document which should be rendered with
// the same font, color and other attributes. A sequence of spans forms a block
// like paragraph or list item.
Span_Type :: enum c.int {
	// <em>...</em>
	span_em,

	// <strong>...</strong>
	span_strong,

	// <a href="xxx">...</a>
	// Detail: Structure Span_A_Detail.
	span_a,

	// <img src="xxx">...</a>
	// Detail: Structure Span_Img_Detail.
	// Note: Image text can contain nested spans and even nested images.
	// If rendered into alt attribute of HTML <img> tag, it's responsibility
	// of the parser to deal with it.
	span_img,

	// <code>...</code>
	span_code,

	// <del>...</del>
	// Note: Recognized only when flag_strikethrough is enabled.
	span_del,

	// For recognizing inline ($) and display ($$) equations
	// Note: Recognized only when flag_latexmathspans is enabled.
	span_latexmath,
	span_latexmath_display,

	// Wiki links
	// Note: Recognized only when flag_wikilinks is enabled.
	span_wikilink,

	// <u>...</u>
	// Note: Recognized only when flag_underline is enabled.
	span_u
}

// Text is the actual textual contents of span.
Text_Type :: enum c.int {
	// Normal text.
	text_normal = 0,

	// NULL character. CommonMark requires replacing NULL character with
	// the replacement char U+FFFD, so this allows caller to do that easily.
	text_nullchar,

	// Line breaks.
	// Note these are not sent from blocks with verbatim output (Block_Type.block_code
	// or Block_Type.block_html). In such cases, '\n' is part of the text itself.
	text_br,         // <br> (hard break)
	text_softbr,     // '\n' in source text where it is not semantically meaningful (soft break)

	// Entity.
	// (a) Named entity, e.g. &nbsp;
	//     (Note MD4C does not have a list of known entities.
	//     Anything matching the regexp /&[A-Za-z][A-Za-z0-9]{1,47};/ is
	//     treated as a named entity.)
	// (b) Numerical entity, e.g. &#1234;
	// (c) Hexadecimal entity, e.g. &#x12AB;
	//
	// As MD4C is mostly encoding agnostic, application gets the verbatim
	// entity text into the parser::text().
	text_entity,

	// Text in a code block (inside Block_Type.block_code) or inlined code (`code`).
	// If it is inside Block_Type.block_code, it includes spaces for indentation and
	// '\n' for new lines. Text_Type.text_br and Text_Type.text_softbr are not sent for this
	// kind of text.
	text_code,

	// Text is a raw HTML. If it is contents of a raw HTML block (i.e. not
	// an inline raw HTML), then Text_Type.text_br and Text_Type.text_softbr are not used.
	// The text contains verbatim '\n' for the new lines.
	text_html,

	// Text is inside an equation. This is processed the same way as inlined code
	// spans (`code`).
	text_latexmath
}

// Alignment enumeration.
Align :: enum c.int {
	align_default = 0,   // When unspecified.
	align_left,
	align_center,
	align_right
}

// String attribute.
//
// This wraps strings which are outside of a normal text flow and which are
// propagated within various detailed structures, but which still may contain
// string portions of different types like e.g. entities.
//
// So, for example, lets consider this image:
//
//     ![image alt text](http://example.org/image.png 'foo &quot; bar')
//
// The image alt text is propagated as a normal text via the Parser::text()
// callback. However, the image title ('foo &quot; bar') is propagated as
// Attribute in Span_Img_Detail::title.
//
// Then the attribute Span_Img_Detail::title shall provide the following:
//  -- [0]: "foo "   (substr_types[0] == Text_Type.text_normal; substr_offsets[0] == 0)
//  -- [1]: "&quot;" (substr_types[1] == Text_Type.text_entity; substr_offsets[1] == 4)
//  -- [2]: " bar"   (substr_types[2] == Text_Type.text_normal; substr_offsets[2] == 10)
//  -- [3]: (n/a)    (n/a                              ; substr_offsets[3] == 14)
//
// Note that these invariants are always guaranteed:
//  -- substr_offsets[0] == 0
//  -- substr_offsets[LAST+1] == size
//  -- Currently, only Text_Type.text_normal, Text_Type.text_entity, Text_Type.text_nullchar
//     substrings can appear. This could change only of the specification
//     changes.
Attribute :: struct {
	text:           cstring,
	size:           c.uint,
	substr_types:   [^]Text_Type,
	substr_offsets: [^]c.uint,
}

// Detailed info for Block_Type.block_ul.
Block_Ul_Detail :: struct {
	is_tight: c.int,  // Non-zero if tight list, zero if loose.
	mark:     c.char, // Item bullet character in MarkDown source of the list, e.g. '-', '+', '*'.
}

// Detailed info for Block_Type.block_ol.
Block_Ol_Detail :: struct {
	start:          c.uint, // Start index of the ordered list.
	is_tight:       c.int,  // Non-zero if tight list, zero if loose.
	mark_delimiter: c.char, // Character delimiting the item marks in MarkDown source, e.g. '.' or ')'
}

// Detailed info for Block_Type.block_li.
Block_Li_Detail :: struct {
	is_task:          c.int,  // Can be non-zero only with flag_tasklists
	task_mark:        c.char, // If is_task, then one of 'x', 'X' or ' '. Undefined otherwise.
	task_mark_offset: c.uint, // If is_task, then offset in the input of the char between '[' and ']'.
}

// Detailed info for Block_Type.block_h.
Block_H_Detail :: struct {
	level: c.uint, // Header level (1 - 6)
}

// Detailed info for Block_Type.block_code.
Block_Code_Detail :: struct {
	info:       Attribute,
	lang:       Attribute,
	fence_char: c.char,    // The character used for fenced code block; or zero for indented code block.
}

// Detailed info for Block_Type.block_table.
Block_Table_Detail :: struct {
	col_count:      c.uint, // Count of columns in the table.
	head_row_count: c.uint, // Count of rows in the table header (currently always 1)
	body_row_count: c.uint, // Count of rows in the table body
}

// Detailed info for Block_Type.block_th and Block_Type.block_td.
Block_Td_Detail :: struct {
	align: Align,
}

// Detailed info for Span_Type.span_a.
Span_A_Detail :: struct {
	href:        Attribute,
	title:       Attribute,
	is_autolink: c.int, // nonzero if this is an autolink
}

// Detailed info for Span_Type.span_img.
Span_Img_Detail :: struct {
	src:   Attribute,
	title: Attribute,
}

// Detailed info for Span_Type.span_wikilink.
Span_Wikilink_Detail :: struct {
	target: Attribute,
}

// Callback procedure types
Enter_Block_Proc :: #type proc "c" (type: Block_Type, detail: rawptr, userdata: rawptr) -> c.int
Leave_Block_Proc :: #type proc "c" (type: Block_Type, detail: rawptr, userdata: rawptr) -> c.int
Enter_Span_Proc  :: #type proc "c" (type: Span_Type, detail: rawptr, userdata: rawptr) -> c.int
Leave_Span_Proc  :: #type proc "c" (type: Span_Type, detail: rawptr, userdata: rawptr) -> c.int
Text_Proc        :: #type proc "c" (type: Text_Type, text: cstring, size: c.uint, userdata: rawptr) -> c.int
Debug_Log_Proc   :: #type proc "c" (msg: cstring, userdata: rawptr)
Syntax_Proc      :: #type proc "c" ()

// Parser structure.
Parser :: struct {
	// Reserved. Set to zero.
	abi_version: c.uint,

	// Dialect options. Bitmask of flag_xxxx values.
	flags:       c.uint,

	// Caller-provided rendering callbacks.
	//
	// For some block/span types, more detailed information is provided in a
	// type-specific structure pointed by the argument 'detail'.
	//
	// The last argument of all callbacks, 'userdata', is just propagated from
	// Parse() and is available for any use by the application.
	//
	// Note any strings provided to the callbacks as their arguments or as
	// members of any detail structure are generally not zero-terminated.
	// Application has to take the respective size information into account.
	//
	// Any rendering callback may abort further parsing of the document by
	// returning non-zero.
	enter_block: Enter_Block_Proc,
	leave_block: Leave_Block_Proc,
	enter_span:  Enter_Span_Proc,
	leave_span:  Leave_Span_Proc,
	text:        Text_Proc,

	// Debug callback. Optional (may be NULL).
	//
	// If provided and something goes wrong, this function gets called.
	// This is intended for debugging and problem diagnosis for developers;
	// it is not intended to provide any errors suitable for displaying to an
	// end user.
	debug_log:   Debug_Log_Proc,

	// Reserved. Set to NULL.
	syntax:      Syntax_Proc,
}

// For backward compatibility. Do not use in new code.
Renderer :: Parser

// Flags specifying extensions/deviations from CommonMark specification.
//
// By default (when Parser::flags == 0), we follow CommonMark specification.
// The following flags may allow some extensions or deviations from it.


FLAG_COLLAPSEWHITESPACE       : c.uint : 0x0001 // In Text_Type.text_normal, collapse non-trivial whitespace into single ' '
FLAG_PERMISSIVEATXHEADERS     : c.uint : 0x0002 // Do not require space in ATX headers ( ###header )
FLAG_PERMISSIVEURLAUTOLINKS   : c.uint : 0x0004 // Recognize URLs as autolinks even without '<', '>'
FLAG_PERMISSIVEEMAILAUTOLINKS : c.uint : 0x0008 // Recognize e-mails as autolinks even without '<', '>' and 'mailto:'
FLAG_NOINDENTEDCODEBLOCKS     : c.uint : 0x0010 // Disable indented code blocks. (Only fenced code works.)
FLAG_NOHTMLBLOCKS             : c.uint : 0x0020 // Disable raw HTML blocks.
FLAG_NOHTMLSPANS              : c.uint : 0x0040 // Disable raw HTML (inline).
FLAG_TABLES                   : c.uint : 0x0100 // Enable tables extension.
FLAG_STRIKETHROUGH            : c.uint : 0x0200 // Enable strikethrough extension.
FLAG_PERMISSIVEWWWAUTOLINKS   : c.uint : 0x0400 // Enable WWW autolinks (even without any scheme prefix, if they begin with 'www.')
FLAG_TASKLISTS                : c.uint : 0x0800 // Enable task list extension.
FLAG_LATEXMATHSPANS           : c.uint : 0x1000 // Enable $ and $$ containing LaTeX equations.
FLAG_WIKILINKS                : c.uint : 0x2000 // Enable wiki links extension.
FLAG_UNDERLINE                : c.uint : 0x4000 // Enable underline extension (and disables '_' for normal emphasis).
FLAG_HARD_SOFT_BREAKS         : c.uint : 0x8000 // Force all soft breaks to act as hard breaks.

FLAG_PERMISSIVEAUTOLINKS : c.uint : (FLAG_PERMISSIVEEMAILAUTOLINKS | FLAG_PERMISSIVEURLAUTOLINKS | FLAG_PERMISSIVEWWWAUTOLINKS)
FLAG_NOHTML              : c.uint : (FLAG_NOHTMLBLOCKS | FLAG_NOHTMLSPANS)

// Convenient sets of flags corresponding to well-known Markdown dialects.
//
// Note we may only support subset of features of the referred dialect.
// The constant just enables those extensions which bring us as close as
// possible given what features we implement.
//
// ABI compatibility note: Meaning of these can change in time as new
// extensions, bringing the dialect closer to the original, are implemented.
DIALECT_COMMONMARK : c.uint : 0
DIALECT_GITHUB     : c.uint : (FLAG_PERMISSIVEAUTOLINKS | FLAG_TABLES | FLAG_STRIKETHROUGH | FLAG_TASKLISTS)

foreign md4c {
	@(private)
	@(link_name="md_parse")
	_parse :: proc "c" (text: cstring, size: c.uint, parser: ^Parser, userdata: rawptr) -> c.int ---
}

// Parse the Markdown document stored in the string 'text'. The Parser
// provides callbacks to be called during the parsing so the caller can
// render the document on the screen or convert the Markdown to another
// format.
//
// Zero is returned on success. If a runtime error occurs (e.g. a memory
// fails), -1 is returned. If the processing is aborted due any callback
// returning non-zero, the return value of the callback is returned.
parse :: proc(text: string, parser: ^Parser, userdata: rawptr) {
	_parse(strings.clone_to_cstring(text), cast (c.uint) len(text), parser, userdata)
}

