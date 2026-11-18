// F1 floats the legend over a verb's form, and ? too where no field types what is pressed: it says what each glyph the
// form draws means.
package form

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

// The legend names each glyph the form draws: the way back, the field under the keyboard, and the menu bar's.
func TestTheLegendNamesEveryGlyphTheFormDraws(t *testing.T) {
	m := newForm(t, "flow", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40}, tea.KeyPressMsg{Code: tea.KeyF1})
	if !m.legend.Open || !strings.Contains(strings.Join(screen(m), "\n"), "flow legend") {
		t.Fatalf("F1 did not show the legend:\n%s", strings.Join(screen(m), "\n"))
	}
	shown := legendText(m)
	for _, want := range []string{"=  kit menu", "‹  back to the verbs: esc"} {
		if !strings.Contains(shown, want) {
			t.Errorf("the legend lacks %q:\n%s", want, shown)
		}
	}
	var frame []string
	for _, l := range m.frame() {
		frame = append(frame, ansi.Strip(l))
	}
	for g := range testkit.Glyphs(strings.Join(frame, "\n")) {
		if !strings.Contains(shown, g) {
			t.Errorf("the form draws %s, which the legend lacks:\n%s", g, shown)
		}
	}
}

// ? shows the legend where no text is typed, and is the field's where one is; F1 is the legend's everywhere; home and
// the arrows move it, and a click on it leaves the form as it was.
func TestTheLegendIsShownHiddenAndMoved(t *testing.T) {
	m := newForm(t, "flow", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40}, tea.KeyPressMsg{Code: '?', Text: "?"})
	if m.typing() || !m.legend.Open || m.legend.At != legend.BottomRight {
		t.Fatalf("? where nothing is typed: typing %v, legend %+v", m.typing(), m.legend)
	}
	if m, _ = drive(t, m, tea.KeyPressMsg{Code: tea.KeyHome}); m.legend.At != legend.TopLeft {
		t.Errorf("home: %v", m.legend.At)
	}
	box, top, x0 := m.legend.Box(m.legendSpec())
	plain := ansi.Strip(box[0])
	at := x0 + ansi.StringWidth(plain[:strings.Index(plain, legend.Arrows[3])])
	if m, _ = drive(t, m, testkit.Click(at, top)); m.legend.At != legend.BottomRight {
		t.Errorf("the ↘ arrow: %v", m.legend.At)
	}
	if m, _ = drive(t, m, tea.KeyPressMsg{Code: tea.KeyF1}); m.legend.Open {
		t.Error("F1 kept the legend")
	}
}

// Where a field types, ? is typed, and F1 shows the legend.
func TestAFieldThatTypesTakesTheQuestionMark(t *testing.T) {
	m := newForm(t, "commit", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	for m.focus = range m.fields {
		if m.typing() {
			break
		}
	}
	m.key(tea.KeyPressMsg{Code: '?', Text: "?"})
	if !m.typing() || m.legend.Open || m.input != "?" {
		t.Fatalf("? in a field that types: typing %v, legend %v, typed %q", m.typing(), m.legend.Open, m.input)
	}
	if m.key(tea.KeyPressMsg{Code: tea.KeyF1}); !m.legend.Open {
		t.Error("F1 did not show the legend over a field that types")
	}
}
