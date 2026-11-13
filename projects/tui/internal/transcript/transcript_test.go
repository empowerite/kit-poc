// What kit tui leaves in the scrollback when it runs a verb: the command line alone.
package transcript

import "testing"

func TestTheTranscriptIsTheCommandLineAlone(t *testing.T) {
	got := Render("", []string{"commit", "--message=#1 tui: the first form", ".gitignore"})
	if want := "kit commit --message='#1 tui: the first form' .gitignore\n"; got != want {
		t.Errorf("transcript %q, want %q", got, want)
	}
	if got := Render("", []string{"version"}); got != "kit version\n" {
		t.Errorf("a verb with no words: %q", got)
	}
}

// A verb that ran in another folder than the one the command was typed in, or over a workspace, says so: the cd to
// the folder first, as kit writes a remedy, and the kit option before the verb.
func TestTheTranscriptSaysTheFolderAndTheWorkspaceTheVerbRanIn(t *testing.T) {
	got := Render("/srv/other repo", []string{"--workspace=core", "flow", "--text"})
	if want := "cd '/srv/other repo' && kit --workspace=core flow --text\n"; got != want {
		t.Errorf("transcript %q, want %q", got, want)
	}
}
