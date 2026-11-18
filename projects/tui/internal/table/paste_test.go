package table

import (
	"slices"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// ranged gives a host whose age takes a range typed, and age's card with the keyboard on the line that is typed.
func ranged(t *testing.T) (*host, Popover) {
	t.Helper()
	age := Field{ID: "age", Label: "age", Type: "time", Filter: true, Renderings: []string{"age"}}
	h := &host{fields: []Field{age}, w: 80, h: 24, values: map[string][]Value{"age": {One("30"), One("90000")}},
		drawn: map[string]string{"age": "age"}}
	p := OpenPopover(h, "age", 10, 3, true)
	for p.Move(h, p.At, 1) != p.At && !p.Lines(h)[p.At].Input {
		p.Key(h, key("down"))
	}
	if !p.Lines(h)[p.At].Input {
		t.Fatalf("no typed line: %q", texts(p, h))
	}
	return h, p
}

// A card's line that is typed takes a paste after what is typed there, and enter adds the range as it adds one typed;
// a line that is not typed takes none.
func TestACardsTypedLineTakesAPaste(t *testing.T) {
	h, p := ranged(t)
	p.Key(h, tea.KeyPressMsg{Code: '>', Text: ">"})
	p.Paste(h, "=2h")
	if p.Typed != ">=2h" {
		t.Fatalf("a paste after >: %q", p.Typed)
	}
	p.Key(h, key("enter"))
	if f := h.Panel().Field("age").Filter; !slices.Equal(f.Values, []string{"≥2h"}) || p.Typed != "" {
		t.Errorf("enter after the paste: %+v, still typed %q", f, p.Typed)
	}
	p.At = 0
	if p.Paste(h, "1h"); p.Typed != "" {
		t.Errorf("a paste on a line that is not typed: %q", p.Typed)
	}
}

// The fields dialog's card takes a paste while it has the keyboard, and keeps it as the dialog keeps what is typed;
// its list takes none.
func TestTheFieldsDialogsCardTakesAPaste(t *testing.T) {
	h, _ := ranged(t)
	h.panel = grid.Panel{Columns: []string{"age"}, Labels: map[string]string{"age": "age"},
		Fields: map[string]grid.Field{}}
	c := OpenColumns(h, "age")
	c.CardAt = slices.IndexFunc(c.Card(h).Lines(h), func(l PopLine) bool { return l.Input })
	if !c.InCard || c.CardAt < 0 {
		t.Fatalf("the dialog's card has no typed line: %+v", c)
	}
	if c.Paste(h, "<5m"); c.Typed != "<5m" || c.Card(h).Typed != "<5m" {
		t.Errorf("a paste in the dialog's card: %q, the card %q", c.Typed, c.Card(h).Typed)
	}
	c.InCard = false
	if c.Paste(h, "x"); c.Typed != "<5m" {
		t.Errorf("a paste on the dialog's list: %q", c.Typed)
	}
}

// A name typed for a preset takes a paste, without the = : and ; a name never holds; with no name typed, the preset
// line takes none.
func TestAPresetsNameTakesAPaste(t *testing.T) {
	h := &host{}
	if PresetPaste(h, "mine") || h.tbl.Naming != "" {
		t.Errorf("a paste with no name typed: %q", h.tbl.Naming)
	}
	h.tbl.SavingAs, h.tbl.Naming = true, "my "
	if !PresetPaste(h, "a=b:c;d view") || h.tbl.Naming != "my abcd view" {
		t.Errorf("a paste in a name: %q", h.tbl.Naming)
	}
}

// A sheet gives a paste to its topmost open layer, which takes it whether it types it or not, then to the preset's
// name typed on its control line; its rows leave it to the screen.
func TestASheetTypesAPasteWhereItTypesAKey(t *testing.T) {
	s := sheet("")
	s.FocusRows()
	if s.Paste("x") {
		t.Error("the rows took a paste")
	}
	s.Focus()
	if s.Paste("x") {
		t.Error("the control line took a paste with no name typed")
	}
	s.choose(ItemSaveAs)
	before := s.tbl.Naming
	if !s.Paste("mine") || s.tbl.Naming != before+"mine" {
		t.Fatalf("a paste in the name typed: %q", s.tbl.Naming)
	}
	if pressed(&s, "enter"); s.tbl.ViewName != before+"mine" {
		t.Errorf("enter after the paste saved %q", s.tbl.ViewName)
	}
	// an open layer takes the paste, typed or not: a card, the fields dialog, and the presets' menu
	s.pop = OpenCard(&s, "kind", false)
	if !s.Paste("x") || s.pop.Typed != "" {
		t.Errorf("a paste under a card that types nothing: %q", s.pop.Typed)
	}
	s.pop, s.cols = Popover{}, Columns{Open: true}
	if !s.Paste("x") || s.cols.Typed != "" {
		t.Errorf("a paste under the fields dialog's list: %q", s.cols.Typed)
	}
	s.cols = Columns{}
	s.Focus()
	if pressed(&s, "tab", "tab", "enter"); !s.presets.Open {
		t.Fatal("enter on the picker did not drop the presets down")
	}
	if !s.Paste("x") || !s.presets.Open || s.tbl.Naming != "" {
		t.Errorf("a paste under the presets' menu: open %v, name %q", s.presets.Open, s.tbl.Naming)
	}
}
