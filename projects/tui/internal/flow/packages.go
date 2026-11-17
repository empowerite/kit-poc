// The Packages app: kit packages' one stage, a row per package in reach, drawn from the catalog as kit workspace's
// stages are, and the menus' actions on the packages selected, or on the one under the cursor, each kit packages add,
// remove, or select, which kittui runs and never does itself. Each shows what it changes and asks first, in the
// dialog the issues' actions ask in, which act.go describes.
package flow

import (
	"encoding/json"
	"slices"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// packagesVerb is kit packages' verb, whose one stage kittui knows after it and a slash.
const packagesVerb = "packages"

// packagesStage is kit packages' stage, as kittui knows it.
const packagesStage = packagesVerb + "/packages"

// The glyphs the Packages app's dialogs draw beside a package: added, and removed.
const (
	Plus  = "➕"
	Minus = "➖"
)

// The Packages app's actions, by the names the tab's menu gives them.
const (
	AddPackages    = "Add"
	RemovePackages = "Remove…"
	OnlyPackages   = "Make Only These Active…"
)

// packageActions gives the Packages app's actions, in the tab's menu's order: those on the packages selected, there
// with nothing selected too, dim, so the menu shows what selecting packages makes possible.
func packageActions() []shell.Item {
	return []shell.Item{{Name: AddPackages}, {Name: RemovePackages},
		{Name: OnlyPackages}}
}

// onPackages says whether the selected stage is kit packages'.
func (m Model) onPackages() bool { return len(m.stages) > 0 && m.stages[m.stage].name == packagesStage }

// packageRow is a row of the packages stage as kit prints it: what an action reads of it.
type packageRow struct {
	Key    string `json:"key"`
	Member string `json:"member"`
	State  string `json:"state"`
}

// memberPackages is the packages selected in one member: the member, none over a repository, its checkout, and each
// package's name, active or not.
type memberPackages struct {
	member, dir    string
	active, others []string
}

// packageStates gives each row of the packages stage's state, active, inactive, or excluded, by the row's key as the
// screen keys it, and each member's active packages, in the rows' order; the screen is Packages, as onPackages says.
func (m Model) packageStates() (states map[string]string, active map[string][]string) {
	states, active = map[string]string{}, map[string][]string{}
	for _, raw := range m.find(packagesStage).rows {
		// a row that is not an object, as kit never prints, reads as a package of no name
		var p packageRow
		_ = json.Unmarshal(raw, &p)
		states[m.keyOf(p.Member, p.Key)] = p.State
		if p.State == "active" {
			active[p.Member] = append(active[p.Member], p.Key)
		}
	}
	return states, active
}

// pickedPackages gives the packages an action acts on, as subjects gives the rows, a member's together, the members
// in the rows' order.
func (m Model) pickedPackages() []memberPackages {
	states, _ := m.packageStates()
	var out []memberPackages
	for _, r := range m.subjects() {
		member, name := refOf(r.Key)
		k := slices.IndexFunc(out, func(g memberPackages) bool { return g.member == member })
		if k < 0 {
			out = append(out, memberPackages{member: member, dir: m.checkoutOf(member)})
			k = len(out) - 1
		}
		if states[r.Key] == "active" {
			out[k].active = append(out[k].active, name)
		} else {
			out[k].others = append(out[k].others, name)
		}
	}
	return out
}

// packageEnabled says whether a Packages action does anything now: Add while a package selected is not active,
// Remove while one is, and Make Only These Active while packages of one member are selected.
func (m Model) packageEnabled(name string) bool {
	picked := m.pickedPackages()
	switch name {
	case AddPackages:
		return slices.ContainsFunc(picked, func(g memberPackages) bool { return len(g.others) > 0 })
	case RemovePackages:
		return slices.ContainsFunc(picked, func(g memberPackages) bool { return len(g.active) > 0 })
	}
	return len(picked) == 1
}

// actOnPackages does what the Packages action named asks, each asking first: Add lists the packages selected that
// are not active, then runs kit packages add on them; Remove lists the active ones selected, then runs kit packages
// remove on them; Make Only These Active lists the packages it keeps or adds and the active ones it takes out, then
// runs kit packages select. Over a group, each runs in each member's checkout, with that member's packages.
func (m *Model) actOnPackages(name string) tea.Cmd {
	picked := m.pickedPackages()
	for _, g := range picked {
		if g.member != "" && g.dir == "" {
			return m.nowhere(g.member)
		}
	}
	each := func(verb string, names func(memberPackages) []string) []call {
		var out []call
		for _, g := range picked {
			if n := names(g); len(n) > 0 {
				out = append(out, call{g.dir, append([]string{packagesVerb, verb}, n...)})
			}
		}
		return out
	}
	line := func(member, glyph, name string) string {
		if member != "" {
			return m.short(member) + " " + glyph + " " + name
		}
		return glyph + " " + name
	}
	// the dialog lists the packages a verb is handed, and its title names one package as one
	asks := func(many, one, does, verb, glyph string, names func(memberPackages) []string) {
		var lines []string
		for _, g := range picked {
			for _, n := range names(g) {
				lines = append(lines, line(g.member, glyph, n))
			}
		}
		title := many
		if len(lines) == 1 {
			title = one
		}
		m.ask = &ask{title: title, does: does, changes: lines, says: m.inHere(), rows: m.subjectKeys(),
			run: func(string) []call { return each(verb, names) }}
	}
	switch name {
	case AddPackages:
		asks("Add these packages, and the files they deliver?", "Add this package, and the files it delivers?",
			"Add", "add", Plus, func(g memberPackages) []string { return g.others })
	case RemovePackages:
		asks("Remove these packages, and the files they delivered?",
			"Remove this package, and the files it delivered?", "Remove", "remove", Minus,
			func(g memberPackages) []string { return g.active })
	case OnlyPackages:
		g := picked[0]
		chosen := slices.Concat(g.active, g.others)
		var lines []string
		for _, n := range g.active {
			lines = append(lines, line(g.member, Checked, n))
		}
		for _, n := range g.others {
			lines = append(lines, line(g.member, Plus, n))
		}
		_, active := m.packageStates()
		for _, n := range active[g.member] {
			if !slices.Contains(chosen, n) {
				lines = append(lines, line(g.member, Minus, n))
			}
		}
		title := "Make these the active packages? kit keeps what they need, and takes out the rest"
		if len(chosen) == 1 {
			title = "Make this the only active package? kit keeps what it needs, and takes out the rest"
		}
		m.ask = &ask{title: title, does: "Select", changes: lines, says: m.inHere(), rows: m.subjectKeys(),
			run: func(string) []call {
				return []call{{g.dir, append([]string{packagesVerb, "select"}, chosen...)}}
			}}
	}
	return nil
}
