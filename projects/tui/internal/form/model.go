// The live form: a Bubble Tea model over the fields, the runner, and the keyboard. Up and down move between fields, as
// tab and shift-tab do but along a row of options, whose options are the stops on its line: there they move between
// the options, and on to the field after the last or before the first; space toggles, picks, or chooses the option
// under the cursor, which is the first of a one-of row with nothing chosen, and a character typed there chooses an
// option that takes a value and starts the value; backspace erases, Enter takes the next
// field or line and, on the command line, runs; shift-Enter runs from anywhere a terminal reports it, and the keys bar
// names it only where the terminal said it does; esc goes back
// to the palette and never quits; ctrl-q quits, and ctrl-c quits as interrupted. In a list, page down and page up move the cursor a page,
// and home and end to the first and last row. Where a window hides rows, a dim line says how many. A paste is typed
// where a key would be, as paste says. In a list of one value, Enter takes the row under the cursor, and backspace
// with nothing typed takes an optional list's answer back; the keys bar names both for what they then do.
//
// The form stands in the frame every screen has: the menu bar first, kit help's, its kit menu, its workspace menu, the
// verb's name, and the search field; the status bar last. A click on the kit menu or the workspace menu drops it down,
// and = or - does where the field with the keyboard types no text; a click on the search field, or / where no text is
// typed, asks for the palette's search, the Help screen's, as FindMsg.
//
// Every field takes a plain click, as press says: a click on a field gives it the keyboard; one on a flag's name, or
// on a name of a row of options, does there what the space does; one on a row of the list that has the keyboard
// picks it; and one on the command line that has the keyboard runs it.
package form

import (
	"fmt"
	"slices"
	"sort"
	"strings"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/fix"
	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/legend"
	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
	"github.com/empowerite/kit/projects/tui/internal/syntax"
)

// BackMsg asks the palette to take the form back: esc, or a click on the way back, on a form opened from the palette.
type BackMsg struct{}

// FindMsg asks for the palette's search, with focus, in the form's place: a click on the form's search field, or /.
type FindMsg struct{}

// appLabel is the screen's name on the menu bar, the Help screen's, which the form is a view of.
const appLabel = "kit help"

// choicesMsg brings a list's rows; flipped names the value whose flip asked for them again, and asked holds the other
// answers the rows were asked with.
type choicesMsg struct {
	key     string
	rows    []kit.Choice
	set     bool
	err     error
	flipped string
	asked   []string
}

// listWindow is the lines a list's window takes: its rows, and the lines that say how many it hides.
const listWindow = 10

// live is how the form draws on a terminal.
var live = Styles{Chosen: style.Chosen, Off: style.Off, Label: style.Label, Dim: style.Off, Refusal: style.Refusal,
	Cursor: style.Cursor}

// Model is a verb's form on the screen.
type Model struct {
	spec    syntax.Spec
	runner  kit.Runner
	back    bool
	legend  legend.Legend // the legend, which F1 shows and hides, and ? where no text is typed, and the corner it stands in
	fields  []Field
	focus   int    // the field with the keyboard; len(fields) is the command line
	cursor  int    // the option in a row, or the row in a list
	input   string // the text being typed: a value, a line, or a list's filter
	note    string // the line under the focused field: a list's line about a row, or what kit refused
	refusal string // the line under the command line
	width   int
	height  int             // the terminal's lines; zero before it says, and nothing is clipped
	shift   bool            // the terminal tells shift-Enter from Enter, so the keys bar names it
	appMenu shell.Menu      // the kit menu, internal/shell's, which has the keyboard while it is open
	books   shell.BooksMenu // the menu bar's workspace menu, which has the keyboard while it is open

	lists  map[string][]kit.Choice
	sets   map[string]bool
	stale  map[string]bool
	seeded map[string]bool
	failed map[string]bool // the lists kit refused, which take what is typed instead

	extOrder []string
	ext      map[string]syntax.Argument
	extSeen  map[string]bool

	initCmd                tea.Cmd
	run, done, interrupted bool
	args                   []string
}

// New opens the form over the fields; back is true when esc returns to the palette, false when the form stands alone.
func New(spec syntax.Spec, fields []Field, r kit.Runner, back bool) Model {
	m := Model{spec: spec, runner: r, back: back, fields: fields, width: 80, lists: map[string][]kit.Choice{}, sets: map[string]bool{},
		stale: map[string]bool{}, seeded: map[string]bool{}, failed: map[string]bool{}, extSeen: map[string]bool{},
		appMenu: shell.Menu{Here: shell.Help}}
	if spec.Extends {
		m.refreshExtension()
		m.rebuild(Collect(m.fields))
	}
	m.focus = FirstEmptyRequired(m.fields)
	if m.focus < 0 {
		m.focus = 0
	}
	m.initCmd = m.enter()
	return m
}

// Init fetches the focused list's rows when the form opens on one.
func (m Model) Init() tea.Cmd { return m.initCmd }

// Done says, after the program ends, whether the command line was accepted, and its words after kit <verb>.
func (m Model) Done() (bool, []string) {
	if !m.run {
		return false, nil
	}
	return true, m.args
}

// Interrupted says whether ctrl-c ended the form.
func (m Model) Interrupted() bool { return m.interrupted }

// Fields gives the fields as they stand, a line being typed included, for the transcript.
func (m Model) Fields() []Field { return m.viewFields() }

// CommandLine gives the words after kit <verb> the form builds now.
func (m Model) CommandLine() []string { return CommandLine(m.spec, m.viewFields()) }

// Update takes a message.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyboardEnhancementsMsg:
		m.shift = msg.SupportsKeyDisambiguation()
	case choicesMsg:
		m.choices(msg)
	case matchedMsg:
		cmd := m.matched(msg)
		return m, cmd
	case shell.WorkspaceMsg:
		m.books = m.books.Told(msg)
	case tea.MouseClickMsg:
		return m, m.click(msg)
	case tea.KeyPressMsg:
		cmd := m.key(msg)
		return m, cmd
	case tea.PasteMsg:
		m.paste(msg.Content)
	}
	return m, nil
}

// menuBar gives the menu bar, as internal/shell draws every screen's: the kit menu's = before kit help, the workspace
// menu, the verb's name, and the search field, idle, as the palette's search is the Help screen's.
func (m Model) menuBar() shell.MenuBar {
	return shell.MenuBar{Screen: appLabel, Open: m.appMenu.Open, Workspace: m.books.Label(), On: m.spec.Verb,
		Search: shell.SearchLine("", false)}
}

// chose does what a choice from the kit menu asks: a screen asks kittui to show it in the form's place, and quit ends
// the form, as ctrl-q does.
func (m *Model) chose(c shell.Choice) tea.Cmd {
	switch {
	case c.Quit:
		m.done = true
		return tea.Quit
	case c.Screen != "":
		return c.Switch()
	}
	return nil
}

// backLabel is the way back to the palette, as the form draws it on its first line: a click on it goes back, as esc
// does.
const backLabel = "‹ verbs"

// onBack says whether a cell of the screen is on the way back, where the frame draws it.
func (m Model) onBack(x, y int) bool {
	lines := m.frame()
	return m.back && y >= 0 && y < len(lines) && strings.HasPrefix(ansi.Strip(lines[y]), " "+backLabel) && x >= 1 &&
		x <= ansi.StringWidth(backLabel)
}

// click takes a click on the menu bar: an open menu's, the kit menu's =, the workspace menu, or the search field; one
// on the way back, which goes back to the palette; and one on the form, as press says. Anywhere else it does nothing.
func (m *Model) click(msg tea.MouseClickMsg) tea.Cmd {
	booksAt := m.menuBar().WorkspaceAt()
	switch {
	case msg.Button != tea.MouseLeft:
	case m.appMenu.Open:
		var c shell.Choice
		m.appMenu, c = m.appMenu.Click(msg.X, msg.Y, m.width)
		return m.chose(c)
	case m.books.Open:
		var picked string
		m.books, picked = m.books.Click(msg.X, msg.Y, booksAt, m.width)
		return shell.Pick(picked)
	case m.legend.Open && m.legend.Click(msg.X, msg.Y, m.legendSpec()):
	case shell.OnApp(msg.X, msg.Y, appLabel):
		m.appMenu = m.appMenu.Opened()
	case m.books.On(msg.X, msg.Y, booksAt):
		m.books = m.books.Opened()
	case msg.Y == shell.Top && msg.X >= m.menuBar().SearchAt(m.width):
		return func() tea.Msg { return FindMsg{} }
	case m.onBack(msg.X, msg.Y):
		return func() tea.Msg { return BackMsg{} }
	default:
		return m.press(msg.X, msg.Y)
	}
	return nil
}

// press takes a click on the form, read through the window that clips it. A click on a field gives it the keyboard,
// and one on a name does there what the space does: on a flag's name it flips the flag, and on a name of a row it
// puts the cursor on the option and chooses or flips it. The name acts only while its field is the one the keyboard
// came to, which a move that brings a verb's own arguments may replace. A click on a row of the list that has the
// keyboard puts the cursor on the row, and picks it or unpicks it on a list of many, as the space does, or takes it
// and goes on, on a list of one, as Enter does. A click on the command line gives it the keyboard, and one on it
// while it has the keyboard runs it, as Enter does there, so no single click runs a command. A click on a blank
// line, or on a line that says how many are hidden, does nothing.
func (m *Model) press(x, y int) tea.Cmd {
	fields, o := m.viewFields(), m.options()
	content, header, first, last, at := Layout(m.spec, fields, o)
	_, from := window(content, m.room(), header, first, last, at)
	if y -= 2; y < 0 || y >= len(from) || from[y] < 0 { // the menu bar and its rule stand over the form
		return nil
	}
	if at >= 0 {
		if k, span := m.cursor+from[y]-at, m.span(); k >= span.Start && k < span.End {
			m.cursor = k
			if m.fields[m.focus].Kind == PickMany {
				return m.list(tea.KeyPressMsg{}, "space")
			}
			return m.list(tea.KeyPressMsg{}, "enter")
		}
	}
	spot, on := SpotAt(Spots(m.spec, fields, o), x, from[y])
	switch {
	case !on:
		return nil
	case spot.Field < len(m.fields):
	case m.focus < len(m.fields):
		return m.move(len(m.fields) - m.focus)
	default:
		return m.tryRun()
	}
	key, cmd := m.fields[spot.Field].Key, tea.Cmd(nil)
	if spot.Field != m.focus {
		cmd = m.move(spot.Field - m.focus)
	}
	if spot.Option < 0 || m.focus >= len(m.fields) || m.fields[m.focus].Key != key {
		return cmd
	}
	switch f := &m.fields[m.focus]; f.Kind {
	case Toggle:
		m.toggle("space")
	case AnyOf, OneOf:
		m.cursor = spot.Option
		m.pickOption(f)
	}
	return cmd
}

// typing says whether the field with the keyboard types what is pressed: a value, a line, or a list's filter.
func (m Model) typing() bool {
	if m.focus >= len(m.fields) {
		return false
	}
	switch m.fields[m.focus].Kind {
	case Text, Lines, Wildcard, Pick, PickMany:
		return true
	}
	return false
}

// View draws the form on the alternate screen, clipped to the terminal's lines so the way back and the focused field
// stay in sight, with the keys bar on the last line, which nothing above it moves.
func (m Model) View() tea.View {
	lines := m.legend.Over(m.frame(), m.legendSpec())
	lines = m.appMenu.Overlay(lines, m.width)
	lines = m.books.Overlay(lines, m.menuBar().WorkspaceAt(), m.width)
	return shell.View(lines, m.height, m.bottom())
}

// frame gives the screen's lines over its last, before the legend and the menus are drawn over them: the menu bar and
// its rule, and the form clipped to the terminal's lines.
func (m Model) frame() []string {
	content, header, first, last, at := Layout(m.spec, m.viewFields(), m.options())
	shown, _ := window(content, m.room(), header, first, last, at)
	lines := strings.Split(strings.TrimSuffix(shown, "\n"), "\n")
	return append([]string{m.menuBar().Line(m.width), shell.RuleLine(m.width, "")}, lines...)
}

// options gives how the form is drawn as it stands: where the keyboard is, and what is typed and said there.
func (m Model) options() Options {
	focus := m.focus
	if focus >= len(m.fields) {
		focus = -1
	}
	return Options{Width: m.width, Focus: focus, Cursor: m.cursor, Styles: live, Expand: m.expand, Note: m.note,
		CommandFocus: m.focus >= len(m.fields), CommandRefusal: m.refusal, Back: m.back}
}

// room gives the lines the form has on the terminal, zero before the terminal says its own, when nothing is clipped.
func (m Model) room() int {
	if m.height <= 0 {
		return 0
	}
	return max(1, m.height-4) // the menu bar and its rule over the form, and the gap and the status bar under it
}

// span gives the rows the window of the list that has the keyboard shows, around its cursor.
func (m Model) span() pane.Span {
	return pane.Frame(len(m.filtered()), listWindow, m.cursor-4, m.cursor, m.cursor)
}

// bottom gives the screen's last line, the keys bar, which nothing above it moves.
func (m Model) bottom() string { return m.keys().Line(m.width) }

// keys gives the path to the keyboard, which the key hints are drawn from, the form's own first, as a field may type
// =, -, and /, which the menu bar's glyphs show: the form, whose esc goes back to the palette,
// or, opened on its own, whose ctrl-q quits, as esc never does; up and down move between fields, and enter takes the next field; and the field under the keyboard, with
// the keys its kind takes: the arrows across a row of options, the space where it toggles, backspace where it erases
// or clears, and the page keys on a list. On a list, enter is named take while it takes an answer, as takes says, and
// backspace clear while it takes one back, as clears says. On a one-of row, enter is named choose, beside the space,
// while it chooses, as chooses says, and the row says that typing gives the option's value where it does, as valued
// says. On the command line, enter runs. Tab, which moves as down and up do, is left unnamed. Shift-Enter is named
// only where the terminal answered Bubble Tea's ask for the kitty keyboard protocol; elsewhere, Terminal.app among
// them, it arrives as Enter, and the way to run is Enter on the command line.
func (m Model) keys() shell.Path {
	if m.appMenu.Open || m.books.Open {
		return shell.Path{shell.MenuKeys()}
	}
	end := shell.Bind("⌃Q", "quit", shell.Quit)
	if m.back {
		end = shell.Bind("esc", "back")
	}
	form := shell.Segment{Takes: []string{"tab", "shift+tab"}, Bindings: []shell.Binding{
		end, shell.Bind("↑↓", "move", "up", "down"), shell.Bind("⏎", "next", "enter")}}
	if m.shift {
		form.Bindings = append(form.Bindings, shell.Bind("⇧⏎", "run", "shift+enter"))
	}
	form.Bindings = append(form.Bindings, m.legendKeys())
	if m.focus >= len(m.fields) {
		// the command line is the last: up moves back, down has nowhere to go, and enter runs
		return shell.Path{form, {Takes: []string{"down"}, Bindings: []shell.Binding{shell.Bind("↑", "move", "up"),
			shell.Bind("⏎", "run", "enter", "shift+enter")}}}
	}
	var field shell.Segment
	switch f := m.fields[m.focus]; f.Kind {
	case Toggle:
		if !f.Required {
			field.Bindings = append(field.Bindings, shell.Bind("␣", "toggle", "space"))
		}
	case AnyOf:
		field.Bindings = append(field.Bindings, shell.Bind("⇥·⇧⇥", "option", "tab", "shift+tab"),
			shell.Bind("␣", "toggle", "space"))
	case OneOf:
		field.Bindings = append(field.Bindings, shell.Bind("⇥·⇧⇥", "option", "tab", "shift+tab"),
			shell.Bind("␣", "choose", "space"))
		if m.chooses(f) {
			field.Bindings = append(field.Bindings, shell.Bind("⏎", "choose", "enter"))
		}
		if !f.Required {
			field.Bindings = append(field.Bindings, shell.Bind("⌫", "clear", "backspace"))
		}
		if m.valued(f) {
			field.Bindings = append(field.Bindings, shell.Bind("", "type its value"))
		}
	case Text, Lines, Wildcard:
		field.Types = true
		field.Bindings = append(field.Bindings, shell.Bind("⌫", "erase", "backspace"))
	case Pick:
		field.Types = true
		erases := "erase"
		if m.clears(f) {
			erases = "clear"
		}
		field.Bindings = append(field.Bindings, shell.Bind("⇞⇟", "page", "pgup", "pgdown"),
			shell.Bind("⌫", erases, "backspace"))
	case PickMany:
		field.Types = true
		field.Bindings = append(field.Bindings, shell.Bind("⇞⇟", "page", "pgup", "pgdown"),
			shell.Bind("␣", "toggle", "space"), shell.Bind("⌫", "erase", "backspace"))
	}
	if m.takes(m.fields[m.focus]) {
		field.Bindings = append([]shell.Binding{shell.Bind("⏎", "take", "enter")}, field.Bindings...)
	}
	return shell.Path{form, field}
}

// takes says whether Enter on the field takes an answer, where the form's own Enter only moves on: on a list of one
// value, the row under the cursor; on a list kit refused, what is typed.
func (m Model) takes(f Field) bool {
	switch f.Kind {
	case Pick:
		return m.cursor < len(m.filtered()) || m.failed[f.Key] && m.input != ""
	case PickMany:
		return m.failed[f.Key] && m.input != ""
	}
	return false
}

// clears says whether backspace on the field takes its answer back: an optional list of one value that has one, with
// nothing typed to erase first. A list the command line needs keeps its answer, which another row replaces.
func (m Model) clears(f Field) bool {
	return f.Kind == Pick && !f.Required && len(f.Values) > 0 && m.input == ""
}

// legendKeys gives the binding of the legend: ? or F1, F1 alone where a field types what is pressed.
func (m Model) legendKeys() shell.Binding {
	if m.typing() {
		return shell.Bind("F1", "legend", "f1")
	}
	return shell.Bind("?", "legend", "?", "f1")
}

// key takes a key press.
func (m *Model) key(k tea.KeyPressMsg) tea.Cmd {
	s := k.String()
	// an open menu takes every press but the quitting ones
	if s != "ctrl+c" && s != shell.Quit {
		switch {
		case m.appMenu.Open:
			var c shell.Choice
			m.appMenu, c = m.appMenu.Key(k)
			return m.chose(c)
		case m.books.Open:
			var picked string
			m.books, picked = m.books.Key(k)
			return shell.Pick(picked)
		}
	}
	if m.legend.Key(s) {
		return nil
	}
	switch s {
	case "f1":
		m.legend.Toggle()
		return nil
	case "ctrl+c":
		m.interrupted, m.done = true, true
		return tea.Quit
	case shell.Quit:
		m.done = true
		return tea.Quit
	case "esc":
		// esc goes back to the palette, when the form came from it, and never quits
		if m.back {
			return func() tea.Msg { return BackMsg{} }
		}
		return nil
	case "shift+enter":
		return m.tryRun()
	}
	// where no text is typed, =, -, and / reach the menu bar
	switch {
	case m.typing():
	case s == "=":
		m.appMenu = m.appMenu.Opened()
		return nil
	case s == shell.Workspaces:
		m.books = m.books.Opened()
		return nil
	case s == "/":
		return func() tea.Msg { return FindMsg{} }
	case s == "?":
		m.legend.Toggle()
		return nil
	}
	if m.focus >= len(m.fields) {
		switch s {
		case "enter":
			return m.tryRun()
		case "up", "shift+tab":
			return m.move(-1)
		}
		return nil
	}
	switch m.fields[m.focus].Kind {
	case Text, Lines, Wildcard:
		return m.text(k, s)
	case Pick, PickMany:
		return m.list(k, s)
	case OneOf, AnyOf:
		return m.row(k, s)
	}
	return m.toggle(s)
}

// move takes the keyboard to the field d away, the command line after the last.
func (m *Model) move(d int) tea.Cmd {
	m.commitLine()
	m.focus = min(max(m.focus+d, 0), len(m.fields))
	return m.enter()
}

// enter readies the focused field: its text, its cursor, its extension, and its list's rows.
func (m *Model) enter() tea.Cmd {
	m.input, m.note, m.cursor = "", "", 0
	if m.spec.Extends {
		m.refreshExtension()
		m.rebuild(Collect(m.fields))
	}
	if m.focus >= len(m.fields) {
		return nil
	}
	f := m.fields[m.focus]
	switch f.Kind {
	case Text:
		if len(f.Values) > 0 {
			m.input = f.Values[0]
		}
	case OneOf:
		// the cursor is on the row's choice, or on its first option while it has none
		m.cursor = max(f.Chosen, 0)
	case Pick, PickMany:
		if m.lists[f.Key] == nil || m.stale[f.Key] {
			return m.fetch(f.Key, "")
		}
	}
	return nil
}

func (m *Model) toggle(s string) tea.Cmd {
	f := &m.fields[m.focus]
	switch s {
	case "space":
		if !f.Required {
			if len(f.Values) > 0 {
				f.Values = nil
			} else {
				f.Values = []string{"1"}
			}
			m.changed(f.Key)
		}
	case "enter", "down", "tab":
		return m.move(1)
	case "up", "shift+tab":
		return m.move(-1)
	}
	return nil
}

// row takes a key on a row of options, whose options are the stops on its line: tab and shift-tab move the cursor
// between them, and past the last or the first to the next field or the one before; space toggles the option under
// the cursor, or chooses it on a one-of row, and enter chooses it too, where chooses says, and goes on; backspace
// clears an optional one-of row, the cursor back on its first option; up and down move between fields. Moving the
// cursor never chooses, so tabbing through a row changes nothing. A character typed on a one-of row whose option
// under the cursor takes a value, as valued says, chooses the option, gives its value the keyboard, and is typed
// there, so a row the form opens on is answered by typing.
func (m *Model) row(k tea.KeyPressMsg, s string) tea.Cmd {
	f := &m.fields[m.focus]
	switch s {
	case "tab":
		if m.cursor >= len(f.Options)-1 {
			return m.move(1)
		}
		m.cursor++
	case "shift+tab":
		if m.cursor <= 0 {
			return m.move(-1)
		}
		m.cursor--
	case "space":
		m.pickOption(f)
	case "backspace":
		if f.Kind == OneOf && !f.Required {
			f.Chosen, m.cursor = -1, 0
			m.changed(f.Key)
		}
	case "enter":
		if m.chooses(*f) {
			m.pickOption(f)
		}
		return m.move(1)
	case "down":
		return m.move(1)
	case "up":
		return m.move(-1)
	default:
		if k.Text != "" && k.Mod&(tea.ModCtrl|tea.ModAlt) == 0 && m.valued(*f) {
			if f.Chosen != m.cursor {
				m.pickOption(f)
			}
			return tea.Batch(m.move(1), m.key(k))
		}
	}
	return nil
}

// chooses says whether Enter on the row chooses the option under the cursor before it goes on: on a one-of row, an
// option that is not the row's choice. On an optional row with nothing chosen, the first option is where the cursor
// starts, not where the person moved it, and Enter there only goes on, so walking a form with Enter turns nothing on.
func (m Model) chooses(f Field) bool {
	return f.Kind == OneOf && f.Chosen != m.cursor && (f.Required || f.Chosen >= 0 || m.cursor > 0)
}

// valued says whether the option under the cursor of a one-of row takes a value that is typed: its alternative opens
// with an option or an operand, as --message or <reference>, whose field follows the row once the option is chosen.
func (m Model) valued(f Field) bool {
	if f.Kind != OneOf {
		return false
	}
	alternative := alternatives(m.spec, f.Path)[m.cursor]
	return len(alternative) > 0 && (alternative[0].Kind == "option" || alternative[0].Kind == "operand")
}

// pickOption toggles the option under the cursor on an any-of row, or chooses it on a one-of row.
func (m *Model) pickOption(f *Field) {
	switch f.Kind {
	case AnyOf:
		option := f.Options[m.cursor]
		if i := index(f.Values, option); i >= 0 {
			f.Values = append(append([]string{}, f.Values[:i]...), f.Values[i+1:]...)
		} else {
			f.Values = append(f.Values, option)
		}
	case OneOf:
		f.Chosen = m.cursor
	}
	m.changed(f.Key)
}

func (m *Model) text(k tea.KeyPressMsg, s string) tea.Cmd {
	f := &m.fields[m.focus]
	if k.Text != "" && k.Mod&(tea.ModCtrl|tea.ModAlt) == 0 {
		m.input += k.Text
		m.typedText()
		return nil
	}
	switch s {
	case "backspace":
		if m.input != "" {
			r := []rune(m.input)
			m.input = string(r[:len(r)-1])
			m.typedText()
		} else if f.Kind != Text && len(f.Values) > 0 {
			f.Values = f.Values[:len(f.Values)-1]
			m.changed(f.Key)
		}
	case "enter":
		if f.Kind != Text && m.input != "" {
			m.commitLine()
			return nil
		}
		return m.move(1)
	case "down", "tab":
		return m.move(1)
	case "up", "shift+tab":
		return m.move(-1)
	}
	return nil
}

// paste types a paste in the field with the keyboard, where a key pressed would be typed: a value and a list's filter
// take it as one line, its line breaks dropped, so a pasted line break neither moves on nor runs; a field of lines
// takes each line of it, as Enter after each would, and leaves the last to go on typing. Under an open menu, on a
// field that types nothing, and on the command line, a paste does nothing.
func (m *Model) paste(content string) {
	lines := shell.PastedLines(content)
	if m.appMenu.Open || m.books.Open || !m.typing() || len(lines) == 0 {
		return
	}
	switch m.fields[m.focus].Kind {
	case Text:
		m.input += strings.Join(lines, "")
		m.typedText()
	case Lines, Wildcard:
		for _, line := range lines[:len(lines)-1] {
			m.input += line
			m.commitLine()
		}
		m.input += lines[len(lines)-1]
	default:
		m.input += strings.Join(lines, "")
		m.cursor = 0
	}
}

// typedText applies the text typed: a text field's value changes as it is typed.
func (m *Model) typedText() {
	f := &m.fields[m.focus]
	if f.Kind != Text {
		return
	}
	f.Values = nil
	if m.input != "" {
		f.Values = []string{m.input}
	}
	m.markStale(f.Key)
}

// commitLine adds the line being typed to a field of lines.
func (m *Model) commitLine() {
	if m.focus >= len(m.fields) || m.input == "" {
		return
	}
	f := &m.fields[m.focus]
	if f.Kind != Lines && f.Kind != Wildcard {
		return
	}
	f.Values = append(append([]string{}, f.Values...), m.input)
	m.input = ""
	m.changed(f.Key)
}

func (m *Model) list(k tea.KeyPressMsg, s string) tea.Cmd {
	f := &m.fields[m.focus]
	rows := m.filtered()
	if s == "space" && f.Kind == PickMany {
		if m.cursor < len(rows) {
			return m.flip(rows[m.cursor].Value)
		}
		return nil
	}
	if k.Text != "" && k.Mod&(tea.ModCtrl|tea.ModAlt) == 0 {
		m.input += k.Text
		m.cursor = 0
		return nil
	}
	switch s {
	case "backspace":
		if r := []rune(m.input); len(r) > 0 {
			m.input = string(r[:len(r)-1])
			m.cursor = 0
		} else if m.clears(*f) {
			f.Values = nil
			m.changed(f.Key)
		}
	case "up":
		if m.cursor > 0 {
			m.cursor--
			return nil
		}
		return m.move(-1)
	case "down":
		if m.cursor < len(rows)-1 {
			m.cursor++
			return nil
		}
		return m.move(1)
	case "pgup", "pgdown", "home", "end":
		m.cursor = paged(s, m.cursor, len(rows), listWindow-1)
	case "enter":
		if f.Kind == Pick && m.cursor < len(rows) {
			f.Values = []string{rows[m.cursor].Value}
			m.changed(f.Key)
		} else if m.failed[f.Key] && m.input != "" {
			return m.take()
		}
		return m.move(1)
	case "ctrl+n":
		if (f.Choices == "open" || m.failed[f.Key]) && m.input != "" {
			return m.take()
		}
	case "tab":
		return m.move(1)
	case "shift+tab":
		return m.move(-1)
	}
	return nil
}

// paged gives where a page key takes a cursor among n rows: page down and page up a page on, home and end to the first
// and the last row, never past either.
func paged(key string, cursor, n, page int) int {
	switch key {
	case "pgdown":
		cursor += page
	case "pgup":
		cursor -= page
	case "home":
		cursor = 0
	case "end":
		cursor = n - 1
	}
	return max(0, min(cursor, n-1))
}

// take makes what is typed the answer, as an open list does on ctrl-n and a list kit refused on Enter too: a pick's
// one value, and the keyboard moves on; one more value of a pick of many, and the keyboard stays.
func (m *Model) take() tea.Cmd {
	f := &m.fields[m.focus]
	kind := f.Kind
	if kind == Pick {
		f.Values = []string{m.input}
	} else {
		f.Values = append(append([]string{}, f.Values...), m.input)
	}
	m.input = ""
	m.changed(f.Key)
	if kind == Pick {
		return m.move(1)
	}
	return nil
}

// flip picks a value of a list of many, or unpicks it; a list whose rows carry state is asked again with the plan.
func (m *Model) flip(value string) tea.Cmd {
	f := &m.fields[m.focus]
	if i := index(f.Values, value); i >= 0 {
		f.Values = append(append([]string{}, f.Values[:i]...), f.Values[i+1:]...)
	} else {
		f.Values = append(append([]string{}, f.Values...), value)
	}
	key := f.Key
	m.changed(key)
	if stateful(m.lists[key]) {
		return m.fetch(key, value)
	}
	return nil
}

// choices takes a list's rows. A list kit calls a set, empty, starts from the values active now, so the command line
// is the whole set; a row the verb has a line about, flipped off, is flipped back on with that line
// shown, since the verb keeps it anyway. A list kit refused shows kit's line as the note, and takes what is typed.
// Rows asked for before another answer changed are kept, and stay stale, so the list asks again when it is next
// entered.
func (m *Model) choices(msg choicesMsg) {
	m.lists[msg.key] = msg.rows
	m.sets[msg.key] = msg.set
	m.stale[msg.key] = !slices.Equal(msg.asked, m.others(msg.key))
	m.failed[msg.key] = msg.err != nil
	if msg.err != nil {
		m.note = msg.err.Error()
		return
	}
	i := m.fieldOf(msg.key)
	if i < 0 {
		return
	}
	f := &m.fields[i]
	if f.Kind == PickMany && msg.set && len(f.Values) == 0 && !m.seeded[msg.key] {
		for _, row := range msg.rows {
			if row.State == "active" {
				f.Values = append(f.Values, row.Value)
			}
		}
		m.rebuild(Collect(m.fields))
	}
	m.seeded[msg.key] = true
	if msg.flipped == "" {
		return
	}
	m.note = ""
	f = &m.fields[m.fieldOf(msg.key)]
	for _, row := range msg.rows {
		if row.Value == msg.flipped && row.Refusal != "" && index(f.Values, row.Value) < 0 {
			f.Values = append(append([]string{}, f.Values...), row.Value)
			m.note = row.Refusal
			m.rebuild(Collect(m.fields))
		}
	}
}

// fetch asks kit for a list's rows, with the answers as they stand, and, for closed choices, whether they are a set.
func (m *Model) fetch(key, flipped string) tea.Cmd {
	r, verb, answers, asked := m.runner, m.spec.Verb, m.answers(), m.others(key)
	closed := false
	if i := m.fieldOf(key); i >= 0 {
		closed = m.fields[i].Choices == "closed"
	}
	return func() tea.Msg {
		rows, err := r.Choices(verb, key, answers)
		set := false
		if err == nil && closed {
			kind, kindErr := r.Kind(verb, key, answers)
			set = kindErr == nil && kind == "set"
		}
		return choicesMsg{key: key, rows: rows, set: set, err: err, flipped: flipped, asked: asked}
	}
}

// others gives the answers but a list's own: what its rows may depend on.
func (m Model) others(key string) []string {
	var out []string
	for _, a := range m.answers() {
		if !strings.HasPrefix(a, key+"=") {
			out = append(out, a)
		}
	}
	return out
}

// answers gives the answers kit syntax takes after a --: each <key>=<value>, and the subcommand words chosen, which a
// verb's choices may depend on, as kit packages select's list does.
func (m Model) answers() []string {
	fields := m.viewFields()
	out := answerList(Collect(fields))
	for _, f := range fields {
		if f.Kind == OneOf && f.Chosen >= 0 {
			if word := f.Options[f.Chosen]; !strings.ContainsAny(word[:1], "-<") && !strings.Contains(word, " ") {
				out = append(out, word)
			}
		}
	}
	return out
}

// matchedMsg brings kit's judgment of the command line it was asked about.
type matchedMsg struct {
	args  []string
	match syntax.Match
	err   error
}

// tryRun asks kit, off the update loop, whether the command line is complete; matched takes the answer.
func (m *Model) tryRun() tea.Cmd {
	m.commitLine()
	r, verb, args := m.runner, m.spec.Verb, m.CommandLine()
	return func() tea.Msg {
		match, err := r.Match(verb, args)
		return matchedMsg{args: args, match: match, err: err}
	}
}

// matched runs the command line when kit judged it complete; otherwise it shows kit's line under the command line and
// takes the keyboard to the first field that needs an answer. An answer about a line that changed since is dropped:
// the person asks again.
func (m *Model) matched(msg matchedMsg) tea.Cmd {
	args, match, err := msg.args, msg.match, msg.err
	if !slices.Equal(args, m.CommandLine()) {
		return nil
	}
	if err != nil {
		m.refusal = err.Error()
		return nil
	}
	switch match.Status {
	case 0:
		m.run, m.done, m.args, m.refusal = true, true, args, ""
		return tea.Quit
	case 1:
		literals := ""
		if len(match.Literals) > 0 {
			literals = " " + strings.Join(match.Literals, " ")
		}
		m.refusal = fmt.Sprintf("kit %s%s needs %s; run: %s", m.spec.Verb, literals, match.Missing,
			fix.Here("kit help "+m.spec.Verb))
		if i := FirstEmptyRequired(m.fields); i >= 0 {
			m.focus = i
			return m.enter()
		}
		return nil
	}
	m.refusal = match.Refusal
	return nil
}

// changed rebuilds the fields from the answers after one of them changed.
func (m *Model) changed(key string) {
	m.markStale(key)
	m.rebuild(Collect(m.fields))
}

// markStale marks every other list to be asked again: its rows may depend on the answer that changed.
func (m *Model) markStale(changed string) {
	for key := range m.lists {
		if key != changed {
			m.stale[key] = true
		}
	}
}

// rebuild lays the fields out again from the answers, with the extension in place of the wildcard; a grammar that
// no longer lays out leaves the fields as they stand, with why as the note.
func (m *Model) rebuild(a Answers) {
	fields, err := Fields(m.spec, a)
	if err != nil {
		m.note = err.Error()
		return
	}
	if len(m.extOrder) > 0 {
		kept := fields[:0:0]
		for _, f := range fields {
			if f.Kind != Wildcard {
				kept = append(kept, f)
			}
		}
		for _, key := range m.extOrder {
			kept = append(kept, Field{Key: key, Label: "«" + strings.TrimPrefix(key, "--") + "»",
				Description: m.ext[key].Description, Kind: Text, Required: true, Chosen: -1, Group: -1,
				Values: a.Options[key]})
		}
		fields = kept
	}
	m.fields = fields
	if m.focus > len(m.fields) {
		m.focus = len(m.fields)
	}
}

// refreshExtension asks kit for the arguments the answers add, once per set of answers kit answered; kit's refusal is
// the focused field's note, and the next field asks again.
func (m *Model) refreshExtension() {
	answers := m.answers()
	seen := strings.Join(answers, "\x00")
	if m.extSeen[seen] {
		return
	}
	order, args, err := m.runner.Extend(m.spec.Verb, answers)
	if err != nil {
		m.note = err.Error()
		return
	}
	m.extSeen[seen] = true
	m.extOrder, m.ext = order, args
}

// viewFields gives the fields with the line being typed counted, as the command line shows it.
func (m Model) viewFields() []Field {
	if m.focus >= len(m.fields) || m.input == "" {
		return m.fields
	}
	f := m.fields[m.focus]
	if f.Kind != Lines && f.Kind != Wildcard {
		return m.fields
	}
	fields := append([]Field{}, m.fields...)
	fields[m.focus].Values = append(append([]string{}, f.Values...), m.input)
	return fields
}

// fieldOf gives the index of the field with the key, or -1.
func (m *Model) fieldOf(key string) int {
	for i, f := range m.fields {
		if f.Key == key {
			return i
		}
	}
	return -1
}

// filtered gives the focused list's rows that hold the text typed, ignoring case.
func (m Model) filtered() []kit.Choice {
	if m.focus >= len(m.fields) {
		return nil
	}
	rows := m.lists[m.fields[m.focus].Key]
	if m.input == "" {
		return rows
	}
	needle := strings.ToLower(m.input)
	var out []kit.Choice
	for _, row := range rows {
		if strings.Contains(strings.ToLower(row.Value), needle) {
			out = append(out, row)
		}
	}
	return out
}

// expand draws the focused field live: the text with its caret, the lines with the one being typed, or the list, and
// gives the line of the list's cursor, -1 for none. Text wider than the screen shows its end, after a …, so the caret
// stays in sight.
func (m Model) expand(i int, indent string) (string, int) {
	if i != m.focus || i >= len(m.fields) {
		return "", -1
	}
	f := m.fields[i]
	at := -1
	room := m.width - ansi.StringWidth(indent) - 2 // the caret, and the cell the screen keeps at its edge
	var b strings.Builder
	switch f.Kind {
	case Text:
		b.WriteString(indent + pane.Tail(m.input, room) + "▏\n")
	case Lines, Wildcard:
		for _, v := range f.Values {
			b.WriteString(indent + pane.Clip(v, room+1) + "\n")
		}
		b.WriteString(indent + pane.Tail(m.input, room) + "▏\n")
		m.hint(&b, indent, "⏎ another line · an empty line ends the list")
	case Pick, PickMany:
		at = m.drawList(&b, f, indent)
	}
	return b.String(), at
}

// drawList draws a list: the filter, a window of rows around the cursor with their marks, a dim line for the rows it
// hides above and one for those below, and the count; the note follows, drawn under the field. A list kit refused
// draws the values taken so far and says it takes what is typed. It gives the line of the cursor's row, -1 for none.
func (m Model) drawList(b *strings.Builder, f Field, indent string) int {
	room := m.width - ansi.StringWidth(indent) - 4 // the filter glyph, its space, the caret, and the screen's edge
	b.WriteString(indent + style.Filter + " " + pane.Tail(m.input, room) + "▏\n")
	all := m.lists[f.Key]
	rows := m.filtered()
	if all == nil {
		switch {
		case m.failed[f.Key] && f.Kind == PickMany:
			for _, v := range f.Values {
				b.WriteString(indent + style.Picked + " " + v + "\n")
			}
			m.hint(b, indent, "⏎ takes what is typed · an empty line ends the list")
		case m.failed[f.Key]:
			for _, v := range f.Values {
				b.WriteString(indent + v + "\n")
			}
			m.hint(b, indent, "⏎ takes what is typed")
		default:
			b.WriteString(indent + style.Off("…") + "\n")
		}
		return -1
	}
	if len(rows) == 0 {
		b.WriteString(indent + style.Off("nothing matches") + "\n")
	}
	span := m.span()
	start, end, at := span.Start, span.End, -1
	if span.Above {
		b.WriteString(pane.Above(start) + "\n")
	}
	widest := 0
	for _, row := range rows[start:end] {
		if n := ansi.StringWidth(row.Value); n > widest {
			widest = n
		}
	}
	planned := m.sets[f.Key]
	states := stateful(all)
	room = m.width - len(indent) - widest - 8
	for k := start; k < end; k++ {
		row := rows[k]
		picked := index(f.Values, row.Value) >= 0
		mark := ""
		switch {
		case planned:
			mark = plan(row, picked) + " "
		case f.Kind == PickMany && picked:
			mark = style.Picked + " "
		case f.Kind == PickMany:
			mark = style.Unpicked + " "
		}
		if states && !planned {
			mark += state(row) + " "
		}
		lead := "  "
		value := row.Value + strings.Repeat(" ", widest-ansi.StringWidth(row.Value))
		if k == m.cursor {
			lead, value = style.Focus+" ", style.Chosen(row.Value)+strings.Repeat(" ", widest-ansi.StringWidth(row.Value))
			at = strings.Count(b.String(), "\n")
		}
		b.WriteString(indent[:len(indent)-2] + lead + mark + value + "  " + style.Off(pane.Clip(row.Description, room)) + "\n")
	}
	if span.Below {
		b.WriteString(pane.More(len(rows)-end) + "\n")
	}
	glyphs := ""
	if named := statesLegend(all, f.Values, planned); states && named != "" {
		glyphs = named + " · "
	}
	switch {
	case f.Kind == PickMany && planned:
		add, remove := 0, 0
		for _, row := range all {
			picked := index(f.Values, row.Value) >= 0
			if picked && row.State != "active" {
				add++
			} else if !picked && row.State == "active" {
				remove++
			}
		}
		m.hint(b, indent, fmt.Sprintf("%s %d to add · %s %d to remove · %s␣ flips · type to filter", style.Add, add,
			style.Remove, remove, glyphs))
	case f.Kind == PickMany:
		m.hint(b, indent, fmt.Sprintf("%d of %d picked · %s␣ pick · type to filter", len(f.Values), len(all), glyphs))
	case f.Choices == "open":
		m.hint(b, indent, glyphs+"⏎ takes it · ctrl-n takes what is typed · type to filter")
	default:
		m.hint(b, indent, glyphs+"⏎ takes it · type to filter")
	}
	return at
}

// statesLegend names, once, each state glyph the list's rows draw, active then excluded: in a list kit calls a set, among
// the marks plan gives, whose ➕ and ➖ the counts name; else among the states state gives.
func statesLegend(all []kit.Choice, values []string, planned bool) string {
	drawn := map[string]bool{}
	for _, row := range all {
		if planned {
			drawn[plan(row, index(values, row.Value) >= 0)] = true
		} else {
			drawn[state(row)] = true
		}
	}
	var out []string
	for _, g := range []struct{ glyph, meaning string }{{style.Active, "active"}, {style.Excluded, "excluded"}} {
		if drawn[g.glyph] {
			out = append(out, g.glyph+" "+g.meaning)
		}
	}
	return strings.Join(out, " · ")
}

// hint writes a line of keys under a field, dim, wrapped to the width left beside the indent.
func (m Model) hint(b *strings.Builder, indent, text string) {
	for _, line := range pane.Wrap(text, m.width-len(indent)) {
		b.WriteString(indent + style.Off(line) + "\n")
	}
}

// state gives a row's state as kit packages draws it: ✅ active, ❌ excluded, or blank.
func state(row kit.Choice) string {
	switch row.State {
	case "active":
		return style.Active
	case "excluded":
		return style.Excluded
	}
	return "  "
}

// plan gives a row's mark in a list kit calls a set: what it is now against what the command line will make it.
func plan(row kit.Choice, picked bool) string {
	switch {
	case picked && row.State == "active":
		return style.Active
	case picked:
		return style.Add
	case row.State == "active":
		return style.Remove
	case row.State == "excluded":
		return style.Excluded
	}
	return "  "
}

// stateful says whether any row carries a state or a line.
func stateful(rows []kit.Choice) bool {
	for _, row := range rows {
		if row.State != "" || row.Refusal != "" {
			return true
		}
	}
	return false
}

// answerList gives the answers as kit syntax takes them after a --: each <key>=<value>, in key order.
func answerList(a Answers) []string {
	var out []string
	for _, source := range []map[string][]string{a.Options, a.Values} {
		keys := make([]string, 0, len(source))
		for key := range source {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			for _, value := range source[key] {
				out = append(out, key+"="+value)
			}
		}
	}
	return out
}

// index gives the position of a value among values, or -1.
func index(values []string, value string) int {
	for i, v := range values {
		if v == value {
			return i
		}
	}
	return -1
}
