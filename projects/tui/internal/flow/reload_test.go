// A stage that loads again keeps the cursor on the row it was on, wherever the rows that came put that row: a watched
// stage loads by itself, and a key pressed after it must act on the row the person was on.
package flow

import (
	"os"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/source"
)

// again gives the picture with a stage loaded again, as a watched stage loads by itself, and answered with the JSON.
func again(m Model, name, data string) Model {
	m.rewatch(name)
	return drive(m, source.Answer[[]byte]{Name: name, Gen: m.find(name).src.Gen(), Value: []byte(data)})
}

func TestAReloadKeepsTheCursorOnItsRowNotOnItsIndex(t *testing.T) {
	fixture, err := os.ReadFile("testdata/issues.json")
	if err != nil {
		t.Fatal(err)
	}
	m := intoRows(loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 40}))
	under := func(m Model) string { return m.rows(0)[m.stages[0].Cursor].Key }
	at := slices.IndexFunc(m.rows(0), func(r row) bool { return r.Key == "#8 #4" })
	if at < 0 {
		t.Fatalf("no row #8 #4:\n%s", view(m))
	}
	m.stages[0].Cursor = at
	// one more issue of kit, older than every other, so it stands first under kit's heading
	older := `[{"number": 3, "ref": "#3", "tracker": "#", "title": "The oldest", "assignees": [], "labels": [],
		"age": 9000000, "source": "github", "organization": "empowerite", "repository": "kit", "status": "backlog"},`
	m = again(m, "issues", older+strings.TrimPrefix(strings.TrimSpace(string(fixture)), "["))
	if got := slices.IndexFunc(m.rows(0), func(r row) bool { return r.Key == "#8 #4" }); got == at {
		t.Fatalf("the reload did not move the row: it is still at %d\n%s", at, view(m))
	}
	if got := under(m); got != "#8 #4" {
		t.Errorf("after the reload the cursor is on %q, not on #8 #4", got)
	}
	// space then selects the row the person was on
	if m = drive(m, press(tea.KeySpace)); !m.stages[0].Picked["#8 #4"] || m.selected() != 1 {
		t.Errorf("space after the reload selected %v", m.stages[0].Picked)
	}
	// a row the reload took away leaves the cursor where it stood, within the rows that came
	m = again(m, "issues", `[{"number": 3, "ref": "#3", "title": "The oldest", "status": "backlog"}]`)
	if k := m.stages[0].Cursor; k >= len(m.rows(0)) || under(m) != "#3" {
		t.Errorf("after its row went, the cursor is at %d of %d rows", k, len(m.rows(0)))
	}
}
