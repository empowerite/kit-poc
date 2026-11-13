// Enter on a row drops the row's menu down, Open Page first, and an action with nothing selected acts on the row
// under the cursor, from the tab's menu, the row's menu, and its key.
package flow

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/source"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// onRow gives the picture with the keyboard in the rows and the cursor on the selected stage's row of the key.
func onRow(t *testing.T, m Model, key string) Model {
	t.Helper()
	k := slices.IndexFunc(m.rows(m.stage), func(r row) bool { return r.Key == key })
	if k < 0 {
		t.Fatalf("no row %q:\n%s", key, view(m))
	}
	m.inRows, m.inPanel, m.onPreset = true, false, false
	m.stages[m.stage].Cursor = k
	m.fit()
	return m
}

// recording gives the picture loaded at 120×40, nothing selected, recording kit's calls.
func recording(t *testing.T) (Model, string) {
	t.Helper()
	m, record := selecting(t)
	clear(m.stages[0].Picked)
	return m, record
}

// names gives the names of a menu's lines, a rule as nothing.
func names(items []shell.Item) []string {
	var out []string
	for _, i := range items {
		out = append(out, i.Name)
	}
	return out
}

// Enter on a row drops its menu down under the row: its page opened first, under the keyboard, the row selected,
// and, a rule apart, the issues' actions on rows, New… left to the tab's menu. Enter again opens the row's page, and
// the keys bar names enter while the rows have the keyboard.
func TestEnterOnARowDropsItsMenuDownAndEnterAgainOpensItsPage(t *testing.T) {
	m, _ := recording(t)
	m = onRow(t, m, "#46")
	if last := lines(m)[len(lines(m))-1]; !strings.Contains(last, "↑↓ move ⏎ menu ") {
		t.Errorf("the rows' keys do not name enter: %q", last)
	}
	y := rowY(m, "#46")
	m = drive(m, press(tea.KeyEnter))
	want := []string{OpenPage, FollowLink, SelectIt, "", "Start Local Work for Each", "Start Local Work Together…",
		"Add to Pull Request…", "Assign to Me", "Assign to…", "Unassign", "Gather Under a Parent…",
		"Close as Not Planned", "Close as Duplicate of…", "Copy Links"}
	if !m.rowMenu.Open || !slices.Equal(names(m.rowItems()), want) || m.rowMenu.At != 0 {
		t.Fatalf("the row's menu: open %v, on line %d, %q", m.rowMenu.Open, m.rowMenu.At, names(m.rowItems()))
	}
	box, top, left, first := m.rowMenuBox()
	if top != y+1 || left != m.indent(0)+len(lead) || first != 0 || len(box) != len(want)+2 {
		t.Errorf("the menu stands at %d, %d, from line %d, %d lines; the row is on line %d", left, top, first,
			len(box), y)
	}
	if v := lines(m); !strings.Contains(v[y], "#46") || !strings.Contains(v[top], "╭") ||
		!strings.Contains(v[top+1], "🌐 Open Page") || !strings.Contains(v[top+1], " O │") ||
		!strings.Contains(v[len(v)-1], "esc close ↑↓ move ⏎ choose") {
		t.Errorf("the menu as drawn:\n%s", view(m))
	}
	browsed = nil
	if m = drive(m, press(tea.KeyEnter)); m.rowMenu.Open || len(browsed) != 1 ||
		!strings.HasSuffix(browsed[0], "/issues/46") {
		t.Errorf("enter on Open Page: menu open %v, opened %q", m.rowMenu.Open, browsed)
	}
	// esc closes it and does nothing; its keys are its own, so down moves along it and not along the rows
	// #46 has no pull request, so Follow Link is dim and down passes over it to Select
	m = drive(m, press(tea.KeyEnter), down)
	if at := m.stages[0].Cursor; m.rowMenu.At != 2 || m.rows(0)[at].Key != "#46" {
		t.Errorf("down in the menu: on line %d, the cursor on %q", m.rowMenu.At, m.rows(0)[at].Key)
	}
	if m = drive(m, esc); m.rowMenu.Open || !m.inRows || len(browsed) != 1 {
		t.Errorf("esc: menu open %v, in rows %v, opened %q", m.rowMenu.Open, m.inRows, browsed)
	}
	// with the keyboard on the bar there is no row under the cursor, and enter does nothing
	if m = drive(m, esc, press(tea.KeyEnter)); m.rowMenu.Open || m.inRows {
		t.Errorf("enter on the bar: menu open %v, in rows %v", m.rowMenu.Open, m.inRows)
	}
}

// Every tab's rows have the menu, whatever the stage: Open Page and Select, and nothing more where the stage has no
// action of its own.
func TestEveryStagesRowsHaveTheMenu(t *testing.T) {
	for i, name := range five {
		m := loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 40})
		m.stage = i
		m = drive(intoRows(m), press(tea.KeyEnter))
		got := names(m.rowItems())
		// issues lead to their pull requests, so their menu has the line to follow one, which no other stage's has
		want := []string{OpenPage, SelectIt}
		if name == "issues" {
			want = []string{OpenPage, FollowLink, SelectIt}
		}
		if !m.rowMenu.Open || !slices.Equal(got[:min(len(got), len(want))], want) || name != "issues" && len(got) != 2 {
			t.Errorf("%s: the row's menu, open %v: %q", name, m.rowMenu.Open, got)
		}
	}
}

// With nothing selected an action acts on the row under the cursor: its key, the tab's menu, and the row's menu ask
// about that one issue, and o opens its page. On a heading, or with the keyboard on the bar, there is no such row,
// and the actions are dim.
func TestWithNothingSelectedAnActionActsOnTheRowUnderTheCursor(t *testing.T) {
	m, record := recording(t)
	m = onRow(t, m, "#46")
	for name, asking := range map[string]Model{
		"its key":        drive(m, tea.KeyPressMsg{Code: 'a', Text: "a"}),
		"the tab's menu": choose(t, m, "Assign to Me"),
		"the row's menu": drive(m, press(tea.KeyEnter), tea.KeyPressMsg{Code: 'a', Text: "a"}),
	} {
		if asking.ask == nil || asking.ask.title != "Assign this issue to you?" ||
			!slices.Equal(asking.ask.changes, []string{"#46 A noun lists, a noun with a verb acts"}) ||
			asking.rowMenu.Open || asking.tabMenu.Open {
			t.Fatalf("Assign to Me by %s: %+v", name, asking.ask)
		}
	}
	m = drive(m, tea.KeyPressMsg{Code: 'a', Text: "a"}, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"assign #46"}) {
		t.Errorf("the calls: %q", got)
	}
	browsed = nil
	m = drive(m, tea.KeyPressMsg{Code: 'o', Text: "o"})
	if len(browsed) != 1 || !strings.HasSuffix(browsed[0], "/issues/46") {
		t.Errorf("o on the row opened %q", browsed)
	}
	// a heading stands for no one issue, and the bar's keyboard leaves no row under the cursor
	heading := m
	heading.stages[0].Cursor = slices.IndexFunc(m.rows(0), func(r row) bool { return r.Aside })
	for name, without := range map[string]Model{"on a heading": heading, "on the bar": drive(m, esc)} {
		for _, action := range []string{"Assign to Me", "Copy Links", OpenPage} {
			if k := item(without, action); k < 0 || without.enabled(k) {
				t.Errorf("%s, %s: line %d, not dim", name, action, k)
			}
		}
		if got := drive(without, tea.KeyPressMsg{Code: 'a', Text: "a"}); got.ask != nil {
			t.Errorf("%s, a asked: %+v", name, got.ask)
		}
	}
}

// A row's menu acts on its own row where the row is not among those selected, and the others stay selected once kit
// did it; on a row among those selected, it acts on them all, as the tab's menu does, and they are selected no longer.
func TestARowsMenuActsOnItsRowUnlessTheRowIsAmongTheSelected(t *testing.T) {
	m, record := selecting(t)
	m = onRow(t, m, "#31 #12")
	// the row's page is the first its cells lead to
	page := ""
	for _, c := range m.rows(0)[m.stages[0].Cursor].Cells {
		if page == "" && strings.Contains(c.Link, "://") {
			page = c.Link
		}
	}
	browsed = nil
	m = drive(m, press(tea.KeyEnter), press(tea.KeyEnter))
	if !slices.Equal(browsed, []string{page}) {
		t.Errorf("Open Page from the menu of a row not selected opened %q, not %q", browsed, page)
	}
	// the tab's menu, and the key, act on the two selected
	if got := drive(m, tea.KeyPressMsg{Code: 'a', Text: "a"}); got.ask == nil || len(got.ask.changes) != 2 {
		t.Errorf("a with two selected: %+v", got.ask)
	}
	m = drive(m, press(tea.KeyEnter), tea.KeyPressMsg{Code: 'a', Text: "a"})
	if m.ask == nil || len(m.ask.changes) != 1 || !strings.HasPrefix(m.ask.changes[0], "#31 ") {
		t.Fatalf("Assign to Me from the menu of a row not selected: %+v", m.ask)
	}
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"assign #31"}) || m.selected() != 2 {
		t.Errorf("the calls: %q, %d selected", got, m.selected())
	}
	m = onRow(t, m, "#45")
	m = drive(m, press(tea.KeyEnter), tea.KeyPressMsg{Code: 'a', Text: "a"})
	if m.ask == nil || len(m.ask.changes) != 2 {
		t.Fatalf("Assign to Me from the menu of a row among the selected: %+v", m.ask)
	}
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"assign #31", "assign #46 #45"}) || m.selected() != 0 {
		t.Errorf("the calls: %q, %d selected", got, m.selected())
	}
}

// The menu's second line selects the row, and once it is selected, unselects it; on a group's heading it selects
// the group's rows, and on a line about the stage it is dim.
func TestARowsMenuSelectsItsRowAndUnselectsIt(t *testing.T) {
	m, _ := recording(t)
	m = onRow(t, m, "#46")
	pick := func(m Model, name string) Model {
		t.Helper()
		m = drive(m, press(tea.KeyEnter))
		k := slices.Index(names(m.rowItems()), name)
		if k < 0 || !m.rowEnabled(k) {
			t.Fatalf("%s is not in the row's menu, or dim: %q", name, names(m.rowItems()))
		}
		m.rowMenu.At = k
		return drive(m, press(tea.KeyEnter))
	}
	if m = pick(m, SelectIt); m.selected() != 1 || !m.stages[0].Picked["#46"] || m.rowMenu.Open {
		t.Errorf("Select: %d selected", m.selected())
	}
	if m = pick(m, UnselectIt); m.selected() != 0 {
		t.Errorf("Unselect: %d selected", m.selected())
	}
	// a heading's group: the six rows of the five issues of kit
	m.stages[0].Cursor = slices.IndexFunc(m.rows(0), func(r row) bool { return strings.HasSuffix(r.Key, "\x00kit") })
	if m = pick(m, SelectIt); m.selected() != 6 {
		t.Errorf("Select on a heading: %d selected", m.selected())
	}
	if m = pick(m, UnselectIt); m.selected() != 0 {
		t.Errorf("Unselect on a heading: %d selected", m.selected())
	}
}

// Near the pane's bottom the menu stands over its row, and one taller than its room scrolls.
func TestARowsMenuStandsOverARowNearTheBottomAndScrollsWhereItIsTall(t *testing.T) {
	m, _ := recording(t)
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 30})
	m = onRow(t, m, "#45")
	y := rowY(m, "#45")
	m = drive(m, press(tea.KeyEnter))
	box, top, _, first := m.rowMenuBox()
	if under, over := m.height-2-y, y-m.top(); under >= len(m.rowItems())+2 || over <= under {
		t.Fatalf("the row on line %d of %d has %d lines under it and %d over it", y, m.height, under, over)
	}
	if top+len(box) != y || first != 0 {
		t.Errorf("the menu stands on lines %d to %d, from line %d; the row is on line %d:\n%s", top,
			top+len(box)-1, first, y, view(m))
	}
	// a short screen has room for the whole menu on neither side: it scrolls, on the side with more room, between
	// the pane's top and the keys bar
	m = drive(m, esc, tea.WindowSizeMsg{Width: 120, Height: 20})
	for _, key := range []string{"empowerite/jig#7", "#31 #12"} {
		m = onRow(t, m, key)
		y = rowY(m, key)
		m = drive(m, press(tea.KeyEnter))
		m.rowMenu.At = len(m.rowItems()) - 1
		box, top, _, first = m.rowMenuBox()
		under, over := m.height-2-y, y-m.top()
		if len(box) != max(under, over) || first == 0 || !strings.Contains(ansi.Strip(box[0]), "▴") ||
			under >= over && top != y+1 || under < over && top+len(box) != y {
			t.Errorf("the menu of %s, on line %d of %d, stands on lines %d to %d, from line %d:\n%s", key, y,
				m.height, top, top+len(box)-1, first, view(m))
		}
		m = drive(m, esc)
	}
}

// A click on a line of the row's menu chooses it, one on a dim line does nothing, and one anywhere else closes the
// menu; another button does nothing.
func TestARowsMenuTakesAClick(t *testing.T) {
	m, _ := recording(t)
	m = onRow(t, m, "empowerite/jig#7")
	m = drive(m, press(tea.KeyEnter))
	_, top, left, _ := m.rowMenuBox()
	// an issue of another repository: Assign to Me is dim
	dim := slices.Index(names(m.rowItems()), "Assign to Me")
	if m = drive(m, testkit.Click(left+3, top+1+dim)); !m.rowMenu.Open || m.ask != nil {
		t.Errorf("a click on a dim line: menu open %v, asking %v", m.rowMenu.Open, m.ask != nil)
	}
	if m = drive(m, tea.MouseClickMsg{X: left + 3, Y: top + 1 + slices.Index(names(m.rowItems()), SelectIt),
		Button: tea.MouseRight}); !m.rowMenu.Open ||
		m.selected() != 0 {
		t.Errorf("a right click on Select: menu open %v, %d selected", m.rowMenu.Open, m.selected())
	}
	if m = drive(m, testkit.Click(left+3, top+1+slices.Index(names(m.rowItems()), SelectIt))); m.rowMenu.Open ||
		m.selected() != 1 {
		t.Errorf("a click on Select: menu open %v, %d selected", m.rowMenu.Open, m.selected())
	}
	m = drive(m, press(tea.KeyEnter))
	if m = drive(m, testkit.Click(0, 0)); m.rowMenu.Open || m.selected() != 1 {
		t.Errorf("a click off the menu: menu open %v, %d selected", m.rowMenu.Open, m.selected())
	}
}

// A reload that takes the row away closes its menu, which would act on another row.
func TestAReloadThatTakesTheRowAwayClosesItsMenu(t *testing.T) {
	m, _ := recording(t)
	m = onRow(t, m, "#46")
	m = drive(m, press(tea.KeyEnter))
	again := func(doc string) source.Answer[[]byte] {
		m.restart("issues")
		return source.Answer[[]byte]{Name: "issues", Gen: m.find("issues").src.Gen(), Value: []byte(doc)}
	}
	// the row is there still: the menu stays, on it
	if m = drive(m, again(`[{"number": 9, "title": "nine"}, {"number": 46, "title": "A noun lists"}]`)); !m.rowMenu.Open {
		t.Fatalf("a reload that keeps the row closed its menu:\n%s", view(m))
	}
	if m = drive(m, again(`[{"number": 9, "title": "nine"}]`)); m.rowMenu.Open {
		t.Errorf("a reload that takes the row away kept its menu:\n%s", view(m))
	}
	// a load that brings no row leaves none under the cursor: enter drops no menu, and the keys bar names none
	m = drive(m, again(`[]`))
	if _, ok := m.underCursor(); ok || !m.inRows || strings.Contains(m.keys().String(), "⏎ menu") {
		t.Fatalf("after a load of no row: in rows %v, the keys %q", m.inRows, m.keys().String())
	}
	if m = drive(m, press(tea.KeyEnter)); m.rowMenu.Open {
		t.Errorf("enter over no row dropped a menu:\n%s", view(m))
	}
}

// Packages' rows have the menu, with its actions, which act on the package under the cursor.
func TestAPackagesRowsMenuActsOnThePackageUnderTheCursor(t *testing.T) {
	m, record := packaged(t)
	m = onRow(t, m, "agents/cursor")
	m = drive(m, press(tea.KeyEnter))
	if got := names(m.rowItems()); !slices.Equal(got, []string{OpenPage, SelectIt, "", AddPackages, RemovePackages,
		OnlyPackages}) {
		t.Fatalf("the row's menu: %q", got)
	}
	m.rowMenu.At = slices.Index(names(m.rowItems()), AddPackages)
	if m = drive(m, press(tea.KeyEnter)); m.ask == nil || m.ask.title != "Add this package, and the files it delivers?" {
		t.Fatalf("Add from the row's menu: %+v", m.ask)
	}
	drive(m, press(tea.KeyEnter))
	if got := actedOn(t, record); !slices.Equal(got, []string{"packages add agents/cursor"}) {
		t.Errorf("the calls: %q", got)
	}
}

// Follow Link in a row's menu does what a click on the row's link does: an issue's pull request is followed to its
// row under changes. On a row of a stage whose rows lead somewhere that has no link, the line is dim, and a click on
// it does nothing; a stage none of whose rows lead anywhere has no such line.
func TestAFollowLinkLineInARowsMenuLeadsToTheRowsLinkedRow(t *testing.T) {
	m := loaded(t, bare())
	m.apply(m.viewsOf(0).Chosen("Underway"))
	m = drive(intoRows(m), down, press(tea.KeyEnter))
	k := slices.Index(names(m.rowItems()), FollowLink)
	if k < 0 || !m.rowEnabled(k) {
		t.Fatalf("the line: %d, %q", k, names(m.rowItems()))
	}
	m.rowMenu.At = k
	m = drive(m, press(tea.KeyEnter))
	if s := m.stages[m.stage]; s.name != "changes" || !m.inRows || m.rows(m.stage)[s.Cursor].Key != "#4" || m.rowMenu.Open {
		t.Errorf("Follow Link: %s, row %d, menu open %v", s.name, s.Cursor, m.rowMenu.Open)
	}
	// a row with no link: the line is there and dim
	n := loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 40})
	at := slices.IndexFunc(n.rows(0), func(r row) bool { return !r.Aside && !grid.Heads(r) && linkOf(r) == "" })
	if at < 0 {
		t.Fatal("every issue row has a link")
	}
	n.inRows, n.stages[0].Cursor = true, at
	n = drive(n, press(tea.KeyEnter))
	if k := slices.Index(names(n.rowItems()), FollowLink); k < 0 || n.rowEnabled(k) {
		t.Errorf("the line on a row with no link: %d", k)
	}
}
