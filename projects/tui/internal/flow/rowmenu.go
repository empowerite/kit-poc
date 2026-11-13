// A row's menu: what enter drops down from the row under the cursor, so one row is acted on without selecting it
// first. Its lines, top to bottom: the row's page opened; the row selected, or no longer; and, a rule apart, on a
// stage with actions, those the tab's menu lists on rows. A line that cannot act now stays, dim. It hangs under the
// row's first line, or over it where the room under it is too little, and takes the keyboard while it is open, the
// way the tab's menu does: up and down move, a line's key chooses it, enter and space choose the line under the
// keyboard, and esc closes it; a click on a line chooses it, and a click anywhere else closes it.
//
// What an action acts on is the same from the tab's menu, a row's menu, and a key: the rows selected, or, with none
// selected, the row under the cursor. A row's menu acts on its own row alone where that row is not among the
// selected.
package flow

import (
	"slices"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/table"
)

// The menus' lines that act on rows whatever the stage: each row's page opened; and, in a row's menu, the row under
// the cursor selected, or, once it is, no longer.
const (
	OpenPage   = "Open Page"
	SelectIt   = "Select"
	UnselectIt = "Unselect"
)

// rowMenu is the menu of the row under the cursor: the dropdown; the key of the row it was opened on; and the screen
// cell it hangs from, the row's first line and the column it was opened at.
type rowMenu struct {
	shell.Dropdown
	key  string
	x, y int
}

// underCursor gives the row under the cursor, a heading or a line about the stage among them, and whether there is
// one: only while the rows have the keyboard, since the cursor shows only then.
func (m Model) underCursor() (row, bool) {
	if len(m.stages) == 0 || !m.inRows {
		return row{}, false
	}
	rows, k := m.rows(m.stage), m.stages[m.stage].Cursor
	if k < 0 || k >= len(rows) {
		return row{}, false
	}
	return rows[k], true
}

// subjects gives the rows an action acts on: the rows selected; or, with none selected, the row under the cursor,
// where it is a row of the table and no heading. From a row's menu they are that row alone, unless it is among the
// selected, which are then acted on together.
func (m Model) subjects() []row {
	picked := m.selectedRows()
	under, ok := m.underCursor()
	if !ok || under.Aside {
		return picked
	}
	among := slices.ContainsFunc(picked, func(r row) bool { return r.Key == under.Key })
	if len(picked) > 0 && (among || !m.rowMenu.Open) {
		return picked
	}
	return []row{under}
}

// subjectKeys gives the keys of the rows an action acts on, which are no longer selected once kit did it.
func (m Model) subjectKeys() []string {
	var keys []string
	for _, r := range m.subjects() {
		keys = append(keys, r.Key)
	}
	return keys
}

// selects says whether space selects the row under the cursor, or unselects it: a row of the table, or a group's
// heading, which stands for its rows.
func (m Model) selects() bool {
	r, ok := m.underCursor()
	return ok && (grid.Heads(r) || !r.Aside)
}

// selectItem gives the row's menu's line that selects the row under the cursor, or, where the row is selected, or
// every row of the heading's group is, the line that unselects it.
func (m Model) selectItem() shell.Item {
	if r, ok := m.underCursor(); ok {
		s := m.stages[m.stage]
		if s.Picked[r.Key] && !r.Aside || table.GroupMarks(m.every(m.stage), s.Picked)[r.Key] == grid.Chosen {
			return shell.Item{Glyph: Sweep, Name: UnselectIt}
		}
	}
	return shell.Item{Glyph: Checked, Name: SelectIt}
}

// rowItems gives the lines of the menu of the row under the cursor: its page opened; the row selected, or no
// longer; and, a rule apart, the stage's actions on rows, where it has some. New…, which acts on no row, is the
// tab's menu's alone.
func (m Model) rowItems() []shell.Item {
	items := []shell.Item{{Glyph: Browse, Name: OpenPage, Keys: "O"}, m.selectItem()}
	actions := slices.DeleteFunc(m.actions(), func(i shell.Item) bool { return i.Name == "New…" })
	if len(actions) > 0 {
		items = append(append(items, shell.Item{}), actions...)
	}
	return items
}

// rowEnabled says whether the row's menu's line k does something now.
func (m Model) rowEnabled(k int) bool { return m.acts(m.rowItems()[k].Name) }

// openRowMenu drops the menu of the row under the cursor down, its first line that acts under the keyboard; it does
// nothing where no row is under the cursor. The pane is scrolled to the row first, and the menu hangs from the row's
// first line, at the screen column x, or at the row's first cell where x is negative. On issues it asks kit for the
// caller's login the first time, which Add to Pull Request needs.
func (m *Model) openRowMenu(x int) tea.Cmd {
	under, ok := m.underCursor()
	if !ok {
		return nil
	}
	m.fit()
	if x < 0 {
		x = m.indent(m.stage) + len(lead)
	}
	lines, k := m.allLines(m.stage), m.stages[m.stage].Cursor
	_, places := m.laid()
	y := m.rowsTop()
	for r, at := range places {
		if at >= 0 && lines[at].Row == k {
			y += r
			break
		}
	}
	m.rowMenu = rowMenu{Dropdown: shell.Dropdown{Open: true}, key: under.Key, x: x, y: y}
	m.rowMenu.Dropdown = m.rowMenu.Opened(m.rowItems(), m.rowEnabled)
	if m.stages[m.stage].name != issuesStage {
		return nil
	}
	return m.askMe()
}

// rowMenuKey takes a key while a row's menu is open, the way a dropdown does, and does what the line chosen says. A
// line chosen leaves the menu open until do has read what the line acts on, and do closes it.
func (m Model) rowMenuKey(k tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	next, chosen := m.rowMenu.Key(k, m.rowItems(), m.rowEnabled)
	if chosen >= 0 {
		return m, m.do(m.rowItems()[chosen].Name)
	}
	m.rowMenu.Dropdown = next
	return m, nil
}

// rowMenuBox gives the row's menu's lines, the screen line of its top edge, the column of its left edge, and the
// first line it shows. It stands under the row it hangs from; where the lines under the row, down to the keys bar,
// are fewer than it takes and the lines over the row are more, it stands over the row. Its left edge is at the
// column it was opened at, or as near as the pane's width lets it be. A menu taller than its room scrolls.
func (m Model) rowMenuBox() (lines []string, top, left, first int) {
	items := m.rowItems()
	under, over := m.height-2-m.rowMenu.y, m.rowMenu.y-m.top()
	room := under
	if len(items)+2 > under && over > under {
		room = over
	}
	lines, _, first = shell.BoxIn(items, m.rowEnabled, m.rowMenu.At, "", -1, m.paneWidth(), max(3, room))
	left = max(0, min(m.rowMenu.x, m.paneWidth()-ansi.StringWidth(lines[0])))
	if room == under {
		return lines, m.rowMenu.y + 1, left, first
	}
	return lines, m.rowMenu.y - len(lines), left, first
}

// rowMenuClick takes a left click while a row's menu is open: on a line it shows, it chooses it, and on one that
// cannot act it does nothing; anywhere else, it closes the menu. A line chosen leaves the menu open until do has
// read what the line acts on, as rowMenuKey says.
func (m *Model) rowMenuClick(x, y int) tea.Cmd {
	box, top, left, first := m.rowMenuBox()
	next, chosen := m.rowMenu.ClickIn(x, y, top, left, ansi.StringWidth(box[0]), first, len(box)-2, m.rowItems(),
		m.rowEnabled)
	if chosen >= 0 {
		return m.do(m.rowItems()[chosen].Name)
	}
	m.rowMenu.Dropdown = next
	return nil
}
