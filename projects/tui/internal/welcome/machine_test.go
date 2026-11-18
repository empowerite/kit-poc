// The welcome judges the machine and depends on no workspace and no repository: kit is asked for the machine's checks
// and fixes alone, with no workspace words and no folder; the pages are the kit package's; the title has no workspace
// menu, and the keys bar no key for one; and the setup step is drawn as any step with checks.
package welcome

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// Whatever workspace the runner names, the checks, a fix, and a keep are the machine's: --machine, and none of
// --workspace= or --folder=.
func TestKitIsAskedForTheMachineAloneWhateverTheRunnerNames(t *testing.T) {
	for name, set := range map[string]func(*kit.Runner){
		"no workspace": func(*kit.Runner) {},
		"a group":      func(r *kit.Runner) { r.Group = "w" },
		"no group":     func(r *kit.Runner) { r.NoGroup = true },
	} {
		record := filepath.Join(t.TempDir(), "calls")
		t.Setenv("FAKE_WELCOME_CALLS", record)
		t.Setenv("FAKE_WELCOME_STATE", filepath.Join(t.TempDir(), "state"))
		r := testkit.Runner(t, "welcome")
		set(&r)
		m := Open(r)
		m.exec = fakeExec
		m = drive(m, append(testkit.Start(m, at120), toChains...)...)
		m = drive(m, press('r'))
		got := strings.Join(calls(t, record), "\n")
		want := "welcome --checks --json --machine --progress\nwelcome --fix=jq --machine\n" +
			"welcome --checks --json --machine --progress"
		if got != want {
			t.Errorf("%s: kit was asked\n%s\nwant\n%s", name, got, want)
		}
	}
}

// The title is the screen's name alone, - is nothing, the keys bar names no workspace key, and the workspace kittui
// tells every screen is no business of the welcome's: the screen is as it was.
func TestTheWelcomeHasNoWorkspaceMenu(t *testing.T) {
	m, _ := loaded(t)
	before := view(m)
	title := strings.Split(before, "\n")[0]
	if strings.Contains(title, shell.Workspaces) || strings.Contains(keysAt(m), "workspace") {
		t.Errorf("a workspace menu: %q, keys %q", title, keysAt(m))
	}
	ws := kit.Workspace{Kind: "group", Name: "w", Members: []kit.WorkspaceMember{{Repository: "github.com/o/a"}}}
	for name, msg := range map[string]tea.Msg{"-": press('-'), "a workspace told": shell.WorkspaceMsg{Workspace: ws},
		"a refusal told": shell.WorkspaceMsg{Refusal: "kit refuses"}} {
		next := drive(m, msg)
		if got := view(next); got != before || next.appMenu.Open {
			t.Errorf("%s changed the screen:\n%s", name, got)
		}
	}
	// a click where the workspace menu stood, after the screen's name, is a click on nothing
	if got := view(drive(m, testkit.Click(len("  = kit welcome ")+2, shell.Top))); got != before {
		t.Errorf("a click after the title:\n%s", got)
	}
}

// The setup step draws exactly as the toolchains do: no table, the page's title, a row a check, a failed check's fix
// and the rest of the page, the cursor's row with its buttons; a search narrows its checks, and finds one by what
// its findings say.
func TestSetupDrawsAsAnyStepWithChecksAndSearchesItsFindings(t *testing.T) {
	m, _ := loaded(t, stepKey(setup))
	m.checks = append(m.checks, kit.Check{ID: "kit-check-x", Step: "setup", Line: "kit check finds 2 problems",
		Findings: []string{".gitignore is missing", ".kit/1st.md is missing"}, Runs: true})
	if v := view(m); m.gridded() || !strings.Contains(v, "      .gitignore is missing\n      .kit/1st.md is missing\n") {
		t.Errorf("no findings under the check's line:\n%s", v)
	}
	m = drive(m, press('/'))
	m = drive(m, testkit.Typed("1st.md")...)
	if v := view(m); !strings.Contains(v, "kit check finds 2 problems") || strings.Contains(v, "gh is not logged in") {
		t.Errorf("a search for a finding:\n%s", v)
	}
	if m.count(setup) != "1" {
		t.Errorf("the bar counts %q", m.count(setup))
	}
}

// A check's own sentence is wrapped under its glyph, whole, at any width, and the buttons of the row under the cursor
// end its last line; a check with no sentence is a blank row.
func TestACheckSentenceLongerThanThePaneIsWrappedUnderItsGlyph(t *testing.T) {
	dir := t.TempDir()
	check := "[\n" + `{"id": "tool-actionlint", "step": "toolchains", "ok": false, "line": "actionlint is not installed; ` +
		`kit lint runs it for .kit/rules/workflows.md and every other file of the rule", "fix": "brew install actionlint", ` +
		`"interactive": false, "more": null, "runs": true},` + "\n" +
		`{"id": "tool-empty", "step": "toolchains", "ok": true, "line": "", "fix": null, "interactive": false, ` +
		`"more": null, "runs": true}` + "\n]\n"
	if err := os.WriteFile(filepath.Join(dir, "checks.json"), []byte(check), 0o644); err != nil {
		t.Fatal(err)
	}
	runner := testkit.Runner(t, "welcome")
	runner.Dir = dir
	m := New(runner)
	m = drive(m, append(testkit.Start(m, tea.WindowSizeMsg{Width: 60, Height: 30}), stepKey(chains))...)
	v := view(m)
	if !strings.Contains(v, "❌ actionlint is not installed; kit lint runs it for\n      .kit/rules/workflows.md and every "+
		"other file of the\n      rule\n") {
		t.Errorf("the sentence is cut:\n%s", v)
	}
	// the cursor's row has the buttons at the end of its last line
	m = drive(m, down)
	if v := view(m); !strings.Contains(v, "\n      rule   ⧉") {
		t.Errorf("the buttons:\n%s", v)
	}
}

// With no kit package to find, as kit cannot say its root, the known steps say where the pages were looked for, by the
// folder alone.
func TestWithNoRootTheStepsSayWhereThePagesWereLookedFor(t *testing.T) {
	tabs := readPages(kit.Runner{Kit: filepath.Join(t.TempDir(), "no-kit"), Dir: t.TempDir()})
	if len(tabs) != len(known) || tabs[terms].missing != filepath.Join(pagesDir, known[terms].file) {
		t.Errorf("tabs %+v", tabs)
	}
}

// What kit says as the checks run is dropped where the screen lags, not waited for: a run that says more than the
// screen listens to does not block, and its end still arrives.
func TestAProgressLineThatFindsTheScreenBehindIsDropped(t *testing.T) {
	m, _ := fake(t)
	m.Close()
	read := m.telling(func(_ context.Context, told func(kit.Progress)) ([]kit.Check, error) {
		for range cap(m.told) + 6 {
			told(kit.Progress{Check: "tool-jq"})
		}
		return nil, nil
	})
	if _, err := read(context.Background(), false); err != nil || len(m.told) != cap(m.told) {
		t.Errorf("%v, %d of %d lines kept", err, len(m.told), cap(m.told))
	}
}

// A section's list item is its text without the marker, one line with the rest.
func TestASectionsListItemsAreItsTextWithoutTheMarker(t *testing.T) {
	_, sections := parseSections("## Part\n\nIntro.\n\n- first item\n* second item\n\n`kit part`\n")
	if len(sections) != 1 || sections[0].text != "Intro. first item second item" ||
		len(sections[0].commands) != 1 || sections[0].commands[0] != "kit part" {
		t.Errorf("sections %+v", sections)
	}
}

// > and < show a level more and less of the terms from the step bar, as from a stage's tab bar in flow, and from the
// rows: the bar keeps the keyboard, and the outline moves with one of them, whichever the table is at.
func TestGreaterAndLessShowALevelMoreAndLessOfTheTerms(t *testing.T) {
	m, _ := loaded(t, stepKey(terms))
	before := maps(m.sheet().Table().Open)
	more := drive(m, press('>'))
	opened := maps(more.sheet().Table().Open)
	less := drive(more, press('<'))
	if opened == before && maps(less.sheet().Table().Open) == opened || more.inPane || less.inPane {
		t.Errorf("neither > nor < moved the outline from %s: now %s", before, maps(less.sheet().Table().Open))
	}
	if rows := drive(m, down, down, press('>')); !rows.sheet().InRows() {
		t.Errorf("> in the rows:\n%s", view(rows))
	}
}
