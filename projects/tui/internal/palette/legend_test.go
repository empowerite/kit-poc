// F1 or ? floats the legend over the verbs' table: it says what each glyph the screen draws means.
package palette

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// legendText gives the legend's lines, every meaning on a line of its own, as the screen draws them.
func legendText(m Model) string {
	var out []string
	for _, g := range m.legendSpec().Lines() {
		for _, l := range g {
			out = append(out, ansi.Strip(l))
		}
	}
	return strings.Join(out, "\n")
}

// The legend names each glyph the screen draws.
func TestTheLegendNamesEveryGlyphTheScreenDraws(t *testing.T) {
	m, _ := drive(listing(t), tea.KeyPressMsg{Code: tea.KeyF1})
	if !m.legend.Open || !strings.Contains(screen(m), "verbs legend") {
		t.Fatalf("F1 did not show the legend:\n%s", screen(m))
	}
	shown := legendText(m)
	var frame []string
	for _, l := range m.frame() {
		frame = append(frame, ansi.Strip(l))
	}
	for g := range testkit.Glyphs(strings.Join(frame, "\n")) {
		if !strings.Contains(shown, g) {
			t.Errorf("the screen draws %s, which the legend lacks:\n%s", g, shown)
		}
	}
}

// ? and F1 show the legend and hide it, home and the arrows move it, and a click off it is the screen's.
func TestTheLegendIsShownHiddenAndMoved(t *testing.T) {
	m, _ := drive(listing(t), tea.KeyPressMsg{Code: '?', Text: "?"})
	if !m.legend.Open || m.legend.At != legend.BottomRight {
		t.Fatalf("? did not show the legend in the bottom right: %+v", m.legend)
	}
	if m, _ = drive(m, tea.KeyPressMsg{Code: tea.KeyHome}); m.legend.At != legend.TopLeft {
		t.Errorf("home: %v", m.legend.At)
	}
	box, top, x0 := m.legend.Box(m.legendSpec())
	plain := ansi.Strip(box[0])
	at := x0 + ansi.StringWidth(plain[:strings.Index(plain, legend.Arrows[3])])
	if m, _ = drive(m, testkit.Click(at, top)); m.legend.At != legend.BottomRight {
		t.Errorf("the ↘ arrow: %v", m.legend.At)
	}
	if m, _ = drive(m, tea.KeyPressMsg{Code: tea.KeyF1}); m.legend.Open {
		t.Error("F1 kept the legend")
	}
}

// The search takes ? as a character.
func TestTheSearchTakesAQuestionMark(t *testing.T) {
	m, _ := drive(searching(t), tea.KeyPressMsg{Code: '?', Text: "?"})
	if m.legend.Open || m.search.Query != "?" {
		t.Errorf("? in the search: legend %v, query %q", m.legend.Open, m.search.Query)
	}
}
