// The issues' actions run kit's verbs on the issues selected there, each after its dialog asks for an answer or a
// yes, by enter or a click on its button; the keys bar says what kit did, or why it refused.
package flow

import (
	"fmt"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
	"github.com/empowerite/kit/projects/tui/internal/table"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// item gives the line of the tab's menu named, or -1.
func item(m Model, name string) int {
	return slices.IndexFunc(m.tabItems(), func(i shell.Item) bool { return i.Name == name })
}

// choose opens the tab's menu and chooses the item named, as enter on it does.
func choose(t *testing.T, m Model, name string) Model {
	t.Helper()
	m = drive(m, press(':'))
	k := item(m, name)
	if k < 0 || !m.enabled(k) {
		t.Fatalf("%s is not in the menu, or dim: %d", name, k)
	}
	m.tabMenu.At = k
	return drive(m, press(tea.KeyEnter))
}

// confirmed chooses the item named, which asks first, and answers its dialog with enter.
func confirmed(t *testing.T, m Model, name string) Model {
	t.Helper()
	if m = choose(t, m, name); m.ask == nil {
		t.Fatalf("%s did not ask", name)
	}
	return drive(m, press(tea.KeyEnter))
}

// drawnAt gives the screen cell a text starts at, as the screen draws it.
func drawnAt(t *testing.T, m Model, text string) (x, y int) {
	t.Helper()
	for y, l := range strings.Split(raw(m), "\n") {
		if at := cellsOf(l, text); len(at) > 0 {
			return at[0], y
		}
	}
	t.Fatalf("the screen does not draw %q:\n%s", text, view(m))
	return 0, 0
}

// acted gives the calls of the verbs that act, as fake-kit recorded them, the stages' loads left out.
func acted(t *testing.T, record string) []string {
	t.Helper()
	var out []string
	for _, c := range calls(t, record) {
		if !strings.HasPrefix(c, "flow ") {
			out = append(out, c)
		}
	}
	return out
}

// selecting gives the picture loaded with two of issues' backlog selected, recording kit's calls.
func selecting(t *testing.T) (Model, string) {
	t.Helper()
	record := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_FLOW_CALLS", record)
	m := loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 40}, down)
	m.stages[0].Picked["#45"], m.stages[0].Picked["#46"] = true, true
	if got := m.refs(); !slices.Equal(got, []string{"#46", "#45"}) {
		t.Fatalf("selected: %q", got)
	}
	return m, record
}

func TestTheIssuesActionsAreInItsMenuDimUntilIssuesAreSelected(t *testing.T) {
	m := loaded(t, options(), down)
	for _, name := range []string{"Start Local Work for Each", "Assign to Me", "Close as Not Planned", "Copy Links"} {
		if k := item(m, name); k < 0 || m.enabled(k) {
			t.Errorf("%s with nothing selected: line %d, not dim", name, k)
		}
	}
	// New… files an issue, and needs none selected
	if k := item(m, "New…"); k < 0 || !m.enabled(k) {
		t.Errorf("New… with nothing selected: line %d, dim", k)
	}
	m, _ = selecting(t)
	names := []string{"New…", "Start Local Work for Each", "Start Local Work Together…", "Add to Pull Request…", "Assign to Me",
		"Assign to…", "Unassign", "Gather Under a Parent…", "Close as Not Planned", "Close as Duplicate of…",
		"Copy Links", OpenPage}
	if got := m.tabItems()[len(m.tabItems())-len(names):]; !slices.EqualFunc(got, names,
		func(i shell.Item, n string) bool { return i.Name == n }) || m.tabItems()[len(m.tabItems())-len(names)-1].Name != "" {
		t.Errorf("the last section: %+v", got)
	}
	// another tab offers none of them, even with rows selected there
	m = drive(m, esc, tab, down, press(tea.KeySpace))
	if item(m, "Assign to Me") >= 0 {
		t.Error("changes offers the issues' actions")
	}
}

// Assign to Me writes to the forge, so it asks first: its dialog says what it will do, lists each issue, names the
// repository they are in, and has the button that does it and Cancel; kit runs on enter, and not before.
func TestAssignToMeAsksFirstThenRunsKitAndTheKeysBarSaysWhatItDid(t *testing.T) {
	m, record := selecting(t)
	// its key alone asks too
	if byKey := drive(m, tea.KeyPressMsg{Code: 'a', Text: "a"}); byKey.ask == nil || len(acted(t, record)) != 0 {
		t.Errorf("a ran %q before it asked: %+v", acted(t, record), byKey.ask)
	}
	m = choose(t, m, "Assign to Me")
	if got := acted(t, record); m.ask == nil || len(got) != 0 {
		t.Fatalf("Assign to Me ran %q before it asked: %+v", got, m.ask)
	}
	v := view(m)
	for _, want := range []string{"─ Assign these issues to you? ─", "│ #46 A noun lists, a noun with a verb acts",
		"│ #45 kit flow is the one picture", "│ in empowerite/kit", "│  ⏎ Assign    esc Cancel "} {
		if !strings.Contains(v, want) {
			t.Errorf("the dialog does not say %q:\n%s", want, v)
		}
	}
	if last := lines(m)[len(lines(m))-1]; !strings.Contains(last, "esc cancel ⏎ assign") {
		t.Errorf("the dialog's keys: %q", last)
	}
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"assign #46 #45"}) {
		t.Fatalf("the calls: %q", got)
	}
	last := lines(m)[len(lines(m))-1]
	if !strings.Contains(last, "✅ kit assign #46 #45") || m.selected() != 0 || strings.Contains(m.View().Content,
		style.Refusal("✅")) {
		t.Errorf("after assign: %q, %d selected", last, m.selected())
	}
	// what reads the forge's issues read them again
	if got := calls(t, record); !slices.ContainsFunc(got, func(c string) bool {
		return strings.HasPrefix(c, "flow issues --json") && strings.Contains(c, "--fresh")
	}) {
		t.Errorf("issues were not read afresh: %q", got)
	}
}

// An issue underway is acted on as one in the backlog is, by its number: the rows of one issue two pull requests close
// stand for it once.
func TestAnIssueUnderwayIsActedOnByItsNumberOnce(t *testing.T) {
	m, record := selecting(t)
	m.stages[0].Picked = map[string]bool{"#45": true, "#8 #4": true, "#8 #11": true}
	if got := m.refs(); !slices.Equal(got, []string{"#8", "#45"}) {
		t.Fatalf("selected: %q", got)
	}
	// the dialog lists it once too
	if asking := choose(t, m, "Assign to Me"); len(asking.ask.changes) != 2 ||
		asking.ask.changes[0] != "#8 Lint the modules" || !strings.HasPrefix(asking.ask.changes[1], "#45 kit flow is") {
		t.Errorf("the dialog lists %q", asking.ask.changes)
	}
	if m = confirmed(t, m, "Assign to Me"); !slices.Equal(acted(t, record), []string{"assign #8 #45"}) {
		t.Errorf("the calls: %q", acted(t, record))
	}
	if member, ref := refOf("github.com/o/a #8 #4"); member != "github.com/o/a" || ref != "#8" {
		t.Errorf("a member's issue underway: %q %q", member, ref)
	}
	// an issue issues do not hold has no title
	if got := m.issueTitle("", "#8"); got != "Lint the modules" || m.issueTitle("", "#99") != "" {
		t.Errorf("the titles: %q", got)
	}
}

// Start Local Work for Each asks first, and says what kit work makes of each issue; on enter it runs kit work once
// per issue, and the notice says how many commands ran.
func TestStartForEachAsksFirstThenRunsKitWorkOncePerIssue(t *testing.T) {
	m, record := selecting(t)
	m = choose(t, m, "Start Local Work for Each")
	if got := acted(t, record); m.ask == nil || len(got) != 0 {
		t.Fatalf("Start Local Work for Each ran %q before it asked: %+v", got, m.ask)
	}
	// what kit work makes is wrapped under the issues, so it is read as one text
	v := m.ask.title + " " + ansi.Strip(strings.Join(m.askBody(), " "))
	for _, want := range []string{"Start local work on each of these issues?", " #46 A noun lists", " #45 kit flow is",
		"in empowerite/kit", "kit work makes a branch, a worktree, a start commit, and a draft pull request for each",
		"assigns the issue to you", "moves the desk's uncommitted work into the first worktree",
		"⏎ Start    esc Cancel"} {
		if !strings.Contains(v, want) {
			t.Errorf("the dialog does not say %q:\n%s", want, view(m))
		}
	}
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"work --sweep #46", "work --sweep #45"}) {
		t.Errorf("the calls: %q", got)
	}
	if last := lines(m)[len(lines(m))-1]; !strings.Contains(last, "✅ kit work --sweep #45, the last of 2 commands") {
		t.Errorf("the notice after two commands: %q", last)
	}
}

// The dialog fits a screen 80 columns wide: none of its lines is cut.
func TestTheDialogFitsEightyColumns(t *testing.T) {
	m, _ := selecting(t)
	m = drive(m, tea.WindowSizeMsg{Width: 80, Height: 24})
	for _, name := range []string{"Start Local Work for Each", "Start Local Work Together…", "Add to Pull Request…"} {
		m.me = "ada"
		m = choose(t, m, name)
		// an issue's line, or a pull request's, is cut where its title is long; what the dialog says itself never is
		for _, l := range m.askBox().Lines {
			if l = ansi.Strip(l); !strings.Contains(l, "#") && strings.Contains(l, "…") {
				t.Errorf("%s: a line of the dialog is cut at 80 columns: %q", name, l)
			}
		}
		m = drive(m, esc)
	}
}

// The dialog's buttons take a plain click: one on the button that does it runs kit, as enter does; one on Cancel,
// or off the dialog, runs nothing and keeps the selection, as esc does; one elsewhere on the dialog, and one with
// another button, leaves it asking.
func TestTheDialogsButtonsTakeAPlainClick(t *testing.T) {
	m, record := selecting(t)
	m = choose(t, m, "Assign to Me")
	x, y := drawnAt(t, m, "⏎ Assign")
	cancelX, _ := drawnAt(t, m, "esc Cancel")
	box := m.askBox()
	for name, c := range map[string]tea.Msg{
		"a click on an issue's line":       testkit.Click(box.Left+3, box.Top+1),
		"a click on the dialog's top edge": testkit.Click(box.Left+3, box.Top),
		"a click between the buttons":      testkit.Click(cancelX-2, y),
		"a click after Cancel":             testkit.Click(cancelX+len("esc Cancel")+1, y),
		"a right click on the button":      tea.MouseClickMsg{X: x, Y: y, Button: tea.MouseRight},
		"a right click off the dialog":     tea.MouseClickMsg{X: 0, Y: y, Button: tea.MouseRight},
	} {
		if m = drive(m, c); m.ask == nil || len(acted(t, record)) != 0 {
			t.Fatalf("%s: asking %v, kit ran %q", name, m.ask != nil, acted(t, record))
		}
	}
	// Cancel: on the cell before its name, on its last cell
	for _, at := range []int{cancelX - 1, cancelX + len("esc Cancel")} {
		if got := drive(m, testkit.Click(at, y)); got.ask != nil || len(acted(t, record)) != 0 || got.selected() != 2 {
			t.Errorf("a click on Cancel at %d: asking %v, kit ran %q, %d selected", at, got.ask != nil,
				acted(t, record), got.selected())
		}
		m = choose(t, drive(m, esc), "Assign to Me")
	}
	// off the dialog
	if got := drive(m, testkit.Click(0, y)); got.ask != nil || len(acted(t, record)) != 0 || got.selected() != 2 {
		t.Errorf("a click off the dialog: asking %v, kit ran %q", got.ask != nil, acted(t, record))
	}
	// the button that does it: on the cell before its key, as the button starts there
	m = choose(t, drive(m, esc), "Assign to Me")
	m = drive(m, testkit.Click(x-1, y))
	if got := acted(t, record); m.ask != nil || !slices.Equal(got, []string{"assign #46 #45"}) {
		t.Errorf("a click on Assign: asking %v, kit ran %q", m.ask != nil, got)
	}
}

// One issue is named as one, in every dialog.
func TestADialogNamesOneIssueAsOne(t *testing.T) {
	m, _ := selecting(t)
	delete(m.stages[0].Picked, "#45")
	m.me = "ada"
	for name, title := range map[string]string{
		"Start Local Work for Each":  "Start local work on this issue?",
		"Start Local Work Together…": "Start local work on this issue under a new parent issue titled",
		"Add to Pull Request…":       "Add this issue to which of your pull requests?",
		"Assign to Me":               "Assign this issue to you?",
		"Assign to…":                 "Assign this issue to which login?",
		"Unassign":                   "Take yourself off this issue?",
		"Gather Under a Parent…":     "Gather this issue under a new parent issue titled",
		"Close as Not Planned":       "Close this issue as not planned?",
		"Close as Duplicate of…":     "Close this issue as a duplicate of which issue?",
	} {
		if got := choose(t, m, name); got.ask == nil || got.ask.title != title {
			t.Errorf("%s on one issue asks %+v, want %q", name, got.ask, title)
		}
	}
}

// A list longer than the screen has room for is cut, its last line saying how many more it holds, and the buttons
// stay on the screen, over the keys bar; on a screen with room for one line of it, that line says how many in all.
func TestAListTooLongForTheScreenIsCutAndKeepsTheButtons(t *testing.T) {
	m, _ := selecting(t)
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 24})
	// every issue of the repository here, one of them a row for each of its two pull requests, listed once
	clear(m.stages[0].Picked)
	m = drive(m, tea.KeyPressMsg{Code: 'a', Mod: tea.ModCtrl})
	delete(m.stages[0].Picked, "empowerite/jig#7")
	n := len(m.refs())
	m = choose(t, m, "Close as Not Planned")
	box := m.askBox()
	if n < 5 || len(m.ask.changes) != n || box.Top+len(box.Lines) > m.height-1 {
		t.Fatalf("%d selected, the dialog lists %d, on lines %d to %d of %d", n, len(m.ask.changes), box.Top,
			box.Top+len(box.Lines)-1, m.height)
	}
	if v := view(m); !strings.Contains(v, "⏎ Close    esc Cancel") || strings.Contains(v, " more") {
		t.Errorf("the dialog at 24 lines:\n%s", v)
	}
	// two lines fewer than the whole dialog takes: the list gives up three issues for the line that says so
	short := m.askTop() + len(box.Lines) + 1 - 2
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: short})
	box = m.askBox()
	if v := view(m); box.Top+len(box.Lines) != m.height-1 || !strings.Contains(v, "│ and 3 more") ||
		!strings.Contains(v, "⏎ Close    esc Cancel") || !strings.Contains(v, "│ in empowerite/kit") {
		t.Errorf("the dialog at %d lines, on lines %d to %d:\n%s", short, box.Top, box.Top+len(box.Lines)-1, v)
	}
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: m.askTop() + 7})
	if v := view(m); !strings.Contains(v, fmt.Sprintf("│ %d in all", n)) ||
		!strings.Contains(v, "⏎ Close    esc Cancel") {
		t.Errorf("the dialog with room for one line of its list:\n%s", v)
	}
}

func TestAClosingActionListsTheIssuesAndRunsOnlyOnYes(t *testing.T) {
	m, record := selecting(t)
	m = choose(t, m, "Close as Not Planned")
	v := view(m)
	if m.ask == nil || !strings.Contains(v, "Close these issues as not planned?") || !strings.Contains(v, "#45 ") ||
		!strings.Contains(v, "#46 ") || !strings.Contains(lines(m)[len(lines(m))-1], "esc cancel ⏎ close") {
		t.Fatalf("the dialog:\n%s", v)
	}
	// esc runs nothing, and keeps the selection
	if m = drive(m, esc); m.ask != nil || len(acted(t, record)) != 0 || m.selected() != 2 {
		t.Fatalf("esc: ask %v, calls %q", m.ask, acted(t, record))
	}
	m = choose(t, m, "Close as Not Planned")
	m = drive(m, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"close --not-planned #46 #45"}) {
		t.Errorf("the calls: %q", got)
	}
	if m = drive(m, typed("x")...); strings.Contains(lines(m)[len(lines(m))-1], "kit close") {
		t.Error("a key did not take the notice away")
	}
}

func TestAnActionThatAsksTakesTheTypedAnswer(t *testing.T) {
	for _, c := range []struct{ name, answer, want string }{
		{"Start Local Work Together…", "The plan", "work --sweep --title=The plan #46 #45"},
		{"Gather Under a Parent…", "The plan", "gather --title=The plan #46 #45"},
		{"Assign to…", "bob", "assign --to=bob #46 #45"},
		{"Close as Duplicate of…", "#7", "close --duplicate-of=#7 #46 #45"},
	} {
		m, record := selecting(t)
		m = choose(t, m, c.name)
		if m.ask == nil || !m.ask.typing {
			t.Fatalf("%s does not ask", c.name)
		}
		// the dialog lists the issues it will change under the line typed, and where they are
		if v := view(m); !strings.Contains(v, "│ #46 A noun lists") || !strings.Contains(v, "│ #45 kit flow is") ||
			!strings.Contains(v, "│ in empowerite/kit") {
			t.Errorf("%s does not list the issues:\n%s", c.name, v)
		}
		// enter with nothing typed waits, as a click on its button does, which is dim until then
		x, y := drawnAt(t, m, "⏎ "+m.ask.does)
		if !strings.Contains(m.View().Content, style.Off(m.ask.doButton())) {
			t.Errorf("%s: the button that waits is not dim", c.name)
		}
		if m = drive(m, press(tea.KeyEnter), testkit.Click(x, y)); m.ask == nil || len(acted(t, record)) != 0 {
			t.Fatalf("%s ran with nothing typed", c.name)
		}
		m = drive(m, typed(c.answer+"x")...)
		m = drive(m, press(tea.KeyBackspace))
		if !strings.Contains(view(m), c.answer+"▏") {
			t.Errorf("%s: the typed line:\n%s", c.name, view(m))
		}
		m = drive(m, press(tea.KeyEnter))
		if got := acted(t, record); !slices.Equal(got, []string{c.want}) {
			t.Errorf("%s: the calls %q", c.name, got)
		}
	}
}

func TestAddToPullRequestPicksOneOfTheCallersOwn(t *testing.T) {
	m, record := selecting(t)
	m.me = "ada"
	numbers, _ := m.mine()
	if len(numbers) == 0 {
		t.Fatal("the fixture has no pull request of ada's")
	}
	m = choose(t, m, "Add to Pull Request…")
	if v := view(m); m.ask == nil || m.ask.pick == nil ||
		!strings.Contains(v, "Add these issues to which of your pull requests?") ||
		!strings.Contains(v, "│ #46 A noun") ||
		!strings.Contains(v, "kit work assigns each issue to you, and the pull request closes it.") ||
		!strings.Contains(lines(m)[len(lines(m))-1], "esc cancel ↑↓ move ⏎ add") {
		t.Fatalf("the dialog:\n%s", v)
	}
	m = drive(m, up, down, up, press(tea.KeyEnter))
	if got := acted(t, record); !slices.Equal(got, []string{"work --pr=" + strconv.Itoa(numbers[0]) + " #46 #45"}) {
		t.Errorf("the calls: %q", got)
	}
	// someone with no open pull request has nothing to add to: the item is dim
	m.me = "nobody"
	m.stages[0].Picked["#45"] = true
	m = drive(m, press(':'))
	if k := item(m, "Add to Pull Request…"); k < 0 || m.enabled(k) {
		t.Errorf("add to pull request for a caller with none: %d", k)
	}
}

func TestARefusalStaysInTheKeysBarAndKeepsTheSelection(t *testing.T) {
	m, _ := selecting(t)
	t.Setenv("FAKE_FLOW_REFUSE", "unassign")
	m = choose(t, m, "Unassign")
	m = drive(m, press(tea.KeyEnter))
	last := lines(m)[len(lines(m))-1]
	if !strings.Contains(last, Failed+" kit unassign refuses for the test") || m.note.Done || m.selected() != 2 {
		t.Errorf("the refusal: %q, %d selected", lines(m)[len(lines(m))-1], m.selected())
	}
}

func TestCopyLinksCopiesEachIssueAsMarkdown(t *testing.T) {
	m, _ := selecting(t)
	if got := m.links(); !strings.HasPrefix(got, "- [#46 ") || !strings.Contains(got, "](https://") ||
		strings.Count(got, "\n") != 1 {
		t.Errorf("the links: %q", got)
	}
	m = drive(m, press(':'))
	m.tabMenu.At = item(m, "Copy Links")
	next, cmd := m.Update(press(tea.KeyEnter))
	if m = next.(Model); cmd == nil || !strings.Contains(ansi.Strip(lines(m)[len(lines(m))-1]), "copied 2 links") {
		t.Errorf("copy links: %q", lines(m)[len(lines(m))-1])
	}
	// an issue kit printed no page for is its reference and title alone
	m = New(runner(t), Options{Stages: []string{"issues"}, NoPresets: true, Clock: &testkit.Clock{}})
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 24},
		answer("issues", `[{"number": 7, "title": "seven"}]`))
	m.stages[0].Picked["#7"] = true
	if got := m.links(); got != "- #7 seven" {
		t.Errorf("the link of an issue with no page: %q", got)
	}
}

// A menu taller than the screen's room scrolls with the keyboard: it ends above the keys bar, marks the items above
// and below it, and a click picks the item it shows there.
func TestATallMenuScrollsWithTheKeyboardAndAClickPicksWhatItShows(t *testing.T) {
	m := loaded(t, options(), tea.WindowSizeMsg{Width: 120, Height: 16}, down)
	m.stages[0].Picked["#45"] = true
	m = drive(m, press(':'))
	box, _, first := m.menuBoxIn()
	if len(box) != 16-1-m.menuTop() || first != 0 || !strings.Contains(ansi.Strip(box[len(box)-1]), "▾") ||
		strings.Contains(ansi.Strip(box[0]), "▴") {
		t.Fatalf("the menu at the top: %d lines, first %d\n%s", len(box), first, view(m))
	}
	m.tabMenu.At = item(m, OpenPage)
	box, left, first := m.menuBoxIn()
	if first == 0 || !strings.Contains(ansi.Strip(box[0]), "▴") || strings.Contains(ansi.Strip(box[len(box)-1]), "▾") {
		t.Errorf("the menu at the end: first %d\n%s", first, view(m))
	}
	// a click on the line that shows Assign to Me picks it
	k := item(m, "Assign to Me")
	record := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FAKE_FLOW_CALLS", record)
	if m = drive(m, testkit.Click(left+3, m.menuTop()+1+k-first)); m.ask == nil || m.ask.does != "Assign" {
		t.Fatalf("a click on Assign to Me: %+v", m.ask)
	}
	if m = drive(m, press(tea.KeyEnter)); !slices.Equal(acted(t, record), []string{"assign #45"}) {
		t.Errorf("enter on the dialog: %q", acted(t, record))
	}
	// a click on the box's bottom edge picks nothing
	m = drive(m, press(':'))
	box, left, _ = m.menuBoxIn()
	if m = drive(m, testkit.Click(left+3, m.menuTop()+len(box)-1)); m.tabMenu.Open || len(acted(t, record)) != 1 {
		t.Errorf("a click on the edge: menu %v, calls %q", m.tabMenu.Open, acted(t, record))
	}
}

// New… asks kit for the trackers, and offers those that give a page, each its prefix and where, the forge's own under
// the keyboard; enter opens the page picked. A tracker with no page is left
// out, and kit's refusal to list them is in place of the keys.
func TestNewOffersTheTrackersAndOpensThePagePicked(t *testing.T) {
	m := loaded(t, options(), down)
	var opened []string
	m.browse = func(url string) error { opened = append(opened, url); return nil }
	m = choose(t, m, "New…")
	if m.ask == nil || m.ask.title != "New issue in which tracker?" || m.ask.at != 0 ||
		!slices.Equal(m.ask.lines, []string{"#  github empowerite/kit", "AB#  ado Claims Team"}) {
		t.Fatalf("the dialog: %+v", m.ask)
	}
	if last := lines(m)[len(lines(m))-1]; !strings.Contains(last, "⏎ open") ||
		!strings.Contains(raw(m), "AB#  ado Claims Team") || !strings.Contains(raw(m), "│  ⏎ Open    esc Cancel ") {
		t.Errorf("the dialog's keys: %q\n%s", last, raw(m))
	}
	// a click on a line puts the keyboard on it, and one on the button opens the page picked
	x, y := drawnAt(t, m, "AB#  ado Claims Team")
	if byClick := drive(m, testkit.Click(x, y)); byClick.ask == nil || byClick.ask.at != 1 || len(opened) != 0 {
		t.Errorf("a click on AB#: %+v, opened %q", byClick.ask, opened)
	}
	x, y = drawnAt(t, m, "⏎ Open")
	if byClick := drive(m, testkit.Click(x, y)); byClick.ask != nil ||
		!slices.Equal(opened, []string{"https://dev.azure.com/example/Claims%20Team/_workitems/create/Task"}) {
		t.Errorf("a click on Open: opened %q, dialog %+v", opened, byClick.ask)
	}
	// the dialog asked again, from its first line
	opened = nil
	if m = choose(t, drive(m, esc), "New…"); m.ask == nil || m.ask.at != 0 {
		t.Fatalf("the dialog asked again: %+v", m.ask)
	}
	if m = drive(m, down, press(tea.KeyEnter)); m.ask != nil ||
		!slices.Equal(opened, []string{"https://dev.azure.com/example/Claims%20Team/_workitems/create/Task"}) {
		t.Errorf("enter on AB#: opened %q, dialog %+v", opened, m.ask)
	}
	// no tracker with a page, or kit's refusal, is said in place of the keys
	trackers, err := m.runner.Trackers(m.ctx)
	if err != nil || len(trackers) != 3 {
		t.Fatalf("the trackers: %+v, %v", trackers, err)
	}
	if m.newIssue(trackersMsg{trackers: trackers[2:]}); m.ask != nil || !strings.Contains(m.note.Text, "the BZ# tracker has no new page") {
		t.Errorf("no tracker with a page: %q", m.note.Text)
	}
	t.Setenv("FAKE_FLOW_REFUSE", "new")
	if m = choose(t, m, "New…"); m.ask != nil || !strings.Contains(lines(m)[len(lines(m))-1], "the forge cannot be read") {
		t.Errorf("a refusal: %+v, %q", m.ask, lines(m)[len(lines(m))-1])
	}
}

// overMembers gives the picture over a group of a and b, each cloned at a directory of its own, issues loaded with an
// issue of each, and the file each call's directory and words are recorded in, and the two directories, as pwd -P
// gives them.
func overMembers(t *testing.T) (Model, string, string, string) {
	t.Helper()
	dirs := filepath.Join(t.TempDir(), "dirs")
	t.Setenv("FAKE_FLOW_DIRS", dirs)
	a, _ := filepath.EvalSymlinks(t.TempDir())
	b, _ := filepath.EvalSymlinks(t.TempDir())
	ws := group
	ws.Members = []kit.WorkspaceMember{{Repository: "github.com/o/a", Checkout: a},
		{Repository: "github.com/o/b", Checkout: b}}
	m := over(t, "issues", "changes")
	m = drive(m, shell.WorkspaceMsg{Workspace: ws}, answer("issues", twoMembers),
		tea.WindowSizeMsg{Width: 120, Height: 40})
	return m, dirs, a, b
}

// ranIn gives the calls the fake recorded that are not the stages' reads, each its directory, a tab, and its words.
func ranIn(t *testing.T, dirs string) []string {
	t.Helper()
	var out []string
	for _, c := range calls(t, dirs) {
		if _, words, _ := strings.Cut(c, "\t"); !strings.HasPrefix(words, "flow ") {
			out = append(out, c)
		}
	}
	return out
}

func TestAssignToMeRunsOnceInEachMember(t *testing.T) {
	m, dirs, a, b := overMembers(t)
	m.stages[0].Picked["github.com/o/a #1"], m.stages[0].Picked["github.com/o/b #2"] = true, true
	if got := m.refs(); !slices.Equal(got, []string{"#1", "#2"}) {
		t.Fatalf("the refs: %q", got)
	}
	confirmed(t, m, "Assign to Me")
	want := []string{a + "\tassign #1", b + "\tassign #2"}
	if got := ranIn(t, dirs); !slices.Equal(got, want) {
		t.Errorf("the calls:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

func TestTheActionsOfOneMemberAreDimAcrossTwo(t *testing.T) {
	m, _, _, _ := overMembers(t)
	one := []string{"Start Local Work Together…", "Add to Pull Request…", "Gather Under a Parent…",
		"Close as Duplicate of…"}
	m.stages[0].Picked["github.com/o/a #1"], m.stages[0].Picked["github.com/o/b #2"] = true, true
	for _, name := range append(one, "Assign to Me") {
		k := item(m, name)
		if k < 0 {
			t.Fatalf("%s is not in the menu", name)
		}
		if dim := !m.enabled(k); dim != slices.Contains(one, name) {
			t.Errorf("%s across two members: dim %v", name, dim)
		}
	}
	delete(m.stages[0].Picked, "github.com/o/b #2")
	for _, name := range []string{"Start Local Work Together…", "Gather Under a Parent…", "Close as Duplicate of…"} {
		if !m.enabled(item(m, name)) {
			t.Errorf("%s with a's issue alone is dim", name)
		}
	}
}

func TestOverAGroupMeIsAskedInAMember(t *testing.T) {
	m, dirs, a, _ := overMembers(t)
	if msg, ok := m.whoami()().(meMsg); !ok || msg.err != nil {
		t.Fatalf("whoami: %+v", msg)
	}
	var me []string
	for _, c := range calls(t, dirs) {
		if strings.HasSuffix(c, "\tflow --me") {
			me = append(me, c)
		}
	}
	if want := a + "\tflow --me"; !slices.Equal(me, []string{want}) {
		t.Errorf("--me ran %q, want %q", me, want)
	}
}

func TestOverAGroupAConfirmNamesEachIssuesMemberAndRunsInEach(t *testing.T) {
	m, dirs, a, b := overMembers(t)
	m.stages[0].Picked["github.com/o/a #1"], m.stages[0].Picked["github.com/o/b #2"] = true, true
	m = choose(t, m, "Unassign")
	// each line names its member, so nothing is said of one repository under them
	if m.ask == nil || !slices.Equal(m.ask.changes, []string{"a #1 a1", "b #2 b2"}) || len(m.ask.says) != 0 {
		t.Fatalf("the dialog: %+v", m.ask)
	}
	m = drive(m, press(tea.KeyEnter))
	want := []string{a + "\tunassign #1", b + "\tunassign #2"}
	if got := ranIn(t, dirs); !slices.Equal(got, want) {
		t.Errorf("the calls:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

func TestOverAGroupNewAsksInTheMemberUnderTheCursor(t *testing.T) {
	m, dirs, _, b := overMembers(t)
	k := slices.IndexFunc(m.rows(0), func(r row) bool { return r.Key == "github.com/o/b #2" })
	if k < 0 {
		t.Fatalf("no row of b:\n%s", view(m))
	}
	m.stages[0].Cursor = k
	m = choose(t, m, "New…")
	var asked []string
	for _, c := range calls(t, dirs) {
		if strings.HasSuffix(c, "\tnew issue --list --json") {
			asked = append(asked, c)
		}
	}
	if want := b + "\tnew issue --list --json"; !slices.Equal(asked, []string{want}) {
		t.Errorf("the trackers were asked %q, want %q", asked, want)
	}
	// with no row under the cursor, New… has no member to file in
	m.stages[0].Cursor = -1
	if m.enabled(item(m, "New…")) {
		t.Error("New… with no row under the cursor is not dim")
	}
}

func TestNoCommandRunsNothing(t *testing.T) {
	m := loaded(t, options())
	if cmd := m.run(nil, nil); cmd != nil || m.note.Text != "" {
		t.Errorf("run with no command: %v, %q", cmd != nil, m.note.Text)
	}
	// a label a row holds is the row's, with its color; one no row holds is its name alone
	if l := m.Label("labels", "bug"); l.Name != "bug" || l.Color == "" {
		t.Errorf("bug: %+v", l)
	}
	if l := m.Label("labels", "nonesuch"); l != (table.Label{Name: "nonesuch"}) {
		t.Errorf("nonesuch: %+v", l)
	}
}

func TestOverARepositoryGivenAnActionRunsInItsCheckout(t *testing.T) {
	dirs := filepath.Join(t.TempDir(), "dirs")
	t.Setenv("FAKE_FLOW_DIRS", dirs)
	a, _ := filepath.EvalSymlinks(t.TempDir())
	r := runner(t)
	r.Group = "github.com/o/a"
	m := New(r, Options{Stages: []string{"issues"}, NoPresets: true, Clock: &testkit.Clock{}})
	ws := kit.Workspace{Kind: "repository", Name: "github.com/o/a", Member: "github.com/o/a", Checkout: a}
	m = drive(m, tea.WindowSizeMsg{Width: 120, Height: 40}, shell.WorkspaceMsg{Workspace: ws},
		answer("issues", `{"rows": [{"number": 1, "title": "a1", "member": "github.com/o/a"}], "errors": []}`))
	m.stages[0].Picked["github.com/o/a #1"] = true
	m = choose(t, m, "Assign to Me")
	if m.ask == nil || !slices.Equal(m.ask.changes, []string{"github.com/o/a #1 a1"}) {
		t.Fatalf("the dialog: %+v", m.ask)
	}
	m = drive(m, press(tea.KeyEnter))
	if got, want := ranIn(t, dirs), []string{a + "\tassign #1"}; !slices.Equal(got, want) {
		t.Errorf("the calls: %q, want %q", got, want)
	}
	// and the caller's login is read there
	m.whoami()()
	if got := calls(t, dirs); !slices.Contains(got, a+"\tflow --me") {
		t.Errorf("--me ran: %q", got)
	}
}

func TestAMemberWhoseCheckoutKitHasNotSaidIsNotActedOn(t *testing.T) {
	dirs := filepath.Join(t.TempDir(), "dirs")
	t.Setenv("FAKE_FLOW_DIRS", dirs)
	// kit has not said the workspace yet: no member's checkout is known
	m := drive(over(t, "issues"), shell.WorkspaceMsg{Workspace: kit.Workspace{Kind: "group", Name: "w"}},
		answer("issues", twoMembers))
	m.stages[0].Picked["github.com/o/a #1"] = true
	m = choose(t, m, "Assign to Me")
	if got := ranIn(t, dirs); len(got) != 0 {
		t.Errorf("ran where a is not: %q", got)
	}
	if !strings.Contains(m.note.Text, "where github.com/o/a is checked out") {
		t.Errorf("the note: %q", m.note.Text)
	}
	// nor is a new issue filed in the member under the cursor, though none is selected
	m.note.Text = ""
	delete(m.stages[0].Picked, "github.com/o/a #1")
	m.stages[0].Cursor = slices.IndexFunc(m.rows(0), func(r row) bool { return r.Key == "github.com/o/a #1" })
	m = choose(t, m, "New…")
	if got := ranIn(t, dirs); len(got) != 0 || m.ask != nil {
		t.Errorf("asked for the trackers where a is not: %q, %+v", got, m.ask)
	}
	if !strings.Contains(m.note.Text, "where github.com/o/a is checked out") {
		t.Errorf("the note of New…: %q", m.note.Text)
	}
}

// Add to Pull Request… adds an issue to a pull request that the changes tab read, so an app with no changes tab,
// Issues, never has one to add to: its menu leaves the line out, where Flow's keeps it, dim until the caller has one.
func TestAnAppWithNoChangesTabLeavesAddToPullRequestOut(t *testing.T) {
	i := drive(appOf(t, shell.Issues, tea.WindowSizeMsg{Width: 160, Height: 30}), press(':'))
	if k := item(i, "Add to Pull Request…"); k >= 0 {
		t.Errorf("the Issues app offers Add to Pull Request… at %d", k)
	}
	if k := item(i, "Assign to Me"); k < 0 {
		t.Error("the Issues app lost its other actions")
	}
	m, _ := selecting(t)
	if k := item(drive(m, press(':')), "Add to Pull Request…"); k < 0 {
		t.Error("Flow lost Add to Pull Request…")
	}
}
