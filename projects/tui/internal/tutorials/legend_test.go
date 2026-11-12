// F1 or ? floats the legend over the cards and over a tutorial's page: it says what each glyph the screen draws means,
// and a glyph with several meanings stands once over them.
package tutorials

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

// The legend names each glyph the cards and the page draw, and none the screen does not.
func TestTheLegendNamesEveryGlyphTheScreenDraws(t *testing.T) {
	m, _ := fake(t)
	m = drive(m, append(testkit.Start(m, at120), press(tea.KeyF1))...)
	if !m.legend.Open || !strings.Contains(view(m), "tutorials legend") {
		t.Fatalf("F1 did not show the legend:\n%s", view(m))
	}
	shown := legendText(m)
	var frame []string
	for _, l := range m.frame() {
		frame = append(frame, ansi.Strip(l))
	}
	for g := range testkit.Glyphs(strings.Join(frame, "\n")) {
		if !strings.Contains(shown, g) {
			t.Errorf("the cards draw %s, which the legend lacks:\n%s", g, shown)
		}
	}
}

// Over a tutorial's page the legend names the line back to the cards, with the page's glyphs, and ? opens and closes it
// there too, where the page has the keyboard.
func TestTheLegendOverAPageNamesTheWayBack(t *testing.T) {
	m, _ := shipped(t, tabKey, tabKey, enter, press('?'))
	if !m.read.open || !m.legend.Open {
		t.Fatalf("? over the page: reading %v, legend %v", m.read.open, m.legend.Open)
	}
	if shown := legendText(m); !strings.Contains(shown, Back+" back to the cards") {
		t.Errorf("the legend over the page does not name the way back:\n%s", shown)
	}
	if m = drive(m, press(tea.KeyF1)); m.legend.Open || !m.read.open {
		t.Errorf("F1 over the page: reading %v, legend %v", m.read.open, m.legend.Open)
	}
}

// A legend over the cards says where a tutorial is: in the kit, with the shipped one drawn.
func TestTheLegendSaysWhereATutorialIs(t *testing.T) {
	m, _ := shipped(t, press('?'))
	if shown := legendText(m); !strings.Contains(shown, Shipped+" in the kit") {
		t.Errorf("the legend does not say a tutorial is in the kit:\n%s", shown)
	}
}

// ? and F1 show the legend and hide it, wherever the keyboard is, a page's too; the corners' keys and arrows move it,
// and a click off it is the screen's.
func TestTheLegendIsShownHiddenAndMoved(t *testing.T) {
	m, _ := fake(t)
	m = drive(m, append(testkit.Start(m, at120), press('?'))...)
	if !m.legend.Open || m.legend.At != legend.BottomRight {
		t.Fatalf("? did not show the legend in the bottom right: %+v", m.legend)
	}
	if m = drive(m, press(tea.KeyHome)); m.legend.At != legend.TopLeft {
		t.Errorf("home: %v", m.legend.At)
	}
	box, top, left := m.legend.Box(m.legendSpec())
	plain := ansi.Strip(box[0])
	at := left + ansi.StringWidth(plain[:strings.Index(plain, legend.Arrows[3])])
	if m = drive(m, testkit.Click(at, top)); m.legend.At != legend.BottomRight {
		t.Errorf("the ↘ arrow: %v", m.legend.At)
	}
	if m = drive(m, press(tea.KeyF1)); m.legend.Open {
		t.Error("F1 kept the legend")
	}
}
