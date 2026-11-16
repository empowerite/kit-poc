package shell

import (
	"encoding/json"
	"image"
	"os"
	"path/filepath"
	"strings"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// Settings are kittui's own, the same on every screen and every view, which the Settings dialog changes and kittui's
// file keeps: whether the keys bar shows on the screen's last line; whether a table folds a value every row of a group
// shares, said once in the group's heading; whether it hides, as a view loads, each column no row holds a value in;
// whether it draws an emoji every row shown shares, which it drops otherwise; and whether a label ends in half circles,
// which a Nerd Font draws, or in a cell of its color; and whether a tab's number is drawn in a circle or is the plain
// digit. With no file, or one that does not read, each is as kittui
// starts: the keys bar shown, shared values folded, empty columns hidden, shared emoji dropped, and labels rounded
// where kit found a Nerd Font, else square, and tab numbers circled. Rounded is nil until the person chooses, so a font found later is followed.
type Settings struct {
	Path        string `json:"-"`
	KeysBar     bool   `json:"keysBar"`
	FoldShared  bool   `json:"foldShared"`
	HideBlank   bool   `json:"hideBlank"`
	SharedEmoji bool   `json:"sharedEmoji"`
	Rounded     *bool  `json:"roundedLabels,omitempty"`
	PlainTabs   bool   `json:"plainTabs,omitempty"`
}

// NerdFont is the variable kit says in whether a Nerd Font is present, 1 or 0, as terminal:export-probes sets it.
const NerdFont = "KIT_NERD_FONT"

// Rounds says whether a label ends in half circles: as the person chose, else where kit found a Nerd Font.
func (s Settings) Rounds() bool {
	if s.Rounded != nil {
		return *s.Rounded
	}
	return os.Getenv(NerdFont) == "1"
}

// Circled says whether a tab's number is drawn in a circle, as it is until the person turns it off.
func (s Settings) Circled() bool { return !s.PlainTabs }

// SettingsMsg tells a screen the settings, when it is made and whenever the dialog changes one, so a table folds and
// draws as they say.
type SettingsMsg struct{ Settings Settings }

// SettingsFile gives the file kittui keeps its settings in: kit/kittui.json under XDG_CONFIG_HOME, else under
// ~/.config, beside the searches; nothing when neither is known.
func SettingsFile() string {
	recent := RecentFile()
	if recent == "" {
		return ""
	}
	return filepath.Join(filepath.Dir(recent), "kittui.json")
}

// LoadSettings gives the settings the file keeps, each it does not keep as kittui starts.
func LoadSettings(path string) Settings {
	s := Settings{KeysBar: true, FoldShared: true, HideBlank: true}
	if data, err := os.ReadFile(path); path != "" && err == nil {
		_ = json.Unmarshal(data, &s)
	}
	s.Path = path
	return s
}

// Save writes the settings to their file. A file that cannot be written leaves them for the session.
func (s Settings) Save() {
	if s.Path == "" {
		return
	}
	if data, err := json.MarshalIndent(s, "", "  "); err == nil && os.MkdirAll(filepath.Dir(s.Path), 0o755) == nil {
		_ = os.WriteFile(s.Path, append(data, '\n'), 0o644)
	}
}

// SettingsScreen is what the app's menu's Settings… asks for: not a screen, but the dialog kittui opens over the one
// shown.
const SettingsScreen Screen = "settings"

// setting is one line of the Settings dialog: its name, what it says, and how it reads and flips its value.
type setting struct {
	name, says string
	get        func(Settings) bool
	flip       func(Settings) Settings
}

// settings are the Settings dialog's lines, in alphabetical order.
var settings = []setting{
	{"Auto-group", "groups a table as it opens by each column whose value is the same on every row",
		func(s Settings) bool { return s.FoldShared },
		func(s Settings) Settings { s.FoldShared = !s.FoldShared; return s }},
	{"Auto-hide", "hides a column while no row has a value in it",
		func(s Settings) bool { return s.HideBlank },
		func(s Settings) Settings { s.HideBlank = !s.HideBlank; return s }},
	{"Circled tab numbers", "draws a tab's number in a circle; off is the plain digit",
		func(s Settings) bool { return s.Circled() },
		func(s Settings) Settings { s.PlainTabs = !s.PlainTabs; return s }},
	{"Key hints", "shows the keys you can press now on the status bar, the bottom line",
		func(s Settings) bool { return s.KeysBar },
		func(s Settings) Settings { s.KeysBar = !s.KeysBar; return s }},
	{"Repeated emoji", "shows an emoji in a column even where every row has the same one",
		func(s Settings) bool { return s.SharedEmoji },
		func(s Settings) Settings { s.SharedEmoji = !s.SharedEmoji; return s }},
	{"Rounded labels", "ends a label with half circles, which need a Nerd Font; off is a block of its color",
		func(s Settings) bool { return s.Rounds() },
		func(s Settings) Settings { on := !s.Rounds(); s.Rounded = &on; return s }},
}

// SettingsDialog is the dialog the app's menu's Settings… opens over the screen shown: whether it is open, which then
// has the keyboard, and the setting under the keyboard; and the screen cell the menu drew Settings… from, which its own
// title, Settings…, stands on, none for a dialog opened from nowhere.
type SettingsDialog struct {
	Open bool
	At   int
	From *image.Point
}

// settingsKeys are the dialog's keys, on the keys bar.
const settingsKeys = "esc close · ↑↓ move · ␣ toggle"

// Key takes a key while the dialog is open: up and down move between the settings, space or enter flips the one under
// the keyboard, which is saved at once, and esc closes the dialog, as = does. It gives the dialog and the settings.
func (d SettingsDialog) Key(k tea.KeyPressMsg, s Settings) (SettingsDialog, Settings) {
	switch key := k.String(); key {
	case "up", "down":
		d.At = Step(d.At, len(settings), map[string]int{"up": -1, "down": 1}[key], Every)
	case "space", "enter":
		s = settings[d.At].flip(s)
		s.Save()
	case "esc", "=":
		d.Open = false
	}
	return d, s
}

// Keys gives the dialog's segment of the keys bar: it takes every press.
func (d SettingsDialog) Keys() Segment {
	s := DialogKeys(settingsKeys)
	s.Bindings[1].Presses = []string{"up", "down"}
	s.Bindings[2].Presses = []string{"space", "enter"}
	return s
}

// Click takes a click while the dialog is open: a left one on a setting puts the keyboard on it and flips it, saved at
// once, as space does; a left one outside the box closes the dialog, as esc does; anything else, as a click on the
// box's edges, changes nothing. The dialog stands where Overlay draws it over a screen of so many lines, so wide. It
// gives the dialog and the settings.
func (d SettingsDialog) Click(msg tea.MouseClickMsg, s Settings, height, width int) (SettingsDialog, Settings) {
	mouse := msg.Mouse()
	if mouse.Button != tea.MouseLeft {
		return d, s
	}
	box := d.box(s, width)
	top, left := d.place(box, height, width)
	switch k, on := (Placed{Lines: box, Top: top, Left: left}).Hit(mouse.X, mouse.Y); {
	case !on:
		d.Open = false
	case k >= 0 && k < len(settings):
		d.At = k
		s = settings[k].flip(s)
		s.Save()
	}
	return d, s
}

// Overlay draws the open dialog over the screen's lines, where place stands it on a screen so wide: each setting
// a box picked or not, its name, and what it says, dim, the one under the keyboard inverse.
func (d SettingsDialog) Overlay(lines []string, s Settings, width int) []string {
	if !d.Open {
		return lines
	}
	box := d.box(s, width)
	top, left := d.place(box, len(lines), width)
	d.release(lines, left)
	return Over(lines, box, top, left)
}

// release clears the menu's keyboard from its Settings… line, as the dialog now has it: the cells of that line before
// column left, where the dialog's box starts, come back as plain text, from the one after the menu's edge. The menu is
// still open under the dialog, on Settings…, for esc to close back to.
func (d SettingsDialog) release(lines []string, left int) {
	if d.From == nil || d.From.Y < 0 || d.From.Y >= len(lines) {
		return
	}
	// the name starts after the box's edge, a cell, the glyph's two cells, and a cell, as Menu.choice says
	from := d.From.X - 4
	if from >= left {
		return
	}
	line := lines[d.From.Y]
	lines[d.From.Y] = pane.Cells(line, 0, from) + ansi.Strip(pane.Cells(line, from, left)) +
		pane.Cells(line, left, ansi.StringWidth(line))
}

// box gives the dialog's lines, as Overlay draws them on a screen so wide: each setting's name, then what it says, in
// one column two cells after the longest name.
func (d SettingsDialog) box(s Settings, width int) []string {
	var body []string
	wide := 0
	for _, set := range settings {
		wide = max(wide, ansi.StringWidth(set.name))
	}
	for k, set := range settings {
		box := style.Unpicked
		if set.get(s) {
			box = style.Picked
		}
		name := box + " " + set.name
		if k == d.At {
			name = style.Selected(name)
		}
		pad := strings.Repeat(" ", wide-ansi.StringWidth(set.name)+2)
		body = append(body, name+pad+style.Off(set.says))
	}
	return Dialog(settingsItem.Name, body, width-2)
}

// place gives the line and the column the dialog's box starts at on a screen of so many lines, so wide: where its
// title, three cells in from the corner, stands on the menu's Settings…, as near as the screen lets; else its third
// line, or as near as the screen lets, and centered across it.
func (d SettingsDialog) place(box []string, height, width int) (top, left int) {
	wide := ansi.StringWidth(box[0])
	if d.From != nil {
		return max(0, min(d.From.Y, height-len(box))), max(0, min(d.From.X-3, width-wide))
	}
	return min(2, max(0, height-len(box))), max(0, (width-wide)/2)
}
