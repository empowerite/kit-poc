// The legend over a verb's form: F1 shows it and hides it anywhere, and ? where no text is typed, which says what each
// glyph the form shows under it means, the menu bar's and the fields', as the legend package draws it; this file says
// which glyphs those are, and on which lines of the screen each stands.
package form

import (
	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// top is the screen line the form starts on, under the menu bar and its rule.
const top = 2

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// menu bar's, which the form's workspace menu is in, the way back to the palette, a field's marks, and a refusal.
func (m Model) parts(last int) []legend.Part {
	menuBar := func(y int) bool { return y == 0 }
	rows := func(y int) bool { return y >= top && y < last }
	out := legend.MenuBar(menuBar, true)
	return append(out,
		legend.One("‹", "back to the verbs: esc", rows),
		legend.One(style.Focus, "the field, or the row, under the keyboard", rows),
		legend.One("◼", "chosen", rows),
		legend.One(style.Excluded, "kit refused", rows))
}

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	return legend.Spec{Title: m.spec.Verb + " legend", Screen: screen, Top: top, Width: m.width, Height: m.height,
		Parts: m.parts(len(screen) - 1)}
}
