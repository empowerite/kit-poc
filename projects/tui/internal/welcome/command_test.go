// The command a step's page starts with, under its title, drawn above its checks with ⧉ and ▶️: the command that gives
// them, which kit has already run once, so the first thing the guide teaches about copy and run is on a command whose
// answer is already below it.
package welcome

import (
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/fix"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

const setupCommand = "kit welcome --checks --machine"

// overSetup opens the setup step over the pages the kit package ships; a command handed the terminal is kept, not run.
func overSetup(t *testing.T) (Model, *[]string) {
	t.Helper()
	overShipped(t)
	m, _ := fake(t)
	var handed []string
	m.exec = func(c *exec.Cmd, _, _ string, done tea.ExecCallback) tea.Cmd {
		handed = append(handed, strings.Join(c.Args, " "))
		return func() tea.Msg { return done(nil) }
	}
	return drive(m, append(testkit.Start(m, at120x40), stepKey(setup))...), &handed
}

// Setup's command stands over its checks with its buttons, and says kit has already run it.
func TestSetupsCommandStandsOverItsChecksAndWasRunOnce(t *testing.T) {
	m, _ := overSetup(t)
	got := view(m)
	command := strings.Index(got, setupCommand+"   ⧉   ▶️")
	checks := strings.Index(got, "❌ gh is not logged in")
	if command < 0 || checks < command {
		t.Fatalf("the command is not over the checks, with its buttons:\n%s", got)
	}
	for _, want := range []string{"kit ran it once, as this screen opened", "⧉ copies it, to run in your own shell",
		"▶️ runs it again here"} {
		if !strings.Contains(strings.Join(strings.Fields(got), " "), want) {
			t.Errorf("the guide does not say %q:\n%s", want, got)
		}
	}
	if strings.Count(got, setupCommand) != 1 {
		t.Errorf("the command is drawn more than once:\n%s", got)
	}
}

// While the first answer is out, kit is running it.
func TestTheCommandSaysKitRunsItWhileTheChecksAreOut(t *testing.T) {
	overShipped(t)
	m, _ := fake(t)
	m = drive(m, at120x40, stepKey(setup))
	m, _ = testkit.Drive(m, nil, m.read()())
	if got := view(m); !strings.Contains(got, "kit is running it now") || strings.Contains(got, "kit ran it once") {
		t.Errorf("while the checks are out:\n%s", got)
	}
}

// ⧉ puts the command on the clipboard and says copied until the next key or click; a click beside copied still reads
// where the buttons were drawn.
func TestACommandsCopyPutsItOnTheClipboard(t *testing.T) {
	m, handed := overSetup(t)
	m, msgs := testkit.Drive(m, nil, buttonClick(setupCommand, fix.CopyName).(clickMsg).at(m))
	if m.copied != commandKey || !strings.Contains(view(m), setupCommand+"   copied   ▶️") || len(*handed) != 0 {
		t.Fatalf("copied %q, handed %q:\n%s", m.copied, *handed, view(m))
	}
	if got := clipboard(msgs); got != setupCommand {
		t.Errorf("the clipboard got %q", got)
	}
	if m = drive(m, down); m.copied != "" || strings.Contains(view(m), "copied") {
		t.Errorf("copied stayed past the next key:\n%s", view(m))
	}
	m, handed = overSetup(t)
	if m = drive(m, buttonClick(setupCommand, fix.CopyName), buttonClick(setupCommand, "copied")); m.copied != commandKey {
		t.Errorf("a click on copied: %q", m.copied)
	}
	if drive(m, buttonClick(setupCommand, fix.RunName)); len(*handed) != 1 {
		t.Errorf("a click on ▶️ beside copied handed %q", *handed)
	}
}

// ▶️ hands the terminal to the command, its words with no shell, and reads the checks again when it ends.
func TestACommandsRunHandsItTheTerminalAndReadsTheChecksAgain(t *testing.T) {
	m, handed := overSetup(t)
	calls := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_WELCOME_CALLS", calls)
	m = drive(m, buttonClick(setupCommand, fix.RunName))
	if len(*handed) != 1 || (*handed)[0] != setupCommand {
		t.Fatalf("handed %q", *handed)
	}
	if got := len(readCalls(t, calls)); got != 1 {
		t.Errorf("the checks were read %d times after it ran, want 1: %q", got, readCalls(t, calls))
	}
}

func readCalls(t *testing.T, path string) []string { t.Helper(); return calls(t, path) }

// A click on the command's words, or past its buttons, does nothing.
func TestAClickOnACommandsWordsDoesNothing(t *testing.T) {
	m, handed := overSetup(t)
	for y, l := range strings.Split(view(m), "\n") {
		if strings.Contains(l, setupCommand) {
			if m = drive(m, testkit.Click(8, y)); m.copied != "" || len(*handed) != 0 {
				t.Errorf("a click on its words: copied %q, handed %q", m.copied, *handed)
			}
			return
		}
	}
	t.Fatalf("no command:\n%s", view(m))
}

// A command that asks a shell for more than words offers ⧉ alone, and says nothing of ▶️.
func TestACommandKitCannotRunOffersCopyAlone(t *testing.T) {
	m, _ := fake(t)
	m = drive(m, testkit.Start(m, at120x40)...)
	var text []string
	for _, l := range m.commandLines("kit a | kit b") {
		text = append(text, ansi.Strip(l.text))
	}
	got := strings.Join(text, "\n")
	if !strings.Contains(got, "kit a | kit b   ⧉ ") || strings.Contains(got, fix.RunName) {
		t.Errorf("a command with a pipe:\n%s", got)
	}
}

// splitCommand takes a page's first paragraph when it is one code span alone, and nothing else.
func TestSplitCommandTakesAFirstParagraphThatIsACodeSpanAlone(t *testing.T) {
	for _, c := range []struct{ rest, command, others string }{
		{"\n`kit a b`\n\nWords.\n", "kit a b", "\nWords.\n"},
		{"`kit a b`", "kit a b", ""},
		{"\nWords `kit a`.\n\n`kit b`\n", "", "\nWords `kit a`.\n\n`kit b`\n"},
		{"`kit a` and more\n", "", "`kit a` and more\n"},
		{"`kit a`\nmore words\n", "", "`kit a`\nmore words\n"},
		{"\n\n", "", "\n\n"},
		{"", "", ""},
	} {
		if command, others := splitCommand(c.rest); command != c.command || others != c.others {
			t.Errorf("splitCommand(%q) = %q, %q; want %q, %q", c.rest, command, others, c.command, c.others)
		}
	}
}
