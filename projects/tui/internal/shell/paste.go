// A paste, as the fields that type take it. Bubble Tea leaves bracketed paste on, so a terminal sends a paste whole,
// as tea.PasteMsg, and not as the keys of its text: a field that types a key takes the paste's text too, through
// Pasted or PastedLines, and a screen gives the message to the field a key pressed would be typed in.
package shell

import (
	"strings"
	"unicode"
)

// PastedLines gives the lines a paste types: the paste cut at its line breaks, each tab a space, every other control
// character dropped, and no blank line kept. A paste of line breaks alone gives none.
func PastedLines(content string) []string {
	var lines []string
	for _, line := range strings.FieldsFunc(content, func(r rune) bool { return r == '\n' || r == '\r' }) {
		line = strings.Map(func(r rune) rune {
			switch {
			case r == '\t':
				return ' '
			case unicode.IsControl(r):
				return -1
			}
			return r
		}, line)
		if strings.TrimSpace(line) != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

// Pasted gives a paste as a field of one line types it: its lines, as PastedLines gives them, one after another, the
// line breaks dropped, so a pasted line break never stands for Enter.
func Pasted(content string) string { return strings.Join(PastedLines(content), "") }
