package flow

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/table"
)

// A terminal sends a paste whole, as tea.PasteMsg, and what an action asks for types it as it types a key: a pasted
// line break does not run the action, and enter then runs it with what was pasted. A dialog that asks for a yes types
// nothing.
func TestAPasteIsTypedInWhatAnActionAsks(t *testing.T) {
	m, record := selecting(t)
	m = choose(t, m, "Gather Under a Parent…")
	m = drive(m, typed("The ")...)
	m = drive(m, tea.PasteMsg{Content: "plan\n"})
	if m.ask == nil || m.ask.typed != "The plan" || len(acted(t, record)) != 0 {
		t.Fatalf("The and a paste of plan: %+v, kit ran %q", m.ask, acted(t, record))
	}
	if p := m.panel(m.stage); p.Query != "" {
		t.Errorf("the search under the dialog took the paste: %q", p.Query)
	}
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"gather --title=The plan #46 #45"}) {
		t.Errorf("enter after the paste: %q", got)
	}
	yes, _ := selecting(t)
	yes = choose(t, yes, "Close as Not Planned")
	if yes.ask == nil || yes.ask.typing {
		t.Fatalf("Close as Not Planned asks for a line, or for nothing: %+v", yes.ask)
	}
	if yes = drive(yes, tea.PasteMsg{Content: "x"}); yes.ask.typed != "" {
		t.Errorf("a paste in a dialog that asks for a yes: %q", yes.ask.typed)
	}
}

// The search with the keyboard types a paste, which narrows the rows as typing does; the bar and the rows, and an
// open menu, take none.
func TestAPasteIsTypedInTheSearchWithTheKeyboard(t *testing.T) {
	m := loaded(t, options(), tea.PasteMsg{Content: "noun"})
	if p := m.panel(m.stage); p.Query != "" || m.inPanel {
		t.Fatalf("a paste on the bar: %q, in panel %v", p.Query, m.inPanel)
	}
	all := len(m.rows(m.stage))
	m = drive(m, append(typed("/N"), tea.PasteMsg{Content: "OU\r\nN\n"})...)
	if p := m.panel(m.stage); p.Query != "NOUN" || !m.inPanel || len(m.rows(m.stage)) >= all {
		t.Errorf("N and a paste of OUN: %q, in panel %v, %d rows of %d", p.Query, m.inPanel, len(m.rows(m.stage)),
			all)
	}
	m.appMenu = m.appMenu.Opened()
	if m = drive(m, tea.PasteMsg{Content: "x"}); m.panel(m.stage).Query != "NOUN" {
		t.Errorf("a paste under the app's menu: %q", m.panel(m.stage).Query)
	}
}

// A name typed for a preset takes a paste, and a field's card, alone or in the fields dialog, takes one on its line
// that is typed.
func TestAPasteIsTypedInAPresetsNameAndOnACard(t *testing.T) {
	m := onDropdown(t, "")
	m.stages[0].SavingAs = true
	if m = drive(m, tea.PasteMsg{Content: "mine"}); m.stages[0].Naming != "mine" ||
		!strings.HasSuffix(presetText(m), SavingAs+" mine▏") {
		t.Errorf("a paste in the name: %q, %q", m.stages[0].Naming, presetText(m))
	}
	typedLine := func(p table.Popover) int {
		return slices.IndexFunc(p.Lines(&m), func(l table.PopLine) bool { return l.Input })
	}
	m.pop = table.OpenCard(&m, "age", false)
	if m.pop.At = typedLine(m.pop); m.pop.At < 0 {
		t.Fatalf("age's card has no line that is typed: %+v", m.pop)
	}
	if m = drive(m, tea.PasteMsg{Content: "<2h"}); m.pop.Typed != "<2h" || m.stages[0].Naming != "mine" {
		t.Errorf("a paste on the card: %q, the name %q", m.pop.Typed, m.stages[0].Naming)
	}
	m.pop, m.cols = table.Popover{}, table.OpenColumns(&m, "age")
	if m.cols.CardAt = typedLine(m.cols.Card(&m)); m.cols.CardAt < 0 {
		t.Fatalf("age's card in the fields dialog has no line that is typed: %+v", m.cols)
	}
	if m = drive(m, tea.PasteMsg{Content: ">1d"}); m.cols.Typed != ">1d" || m.stages[0].Naming != "mine" {
		t.Errorf("a paste on the dialog's card: %q, the name %q", m.cols.Typed, m.stages[0].Naming)
	}
}
