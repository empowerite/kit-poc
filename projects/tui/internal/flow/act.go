// The issues' actions: what the tab's menu, and a row's, offer on the issues selected in issues, or, with none
// selected, on the issue under the cursor, each a kit verb kittui runs and never does itself, so a terminal, an agent
// over kit serve, and the menu do the same thing. The rows an action acts on are those subjects gives. An action that
// writes asks first, once, in the one dialog they share: its title says what it will do, a line for each issue says
// which it will change and where, and it has two buttons. Enter, or a click on the button that does it, runs kit;
// esc, a click on Cancel, or a click off the dialog runs nothing. One that wants an answer, a title, a login, an
// issue, or one of the caller's pull requests, asks for it in the same dialog. While kit runs, the keys bar says so;
// then it says what kit did, or why it refused, the rows it acted on are selected no longer when kit did it, and the
// stages that read the forge's issues and pull requests read them afresh. kit's verbs read a reference in the
// repository they run in, so while an issue of another repository, which kit lists where a pull request here closes
// it, is among those acted on, every action that hands kit a reference is dim; Copy Links, which hands kit nothing,
// is not.
package flow

import (
	"fmt"
	"slices"
	"strconv"
	"strings"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/pane"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// The glyphs beside the issues' actions that the picture's own glyphs do not name already: a new issue written, the
// issues handed to someone, the caller walking away from them, gathered in a basket, closed as not planned, and
// closed as a twin.
const (
	Write  = "📝"
	Hand   = "👥"
	Leave  = "🚶"
	Gather = "🧺"
	Drop   = "🚫"
	Twin   = "♊"
)

// issuesStage is kit flow's stage of every open issue, in the backlog and underway, whose rows the issues' actions act
// on.
const issuesStage = "issues"

// actions gives the issues' actions, in the tab's menu's order, on issues, the Packages app's on its stage, as
// packages.go says, and none elsewhere: New… first, which files an issue and needs none selected, then those on the
// issues it acts on, there with none to act on too, dim, so the menu shows what a row makes possible; Add to Pull
// Request… only where the app has the changes tab, never in Issues, whose menu has no such line to show dim.
func (m Model) actions() []shell.Item {
	if m.onPackages() {
		return packageActions()
	}
	if len(m.stages) == 0 || m.stages[m.stage].name != issuesStage {
		return nil
	}
	items := []shell.Item{
		{Glyph: Write, Name: "New…", Keys: "N"},
		{Glyph: Sprout, Name: "Start Local Work for Each"},
		{Glyph: Branch, Name: "Start Local Work Together…"},
		{Glyph: Change, Name: "Add to Pull Request…"},
		{Glyph: Owner, Name: "Assign to Me", Keys: "A"},
		{Glyph: Hand, Name: "Assign to…"},
		{Glyph: Leave, Name: "Unassign"},
		{Glyph: Gather, Name: "Gather Under a Parent…"},
		{Glyph: Drop, Name: "Close as Not Planned"},
		{Glyph: Twin, Name: "Close as Duplicate of…"},
		{Glyph: ToPage, Name: "Copy Links"},
	}
	if m.find("changes") == nil {
		// the pull requests to add to are those the changes tab read: an app without it never has one
		items = slices.DeleteFunc(items, func(i shell.Item) bool { return i.Name == "Add to Pull Request…" })
	}
	return items
}

// ask is what an action asks before kit runs, in the one dialog every action that writes shares: a title, which says
// what it will do; a line to type, or lines to pick one of, each with its answer, such as the caller's pull requests
// by number, or neither, for a yes alone; what it will change, a line each, which listed gives for the issues; what
// the dialog says under them, where they are and what kit makes of them; the name of its button that does it; and
// the kit commands the answer makes, or, with then, what it does in their place.
type ask struct {
	title   string
	typing  bool     // whether the answer is typed
	typed   string   // what is typed so far
	lines   []string // the lines to pick from
	pick    []string // each line's answer, when one is picked
	at      int      // the line under the keyboard
	changes []string // what it will change, a line each
	rows    []string // the keys of the rows it acts on
	says    []string // what is said under them, a sentence each: the repository, and what kit makes
	does    string   // the name on its button that does it: Assign
	run     func(answer string) []call
	then    func(answer string) tea.Cmd
}

// call is one kit command an action runs: the checkout it runs in, none for where the screen reads, and its words.
type call struct {
	dir   string
	words []string
}

// memberRefs is the issues selected in one member's issues: the member, none over a repository, its checkout, and
// the issues' references, each once.
type memberRefs struct {
	member, dir string
	refs        []string
}

// refOf gives a row's member and what it names, from the row's key, which holds the member before it over a group: an
// issues row's issue's reference, #45 or AB#4521, or empowerite/jig#7 for an issue of another repository, its first
// word that holds a #, the pull request's after it for an issue underway, as #45 #46, left out; or a packages row's
// package.
func refOf(key string) (member, ref string) {
	words := strings.Fields(key)
	if k := slices.IndexFunc(words, func(w string) bool { return strings.Contains(w, "#") }); k >= 0 {
		return strings.Join(words[:k], " "), words[k]
	}
	if k := strings.LastIndex(key, " "); k >= 0 {
		return key[:k], key[k+1:]
	}
	return "", key
}

// checkoutOf gives a member's checkout, as kit said the workspace: a group's member's, or the repository's given by
// --workspace; none for a row of no member, which runs where the screen reads, and none where kit has not said.
func (m Model) checkoutOf(member string) string {
	if m.ws.Member == member && m.ws.Checkout != "" {
		return m.ws.Checkout
	}
	for _, w := range m.ws.Members {
		if w.Repository == member {
			return w.Checkout
		}
	}
	return ""
}

// refsByMember gives the issues an action acts on, a member's together, the members in the rows' order, an issue
// underway that two rows stand for once.
func (m Model) refsByMember() []memberRefs {
	var out []memberRefs
	for _, r := range m.subjects() {
		member, ref := refOf(r.Key)
		k := slices.IndexFunc(out, func(g memberRefs) bool { return g.member == member })
		if k < 0 {
			out = append(out, memberRefs{member: member, dir: m.checkoutOf(member)})
			k = len(out) - 1
		}
		if !slices.Contains(out[k].refs, ref) {
			out[k].refs = append(out[k].refs, ref)
		}
	}
	return out
}

// oneMember names the actions that act in one member, which a selection across two cannot take.
var oneMember = []string{"Start Local Work Together…", "Add to Pull Request…", "Gather Under a Parent…",
	"Close as Duplicate of…"}

// trackersMsg is what kit said of the trackers a new issue can be filed in, or why it could not say.
type trackersMsg struct {
	trackers []kit.Tracker
	err      error
}

// actedMsg is what kit printed for an action's commands, its refusal when one failed: those after it did not run;
// how many commands the action ran, or would have; and the keys of the rows it acted on.
type actedMsg struct {
	out  string
	err  error
	ran  int
	rows []string
}

// refs gives the references of the issues an action acts on, in the rows' order: #45, whatever their member, each
// once.
func (m Model) refs() []string {
	var out []string
	for _, r := range m.subjects() {
		if _, ref := refOf(r.Key); !slices.Contains(out, ref) {
			out = append(out, ref)
		}
	}
	return out
}

// mine gives the caller's open pull requests, as the changes stage read them, in the member of the issues selected:
// each one's number and line.
func (m Model) mine() (numbers []int, lines []string) {
	member := ""
	if groups := m.refsByMember(); len(groups) > 0 {
		member = groups[0].member
	}
	for _, s := range m.stages {
		if s.name != "changes" {
			continue
		}
		for _, p := range of[pull](s) {
			if m.me != "" && p.Author == m.me && p.Member == member {
				numbers = append(numbers, p.Number)
				lines = append(lines, fmt.Sprintf("%s #%d %s", Change, p.Number, p.Title))
			}
		}
	}
	return numbers, lines
}

// acting says whether a menu's line is one of the issues' actions, and whether it does anything now: New… always;
// the rest none while there is no issue to act on, none selected and none under the cursor, as subjects says; all of
// those but Copy Links, which hand kit the issues' references, none while an issue of another repository is among
// them, as away says; and Add to Pull Request only while the caller has an open pull request to add to.
func (m Model) acting(name string) (action, enabled bool) {
	if !slices.ContainsFunc(m.actions(), func(i shell.Item) bool { return i.Name == name }) {
		return false, false
	}
	if m.onPackages() {
		return true, m.packageEnabled(name)
	}
	if name == "New…" {
		return true, m.runner.Group == "" || m.cursorMember() != ""
	}
	if len(m.subjects()) == 0 || name != "Copy Links" && m.away() ||
		slices.Contains(oneMember, name) && len(m.refsByMember()) > 1 {
		return true, false
	}
	if name == "Add to Pull Request…" {
		numbers, _ := m.mine()
		return true, len(numbers) > 0
	}
	return true, true
}

// away says whether an issue of another repository, as elsewhere says, is among those an action acts on: kit's verbs
// would read its reference as the issue of that number in the repository here.
func (m Model) away() bool {
	far := map[string]bool{}
	for _, i := range of[issue](*m.find(issuesStage)) {
		if m.elsewhere(i) {
			far[m.keyOf(i.Member, m.named(i))] = true
		}
	}
	if len(far) == 0 {
		return false
	}
	return slices.ContainsFunc(m.subjects(), func(r row) bool {
		member, ref := refOf(r.Key)
		return far[m.keyOf(member, ref)]
	})
}

// nowhere says an action does not run, as kit has not said where the member it acts in is checked out, and running
// where the screen reads would act on another repository's issues.
func (m *Model) nowhere(member string) tea.Cmd {
	m.note.Text = fmt.Sprintf("%s kit has not said where %s is checked out; pick the workspace again from %s", Failed,
		member, shell.Workspaces)
	m.note.Done = false
	return nil
}

// cursorMember gives the member of the issues row under the cursor, over a group, or none.
func (m Model) cursorMember() string {
	rows, k := m.rows(m.stage), m.stages[m.stage].Cursor
	if k < 0 || k >= len(rows) || rows[k].Aside {
		return ""
	}
	member, _ := refOf(rows[k].Key)
	return member
}

// act does what the issues' action named asks: one that hands kit the issues asks first, in the dialog ask
// describes, and runs kit only on its answer; New… asks kit for the trackers, and Copy Links, which hands kit
// nothing, copies at once. Over a group, an action on the issues runs in each member's checkout, with that member's
// issues; one that acts in one member runs in its.
func (m *Model) act(name string) tea.Cmd {
	if m.onPackages() {
		return m.actOnPackages(name)
	}
	refs, groups := m.refs(), m.refsByMember()
	for _, g := range groups {
		if g.member != "" && g.dir == "" {
			return m.nowhere(g.member)
		}
	}
	dir := ""
	if len(groups) > 0 {
		dir = groups[0].dir
	}
	one := func(words ...string) []call { return []call{{dir, words}} }
	each := func(words ...string) func(string) []call {
		return func(string) []call {
			var out []call
			for _, g := range groups {
				out = append(out, call{g.dir, append(slices.Clone(words), g.refs...)})
			}
			return out
		}
	}
	// the dialog names one issue as one
	these, all, twins := "these issues", "each of these issues", "duplicates"
	if len(refs) == 1 {
		these, all, twins = "this issue", "this issue", "a duplicate"
	}
	asks := func(a ask, made ...string) {
		a.changes, a.says, a.rows = m.listed(), append(m.inHere(), made...), m.subjectKeys()
		m.ask = &a
	}
	confirm := func(title, does string, words ...string) {
		asks(ask{title: title, does: does, run: each(words...)})
	}
	question := func(title, does string, run func(answer string) []call, made ...string) {
		asks(ask{title: title, does: does, typing: true, run: run}, made...)
	}
	switch name {
	case "New…":
		m.note.Text, m.note.Done = "→ kit new issue --list …", true
		r, ctx := m.runner, m.ctx
		if member := m.cursorMember(); member != "" {
			if r.Dir = m.checkoutOf(member); r.Dir == "" {
				return m.nowhere(member)
			}
		}
		return func() tea.Msg {
			trackers, err := r.Trackers(ctx)
			return trackersMsg{trackers, err}
		}
	case "Start Local Work for Each":
		// The person at the screen chose this, and kit work has no terminal to see that by, so the flag says it: the
		// desk's uncommitted work is swept into the first worktree made, as kit work does at a terminal.
		asks(ask{title: "Start local work on " + all + "?", does: "Start", run: func(string) []call {
			var calls []call
			for _, g := range groups {
				for _, r := range g.refs {
					calls = append(calls, call{g.dir, []string{"work", "--sweep", r}})
				}
			}
			return calls
		}}, "kit work makes a branch, a worktree, a start commit, and a draft pull request for each issue, assigns "+
			"the issue to you, and moves the desk's uncommitted work into the first worktree.")
	case "Start Local Work Together…":
		question("Start local work on "+these+" under a new parent issue titled", "Start", func(t string) []call {
			return one(append([]string{"work", "--sweep", "--title=" + t}, refs...)...)
		}, "kit work files the parent issue, and makes one branch, one worktree, a start commit, and a draft pull "+
			"request that closes them all. It assigns them to you, and moves the desk's uncommitted work into the "+
			"worktree.")
	case "Add to Pull Request…":
		numbers, lines := m.mine()
		var picks []string
		for _, n := range numbers {
			picks = append(picks, strconv.Itoa(n))
		}
		asks(ask{title: "Add " + these + " to which of your pull requests?", does: "Add", lines: lines, pick: picks,
			run: func(n string) []call { return one(append([]string{"work", "--pr=" + n}, refs...)...) }},
			"kit work assigns each issue to you, and the pull request closes it.")
	case "Assign to Me":
		confirm("Assign "+these+" to you?", "Assign", "assign")
	case "Assign to…":
		question("Assign "+these+" to which login?", "Assign", func(login string) []call {
			return each("assign", "--to="+login)("")
		})
	case "Unassign":
		confirm("Take yourself off "+these+"?", "Unassign", "unassign")
	case "Gather Under a Parent…":
		question("Gather "+these+" under a new parent issue titled", "Gather", func(t string) []call {
			return one(append([]string{"gather", "--title=" + t}, refs...)...)
		})
	case "Close as Not Planned":
		confirm("Close "+these+" as not planned?", "Close", "close", "--not-planned")
	case "Close as Duplicate of…":
		question("Close "+these+" as "+twins+" of which issue?", "Close", func(original string) []call {
			return one(append([]string{"close", "--duplicate-of=" + original}, refs...)...)
		})
	case "Copy Links":
		// the terminal does not say whether it took the request, so the notice says what was sent
		noun := "links"
		if len(refs) == 1 {
			noun = "link"
		}
		m.done(fmt.Sprintf("%s sent %d %s to the clipboard", ToPage, len(refs), noun))
		return tea.SetClipboard(m.links())
	}
	return nil
}

// newIssue takes what kit said of the trackers: a dialog that picks the one to file a new issue in, each line its
// prefix and where, the page opened once it is picked; it starts on the forge's own, which kit lists first, as
// the issues' are. A tracker that gives no page is left out; with none left, the notice says why.
func (m *Model) newIssue(msg trackersMsg) tea.Cmd {
	m.note.Text = ""
	if msg.err != nil {
		m.note.Text, m.note.Done = Failed+" "+msg.err.Error(), false
		return nil
	}
	a := &ask{title: "New issue in which tracker?", does: "Open", then: m.openPage}
	refusal := "kit names no tracker to file a new issue in"
	for _, t := range msg.trackers {
		if t.URL == "" {
			refusal = t.Error
			continue
		}
		a.lines, a.pick = append(a.lines, t.Prefix+"  "+t.Label), append(a.pick, t.URL)
	}
	if len(a.pick) == 0 {
		m.note.Text, m.note.Done = Failed+" "+refusal, false
		return nil
	}
	m.ask = a
	return nil
}

// listed gives a line for each issue an action acts on, its reference and title, after its member's short name over
// a group, for the dialog an action asks in, which lists what it will change: an issue underway that two rows stand
// for is listed once.
func (m Model) listed() []string {
	var out []string
	for _, r := range m.subjects() {
		member, ref := refOf(r.Key)
		line := ref + " " + m.issueTitle(member, ref)
		if member != "" {
			line = m.short(member) + " " + line
		}
		if !slices.Contains(out, line) {
			out = append(out, line)
		}
	}
	return out
}

// inHere gives what an action's dialog says of where the rows it lists are, under them: in, and the path of the
// repository here, which pathHere gives; nothing over a group, where each line names its member, and nothing where
// kittui knows no repository here.
func (m Model) inHere() []string {
	if here := m.pathHere(""); m.runner.Group == "" && here != "" {
		return []string{"in " + here}
	}
	return nil
}

// issueTitle gives a member's issue's title, by what its row's key names it by, as named gives it, as issues read it,
// or nothing; it asks only on issues, whose actions are the only ones that name issues.
func (m Model) issueTitle(member, ref string) string { return m.issueNamed(member, ref).Title }

// issueNamed gives a member's issue, by what its row's key names it by, as named gives it, as issues read it: the last
// of its rows, where an issue underway has one for each pull request that closes it; or an issue of no title and no
// page, where issues hold none of that name.
func (m Model) issueNamed(member, ref string) (found issue) {
	for _, i := range of[issue](*m.find(issuesStage)) {
		if i.Member == member && m.named(i) == ref {
			found = i
		}
	}
	return found
}

// links gives the issues an action acts on as Markdown, one a line: a link to each issue's page, the one kit printed
// for the issue, never its pull request's, its reference and title the link's text, or the text alone for an issue
// kit printed no page for.
func (m Model) links() string {
	var out []string
	for _, r := range m.subjects() {
		member, ref := refOf(r.Key)
		i := m.issueNamed(member, ref)
		text := ref + " " + i.Title
		if i.URL == "" {
			out = append(out, "- "+text)
		} else {
			out = append(out, fmt.Sprintf("- [%s](%s)", text, i.URL))
		}
	}
	return strings.Join(out, "\n")
}

// run runs kit's commands, one after another, each in its checkout, the keys bar saying so until kit answers; a
// refusal stops the rest. rows are the keys of the rows the commands act on.
func (m *Model) run(calls []call, rows []string) tea.Cmd {
	if len(calls) == 0 {
		return nil
	}
	m.note.Text, m.note.Done = "→ kit "+strings.Join(calls[0].words, " ")+" …", true
	r, ctx := m.runner, m.ctx
	return func() tea.Msg {
		var out strings.Builder
		for _, c := range calls {
			in := r
			if c.dir != "" {
				in.Dir = c.dir
			}
			o, err := in.Act(ctx, c.words...)
			out.WriteString(o)
			if err != nil {
				return actedMsg{out.String(), err, len(calls), rows}
			}
		}
		return actedMsg{out.String(), nil, len(calls), rows}
	}
}

// acted takes what kit said for an action: its last line in place of the keys, and, where the action ran more than
// one command, that the line is the last of so many, or its refusal; when kit did what was asked, the rows it acted
// on are selected no longer, and any other selected stays; either way, what reads the forge's issues reads them
// afresh, and the packages stage, after a Packages action, reads the active set again.
func (m *Model) acted(msg actedMsg) tea.Cmd {
	lines := strings.Split(strings.TrimSpace(ansi.Strip(msg.out)), "\n")
	name := issuesStage
	if m.onPackages() {
		name = packagesStage
	}
	if msg.err != nil {
		m.note.Text, m.note.Done = Failed+" "+msg.err.Error(), false
	} else {
		did := lines[len(lines)-1]
		if msg.ran > 1 {
			did += fmt.Sprintf(", the last of %d commands", msg.ran)
		}
		m.done(did)
		if s := m.find(name); s != nil {
			for _, key := range msg.rows {
				delete(s.Picked, key)
			}
		}
	}
	return m.refresh(name)
}

// askKey takes a key while an action asks: esc does not run it; enter runs it with the answer, which a typed one
// needs; up and down move along the lines to pick from; anything else is typed, when the answer is.
func (m Model) askKey(k tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	a := m.ask
	switch key := k.String(); {
	case key == "esc":
		m.ask = nil
	case key == "enter":
		answer := strings.TrimSpace(a.typed)
		switch {
		case a.pick != nil:
			answer = a.pick[a.at]
		case a.waits():
			return m, nil
		}
		m.ask = nil
		if a.then != nil {
			return m, a.then(answer)
		}
		return m, m.run(a.run(answer), a.rows)
	case a.pick != nil && (key == "up" || key == "down"):
		a.at = shell.Step(a.at, len(a.pick), map[string]int{"up": -1, "down": 1}[key], shell.Every)
	case a.typing:
		a.typed, _ = shell.Type(a.typed, k)
	}
	return m, nil
}

// cancelButton is the dialog's button that runs nothing, named with its key: esc does the same.
const cancelButton = " esc Cancel "

// doButton gives the dialog's button that does what it asks, named with its key: enter does the same.
func (a ask) doButton() string { return " ⏎ " + a.does + " " }

// waits says whether the dialog's button that does it does nothing yet: its answer is typed, and nothing is.
func (a ask) waits() bool { return a.typing && strings.TrimSpace(a.typed) == "" }

// buttons gives the dialog's last line, its two buttons, two cells apart: the one that does it, drawn inverse, the
// way a menu draws the line under the keyboard, and dim while it waits for an answer; and Cancel.
func (a ask) buttons() string {
	if a.waits() {
		return style.Off(a.doButton()) + "  " + cancelButton
	}
	return style.Selected(a.doButton()) + "  " + cancelButton
}

// askKeys gives the keys of the dialog an action asks in, for the keys bar, which names them the way its buttons do:
// esc cancels, enter does it, and up and down move along the lines to pick from.
func (m Model) askKeys() string {
	if m.ask.pick != nil {
		return "esc cancel · ↑↓ move · ⏎ " + strings.ToLower(m.ask.does)
	}
	return "esc cancel · ⏎ " + strings.ToLower(m.ask.does)
}

// askBody gives the lines of the dialog an action asks in, under its title: the line typed so far, with its caret,
// or the lines to pick from, the one under the keyboard inverse; a blank line apart, what it will change, a line
// each, and what the ask says under them, dim, wrapped; and last, a blank line apart, its buttons. The box ends above
// the keys bar, so the buttons always show: a list longer than the room is cut, its last line saying how many more
// it holds.
func (m Model) askBody() []string {
	a := m.ask
	var body []string
	switch {
	case a.typing:
		body = append(body, a.typed+style.Mark("▏"))
	case a.pick != nil:
		body = slices.Clone(a.lines)
		body[a.at] = style.Selected(body[a.at])
	}
	var says []string
	for _, s := range a.says {
		for _, l := range pane.Wrap(s, min(72, m.paneWidth()-6)) {
			says = append(says, style.Off(l))
		}
	}
	if len(a.changes) > 0 {
		if len(body) > 0 {
			body = append(body, "")
		}
		// the screen's lines under the box's top edge and over the keys bar, less the box's bottom edge, the buttons
		// and the blank over them, and what else the box holds
		changes := a.changes
		if room := max(1, m.height-m.askTop()-5-len(body)-len(says)); len(changes) > room {
			rest := fmt.Sprintf("and %d more", len(changes)-room+1)
			if room == 1 {
				rest = fmt.Sprintf("%d in all", len(changes))
			}
			changes = append(slices.Clone(changes[:room-1]), style.Off(rest))
		}
		body = append(append(body, changes...), says...)
	}
	return append(body, "", a.buttons())
}

// askTop gives the screen line the top edge of the dialog an action asks in stands on: near the rows' top.
func (m Model) askTop() int { return m.top() + 1 }

// askBox gives the dialog an action asks in, where it stands: centered over the rows, near their top.
func (m Model) askBox() shell.Placed {
	lines := shell.Dialog(m.ask.title, m.askBody(), m.paneWidth()-2)
	return shell.Placed{Lines: lines, Top: m.askTop(), Left: max(0, (m.paneWidth()-ansi.StringWidth(lines[0]))/2)}
}

// askClick takes a click while an action asks, and every one: a left click on the button that does it runs it, the
// same as enter; one on Cancel, or off the dialog, runs nothing, the same as esc; one on a line to pick from puts
// the keyboard on it; anywhere else on the dialog, and with another button, it does nothing.
func (m Model) askClick(c tea.MouseClickMsg) (Model, tea.Cmd, bool) {
	if c.Button != tea.MouseLeft {
		return m, nil, true
	}
	a, box := m.ask, m.askBox()
	line, on := box.Hit(c.X, c.Y)
	// a body line starts a cell in from the box's left edge
	x, do := c.X-box.Left-2, ansi.StringWidth(a.doButton())
	switch {
	case !on:
		m.ask = nil
	case line == len(box.Lines)-3 && x >= 0 && x < do:
		next, cmd := m.askKey(tea.KeyPressMsg{Code: tea.KeyEnter})
		return next.(Model), cmd, true
	case line == len(box.Lines)-3 && x >= do+2 && x < do+2+ansi.StringWidth(cancelButton):
		m.ask = nil
	case a.pick != nil && line >= 0 && line < len(a.pick):
		a.at = line
	}
	return m, nil, true
}
