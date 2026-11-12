package screens

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/app"
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// query gives what is typed in the search of the help's palette, as its menu bar draws it.
func query(m Model) string {
	_, typed, _ := strings.Cut(title(m), shell.Find+" ")
	return strings.TrimRight(typed, " ▏")
}

// A terminal sends a paste whole, as tea.PasteMsg. The screen shown types it where it types a key; while the Open
// Repository… dialog is open, the dialog types it and the screen under it does not; and under the Settings dialog
// nothing does.
func TestAPasteGoesToTheOpenDialogThenToTheScreenShown(t *testing.T) {
	m := help(t)
	m = drive(m, append(typed("/c"), tea.PasteMsg{Content: "ont\n"})...)
	if _, ok := m.made[shell.Help].(app.Model); !ok || query(m) != "cont" {
		t.Fatalf("c and a paste of ont in the palette's search: %q", title(m))
	}
	m = drive(m, shell.OpenMsg{}, tea.KeyPressMsg{Code: 'u', Mod: tea.ModCtrl}, tea.PasteMsg{Content: "/srv/code\n"})
	if !m.opener.Open || m.opener.Typed != "/srv/code" || query(m) != "cont" {
		t.Errorf("a paste in Open Repository…: %q, the search under it %q", m.opener.Typed, query(m))
	}
	m = drive(m, tea.KeyPressMsg{Code: tea.KeyEscape}, shell.SwitchMsg{Screen: shell.SettingsScreen},
		tea.PasteMsg{Content: "x"})
	if !m.dialog.Open || query(m) != "cont" {
		t.Errorf("a paste under Settings…: open %v, the search under it %q\n%s", m.dialog.Open, query(m),
			ansi.Strip(m.View().Content))
	}
}
