package table

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// resolveFields are the fields the fold's tests give a tab: some that can group, sort, and filter, one that holds a list,
// and one without a label, which no preset can show.
var resolveFields = []Field{
	{ID: "org", Label: "Org", Group: true, Sort: true, Filter: true, Renderings: []string{"text", "badge"}},
	{ID: "repo", Label: "Repo", Group: true, Sort: true, Filter: true},
	{ID: "state", Label: "State", Group: true, Sort: true, Filter: true},
	{ID: "assignee", Label: "Assignee", Filter: true},
	{ID: "title", Label: "Title", Sort: true},
	{ID: "labels", Label: "Labels", One: "label", Renderings: []string{"list", "count"}},
	{ID: "key"},
}

func grp(depth int) Setting { return Setting{Placement: PlaceGroup, Depth: depth} }

func inc(v ...string) *ValueFilter { return &ValueFilter{Include: v} }

func layerOf(name string, level Level, fields map[string]Setting, add ...Facet) Layer {
	return Layer{Name: name, Level: level, Preset: Preset{Name: name, Fields: fields, Add: Facets(add...)}}
}

// constraintOf gives the one constraint a layer gave a field in a facet, off or not.
func constraintOf(t *testing.T, p Provenance, layer, field string, facet Facet, off bool) Constraint {
	t.Helper()
	var found []Constraint
	for _, c := range p.Constraints {
		if c.Layer == layer && c.Field == field && c.Facet == facet && c.Off == off {
			found = append(found, c)
		}
	}
	if len(found) != 1 {
		t.Fatalf("want one constraint of %s on %s in %s (off %v), got %v", layer, field, facet, off, found)
	}
	return found[0]
}

func TestResolveNarrowestWins(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("Mine", LevelGlobal, map[string]Setting{"assignee": {Filter: inc("@me")}, "state": {Filter: inc("open")}}),
		layerOf("Underway", LevelTab, map[string]Setting{"state": {Filter: inc("underway")}}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"assignee": {Filter: inc("@me")}, "state": {Filter: inc("underway")}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveExcludeFilter(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("Hide done", LevelGlobal, map[string]Setting{"state": {Filter: &ValueFilter{Exclude: []string{"done"}}}}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"state": {Filter: &ValueFilter{Exclude: []string{"done"}}}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveEmptyFilterSaysNothing(t *testing.T) {
	got, p := Resolve([]Layer{
		layerOf("Empty", LevelGlobal, map[string]Setting{"state": {Filter: &ValueFilter{}}}),
	}, resolveFields)
	if !reflect.DeepEqual(got, Preset{}) || len(p.Constraints) != 0 {
		t.Errorf("got %+v and %v, want nothing", got, p.Constraints)
	}
}

func TestResolveListReplaces(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("By org, repo", LevelGlobal, map[string]Setting{"org": grp(1), "repo": grp(2)}),
		layerOf("By state", LevelTab, map[string]Setting{"state": grp(1)}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"state": grp(1)}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveListAdds(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("By org, repo", LevelGlobal, map[string]Setting{"org": grp(1), "repo": grp(2)}),
		layerOf("Then state", LevelTab, map[string]Setting{"state": grp(1), "org": grp(1)}, FacetPlace),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2), "state": grp(3)}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveGroupsNumberedByDepth(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("Deep", LevelGlobal, map[string]Setting{"repo": grp(5), "org": grp(2)}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2)}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveSortReplacesAndAdds(t *testing.T) {
	base := layerOf("By title", LevelGlobal, map[string]Setting{"title": {Sort: "asc", Priority: 1}})
	cases := map[string]struct {
		next Layer
		want Preset
	}{
		"replaces": {
			layerOf("By state", LevelTab, map[string]Setting{"state": {Sort: "desc", Priority: 1}}),
			Preset{Fields: map[string]Setting{"state": {Sort: "desc", Priority: 1}}},
		},
		"adds": {
			layerOf("Then state", LevelTab, map[string]Setting{"state": {Sort: "desc", Priority: 1}}, FacetSort),
			Preset{Fields: map[string]Setting{"title": {Sort: "asc", Priority: 1}, "state": {Sort: "desc", Priority: 2}}},
		},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if got, _ := Resolve([]Layer{base, c.next}, resolveFields); !reflect.DeepEqual(got, c.want) {
				t.Errorf("got %+v, want %+v", got, c.want)
			}
		})
	}
}

func TestResolveSortIgnoresADirectionItDoesNotKnow(t *testing.T) {
	got, p := Resolve([]Layer{layerOf("Odd", LevelGlobal, map[string]Setting{"title": {Sort: "sideways", Priority: 1}})}, resolveFields)
	if !reflect.DeepEqual(got, Preset{}) || len(p.Constraints) != 0 {
		t.Errorf("got %+v and %v, want nothing", got, p.Constraints)
	}
}

func TestResolveOrderReplacesAndAdds(t *testing.T) {
	base := layerOf("Columns", LevelGlobal, map[string]Setting{
		"title": {Placement: PlaceColumn, Position: 1}, "org": {Placement: PlaceColumn, Position: 2}})
	replaced, _ := Resolve([]Layer{base,
		layerOf("State first", LevelTab, map[string]Setting{"state": {Placement: PlaceColumn, Position: 1}})}, resolveFields)
	if want := (Preset{Fields: map[string]Setting{"state": {Placement: PlaceColumn, Position: 1}}}); !reflect.DeepEqual(replaced, want) {
		t.Errorf("replaced: got %+v, want %+v", replaced, want)
	}
	added, _ := Resolve([]Layer{base,
		layerOf("Then state", LevelTab, map[string]Setting{"state": {Placement: PlaceColumn, Position: 1}}, FacetOrder)}, resolveFields)
	want := Preset{Fields: map[string]Setting{"title": {Placement: PlaceColumn, Position: 1},
		"org": {Placement: PlaceColumn, Position: 2}, "state": {Placement: PlaceColumn, Position: 3}}}
	if !reflect.DeepEqual(added, want) {
		t.Errorf("added: got %+v, want %+v", added, want)
	}
}

func TestResolveHiddenStaysUntilPlaced(t *testing.T) {
	hide := layerOf("Plain", LevelGlobal, map[string]Setting{"title": {Placement: PlaceHidden}})
	quiet := layerOf("Quiet", LevelApp, map[string]Setting{"org": {Filter: inc("a")}})
	if got, _ := Resolve([]Layer{hide, quiet}, resolveFields); got.Fields["title"].Placement != PlaceHidden {
		t.Errorf("title is %+v, want hidden", got.Fields["title"])
	}
	show := layerOf("Show", LevelTab, map[string]Setting{"title": {Placement: PlaceColumn}})
	if got, _ := Resolve([]Layer{hide, quiet, show}, resolveFields); got.Fields["title"] != (Setting{Placement: PlaceColumn}) {
		t.Errorf("title is %+v, want a column", got.Fields["title"])
	}
	pos := layerOf("Position", LevelTab, map[string]Setting{"title": {Placement: PlaceColumn, Position: 1}})
	if got, _ := Resolve([]Layer{hide, pos}, resolveFields); got.Fields["title"] != (Setting{Placement: PlaceColumn, Position: 1}) {
		t.Errorf("title is %+v, want a column at 1", got.Fields["title"])
	}
}

func TestResolveHidingLeavesGroupsAndOrder(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("Groups", LevelGlobal, map[string]Setting{"org": grp(1), "state": grp(2),
			"title": {Placement: PlaceColumn, Position: 1}}),
		layerOf("Hide", LevelTab, map[string]Setting{"org": {Placement: PlaceHidden}, "title": {Placement: PlaceHidden}}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": {Placement: PlaceHidden}, "state": grp(1),
		"title": {Placement: PlaceHidden}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolvePlacingAColumnLeavesTheGroups(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("Groups", LevelGlobal, map[string]Setting{"org": grp(1), "repo": grp(2)}),
		layerOf("Columns", LevelTab, map[string]Setting{"org": {Placement: PlaceColumn},
			"repo": {Placement: PlaceColumn, Position: 1}}, FacetPlace),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": {Placement: PlaceColumn}, "repo": {Placement: PlaceColumn, Position: 1}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveRender(t *testing.T) {
	global := layerOf("Badges", LevelGlobal, map[string]Setting{"org": {Rendering: "badge"}, "labels": {Flat: true}})
	tab := layerOf("Text", LevelTab, map[string]Setting{"org": {Rendering: "text"}})
	got, _ := Resolve([]Layer{global, tab}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": {Rendering: "text"}, "labels": {Flat: true}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveRenderAppliesWhatItCan(t *testing.T) {
	got, p := Resolve([]Layer{layerOf("Mixed", LevelGlobal, map[string]Setting{
		"title": {Rendering: "badge", Flat: true},
		"org":   {Rendering: "badge", Flat: true},
	})}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": {Rendering: "badge"}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
	if c := constraintOf(t, p, "Mixed", "title", FacetRender, false); c.Status != NotApplicable || c.Reason != "no such rendering" {
		t.Errorf("title's render is %+v, want not applicable, no such rendering", c)
	}
}

func TestResolveOff(t *testing.T) {
	mine := layerOf("Mine", LevelGlobal, map[string]Setting{"assignee": {Filter: inc("@me")}})
	off := layerOf("Everyone", LevelTab, map[string]Setting{"assignee": {Off: Facets(FacetFilter)}})
	if got, _ := Resolve([]Layer{mine, off}, resolveFields); !reflect.DeepEqual(got, Preset{}) {
		t.Errorf("off: got %+v, want nothing", got)
	}
	again := layerOf("Bob's", LevelEdit, map[string]Setting{"assignee": {Filter: inc("bob")}})
	want := Preset{Fields: map[string]Setting{"assignee": {Filter: inc("bob")}}}
	if got, _ := Resolve([]Layer{mine, off, again}, resolveFields); !reflect.DeepEqual(got, want) {
		t.Errorf("on again: got %+v, want %+v", got, want)
	}
}

func TestResolveOffWinsInTheSameSetting(t *testing.T) {
	got, p := Resolve([]Layer{layerOf("Both", LevelTab, map[string]Setting{
		"assignee": {Filter: inc("@me"), Off: Facets(FacetFilter)}})}, resolveFields)
	if !reflect.DeepEqual(got, Preset{}) {
		t.Errorf("got %+v, want nothing", got)
	}
	if c := constraintOf(t, p, "Both", "assignee", FacetFilter, true); c.Status != InForce {
		t.Errorf("off is %+v, want in force", c)
	}
}

func TestResolveOffEachFacet(t *testing.T) {
	base := layerOf("Base", LevelGlobal, map[string]Setting{
		"org":    {Placement: PlaceGroup, Depth: 1, Sort: "asc", Priority: 1, Rendering: "badge", Flat: false},
		"title":  {Placement: PlaceHidden},
		"state":  {Placement: PlaceColumn, Position: 1},
		"labels": {Flat: true},
	})
	cases := map[string]struct {
		off   map[string]Setting
		field string
		want  Setting
	}{
		"place ungroups":    {map[string]Setting{"org": {Off: Facets(FacetPlace)}}, "org", Setting{Sort: "asc", Priority: 1, Rendering: "badge"}},
		"place unhides":     {map[string]Setting{"title": {Off: Facets(FacetPlace)}}, "title", Setting{}},
		"order":             {map[string]Setting{"state": {Off: Facets(FacetOrder)}}, "state", Setting{}},
		"sort":              {map[string]Setting{"org": {Off: Facets(FacetSort)}}, "org", Setting{Placement: PlaceGroup, Depth: 1, Rendering: "badge"}},
		"render":            {map[string]Setting{"org": {Off: Facets(FacetRender)}}, "org", Setting{Placement: PlaceGroup, Depth: 1, Sort: "asc", Priority: 1}},
		"render drops flat": {map[string]Setting{"labels": {Off: Facets(FacetRender)}}, "labels", Setting{}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got, _ := Resolve([]Layer{base, layerOf("Off", LevelTab, c.off)}, resolveFields)
			if got.Fields[c.field] != c.want {
				t.Errorf("%s is %+v, want %+v", c.field, got.Fields[c.field], c.want)
			}
		})
	}
}

func TestResolveAbsentFieldIsNotApplicable(t *testing.T) {
	got, p := Resolve([]Layer{layerOf("Mine", LevelGlobal, map[string]Setting{"author": {Filter: inc("@me")}})}, resolveFields)
	if !reflect.DeepEqual(got, Preset{}) {
		t.Errorf("got %+v, want no filter: Review Focus 2", got)
	}
	c := constraintOf(t, p, "Mine", "author", FacetFilter, false)
	if c.Status != NotApplicable || c.Reason != "no such field" || c.Level != LevelGlobal {
		t.Errorf("got %+v, want not applicable, no such field, global", c)
	}
}

func TestResolveAbsentFieldOffIsNotApplicable(t *testing.T) {
	_, p := Resolve([]Layer{layerOf("Off", LevelTab, map[string]Setting{"author": {Off: Facets(FacetFilter)}})}, resolveFields)
	if c := constraintOf(t, p, "Off", "author", FacetFilter, true); c.Status != NotApplicable {
		t.Errorf("got %+v, want not applicable", c)
	}
}

func TestResolveFieldCannot(t *testing.T) {
	cases := map[string]struct {
		field   string
		setting Setting
		facet   Facet
		reason  string
	}{
		"group":     {"assignee", grp(1), FacetPlace, "cannot group"},
		"hide":      {"key", Setting{Placement: PlaceHidden}, FacetPlace, "has no label"},
		"column":    {"key", Setting{Placement: PlaceColumn}, FacetPlace, "has no label"},
		"position":  {"key", Setting{Placement: PlaceColumn, Position: 2}, FacetOrder, "has no label"},
		"sort":      {"assignee", Setting{Sort: "asc", Priority: 1}, FacetSort, "cannot sort"},
		"filter":    {"title", Setting{Filter: inc("x")}, FacetFilter, "cannot filter"},
		"rendering": {"title", Setting{Rendering: "badge"}, FacetRender, "no such rendering"},
		"flat":      {"title", Setting{Flat: true}, FacetRender, "holds no list"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got, p := Resolve([]Layer{layerOf("L", LevelGlobal, map[string]Setting{c.field: c.setting})}, resolveFields)
			if !reflect.DeepEqual(got, Preset{}) {
				t.Errorf("got %+v, want nothing applied", got)
			}
			if k := constraintOf(t, p, "L", c.field, c.facet, false); k.Status != NotApplicable || k.Reason != c.reason {
				t.Errorf("got %+v, want not applicable, %q", k, c.reason)
			}
		})
	}
}

func TestResolveSortCanBeAListField(t *testing.T) {
	got, _ := Resolve([]Layer{layerOf("By labels", LevelGlobal, map[string]Setting{"labels": {Sort: "desc", Priority: 1}})}, resolveFields)
	want := Preset{Fields: map[string]Setting{"labels": {Sort: "desc", Priority: 1}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveInapplicableListKeepsTheBroader(t *testing.T) {
	got, p := Resolve([]Layer{
		layerOf("By org, repo", LevelGlobal, map[string]Setting{"org": grp(1), "repo": grp(2)}),
		layerOf("By ghost", LevelTab, map[string]Setting{"ghost": grp(1), "title": grp(2)}),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2)}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v: Review Focus 1", got, want)
	}
	if c := constraintOf(t, p, "By org, repo", "org", FacetPlace, false); c.Status != InForce {
		t.Errorf("org's group is %+v, want in force", c)
	}
}

func TestResolveProvenance(t *testing.T) {
	_, p := Resolve([]Layer{
		layerOf("Open", LevelGlobal, map[string]Setting{"state": {Filter: inc("open")}, "org": grp(1),
			"assignee": {Filter: inc("@me")}}),
		layerOf("Done", LevelApp, map[string]Setting{"state": {Filter: inc("done")}, "assignee": {Off: Facets(FacetFilter)}}),
		layerOf("By state", LevelTab, map[string]Setting{"state": grp(1)}),
	}, resolveFields)
	for _, c := range []struct {
		layer, field string
		facet        Facet
		off          bool
		want         Status
	}{
		{"Open", "state", FacetFilter, false, Overridden},
		{"Done", "state", FacetFilter, false, InForce},
		{"Open", "assignee", FacetFilter, false, Off},
		{"Done", "assignee", FacetFilter, true, InForce},
		{"Open", "org", FacetPlace, false, Overridden},
		{"By state", "state", FacetPlace, false, InForce},
	} {
		if got := constraintOf(t, p, c.layer, c.field, c.facet, c.off); got.Status != c.want {
			t.Errorf("%s's %s on %s is %v, want %v", c.layer, c.facet, c.field, got.Status, c.want)
		}
	}
	if c, ok := p.Why("state", FacetFilter); !ok || c.Layer != "Done" {
		t.Errorf("why state's filter: got %+v, %v, want Done", c, ok)
	}
	if c, ok := p.Why("assignee", FacetFilter); !ok || c.Layer != "Done" || !c.Off {
		t.Errorf("why assignee's filter: got %+v, %v, want Done's off", c, ok)
	}
	if _, ok := p.Why("title", FacetFilter); ok {
		t.Error("why title's filter: found one, want none")
	}
}

func TestResolveOffAnOverriddenOff(t *testing.T) {
	_, p := Resolve([]Layer{
		layerOf("Off", LevelApp, map[string]Setting{"assignee": {Off: Facets(FacetFilter)}}),
		layerOf("On", LevelTab, map[string]Setting{"assignee": {Filter: inc("bob")}}),
	}, resolveFields)
	if c := constraintOf(t, p, "Off", "assignee", FacetFilter, true); c.Status != Overridden {
		t.Errorf("off is %+v, want overridden by the filter after it", c)
	}
}

func TestResolveAddKeepsAFieldWhereItStands(t *testing.T) {
	got, p := Resolve([]Layer{
		layerOf("Org", LevelGlobal, map[string]Setting{"org": grp(1)}),
		layerOf("Again", LevelTab, map[string]Setting{"org": grp(1)}, FacetPlace),
	}, resolveFields)
	if want := (Preset{Fields: map[string]Setting{"org": grp(1)}}); !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
	if c := constraintOf(t, p, "Again", "org", FacetPlace, false); c.Status != Overridden {
		t.Errorf("got %+v, want overridden: the field stands where it did", c)
	}
}

func TestResolveAddIgnoresFacetsThatAreNotLists(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("A", LevelGlobal, map[string]Setting{"state": {Filter: inc("open")}}),
		layerOf("B", LevelTab, map[string]Setting{"state": {Filter: inc("done")}}, FacetFilter, FacetRender),
	}, resolveFields)
	if want := (Preset{Fields: map[string]Setting{"state": {Filter: inc("done")}}}); !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestResolveNoLayersFoldToNothing(t *testing.T) {
	got, p := Resolve(nil, resolveFields)
	if !reflect.DeepEqual(got, Preset{}) || len(p.Constraints) != 0 {
		t.Errorf("got %+v and %v, want nothing", got, p.Constraints)
	}
}

func TestResolveDoesNotShareItsFilters(t *testing.T) {
	in := layerOf("Mine", LevelGlobal, map[string]Setting{"assignee": {Filter: inc("@me")}})
	got, _ := Resolve([]Layer{in}, resolveFields)
	got.Fields["assignee"].Filter.Include[0] = "changed"
	if in.Preset.Fields["assignee"].Filter.Include[0] != "@me" {
		t.Error("the fold's filter shares its values with the layer's")
	}
}

// The preset a fold gives sets a panel as one layer that states the same does: the table applies it as it applies any.
func TestResolvedPanelEqualsApplied(t *testing.T) {
	all := map[string]Setting{
		"org":      grp(1),
		"title":    {Placement: PlaceHidden},
		"state":    {Sort: "desc", Priority: 1, Filter: inc("open")},
		"assignee": {Filter: inc("@me")},
		"labels":   {Flat: true},
	}
	one := layerOf("One", LevelTab, all)
	folded, _ := Resolve([]Layer{
		layerOf("Global", LevelGlobal, map[string]Setting{"org": grp(1), "assignee": {Filter: inc("@me")}}),
		layerOf("Tab", LevelTab, map[string]Setting{"title": {Placement: PlaceHidden}, "labels": {Flat: true},
			"state": {Sort: "desc", Priority: 1, Filter: inc("open")}}),
	}, resolveFields)
	want, _ := Resolve([]Layer{one}, resolveFields)
	a, b := folded.Panel(resolveFields, grid.Panel{}), want.Panel(resolveFields, grid.Panel{})
	if !reflect.DeepEqual(a, b) {
		t.Errorf("a stack's panel is %+v, one layer's is %+v", a, b)
	}
}

func TestResolveAddKeepsASortWhereItStands(t *testing.T) {
	got, _ := Resolve([]Layer{
		layerOf("By title", LevelGlobal, map[string]Setting{"title": {Sort: "asc", Priority: 1}}),
		layerOf("Again", LevelTab, map[string]Setting{"title": {Sort: "desc", Priority: 1}}, FacetSort),
	}, resolveFields)
	want := Preset{Fields: map[string]Setting{"title": {Sort: "asc", Priority: 1}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestFacetSetJSON(t *testing.T) {
	set := Facets(FacetFilter, FacetPlace, Facet("nonsense"))
	data, err := json.Marshal(set)
	if err != nil || string(data) != `["place","filter"]` {
		t.Fatalf("marshal: got %s, %v, want [\"place\",\"filter\"]", data, err)
	}
	var back FacetSet
	if err := json.Unmarshal(data, &back); err != nil || back != set {
		t.Errorf("unmarshal: got %v, %v, want %v", back, err, set)
	}
	if set.Has(Facet("nonsense")) || set.Has(FacetSort) || !set.Has(FacetPlace) {
		t.Error("Has says a facet is in the set that is not, or not that is")
	}
}

func TestFacetSetJSONRefusesWhatIsNotAFacet(t *testing.T) {
	var s FacetSet
	err := json.Unmarshal([]byte(`["filter","nonsense"]`), &s)
	if err == nil || !strings.Contains(err.Error(), `"nonsense" is not a facet; want one of place order sort filter render`) {
		t.Errorf("got %v, want the refusal to name the facets", err)
	}
	if err := json.Unmarshal([]byte(`"filter"`), &s); err == nil {
		t.Error("a facet that is not in a list was read")
	}
}

func TestPresetsKeepOffAndAddInTheFile(t *testing.T) {
	in := Preset{Name: "Mine", Add: Facets(FacetPlace), Fields: map[string]Setting{"assignee": {Off: Facets(FacetFilter)}}}
	data, err := json.Marshal(in)
	if err != nil || !strings.Contains(string(data), `"add":["place"]`) || !strings.Contains(string(data), `"off":["filter"]`) {
		t.Fatalf("marshal: got %s, %v", data, err)
	}
	var back Preset
	if err := json.Unmarshal(data, &back); err != nil || !reflect.DeepEqual(back, in) {
		t.Errorf("round trip: got %+v, %v, want %+v", back, err, in)
	}
	plain, _ := json.Marshal(Preset{Name: "Plain", Fields: map[string]Setting{"title": {Sort: "asc"}}})
	if strings.Contains(string(plain), "off") || strings.Contains(string(plain), "add") {
		t.Errorf("a preset that adds and switches off nothing says so: %s", plain)
	}
}

func TestResolveSortsNumberedByPriority(t *testing.T) {
	got, _ := Resolve([]Layer{layerOf("Two keys", LevelGlobal, map[string]Setting{
		"title": {Sort: "desc", Priority: 9}, "state": {Sort: "asc", Priority: 2}})}, resolveFields)
	want := Preset{Fields: map[string]Setting{"state": {Sort: "asc", Priority: 1}, "title": {Sort: "desc", Priority: 2}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestFacetSetWithout(t *testing.T) {
	s := Facets(FacetFilter, FacetSort)
	if got := s.Without(FacetFilter); got != Facets(FacetSort) || got.Has(FacetFilter) {
		t.Errorf("without filter: %v", got)
	}
	if got := s.Without("nothing"); got != s {
		t.Errorf("without a name that is no facet: %v", got)
	}
}
