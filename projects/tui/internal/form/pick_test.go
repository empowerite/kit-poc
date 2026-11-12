package form

import (
	"slices"
	"strings"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/syntax"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// On a list of one value, Enter takes the row under the cursor, and the keys bar names it take while there is a row
// to take, and next when the filter leaves none. Backspace with nothing typed takes an optional list's answer back,
// and the keys bar names it clear while it would; a list the command line needs keeps its answer.
func TestAnOptionalPickIsTakenOnEnterAndClearedOnBackspace(t *testing.T) {
	m := newForm(t, "new", FromMatch(syntax.Match{Literals: []string{"file"}}), true)
	i := slices.IndexFunc(m.fields, func(f Field) bool { return f.Key == "--rule" })
	if m = focusOn(m, i); m.fields[i].Kind != Pick || m.fields[i].Required {
		t.Fatalf("--rule is not an optional list of one: %+v", m.fields[i])
	}
	if bar := m.keys().String(); !strings.Contains(bar, "⏎ take") || strings.Contains(bar, "⏎ next") ||
		!strings.Contains(bar, "⌫ erase") {
		t.Errorf("the keys on a list with a row under the cursor: %q", bar)
	}
	m = send(m, key("enter"))
	if got := m.fields[i].Values; !slices.Equal(got, []string{"a"}) || m.focus != i+1 {
		t.Fatalf("Enter on the first row: %q, focus %d", got, m.focus)
	}
	m = focusOn(m, i)
	if bar := m.keys().String(); !strings.Contains(bar, "⌫ clear") {
		t.Errorf("the keys on a list with an answer and nothing typed: %q", bar)
	}
	// what is typed is erased first, the answer kept; a filter that leaves no row has nothing for Enter to take
	m = send(m, testkit.Typed("zz")...)
	if bar := m.keys().String(); !strings.Contains(bar, "⌫ erase") || !strings.Contains(bar, "⏎ next") ||
		strings.Contains(bar, "⏎ take") {
		t.Errorf("the keys on a list with a filter no row holds: %q", bar)
	}
	m = send(m, key("backspace"), key("backspace"))
	if got := m.fields[i].Values; !slices.Equal(got, []string{"a"}) || m.input != "" {
		t.Fatalf("backspace over what is typed: %q, input %q", got, m.input)
	}
	m = send(m, key("backspace"))
	if got := m.fields[i].Values; len(got) != 0 || slices.Contains(m.CommandLine(), "--rule=a") || m.focus != i {
		t.Errorf("backspace with nothing typed: %q, line %q, focus %d", got, m.CommandLine(), m.focus)
	}
	if bar := m.keys().String(); !strings.Contains(bar, "⌫ erase") {
		t.Errorf("the keys on a list with no answer: %q", bar)
	}
	// a list the command line needs keeps its answer
	m = send(m, key("enter"))
	m = focusOn(m, i)
	m.fields[i].Required = true
	if bar := m.keys().String(); !strings.Contains(bar, "⌫ erase") {
		t.Errorf("the keys on a required list with an answer: %q", bar)
	}
	if m = send(m, key("backspace")); !slices.Equal(m.fields[i].Values, []string{"a"}) {
		t.Errorf("backspace on a required list: %q", m.fields[i].Values)
	}
}

// On a list kit refused, Enter takes what is typed, of one value or of many, and the keys bar names it take once
// something is typed; with nothing typed it moves on, and is the form's next.
func TestTheKeysBarNamesEnterTakeOnARefusedListWithSomethingTyped(t *testing.T) {
	for verb, c := range map[string]struct {
		a     Answers
		field string
	}{
		"new":    {FromMatch(syntax.Match{Literals: []string{"file"}}), "--rule"},
		"commit": {Answers{}, "<path>"},
	} {
		t.Setenv("FAKE_KIT_REFUSE", verb)
		m := newForm(t, verb, c.a, true)
		m = focusOn(m, slices.IndexFunc(m.fields, func(f Field) bool { return f.Key == c.field }))
		if bar := m.keys().String(); !m.failed[c.field] || !strings.Contains(bar, "⏎ next") {
			t.Errorf("kit %s, a refused list with nothing typed: refused %v, %q", verb, m.failed[c.field], bar)
		}
		m = send(m, testkit.Typed("x")...)
		if bar := m.keys().String(); !strings.Contains(bar, "⏎ take") || strings.Contains(bar, "⏎ next") {
			t.Errorf("kit %s, a refused list with x typed: %q", verb, bar)
		}
	}
}
