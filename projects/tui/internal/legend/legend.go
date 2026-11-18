// The legend: a box that floats over a screen, F1 or ? showing it and hiding it, which says what each glyph the screen
// shows under it means, in the order each first appears, and marks those a click on leads somewhere. Every screen, on
// every tab, holds one, over its own parts: what it says is the screen's, the box and the way it moves are this
// package's. A glyph the screen draws with several meanings is listed once, its meanings under it, one to a line.
//
// It stands in a corner of the rows, the bottom right as it opens; the corners' arrows on its top edge move it to
// another, its own dim, and so do home and end, to the top left and the bottom right, and page up and page down, to the
// corner over and under it. It takes no other key but F1 and ?, and no click but its arrows', so the rows under it go
// on as they were.
package legend

import (
	"cmp"
	"slices"
	"strings"

	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// Corner is where the legend stands: one of the rows' corners. The zero Corner is the bottom right, where it opens.
type Corner int

// The corners.
const (
	BottomRight Corner = iota
	TopLeft
	TopRight
	BottomLeft
)

// order is the corners in the order their arrows stand on the legend's top edge.
var order = []Corner{TopLeft, TopRight, BottomLeft, BottomRight}

// Arrows are the corners' arrows on the legend's top edge, in order's order.
var Arrows = []string{"↖", "↗", "↙", "↘"}

// Legend is the legend while it shows, and the corner it stands in.
type Legend struct {
	Open bool
	At   Corner
}

// Toggle shows the legend, or hides it, where it stands kept.
func (l *Legend) Toggle() { l.Open = !l.Open }

// Key takes a key while the legend shows, and says whether it moved it: home to the top left and end to the bottom
// right, as their arrows do, and page up and page down to the corner over and under it, on its side.
func (l *Legend) Key(k string) bool {
	if !l.Open {
		return false
	}
	right := l.At == TopRight || l.At == BottomRight
	switch {
	case k == "home":
		l.At = TopLeft
	case k == "end":
		l.At = BottomRight
	case k == "pgup" && right:
		l.At = TopRight
	case k == "pgup":
		l.At = TopLeft
	case k == "pgdown" && right:
		l.At = BottomRight
	case k == "pgdown":
		l.At = BottomLeft
	default:
		return false
	}
	return true
}

// Part is a glyph the legend explains where the screen shows it: the glyph, or those that mean the same, as the tabs'
// numbers; what it means; its mark, when a click on it leads somewhere; and the screen lines it means that on, as one
// glyph means one thing on the rule and another on the control line.
type Part struct {
	Glyphs        []string
	Meaning, Mark string
	On            func(y int) bool
}

// One gives the part for a single glyph.
func One(glyph, meaning string, on func(y int) bool) Part {
	return Part{[]string{glyph}, meaning, "", on}
}

// Spec is what a screen says of itself while the legend is drawn: the title of the box; the screen's lines, the last
// the keys bar's, as they are drawn without the legend; the line the rows start on, which the legend keeps under; the
// screen's width and height; and the parts, built for those lines.
type Spec struct {
	Title         string
	Screen        []string
	Top           int
	Width, Height int
	Parts         []Part
}

// found is a part's glyph, where the screen first shows it, and the legend's line for it.
type found struct {
	glyph, meaning string
	y, at          int
}

// Lines gives the legend: every glyph the screen shows under it that the legend can explain, in the order each first
// appears, reading from the top left, each two cells wide, a space, what it means, and its mark when a click on it
// leads somewhere; a glyph with several meanings once, its meanings one to a line, those after the first under it, in
// the order each appears; or, where the screen shows none, a dim line that says so.
func (s Spec) Lines() [][]string {
	var shown []found
	for _, p := range s.Parts {
		first := found{y: -1}
		for y, l := range s.Screen {
			if !p.On(y) {
				continue
			}
			plain := ansi.Strip(l)
			for _, g := range p.Glyphs {
				if at := strings.Index(plain, g); at >= 0 && (first.y < 0 || y < first.y || y == first.y && at < first.at) {
					first = found{g, p.Meaning + marked(p.Mark), y, at}
				}
			}
			if first.y >= 0 {
				break
			}
		}
		if first.y >= 0 {
			shown = append(shown, first)
		}
	}
	slices.SortStableFunc(shown, func(a, b found) int { return cmp.Or(cmp.Compare(a.y, b.y), cmp.Compare(a.at, b.at)) })
	var glyphs []string
	meanings := map[string][]string{}
	for _, f := range shown {
		if !slices.Contains(meanings[f.glyph], f.meaning) {
			if _, again := meanings[f.glyph]; !again {
				glyphs = append(glyphs, f.glyph)
			}
			meanings[f.glyph] = append(meanings[f.glyph], f.meaning)
		}
	}
	var out [][]string
	for _, g := range glyphs {
		group := []string{pane.Pad(g, 2, false) + " " + meanings[g][0]}
		for _, m := range meanings[g][1:] {
			group = append(group, "   "+m)
		}
		out = append(out, group)
	}
	if len(out) == 0 {
		return [][]string{{style.Off("no glyph on the screen")}}
	}
	return out
}

// marked gives a legend's mark after its meaning, dim after a space, or nothing for none.
func marked(mark string) string {
	if mark == "" {
		return ""
	}
	return " " + style.Off(mark)
}

// columned lays a legend's groups out in as few columns as hold them in rows lines, side by side, two cells apart,
// each as wide as its widest line, so a legend taller than the room under the tab bar shows whole. A glyph's meanings
// stay in one column.
func columned(groups [][]string, rows int) []string {
	var lines []string
	for _, g := range groups {
		lines = append(lines, g...)
	}
	if rows < 1 || len(lines) <= rows {
		return lines
	}
	var cols [][]string
	for n := (len(lines) + rows - 1) / rows; ; n++ {
		if cols = packed(groups, (len(lines)+n-1)/n); len(cols) <= n {
			break
		}
	}
	tallest := 0
	for _, part := range cols {
		tallest = max(tallest, len(part))
	}
	out := make([]string, tallest)
	for c, part := range cols {
		width := 0
		for _, l := range part {
			width = max(width, ansi.StringWidth(l))
		}
		for k := range out {
			l := ""
			if k < len(part) {
				l = part[k]
			}
			if c < len(cols)-1 {
				l = pane.Pad(l, width, false) + "  "
			}
			out[k] += l
		}
	}
	return out
}

// packed fills columns with the groups in order, a new column when the next group does not fit in height lines, the
// columns' lines each; a group taller than that stands in a column of its own, so none is cut.
func packed(groups [][]string, height int) [][]string {
	var cols [][]string
	for _, g := range groups {
		if n := len(cols); n == 0 || len(cols[n-1])+len(g) > height {
			cols = append(cols, nil)
		}
		cols[len(cols)-1] = append(cols[len(cols)-1], g...)
	}
	return cols
}

// Box gives the legend's lines, a dialog titled by the screen, the corners' arrows at its top edge's right end, the one
// it stands in dim; and the screen line and column it is drawn from, in its corner of the rows, under the bar and over
// the keys bar.
func (l Legend) Box(s Spec) (lines []string, top, left int) {
	// a blank line, dropped once drawn, wide enough that the title, a dash, and the arrows fit on the top edge
	room := strings.Repeat(" ", ansi.StringWidth(s.Title)+len(Arrows)*2+3)
	lines = shell.Dialog(s.Title, append(columned(s.Lines(), s.Height-1-s.Top-2), room), s.Width)
	width := ansi.StringWidth(lines[0])
	// the arrows, a space before each, on the top edge, a cell short of its right corner
	var buttons []string
	for k, a := range Arrows {
		if order[k] == l.At {
			a = style.Off(a)
		}
		buttons = append(buttons, a)
	}
	lines[0] = shell.Splice(lines[0], " "+strings.Join(buttons, " ")+" ", width-len(Arrows)*2-2)
	lines = append(lines[:len(lines)-2], lines[len(lines)-1])
	top, left = s.Top, 0
	if l.At == TopRight || l.At == BottomRight {
		left = max(0, s.Width-width)
	}
	if l.At == BottomLeft || l.At == BottomRight {
		top = max(s.Top, s.Height-1-len(lines))
	}
	return lines, top, left
}

// Over draws the legend over the screen's lines while it shows, under the menus and dialogs drawn after it.
func (l Legend) Over(lines []string, s Spec) []string {
	if !l.Open {
		return lines
	}
	box, top, left := l.Box(s)
	return shell.Over(lines, box, top, left)
}

// Click takes a click while the legend shows, and says whether it fell on it: on a corner's arrow, the legend moves
// to that corner; anywhere else on it, nothing. A click off it is the screen's.
func (l *Legend) Click(x, y int, s Spec) bool {
	box, top, left := l.Box(s)
	width := ansi.StringWidth(box[0])
	if x < left || x >= left+width || y < top || y >= top+len(box) {
		return false
	}
	if at := x - (left + width - len(Arrows)*2 - 1); y == top && at >= 0 && at%2 == 0 && at/2 < len(Arrows) {
		l.At = order[at/2]
	}
	return true
}
