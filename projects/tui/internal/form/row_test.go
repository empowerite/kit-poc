package form

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/syntax"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// The form of kit commit opens on its required row, --message or --file, with the cursor on --message: what is typed
// chooses --message and is its first line, with no key before it.
func TestTypingOnARequiredRowChoosesTheOptionUnderTheCursorAndStartsItsValue(t *testing.T) {
	m := newForm(t, "commit", Answers{}, false)
	if f := m.fields[m.focus]; f.Kind != OneOf || !f.Required || m.cursor != 0 {
		t.Fatalf("kit commit opens on %+v, cursor %d", f, m.cursor)
	}
	m = send(m, testkit.Typed("#1 tui: x")...)
	if got := strings.Join(m.CommandLine(), "\x00"); got != "--message=#1 tui: x" {
		t.Errorf("typed on the row: %q, focus %d, input %q", got, m.focus, m.input)
	}
	// kit work opens on <reference>, --title, or --pr: 7 typed is the reference
	m = send(newForm(t, "work", Answers{}, false), testkit.Typed("7")...)
	if got := strings.Join(m.CommandLine(), " "); got != "7" {
		t.Errorf("7 typed on kit work's row: %q", got)
	}
}

// On a required row with nothing chosen, the space chooses the option under the cursor, the first, and Enter chooses
// it and goes on to its value.
func TestSpaceAndEnterChooseTheFirstOptionOfARequiredRow(t *testing.T) {
	m := send(newForm(t, "commit", Answers{}, false), key("space"))
	if f := m.fields[1]; f.Chosen != 0 || m.focus != 1 {
		t.Errorf("the space on the row: chosen %d, focus %d", f.Chosen, m.focus)
	}
	m = send(newForm(t, "commit", Answers{}, false), key("enter"))
	if f := m.fields[1]; f.Chosen != 0 || m.focus != 2 || m.fields[2].Key != "--message" {
		t.Fatalf("Enter on the row: chosen %d, focus %d on %q", f.Chosen, m.focus, m.fields[m.focus].Key)
	}
	m = send(m, testkit.Typed("hello")...)
	if got := strings.Join(m.CommandLine(), "\x00"); got != "--message=hello" {
		t.Errorf("Enter, then hello: %q", got)
	}
}

// Enter walks a form without turning anything on: on an optional row with nothing chosen the cursor starts on the
// first option, and Enter there only goes on, while the space chooses it, and Enter on an option the cursor was moved
// to chooses that one. The keys bar names Enter choose only while it would choose.
func TestEnterOnAnOptionalRowWithNothingChosenOnlyGoesOn(t *testing.T) {
	m := newForm(t, "flow", Answers{}, false)
	for m.focus < len(m.fields) {
		m = send(m, key("enter"))
	}
	if line := m.CommandLine(); len(line) != 0 {
		t.Fatalf("Enter through the form of kit flow wrote %q", line)
	}
	m = focusOn(m, 2)
	if f := m.fields[2]; f.Key != "--text | --json | --jq" || f.Required || f.Chosen != -1 || m.cursor != 0 {
		t.Fatalf("kit flow's output row: %+v, cursor %d", f, m.cursor)
	}
	if bar := m.keys().String(); !strings.Contains(bar, "␣ choose ⌫ clear") || strings.Contains(bar, "type its value") {
		t.Errorf("the keys on an optional row at rest: %q", bar)
	}
	m = send(m, key("tab"))
	if bar := m.keys().String(); !strings.Contains(bar, "␣·⏎ choose") || strings.Contains(bar, "⏎ next") {
		t.Errorf("the keys on an option the cursor was moved to: %q", bar)
	}
	if m = send(m, key("enter")); m.fields[2].Chosen != 1 || m.focus != 4 {
		// field 3 is --json's own flag, which the row names: it is no stop
		t.Errorf("Enter on --json: chosen %d, focus %d", m.fields[2].Chosen, m.focus)
	}
	// a letter typed on a row of flags, one of or any of, chooses nothing and is typed nowhere
	m = focusOn(m, 2)
	if m = send(m, testkit.Typed("x")...); m.fields[2].Chosen != 1 || m.focus != 2 || m.input != "" {
		t.Errorf("x on a row of flags: chosen %d, focus %d, input %q", m.fields[2].Chosen, m.focus, m.input)
	}
	m = focusOn(m, 1)
	if m = send(m, testkit.Typed("x")...); m.fields[1].Kind != AnyOf || len(m.fields[1].Values) != 0 || m.focus != 1 {
		t.Errorf("x on an any-of row: %+v, focus %d", m.fields[1], m.focus)
	}
}

// On a required row, the keys bar names Enter choose beside the space until the option under the cursor is chosen,
// and says that typing gives the option's value while it takes one. What is typed on an option already chosen goes on
// in its value, and a key held with ctrl is no character.
func TestARequiredRowNamesWhatEnterAndTypingDo(t *testing.T) {
	m := newForm(t, "work", Answers{}, false)
	if bar := m.keys().String(); !strings.Contains(bar, "⇥·⇧⇥ option ␣·⏎ choose type its value") {
		t.Errorf("the keys on kit work's row, on <reference>: %q", bar)
	}
	m = send(m, key("tab"), key("space"))
	if f := m.fields[0]; f.Options[f.Chosen] != "--title" || m.focus != 0 {
		t.Fatalf("the space on --title: %+v, focus %d", f, m.focus)
	}
	if bar := m.keys().String(); !strings.Contains(bar, "␣ choose type its value") || strings.Contains(bar, "⏎ choose") {
		t.Errorf("the keys on --title, chosen: %q", bar)
	}
	if m = send(m, tea.KeyPressMsg{Code: 'a', Mod: tea.ModCtrl}); m.focus != 0 || m.input != "" {
		t.Errorf("ctrl-a on the row: focus %d, input %q", m.focus, m.input)
	}
	m = send(m, testkit.Typed("The plan")...)
	if got := strings.Join(m.CommandLine(), "\x00"); got != "--title=The plan" || m.fields[m.focus].Key != "--title" {
		t.Errorf("typed on --title, chosen: %q, on %q", got, m.fields[m.focus].Key)
	}
}

// A row's alternatives are found by its path in the grammar, and an alternative of no node takes no value.
func TestARowsAlternativesAreFoundByItsPath(t *testing.T) {
	packages := specs(t)["packages"]
	if got := labels(alternatives(packages, "")); len(got) != 5 || got[2] != "--stages" || got[4] != "packages" {
		t.Errorf("the usage lines of kit packages: %q", got)
	}
	if got := labels(alternatives(packages, "1/0")); !slices.Equal(got, []string{"select", "add", "remove"}) {
		t.Errorf("the row of kit packages' second line: %q", got)
	}
	if got := labels(alternatives(specs(t)["commit"], "0/1")); !slices.Equal(got, []string{"--message", "--file"}) {
		t.Errorf("kit commit's row: %q", got)
	}
	spec := syntax.Spec{Verb: "x", Syntax: [][]syntax.Node{{{Kind: "group", Optional: true, Alternatives: [][]syntax.Node{
		{}, {{Kind: "flag", Name: "up"}}}}}}}
	fields, _ := Fields(spec, Answers{})
	m := New(spec, fields, testkit.Runner(t, "kit"), true)
	if f := m.fields[m.focus]; f.Kind != OneOf || m.cursor != 0 || m.valued(f) {
		t.Errorf("an alternative of no node: %+v, cursor %d, valued %v", f, m.cursor, m.valued(f))
	}
}

// A row is drawn by its own alternatives, found by its path, whatever groups the usage lines not chosen hold. In kit
// tools' form, the second usage line chosen and run in its row, the row is drawn one name per line, since run has a
// field of its own, and <command>… is drawn under run, in the row, not at the top margin under the last usage line.
func TestARowIsDrawnByItsOwnAlternativesWhateverTheOtherUsageLinesHold(t *testing.T) {
	spec := specs(t)["tools"]
	fields, _ := Fields(spec, Answers{Chosen: map[string]int{"": 1, "1/1": 3}})
	if kinds(fields) != "OneOf Text OneOf Lines" || fields[2].Key != "install | update | path | run" ||
		fields[3].Group != 2 {
		t.Fatalf("kit tools run: %s %+v", kinds(fields), fields)
	}
	lines := strings.Split(RenderStatic(spec, fields, 100), "\n")
	at := func(prefix string) int {
		return slices.IndexFunc(lines, func(line string) bool { return strings.HasPrefix(line, prefix) })
	}
	heading, install, run := at("     one of"), at("     install "), at("     *run*")
	command, sources := at("     <command>… required"), at("   sources")
	if heading < 0 || install != heading+1 || run < install || command != run+2 || sources < command ||
		at("   <command>") >= 0 {
		t.Errorf("one of at %d, install at %d, run at %d, <command>… at %d, sources at %d:\n%s", heading, install, run,
			command, sources, strings.Join(lines, "\n"))
	}
}

// The flag that opens a chosen alternative is named by its row: the keyboard never stops on it, and a side-by-side row
// does not draw it again below.
func TestTheFlagOfAChosenOptionIsNoStopAndIsDrawnOnce(t *testing.T) {
	m := newForm(t, "context", Answers{Chosen: map[string]int{"": 1}}, false)
	if len(m.fields) != 2 || !m.fields[1].Opening {
		t.Fatalf("kit context --claude: %+v", m.fields)
	}
	if m = send(m, key("down")); m.focus != 2 {
		t.Errorf("down from the row: focus %d, want the command line at 2", m.focus)
	}
	if m = send(m, key("up")); m.focus != 0 {
		t.Errorf("up from the command line: focus %d, want the row at 0", m.focus)
	}
	m = newForm(t, "trust", Answers{Chosen: map[string]int{"": 0, "0/0": 1}}, false)
	view := RenderStatic(m.spec, m.fields, 100)
	if n := strings.Count(view, "--json"); n != 2 { // the row's name, and the command line
		t.Errorf("--json drawn %d times, want the row and the command line:\n%s", n, view)
	}
}

// A row drawn one option under another, as kit commit's --message and --file, is walked by up and down, which leave
// it past its ends; a row drawn on one line is left by them at once.
func TestUpAndDownWalkTheOptionsOfAStackedRow(t *testing.T) {
	m := newForm(t, "commit", Answers{}, false)
	m = send(m, tea.WindowSizeMsg{Width: 100, Height: 40})
	row := slices.IndexFunc(m.fields, func(f Field) bool { return f.Kind == OneOf })
	m = focusOn(m, row)
	if !m.stacked() {
		t.Fatal("kit commit's row of --message and --file is not stacked")
	}
	if m = send(m, key("down")); m.focus != row || m.cursor != 1 {
		t.Errorf("down on the first option: focus %d, cursor %d", m.focus, m.cursor)
	}
	if m = send(m, key("up")); m.focus != row || m.cursor != 0 {
		t.Errorf("up on the second option: focus %d, cursor %d", m.focus, m.cursor)
	}
	if m = send(m, key("up")); m.focus != row-1 {
		t.Errorf("up on the first option: focus %d, want %d", m.focus, row-1)
	}
	m = focusOn(m, row)
	if m = send(m, key("down"), key("down")); m.focus != row+1 {
		t.Errorf("down past the last option: focus %d, want %d", m.focus, row+1)
	}
	flow := newForm(t, "flow", Answers{}, false)
	flow = send(flow, tea.WindowSizeMsg{Width: 100, Height: 40})
	if flow = focusOn(flow, 2); flow.stacked() || send(flow, key("down")).focus != 3 {
		t.Error("down on a row drawn on one line stays in it")
	}
}
