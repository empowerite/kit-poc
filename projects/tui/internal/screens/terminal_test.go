// The root tells the styles what the terminal draws, as the program says it at its start, so a terminal of no color
// still shows where the keyboard is.
package screens

import (
	"bytes"
	"image/color"
	"regexp"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/flow"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// sgr finds each escape that sets how text is drawn, and its parameters.
var sgr = regexp.MustCompile(`\x1b\[([0-9;:]*)m`)

// issues gives the root on Issues, over the flow package's fake kit, at 120×30, loaded, then told what the terminal
// says of itself; the styles are as they started once the test ends.
func issues(t *testing.T, terminal ...tea.Msg) Model {
	t.Helper()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Cleanup(style.Reset)
	r := testkit.Runner(t, "flow")
	f, err := flow.OpenApp(r, shell.Issues, flow.Words{})
	if err != nil {
		t.Fatal(err)
	}
	m, _ := testkit.Drive(New(r, shell.Issues, f), nil, testkit.Start(New(r, shell.Issues, f),
		append([]tea.Msg{tea.WindowSizeMsg{Width: 120, Height: 30}}, terminal...)...)...)
	t.Cleanup(m.Close)
	return m
}

// sent gives the lines of the screen as a terminal of the profile is sent them: the program writes a view through
// the profile, which drops what the terminal cannot draw.
func sent(t *testing.T, p colorprofile.Profile, m Model) []string {
	t.Helper()
	var b bytes.Buffer
	if _, err := (&colorprofile.Writer{Forward: &b, Profile: p}).Write([]byte(m.View().Content)); err != nil {
		t.Fatal(err)
	}
	return strings.Split(b.String(), "\n")
}

// reversed gives the text of each line of the screen that has reverse video on it, without its escapes, from where
// the reverse video starts.
func reversed(lines []string) []string {
	var out []string
	for _, l := range lines {
		for _, at := range sgr.FindAllStringSubmatchIndex(l, -1) {
			if slices.Contains(strings.Split(l[at[2]:at[3]], ";"), "7") {
				out = append(out, strings.TrimSpace(ansi.Strip(l[at[0]:])))
				break
			}
		}
	}
	return out
}

// With NO_COLOR, the terminal is sent no color, and the row under the cursor, a group's heading or a row, is the one
// line of the screen in reverse video, the whole line, wherever the cursor goes.
func TestWithNoColorTheRowUnderTheCursorIsInReverseVideo(t *testing.T) {
	m := issues(t, tea.ColorProfileMsg{Profile: colorprofile.Ascii})
	if got := reversed(sent(t, colorprofile.Ascii, m)); len(got) != 0 {
		t.Fatalf("with the keyboard on the tab bar, reverse video: %q", got)
	}
	m, _ = testkit.Drive(m, nil, testkit.Press("down"), testkit.Press("down"), testkit.Press("down"))
	if got := reversed(sent(t, colorprofile.Ascii, m)); len(got) != 1 || !strings.HasPrefix(got[0], "□ ▾ jig 1") {
		t.Fatalf("on the heading of jig, reverse video: %q", got)
	}
	m, _ = testkit.Drive(m, nil, testkit.Press("down"))
	got := reversed(sent(t, colorprofile.Ascii, m))
	if len(got) != 1 || !strings.HasPrefix(got[0], "□ ▸ #7") || !strings.HasSuffix(got[0], "Fix the thing") {
		t.Errorf("on the row of #7, reverse video: %q", got)
	}
	for _, l := range sent(t, colorprofile.Ascii, m) {
		// the band is on from the line's first cell to the pane's last, taken up again after each style in it ends
		if strings.Contains(l, "#7") && (!strings.HasPrefix(l, "\x1b[7m") || ansi.StringWidth(l) != 119 ||
			strings.Count(l, "\x1b[m") != strings.Count(l, "\x1b[m\x1b[7m")+1) {
			t.Errorf("the row's line is not reversed whole, %d cells: %q", ansi.StringWidth(l), l)
		}
	}
}

// The band under the cursor is told by the terminal's background: dark grey on a dark one, light grey on a light one,
// and reverse video, which reads on both, where the terminal did not say, as under NO_COLOR, where no color is sent.
func TestTheBandUnderTheCursorIsToldByTheTerminalsBackground(t *testing.T) {
	grey := func(l string) string {
		m := regexp.MustCompile(`48;5;(\d+)`).FindStringSubmatch(l)
		if m == nil {
			return ""
		}
		return m[1]
	}
	for _, c := range []struct {
		name     string
		terminal []tea.Msg
		grey     string
		reversed bool
	}{
		{"dark", []tea.Msg{tea.BackgroundColorMsg{Color: color.Black}}, "236", false},
		{"light", []tea.Msg{tea.BackgroundColorMsg{Color: color.White}}, "254", false},
		{"unknown", nil, "", true},
		{"no color, dark", []tea.Msg{tea.BackgroundColorMsg{Color: color.Black},
			tea.ColorProfileMsg{Profile: colorprofile.Ascii}}, "", true},
	} {
		t.Run(c.name, func(t *testing.T) {
			m := issues(t, c.terminal...)
			m, _ = testkit.Drive(m, nil, testkit.Press("down"), testkit.Press("down"), testkit.Press("down"),
				testkit.Press("down"))
			var rows []string
			for _, l := range strings.Split(m.View().Content, "\n") {
				if strings.Contains(ansi.Strip(l), "#7 ") {
					rows = append(rows, l)
				}
			}
			if len(rows) != 1 || grey(rows[0]) != c.grey || strings.Contains(rows[0], "\x1b[7m") != c.reversed {
				t.Errorf("the row under the cursor, band %q, reversed %v: %q", c.grey, c.reversed, rows)
			}
		})
	}
}

// With NO_COLOR, the line under the keyboard in a menu, the stop the keyboard is on in the control line, the preset
// selector while it has the keyboard, and the line under the keyboard in a dialog are each in reverse video, and
// nothing else is.
func TestWithNoColorTheLineUnderTheKeyboardIsInReverseVideo(t *testing.T) {
	m := issues(t, tea.ColorProfileMsg{Profile: colorprofile.Ascii})
	m, _ = testkit.Drive(m, nil, testkit.Press("="))
	first := reversed(sent(t, colorprofile.Ascii, m))
	m, _ = testkit.Drive(m, nil, testkit.Press("down"))
	second := reversed(sent(t, colorprofile.Ascii, m))
	if len(first) != 1 || len(second) != 1 || !strings.HasPrefix(first[0], "🎫 Issues") ||
		!strings.HasPrefix(second[0], "🔀 Changes") {
		t.Errorf("the app's menu's line under the keyboard, then after down: %q, %q", first, second)
	}
	m, _ = testkit.Drive(m, nil, testkit.Press("esc"), testkit.Press("down"))
	if got := reversed(sent(t, colorprofile.Ascii, m)); len(got) != 1 || !strings.HasPrefix(got[0], "▾ source ·") {
		t.Errorf("the control line's stop under the keyboard: %q", got)
	}
	// tab steps along the control line's stops, each reversed in its turn, the last the preset selector
	var stops []string
	for range 4 {
		m, _ = testkit.Drive(m, nil, testkit.Press("tab"))
		got := reversed(sent(t, colorprofile.Ascii, m))
		if len(got) != 1 {
			t.Fatalf("the control line's stops under the keyboard: %q", got)
		}
		stops = append(stops, strings.Join(strings.Fields(got[0])[:2], " "))
	}
	if want := []string{"· organization", "· repository", "▾ 7", "All Issues"}; !slices.Equal(stops, want) {
		t.Errorf("the control line's stops under the keyboard, then the preset selector: %q, want %q", stops, want)
	}
	m, _ = testkit.Drive(m, nil, shell.SwitchMsg{Screen: shell.SettingsScreen}, testkit.Press("down"))
	got := reversed(sent(t, colorprofile.Ascii, m))
	if len(got) != 2 || !strings.HasPrefix(got[0], "◼ Auto-group") {
		t.Errorf("the Settings dialog's line under the keyboard, over the selector: %q", got)
	}
}

// A label ends in the half circles a Nerd Font gives until the Settings dialog's Rounded labels line is turned off, in
// every screen at once, and the choice is kept; off, a label is a block of its color with a cell each side, and on again
// the half circles come back.
func TestRoundedLabelsAreASettingAndLabelsStartRounded(t *testing.T) {
	m := issues(t)
	t.Cleanup(func() { style.Rounded(false) })
	// the labels of #1 are priority=high, a key and a value, and bug under #46
	view := func() string { return ansi.Strip(m.View().Content) }
	if v := view(); !strings.Contains(v, style.PillLeft+"bug"+style.PillRight) ||
		!strings.Contains(v, style.PillLeft+"All Issues ▼"+style.PillRight) {
		t.Fatalf("labels start rounded:\n%s", v)
	}
	toggle := []tea.Msg{shell.SwitchMsg{Screen: shell.SettingsScreen}, testkit.Press("down"), testkit.Press("down"),
		testkit.Press("down"), testkit.Press("down"), testkit.Press("space"), testkit.Press("esc")}
	m, _ = testkit.Drive(m, nil, toggle...)
	if v := view(); strings.Contains(v, style.PillLeft) || strings.Contains(v, style.PillRight) ||
		!strings.Contains(v, " priority  h") || !strings.Contains(v, " bug ") || !strings.Contains(v, "All Issues ▼ ") {
		t.Errorf("plain labels:\n%s", v)
	}
	if m.settings.Rounded {
		t.Error("the setting is not off")
	}
	// kept in the file, so the next kittui starts as this one stands
	if saved := shell.LoadSettings(m.settings.Path); saved.Rounded {
		t.Errorf("the settings file: %+v", saved)
	}
	m, _ = testkit.Drive(m, nil, toggle...)
	if v := view(); !strings.Contains(v, style.PillLeft+"bug"+style.PillRight) {
		t.Errorf("rounded again:\n%s", v)
	}
}
