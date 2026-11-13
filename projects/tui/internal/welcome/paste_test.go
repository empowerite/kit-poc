package welcome

import (
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A terminal sends a paste whole, as tea.PasteMsg, and the step's search with focus types it as it types a key, its
// line breaks dropped, the search keeping the keyboard. A page, and an open menu, take none.
func TestAPasteIsTypedInTheStepsSearchWithFocus(t *testing.T) {
	m, _ := loaded(t, tea.PasteMsg{Content: "jq"})
	if m.search().Query != "" {
		t.Fatalf("a paste on a page: %q", m.search().Query)
	}
	m = drive(m, press('/'), testkit.Typed("j")[0], tea.PasteMsg{Content: "q\n"})
	if s := m.search(); s.Query != "jq" || !s.Focused {
		t.Errorf("j and a paste of q: %+v", s)
	}
	for name, open := range map[string]func(*Model){
		"the tab's menu":          func(m *Model) { m.tabMenu.Open = true },
		"the app's menu":          func(m *Model) { m.appMenu.Open = true },
		"the searches remembered": func(m *Model) { m.recent.Open = true },
	} {
		under := m
		open(&under)
		if under = drive(under, tea.PasteMsg{Content: "x"}); under.search().Query != "jq" {
			t.Errorf("a paste under %s: %q", name, under.search().Query)
		}
	}
}

// On a step that is a table, a name typed for a preset takes a paste, as the table types it.
func TestAPasteIsTypedInAPresetsNameOnAStepsTable(t *testing.T) {
	m, _ := loaded(t, stepKey(terms))
	s := termsSheet(m)
	s.Focus()
	s.Table().SavingAs = true
	if m = drive(m, tea.PasteMsg{Content: "mine"}); termsSheet(m).Table().Naming != "mine" || m.search().Query != "" {
		t.Errorf("a paste in the name: %q, search %q", termsSheet(m).Table().Naming, m.search().Query)
	}
}
