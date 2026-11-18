package palette

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A terminal sends a paste whole, as tea.PasteMsg, and the search with focus types it as it types a key, its line
// breaks dropped, so the rows narrow and the search keeps the keyboard; a word that is a key's name is typed, not
// pressed. With the rows focused, and under an open menu, a paste types nothing.
func TestAPasteIsTypedInTheSearchWithFocus(t *testing.T) {
	m, _ := drive(searching(t), testkit.Typed("c")[0], tea.PasteMsg{Content: "ont\n"})
	if m.search.Query != "cont" || names(m) != "context" || !m.search.Focused {
		t.Fatalf("c and a paste of ont: %q, rows %q, focused %v", m.search.Query, names(m), m.search.Focused)
	}
	m, _ = drive(m, ctrlU, tea.PasteMsg{Content: "enter"})
	if m.search.Query != "enter" || !m.search.Focused {
		t.Errorf("a paste of the word enter: %q, focused %v", m.search.Query, m.search.Focused)
	}
	if m, _ = drive(m, ctrlU, tea.PasteMsg{Content: "a=b"}); m.search.Query != "a=b" || m.appMenu.Open {
		t.Errorf("a paste that holds =: %q, the menu open %v", m.search.Query, m.appMenu.Open)
	}
	rows, _ := drive(listing(t), tea.PasteMsg{Content: "cont"})
	if rows.search.Query != "" || rows.search.Focused {
		t.Errorf("a paste on the rows: %q, focused %v", rows.search.Query, rows.search.Focused)
	}
	m, _ = drive(m, ctrlU)
	if under, _ := drive(m, testkit.Typed("=")[0], tea.PasteMsg{Content: "cont"}); !under.appMenu.Open ||
		under.search.Query != "" {
		t.Errorf("a paste under the kit menu: open %v, %q", under.appMenu.Open, under.search.Query)
	}
	m.recent.Open = true
	if m, _ = drive(m, tea.PasteMsg{Content: "cont"}); m.search.Query != "" {
		t.Errorf("a paste under the searches remembered: %q", m.search.Query)
	}
}

// A name typed for a preset takes a paste, as the table types it, and not the search.
func TestAPasteIsTypedInAPresetsName(t *testing.T) {
	m := listing(t)
	x, y := at(m, "Default ▼", 1)
	m, _ = drive(m, testkit.Click(x, y), testkit.Press("s"), enter)
	if !m.sheet.Table().SavingAs {
		t.Fatalf("Save As… does not ask for a name:\n%s", screen(m))
	}
	before := m.sheet.Table().Naming
	m, _ = drive(m, tea.PasteMsg{Content: "mine\n"})
	if got := m.sheet.Table().Naming; got != before+"mine" || m.search.Query != "" || !m.sheet.Table().SavingAs {
		t.Fatalf("a paste in the name: %q, search %q", got, m.search.Query)
	}
	next, _ := m.Update(enter)
	if m = next.(Model); !strings.Contains(last(m), "saved the preset "+before+"mine") {
		t.Errorf("enter after the paste: %q", last(m))
	}
}
