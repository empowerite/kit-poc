// A stage that loads, or that kit refused, gives no rows: nothing of the load before is drawn, counted, selected, or
// acted on behind the line that says so.
package flow

import (
	"errors"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/source"
	"github.com/empowerite/kit/projects/tui/internal/table"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// refusedOver gives the picture at a width, issues searched for jig and grouped so that their frozen headings take
// more than one line, the rows with the keyboard and one selected, then loaded again, the load refused.
func refusedOver(t *testing.T, width int) Model {
	t.Helper()
	m := loaded(t, options(), tea.WindowSizeMsg{Width: width, Height: 24})
	p := m.panel(0)
	p.Query = "jig"
	m.setPanel(p.GroupedBy([]string{"source", "organization", "repository", "status", "milestone"}))
	m = intoRows(m)
	if n := table.FrozenLines(&m); n < 2 {
		t.Fatalf("the frozen headings take %d lines at %d columns:\n%s", n, width, view(m))
	}
	m.stages[0].Picked["empowerite/jig#7"] = true
	if m.selected() != 1 {
		t.Fatalf("jig's #7 is not selected: %d rows", m.selected())
	}
	m.restart("issues")
	return drive(m, source.Answer[[]byte]{Name: "issues", Gen: m.find("issues").src.Gen(),
		Err: errors.New("the forge is away")})
}

func TestARefusedReloadDrawsTheRefusalAndNoRowOfTheLoadBefore(t *testing.T) {
	for _, width := range []int{30, 40} {
		m := refusedOver(t, width)
		v := view(m)
		if !strings.Contains(v, "the forge is away") || strings.Contains(v, "Fix the thing") {
			t.Errorf("at %d columns, the refusal over the rows:\n%s", width, v)
		}
		// the heading over the groups stays, on the control line, and nothing under it
		if n := len(keys(m)); n != 0 || len(m.rows(0)) != 1 || !m.controls() || table.FrozenLines(&m) != 0 ||
			m.selected() != 0 {
			t.Errorf("at %d columns, the refused stage gives %d rows under %d headings, %d frozen lines, %d selected",
				width, n, len(m.rows(0))-n, table.FrozenLines(&m), m.selected())
		}
		// the tab's menu selects and copies nothing of the load before, and a key in the rows moves to none
		m = drive(m, press(':'))
		for _, name := range []string{"Select All", "Copy Links", OpenPage} {
			if k := item(m, name); k < 0 || m.enabled(k) {
				t.Errorf("at %d columns, %s over the refusal: line %d, not dim", width, name, k)
			}
		}
		if m = drive(m, esc, down, press(tea.KeySpace), press(tea.KeyPgDown)); m.selected() != 0 {
			t.Errorf("at %d columns, space over the refusal selected %d rows", width, m.selected())
		}
		// the stage loaded again, its rows are back
		m.restart("issues")
		m = drive(m, source.Answer[[]byte]{Name: "issues", Gen: m.find("issues").src.Gen(),
			Value: []byte(`[{"number": 7, "title": "jig again"}]`)})
		if v := view(m); len(m.rows(0)) == 0 || !strings.Contains(v, "jig again") {
			t.Errorf("at %d columns, the stage loaded again:\n%s", width, v)
		}
	}
}

// Rows folded away under the heading over the groups are no more there after a refusal than rows that showed: Select
// All finds none.
func TestARefusedReloadKeepsNoRowFoldedUnderTheHeadingOverTheGroups(t *testing.T) {
	m := loaded(t, options())
	unfold(&m)
	for y, l := range lines(m) {
		if x := strings.Index(l, "▾ 7"); x >= 0 {
			m = drive(m, testkit.Click(ansi.StringWidth(l[:x]), y))
		}
	}
	if !table.FoldedAway(m.rows(0)) || len(m.every(0)) < 2 {
		t.Fatalf("the rows are not folded away: %d of %d\n%s", len(m.rows(0)), len(m.every(0)), view(m))
	}
	m.restart("issues")
	m = drive(m, source.Answer[[]byte]{Name: "issues", Gen: m.find("issues").src.Gen(),
		Err: errors.New("the forge is away")})
	if n := len(m.every(0)); n != 1 || !m.controls() || !strings.Contains(view(m), "the forge is away") {
		t.Errorf("the refused stage holds %d rows, folded or not:\n%s", n, view(m))
	}
	m = drive(m, press(':'))
	if k := item(m, "Select All"); k < 0 || m.enabled(k) {
		t.Errorf("Select All over the refusal: line %d, not dim", k)
	}
}

// What kit kept of only some members of a group is decoded and then left, the stage still loading: it gives no row
// either.
func TestAStageThatLoadsGivesNoRowOfAKeptCopyItLeft(t *testing.T) {
	kept := `{"rows": [{"number": 7, "title": "kept of a", "member": "github.com/o/a"}], "errors": [{"member":
		"github.com/o/b", "error": "kit flow issues has printed nothing here yet; run it without --cached"}]}`
	m := over(t, "issues")
	m = drive(m, source.Answer[[]byte]{Name: "issues", Kept: true, Value: []byte(kept)})
	if s := m.find("issues"); !s.src.Loading || len(s.parsed) != 1 {
		t.Fatalf("the kept copy: loading %v, %d records", s.src.Loading, len(s.parsed))
	}
	if n := len(m.rows(0)); n != 0 || !strings.Contains(view(m), "loading") {
		t.Errorf("a stage that loads gives %d rows:\n%s", n, view(m))
	}
}
