// A pull request's open row says what stands between it and its merge, a line for each state kit's document says
// holds it back, in kit's words, with the failing check, the checks' counts, the unresolved threads, and who is asked.
package flow

import (
	"path/filepath"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

func TestAnOpenPullRequestSaysWhatBlocksIt(t *testing.T) {
	for _, width := range []int{80, 120} {
		m := loaded(t, viewing(""), tea.WindowSizeMsg{Width: width, Height: 36})
		m = intoRows(drive(m, tabsTo("changes")...))
		// the rows closed, the state and the checks are glyphs alone at these widths
		if v := view(m); strings.Contains(v, "failing") || strings.Contains(v, "a check failed") {
			t.Fatalf("at %d columns the closed rows say why already:\n%s", width, v)
		}
		// #3 is a draft whose checks run, with two threads unresolved; #4 has a failed check
		m = drive(m, down, toggle, down, toggle)
		v := view(m)
		for _, want := range []string{
			"🔨 draft",
			"🚦 queued: a check is still running; 0 of 2 passed",
			"💬 comments:open: a review thread is unresolved; 2 threads",
			"🔥 failing:gate: a check failed; lint, 1 of 2 passed",
		} {
			if !strings.Contains(v, want) {
				t.Errorf("at %d columns the open rows do not say %q:\n%s", width, want, v)
			}
		}
		if width == 80 {
			testkit.Golden(t, filepath.Join("testdata", "changes-blocked.golden"), raw(m))
		}
	}
}

// Each state kit's document says of a pull request is a line, in the order kit names the states; one that is ready
// has none.
func TestThePullRequestsBlockersAreThoseKitsDocumentSays(t *testing.T) {
	took := int64(95)
	for _, c := range []struct {
		name string
		p    pull
		want []string
	}{
		{"ready", pull{State: "ready", Checks: &checks{State: "SUCCESS", Passed: 2, Total: 2, Took: &took}}, nil},
		{"a state kit has not named", pull{State: "merged"}, nil},
		{"conflicted", pull{State: "conflicted", Checks: &checks{State: "SUCCESS", Passed: 1, Total: 1}},
			[]string{"💥 conflicted: with its base"}},
		{"no check", pull{State: "no-check", Checks: &checks{State: "NONE"}},
			[]string{"📭 no-check: no check has reported"}},
		{"one thread", pull{State: "comments:open", Unresolved: 1},
			[]string{"💬 comments:open: a review thread is unresolved; 1 thread"}},
		{"a review", pull{State: "blocked:approval"}, []string{"👀 blocked:approval: a review blocks the merge"}},
		{"a review, with who", pull{State: "blocked:approval", Reviewers: []reviewer{{Login: "bob", State: "changes"},
			{Login: "cy", State: "requested"}, {Login: "di", State: "approved"}, {Login: "ed", State: "commented"}}},
			[]string{"👀 blocked:approval: a review blocks the merge; bob asked for changes, cy is asked"}},
		{"a draft that fails, with threads", pull{State: "draft", Unresolved: 3,
			Checks: &checks{State: "FAILURE", Passed: 0, Total: 1, Failing: "gate"}},
			[]string{"🔨 draft", "🔥 failing:gate: a check failed; gate, 0 of 1 passed",
				"💬 comments:open: a review thread is unresolved; 3 threads"}},
	} {
		if got := blockers(c.p); !slices.Equal(got, c.want) {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
}
