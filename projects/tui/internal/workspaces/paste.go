// A paste, as the screen types it. A terminal sends a paste whole, and not as the keys of its text, so what types a
// key takes a paste's text too, as shell.Pasted gives it: a git URL, a pattern, or a command in an action's dialog, a
// word in the search, and a name or a range where the table types one.
package workspaces

// paste types a paste where a key pressed would be typed: in an open dialog, which takes it whether a line is typed
// there or not; in the search while it has focus; else where the table types, a card's line or a preset's name,
// while the screen draws the table (see listed). Under an open menu, and on the rows, it types nothing.
func (m *Model) paste(text string) {
	switch layered := m.listed() && m.sheet.Layered(); {
	case m.prompt.open:
		m.prompt = m.prompt.paste(text)
	case m.group.Open || m.appMenu.Open || m.books.Open || m.recent.Open:
	case m.search.Focused && !layered:
		m.search.Query += text
		m.sheet.Search(m.search.Query)
	case m.listed():
		m.sheet.Paste(text)
	}
}

// paste types a paste after what is typed while a line is typed, as key types a key, and takes kit's line away; a
// dialog that only confirms types nothing.
func (p prompt) paste(text string) prompt {
	if p.typing {
		p.typed, p.refusal = p.typed+text, ""
	}
	return p
}
