package form

import (
	"slices"
	"strings"
	"testing"
)

// chooseOn puts the keyboard on the field, moves the cursor along its row to the option, and chooses it with the
// space, as a person would with tab and shift-tab.
func chooseOn(t *testing.T, m Model, field int, option string) Model {
	t.Helper()
	m = focusOn(m, field)
	at := slices.Index(m.fields[field].Options, option)
	if at < 0 {
		t.Fatalf("field %d has no option %q: %q", field, option, m.fields[field].Options)
	}
	for m.cursor < at {
		m = send(m, key("tab"))
	}
	for m.cursor > at {
		m = send(m, key("shift+tab"))
	}
	if m = send(m, key("space")); m.fields[field].Chosen != at {
		t.Fatalf("space on %q chose %d, not %d", option, m.fields[field].Chosen, at)
	}
	return m
}

// A one-of row's choice is kept by the row's place in the grammar, so it stays with its row: a row that takes the
// place of one that left, when an earlier row changes, has no choice of its own, and the form neither ends on a
// choice the new row does not have nor writes one nobody made.
func TestAChoiceStaysWithItsRowWhenAnEarlierRowChanges(t *testing.T) {
	// kit flow: --jq, the third of its row, then the stage issues in the first row, whose own row has two options,
	// --json and --jq: --jq, answered, is chosen there by its name, not by the place it had in the row that left
	m := chooseOn(t, newForm(t, "flow", Answers{}, false), 2, "--jq")
	m = chooseOn(t, m, 0, "issues")
	row := m.fields[slices.IndexFunc(m.fields, func(f Field) bool { return slices.Contains(f.Options, "--jq") })]
	if line := strings.Join(m.CommandLine(), " "); line != "issues --jq" || row.Key != "--json | --jq" || row.Chosen != 1 {
		t.Errorf("kit flow, --jq then issues: %q, %q chosen %d", line, row.Key, row.Chosen)
	}
	// kit tools: run, the fourth of the second line's row, then back to the first line, whose row has two
	m = chooseOn(t, newForm(t, "tools", Answers{}, false), 0, "--toolchain (install | update | path | run <command>…)")
	inner := slices.IndexFunc(m.fields, func(f Field) bool { return f.Kind == OneOf && f.Group == 0 })
	if inner < 0 {
		t.Fatalf("the second line of kit tools has no row: %s", kinds(m.fields))
	}
	m = chooseOn(t, m, inner, "run")
	m = chooseOn(t, m, 0, "kit tools")
	if row := m.fields[len(m.fields)-1]; row.Key != "--json | --jq" || row.Chosen != -1 || len(m.CommandLine()) != 0 {
		t.Errorf("kit tools, run then the first line: %q chosen %d, line %q", row.Key, row.Chosen, m.CommandLine())
	}
	// kit packages: --inactive, the second of its row, then the second line, whose row's second is add
	m = chooseOn(t, newForm(t, "packages", Answers{}, false), 1, "--inactive")
	m = chooseOn(t, m, 0, "(select | add | remove) <package>")
	if row := m.fields[1]; row.Key != "select | add | remove" || row.Chosen != -1 || len(m.CommandLine()) != 0 {
		t.Errorf("kit packages, --inactive then the second line: %q chosen %d, line %q", row.Key, row.Chosen,
			m.CommandLine())
	}
	// back on the first line, the row that left does not come back chosen
	m = chooseOn(t, m, 0, "kit packages")
	if row := m.fields[1]; row.Key != "--active | --inactive" || row.Chosen != -1 || len(m.CommandLine()) != 0 {
		t.Errorf("kit packages, back on the first line: %q chosen %d, line %q", row.Key, row.Chosen, m.CommandLine())
	}
}

// A row's path is the place of its group in the grammar, which Collect keys its choice by; a choice past the end of
// the row's alternatives is not taken, and the row is then chosen as the words given decide, or not at all.
func TestARowIsKeyedByItsPathAndAChoicePastItsEndIsNotTaken(t *testing.T) {
	spec := specs(t)["packages"]
	fields, err := Fields(spec, Answers{Chosen: map[string]int{"": 1, "1/0": 3}})
	if err != nil {
		t.Fatal(err)
	}
	if fields[0].Path != "" || fields[1].Path != "1/0" || fields[1].Key != "select | add | remove" {
		t.Fatalf("the rows' paths: %q, %q of %q", fields[0].Path, fields[1].Path, fields[1].Key)
	}
	if fields[1].Chosen != -1 || len(CommandLine(spec, fields)) != 0 {
		t.Errorf("a choice past the row's end: chosen %d, line %q", fields[1].Chosen, CommandLine(spec, fields))
	}
	if got := Collect(fields).Chosen; len(got) != 2 || got[""] != 1 || got["1/0"] != -1 {
		t.Errorf("the choices collected: %v", got)
	}
	fields, _ = Fields(spec, Answers{Literals: []string{"add"}, Chosen: map[string]int{"": 1, "1/0": 3}})
	if fields[1].Chosen != 1 || strings.Join(CommandLine(spec, fields), " ") != "add" {
		t.Errorf("add given, and a choice past the row's end: chosen %d, line %q", fields[1].Chosen,
			CommandLine(spec, fields))
	}
	// a verb of one usage line: its first group is the line's second node
	commit, _ := Fields(specs(t)["commit"], Answers{})
	if row := commit[slices.IndexFunc(commit, func(f Field) bool { return f.Kind == OneOf })]; row.Path != "0/1" {
		t.Errorf("kit commit's row: %q", row.Path)
	}
}
