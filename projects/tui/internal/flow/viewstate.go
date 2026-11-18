// The view state: where the person left a screen, apart from its rows, which kit keeps, and its panel, which the
// presets keep. It is the tab selected and, for each stage, the row the cursor is on and how far the rows scrolled,
// the columns scrolled past, the folds opened or closed, and the rows selected. The root keeps it in the kit cache for
// each workspace, when the workspace is left and when kittui ends, and gives it to the screen it makes there again,
// so a restart, or a workspace closed to free memory, comes back as it was left.
package flow

import (
	"maps"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// ViewState is where the person left a screen: the stage selected, and each stage's place by its name.
type ViewState struct {
	Stage  string                `json:"stage"`
	Stages map[string]StageState `json:"stages"`
}

// StageState is where the person left a stage's rows: the cursor, which is a row's index, kept inside the rows
// by the clamp that runs as they load; the rows scrolled past; the columns scrolled past; the folds, by the key of the
// row folded; and the keys of the rows selected.
type StageState struct {
	Cursor int             `json:"cursor,omitempty"`
	Offset int             `json:"offset,omitempty"`
	Shift  int             `json:"shift,omitempty"`
	Open   map[string]bool `json:"open,omitempty"`
	Picked []string        `json:"picked,omitempty"`
}

// State gives where the screen was left.
func (m Model) State() ViewState {
	v := ViewState{Stages: map[string]StageState{}}
	if m.stage < len(m.stages) {
		v.Stage = m.stages[m.stage].name
	}
	for _, s := range m.stages {
		st := StageState{Cursor: s.Cursor, Offset: s.Offset, Shift: s.Shift, Open: maps.Clone(s.Open)}
		for key, on := range s.Picked {
			if on {
				st.Picked = append(st.Picked, key)
			}
		}
		v.Stages[s.name] = st
	}
	return v
}

// Restored gives the screen as it was left, where v says: a stage it names that this screen does not draw is passed
// by, and the stage selected stays as the screen opened on it where the person named a tab, as kit flow <stage> does.
func (m Model) Restored(v ViewState) Model {
	for name, st := range v.Stages {
		s := m.find(name)
		if s == nil {
			continue
		}
		s.Cursor, s.Offset, s.Shift = max(st.Cursor, 0), max(st.Offset, 0), max(st.Shift, 0)
		s.Open = grid.Outline(maps.Clone(st.Open))
		if s.Open == nil {
			s.Open = grid.Outline{}
		}
		s.Picked = map[string]bool{}
		for _, key := range st.Picked {
			s.Picked[key] = true
		}
	}
	if k := m.indexOf(v.Stage); k >= 0 && m.words.Tab == "" {
		m.stage = k
	}
	m.rebuild()
	return m
}

// indexOf gives the index of the stage named, or -1.
func (m Model) indexOf(name string) int {
	for i, s := range m.stages {
		if s.name == name {
			return i
		}
	}
	return -1
}
