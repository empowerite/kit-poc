// A paste, as the picture types it. A terminal sends a paste whole, and not as the keys of its text, so what types a
// key takes a paste's text too, as shell.Pasted gives it: a title, a login, or a number an action asks for, a word in
// the search, a range on a field's card, and a preset's name.
package flow

import "github.com/empowerite/kit/projects/tui/internal/table"

// paste types a paste where a key pressed would be typed, in the order the keys follow: in what an action asks, while
// its answer is typed; on a field's card, standing alone or in the fields dialog, as the card types it; in the search
// while it has the keyboard, which narrows the rows as typing does; and in the name typed for a preset on the preset
// line. Under any other open layer, and on the bar or the rows, it types nothing.
func (m *Model) paste(text string) {
	switch {
	case m.ask != nil:
		if m.ask.typing {
			m.ask.typed += text
		}
	case m.pop.Open:
		m.pop.Paste(m, text)
	case m.cols.Open:
		m.cols.Paste(m, text)
	case m.layers().Opened(*m):
	case m.inPanel:
		p := m.panel(m.stage)
		p.Query += text
		m.setPanel(p)
	case m.onPreset:
		table.PresetPaste(m, text)
	}
}
