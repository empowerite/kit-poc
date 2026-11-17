// A move to another workspace keeps the screens of the one left, and a move back shows them as they were.
package screens

import (
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// movers gives the root on the issues' picture of the repository github.com/o/a, over a kit that knows github.com/o/b
// too, and the clock the screens read, which the test moves.
func movers(t *testing.T) (Model, *time.Time) {
	t.Helper()
	m, _ := helped(t)
	m = drive(m, shell.SwitchMsg{Screen: shell.Issues})
	clock := time.Now()
	was := now
	now = func() time.Time { return clock }
	t.Cleanup(func() { now = was })
	return m, &clock
}

func TestGoingBackShowsTheScreenAsItWasLeft(t *testing.T) {
	m, _ := movers(t)
	m = drive(m, typed("/xyz")...)
	picture, epoch := m.made[shell.Issues], m.epochs[shell.Issues]
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/b"})
	if m.epochs[shell.Issues] == epoch || strings.Contains(title(m), "xyz") || len(m.parked) != 1 {
		t.Fatalf("on b: epoch %d (was %d), %d parked, titled %q", m.epochs[shell.Issues], epoch, len(m.parked), title(m))
	}
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/a"})
	if got := title(m); !strings.Contains(got, "xyz") || !strings.Contains(got, "o/a") {
		t.Errorf("back on a: %q", got)
	}
	if m.epochs[shell.Issues] != epoch || len(m.parked) != 1 || m.parked[0].ws.Name != "github.com/o/b" {
		t.Errorf("back on a: epoch %d (was %d), %d parked", m.epochs[shell.Issues], epoch, len(m.parked))
	}
	if m.made[shell.Issues] == nil || picture == nil {
		t.Errorf("no screen: %v", m.made[shell.Issues])
	}
}

func TestAnAnswerForAParkedScreenReachesIt(t *testing.T) {
	m, _ := movers(t)
	epoch := m.epochs[shell.Issues]
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/b"})
	// the answer of what the picture of a started comes while b is shown: it is the parked screen's, not b's
	m = drive(m, tagged{to: shell.Issues, epoch: epoch, msg: tea.WindowSizeMsg{Width: 70, Height: 20}})
	if n := len(strings.Split(m.made[shell.Issues].View().Content, "\n")); n != 30 {
		t.Errorf("the answer reached b's picture: %d lines", n)
	}
	lines := func() int { return len(strings.Split(m.parked[0].made[shell.Issues].View().Content, "\n")) }
	if n := lines(); n != 20 {
		t.Errorf("the parked picture did not take its answer: %d lines", n)
	}
	// an answer for no screen kept is dropped
	m = drive(m, tagged{to: shell.Issues, epoch: -1, msg: tea.WindowSizeMsg{Width: 70, Height: 10}})
	if n := lines(); n != 20 {
		t.Errorf("an answer for no screen: %d lines", n)
	}
}

func TestScreensParkedPastTheMostAreClosed(t *testing.T) {
	m, _ := movers(t)
	for i, name := range []string{"b", "c", "d", "e", "f"} {
		m.asked++
		ws := kit.Workspace{Kind: "repository", Name: "github.com/o/" + name, Checkout: t.TempDir()}
		m = drive(m, workspaceMsg{gen: m.asked, ws: ws})
		if want := min(i+1, parkedMost); len(m.parked) != want {
			t.Fatalf("after %s: %d parked, want %d", name, len(m.parked), want)
		}
	}
	if got := m.parked[0].ws.Name; got != "github.com/o/e" {
		t.Errorf("the latest left, first: %s", got)
	}
}

func TestScreensParkedLongAreReadAgainAndRecentOnesAreNot(t *testing.T) {
	m, clock := movers(t)
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/b"})
	*clock = clock.Add(parkedFresh / 2)
	if _, cmd := m.unpark(m.parked[0].ws); cmd != nil && !quiet(cmd) {
		t.Error("a screen parked a short while read again")
	}
	*clock = clock.Add(parkedFresh)
	if _, cmd := m.unpark(m.parked[0].ws); cmd == nil {
		t.Error("a screen parked long did not read again")
	}
}

// quiet says whether a batch of commands holds none, as unpark's of nothing does.
func quiet(cmd tea.Cmd) bool {
	msg := cmd()
	b, ok := msg.(tea.BatchMsg)
	return msg == nil || ok && len(b) == 0
}

func TestAGroupThatLostAMemberSinceIsNotGivenBackItsOldScreens(t *testing.T) {
	m, _ := movers(t)
	group := kit.Workspace{Kind: "group", Name: "w", Members: []kit.WorkspaceMember{{Repository: "github.com/o/a"}}}
	m.asked++
	m = drive(m, workspaceMsg{gen: m.asked, ws: group})
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/b"})
	if len(m.parked) != 2 {
		t.Fatalf("%d parked", len(m.parked))
	}
	group.Members = nil
	m.asked++
	m = drive(m, workspaceMsg{gen: m.asked, ws: group})
	if len(m.parked) != 2 || m.parked[0].ws.Name != "github.com/o/b" || m.parked[1].ws.Kind != "repository" {
		t.Errorf("the old w was kept: %+v", m.parked)
	}
}
