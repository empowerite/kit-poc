// How a step with checks is laid out: its page's title, its checks, then the rest of its page, which the keyboard
// reaches past the last row; and, where the checks are a table, the rest of the page under the table where the table
// leaves it room.
package welcome

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// inOrder says whether each text is on the screen after the one before it.
func inOrder(screen string, texts ...string) bool {
	at := 0
	for _, text := range texts {
		k := strings.Index(screen[at:], text)
		if k < 0 {
			return false
		}
		at += k + len(text)
	}
	return true
}

func TestAStepWithChecksDrawsItsTitleItsChecksThenTheRestOfItsPage(t *testing.T) {
	m, _ := loaded(t, stepKey(chains))
	if v := view(m); !inOrder(v, "   Toolchains\n\n", "✅ bash 5.2 runs kit", "add it to your shell profile to keep it\n\n",
		"   A toolchain installs tools. When several are usable, choose one.\n") {
		t.Errorf("the toolchains:\n%s", v)
	}
	m = drive(m, stepKey(setup))
	if v := view(m); !inOrder(v, "   Setup — this machine's logins and terminal\n\n", "❌ gh is not logged in",
		"read: kit help check\n\n", "   Each line is a check.") {
		t.Errorf("setup:\n%s", v)
	}
}

// A page's title is the `# ` heading it starts with, after its comments and blank lines. A page that starts with
// anything else has none: its step starts with its checks, and all of the page stands under them.
func TestAPageWithNoTitleStandsUnderItsChecks(t *testing.T) {
	for page, want := range map[string][]string{
		"<!-- a comment\nof two lines -->\n\n# Toolchains — tools\n\nThe rest.\n": {"   Toolchains — tools\n\n", "✅ bash 5.2 runs kit", "\n\n   The rest.\n"},
		"No title here.\n\n# Later — a heading\n":                                 {"   ✅ bash 5.2 runs kit", "\n\n   No title here.\n\n   Later — a heading\n"},
		"# Toolchains — the title alone\n":                                        {"   Toolchains — the title alone\n\n", "✅ bash 5.2 runs kit"},
	} {
		m, _ := fake(t)
		m.runner = pagesWith(t, map[string]string{"2-toolchains.md": page})
		m = drive(m, testkit.Start(m, at120)...)
		v := view(m)
		pane := strings.Join(strings.Split(v, "\n")[m.paneTop():], "\n")
		if !strings.HasPrefix(pane, want[0]) || !inOrder(pane, want...) {
			t.Errorf("%q is drawn:\n%s", page, v)
		}
	}
}

// On a step's last row, down, page down, and end scroll on to the rest of the page, the cursor where it was; the pane
// stays there until a key moves the cursor, and up brings the rows back.
func TestPastAStepsLastRowTheKeysScrollToTheRestOfItsPage(t *testing.T) {
	overShipped(t)
	m, _ := fake(t)
	m = drive(m, append(testkit.Start(m, at80), stepKey(chains), down, press(tea.KeyEnd))...)
	last, end := m.rows(m.step), "docs/toolchains.md"
	if m.cursor != last[len(last)-1] || !m.inPane || strings.Contains(view(m), end) {
		t.Fatalf("end: cursor %d, in the pane %v:\n%s", m.cursor, m.inPane, view(m))
	}
	before := m.offsets[m.step]
	if m = drive(m, down); m.offsets[m.step] != before+1 || m.cursor != last[len(last)-1] {
		t.Errorf("down on the last row: offset %d after %d, cursor %d", m.offsets[m.step], before, m.cursor)
	}
	if m = drive(m, pgdown); m.offsets[m.step] <= before+1 || m.cursor != last[len(last)-1] {
		t.Errorf("page down on the last row: offset %d after %d, cursor %d", m.offsets[m.step], before, m.cursor)
	}
	if m = drive(m, press(tea.KeyEnd)); !strings.Contains(view(m), end) || !strings.Contains(view(m), "\n   kit toolchains\n") ||
		!m.inPane {
		t.Errorf("end on the last row does not reach the page's end:\n%s", view(m))
	}
	// a key that moves no cursor leaves the pane there
	if m = drive(m, press('?'), press('?')); !strings.Contains(view(m), end) {
		t.Errorf("the legend, shown and hidden, moved the pane:\n%s", view(m))
	}
	if m = drive(m, up); m.cursor != last[len(last)-2] || !strings.Contains(view(m), focus+Failed+" several tool managers") {
		t.Errorf("up: cursor %d:\n%s", m.cursor, view(m))
	}
	if m = drive(m, esc); m.offsets[m.step] != 0 || m.inPane {
		t.Errorf("esc: offset %d, in the pane %v", m.offsets[m.step], m.inPane)
	}
}

// A link in the rest of a step's page, under its checks, is followed by a click, as one on any page is.
func TestALinkUnderAStepsChecksIsFollowed(t *testing.T) {
	overShipped(t)
	m, _ := fake(t)
	m = drive(m, append(testkit.Start(m, at120), stepKey(chains))...)
	x, y := at(t, m, "its toolchain.")
	if m = drive(m, testkit.Click(x+4, y)); m.tabs[m.step].id != "terms" || m.search().Query != "toolchain" {
		t.Errorf("a click on the term: step %s, search %q", m.tabs[m.step].id, m.search().Query)
	}
}

// The setup step is drawn as the toolchains are: its title, its checks, a row each, and the rest of its page under them,
// whose links are followed by a click.
func TestSetupDrawsItsChecksAndTheRestOfItsPageUnderThem(t *testing.T) {
	overShipped(t)
	m, _ := fake(t)
	m = drive(m, append(testkit.Start(m, tea.WindowSizeMsg{Width: 120, Height: 60}), stepKey(setup))...)
	v := view(m)
	if m.gridded() || !inOrder(v, "   Setup — this machine's logins", Failed+" gh is not logged in to github.com",
		Failed+" kit check finds 2 differences", "\n\n   This step checks what the work") {
		t.Fatalf("the page is not under the checks:\n%s", v)
	}
	x, y := at(t, m, "code forge")
	if m = drive(m, testkit.Click(x, y)); m.tabs[m.step].id != "terms" || m.search().Query != "code forge" {
		t.Errorf("a click on the term: step %s, search %q", m.tabs[m.step].id, m.search().Query)
	}
}
