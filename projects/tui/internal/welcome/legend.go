// The legend over a step's pane: F1 or ? showing it and hiding it, which says what each glyph the screen shows under
// it means, the frame's, the step's table's, and the checks', as the legend package draws it; this file says which
// glyphs those are, and on which lines of the screen each stands.
package welcome

import (
	"github.com/empowerite/kit/projects/tui/internal/fix"
	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// frame's, the steps' tabs', then the selected step's table's or its page's, each on the lines it stands on.
func (m Model) parts(last int) []legend.Part {
	top := m.paneTop()
	menuBar := func(y int) bool { return y == 0 }
	tabBar := func(y int) bool { return !m.maximized && y > 0 && y < top }
	rows := func(y int) bool { return y >= top && y < last }
	out := legend.MenuBar(menuBar, true)
	out = append(out, legend.Tabs(legend.Bar{Tabs: tabBar, Menu: func(y int) bool { return m.maximized && menuBar(y) }})...)
	for _, t := range m.tabs {
		out = append(out, legend.One(t.glyph, t.name+" step", func(y int) bool { return tabBar(y) || m.maximized && y == 0 }))
	}
	if m.gridded() {
		out = append(out, legend.Table(legend.SheetRows(m.sheet(), last))...)
	}
	return append(out,
		legend.One(Passed, "check passed", rows),
		legend.One(Offered, "check passed, and offers a fix", rows),
		legend.One(Failed, "check failed", rows),
		legend.One(fix.CopyName, "copy the fix: click or c", rows),
		legend.One(fix.RunName, "run the fix: click or r", rows),
		legend.Part{Glyphs: []string{pane.Before, pane.After}, Meaning: "scroll across: click", On: rows},
		legend.One(style.Focus, "under the keyboard", rows))
}

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	return legend.Spec{Title: m.tabs[m.step].name + " legend", Screen: screen, Top: m.paneTop(), Width: m.width,
		Height: m.height, Parts: m.parts(len(screen) - 1)}
}
