// The steps with checks drawn over the pages the kit package ships, where every other test draws the fixture's short
// ones: at 80×24, and at 120×40 as a person with a larger window has it, each opens with its title and its checks on
// the screen, and the rest of its page under them.
package welcome

import (
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// at80 is a terminal as it first opens, and at120x40 a larger window.
var (
	at80     = tea.WindowSizeMsg{Width: 80, Height: 24}
	at120x40 = tea.WindowSizeMsg{Width: 120, Height: 40}
)

// overShipped has the fake kit answer root with this repository's kit, so the pages are the ones the kit package
// ships.
func overShipped(t *testing.T) {
	t.Helper()
	root, err := filepath.Abs(filepath.Join("..", "..", "..", "..", "kit"))
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("FAKE_WELCOME_ROOT", root)
}

func TestAStepOverTheShippedPagesOpensWithItsChecksOnScreen(t *testing.T) {
	overShipped(t)
	for _, c := range []struct {
		step          int
		title, checks string
		golden        string
	}{
		{chains, "Toolchains —", "✅ bash 5.2 runs kit\n   ❌ jq is not installed\n", "toolchains-shipped.golden"},
		{setup, "Setup —", "❌ gh is not logged in to github.com\n", "setup-shipped.golden"},
	} {
		for size, golden := range map[tea.WindowSizeMsg]string{at80: c.golden,
			at120x40: strings.Replace(c.golden, "-shipped", "-shipped-120", 1)} {
			m, _ := fake(t)
			m = drive(m, append(testkit.Start(m, size), stepKey(c.step))...)
			v := view(m)
			pane := strings.Split(v, "\n")[m.paneTop():]
			if !strings.HasPrefix(pane[0], "   "+c.title) || !strings.Contains(v, c.checks) {
				t.Errorf("%s does not open with its title and its checks:\n%s", m.tabs[m.step].name, v)
			}
			testkit.Golden(t, filepath.Join("testdata", golden), v)
		}
	}
	// the setup step's table, over a group
	m, _, _ := group(t, stepKey(setupStep), at80)
	v := view(m)
	if pane := strings.Split(v, "\n")[m.paneTop():]; !strings.HasPrefix(pane[0], "   Setup —") ||
		!strings.Contains(v, "This machine") || !strings.Contains(v, "gh is not logged in to github.com") {
		t.Errorf("the setup table does not open with its title and its rows:\n%s", v)
	}
	testkit.Golden(t, filepath.Join("testdata", "setup-folders-shipped.golden"), v)
}
