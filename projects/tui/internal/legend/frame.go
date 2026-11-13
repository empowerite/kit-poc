// What every screen draws alike, as parts for a legend: the menu bar's glyphs, the tab bar's, and the table's, where
// the screen says on which of its lines each stands.
package legend

import (
	"strings"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/table"
	"github.com/empowerite/kit/projects/tui/internal/tabs"
)

// MenuBar gives the parts of the menu bar, which every screen draws: the kit menu's glyph, the workspace menu's where
// the screen has one, the crumb's way back, and the search with the past searches.
func MenuBar(on func(y int) bool, workspaces bool) []Part {
	out := []Part{One(shell.App, "kit menu", on)}
	if workspaces {
		out = append(out, One(shell.Workspaces, "workspace menu", on))
	}
	return append(out,
		One(shell.Back, "back: click or ⌫", on),
		One(grid.Search, "search: / or click", on),
		One(shell.Recall, "past searches", on))
}

// Bar says where a tab bar stands: the lines it takes, and those the menu bar shares with the selected tab when a tab
// is maximized.
type Bar struct {
	Tabs, Menu func(y int) bool
}

// Tabs gives the parts of the tab bar: the selected tab's menu, the tabs' numbers, one line for all of them, since the
// selected tab's is the same digit, bold; the arrows that scroll the tabs, and the dot of a tab that is stale. The tab
// menu stands on the bar, or, as the tab is maximized, on the menu bar.
func Tabs(b Bar) []Part {
	var numbers []string
	for i := range 10 {
		numbers = append(numbers, tabs.Marker(i))
	}
	return []Part{
		One(tabs.Menu, "tab menu", func(y int) bool { return b.Tabs(y) || b.Menu(y) }),
		{numbers, "tab: click to select; bold is selected", "", b.Tabs},
		{[]string{tabs.Before, tabs.After}, "more tabs: click to scroll", "", b.Tabs},
		One(tabs.Stale, "stale: click to reload", b.Tabs),
	}
}

// Rows says where a table stands: the screen lines it draws its header on, the control line, the rules, and its rows.
type Rows struct {
	Header, Control, Rule, Rows func(y int) bool
}

// Table gives the parts of a table: the arrows that scroll its columns, the folds of its groups and what a group's
// mark says of its rows, the control line's filter, fields, and presets, and the rule's marks of what the columns
// sort and group by.
func Table(r Rows) []Part {
	return []Part{
		{[]string{grid.Before, grid.After}, "more columns: click to scroll", "", r.Header},
		One(grid.Unfolded, "open: click to close", r.Rows),
		One(grid.Folded, "closed: click to open", r.Rows),
		One("¬", "filtered out", r.Control),
		One(table.Fields, "fields dialog", r.Control),
		One(table.Presets, "presets menu, not a sort", r.Control),
		One(table.Sortable, "sortable: click to sort", r.Rule),
		{strings.Split(grid.RaisedDigits, ""), "ascending, its place: click to reverse", "", r.Rule},
		{strings.Split(grid.LoweredDigits, ""), "descending, its place: click to clear", "", r.Rule},
		One(table.FlattenGlyph, "list: click to flatten", r.Rule),
		One(table.GatherGlyph, "flattened: click to gather", r.Rule),
		One(grid.Chosen, "group selected", r.Rows),
		One(grid.Partly, "group partly selected", r.Rows),
		One(grid.Unchosen, "not selected: click to select", r.Rows),
	}
}

// SheetRows gives where a sheet's table stands on a screen whose last line, the keys bar's, is the line last: the
// control line first in its pane, the rules under the heading over the groups and under the header, and the rows.
func SheetRows(s *table.Sheet, last int) Rows {
	top, _ := s.Pane()
	in := func(y int) bool { return y >= top && y < last }
	rule := func(y int) bool { return in(y) && (table.OnRule(s, y) || s.Controls() && y == top+1) }
	control := func(y int) bool { return s.Controls() && y == top }
	return Rows{
		Header:  func(y int) bool { _, ok := table.HeaderLine(s, y); return in(y) && ok && !rule(y) },
		Control: control,
		Rule:    rule,
		Rows:    in,
	}
}
