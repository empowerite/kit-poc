// An issue of another repository, which kit lists underway where a pull request here closes it, is a row of its own:
// its key names its repository, its title leads to its own page, and no action hands kit its number, which kit would
// read as this repository's issue.
package flow

import (
	"slices"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// twoOfOneNumber is kit's issues where pull request 5 closes #12 of the repository here and #12 of jig, each with its
// own page and the pull request's, as kit prints them.
const twoOfOneNumber = `[
  {"number": 12, "ref": "#12", "title": "kit's twelve", "status": "underway", "source": "github",
   "organization": "empowerite", "repository": "kit", "url": "https://github.com/empowerite/kit/issues/12",
   "pr": {"number": 5, "state": "ready", "author": "ada", "url": "https://github.com/empowerite/kit/pull/5"}},
  {"number": 12, "ref": "#12", "title": "jig's twelve", "status": "underway", "source": "github",
   "organization": "empowerite", "repository": "jig", "url": "https://github.com/empowerite/jig/issues/12",
   "pr": {"number": 5, "state": "ready", "author": "ada", "url": "https://github.com/empowerite/kit/pull/5"}}]`

// writes are the issues' actions that hand kit an issue's reference.
var writes = []string{"Start Local Work for Each", "Start Local Work Together…", "Assign to Me", "Assign to…",
	"Unassign", "Gather Under a Parent…", "Close as Not Planned", "Close as Duplicate of…"}

func TestAnIssueOfAnotherRepositoryIsARowOfItsOwn(t *testing.T) {
	o := options()
	o.Stages = []string{"issues"}
	m := drive(New(runner(t), o), tea.WindowSizeMsg{Width: 120, Height: 40}, answer("issues", twoOfOneNumber))
	if m.stages[0].refusal != "" {
		t.Fatalf("two issues of one number under one pull request are refused: %s", m.stages[0].refusal)
	}
	var keys, pages []string
	for _, r := range m.records(m.stages[0]) {
		keys, pages = append(keys, r.Key), append(pages, r.values["title"].Link)
	}
	if want := []string{"#12 #5", "empowerite/jig#12 #5"}; !slices.Equal(keys, want) {
		t.Errorf("the keys: %q, want %q", keys, want)
	}
	if want := []string{"https://github.com/empowerite/kit/issues/12",
		"https://github.com/empowerite/jig/issues/12"}; !slices.Equal(pages, want) {
		t.Errorf("the titles lead to %q, want %q", pages, want)
	}
	// each row's title is its own issue's, in the dialog that confirms and in the links copied
	m.stages[0].Picked["#12 #5"] = true
	if got := m.listed(); !slices.Equal(got, []string{"#12 kit's twelve"}) {
		t.Errorf("the issue here is listed %q", got)
	}
	m.stages[0].Picked = map[string]bool{"empowerite/jig#12 #5": true}
	if got := m.listed(); !slices.Equal(got, []string{"empowerite/jig#12 jig's twelve"}) {
		t.Errorf("jig's issue is listed %q", got)
	}
	// the pull request is the repository's here, whichever issue it closes
	for _, r := range m.records(m.stages[0]) {
		if got := r.values["state"].Link; got != "https://github.com/empowerite/kit/pull/5" {
			t.Errorf("%s's pull request leads to %q", r.Key, got)
		}
	}
	// where kittui knows the workspace and no origin, the row is keyed by its repository, and its page is still kit's
	m = New(runner(t), Options{Stages: []string{"issues"}, NoPresets: true, Clock: &testkit.Clock{}})
	m = drive(m, shell.WorkspaceMsg{Workspace: kit.Workspace{Kind: "repository", Member: "github.com/empowerite/kit"}},
		answer("issues", twoOfOneNumber))
	if r := m.records(m.stages[0])[1]; r.Key != "empowerite/jig#12 #5" ||
		r.values["title"].Link != "https://github.com/empowerite/jig/issues/12" {
		t.Errorf("with no origin: the key %q, the page %q", r.Key, r.values["title"].Link)
	}
}

func TestNoActionHandsKitTheNumberOfAnotherRepositorysIssue(t *testing.T) {
	m, record := selecting(t)
	// the fixture's first row is #7 of jig, in kit's picture
	m.stages[0].Picked = map[string]bool{"empowerite/jig#7": true}
	if m.selected() != 1 {
		t.Fatalf("jig's #7 is not selected by its repository: %d rows", m.selected())
	}
	m = drive(m, press(':'))
	for _, name := range append(slices.Clone(writes), "Add to Pull Request…") {
		if k := item(m, name); k < 0 || m.enabled(k) {
			t.Errorf("%s on another repository's issue: line %d, not dim", name, k)
		}
	}
	// what writes nothing is still offered, and the link copied is to jig's issue
	for _, name := range []string{"New…", "Copy Links"} {
		if k := item(m, name); k < 0 || !m.enabled(k) {
			t.Errorf("%s on another repository's issue: line %d, dim", name, k)
		}
	}
	if got, want := m.links(), "- [empowerite/jig#7 Fix the thing](https://github.com/empowerite/jig/issues/7)"; got != want {
		t.Errorf("the link copied: %q, want %q", got, want)
	}
	// the action's key runs nothing either
	m = drive(m, esc, typed("a")[0])
	if got := acted(t, record); len(got) != 0 {
		t.Errorf("a on another repository's issue ran %q", got)
	}
	// with an issue of the repository here beside it, the actions stay dim
	m.stages[0].Picked["#45"] = true
	if k := item(m, "Assign to Me"); m.enabled(k) {
		t.Error("Assign to Me with another repository's issue among those selected is not dim")
	}
	delete(m.stages[0].Picked, "empowerite/jig#7")
	if k := item(m, "Assign to Me"); !m.enabled(k) {
		t.Error("Assign to Me on an issue of the repository here is dim")
	}
}

// The repository a row is read in is the row's member over a group, else the one kit says the workspace is, else
// origin's, whose path may lack its leading groups; its letters' case is the forge's to choose.
func TestTheRepositoryHereIsTheMembersThenTheWorkspacesThenOrigins(t *testing.T) {
	m := New(runner(t), Options{Stages: []string{"issues"}, NoPresets: true, Clock: &testkit.Clock{},
		Origin: Origin{Host: "gitlab.com", Repo: "sub/kit"}})
	jig := issue{Number: 7, Organization: "empowerite", Repository: "jig"}
	for _, c := range []struct {
		name string
		i    issue
		ws   string
		want bool
	}{
		{"no place", issue{Number: 7}, "", false},
		{"origin's, under its groups", issue{Organization: "group/sub", Repository: "kit"}, "", false},
		{"another than origin's", jig, "", true},
		{"the workspace's, whatever origin says", jig, "github.com/Empowerite/Jig", false},
		{"another than the workspace's", issue{Organization: "sub", Repository: "kit"}, "github.com/empowerite/jig", true},
		{"its member's", issue{Organization: "o", Repository: "a", Member: "github.com/o/a"}, "", false},
		{"another than its member's", issue{Organization: "o", Repository: "b", Member: "github.com/o/a"}, "", true},
	} {
		m.ws = kit.Workspace{Member: c.ws}
		if got := m.elsewhere(c.i); got != c.want {
			t.Errorf("%s: elsewhere %v, want %v", c.name, got, c.want)
		}
	}
	// rows built before kit said the workspace are built again once it has: origin is a fork here, and kit reads jig
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 40},
		answer("issues", `[{"number": 7, "organization": "empowerite", "repository": "jig"}]`))
	if got := keys(m); !slices.Equal(got, []string{"empowerite/jig#7"}) {
		t.Errorf("before kit said the workspace, the key is %q", got)
	}
	m = drive(m, shell.WorkspaceMsg{Workspace: kit.Workspace{Kind: "repository", Member: "github.com/empowerite/jig"}})
	if got := keys(m); !slices.Equal(got, []string{"#7"}) {
		t.Errorf("once kit said the workspace, the key is %q", got)
	}
	// with no origin and no workspace, kittui cannot tell, and the row is the repository's here
	m.origin, m.ws = Origin{}, kit.Workspace{}
	if m.elsewhere(jig) {
		t.Error("an issue is elsewhere with nowhere known")
	}
}
