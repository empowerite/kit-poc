package shell

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

// A search wider than the screen keeps the cell the edge keeps, with no left part and no gap that would push it over,
// and one that has the keyboard is cut at its start, so its caret and what was typed last stay in sight.
func TestALongSearchKeepsItsCaretAndTheBarsWidth(t *testing.T) {
	typed := strings.Repeat("abcdefghij", 5)
	bar := MenuBar{Screen: "kit help", On: "x", Search: SearchLine(typed, true)}
	line := bar.Line(40)
	if w := ansi.StringWidth(line); w > 39 || !strings.HasSuffix(ansi.Strip(line), "hij"+caret) {
		t.Errorf("a focused search of %d cells on 40: %d cells, %q", len(typed), w, ansi.Strip(line))
	}
	bar.Search = SearchLine(typed, false)
	line = bar.Line(40)
	if w := ansi.StringWidth(line); w > 39 || !strings.HasPrefix(ansi.Strip(line), Find+" abc") {
		t.Errorf("an unfocused one: %d cells, %q", w, ansi.Strip(line))
	}
	bar.Search = SearchLine("ab", true)
	if line = bar.Line(60); !strings.HasSuffix(ansi.Strip(line), Find+" ab"+caret) || ansi.StringWidth(line) > 59 {
		t.Errorf("a short one stays at its place: %d cells, %q", ansi.StringWidth(line), ansi.Strip(line))
	}
}
