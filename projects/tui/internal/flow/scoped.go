// The presets that stand beyond one stage, as internal/table keeps them: saved everywhere or in the app, active, and
// followed from stage to stage, since the file is one. Making one active, or no longer, or switching a constraint of
// one off, sets every stage's panel as its stack now says, what the person changed in each kept.
package flow

import (
	"fmt"
	"slices"
	"strings"

	"github.com/empowerite/kit/projects/tui/internal/table"
)

// reserved gives the names of every stage's own views, which a preset saved everywhere or in the app may not take.
func reserved() []string {
	names := []string{table.Default}
	for _, s := range catalog {
		for _, p := range s.Presets {
			if !slices.Contains(names, p.Name) {
				names = append(names, p.Name)
			}
		}
	}
	slices.Sort(names)
	return names
}

// saveNamed keeps the selected stage's panel under the name typed, as saveAs does, or, where the name was typed for a
// preset saved everywhere or in the app, there.
func (m *Model) saveNamed(name string) {
	s := &m.stages[m.stage]
	if !s.Scoped {
		m.saveAs(name)
		return
	}
	scoped, saved, err := m.viewsOf(m.stage).SaveAt(name, s.Scope, s.ViewName, s.View)
	if err != nil {
		m.refuseName(name, err)
		return
	}
	before := m.scoped
	if !m.keepStack(saved, scoped, "saved") {
		return
	}
	level := s.Scope
	s.SavingAs, s.Naming, s.Renaming, s.Scoped = false, "", "", false
	// the stage saved from is as it was; the others now have the preset beneath them
	m.restack(before)
	m.done(Save + " saved the preset " + name + " " + table.ScopeWord(level, string(m.app)))
}

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
	now := m.scoped
	for i := range m.stages {
		s := &m.stages[i]
		if catalog[s.name] == nil {
			continue
		}
		m.scoped = before
		was := m.viewsOf(i)
		m.scoped = now
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
	m.done(Save + " changed " + card.C.Layer + "'s " + string(card.C.Facet) + " of " + strings.TrimSpace(card.C.Field))
}
