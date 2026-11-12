// A paste, as the screen types it. A terminal sends a paste whole, and not as the keys of its text, so what types a
// key takes a paste's text too, as shell.Pasted gives it.
package tutorials

// paste types a paste where a key pressed would be typed: in the search while it has focus, which narrows the cards,
// or finds in the page, as typing does; else where the table types, a card's line or a preset's name. Under an open
// menu, and on the cards, it types nothing.
func (m *Model) paste(text string) {
	switch {
	case m.appMenu.Open || m.recent.Open:
	case m.search.Focused && !m.sheet.Layered():
		m.typed(m.search.Query + text)
	default:
		m.sheet.Paste(text)
	}
}
