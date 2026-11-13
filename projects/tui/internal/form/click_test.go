package form

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/syntax"
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

// A plain click on a flag's name gives the flag the keyboard and flips it, as the space does there. A click on its
// description gives it the keyboard and no more; a click on the blank line under it, on the rule over the form, or
// with another button, does nothing.
func TestAClickOnAFlagsNameGivesItTheKeyboardAndFlipsIt(t *testing.T) {
	m := newForm(t, "commit", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	x, y := lineAt(t, m, "--all")
	beside, _ := lineAt(t, m, "stages every")
	for name, click := range map[string]tea.MouseClickMsg{
		"on the blank line under the flag": testkit.Click(x, y+1),
		"on the rule over the form":        testkit.Click(x, 1),
		"under the form":                   testkit.Click(x, 30),
		"with another button":              {X: x, Y: y, Button: tea.MouseRight},
	} {
		if got := send(m, click); got.focus != 1 || len(got.fields[0].Values) != 0 {
			t.Errorf("a click %s: focus %d, --all %q", name, got.focus, got.fields[0].Values)
		}
	}
	if m = send(m, testkit.Click(beside, y)); m.focus != 0 || len(m.fields[0].Values) != 0 {
		t.Fatalf("a click on the description: focus %d, --all %q", m.focus, m.fields[0].Values)
	}
	m = send(m, key("down"))
	if m = send(m, testkit.Click(x, y)); m.focus != 0 || !slices.Equal(m.CommandLine(), []string{"--all"}) {
		t.Fatalf("a click on the name: focus %d, the line %q", m.focus, m.CommandLine())
	}
	if m = send(m, testkit.Click(x+len("--all")-1, y)); len(m.CommandLine()) != 0 {
		t.Errorf("a click on the name's last cell, the flag on: the line %q", m.CommandLine())
	}
	for _, at := range []int{x - 1, x + len("--all")} {
		if m = send(m, testkit.Click(at, y)); m.focus != 0 || len(m.CommandLine()) != 0 {
			t.Errorf("a click beside the name, at %d: focus %d, the line %q", at, m.focus, m.CommandLine())
		}
	}
}

// A click on a name of a row gives the row the keyboard, puts its cursor on the name, and chooses or flips it, as the
// space does: on a row drawn one name per line, and on one drawn side by side, where the cells between two names
// give the row the keyboard and choose nothing. The form is taller than the screen here, so each click is read
// through the window that clips it, and a click on a line that says how many lines are hidden does nothing.
func TestAClickOnARowsNameChoosesIt(t *testing.T) {
	m := newForm(t, "commit", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	m = send(m, key("up"))
	x, y := lineAt(t, m, "--file")
	if m = send(m, testkit.Click(x, y)); m.focus != 1 || m.cursor != 1 || m.fields[1].Chosen != 1 {
		t.Fatalf("a click on --file: focus %d, cursor %d, chosen %d", m.focus, m.cursor, m.fields[1].Chosen)
	}
	x, y = lineAt(t, m, "--message")
	if m = send(m, testkit.Click(x, y)); m.cursor != 0 || m.fields[1].Chosen != 0 {
		t.Errorf("a click on --message: cursor %d, chosen %d", m.cursor, m.fields[1].Chosen)
	}

	m = newForm(t, "flow", Answers{Chosen: map[string]int{"": 0}}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	if lines := screen(m); !strings.HasPrefix(lines[4], "↑") {
		t.Fatalf("the form is not clipped under the way back:\n%s", strings.Join(lines, "\n"))
	}
	if got := send(m, testkit.Click(0, 4)); got.focus != 0 || got.fields[0].Chosen != 0 {
		t.Errorf("a click on the line that says what is hidden: focus %d, chosen %d", got.focus,
			got.fields[0].Chosen)
	}
	x, y = lineAt(t, m, "--jq")
	if m = send(m, testkit.Click(x, y)); m.focus != 2 || m.cursor != 2 || m.fields[2].Chosen != 2 {
		t.Fatalf("a click on --jq: focus %d, cursor %d, chosen %d", m.focus, m.cursor, m.fields[2].Chosen)
	}
	x, y = lineAt(t, m, "--fresh")
	if m = send(m, testkit.Click(x-1, y)); m.focus != 1 || len(m.fields[1].Values) != 0 {
		t.Fatalf("a click between two names: focus %d, on %q", m.focus, m.fields[1].Values)
	}
	if m = send(m, testkit.Click(x, y)); m.cursor != 1 || !slices.Equal(m.fields[1].Values, []string{"--fresh"}) {
		t.Fatalf("a click on --fresh: cursor %d, on %q", m.cursor, m.fields[1].Values)
	}
	x, _ = lineAt(t, m, "--no-fetch")
	if m = send(m, testkit.Click(x, y), testkit.Click(x+len("--no-fetch")+len(sep), y)); m.cursor != 1 ||
		!slices.Equal(m.fields[1].Values, []string{"--no-fetch"}) {
		t.Errorf("a click on --no-fetch, then on --fresh again: cursor %d, on %q", m.cursor, m.fields[1].Values)
	}
	x, y = lineAt(t, m, "--stages")
	if m = send(m, testkit.Click(x, y)); m.focus != 0 || m.cursor != 1 || m.fields[0].Chosen != 1 {
		t.Errorf("a click on --stages: focus %d, cursor %d, chosen %d", m.focus, m.cursor, m.fields[0].Chosen)
	}

	// a row under a row's name is drawn two columns in, and its names are where it draws them
	m = newForm(t, "packages", Answers{Chosen: map[string]int{"": 1}}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	x, y = lineAt(t, m, "remove required")
	if m = send(m, testkit.Click(x-1, y)); m.focus != 1 || m.fields[1].Chosen != -1 {
		t.Fatalf("a click before remove: focus %d, chosen %d", m.focus, m.fields[1].Chosen)
	}
	if m = send(m, testkit.Click(x, y)); m.cursor != 2 || m.fields[1].Chosen != 2 {
		t.Errorf("a click on remove: cursor %d, chosen %d", m.cursor, m.fields[1].Chosen)
	}
}

// A click on a field that is typed in gives it the keyboard, the line being typed where the keyboard was kept as
// Enter would keep it: on its label, and on the lines of a value drawn under its option's name, which has no label.
func TestAClickOnATypedFieldGivesItTheKeyboard(t *testing.T) {
	m := newForm(t, "commit", Answers{Options: map[string][]string{"--message": {"one", "two"}}}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	lines := slices.IndexFunc(m.fields, func(f Field) bool { return f.Key == "--message" })
	paths := slices.IndexFunc(m.fields, func(f Field) bool { return f.Key == "<path>" })
	if m.fields[lines].Kind != Lines || m.fields[paths].Kind != PickMany || m.focus == lines {
		t.Fatalf("the fields: %+v, focus %d", m.fields, m.focus)
	}
	x, y := lineAt(t, m, "two")
	if m = send(m, testkit.Click(x, y)); m.focus != lines {
		t.Fatalf("a click on a line of --message: focus %d", m.focus)
	}
	m = send(m, testkit.Typed("three")...)
	x, y = lineAt(t, m, "<path>")
	m, _ = drive(t, m, testkit.Click(x, y))
	if m.focus != paths || !slices.Equal(m.fields[lines].Values, []string{"one", "two", "three"}) {
		t.Fatalf("a click on <path>…: focus %d, the lines %q", m.focus, m.fields[lines].Values)
	}
	if len(m.filtered()) == 0 {
		t.Errorf("the list the click gave the keyboard has no rows:\n%s", strings.Join(screen(m), "\n"))
	}
}

// A click on a row of the list that has the keyboard puts the cursor on the row and does as the space does on a list
// of many, which picks it or unpicks it, and as Enter does on a list of one, which takes it and goes on. A click on
// the list's filter, or on the line that says how many rows it hides, does nothing.
func TestAClickOnAListsRowPicksIt(t *testing.T) {
	m := rows40(t, 40)
	x, y := lineAt(t, m, path(3))
	if m = send(m, testkit.Click(x, y)); m.cursor != 3 || !slices.Equal(m.fields[m.focus].Values, []string{path(3)}) {
		t.Fatalf("a click on a row: cursor %d, picked %q", m.cursor, m.fields[m.focus].Values)
	}
	if m = send(m, testkit.Click(x+40, y-2)); m.cursor != 1 ||
		!slices.Equal(m.fields[m.focus].Values, []string{path(3), path(1)}) {
		t.Fatalf("a click far along another row: cursor %d, picked %q", m.cursor, m.fields[m.focus].Values)
	}
	if m = send(m, testkit.Click(x, y)); m.cursor != 3 || !slices.Equal(m.fields[m.focus].Values, []string{path(1)}) {
		t.Fatalf("a second click on the row: cursor %d, picked %q", m.cursor, m.fields[m.focus].Values)
	}
	_, filter := lineAt(t, m, path(0))
	_, more := lineAt(t, m, "↓")
	for name, at := range map[string]int{"on the filter": filter - 1, "on the line of the rows hidden": more} {
		got := send(m, testkit.Click(x, at))
		if got.cursor != 3 || len(got.fields[got.focus].Values) != 1 || got.focus != m.focus {
			t.Errorf("a click %s: cursor %d, picked %q, focus %d", name, got.cursor, got.fields[got.focus].Values,
				got.focus)
		}
	}

	t.Setenv("FAKE_KIT_ROWS", "")
	m = newForm(t, "new", FromMatch(syntax.Match{Literals: []string{"file"}}), true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	rule := slices.IndexFunc(m.fields, func(f Field) bool { return f.Key == "--rule" })
	x, y = lineAt(t, m, "--rule")
	if m, _ = drive(t, m, testkit.Click(x, y)); m.focus != rule || len(m.filtered()) != 3 {
		t.Fatalf("a click on --rule: focus %d, %d rows", m.focus, len(m.filtered()))
	}
	x, y = lineAt(t, m, "b ")
	m, _ = drive(t, m, testkit.Click(x, y))
	if !slices.Equal(m.fields[rule].Values, []string{"b"}) || m.focus != rule+1 {
		t.Errorf("a click on a row of a list of one: %q, focus %d", m.fields[rule].Values, m.focus)
	}
}

// A click on the command line gives it the keyboard, and a click on it while it has the keyboard runs it, as Enter
// does there, so no one click runs a command. A click on what kit says under it does nothing.
func TestAClickOnTheCommandLineGivesItTheKeyboardAndASecondRunsIt(t *testing.T) {
	t.Setenv("FAKE_KIT_MATCH_REFUSE", "tidy")
	m := newForm(t, "tidy", Answers{}, true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	command := func(m Model) int {
		lines := screen(m)
		for y := len(lines) - 1; y >= 0; y-- {
			if strings.HasPrefix(lines[y], " kit tidy") {
				return y
			}
		}
		t.Fatalf("no command line:\n%s", strings.Join(lines, "\n"))
		return -1
	}
	m, produced := drive(t, m, testkit.Click(3, command(m)))
	if done, _ := m.Done(); m.focus != len(m.fields) || done || len(produced) != 0 || m.refusal != "" {
		t.Fatalf("a first click: focus %d, done %v, produced %v, kit says %q", m.focus, done, produced, m.refusal)
	}
	if m, _ = drive(t, m, testkit.Click(3, command(m))); !strings.Contains(m.refusal, "refuses these words") {
		t.Fatalf("a second click asked kit nothing: %q", m.refusal)
	}
	m.refusal = "kit says no"
	if got, produced := drive(t, m, testkit.Click(3, command(m)+1)); len(produced) != 0 || got.refusal != "kit says no" {
		t.Errorf("a click on what kit says under the command line: produced %v, %q", produced, got.refusal)
	}
	t.Setenv("FAKE_KIT_MATCH_REFUSE", "")
	m, _ = drive(t, m, testkit.Click(3, command(m)))
	if done, _ := m.Done(); !done {
		t.Errorf("a click on the command line that has the keyboard ran nothing:\n%s", strings.Join(screen(m), "\n"))
	}
}

// A click acts on the field drawn where it fell: kit is asked for the verb's own arguments off the update loop, so the
// click flips the flag it fell on, and the arguments come in the wildcard's place after, the keyboard staying on that
// flag by its key, not by its place.
func TestAClickActsOnTheFieldDrawnAndTheExtensionKeepsTheKeyboardOnIt(t *testing.T) {
	one := func(n syntax.Node, repeat bool) syntax.Node {
		return syntax.Node{Kind: "group", Optional: true, Repeat: repeat, Alternatives: [][]syntax.Node{{n}}}
	}
	spec := syntax.Spec{Verb: "new", Extends: true, Syntax: [][]syntax.Node{{
		one(syntax.Node{Kind: "option", Name: "hole", Value: "value", Wildcard: true}, true),
		one(syntax.Node{Kind: "flag", Name: "up"}, false)}}}
	fields, _ := Fields(spec, Answers{})
	m := New(spec, fields, testkit.Runner(t, "kit"), true)
	m, _ = drive(t, m, tea.WindowSizeMsg{Width: 100, Height: 40})
	if kinds(m.fields) != "Wildcard Toggle" || m.focus != 0 {
		t.Fatalf("the fields: %s, focus %d", kinds(m.fields), m.focus)
	}
	m = send(m, testkit.Typed("--x=y")...)
	x, y := lineAt(t, m, "--up")
	m = send(m, testkit.Click(x, y))
	if m.focus != 0 || m.fields[0].Key != "--up" || len(m.fields[0].Values) != 1 || m.fields[1].Key != "--title" {
		t.Errorf("the click: focus %d, fields %+v", m.focus, m.fields)
	}
}
