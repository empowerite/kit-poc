package form

import (
	"slices"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A plain click on the way back, ‹ verbs, goes back to the palette, as esc does; a click beside it, one with another
// button, and one on a form that stands alone, which draws no way back, go nowhere.
func TestAClickOnTheWayBackGoesBack(t *testing.T) {
	backs := func(produced []tea.Msg) bool { return slices.Contains(produced, tea.Msg(BackMsg{})) }
	m := newForm(t, "tidy", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 30})
	x, y := lineAt(t, m, backLabel)
	for _, at := range []int{x, x + ansi.StringWidth(backLabel) - 1} {
		if _, produced := drive(t, m, testkit.Click(at, y)); !backs(produced) {
			t.Errorf("a click on %s at %d, %d: %v", backLabel, at, y, produced)
		}
	}
	for name, click := range map[string]tea.MouseClickMsg{
		"before it":           testkit.Click(x-1, y),
		"after it":            testkit.Click(x+ansi.StringWidth(backLabel), y),
		"on the line under":   testkit.Click(x, y+1),
		"with another button": {X: x, Y: y, Button: tea.MouseRight},
	} {
		if _, produced := drive(t, m, click); backs(produced) {
			t.Errorf("a click %s went back", name)
		}
	}
	alone := newForm(t, "tidy", Answers{}, false)
	alone, _ = drive(t, alone, tea.WindowSizeMsg{Width: 100, Height: 30})
	if _, produced := drive(t, alone, testkit.Click(x, y)); backs(produced) {
		t.Error("a click where the way back would be went back from a form that stands alone")
	}
}
