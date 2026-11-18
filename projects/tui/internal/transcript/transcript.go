// Package transcript writes what kit tui leaves in the scrollback when it runs a verb: the command line it built,
// quoted as a shell needs it, so the verb's own output follows the command that made it.
package transcript

import (
	"github.com/empowerite/kit/projects/tui/internal/fix"
	"github.com/empowerite/kit/projects/tui/internal/form"
)

// Render gives the transcript of a form that ran kit <words>…: the command line alone, on one line, after the cd to
// the folder it ran in where that is another than the one the command was typed in, as kit writes a remedy; no folder
// says it ran where it was typed.
func Render(folder string, words []string) string {
	return fix.In(folder, "kit "+form.Quote(words)) + "\n"
}
