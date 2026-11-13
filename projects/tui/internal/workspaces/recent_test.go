package workspaces

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A search is remembered when it gives the rows the keyboard, as on every screen; in the search, ctrl+r or a click on its
// Recall glyph drops the searches down, a key or a click on one searches it again, and under the dropdown a paste and
// the wheel do nothing.
func TestTheWorkspacesSearchIsRememberedAndRecalled(t *testing.T) {
	m, _ := opened(t, listJSON)
	m, _ = drive(m, append([]tea.Msg{testkit.Press("/")}, append(testkit.Typed("solo"), testkit.Press("enter"))...)...)
	if !slices.Equal(m.recent.Items, []string{"solo"}) || m.search.Focused {
		t.Fatalf("remembered: %q, search focused %v", m.recent.Items, m.search.Focused)
	}
	ctrlU, ctrlR := tea.KeyPressMsg{Code: 'u', Mod: tea.ModCtrl}, tea.KeyPressMsg{Code: 'r', Mod: tea.ModCtrl}
	if m, _ = drive(m, testkit.Press("/"), ctrlU, ctrlR); !m.recent.Open || !strings.Contains(m.keys().String(), "close") ||
		m.search.Query != "" {
		t.Fatalf("ctrl+r: open %v, keys %q", m.recent.Open, m.keys().String())
	}
	if m, _ = drive(m, tea.PasteMsg{Content: "x"}, tea.MouseWheelMsg{Button: tea.MouseWheelDown}); m.search.Query != "" {
		t.Errorf("a paste under the dropdown: %q", m.search.Query)
	}
	if m, _ = drive(m, testkit.Press("enter")); m.recent.Open || m.search.Query != "solo" || strings.Contains(view(m), "github.com/o/a") {
		t.Errorf("enter on solo: open %v, %q", m.recent.Open, m.search.Query)
	}
	m, _ = drive(m, ctrlU, testkit.Click(m.recallAt(), shell.Top))
	if !m.recent.Open {
		t.Fatalf("a click on the Recall glyph did not drop the searches down:\n%s", view(m))
	}
	_, left := m.recent.Box(m.recallAt(), m.width)
	if m, _ = drive(m, testkit.Click(left+3, shell.Top+1)); m.recent.Open || m.search.Query != "solo" {
		t.Errorf("a click on solo: open %v, %q", m.recent.Open, m.search.Query)
	}
}
