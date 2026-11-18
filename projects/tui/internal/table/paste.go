// A paste, as a table types it. A terminal sends a paste whole, and not as the keys of its text, so what a table
// types a key in takes a paste's text too, as shell.Pasted gives it: the line of a field's card that is typed,
// standing alone or in the fields dialog, and the name typed for a preset.
package table

import "strings"

// Paste types a paste on the card's line that is typed, while the keyboard is on it, after what is typed there, as
// Key types a key; on any other line it types nothing.
func (p *Popover) Paste(h Host, text string) {
	if lines := p.Lines(h); p.At >= 0 && p.At < len(lines) && lines[p.At].Input {
		p.Typed += text
	}
}

// Paste types a paste in the fields dialog's card while the card has the keyboard, as the card types it; the list
// types nothing.
func (c *Columns) Paste(h Host, text string) {
	if !c.InCard {
		return
	}
	p := c.Card(h)
	p.Paste(h, text)
	c.Typed = p.Typed
}

// PresetPaste types a paste after the name typed for Save As… or Rename…, = : and ; apart, which a name never holds,
// as PresetKey types a key; and says whether a name is typed.
func PresetPaste(h Host, text string) bool {
	t := h.Table()
	if !t.SavingAs {
		return false
	}
	t.Naming += strings.Map(func(r rune) rune {
		if strings.ContainsRune("=:;", r) {
			return -1
		}
		return r
	}, text)
	return true
}

// Paste types a paste where the sheet would type a key, and says whether the sheet took it: an open layer's, the
// topmost, takes it, and types it where it is a card's line that is typed; then the control line's, while a preset's
// name is typed there. The rows type nothing, and leave the paste to the screen.
func (s *Sheet) Paste(text string) bool {
	switch {
	case s.pop.Open:
		s.pop.Paste(s, text)
	case s.cols.Open:
		s.cols.Paste(s, text)
	case s.Layered():
	default:
		return s.onControls && PresetPaste(s, text)
	}
	return true
}
