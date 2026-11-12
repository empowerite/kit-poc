package shell

import (
	"slices"
	"testing"
)

// A paste is cut at its line breaks, whichever kind they are; a tab is a space, any other control character is
// dropped, and a blank line is no line. A field of one line types the lines one after another.
func TestAPasteIsItsLinesWithoutControlCharacters(t *testing.T) {
	for _, c := range []struct {
		content string
		lines   []string
		one     string
	}{
		{"#1 a pasted subject", []string{"#1 a pasted subject"}, "#1 a pasted subject"},
		{"git@host:o/r.git\n", []string{"git@host:o/r.git"}, "git@host:o/r.git"},
		{"a\r\nb\rc\n\n \nd", []string{"a", "b", "c", "d"}, "abcd"},
		{"a\tb\x1b[31m\x00\x7fc", []string{"a b[31mc"}, "a b[31mc"},
		{" kept as typed ", []string{" kept as typed "}, " kept as typed "},
		{"\n\r\n", nil, ""},
		{"", nil, ""},
	} {
		if got := PastedLines(c.content); !slices.Equal(got, c.lines) {
			t.Errorf("PastedLines(%q) = %q, not %q", c.content, got, c.lines)
		}
		if got := Pasted(c.content); got != c.one {
			t.Errorf("Pasted(%q) = %q, not %q", c.content, got, c.one)
		}
	}
}
