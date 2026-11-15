// The presets that stand beyond one stage, as internal/table keeps them: saved everywhere or in the app, active, and
// followed from stage to stage, since the file is one. Making one active, or no longer, or switching a constraint of
// one off, sets every stage's panel as its stack now says, what the person changed in each kept.
package flow

import (
	"fmt"
	"slices"

	"github.com/empowerite/kit/projects/tui/internal/table"
)

// keepStack keeps the person's presets of the selected stage and those of global and app scope with their active
// names, as table.KeepViews does, and says whether it could; when it could not, the notice says why, and nothing
// changes.
func (m *Model) keepStack(saved []table.Preset, scoped table.Scoped, what string) bool {
	all, got, err := table.KeepViews(m.presetsPath, m.stages[m.stage].name, m.viewsOf(m.stage), saved, scoped)
	if err != nil {
		m.note.Text, m.note.Done = fmt.Sprintf("%s the preset could not be %s: %v", Failed, what, err), false
		return false
	}
	if all != nil {
		m.saved = all
	}
	m.scoped = got
	return true
}

// restack sets every stage's panel as its stack now says, once the scoped presets changed from before, what the person
// changed in each kept, and each stage's panel as it was left is kept again, so a stage opens as the presets now say.
func (m *Model) restack(before table.Scoped) {
	for i := range m.stages {
		s := &m.stages[i]
		if catalog[s.name] == nil {
			continue
		}
		was := m.viewsOf(i)
		was.Scoped = before
		s.SetView(was.Rebased(m.viewsOf(i), s.ViewName, s.View))
	}
	m.rebuild()
	for i := range m.stages {
		m.clamp(i)
		if catalog[m.stages[i].name] != nil {
			m.rememberAt(i)
		}
	}
	m.fit()
}

// toggle makes the preset of a level active, or no longer, and every stage follows.
func (m *Model) toggle(l table.Level, name string) {
	v, before := m.viewsOf(m.stage), m.scoped
	scoped, err := v.Toggle(l, name)
	if err != nil || !m.keepStack(v.Saved, scoped, "changed") {
		return
	}
	m.restack(before)
	did := "made " + name + " active " + table.ScopeWord(l, string(m.app))
	if !slices.Contains(scoped.Active[table.ScopeKey(l, string(m.app))], name) {
		did = "stopped " + name + " being active " + table.ScopeWord(l, string(m.app))
	}
	m.done(Save + " " + did)
}

// switched does what the line chosen on the card of a dim chip says: the constraint is switched off at a level, or on
// again, and every stage follows.
func (m *Model) switched(card table.ConstraintCard, k int) {
	before := m.scoped
	scoped, saved, err := card.Choose(m, k)
	if err != nil || !m.keepStack(saved, scoped, "changed") {
		return
	}
	m.restack(before)
	m.done(Save + " changed " + card.C.Layer + "'s " + string(card.C.Facet) + " of " + card.C.Field)
}
