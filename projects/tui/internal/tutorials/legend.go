// The legend over the cards: F1 or ? showing it and hiding it, which says what each glyph the screen shows under it
// means, the menu bar's, the control line's, and each card's, over a tutorial's page too, as the legend package draws
// it; this file says which glyphs those are, and on which lines of the screen each stands.
package tutorials

import (
	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/pane"
)

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// menu bar's, the table's on the control line and in the headings over the cards, where a tutorial is, each card's
// glyph, and, over a tutorial's page, the line back to the cards.
func (m Model) parts(last int) []legend.Part {
	menuBar := func(y int) bool { return y == 0 }
	control := func(y int) bool { return y == controlTop && !m.read.open }
	cards := func(y int) bool { return y >= paneTop && y < last }
	none := func(int) bool { return false }
	out := legend.MenuBar(menuBar, false)
	out = append(out, legend.Table(legend.Rows{Header: none, Control: control, Rule: none, Rows: cards})...)
	out = append(out,
		legend.One(Shipped, "in the kit", cards),
		legend.One(Online, "online", cards),
		legend.One(Back, "back to the cards: click", func(y int) bool { return y == controlTop && m.read.open }),
		legend.Part{Glyphs: []string{pane.Before, pane.After}, Meaning: "scroll across: click", On: cards})
	for _, t := range m.catalog.Tutorials {
		out = append(out, legend.One(t.Glyph, t.Title, cards))
	}
	return out
}

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	return legend.Spec{Title: "tutorials legend", Screen: screen, Top: paneTop, Width: m.width, Height: m.height,
		Parts: m.parts(len(screen) - 1)}
}
