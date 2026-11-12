package tutorials

import (
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A terminal sends a paste whole, as tea.PasteMsg, and the search with focus types it as it types a key, its line
// breaks dropped: the cards narrow, and the search keeps the keyboard. The cards, and an open menu, take none.
func TestAPasteIsTypedInTheSearchWithFocus(t *testing.T) {
	m, _ := fake(t)
	m = drive(m, testkit.Start(m, at120)...)
	if m = drive(m, tea.PasteMsg{Content: "tour"}); m.search.Query != "" || len(m.cards()) != 2 {
		t.Fatalf("a paste on the cards: %q, %d cards", m.search.Query, len(m.cards()))
	}
	m = drive(m, press('/'), testkit.Typed("T")[0], tea.PasteMsg{Content: "OU\nR\r\n"})
	if cards := m.cards(); m.search.Query != "TOUR" || !m.search.Focused || len(cards) != 1 ||
		cards[0].ID != "kittui-tour" {
		t.Errorf("T and a paste of OUR: %q, focused %v, %v", m.search.Query, m.search.Focused, cards)
	}
	for name, open := range map[string]func(*Model){
		"the app's menu":          func(m *Model) { m.appMenu.Open = true },
		"the searches remembered": func(m *Model) { m.recent.Open = true },
	} {
		under := m
		open(&under)
		if under = drive(under, tea.PasteMsg{Content: "x"}); under.search.Query != "TOUR" {
			t.Errorf("a paste under %s: %q", name, under.search.Query)
		}
	}
}

// A name typed for a preset takes a paste, as the table types it, and not the search.
func TestAPasteIsTypedInAPresetsName(t *testing.T) {
	m, _ := loaded(t, up, tabKey, enter, testkit.Press("s"), enter)
	if !m.sheet.Table().SavingAs {
		t.Fatalf("Save As… does not ask for a name:\n%s", view(m))
	}
	before := m.sheet.Table().Naming
	if m = drive(m, tea.PasteMsg{Content: "mine"}); m.sheet.Table().Naming != before+"mine" || m.search.Query != "" {
		t.Errorf("a paste in the name: %q, search %q", m.sheet.Table().Naming, m.search.Query)
	}
}
