// The stages' bar has the keyboard until a menu, the search, the control line, or the rows take it, which is where
// kittui's root takes q as ⌃Q.
package flow

import (
	"testing"

	tea "charm.land/bubbletea/v2"
)

func TestTheBarHasTheKeyboardUntilAnotherControlTakesIt(t *testing.T) {
	if m := loaded(t, viewing("")); !m.OnBar() {
		t.Fatalf("a picture just loaded: the bar does not have the keyboard:\n%s", raw(m))
	}
	down, esc := press(tea.KeyDown), press(tea.KeyEscape)
	// a model of its own for each case, as a copy shares its stages with the one it is copied from
	for name, msgs := range map[string][]tea.Msg{
		"the app's menu":   typed("="),
		"the tab's menu":   typed(":"),
		"the search":       typed("/"),
		"the control line": {down},
		"the rows":         {down, down},
	} {
		if m := loaded(t, viewing(""), msgs...); m.OnBar() {
			t.Errorf("under %s, the bar still has the keyboard:\n%s", name, raw(m))
		}
	}
	// esc from the rows gives the bar the keyboard back, and maximized, with no bar drawn, the keyboard is where it was
	if m := loaded(t, viewing(""), down, down, esc); !m.OnBar() {
		t.Errorf("after esc from the rows:\n%s", raw(m))
	}
	if m := loaded(t, viewing(""), typed("m")...); !m.maximized || !m.OnBar() {
		t.Errorf("maximized %v:\n%s", m.maximized, raw(m))
	}
}
