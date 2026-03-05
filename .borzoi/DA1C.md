# Issue templates
- STATUS: Open
- AUTHOR: readf0x
- PRIORI: 1
- CRDATE: 2025-12-09T21:33:21Z
A good plan for this would be having `name.template.md` inside the DB which
just gets injected at the end of the file, pretty simple. The interface for
choosing the template is slightly more complex however. Do we enforce picking a
template by asking interactively? Or do we just assume no template if none is
specified?
