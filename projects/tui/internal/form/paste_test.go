package form

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A terminal sends a paste whole, as tea.PasteMsg, and the field with the keyboard types it as it types a key: a
// value takes it as one line, so a pasted line break neither moves on nor runs the command line.
func TestAPasteIsTheValueOfATextField(t *testing.T) {
	m := send(newForm(t, "generate", Answers{}, true), key("down"))
	m = send(m, testkit.Typed("1")...)
	m = send(m, tea.PasteMsg{Content: "2\r\n3\n"})
	if line := strings.Join(m.CommandLine(), " "); line != "--iterations=123" || m.focus != 1 || m.input != "123" {
		t.Errorf("after 1 and a paste of two lines: %q, focus %d, input %q", line, m.focus, m.input)
	}
	if run, _ := m.Done(); run {
		t.Error("a pasted line break ran the command line")
	}
}

// A field of lines takes each line of a paste, as Enter after each would, and leaves the last to go on typing; a
// paste of one line is typed after what is typed, and a paste of line breaks alone types nothing.
func TestAPasteOfLinesIsTheLinesOfAFieldOfLines(t *testing.T) {
	m := newForm(t, "template", Answers{}, true)
	m = send(m, testkit.Typed("a")...)
	m = send(m, tea.PasteMsg{Content: ".md\n\nb.md\nc"})
	if got := m.fields[0].Values; !slices.Equal(got, []string{"a.md", "b.md"}) || m.input != "c" || m.focus != 0 {
		t.Fatalf("three lines pasted after a: %q, input %q, focus %d", got, m.input, m.focus)
	}
	m = send(m, tea.PasteMsg{Content: ".md"}, tea.PasteMsg{Content: "\n\r\n"})
	if got := m.fields[0].Values; len(got) != 2 || m.input != "c.md" || m.focus != 0 {
		t.Errorf("one line, then line breaks alone: %q, input %q, focus %d", got, m.input, m.focus)
	}
	if line := strings.Join(m.CommandLine(), " "); line != "fix a.md b.md c.md" {
		t.Errorf("the command line: %q", line)
	}
}

// A list's filter takes a paste as one line, the cursor back on the first row it leaves; a field that types nothing,
// the command line, and a form under an open menu take none.
func TestAPasteFiltersAListAndIsDroppedWhereNothingTypes(t *testing.T) {
	t.Setenv("FAKE_KIT_ROWS", "30")
	m := focusOn(newForm(t, "commit", Answers{}, true), 2)
	m = send(m, key("down"), tea.PasteMsg{Content: "docs/\n"})
	if m.input != "docs/" || m.cursor != 0 || len(m.filtered()) >= 30 {
		t.Errorf("a paste in a list: input %q, cursor %d, %d rows", m.input, m.cursor, len(m.filtered()))
	}
	m = send(m, testkit.Typed("=")...)
	if m.appMenu.Open {
		t.Fatal("= in a list's filter dropped the kit menu down")
	}
	m = focusOn(m, 0)
	before := m.CommandLine()
	if m = send(m, tea.PasteMsg{Content: "x"}); m.input != "" || !slices.Equal(m.CommandLine(), before) {
		t.Errorf("a paste on a flag: input %q, line %q", m.input, m.CommandLine())
	}
	m.focus = len(m.fields)
	if m = send(m, tea.PasteMsg{Content: "x"}); m.input != "" || !slices.Equal(m.CommandLine(), before) {
		t.Errorf("a paste on the command line: input %q, line %q", m.input, m.CommandLine())
	}
	text := send(newForm(t, "generate", Answers{}, true), key("down"))
	text.appMenu = text.appMenu.Opened()
	if text = send(text, tea.PasteMsg{Content: "7"}); text.input != "" {
		t.Errorf("a paste under the kit menu typed %q", text.input)
	}
	text.appMenu.Open, text.books = false, text.books.Opened()
	if text = send(text, tea.PasteMsg{Content: "7"}); text.input != "" {
		t.Errorf("a paste under the workspace menu typed %q", text.input)
	}
}
