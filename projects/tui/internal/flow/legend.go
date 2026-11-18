// The legend over a stage's rows: F1 or ? showing it and hiding it, which says what each glyph the screen shows under
// it means, the frame's, the controls', and the selected stage's rows', as the legend package draws it; this file says
// which glyphs those are, and on which lines of the screen each stands.
package flow

import (
	"strings"

	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/legend"
)

// legendKey takes a key while the legend shows, and says whether it moved it, as the legend package says.
func (m *Model) legendKey(k string) bool { return m.legend.Key(k) }

// toggleLegend shows the legend, or hides it, where it stands kept.
func (m *Model) toggleLegend() {
	if len(m.stages) > 0 {
		m.legend.Toggle()
	}
}

// drawn gives the text the selected stage's rows draw now, the lines the pane shows, to find the glyphs in.
func (m Model) drawn() string {
	var out []string
	for _, l := range m.allLines(m.stage) {
		out = append(out, ansi.Strip(l.Text))
	}
	return strings.Join(out, "\n")
}

// parts gives every glyph the legend can explain on a screen whose last line, the keys bar's, is the line last: the
// frame's and the controls', then the selected stage's rows' and its tab's, each on the lines it stands on.
func (m Model) parts(last int) []legend.Part {
	top := m.top()
	menuBar := func(y int) bool { return y == 0 }
	tabBar := func(y int) bool { return !m.maximized && y > 0 && y < top }
	control := func(y int) bool { return m.controls() && y == top }
	// the rule under the header, and the one under the heading over the groups, whose marks mean the same
	rule := func(y int) bool { return y >= top && y < last && (m.onRule(y) || m.controls() && y == top+1) }
	header := func(y int) bool { return y >= top && y < last && m.inHeader(y) }
	rows := func(y int) bool { return y >= top && y < last }
	headings := func(y int) bool { return rows(y) && !rule(y) && !control(y) }
	status := func(y int) bool { return y == last }
	out := legend.MenuBar(menuBar, true)
	out = append(out, legend.Tabs(legend.Bar{Tabs: tabBar, Menu: func(y int) bool { return m.maximized && menuBar(y) }})...)
	out = append(out, legend.Table(legend.Rows{Header: header, Control: control, Rule: rule, Rows: rows})...)
	out = append(out, legend.One(Unwatched, "watched", status))
	for _, g := range []string{GitHub, GitLab} {
		out = append(out, legend.One(g, "forge requests left", status))
	}
	name := m.stages[m.stage].name
	for _, s := range m.stages {
		if g := stageGlyphs[s.name]; g != "" {
			out = append(out, legend.One(g, label(s.name)+" stage", tabBar))
		}
	}
	for _, e := range legends[name] {
		out = append(out, legend.Part{Glyphs: []string{e.glyph}, Meaning: e.meaning, Mark: marks[name][e.glyph], On: headings})
	}
	if name == "changes" || name == "issues" {
		// a change's state is the glyph of its row, and of the row of the issue it closes, which the pull request's
		// page is behind only on a change's
		mark := ""
		if name == "changes" {
			mark = ToPage
		}
		for _, e := range states {
			out = append(out, legend.Part{Glyphs: []string{e.glyph}, Meaning: e.meaning, Mark: mark, On: headings})
		}
	}
	return out
}

// legendSpec gives what the legend is drawn from: the screen's lines under it, the keys bar last, and the parts.
func (m Model) legendSpec() legend.Spec {
	screen := append(m.frame(), m.bottom())
	return legend.Spec{Title: label(m.stages[m.stage].name) + " legend", Screen: screen, Top: m.top(), Width: m.width,
		Height: m.height, Parts: m.parts(len(screen) - 1)}
}

// overLegend draws the legend over the screen's lines while it shows, under the menus and dialogs drawn after it.
func (m Model) overLegend(lines []string) []string {
	if !m.legend.Open {
		return lines
	}
	return m.legend.Over(lines, m.legendSpec())
}

// legendClick takes a click while the legend shows, and says whether it fell on it, as the legend package says.
func (m *Model) legendClick(x, y int) bool { return m.legend.Click(x, y, m.legendSpec()) }
