package workspaces

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A terminal sends a paste whole, as tea.PasteMsg, and a dialog's line types it as it types a key: a pasted line
// break asks kit nothing, and enter then runs what was pasted. A dialog that only confirms types nothing.
func TestAPasteIsTypedInADialogsLine(t *testing.T) {
	m, record := opened(t, listJSON)
	m, _ = drive(m, testkit.Press("n"), testkit.Typed("t")[0])
	m.prompt.refusal = "kit refused"
	m, asked := drive(m, tea.PasteMsg{Content: "ools github.com/o/*-tool\n"})
	if m.prompt.typed != "tools github.com/o/*-tool" || m.prompt.refusal != "" || !m.prompt.open || m.prompt.busy ||
		len(asked) != 0 || recorded(t, record) != "" {
		t.Fatalf("t and a paste: %q, refusal %q, busy %v, kit ran %q", m.prompt.typed, m.prompt.refusal,
			m.prompt.busy, recorded(t, record))
	}
	if m.search.Query != "" {
		t.Errorf("the search under the dialog took the paste: %q", m.search.Query)
	}
	drive(m, testkit.Press("enter"))
	if got := recorded(t, record); !strings.Contains(got, "workspaces --new=tools github.com/o/*-tool") {
		t.Errorf("enter after the paste asked kit %q", got)
	}
	confirm, _ := opened(t, listJSON)
	confirm, _ = drive(confirm, testkit.Press("d"))
	if !confirm.prompt.open || confirm.prompt.typing {
		t.Fatalf("d asks for a line, or opens nothing: %+v", confirm.prompt)
	}
	if confirm, _ = drive(confirm, tea.PasteMsg{Content: "w"}); confirm.prompt.typed != "" {
		t.Errorf("a paste in a dialog that confirms: %q", confirm.prompt.typed)
	}
}

// The search with focus types a paste, which narrows the rows as typing does; a preset's name typed on the table's
// control line takes it; the rows, and an open menu, take none.
func TestAPasteIsTypedInTheSearchAndInAPresetsName(t *testing.T) {
	m, _ := opened(t, listJSON)
	if m, _ = drive(m, tea.PasteMsg{Content: "solo"}); m.search.Query != "" || strings.Contains(view(m), "🔎 solo") {
		t.Fatalf("a paste on the rows: %q", m.search.Query)
	}
	m, _ = drive(m, testkit.Press("/"), tea.PasteMsg{Content: "so\r\nlo\n"})
	if v := view(m); m.search.Query != "solo" || !m.search.Focused || strings.Contains(v, "github.com/o/a") ||
		!strings.Contains(v, "github.com/me/solo") {
		t.Errorf("a paste in the search: %q, focused %v\n%s", m.search.Query, m.search.Focused, v)
	}
	for name, open := range map[string]func(*Model){
		"the app's menu":     func(m *Model) { m.appMenu.Open = true },
		"the group's menu":   func(m *Model) { m.group.Open = true },
		"the workspace menu": func(m *Model) { m.books = m.books.Opened() },
	} {
		under := m
		open(&under)
		if under, _ = drive(under, tea.PasteMsg{Content: "x"}); under.search.Query != "solo" {
			t.Errorf("a paste under %s: %q", name, under.search.Query)
		}
	}
	m, _ = drive(m, testkit.Press("esc"))
	m.sheet.Focus()
	x, y := lineAt(t, m, "Default ▼")
	m, _ = drive(m, left(x+1, y), testkit.Press("s"), testkit.Press("enter"))
	if !m.sheet.Table().SavingAs {
		t.Fatalf("Save As… does not ask for a name:\n%s", view(m))
	}
	before := m.sheet.Table().Naming
	if m, _ = drive(m, tea.PasteMsg{Content: "mine"}); m.sheet.Table().Naming != before+"mine" ||
		m.search.Query != "solo" {
		t.Errorf("a paste in the name: %q, search %q", m.sheet.Table().Naming, m.search.Query)
	}
	// a table the screen does not draw, as under kit's refusal, takes no paste
	m.refusal = "kit refused"
	if m, _ = drive(m, tea.PasteMsg{Content: "x"}); m.listed() || m.sheet.Table().Naming != before+"mine" {
		t.Errorf("a paste in a table that is not drawn: listed %v, %q", m.listed(), m.sheet.Table().Naming)
	}
}
