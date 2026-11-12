package legend

import (
	"slices"
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/table"
)

// everywhere is a part's line predicate that holds for every line.
func everywhere(int) bool { return true }

// onLine gives the predicate that holds for the line y alone.
func onLine(y int) func(int) bool { return func(l int) bool { return l == y } }

// text gives the legend's lines flattened, without escapes, a glyph's meanings each on a line of its own.
func text(s Spec) []string {
	var out []string
	for _, g := range s.Lines() {
		for _, l := range g {
			out = append(out, ansi.Strip(l))
		}
	}
	return out
}

// A glyph the screen draws with several meanings is listed once, its meanings under it, in the order each first
// appears, as X x1 / Y y / X x2 is X x1, three spaces and x2 under it, then Y y; one meaning said twice is said once; and
// a glyph the screen does not show is not listed.
func TestAGlyphWithSeveralMeaningsIsListedOnceItsMeaningsUnderIt(t *testing.T) {
	s := Spec{Screen: []string{"X Y", "  X", "Z"}, Parts: []Part{
		One("X", "x1", onLine(0)), One("Y", "y", onLine(0)), One("X", "x2", onLine(1)), One("X", "x1", onLine(1)),
		One("W", "never", everywhere)}}
	want := []string{"X  x1", "   x2", "Y  y"}
	if got := text(s); !slices.Equal(got, want) {
		t.Errorf("the legend:\n%q\nwant\n%q", got, want)
	}
	if groups := s.Lines(); len(groups) != 2 || len(groups[0]) != 2 || len(groups[1]) != 1 {
		t.Errorf("the groups: %q", groups)
	}
}

// Each glyph stands in the order it first appears, reading from the top left, a part's glyphs found where the first
// of them is; a mark follows its meaning; and a screen that shows none says so.
func TestTheLegendReadsFromTheTopLeftAndMarksWhatAClickLeadsTo(t *testing.T) {
	s := Spec{Screen: []string{"b a", "a"}, Parts: []Part{
		{[]string{"a", "b"}, "the first of them", "🔗", everywhere}, One("a", "second", onLine(1)),
		{[]string{"c"}, "gone", "", everywhere}}}
	if got, want := text(s), []string{"b  the first of them 🔗", "a  second"}; !slices.Equal(got, want) {
		t.Errorf("the legend:\n%q\nwant\n%q", got, want)
	}
	if got := text(Spec{Screen: []string{"nothing"}, Parts: s.Parts}); !slices.Equal(got, []string{"no glyph on the screen"}) {
		t.Errorf("a screen with no glyph: %q", got)
	}
}

// Columns are as few as hold the lines in the rows there are, a glyph's meanings together, so none is cut from its
// glyph; lines that fit are one column, and a group taller than the rows stands in a column of its own.
func TestColumnsKeepAGlyphsMeaningsTogether(t *testing.T) {
	g := func(lines ...string) []string { return lines }
	for _, c := range []struct {
		name   string
		groups [][]string
		rows   int
		want   []string
	}{
		{"it fits", [][]string{g("a"), g("b")}, 5, []string{"a", "b"}},
		{"no room", [][]string{g("a"), g("b")}, 0, []string{"a", "b"}},
		{"even split", [][]string{g("aa"), g("bb"), g("cc"), g("dd")}, 2, []string{"aa  cc", "bb  dd"}},
		{"a group stays whole", [][]string{g("a1", "a2"), g("b"), g("c")}, 2, []string{"a1  b", "a2  c"}},
		{"a group taller than the rows", [][]string{g("a"), g("b1", "b2", "b3"), g("c")}, 2,
			[]string{"a  b1  c", "   b2  ", "   b3  "}},
	} {
		if got := columned(c.groups, c.rows); !slices.Equal(got, c.want) {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
}

// The box is a dialog titled by the screen, the corners' arrows on its top edge, the one it stands in dim; it stands in
// its corner of the rows, under the bar and over the keys bar; and home, end, page up, and page down move it as the arrows
// do, while it shows.
func TestTheBoxStandsInItsCornerAndTheKeysMoveIt(t *testing.T) {
	screen := make([]string, 20)
	for k := range screen {
		screen[k] = strings.Repeat(" ", 40)
	}
	screen[3] = "X"
	s := Spec{Title: "t legend", Screen: screen, Top: 2, Width: 40, Height: 20, Parts: []Part{One("X", "ex", everywhere)}}
	l := Legend{Open: true}
	for _, c := range []struct {
		at        Corner
		top, left int
	}{{TopLeft, 2, 0}, {TopRight, 2, -1}, {BottomLeft, -1, 0}, {BottomRight, -1, -1}} {
		l.At = c.at
		box, top, left := l.Box(s)
		width := ansi.StringWidth(box[0])
		if (c.top >= 0 && top != c.top) || (c.top < 0 && top+len(box) != s.Height-1) ||
			(c.left >= 0 && left != c.left) || (c.left < 0 && left+width != s.Width) {
			t.Errorf("corner %d: top %d, left %d, %d wide, %d high", c.at, top, left, width, len(box))
		}
		if !strings.Contains(ansi.Strip(box[0]), "t legend") || !strings.Contains(box[0], Arrows[0]) {
			t.Errorf("the top edge: %q", box[0])
		}
	}
	// a screen narrower than the box leaves it at the left edge
	if _, _, left := (Legend{At: BottomRight}).Box(Spec{Title: "t", Screen: screen, Width: 5, Height: 20, Parts: s.Parts}); left != 0 {
		t.Errorf("a box wider than the screen: left %d", left)
	}
	for _, c := range []struct {
		from  Corner
		key   string
		want  Corner
		moved bool
	}{
		{BottomRight, "home", TopLeft, true}, {TopLeft, "end", BottomRight, true},
		{BottomRight, "pgup", TopRight, true}, {TopRight, "pgup", TopRight, true},
		{TopRight, "pgdown", BottomRight, true}, {BottomRight, "pgdown", BottomRight, true},
		{BottomLeft, "pgup", TopLeft, true}, {TopLeft, "pgdown", BottomLeft, true},
		{TopLeft, "x", TopLeft, false},
	} {
		l = Legend{Open: true, At: c.from}
		if moved := l.Key(c.key); moved != c.moved || l.At != c.want {
			t.Errorf("%s from %d: moved %v, at %d, want %v, %d", c.key, c.from, moved, l.At, c.moved, c.want)
		}
	}
	if hidden := (Legend{At: BottomRight}); hidden.Key("home") || hidden.At != BottomRight {
		t.Error("home moved the hidden legend")
	}
	hidden := Legend{}
	if hidden.Toggle(); !hidden.Open {
		t.Error("toggle did not show it")
	}
	if hidden.Toggle(); hidden.Open {
		t.Error("toggle did not hide it")
	}
}

// The legend is drawn over the lines while it shows, and not while it is hidden; a click on a corner's arrow moves it
// there, a click elsewhere on it does nothing and is its, and a click off it is the screen's.
func TestTheLegendIsDrawnAndClickedOnlyWhileItShows(t *testing.T) {
	screen := make([]string, 12)
	for k := range screen {
		screen[k] = strings.Repeat(".", 30)
	}
	screen[3] = "X" + screen[3][1:]
	s := Spec{Title: "t legend", Screen: screen, Top: 1, Width: 30, Height: 12, Parts: []Part{One("X", "ex", everywhere)}}
	if got := (Legend{}).Over(screen, s); !slices.Equal(got, screen) {
		t.Error("the hidden legend was drawn")
	}
	l := Legend{Open: true}
	drawn := l.Over(screen, s)
	if !strings.Contains(ansi.Strip(strings.Join(drawn, "\n")), "ex") {
		t.Errorf("the legend is not over the lines:\n%s", strings.Join(drawn, "\n"))
	}
	box, top, left := l.Box(s)
	plain := ansi.Strip(box[0])
	for k, c := range order {
		l.At = BottomRight
		box, top, left = l.Box(s)
		plain = ansi.Strip(box[0])
		x := left + ansi.StringWidth(plain[:strings.Index(plain, Arrows[k])])
		if !l.Click(x, top, s) || l.At != c {
			t.Errorf("the %s arrow: at %d", Arrows[k], l.At)
		}
	}
	l = Legend{Open: true, At: BottomRight}
	box, top, left = l.Box(s)
	if !l.Click(left+1, top+1, s) || l.At != BottomRight {
		t.Errorf("a click on the legend off its arrows: at %d", l.At)
	}
	if l.Click(left-1, top, s) || l.Click(left, top-1, s) || l.Click(left+ansi.StringWidth(box[0]), top, s) ||
		l.Click(left, top+len(box), s) {
		t.Error("a click off the legend was taken")
	}
}

// The frame's parts: the menu bar's, with the workspace menu where the screen has one, the tab bar's, and the table's.
func TestTheFramesPartsAreTheMenuBarsTheTabsAndTheTables(t *testing.T) {
	glyphs := func(parts []Part) []string {
		var out []string
		for _, p := range parts {
			out = append(out, p.Glyphs...)
		}
		return out
	}
	with, without := glyphs(MenuBar(everywhere, true)), glyphs(MenuBar(everywhere, false))
	if len(with) != len(without)+1 || !slices.Contains(with, "-") || slices.Contains(without, "-") {
		t.Errorf("the menu bar's glyphs: %q, %q", with, without)
	}
	bar := Tabs(Bar{Tabs: onLine(1), Menu: onLine(0)})
	if !bar[0].On(0) || !bar[0].On(1) || bar[0].On(2) || bar[1].On(0) || !bar[1].On(1) {
		t.Error("the tab menu stands on the bar and, maximized, on the menu bar; the other tab glyphs on the bar alone")
	}
	if got := Table(Rows{Header: onLine(1), Control: onLine(2), Rule: onLine(3), Rows: onLine(4)}); len(got) != 13 ||
		!got[0].On(1) || !got[3].On(2) || !got[6].On(3) || !got[1].On(4) || !slices.Contains(got[0].Glyphs, grid.Before) {
		t.Errorf("the table's parts: %v", glyphs(got))
	}
	if pane.Before == "" {
		t.Fatal("no scroll glyph")
	}
}

// A sheet's rows: the control line first in its pane, the rules under the heading over the groups and under the header,
// the header between them, and the rows, none above the pane or on the keys bar.
func TestASheetsRowsStandWhereItsPaneDoes(t *testing.T) {
	catalog, err := table.ReadCatalog([]byte(`{"stages": [{"stage": "things", "record": ".[]", "fields": [
		{"id": "name", "label": "name", "type": "text", "path": ".name", "sort": true, "renderings": ["text"],
		 "width": "whole", "placement": "column"}], "presets": [{"name": "Default", "fields": {}}]}]}`))
	if err != nil {
		t.Fatal(err)
	}
	sheet := table.NewSheet(catalog["things"], "things", "", "")
	sheet.SetRecords([]table.Record{{Row: grid.Row{Key: "a"}, Values: map[string]table.Value{"name": table.One("a")}}})
	sheet.Place(2, 10, 80, 14)
	rows := SheetRows(&sheet, 13)
	var control, rule, header, in []int
	for y := range 14 {
		for _, c := range []struct {
			on  func(int) bool
			set *[]int
		}{{rows.Control, &control}, {rows.Rule, &rule}, {rows.Header, &header}, {rows.Rows, &in}} {
			if c.on(y) {
				*c.set = append(*c.set, y)
			}
		}
	}
	if !slices.Equal(control, []int{2}) || len(rule) == 0 || rule[0] < 3 || in[0] != 2 || in[len(in)-1] != 12 {
		t.Errorf("control %v, rule %v, header %v, rows %v", control, rule, header, in)
	}
	for _, y := range header {
		if slices.Contains(rule, y) {
			t.Errorf("line %d is the header and the rule", y)
		}
	}
}
