// A plain click acts on a row: on the box in its gutter it selects the row, on the row under the cursor it drops the
// row's menu down where the click fell, and elsewhere it moves the cursor, so every action on rows has a path by
// plain clicks alone.
package flow

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/style"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// A click on the box in a row's gutter, either of its two cells, selects the row and puts the cursor on it, and a
// second unselects it; the control line counts it. A click on a heading's box selects its group. A click on the rest
// of a row selects nothing.
func TestAClickOnARowsBoxSelectsIt(t *testing.T) {
	m, _ := recording(t)
	y, box := rowY(m, "#46"), m.indent(0)
	for _, x := range []int{box, box + 1} {
		got := drive(m, testkit.Click(x, y))
		if at := got.stages[0].Cursor; got.selected() != 1 || !got.stages[0].Picked["#46"] || !got.inRows ||
			got.rows(0)[at].Key != "#46" || got.rowMenu.Open {
			t.Fatalf("a click on #46's box at %d: %d selected, in rows %v, cursor on %q", x, got.selected(),
				got.inRows, got.rows(0)[at].Key)
		}
		if line := lines(got)[got.top()]; !strings.Contains(line, "1 selected") {
			t.Errorf("the control line after the click: %q", line)
		}
		if got = drive(got, testkit.Click(x, y)); got.selected() != 0 || got.rowMenu.Open {
			t.Errorf("a second click on the box at %d: %d selected, menu %v", x, got.selected(), got.rowMenu.Open)
		}
	}
	// the cell before the box, the fold's after it, and the row's text
	for _, x := range []int{box - 1, box + 2, box + 12} {
		if got := drive(m, testkit.Click(x, y)); got.selected() != 0 {
			t.Errorf("a click at %d, beside #46's box, selected %d", x, got.selected())
		}
	}
	// kit's heading: its box stands two cells before its ▾
	k := slices.IndexFunc(m.rows(0), func(r row) bool { return strings.HasSuffix(r.Key, "\x00kit") })
	hy := m.rowLine(k)
	hx := ansi.StringWidth(strings.SplitN(lines(m)[hy], grid.Unfolded, 2)[0]) - 2
	if got := drive(m, testkit.Click(hx, hy)); got.selected() != 6 || got.stages[0].Cursor != k {
		t.Errorf("a click on kit's heading's box at %d: %d selected, cursor %d of %d:\n%s", hx, got.selected(),
			got.stages[0].Cursor, k, view(got))
	}
}

// Every tab's rows take the click, whatever the stage.
func TestEveryStagesRowsTakeAClickOnTheirBox(t *testing.T) {
	for i, name := range five {
		m := loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 40})
		m.stage = i
		m = intoRows(m)
		y := m.rowLine(m.stages[i].Cursor)
		if m = drive(m, esc, testkit.Click(m.indent(i), y)); m.selected() != 1 || !m.inRows {
			t.Errorf("%s: a click on a row's box selected %d, in rows %v", name, m.selected(), m.inRows)
		}
	}
}

// The row under the cursor draws the box, dim, so the gutter shows where a click selects: a row of the table, or a
// group's heading, and no other row; once the row is selected, its mark stands there instead.
func TestTheRowUnderTheCursorOffersItsBox(t *testing.T) {
	m, _ := recording(t)
	m = onRow(t, m, "#46")
	dim := style.Off(grid.Unchosen)
	if v := m.View().Content; strings.Count(v, dim) != 1 || !strings.Contains(cursor(m), "#46") ||
		!strings.Contains(lines(m)[rowY(m, "#46")], grid.Unchosen+" "+grid.Folded+" #46") {
		t.Errorf("the box on the cursor's row, %d on the screen:\n%s", strings.Count(v, dim), view(m))
	}
	if m = drive(m, press(tea.KeySpace)); strings.Contains(m.View().Content, dim) ||
		!strings.Contains(lines(m)[rowY(m, "#46")], grid.Chosen+" "+grid.Folded+" #46") {
		t.Errorf("the selected row under the cursor:\n%s", view(m))
	}
	m = drive(m, press(tea.KeySpace))
	k := slices.IndexFunc(m.rows(0), func(r row) bool { return strings.HasSuffix(r.Key, "\x00kit") })
	m.stages[0].Cursor = k
	if v := m.View().Content; strings.Count(v, dim) != 1 ||
		!strings.Contains(lines(m)[m.rowLine(k)], grid.Unchosen+" "+grid.Unfolded+" kit") {
		t.Errorf("the box on the heading under the cursor:\n%s", view(m))
	}
	// with the keyboard on the bar no row is under the cursor, and none draws the box
	if m = drive(m, esc); strings.Contains(m.View().Content, dim) {
		t.Errorf("a box with the keyboard on the bar:\n%s", view(m))
	}
	// the legend names it while it shows
	m = onRow(t, m, "#46")
	if m = drive(m, press('?')); !strings.Contains(view(m), grid.Unchosen+"  not selected: click to select") {
		t.Errorf("the legend does not name the box:\n%s", view(m))
	}
}

// A click on a row moves the cursor there, and a click on the row under the cursor drops its menu down from the
// row, at the click; plain clicks alone then choose an action and answer its dialog, so kit runs with no key
// pressed. Near the pane's right edge the menu stands as far right as it fits.
func TestAClickOnTheRowUnderTheCursorDropsItsMenuDownAtTheClick(t *testing.T) {
	m, record := recording(t)
	y := rowY(m, "#46")
	m = drive(m, testkit.Click(40, y))
	if at := m.stages[0].Cursor; !m.inRows || m.rows(0)[at].Key != "#46" || m.rowMenu.Open || m.selected() != 0 {
		t.Fatalf("a click on #46: in rows %v, cursor on %q, menu %v, %d selected", m.inRows, m.rows(0)[at].Key,
			m.rowMenu.Open, m.selected())
	}
	m = drive(m, testkit.Click(40, y))
	_, top, left, _ := m.rowMenuBox()
	if !m.rowMenu.Open || left != 40 || top != y+1 {
		t.Fatalf("a second click on #46: menu %v, at %d, %d; the row is on line %d", m.rowMenu.Open, left, top, y)
	}
	x, line := drawnAt(t, m, "Assign to Me")
	if m = drive(m, testkit.Click(x, line)); m.ask == nil || m.rowMenu.Open ||
		!slices.Equal(m.ask.changes, []string{"#46 A noun lists, a noun with a verb acts"}) {
		t.Fatalf("a click on Assign to Me in the row's menu: %+v", m.ask)
	}
	x, line = drawnAt(t, m, "⏎ Assign")
	m = drive(m, testkit.Click(x, line))
	if got := acted(t, record); !slices.Equal(got, []string{"assign #46"}) {
		t.Errorf("the calls: %q", got)
	}
	// a click at the pane's right end: the menu's right edge is the pane's
	m = drive(m, testkit.Click(m.paneWidth()-2, y))
	box, _, left, _ := m.rowMenuBox()
	if !m.rowMenu.Open || left+ansi.StringWidth(box[0]) != m.paneWidth() {
		t.Errorf("the menu from a click at the right end: open %v, columns %d to %d of %d", m.rowMenu.Open, left,
			left+ansi.StringWidth(box[0]), m.paneWidth())
	}
	// a click off it closes it, and moves no cursor
	if m = drive(m, testkit.Click(40, rowY(m, "#45"))); m.rowMenu.Open || m.rows(0)[m.stages[0].Cursor].Key != "#46" {
		t.Errorf("a click off the menu: open %v, cursor on %q", m.rowMenu.Open, m.rows(0)[m.stages[0].Cursor].Key)
	}
}
