package table

import (
	"reflect"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// roundTrip says that resolving a preset with the delta from it to a panel over it sets the panel, and gives the delta.
func roundTrip(t *testing.T, applied, want Preset) Preset {
	t.Helper()
	panel := want.Panel(resolveFields, grid.Panel{})
	delta := Delta(applied, panel, resolveFields)
	got, _ := Resolve([]Layer{{Name: "applied", Preset: applied}, {Name: "edit", Level: LevelEdit, Preset: delta}}, resolveFields)
	if a := got.Panel(resolveFields, grid.Panel{}); !reflect.DeepEqual(a, panel) {
		t.Errorf("the delta %+v over %+v sets %+v, want %+v", delta, applied, a, panel)
	}
	return delta
}

func TestDeltaOfNothingChangedIsEmpty(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"org": grp(1), "state": {Sort: "asc", Priority: 1, Filter: inc("open")},
		"title": {Placement: PlaceHidden}, "labels": {Flat: true}}}
	if got := roundTrip(t, applied, applied); !reflect.DeepEqual(got, Preset{}) {
		t.Errorf("got %+v, want nothing", got)
	}
	if got := roundTrip(t, Preset{}, Preset{}); !reflect.DeepEqual(got, Preset{}) {
		t.Errorf("of nothing: got %+v, want nothing", got)
	}
}

func TestDeltaGivesAnAddedFilterAndSwitchesOffARemovedOne(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"state": {Filter: inc("open")}}}
	cases := map[string]struct {
		want  Preset
		delta Preset
	}{
		"added": {Preset{Fields: map[string]Setting{"state": {Filter: inc("open")}, "assignee": {Filter: inc("@me")}}},
			Preset{Fields: map[string]Setting{"assignee": {Filter: inc("@me")}}}},
		"removed": {Preset{}, Preset{Fields: map[string]Setting{"state": {Off: Facets(FacetFilter)}}}},
		"changed": {Preset{Fields: map[string]Setting{"state": {Filter: &ValueFilter{Exclude: []string{"done"}}}}},
			Preset{Fields: map[string]Setting{"state": {Filter: &ValueFilter{Exclude: []string{"done"}}}}}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if got := roundTrip(t, applied, c.want); !reflect.DeepEqual(got, c.delta) {
				t.Errorf("got %+v, want %+v", got, c.delta)
			}
		})
	}
}

func TestDeltaGivesTheWholeListThatChanged(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2)}}
	cases := map[string]struct {
		want  Preset
		delta Preset
	}{
		"another grouping": {Preset{Fields: map[string]Setting{"state": grp(1)}},
			Preset{Fields: map[string]Setting{"state": grp(1), "org": {Off: Facets(FacetPlace)}, "repo": {Off: Facets(FacetPlace)}}}},
		"reordered": {Preset{Fields: map[string]Setting{"repo": grp(1), "org": grp(2)}},
			Preset{Fields: map[string]Setting{"repo": grp(1), "org": grp(2)}}},
		"one more": {Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2), "state": grp(3)}},
			Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2), "state": grp(3)}}},
		"none": {Preset{}, Preset{Fields: map[string]Setting{"org": {Off: Facets(FacetPlace)}, "repo": {Off: Facets(FacetPlace)}}}},
		"one hidden instead": {Preset{Fields: map[string]Setting{"org": grp(1), "repo": {Placement: PlaceHidden}}},
			Preset{Fields: map[string]Setting{"org": grp(1), "repo": {Placement: PlaceHidden}}}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if got := roundTrip(t, applied, c.want); !reflect.DeepEqual(got, c.delta) {
				t.Errorf("got %+v, want %+v", got, c.delta)
			}
		})
	}
}

func TestDeltaGivesSortKeys(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"title": {Sort: "asc", Priority: 1}}}
	cases := map[string]struct {
		want  Preset
		delta Preset
	}{
		"another key": {Preset{Fields: map[string]Setting{"state": {Sort: "desc", Priority: 1}}},
			Preset{Fields: map[string]Setting{"state": {Sort: "desc", Priority: 1}, "title": {Off: Facets(FacetSort)}}}},
		"turned": {Preset{Fields: map[string]Setting{"title": {Sort: "desc", Priority: 1}}},
			Preset{Fields: map[string]Setting{"title": {Sort: "desc", Priority: 1}}}},
		"none": {Preset{}, Preset{Fields: map[string]Setting{"title": {Off: Facets(FacetSort)}}}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if got := roundTrip(t, applied, c.want); !reflect.DeepEqual(got, c.delta) {
				t.Errorf("got %+v, want %+v", got, c.delta)
			}
		})
	}
}

// A panel with its columns in another order than the table's says every column's position, from 1.
func TestDeltaGivesTheOrderOfTheColumns(t *testing.T) {
	all := []string{"title", "org", "repo", "state", "assignee", "labels"}
	cols := func(ids ...string) Preset {
		p := Preset{Fields: map[string]Setting{}}
		for k, id := range ids {
			p.Fields[id] = Setting{Placement: PlaceColumn, Position: k + 1}
		}
		return p
	}
	if got := roundTrip(t, Preset{}, cols(all...)); !reflect.DeepEqual(got, cols(all...)) {
		t.Errorf("a new order: got %+v, want %+v", got, cols(all...))
	}
	want := Preset{Fields: map[string]Setting{}}
	for _, id := range all {
		want.Fields[id] = Setting{Off: Facets(FacetOrder)}
	}
	if got := roundTrip(t, cols(all...), Preset{}); !reflect.DeepEqual(got, want) {
		t.Errorf("no order: got %+v, want %+v", got, want)
	}
	moved := cols("org", "title", "repo", "state", "assignee", "labels")
	if got := roundTrip(t, cols(all...), moved); !reflect.DeepEqual(got, moved) {
		t.Errorf("two swapped: got %+v, want %+v", got, moved)
	}
}

func TestDeltaShowsAndHidesAColumn(t *testing.T) {
	hidden := Preset{Fields: map[string]Setting{"title": {Placement: PlaceHidden}}}
	if got := roundTrip(t, Preset{}, hidden); !reflect.DeepEqual(got, hidden) {
		t.Errorf("hiding: got %+v, want %+v", got, hidden)
	}
	if got, want := roundTrip(t, hidden, Preset{}), (Preset{Fields: map[string]Setting{"title": {Off: Facets(FacetPlace)}}}); !reflect.DeepEqual(got, want) {
		t.Errorf("showing: got %+v, want %+v", got, want)
	}
}

func TestDeltaShowsAColumnTheCatalogHides(t *testing.T) {
	fields := []Field{{ID: "id", Label: "Id", Placement: PlaceHidden}, {ID: "title", Label: "Title"}}
	applied := Preset{}
	panel := Preset{Fields: map[string]Setting{"id": {Placement: PlaceColumn}}}.Panel(fields, grid.Panel{})
	got := Delta(applied, panel, fields)
	want := Preset{Fields: map[string]Setting{"id": {Placement: PlaceColumn}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestDeltaGivesHowAFieldIsDrawn(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"org": {Rendering: "badge"}}}
	cases := map[string]struct {
		want  Preset
		delta Preset
	}{
		"another": {Preset{Fields: map[string]Setting{"org": {Rendering: "text"}}},
			Preset{Fields: map[string]Setting{"org": {Rendering: "text"}}}},
		"flat": {Preset{Fields: map[string]Setting{"org": {Rendering: "badge"}, "labels": {Flat: true}}},
			Preset{Fields: map[string]Setting{"labels": {Flat: true}}}},
		"none": {Preset{}, Preset{Fields: map[string]Setting{"org": {Off: Facets(FacetRender)}}}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if got := roundTrip(t, applied, c.want); !reflect.DeepEqual(got, c.delta) {
				t.Errorf("got %+v, want %+v", got, c.delta)
			}
		})
	}
}

func TestDeltaOverTheAppliedSetsThePanelWhateverChanged(t *testing.T) {
	applied := Preset{Fields: map[string]Setting{"org": grp(1), "repo": grp(2), "title": {Sort: "asc", Priority: 1},
		"state": {Filter: inc("open")}, "labels": {Flat: true}, "assignee": {Placement: PlaceHidden}}}
	want := Preset{Fields: map[string]Setting{"state": grp(1), "title": {Sort: "desc", Priority: 1},
		"assignee": {Filter: inc("@me")}, "org": {Rendering: "badge"}}}
	roundTrip(t, applied, want)
}
