// The styles draw their text whole, each with its own escapes, and the keys bar fits its line and ends the screen.
package style

import (
	"bytes"
	"slices"
	"strings"
	"testing"

	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/ansi"
)

// Each style keeps its text as it is, and only adds the escapes that draw it; two styles draw it differently.
func TestEveryStyleDrawsItsTextWholeAndInItsOwnWay(t *testing.T) {
	styles := map[string]func(string) string{"Mark": Mark, "Gain": Gain, "Loss": Loss, "Warn": Warn, "Repo": Repo,
		"Chosen": Chosen, "Menu": Menu, "Off": Off, "Label": Label, "Cursor": Cursor, "Refusal": Refusal,
		"Selected": Selected, "Link": Link, "Text": Text, "Literal": Literal}
	drawn := map[string]string{}
	for name, draw := range styles {
		got := draw("kit 🏭")
		if ansi.Strip(got) != "kit 🏭" {
			t.Errorf("%s changes the text: %q", name, ansi.Strip(got))
		}
		for other, before := range drawn {
			if got == before && other != name {
				t.Errorf("%s and %s draw alike: %q", name, other, got)
			}
		}
		drawn[name] = got
	}
}

// The line under the keyboard in a menu or a dialog drops its own styles, so a dim glyph in it leaves no hole in the
// bar, and stands on the menu's bright cyan, 14, in black, 16: reverse video, 7, with the cyan as the text's color and
// the black as its ground, which a terminal of colors draws as black on cyan.
func TestTheLineSelectedInAMenuStandsOnTheMenusColor(t *testing.T) {
	got := Selected(Off("⦾") + " off")
	if got != "\x1b[7;96;48;5;16m⦾ off\x1b[m" {
		t.Errorf("selected: %q", got)
	}
}

// uncolored gives a text as a terminal of no color is sent it, as under NO_COLOR: the program writes through the
// terminal's profile, which drops the colors and keeps the rest.
func uncolored(t *testing.T, text string) string {
	t.Helper()
	var b bytes.Buffer
	if _, err := (&colorprofile.Writer{Forward: &b, Profile: colorprofile.ASCII}).Write([]byte(text)); err != nil {
		t.Fatal(err)
	}
	return b.String()
}

// A terminal of no color is sent the line under the keyboard in reverse video, in a menu's own color or a group's,
// bold too on the line of where the menu is, though it is told nothing of the terminal.
func TestTheLineSelectedIsReverseVideoWithNoColor(t *testing.T) {
	_, under := MenuIn("114")
	for name, c := range map[string]struct{ got, want string }{
		"Selected":        {Selected(Off("⦾") + " off"), "\x1b[7m⦾ off\x1b[m"},
		"MenuIn":          {under("Save"), "\x1b[7mSave\x1b[m"},
		"MenuHereIn":      {MenuHereIn("")("Flow"), "\x1b[1;7mFlow\x1b[m"},
		"MenuHereIn(114)": {MenuHereIn("114")("Flow"), "\x1b[1;7mFlow\x1b[m"},
	} {
		if got := uncolored(t, c.got); got != c.want {
			t.Errorf("%s with no color: %q, want %q", name, got, c.want)
		}
	}
}

// Told the terminal has no color, as under NO_COLOR or with TERM=dumb, the band is reverse video, opened again after
// each style in the line ends, and the look is another; told it has colors again, the band is the faint background.
func TestTheBandIsReverseVideoOnATerminalOfNoColor(t *testing.T) {
	t.Cleanup(func() { Profile(colorprofile.TrueColor) })
	line := "#45 " + Off("2h") + " title"
	faint, look := Band(line, 20), Look()
	for _, p := range []colorprofile.Profile{colorprofile.ASCII, colorprofile.NoTTY} {
		Profile(p)
		got := Band(line, 20)
		if got != "\x1b[7m#45 \x1b[2m2h\x1b[m\x1b[7m title        \x1b[m" || uncolored(t, got) != got {
			t.Errorf("the band at %s: %q", p, got)
		}
		if Look() == look {
			t.Errorf("the look at %s is the look with colors: %q", p, look)
		}
	}
	for _, p := range []colorprofile.Profile{colorprofile.ANSI, colorprofile.ANSI256, colorprofile.TrueColor} {
		if Profile(p); Band(line, 20) != faint || Look() != look {
			t.Errorf("the band at %s: %q", p, Band(line, 20))
		}
	}
}

// A menu in a group's color draws its edges and the line under the keyboard in that color, the text kept; no color
// draws them as the menu's own.
func TestAMenuInAGroupsColorDrawsInIt(t *testing.T) {
	edge, under := MenuIn("114")
	if ansi.Strip(edge("╭─╮")) != "╭─╮" || edge("╭─╮") == Menu("╭─╮") || ansi.Strip(under(Off("Save"))) != "Save" ||
		under("Save") == Selected("Save") || under(Off("Save")) != under("Save") {
		t.Errorf("in 114: %q, %q", edge("╭─╮"), under(Off("Save")))
	}
	if own, sel := MenuIn(""); own("╭─╮") != Menu("╭─╮") || sel("Save") != Selected("Save") {
		t.Error("no color is not the menu's own")
	}
}

// A band keeps the line's text and styles, pads it to the width, and opens the band again after each style ends.
func TestABandRunsTheWholeLine(t *testing.T) {
	line := "#45 " + Off("2h") + " title"
	got := Band(line, 20)
	if ansi.Strip(got) != "#45 2h title        " {
		t.Errorf("the band's text: %q", ansi.Strip(got))
	}
	open, _, _ := strings.Cut(band.Render("x"), "x")
	if !strings.Contains(got, "\x1b[m"+open+" title") || !strings.Contains(got, Off("2h")) {
		t.Errorf("the band does not run past the dim age: %q", got)
	}
}

// The bar is one dim line after a space, clipped to the width with …, and nothing at all on a screen of one column.
// A key on the keys bar and what it does are drawn brighter in the control the keyboard is in than in the controls
// around it, and say the same either way.
func TestTheBarsKeysAreBrighterWhereTheKeyboardIs(t *testing.T) {
	for name, draw := range map[string]func(string, bool) string{"key": BarKey, "does": BarDoes} {
		if here, around := draw("move", true), draw("move", false); here == around || ansi.Strip(here) != "move" ||
			ansi.Strip(around) != "move" {
			t.Errorf("the %s: %q where the keyboard is, %q around it", name, here, around)
		}
	}
	if BarDoes("move", false) != Off("move") || ansi.Strip(BarRule(" │ ")) != " │ " {
		t.Error("what a key does around the keyboard is not dim, or the rule says something else")
	}
}

// The bar is the last line of a screen of any height: the lines above are cut or padded to the rest, and a height not
// yet known draws them all, a gap, and the bar.
func TestTheBarIsTheLastLineOfTheScreen(t *testing.T) {
	lines := []string{"a", "b", "c"}
	for _, c := range []struct {
		height int
		want   []string
	}{
		{5, []string{"a", "b", "c", "", "bar"}},
		{3, []string{"a", "b", "bar"}},
		{1, []string{"bar"}},
		{0, []string{"a", "b", "c", "", "bar"}},
	} {
		if got := Bottom(slices.Clone(lines), c.height, "bar"); !slices.Equal(got, c.want) {
			t.Errorf("Bottom at %d = %q, want %q", c.height, got, c.want)
		}
	}
}

func TestATintIsNotBold(t *testing.T) {
	if got := Tint("x"); strings.Contains(got, "1;") {
		t.Errorf("a tint is bold: %q", got)
	}
}

// In gives the mark and the tint in a color of their own, and the accent's for none.
func TestInDrawsAGroupsColor(t *testing.T) {
	if m, ti := In(""); m("x") != Mark("x") || ti("x") != Tint("x") {
		t.Error("no color is not the accent")
	}
	if m, ti := In("75"); m("x") == Mark("x") || ti("x") == Tint("x") || m("x") == ti("x") || ansi.Strip(m("x")) != "x" {
		t.Errorf("a color: %q %q", m("x"), ti("x"))
	}
}

func TestTheMenusLineForWhereItIsIsTheBarBold(t *testing.T) {
	if MenuHereIn("")("x") == Selected("x") || ansi.Strip(MenuHereIn("")("\x1b[1mx\x1b[0m")) != "x" ||
		!strings.Contains(MenuHereIn("114")("x"), "7;38;5;114;48;5;16") {
		t.Errorf("here: %q, colored %q", MenuHereIn("")("x"), MenuHereIn("114")("x"))
	}
}
