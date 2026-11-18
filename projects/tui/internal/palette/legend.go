// The legend over the verbs' table: F1 or ? showing it and hiding it, which says what each glyph the screen shows under
// it means, the menu bar's and the table's, as the legend package draws it; this file says which glyphs those are, and
// on which lines of the screen each stands.
package palette

import "github.com/empowerite/kit/projects/tui/internal/legend"

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// menu bar's, which the workspace menu is in, and the table's.
func (m Model) parts(last int) []legend.Part {
	menuBar := func(y int) bool { return y == 0 }
	table := legend.SheetRows(&m.sheet, last)
	return append(legend.MenuBar(menuBar, true), legend.Table(table)...)
}

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	top, _ := m.sheet.Pane()
	return legend.Spec{Title: "verbs legend", Screen: screen, Top: top, Width: m.width, Height: m.height,
		Parts: m.parts(len(screen) - 1)}
}
