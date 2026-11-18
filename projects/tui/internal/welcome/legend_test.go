// F1 or ? floats the legend over every step's pane, on every tab: it says what each glyph the step draws means, and a
// glyph with several meanings stands once over them.
package welcome

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/tabs"
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

// Every step has a legend, titled by the step, and it names each glyph the step draws, the bar's, the checks', and
// the table's; the glyphs the legend names are the ones on the screen alone.
func TestEveryStepHasALegendOfWhatItDraws(t *testing.T) {
	for i, name := range []string{"introduction", "toolchains", "setup", "customize", "terms"} {
		m, _ := loaded(t, stepKey(i), press(tea.KeyF1))
		if !m.legend.Open || !strings.Contains(ansi.Strip(view(m)), name+" legend") {
			t.Fatalf("%s: F1 did not show the legend:\n%s", name, view(m))
		}
		shown := legendText(m)
		var frame []string
		for _, l := range m.frame() {
			frame = append(frame, ansi.Strip(l))
		}
		for g := range testkit.Glyphs(strings.Join(frame, "\n")) {
			// the tabs' numbers are one line, the first of each kind
			if !strings.Contains(shown, g) && !isMarker(g) {
				t.Errorf("%s draws %s, which its legend lacks:\n%s", name, g, shown)
			}
		}
		for _, line := range strings.Split(shown, "\n") {
			if g, _, _ := strings.Cut(line, " "); g != "" && len(g) > 1 && !strings.Contains(strings.Join(frame, "\n"), g) {
				t.Errorf("%s: the legend names %q, which the step does not draw", name, g)
			}
		}
	}
}

// ? and F1 show the legend and hide it, home and end and the arrows move it, and a click off it is the screen's.
func TestTheLegendIsShownHiddenAndMoved(t *testing.T) {
	m, _ := loaded(t, press('?'))
	if !m.legend.Open || m.legend.At != legend.BottomRight {
		t.Fatalf("? did not show the legend in the bottom right: %+v", m.legend)
	}
	if m = drive(m, press(tea.KeyHome)); m.legend.At != legend.TopLeft {
		t.Errorf("home: %v", m.legend.At)
	}
	box, top, left := m.legend.Box(m.legendSpec())
	k := strings.Index(ansi.Strip(box[0]), legend.Arrows[3])
	if m = drive(m, testkit.Click(left+ansi.StringWidth(ansi.Strip(box[0])[:k]), top)); m.legend.At != legend.BottomRight {
		t.Errorf("the ↘ arrow: %v", m.legend.At)
	}
	step := m.step
	if m = drive(m, testkit.Click(0, 1)); m.step != step && !m.legend.Open {
		t.Error("a click off the legend was lost")
	}
	if m = drive(m, press(tea.KeyF1)); m.legend.Open {
		t.Error("F1 kept the legend")
	}
}

// The search takes ? as a character; F1 is the legend's alone.
func TestTheSearchTakesAQuestionMark(t *testing.T) {
	m, _ := loaded(t, append([]tea.Msg{press('/')}, testkit.Typed("?")...)...)
	if m.legend.Open || m.search().Query != "?" {
		t.Errorf("? in the search: legend %v, query %q", m.legend.Open, m.search().Query)
	}
}

// isMarker says whether a glyph is one of the tab bar's numbers.
func isMarker(g string) bool {
	for i := range 10 {
		if g == tabs.Marker(i, false) || g == tabs.Marker(i, true) {
			return true
		}
	}
	return false
}
