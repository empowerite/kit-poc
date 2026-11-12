// The legend over the groups' table: F1 or ? showing it and hiding it, which says what each glyph the screen shows
// under it means, the menu bar's, the table's, and a favorite's, as the legend package draws it; this file says which
// glyphs those are, and on which lines of the screen each stands.
package workspaces

import "github.com/empowerite/kit/projects/tui/internal/legend"

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// menu bar's, the table's, which stands under the menu bar's rule, the favorite column's, a favorite's star, and
// kit's refusal.
func (m Model) parts(last int) []legend.Part {
	menuBar := func(y int) bool { return y == 0 }
	rows := func(y int) bool { return y >= tableTop && y < last }
	out := legend.MenuBar(menuBar, true)
	table := legend.SheetRows(m.sheet, last)
	out = append(out, legend.Table(table)...)
	return append(out,
		legend.One(Column, "favorite column", table.Header),
		legend.One(Star, "favorite", rows),
		legend.One(Failed, "kit refused", rows))
}

// tableTop is the screen line the table starts on, under the menu bar and its rule.
const tableTop = 2

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	return legend.Spec{Title: "workspaces legend", Screen: screen, Top: tableTop, Width: m.width, Height: m.height,
		Parts: m.parts(len(screen) - 1)}
}
