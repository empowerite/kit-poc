package table

import (
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"
)

// stacking is a host whose views are stackViews: the table "things", its fields resolveFields, set as Underway.
func stacking() *host {
	h := presetting()
	h.views = stackViews()
	h.fields = resolveFields
	h.tbl = Table{ViewName: "Underway", View: h.views.Chosen("Underway").Panel(resolveFields, h.panel)}
	return h
}

func scopeOf(s Scoped, v Views, l Level) ([]Preset, []string) {
	switch l {
	case LevelGlobal:
		return s.Global, s.Active["global"]
	case LevelApp:
		return s.Apps[v.App], s.Active["app:"+v.App]
	}
	return nil, s.Active["tab:"+v.Tab]
}

func TestSwitchOffWritesALayerWithOffAtTheLevel(t *testing.T) {
	asked := Constraint{Layer: "Mine", Level: LevelGlobal, Field: "assignee", Facet: FacetFilter}
	for _, tc := range []struct {
		level Level
		name  string
	}{{LevelTab, OffHere}, {LevelApp, OffInApp}, {LevelGlobal, OffEverywhere}} {
		v := stackViews()
		scoped, saved, err := v.SwitchOff(asked, tc.level)
		if err != nil {
			t.Fatal(err)
		}
		got := v
		got.Scoped, got.Saved = scoped, saved
		list := saved
		if tc.level != LevelTab {
			list, _ = scopeOf(scoped, v, tc.level)
		}
		k := slices.IndexFunc(list, func(p Preset) bool { return p.Name == tc.name })
		if k < 0 || !list[k].Fields["assignee"].Off.Has(FacetFilter) {
			t.Fatalf("level %d: no layer %q with the switch: %+v", tc.level, tc.name, list)
		}
		if _, active := scopeOf(scoped, v, tc.level); !slices.Contains(active, tc.name) {
			t.Errorf("level %d: %q is not active: %v", tc.level, tc.name, active)
		}
		if applied, _ := got.Applied("Underway", nil); applied.Fields["assignee"].Filter != nil {
			t.Errorf("level %d: the filter still holds: %+v", tc.level, applied.Fields["assignee"])
		}
		if v.Scoped.Active["global"][0] != "By org" || len(v.Scoped.Global) != 2 {
			t.Errorf("level %d: the views it was asked of changed", tc.level)
		}
	}
}

func TestSwitchOffKeepsWhatWasSwitchedOffBefore(t *testing.T) {
	v := stackViews()
	scoped, saved, _ := v.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelTab)
	v.Scoped, v.Saved = scoped, saved
	scoped, saved, _ = v.SwitchOff(Constraint{Field: "assignee", Facet: FacetSort}, LevelTab)
	if k := slices.IndexFunc(saved, func(p Preset) bool { return p.Name == OffHere }); k < 0 ||
		saved[k].Fields["assignee"].Off != Facets(FacetFilter, FacetSort) {
		t.Errorf("the layer: %+v", saved)
	}
	if n := slices.Index(scoped.Active["tab:things"], OffHere); n < 0 || slices.Index(scoped.Active["tab:things"][n+1:], OffHere) >= 0 {
		t.Errorf("active more than once: %v", scoped.Active["tab:things"])
	}
}

func TestSwitchOffRefusesAnEditAsALevel(t *testing.T) {
	if _, _, err := stackViews().SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelEdit); err != ErrScope {
		t.Errorf("got %v", err)
	}
}

func TestSwitchOnTakesTheSwitchAwayAndTheLayerThatHeldOnlyIt(t *testing.T) {
	v := stackViews()
	scoped, saved, _ := v.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelApp)
	v.Scoped, v.Saved = scoped, saved
	_, prov := v.Applied("Underway", nil)
	sw, ok := prov.Why("assignee", FacetFilter)
	if !ok || !sw.Off || sw.Level != LevelApp || sw.Layer != OffInApp {
		t.Fatalf("the switch in force: %+v, %v", sw, ok)
	}
	scoped, saved, err := v.SwitchOn(sw)
	if err != nil {
		t.Fatal(err)
	}
	v.Scoped, v.Saved = scoped, saved
	if apps, active := scopeOf(scoped, v, LevelApp); slices.ContainsFunc(apps, func(p Preset) bool { return p.Name == OffInApp }) ||
		slices.Contains(active, OffInApp) {
		t.Errorf("the layer stays: %+v, %v", apps, active)
	}
	if applied, _ := v.Applied("Underway", nil); applied.Fields["assignee"].Filter == nil {
		t.Error("the filter is not back")
	}
}

func TestSwitchOnLeavesWhatElseALayerSays(t *testing.T) {
	v := stackViews()
	v.Scoped.Global[1].Fields["org"] = Setting{Placement: PlaceGroup, Depth: 1, Off: Facets(FacetSort)}
	scoped, saved, err := v.SwitchOn(Constraint{Layer: "By org", Level: LevelGlobal, Field: "org", Facet: FacetSort, Off: true})
	if err != nil {
		t.Fatal(err)
	}
	if got := scoped.Global[1].Fields["org"]; got.Placement != PlaceGroup || got.Off != 0 || len(saved) != len(v.Saved) {
		t.Errorf("the setting: %+v", got)
	}
	if !slices.Contains(scoped.Active["global"], "By org") {
		t.Error("the layer that said more was deactivated")
	}
}

func TestSwitchOnAtATabAndOfAnythingNotThere(t *testing.T) {
	v := stackViews()
	scoped, saved, _ := v.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelTab)
	v.Scoped, v.Saved = scoped, saved
	scoped, saved, err := v.SwitchOn(Constraint{Layer: OffHere, Level: LevelTab, Field: "assignee", Facet: FacetFilter, Off: true})
	if err != nil || slices.ContainsFunc(saved, func(p Preset) bool { return p.Name == OffHere }) ||
		slices.Contains(scoped.Active["tab:things"], OffHere) {
		t.Errorf("the tab's layer stays: %v, %+v, %v", err, saved, scoped.Active)
	}
	// a switch no layer holds, a layer gone, and an edit are all left as they were
	for _, c := range []Constraint{
		{Layer: "Gone", Level: LevelGlobal, Field: "assignee", Facet: FacetFilter},
		{Layer: "Mine", Level: LevelGlobal, Field: "gone", Facet: FacetFilter},
	} {
		if got, _, err := v.SwitchOn(c); err != nil || len(got.Global) != len(v.Scoped.Global) {
			t.Errorf("%+v: %v, %+v", c, err, got.Global)
		}
	}
	if _, _, err := v.SwitchOn(Constraint{Level: LevelEdit}); err != ErrScope {
		t.Errorf("an edit: %v", err)
	}
}

func TestTheStackChipsNameTheLayersInForceWithTheirScope(t *testing.T) {
	var got []string
	for _, c := range StackChips(stacking()) {
		got = append(got, ansi.Strip(c.Text))
	}
	want := []string{"By org (everywhere)", "Mine (everywhere)", "By repo (in issues)", "Wide (here)"}
	if !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestAConstraintTheTabCannotUseIsDimWithItsLayerAndReason(t *testing.T) {
	h := stacking()
	h.views.Scoped.Global = append(h.views.Scoped.Global, Preset{Name: "Reviewed",
		Fields: map[string]Setting{"reviewer": {Filter: inc("@me")}}})
	h.views.Scoped.Active["global"] = append(h.views.Scoped.Active["global"], "Reviewed")
	var dim []StackChip
	for _, c := range StackChips(h) {
		if c.Card != nil {
			dim = append(dim, c)
		}
	}
	if len(dim) != 1 || ansi.Strip(dim[0].Text) != "reviewer: @me" || dim[0].Card.Reason != "no such field" ||
		dim[0].Card.Layer != "Reviewed" {
		t.Fatalf("the dim chips: %+v", dim)
	}
	if dim[0].Text == ansi.Strip(dim[0].Text) {
		t.Error("the chip is not styled")
	}
}

func TestAConstraintSwitchedOffIsDimAndOffersToComeBack(t *testing.T) {
	h := stacking()
	scoped, saved, _ := h.views.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelTab)
	h.views.Scoped, h.views.Saved = scoped, saved
	var dim []StackChip
	for _, c := range StackChips(h) {
		if c.Card != nil {
			dim = append(dim, c)
		}
	}
	if len(dim) != 1 || ansi.Strip(dim[0].Text) != "Assignee: @me" || dim[0].Card.Status != Off {
		t.Fatalf("the dim chips: %+v", dim)
	}
	card := ConstraintCard{Open: true, C: *dim[0].Card}
	var lines []string
	for _, l := range card.Lines(h) {
		lines = append(lines, ansi.Strip(l.Text))
	}
	if want := []string{"Mine (everywhere)", LineOffHere, "", OnAgain}; !slices.Equal(lines, want) {
		t.Errorf("got %q, want %q", lines, want)
	}
	scoped, saved, err := card.Choose(h, len(lines)-1)
	if err != nil || slices.ContainsFunc(saved, func(p Preset) bool { return p.Name == OffHere }) ||
		slices.Contains(scoped.Active["tab:things"], OffHere) {
		t.Errorf("on again: %v, %+v, %v", err, saved, scoped.Active)
	}
}

func TestAnInapplicableConstraintsCardOffersOffAtEachLevelAndThenItsChipGoes(t *testing.T) {
	h := stacking()
	h.views.Scoped.Global = append(h.views.Scoped.Global, Preset{Name: "Reviewed",
		Fields: map[string]Setting{"reviewer": {Filter: inc("@me")}}})
	h.views.Scoped.Active["global"] = append(h.views.Scoped.Active["global"], "Reviewed")
	var c Constraint
	for _, chip := range StackChips(h) {
		if chip.Card != nil {
			c = *chip.Card
		}
	}
	card := ConstraintCard{Open: true, C: c}
	var lines []string
	for _, l := range card.Lines(h) {
		lines = append(lines, ansi.Strip(l.Text))
	}
	want := []string{"Reviewed (everywhere)", "no such field", "", LineOffHere, LineOffInApp, LineOffEverywhere}
	if !slices.Equal(lines, want) {
		t.Fatalf("got %q, want %q", lines, want)
	}
	for k, level := range map[int]Level{3: LevelTab, 4: LevelApp, 5: LevelGlobal} {
		scoped, saved, err := card.Choose(h, k)
		if err != nil {
			t.Fatal(err)
		}
		got := h.views
		got.Scoped, got.Saved = scoped, saved
		gone := true
		for _, chip := range StackChips(&host{views: got, fields: h.fields, tbl: h.tbl}) {
			gone = gone && chip.Card == nil
		}
		list, _ := scopeOf(scoped, got, level)
		if level == LevelTab {
			list = saved
		}
		if !gone || !slices.ContainsFunc(list, func(p Preset) bool { return p.Fields["reviewer"].Off.Has(FacetFilter) }) {
			t.Errorf("level %d: the chip stays or the switch is not kept", level)
		}
	}
	// a line that is no choice does nothing
	for _, k := range []int{0, 1, 2, 99, -1} {
		if _, _, err := card.Choose(h, k); err != ErrNoChoice {
			t.Errorf("line %d: %v", k, err)
		}
	}
}

func TestADimChipSaysAFacetAndAnExcludingFilter(t *testing.T) {
	h := stacking()
	h.views.Scoped.Global = append(h.views.Scoped.Global, Preset{Name: "Odd", Fields: map[string]Setting{
		"gone": {Placement: PlaceGroup, Depth: 1}, "key": {Filter: &ValueFilter{Exclude: []string{"x"}}}}})
	h.views.Scoped.Active["global"] = append(h.views.Scoped.Active["global"], "Odd")
	var got []string
	for _, c := range StackChips(h) {
		if c.Card != nil {
			got = append(got, ansi.Strip(c.Text))
		}
	}
	if want := []string{"key: ¬x", "gone place"}; !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestSwitchingTheLastLayerOffLeavesNoActiveNames(t *testing.T) {
	v := stackViews()
	v.Scoped.Active = nil
	scoped, saved, _ := v.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelTab)
	v.Scoped, v.Saved = scoped, saved
	scoped, _, err := v.SwitchOn(Constraint{Layer: OffHere, Level: LevelTab, Field: "assignee", Facet: FacetFilter, Off: true})
	if err != nil || len(scoped.Active["tab:things"]) != 0 {
		t.Errorf("%v, %v", err, scoped.Active)
	}
}

func TestTheControlLineDrawsTheStackAndItsDimChipsAreTargets(t *testing.T) {
	h := stacking()
	h.w = 200
	h.views.Scoped.Global = append(h.views.Scoped.Global, Preset{Name: "Reviewed",
		Fields: map[string]Setting{"reviewer": {Filter: inc("@me")}}})
	h.views.Scoped.Active["global"] = append(h.views.Scoped.Active["global"], "Reviewed")
	tail := SelectorPill("Underway", "4", false)
	line, _ := Control(h, "  left", tail)
	plain := ansi.Strip(line)
	for _, want := range []string{"By org (everywhere)", "Mine (everywhere)", "By repo (in issues)", "Wide (here)",
		"Reviewed (everywhere)", "reviewer: @me", FieldsButton} {
		if !strings.Contains(plain, want) {
			t.Errorf("%q is not in %q", want, plain)
		}
	}
	spots := ControlSpots(h, "  left", tail)
	var cards []ControlSpot
	for _, s := range spots {
		if s.Card != nil {
			cards = append(cards, s)
		}
	}
	// the chips that only name a layer are no target; the dim one is, and 📇 Fields stays the last
	if len(cards) != 1 || ansi.Strip(ansi.Cut(line, cards[0].From, cards[0].Until)) != "reviewer: @me" ||
		cards[0].Card.Layer != "Reviewed" || spots[len(spots)-1].Field != "" || spots[len(spots)-1].Card != nil {
		t.Errorf("the spots: %+v", spots)
	}
}

// A click on a dim chip opens its card under it, with the keyboard on the first choice; a key or a click chooses, and
// esc, or a click off the card, closes it.
func TestTheCardOfADimChipTakesKeysAndClicks(t *testing.T) {
	h := stacking()
	h.w, h.h = 200, 40
	h.views.Scoped.Global = append(h.views.Scoped.Global, Preset{Name: "Reviewed",
		Fields: map[string]Setting{"reviewer": {Filter: inc("@me")}}})
	h.views.Scoped.Active["global"] = append(h.views.Scoped.Active["global"], "Reviewed")
	var spot ControlSpot
	for _, s := range ControlSpots(h, "  left", SelectorPill("Underway", "4", false)) {
		if s.Card != nil {
			spot = s
		}
	}
	cc := OpenConstraint(h, spot)
	if !cc.Open || cc.At != 3 || cc.X != spot.From {
		t.Fatalf("opened: %+v", cc)
	}
	box, top, left := cc.Box(h)
	if top != 4 || left > spot.From || !strings.Contains(ansi.Strip(box[0]), "filter") || len(box) != 8 {
		t.Errorf("the box at %d, %d: %q", top, left, ansi.Strip(strings.Join(box, "\n")))
	}
	if chosen := cc.Key(h, key("down")); chosen != -1 || cc.At != 4 {
		t.Errorf("down: %d, at %d", chosen, cc.At)
	}
	if chosen := cc.Key(h, tea.KeyPressMsg{Code: tea.KeyEnter}); chosen != 4 || cc.Open {
		t.Errorf("enter: %d, open %v", chosen, cc.Open)
	}
	cc = OpenConstraint(h, spot)
	if chosen := cc.Click(h, left+3, top+1+5); chosen != 5 {
		t.Errorf("a click on off everywhere: %d", chosen)
	}
	cc = OpenConstraint(h, spot)
	if chosen := cc.Click(h, left+3, top+1+1); chosen != -1 || !cc.Open {
		t.Errorf("a click on a line that is no choice: %d, open %v", chosen, cc.Open)
	}
	if chosen := cc.Click(h, 0, 0); chosen != -1 || cc.Open {
		t.Errorf("a click off it: %d, open %v", chosen, cc.Open)
	}
	// near the right edge the card keeps on the screen
	h.w = 40
	cc = OpenConstraint(h, ControlSpot{Card: spot.Card, From: 38, Until: 40})
	if box, _, left := cc.Box(h); left+ansi.StringWidth(box[0]) > 40 {
		t.Errorf("the card leaves the screen: %d + %d", left, ansi.StringWidth(box[0]))
	}
	if cc.Keys().Bindings == nil {
		t.Error("no keys")
	}
}

func TestSwitchingOffInAnAppWithNoScopedPresetsYetKeepsEveryMapUsable(t *testing.T) {
	v := Views{Fields: resolveFields, App: "issues", Tab: "things"}
	scoped, _, err := v.SwitchOff(Constraint{Field: "assignee", Facet: FacetFilter}, LevelApp)
	if err != nil || len(scoped.Apps["issues"]) != 1 || !slices.Equal(scoped.Active["app:issues"], []string{OffInApp}) {
		t.Errorf("%v, %+v", err, scoped)
	}
}
