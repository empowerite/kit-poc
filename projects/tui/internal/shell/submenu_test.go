// A menu line that opens a submenu: its > at the right, → . and enter to open it, ← and esc to close one level, a click
// to open it or to choose a line of it, and the submenu's box hung from its parent's line.
package shell

import (
	"slices"
	"strconv"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/style"
)

// cascade is a root of three lines, the second opening a submenu of two, one of which has a key, and the third a line
// that opens nothing; and the owner's Subs for it.
var (
	root    = []Item{{Name: "Plain"}, {Name: "More", Opens: true}, {Name: "Dim", Opens: true}}
	rootOn  = func(k int) bool { return k < 2 }
	subItem = []Item{{Name: "One"}, {Name: "Two", Keys: "T"}}
	subs    = func(path []int) ([]Item, func(int) bool) {
		if slices.Equal(path, []int{1}) {
			return subItem, Every
		}
		return nil, Every
	}
)

func arrowRight() tea.KeyPressMsg { return tea.KeyPressMsg{Code: tea.KeyRight} }
func arrowLeft() tea.KeyPressMsg  { return tea.KeyPressMsg{Code: tea.KeyLeft} }

func TestAnOpensLineEndsInADimGreaterThan(t *testing.T) {
	box, _ := Box(root[:2], Every, -1, "", -1, 80)
	if got := ansi.Strip(box[1]) + ansi.Strip(box[2]); got != "│ Plain   ││ More  > │" {
		t.Errorf("the lines: %q", got)
	}
	if !strings.Contains(box[2], style.Off(" >")) {
		t.Errorf("the > is not dim: %q", box[2])
	}
}

func TestRightDotAndEnterOpenASubmenuAndLeftAndEscCloseIt(t *testing.T) {
	for _, open := range []tea.KeyPressMsg{arrowRight(), {Code: '.', Text: "."}, {Code: tea.KeyEnter}} {
		d, _ := Dropdown{}.Opened(root, rootOn).KeyIn(key("down"), root, rootOn, subs)
		d, chosen := d.KeyIn(open, root, rootOn, subs)
		if chosen != nil || !d.Open || !slices.Equal(d.Path, []int{1}) || d.At != 0 {
			t.Fatalf("%v: chosen %v, open %v, path %v, at %d", open, chosen, d.Open, d.Path, d.At)
		}
		if d, chosen = d.KeyIn(key("down"), root, rootOn, subs); d.At != 1 || chosen != nil {
			t.Fatalf("down in the submenu: at %d", d.At)
		}
		if d, _ = d.KeyIn(arrowLeft(), root, rootOn, subs); len(d.Path) != 0 || d.At != 1 || !d.Open {
			t.Fatalf("left: path %v, at %d, open %v", d.Path, d.At, d.Open)
		}
		d, _ = d.KeyIn(open, root, rootOn, subs)
		if d, _ = d.KeyIn(key("esc"), root, rootOn, subs); len(d.Path) != 0 || !d.Open {
			t.Fatalf("esc in a submenu closed the menu: %v %v", d.Path, d.Open)
		}
		if d, _ = d.KeyIn(key("esc"), root, rootOn, subs); d.Open {
			t.Fatal("esc at the root did not close the menu")
		}
	}
}

func TestEnterChoosesALineOfASubmenuByItsPath(t *testing.T) {
	d, _ := Dropdown{}.Opened(root, rootOn).KeyIn(key("down"), root, rootOn, subs)
	d, _ = d.KeyIn(arrowRight(), root, rootOn, subs)
	d, _ = d.KeyIn(key("down"), root, rootOn, subs)
	if d, chosen := d.KeyIn(key("enter"), root, rootOn, subs); !slices.Equal(chosen, []int{1, 1}) || d.Open ||
		len(d.Path) != 0 {
		t.Errorf("enter on Two: chosen %v, open %v, path %v", chosen, d.Open, d.Path)
	}
	// a line of the root chosen by enter is a path of one
	if _, chosen := (Dropdown{}).Opened(root, rootOn).KeyIn(key("enter"), root, rootOn, subs); !slices.Equal(chosen, []int{0}) {
		t.Errorf("enter on Plain: %v", chosen)
	}
}

func TestRightOnALineWithoutASubmenuDoesNothing(t *testing.T) {
	d := Dropdown{}.Opened(root, rootOn)
	for _, k := range []tea.KeyPressMsg{arrowRight(), {Code: '.', Text: "."}, arrowLeft()} {
		if got, chosen := d.KeyIn(k, root, rootOn, subs); chosen != nil || !got.Open || got.At != 0 || len(got.Path) != 0 {
			t.Errorf("%v on Plain: chosen %v, open %v, at %d", k, chosen, got.Open, got.At)
		}
	}
}

func TestADimOpensLineCannotBeOpenedByKeyOrClick(t *testing.T) {
	d := Dropdown{Open: true, At: 2}
	if got, chosen := d.KeyIn(arrowRight(), root, rootOn, subs); chosen != nil || len(got.Path) != 0 {
		t.Errorf("→ on a dim line: %v %v", chosen, got.Path)
	}
	if got, chosen := d.KeyIn(key("enter"), root, rootOn, subs); chosen != nil || len(got.Path) != 0 {
		t.Errorf("enter on a dim line: %v %v", chosen, got.Path)
	}
	box, left := Box(root, rootOn, 0, "", -1, 80)
	levels := []Level{{Items: root, Enabled: rootOn, Box: Placed{Lines: box, Top: 0, Left: left}}}
	if got, chosen := d.ClickAt(left+2, 3, levels, subs); chosen != nil || len(got.Path) != 0 || !got.Open {
		t.Errorf("a click on a dim line: %v %v open %v", chosen, got.Path, got.Open)
	}
}

func TestAClickOnAnOpensLineOpensItAndOnTheParentWhileOpenClosesTheSubmenu(t *testing.T) {
	box, left := Box(root, rootOn, 0, "", -1, 80)
	rootBox := Placed{Lines: box, Top: 0, Left: left}
	levels := []Level{{Items: root, Enabled: rootOn, Box: rootBox}}
	d := Dropdown{Open: true}
	d, chosen := d.ClickAt(left+2, 2, levels, subs)
	if chosen != nil || !slices.Equal(d.Path, []int{1}) || d.At != 0 {
		t.Fatalf("a click on More: chosen %v, path %v, at %d", chosen, d.Path, d.At)
	}
	sub, _ := SubBox(subItem, Every, d.At, rootBox, 1, 80, 24)
	levels = append(levels, Level{Items: subItem, Enabled: Every, Box: sub})
	// a click on the parent's other line closes the submenu and chooses that line
	if got, chosen := d.ClickAt(left+2, 1, levels, subs); !slices.Equal(chosen, []int{0}) || got.Open {
		t.Errorf("a click on Plain with the submenu open: %v open %v", chosen, got.Open)
	}
	// a click on a line of the submenu chooses it, by its path
	if got, chosen := d.ClickAt(sub.Left+2, sub.Top+2, levels, subs); !slices.Equal(chosen, []int{1, 1}) || got.Open {
		t.Errorf("a click on Two: %v open %v", chosen, got.Open)
	}
	// a click on a submenu's edge does nothing; one off every box closes the menu
	if got, chosen := d.ClickAt(sub.Left, sub.Top, levels, subs); chosen != nil || !got.Open {
		t.Errorf("a click on the edge: %v open %v", chosen, got.Open)
	}
	if got, chosen := d.ClickAt(70, 20, levels, subs); chosen != nil || got.Open || len(got.Path) != 0 {
		t.Errorf("a click off the boxes: %v open %v path %v", chosen, got.Open, got.Path)
	}
}

func TestASubmenuOpensToTheLeftWhereItWouldRunPastTheRoomAndUpWhereItWouldRunPastTheBottom(t *testing.T) {
	box, _ := Box(root, rootOn, 0, "", -1, 80)
	parent := Placed{Lines: box, Top: 3, Left: 10}
	width := ansi.StringWidth(box[0])
	roomy, _ := SubBox(subItem, Every, 0, parent, 1, 80, 24)
	if roomy.Left != 10+width-1 || roomy.Top != 3+1+1 {
		t.Errorf("room to the right: left %d top %d", roomy.Left, roomy.Top)
	}
	cramped, _ := SubBox(subItem, Every, 0, parent, 1, 10+width+3, 24)
	if cw := ansi.StringWidth(cramped.Lines[0]); cramped.Left != 10-cw+1 {
		t.Errorf("no room to the right: left %d", cramped.Left)
	}
	low, _ := SubBox(subItem, Every, 0, parent, 1, 80, 7)
	if low.Top+len(low.Lines) != 7 {
		t.Errorf("no room below: top %d of %d lines in 7", low.Top, len(low.Lines))
	}
	flush, _ := SubBox(subItem, Every, 0, Placed{Lines: box, Top: 0, Left: 0}, 0, 4, 24)
	if flush.Left != 0 {
		t.Errorf("no room either side: left %d", flush.Left)
	}
}

func TestAShortcutAndATypedLetterActInTheDeepestOpenMenu(t *testing.T) {
	d, _ := Dropdown{}.Opened(root, rootOn).KeyIn(key("down"), root, rootOn, subs)
	d, _ = d.KeyIn(arrowRight(), root, rootOn, subs)
	if _, chosen := d.KeyIn(key("t"), root, rootOn, subs); !slices.Equal(chosen, []int{1, 1}) {
		t.Errorf("T, the key of Two: %v", chosen)
	}
	if got, chosen := d.KeyIn(key("o"), root, rootOn, subs); chosen != nil || got.At != 0 {
		t.Errorf("o, the start of One, in the submenu: at %d, chosen %v", got.At, chosen)
	}
}

func TestKeyStaysTheOneLevelFormAndIgnoresOpens(t *testing.T) {
	d, at := Dropdown{}.Opened(root, rootOn).Key(key("enter"), root, rootOn)
	if at != 0 || d.Open {
		t.Errorf("enter: %d, open %v", at, d.Open)
	}
	d, at = Dropdown{Open: true, At: 1}.Key(arrowRight(), root, rootOn)
	if at != -1 || !d.Open || len(d.Path) != 0 {
		t.Errorf("→ with no submenus to give: at %d, path %v", at, d.Path)
	}
}

func TestOpenedAndAClickOffTheBoxesClearThePathOfAMenuClosedByItsOwner(t *testing.T) {
	if d := (Dropdown{Open: true, Path: []int{1}, At: 1}).Opened(root, rootOn); len(d.Path) != 0 || d.At != 0 {
		t.Errorf("reopened: path %v, at %d", d.Path, d.At)
	}
	if d, chosen := (Dropdown{Open: true, Path: []int{1}}).ClickIn(70, 20, 0, 0, 10, 0, 3, root, rootOn); d.Open ||
		len(d.Path) != 0 || chosen != -1 {
		t.Errorf("a click off the box: open %v, path %v", d.Open, d.Path)
	}
}

func TestALineThatOpensASubmenuIsNeverChosenItself(t *testing.T) {
	if d, at := (Dropdown{Open: true, At: 1}).Key(key("enter"), root, rootOn); at != -1 || !d.Open {
		t.Errorf("enter on More with no submenus given: %d, open %v", at, d.Open)
	}
	box, left := Box(root, rootOn, 0, "", -1, 80)
	if d, at := (Dropdown{Open: true}).ClickIn(left+2, 2, 0, left, ansi.StringWidth(box[0]), 0, 3, root, rootOn); at != -1 ||
		!d.Open {
		t.Errorf("a click on More with no submenus given: %d, open %v", at, d.Open)
	}
}

func TestAMenusOwnCloseKeyClosesEveryLevelWhereEscClosesOne(t *testing.T) {
	d, _ := Dropdown{}.Opened(root, rootOn).KeyIn(key("down"), root, rootOn, subs)
	d, _ = d.KeyIn(arrowRight(), root, rootOn, subs)
	if got, _ := d.KeyIn(key("="), root, rootOn, subs, "="); got.Open || len(got.Path) != 0 {
		t.Errorf("= with a submenu open: open %v, path %v", got.Open, got.Path)
	}
}

func TestAClickWithMoreLevelsThanThePathHoldsDoesNotPanic(t *testing.T) {
	box, left := Box(root, rootOn, 0, "", -1, 80)
	rootBox := Placed{Lines: box, Top: 0, Left: left}
	sub, _ := SubBox(subItem, Every, 0, rootBox, 1, 80, 24)
	levels := []Level{{Items: root, Enabled: rootOn, Box: rootBox}, {Items: subItem, Enabled: Every, Box: sub}}
	// the levels are the owner's to keep in step with the path; given more, the click is still taken, as a line of the
	// level it falls on
	if _, chosen := (Dropdown{Open: true}).ClickAt(sub.Left+2, sub.Top+1, levels, subs); chosen == nil {
		t.Error("a click on a submenu the path does not name was not taken")
	}
}

func TestASubmenuTallerThanTheScreenScrollsToTheKeyboard(t *testing.T) {
	tall := make([]Item, 12)
	for k := range tall {
		tall[k].Name = "Line " + strconv.Itoa(k)
	}
	box, _ := Box(root, rootOn, 0, "", -1, 80)
	sub, first := SubBox(tall, Every, 9, Placed{Lines: box, Top: 0, Left: 0}, 1, 80, 8)
	if len(sub.Lines) > 8 || sub.Top < 0 || first <= 0 || !strings.Contains(ansi.Strip(strings.Join(sub.Lines, "\n")), "Line 9") {
		t.Errorf("a tall submenu: %d lines, top %d, first %d", len(sub.Lines), sub.Top, first)
	}
}
