package welcome

import (
	"errors"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/source"
	"github.com/empowerite/kit/projects/tui/internal/tabs"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A page that cannot be read gives the path it was looked for at, and no markdown.
func TestAPageThatIsNotThereGivesThePathItWasLookedFor(t *testing.T) {
	path := filepath.Join(t.TempDir(), "4-setup.md")
	if page, missing := readPage(path); page != "" || missing != path {
		t.Errorf("readPage = %q, %q", page, missing)
	}
}

// The screen opens with origin's owner/repo in its title, read from git where the command was typed, and without
// it in a repository with no origin.
func TestOpenReadsTheRepositoryFromOrigin(t *testing.T) {
	r := repoWith(t, nil)
	if m := Open(r, kit.Workspace{}); m.books.Fallback != "" {
		t.Errorf("no origin, and the repo is %q", m.books.Fallback)
	}
	if out, err := exec.Command("git", "-C", r.Dir, "remote", "add", "origin",
		"https://github.com/empowerite/kit.git").CombinedOutput(); err != nil {
		t.Fatalf("git remote add: %v\n%s", err, out)
	}
	m := Open(r, kit.Workspace{})
	shown := view(drive(m, at120))
	if m.books.Fallback != "empowerite/kit" || !strings.Contains(shown, "empowerite/kit") {
		t.Errorf("origin's repo is %q:\n%s", m.books.Fallback, shown)
	}
}

// A check whose step has no checks, or no page, shows under the last step that has checks.
func TestACheckOfAStepWithoutChecksShowsUnderTheLastStepThatHasThem(t *testing.T) {
	m, _ := fake(t)
	for _, step := range []string{"introduction", "nonesuch"} {
		if got := m.stepOf(kit.Check{ID: "stray", Step: step}); got != setup {
			t.Errorf("a check of %q shows under step %d, not setup", step, got)
		}
	}
}

// Pages that make no step change nothing; pages without the selected step's select the first step, on the bar.
func TestNewPagesWithoutTheSelectedStepSelectTheFirst(t *testing.T) {
	m, _ := atChains(t)
	before := m.tabs
	if m.setTabs(nil); len(m.tabs) != len(before) || m.step != chains || !m.inPane {
		t.Fatalf("no pages changed the steps: %d steps, step %d", len(m.tabs), m.step)
	}
	m.setTabs([]tab{known[introduction], known[terms]})
	if m.step != 0 || m.inPane || len(m.tabs) != 2 {
		t.Errorf("without the selected step: step %d, in the pane %v, %d steps", m.step, m.inPane, len(m.tabs))
	}
}

// A refusal with nothing on stderr says how kit ended: with its code, or that it failed when there is none.
func TestARefusalWithNothingOnStderrSaysHowKitEnded(t *testing.T) {
	for _, c := range []struct {
		err  error
		want string
	}{
		{&kit.ExitError{Code: 3}, "kit welcome --checks exited 3 with nothing on stderr"},
		{errors.New(""), "kit welcome --checks failed"},
		{errors.New("kit welcome refuses"), "kit welcome refuses"},
	} {
		if got := refusalOf(c.err); got != c.want {
			t.Errorf("refusalOf(%#v) = %q, not %q", c.err, got, c.want)
		}
	}
}

// A fix that cannot run at all says why, in red, under its check.
func TestAFixThatCannotRunSaysWhy(t *testing.T) {
	m, _ := loaded(t)
	m.fixed(fixedMsg{id: "jq", key: "jq", err: errors.New("no such file")})
	if n := m.notes["jq"]; !n.refusal || n.text != "kit welcome --fix=jq: no such file" {
		t.Errorf("the note: %+v", n)
	}
}

// On the bar over a step with checks, up does nothing; down does nothing while the checks have not answered, and the
// step says it is checking.
func TestUpOnTheBarAndDownBeforeTheChecksAnswerDoNothing(t *testing.T) {
	m, _ := atChains(t, esc)
	if m = drive(m, up); m.inPane || m.step != chains {
		t.Errorf("up on the bar: in the pane %v, step %d", m.inPane, m.step)
	}
	m, _ = fake(t)
	m = drive(m, at120, tabKey, tabKey, down)
	if m.inPane {
		t.Error("down entered the rows of a step whose checks have not answered")
	}
	if v := view(m); !strings.Contains(v, "checking…") {
		t.Errorf("the step does not say it is checking:\n%s", v)
	}
}

// On a screen too narrow for every tab, the bar scrolls to the selected step, whole, with a triangle where steps are
// hidden.
func TestOnAScreenTooNarrowTheBarScrolls(t *testing.T) {
	m, _ := atChains(t, tea.WindowSizeMsg{Width: 44, Height: 30})
	bar := strings.Split(view(m), "\n")[2]
	if !strings.Contains(bar, "│ 🧰 toolchains  3 : │") || !strings.HasSuffix(bar, tabs.After) {
		t.Errorf("at 44 columns, the bar does not scroll to the toolchains: %q", bar)
	}
}

// A step with checks, none of them its own once the checks have answered, shows its page alone.
func TestAStepWhoseChecksAnsweredWithNoneOfItsOwnShowsItsPageAlone(t *testing.T) {
	m, _ := atChains(t, esc)
	var chainsOnly []kit.Check
	for _, c := range m.checks {
		if c.Step == "toolchains" {
			chainsOnly = append(chainsOnly, c)
		}
	}
	m = drive(m, source.Answer[[]kit.Check]{Name: "checks", Value: chainsOnly}, tabKey)
	if v := view(m); m.step != setup || strings.Contains(v, "checking…") || strings.Contains(v, "gh is not logged in") {
		t.Errorf("setup with no checks of its own:\n%s", v)
	}
}

// The pane scrolls back up to the cursor's row when its offset has gone past it, and leaves a cursor that is not on
// the step as it is.
func TestThePaneScrollsBackToTheCursorsRow(t *testing.T) {
	m, _ := atChains(t, tea.WindowSizeMsg{Width: 120, Height: 9}, esc, tabKey, down)
	if !m.inPane {
		t.Fatal("not in the rows")
	}
	m.offsets[m.step] = 50
	m.fit()
	lines := m.stepLines()
	first := -1
	for k, l := range lines {
		if l.row == m.cursor {
			first = k
			break
		}
	}
	if m.offsets[m.step] > first {
		t.Errorf("the offset %d is past the cursor's first line %d", m.offsets[m.step], first)
	}
	// a cursor that names no row of the step leaves the offset as it is
	m.cursor, m.offsets[m.step] = len(m.checks)+5, 1
	m.fit()
	if m.offsets[m.step] != 1 {
		t.Errorf("a cursor off the step moved the offset to %d", m.offsets[m.step])
	}
}

// A fix runs the checks again, superseding a run still out: that run's answer, when it comes, is dropped, and the
// screen goes on checking until the latest answers.
func TestARunOfTheChecksThatAFixSupersededIsDropped(t *testing.T) {
	m := New(testkit.Runner(t, "welcome"), "")
	first := m.check()
	next, again := m.Update(fixedMsg{id: "jq", key: "jq"})
	m = next.(Model)
	if again == nil || !m.checking.Running() || m.checking.Gen() != 1 {
		t.Fatalf("after the fix: running %v, gen %d", m.checking.Running(), m.checking.Gen())
	}
	if m = drive(m, first()); m.checks != nil || !m.checking.Running() {
		t.Errorf("the superseded run was taken: %d checks, running %v", len(m.checks), m.checking.Running())
	}
}

// The page keys, pgup, pgdown, home, and end, move over a step's rows, so a step that shows no check takes none.
var pagingKeys = []tea.KeyPressMsg{pgdown, pgup, press(tea.KeyHome), press(tea.KeyEnd)}

// A search that shows none of a step's checks gives the bar the keyboard when it is left, by any of its four keys,
// since the pane has no row to take it; the page keys then do nothing, and the screen goes on.
func TestASearchThatShowsNoCheckLeavesTheKeyboardOnTheBar(t *testing.T) {
	for _, leave := range []tea.KeyPressMsg{enter, down, esc, tabKey} {
		keys := append([]tea.Msg{stepKey(chains), down, press('/')}, testkit.Typed("zzzz")...)
		m, _ := loaded(t, append(keys, leave)...)
		if n := len(m.rows(m.step)); n != 0 || m.inPane || m.search().Focused {
			t.Fatalf("after %s: %d rows, in the pane %v, in the search %v", leave, n, m.inPane, m.search().Focused)
		}
		for _, k := range pagingKeys {
			if m = drive(m, k); m.inPane || !strings.Contains(view(m), "no check matches the search") {
				t.Errorf("%s after %s: in the pane %v:\n%s", k, leave, m.inPane, view(m))
			}
		}
	}
	// a search that shows a check still gives its row the keyboard
	m, _ := loaded(t, append(append([]tea.Msg{stepKey(chains), press('/')}, testkit.Typed("jq")...), enter)...)
	if !m.inPane || m.cursor != 1 {
		t.Errorf("a search that shows jq: in the pane %v, cursor %d", m.inPane, m.cursor)
	}
}

// The keys bar names what Enter in the search and down on the bar lead to, so where a search shows none of a step's
// checks it names no checks: Enter in the search leads to the tabs, and the bar offers no down. With a check shown,
// both name the checks.
func TestTheKeysBarNamesNoChecksWhereTheSearchShowsNone(t *testing.T) {
	bar := func(m Model) string { return m.keys().String() }
	m, _ := loaded(t, stepKey(chains), down, press('/'))
	if got := bar(m); !strings.Contains(got, "⏎ checks") {
		t.Fatalf("the search, every check shown: %q", got)
	}
	m = drive(m, testkit.Typed("zzzz")...)
	if got := bar(m); len(m.rows(m.step)) != 0 || !strings.Contains(got, "⏎ tabs") || strings.Contains(got, "checks") {
		t.Errorf("the search, no check shown: %q", got)
	}
	if m = drive(m, enter); m.inPane || m.search().Focused {
		t.Fatalf("Enter left the keyboard off the bar: in the pane %v, in the search %v", m.inPane, m.search().Focused)
	}
	if got := bar(m); !strings.Contains(got, "⇥·⇧⇥ tab") || strings.Contains(got, "↓") || strings.Contains(got, "checks") {
		t.Errorf("the bar, no check shown: %q", got)
	}
	m = drive(m, press('/'), tea.KeyPressMsg{Code: 'u', Mod: tea.ModCtrl}, enter, esc)
	if got := bar(m); m.inPane || !strings.Contains(got, "↓ checks") {
		t.Errorf("the bar, every check shown: in the pane %v, %q", m.inPane, got)
	}
}

// The pane can hold the keyboard with no row under it, where the checks are read again and none of the step's comes
// back. The page keys do nothing there, and up gives the bar the keyboard.
func TestThePageKeysDoNothingInAPaneLeftWithNoRow(t *testing.T) {
	m, _ := atChains(t)
	var setupOnly []kit.Check
	for _, c := range m.checks {
		if c.Step == "setup" {
			setupOnly = append(setupOnly, c)
		}
	}
	m = drive(m, source.Answer[[]kit.Check]{Name: "checks", Value: setupOnly})
	if n := len(m.rows(m.step)); n != 0 || !m.inPane || m.step != chains {
		t.Fatalf("after the checks were read again: %d rows, in the pane %v, step %d", n, m.inPane, m.step)
	}
	for _, k := range pagingKeys {
		if m = drive(m, k); !m.inPane || m.cursor != 0 {
			t.Errorf("%s: in the pane %v, cursor %d", k, m.inPane, m.cursor)
		}
	}
	if m = drive(m, up); m.inPane {
		t.Error("up did not give the bar the keyboard")
	}
}

// c, r, and k act on the check under the cursor, and a step that shows no check has none there. Where the checks are
// read again and none of the step's comes back, the cursor's index names another step's check: one whose fix kit runs,
// or a terminal's failed finding. The keys bar offers nothing for it, and the three keys do nothing.
func TestAStepThatShowsNoCheckOffersNoFixOfAnother(t *testing.T) {
	record := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_WELCOME_CALLS", record)
	for _, other := range []kit.Check{
		{ID: "gh-auth", Step: "setup", Line: "gh is not logged in to github.com", Fix: "gh auth login", Runs: true},
		{ID: "terminal-iterm-option", Step: "setup", Line: "iTerm2 sends ⌥ as a plain key", Fix: "set it", Runs: true},
	} {
		m, r := atChains(t)
		m = drive(m, source.Answer[[]kit.Check]{Name: "checks", Value: []kit.Check{other}})
		if n := len(m.rows(m.step)); n != 0 || !m.inPane || m.step != chains || m.checks[m.cursor].ID != other.ID {
			t.Fatalf("%s: %d rows, in the pane %v, step %d, cursor %d", other.ID, n, m.inPane, m.step, m.cursor)
		}
		if m.copies() || m.runsHere() || m.keeping() || keysAt(m) != paneKeys {
			t.Errorf("%s is offered: copies %v, runs %v, keeps %v, keys %q", other.ID, m.copies(), m.runsHere(),
				m.keeping(), keysAt(m))
		}
		before := len(calls(t, record))
		for _, key := range []rune{'c', 'r', 'k'} {
			var msgs []tea.Msg
			if m, msgs = testkit.Drive(m, nil, press(key)); clipboard(msgs) != "" {
				t.Errorf("%s: %c copied %q", other.ID, key, clipboard(msgs))
			}
		}
		if got := calls(t, record); len(r.calls) != 0 || len(got) != before {
			t.Errorf("%s: a fix ran %q, kit was called %q", other.ID, r.calls, got[before:])
		}
	}
}
