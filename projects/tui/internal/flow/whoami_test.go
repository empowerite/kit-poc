// A view that filters by @me needs the caller's login to let a row through: kit is asked who the caller is as soon as
// a panel holds @me, not only when a card opens, and the rows wait for the answer.
package flow

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// mine gives the keys of the fixture's issues ada is assigned, as All Issues lets them through.
var mine = []string{"empowerite/jig#7", "#31 #12"}

// A panel kept from the last session with assignees: @me opens on the caller's issues.
func TestAViewKeptWithMeOpensOnTheCallersRows(t *testing.T) {
	file := filepath.Join(t.TempDir(), "presets.json")
	// the session before: @me ticked in the assignees' card, which the file keeps as the panel was left
	m := drive(popoverOf(loaded(t, viewing(file)), "assignees"), down, press(tea.KeySpace))
	if !slices.Equal(keys(m), mine) {
		t.Fatalf("@me ticked: %q\n%s", keys(m), view(m))
	}
	// this session: no card is opened
	m = loaded(t, viewing(file), tea.WindowSizeMsg{Width: 120, Height: 40})
	if !strings.Contains(presetText(m), "assignees: @me") {
		t.Fatalf("the panel kept does not hold @me: %q", presetText(m))
	}
	if m.me != "ada" || !slices.Equal(keys(m), mine) || strings.Contains(view(m), "no row matches the panel") {
		t.Errorf("the view opens for %q on %q\n%s", m.me, keys(m), view(m))
	}
	// kit was asked once, however many messages came since
	m = drive(m, down, up, tea.WindowSizeMsg{Width: 100, Height: 40})
	if m.who != said {
		t.Errorf("after the answer: %v", m.who)
	}
}

// While kit has not answered, a panel that holds @me draws loading and gives no row, never that no row matches.
func TestAPanelThatHoldsMeLoadsUntilKitSaysWhoTheCallerIs(t *testing.T) {
	record := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_FLOW_CALLS", record)
	fixture, err := os.ReadFile("testdata/issues.json")
	if err != nil {
		t.Fatal(err)
	}
	o := options()
	o.Stages = []string{"issues"}
	// the view filters by @me and groups by nothing, so its rows group as they load, by what the caller's rows share
	held := func() Model {
		m := New(runner(t), o)
		m.stages[0].View = m.stages[0].View.GroupedBy(nil).
			FilteredBy("assignees", grid.Filter{Values: []string{grid.Caller}})
		return m
	}
	m := held()
	// the first message asks kit, which has not answered yet; the stage loads meanwhile
	next, ask := m.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	if m = next.(Model); m.who != asking || ask == nil {
		t.Fatalf("the first message: %v, asked %v", m.who, ask != nil)
	}
	next, _ = m.Update(answer("issues", string(fixture)))
	m = next.(Model)
	if v := view(m); len(m.rows(0)) != 0 || !strings.Contains(v, "loading") || strings.Contains(v, "no row matches") {
		t.Errorf("before kit answers, %d rows:\n%s", len(m.rows(0)), v)
	}
	if groups := m.panel(0).Groups(); len(groups) != 0 || !m.stages[0].Grouping {
		t.Errorf("before kit answers, the rows group by %q", groups)
	}
	// a message meanwhile does not ask again
	if next, again := m.Update(tea.WindowSizeMsg{Width: 120, Height: 40}); again != nil {
		t.Errorf("kit was asked again while it had not answered: %v", next.(Model).who)
	}
	// once kit answers the rows come, grouped as they are where the login is known before the stage loads
	first := drive(held(), meMsg{login: "ada"}, tea.WindowSizeMsg{Width: 120, Height: 40},
		answer("issues", string(fixture)))
	want := first.panel(0).Groups()
	if m = drive(m, ask()); m.me != "ada" || !slices.Equal(keys(m), keys(first)) || len(keys(m)) != 2 ||
		len(want) == 0 || !slices.Equal(m.panel(0).Groups(), want) {
		t.Errorf("once kit answers, for %q: %q, grouped by %q, want %q by %q\n%s", m.me, keys(m),
			m.panel(0).Groups(), keys(first), want, view(m))
	}
	if got := calls(t, record); !slices.Equal(got, []string{"flow --me"}) {
		t.Errorf("kit was asked %q", got)
	}
	// a panel that comes to hold @me later, whatever set it, asks the same way
	m = New(runner(t), o)
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 40}, answer("issues", string(fixture)))
	if m.who != unasked {
		t.Fatalf("no panel holds @me, and kit was asked: %v", m.who)
	}
	m.setPanel(m.panel(0).FilteredBy("assignees", grid.Filter{Values: []string{grid.Caller}}))
	if m = drive(m, down); m.me != "ada" || !slices.Equal(keys(m), mine) {
		t.Errorf("@me set later, for %q: %q", m.me, keys(m))
	}
}

// A failed answer says so in place of the keys, is not asked for again by itself, and is by the next card.
func TestAFailedAnswerToWhoTheCallerIsSaysSoAndTheNextCardAsksAgain(t *testing.T) {
	record := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_FLOW_CALLS", record)
	t.Setenv("FAKE_FLOW_REFUSE", "me")
	o := options()
	o.Stages = []string{"issues"}
	m := New(runner(t), o)
	m.stages[0].View = m.stages[0].View.FilteredBy("assignees", grid.Filter{Values: []string{grid.Caller}})
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 40}, m.Init()())
	asks := func() int {
		return len(slices.DeleteFunc(calls(t, record), func(c string) bool { return c != "flow --me" }))
	}
	last := lines(m)[len(lines(m))-1]
	if !strings.Contains(last, Failed+" kit flow --me failed, so @me matches no one: ") || m.note.Done ||
		!strings.Contains(view(m), "no row matches the panel") {
		t.Errorf("the refusal: %q\n%s", last, view(m))
	}
	// no message after it asks again by itself
	if m = drive(m, down, up, tea.WindowSizeMsg{Width: 120, Height: 40}); m.who != unsaid || asks() != 1 {
		t.Fatalf("after the refusal: %v, asked %d times", m.who, asks())
	}
	// kit can say now, and a card asks again
	t.Setenv("FAKE_FLOW_REFUSE", "")
	if m = popoverOf(m, "assignees"); m.me != "ada" || m.who != said || asks() != 2 || !slices.Equal(keys(m), mine) {
		t.Errorf("after the card: %q, %v, asked %d times, %q", m.me, m.who, asks(), keys(m))
	}
}

// Over a group the caller is asked in a member's checkout, so not before kit has said the workspace.
func TestOverAGroupAPanelThatHoldsMeAsksOnceKitSaidTheWorkspace(t *testing.T) {
	dirs := filepath.Join(t.TempDir(), "dirs")
	t.Setenv("FAKE_FLOW_DIRS", dirs)
	a, _ := filepath.EvalSymlinks(t.TempDir())
	r := runner(t)
	r.Group = "w"
	m := New(r, Options{Stages: []string{"issues"}, NoPresets: true, Clock: &testkit.Clock{}})
	m.stages[0].View = m.stages[0].View.FilteredBy("assignees", grid.Filter{Values: []string{grid.Caller}})
	if m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 24}); m.who != unasked || len(calls(t, dirs)) != 0 {
		t.Fatalf("before kit said the workspace: %v, %q", m.who, calls(t, dirs))
	}
	ws := group
	ws.Members = []kit.WorkspaceMember{{Repository: "github.com/o/a", Checkout: a}}
	m = drive(m, shell.WorkspaceMsg{Workspace: ws})
	if got := calls(t, dirs); m.me != "ada" || !slices.Equal(got, []string{a + "\tflow --me"}) {
		t.Errorf("once kit said the workspace: %q, %q", m.me, got)
	}
}
