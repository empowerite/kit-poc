// A paste, as the dialog types it. A terminal sends a paste whole, and not as the keys of its text, so the dialog
// takes a paste's text, as shell.Pasted gives it, where it types a key.
package opener

import "strings"

// Paste types a paste, as Key types a key: over the clones, where their table types, a card's line or a preset's
// name, and nowhere under the groups' dropdown; else after what is typed, kit's lines gone, the highlight back on
// what is typed and the folders back in place of the clones. A paste that starts with / or ~ is a whole path, which
// can mean nothing after what is typed, ~/ as the dialog opens, so it takes the place of what is typed. A paste of
// nothing changes nothing.
func (d Dialog) Paste(text string) Dialog {
	if text == "" || d.found != nil && (d.adding.Open || d.table.Paste(text)) {
		return d
	}
	if strings.HasPrefix(text, "/") || strings.HasPrefix(text, "~") {
		return d.typing(text)
	}
	return d.typing(d.Typed + text)
}
