// A paste, as the screen types it. A terminal sends a paste whole, and not as the keys of its text, so what types a
// key takes a paste's text too, as shell.Pasted gives it.
package welcome

// paste types a paste where a key pressed would be typed: in the selected step's search while it has focus, which
// narrows the step, or finds in its page, as typing does; else, on a step that is a table, where the table types, a
// card's line or a preset's name. Under an open menu, and on a page or the rows, it types nothing.
func (m *Model) paste(text string) {
	switch s := m.search(); {
	case m.tabMenu.Open || m.appMenu.Open || m.recent.Open:
	case s.Focused:
		s.Query += text
		m.setSearch(s)
	case m.gridded():
		m.sheet().Paste(text)
	}
}
