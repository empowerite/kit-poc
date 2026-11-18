package table

import (
	"slices"
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// A drawing that offers the box draws it, dim, on the row under the cursor alone, a row of the table or a group's
// heading, while that row is not selected; with no row under the cursor, or where the drawing does not offer it, no
// row has it.
func TestADrawingOffersTheBoxOnTheRowUnderTheCursorAlone(t *testing.T) {
	s := sheet("")
	s.FocusRows()
	rows := s.Rows()
	at := func(key string) int { return slices.IndexFunc(rows, func(r grid.Row) bool { return r.Key == key }) }
	heading := slices.IndexFunc(rows, func(r grid.Row) bool { return grid.Heads(r) && !grid.OverGroups(r) })
	if at("apple") < 0 || heading < 0 {
		t.Fatalf("the sheet has no apple, or no heading: %d, %d", at("apple"), heading)
	}
	draw := func(d Drawing, chosen int) []string {
		d.Names, d.Width, d.Pane, d.Open = s.Names(), s.GridWidth(), s.paneWidth(), s.tbl.Open
		var boxed []string
		for _, l := range d.Draw(rows, chosen) {
			if strings.Contains(l.Text, style.Off(grid.Unchosen)) {
				boxed = append(boxed, strings.TrimSpace(ansi.Strip(l.Text)))
			}
		}
		return boxed
	}
	offers := Drawing{Offers: true, Picked: map[string]bool{}}
	if got := draw(offers, at("apple")); len(got) != 1 || !strings.HasPrefix(got[0], grid.Unchosen+"   apple") {
		t.Errorf("the box with the cursor on apple: %q", got)
	}
	if got := draw(offers, heading); len(got) != 1 || !strings.HasPrefix(got[0], grid.Unchosen+" "+grid.Unfolded) {
		t.Errorf("the box with the cursor on a heading: %q", got)
	}
	if got := draw(offers, -1); len(got) != 0 {
		t.Errorf("a box with no row under the cursor: %q", got)
	}
	if got := draw(Drawing{Offers: true, Picked: map[string]bool{"apple": true}}, at("apple")); len(got) != 0 {
		t.Errorf("a box on the selected row under the cursor: %q", got)
	}
	if got := draw(Drawing{Picked: map[string]bool{}}, at("apple")); len(got) != 0 {
		t.Errorf("a box from a drawing that offers none: %q", got)
	}
}
