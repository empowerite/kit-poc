package flow

import (
	"reflect"
	"testing"
)

// Where the person left a screen is what State says, and a screen made again is given it back; a stage the screen does
// not draw, and a place that cannot be, are passed by.
func TestAScreenIsGivenBackWhereItWasLeft(t *testing.T) {
	m := loaded(t, options(), tab, tab)
	m.stages[m.stage].Cursor, m.stages[m.stage].Offset, m.stages[m.stage].Shift = 2, 1, 3
	m.stages[m.stage].Open["group:a"] = false
	m.stages[m.stage].Picked["7"] = true
	m.stages[m.stage].Picked["8"] = false
	left := m.State()
	if left.Stage != m.stages[m.stage].name || len(left.Stages) != len(m.stages) {
		t.Fatalf("the state: %+v", left)
	}
	if st := left.Stages[left.Stage]; st.Cursor != 2 || st.Offset != 1 || st.Shift != 3 || st.Open["group:a"] ||
		!reflect.DeepEqual(st.Picked, []string{"7"}) {
		t.Fatalf("the stage's place: %+v", st)
	}
	left.Stages["not-a-stage"] = StageState{Cursor: 5}
	left.Stages[left.Stage] = StageState{Cursor: -4, Offset: -1, Shift: -2, Open: nil, Picked: []string{"7"}}
	again := New(m.runner, options()).Restored(left)
	if again.stages[again.stage].name != left.Stage {
		t.Errorf("the tab: %s, want %s", again.stages[again.stage].name, left.Stage)
	}
	s := again.stages[again.stage]
	if s.Cursor != 0 || s.Offset != 0 || s.Shift != 0 || s.Open == nil || !s.Picked["7"] {
		t.Errorf("a place that cannot be: %+v", s.Table)
	}
	left = m.State()
	if got := New(m.runner, options()).Restored(left).State(); !reflect.DeepEqual(got, left) {
		t.Errorf("the state after it is given back:\n%+v\nwant\n%+v", got, left)
	}
}

// A tab the person named, as kit flow <stage> does, stays the tab selected.
func TestATabNamedIsNotMovedByWhereTheScreenWasLeft(t *testing.T) {
	o := options()
	m := New(loaded(t, o).runner, o)
	m.words.Tab = "issues"
	left := ViewState{Stage: m.stages[len(m.stages)-1].name}
	if got := m.Restored(left); got.stage != m.stage {
		t.Errorf("the tab moved to %d from %d", got.stage, m.stage)
	}
	// a stage named that is no stage of the screen's selects none
	m.words.Tab = ""
	if got := m.Restored(ViewState{Stage: "nothing"}); got.stage != m.stage {
		t.Errorf("the tab moved to %d", got.stage)
	}
}
