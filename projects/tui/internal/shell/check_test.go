// The look of a menu's lines: a gutter for a toggle's mark where any line is one, and a glyph, where a line has one,
// inline before its name, with no column kept for it.
package shell

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

// plainBox gives a box's lines without their escapes.
func plainBox(items []Item) []string {
	box, _ := Box(items, Every, -1, "", -1, 80)
	out := make([]string, len(box))
	for k, l := range box {
		out[k] = ansi.Strip(l)
	}
	return out
}

func TestAMenuWithNoGlyphAndNoCheckHasNeitherGutterNorGlyphCell(t *testing.T) {
	got := plainBox([]Item{{Name: "Refresh"}, {Name: "Quit"}})
	if got[0] != "╭─────────╮" || got[1] != "│ Refresh │" || got[2] != "│ Quit    │" {
		t.Errorf("a menu of names alone:\n%s", strings.Join(got, "\n"))
	}
}

func TestALineWithACheckStateDrawsItsMarkInATwoCellGutterAndEveryLineLeavesRoomForIt(t *testing.T) {
	got := plainBox([]Item{{Name: "Watch", Check: Off}, {Name: "Watching", Check: On}, {Name: "All", Check: Mixed},
		{Name: "Other"}})
	want := []string{"│   Watch    │", "│ ✔ Watching │", "│ – All      │", "│   Other    │"}
	if !strings.HasPrefix(got[1], want[0][:3]) || strings.Join(got[1:5], "\n") != strings.Join(want, "\n") {
		t.Errorf("the gutter:\n%s\nwant\n%s", strings.Join(got[1:5], "\n"), strings.Join(want, "\n"))
	}
}

func TestAGlyphIsDrawnInlineBeforeItsNameAndNoColumnIsKeptForIt(t *testing.T) {
	got := plainBox([]Item{{Glyph: "🏠", Name: "Welcome"}, {Name: "Quit"}})
	if got[1] != "│ 🏠 Welcome │" || got[2] != "│ Quit       │" {
		t.Errorf("a glyph inline:\n%s", strings.Join(got, "\n"))
	}
}

func TestEveryLineOfAMenuIsAsWideAsItsWidestWhicheverThatIs(t *testing.T) {
	for _, items := range [][]Item{
		{{Glyph: "🏠", Name: "Go"}, {Name: "A long name with no glyph", Keys: "K"}},
		{{Glyph: "🏠", Name: "A long name with a glyph"}, {Name: "Go", Check: On}},
	} {
		box := plainBox(items)
		for _, l := range box {
			if ansi.StringWidth(l) != ansi.StringWidth(box[0]) {
				t.Errorf("uneven box:\n%s", strings.Join(box, "\n"))
			}
		}
	}
}

func TestNameColIsWhereEachNameStarts(t *testing.T) {
	for _, c := range []struct {
		items []Item
		k, at int
	}{
		{[]Item{{Name: "a"}, {Name: "b"}}, 0, 2},
		{[]Item{{Name: "a", Check: Off}, {Name: "b"}}, 1, 4},
		{[]Item{{Glyph: "🏠", Name: "a"}, {Name: "b"}}, 0, 5},
		{[]Item{{Glyph: "🏠", Name: "a", Check: On}}, 0, 7},
	} {
		if got := NameCol(c.items, c.k); got != c.at {
			t.Errorf("NameCol(%v, %d) = %d, want %d", c.items, c.k, got, c.at)
		}
	}
}
