package table

import (
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// stackViews is the views of one table, "things" in the app "issues", with a global preset, an app preset, and a tab
// preset each active, and a built-in that filters state.
func stackViews() Views {
	return Views{
		Fields: resolveFields,
		Own: []Preset{
			{Name: "Underway", Fields: map[string]Setting{"state": {Filter: inc("underway")}}},
			{Name: "Compact"},
		},
		Saved: []Preset{{Name: "Wide", Fields: map[string]Setting{"title": {Sort: "asc", Priority: 1}}}},
		Team:  []Preset{{Name: "Team's"}},
		Scoped: Scoped{
			Global: []Preset{{Name: "Mine", Fields: map[string]Setting{"assignee": {Filter: inc("@me")}}},
				{Name: "By org", Fields: map[string]Setting{"org": grp(1)}}},
			Apps:   map[string][]Preset{"issues": {{Name: "By repo", Fields: map[string]Setting{"repo": grp(1)}}}},
			Active: map[string][]string{"global": {"By org", "Mine"}, "app:issues": {"By repo"}, "tab:things": {"Wide"}},
		},
		App: "issues", Tab: "things",
	}
}

func layerNames(layers []Layer) []string {
	var out []string
	for _, l := range layers {
		out = append(out, l.Name)
	}
	return out
}

func TestStackOrder(t *testing.T) {
	layers := stackViews().Stack("Underway", &Preset{Name: EditName})
	if got, want := layerNames(layers), []string{"By org", "Mine", "By repo", "Underway", "Wide", EditName}; !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
	var levels []Level
	for _, l := range layers {
		levels = append(levels, l.Level)
	}
	if want := []Level{LevelGlobal, LevelGlobal, LevelApp, LevelTab, LevelTab, LevelEdit}; !slices.Equal(levels, want) {
		t.Errorf("levels %v, want %v", levels, want)
	}
}

func TestStackSkipsAnActiveNameThatIsGone(t *testing.T) {
	v := stackViews()
	v.Scoped.Active = map[string][]string{"global": {"Gone", "Mine"}, "app:issues": {"Gone"}, "tab:things": {"Gone"}}
	if got, want := layerNames(v.Stack("Underway", nil)), []string{"Mine", "Underway"}; !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestStackWithNothingActiveIsTheBase(t *testing.T) {
	v := stackViews()
	v.Scoped.Active = nil
	if got, want := layerNames(v.Stack("Compact", nil)), []string{"Compact"}; !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
	if got, want := layerNames(v.Stack("Gone", nil)), []string{"Underway"}; !slices.Equal(got, want) {
		t.Errorf("a base that is gone is the opening view: got %q, want %q", got, want)
	}
}

func TestStackTabMixinsComeFromAnyOfTheTablesViews(t *testing.T) {
	v := stackViews()
	v.Scoped.Active = map[string][]string{"tab:things": {"Team's", "Compact", "Wide"}}
	if got, want := layerNames(v.Stack("Underway", nil)), []string{"Underway", "Team's", "Compact", "Wide"}; !slices.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestAppliedResolvesTheStack(t *testing.T) {
	got, prov := stackViews().Applied("Underway", nil)
	// the app's grouping replaces the global one: the narrower layer's list wins
	want := Preset{Fields: map[string]Setting{"assignee": {Filter: inc("@me")}, "repo": grp(1),
		"state": {Filter: inc("underway")}, "title": {Sort: "asc", Priority: 1}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
	if c, ok := prov.Why("repo", FacetPlace); !ok || c.Layer != "By repo" || c.Level != LevelApp {
		t.Errorf("why repo is grouped: %+v, %v", c, ok)
	}
}

func TestAppliedWithAPanelIsTheStackWithThePanelsEdit(t *testing.T) {
	v := stackViews()
	under, _ := v.Applied("Underway", nil)
	edited := under
	edited.Fields = map[string]Setting{}
	for id, s := range under.Fields {
		edited.Fields[id] = s
	}
	edited.Fields["title"] = Setting{Sort: "desc", Priority: 1}
	panel := edited.Panel(v.Fields, grid.Panel{})
	got, _ := v.Applied("Underway", &panel)
	if a := got.Panel(v.Fields, grid.Panel{}); !reflect.DeepEqual(a, panel) {
		t.Errorf("the stack with the edit sets %+v, want the panel %+v", a, panel)
	}
}

// Saving at global scope keeps what the person changed, never what the tab's own base says.
func TestIsReadsTheStack(t *testing.T) {
	v := stackViews()
	under, _ := v.Applied("Underway", nil)
	table := Table{ViewName: "Underway", View: under.Panel(v.Fields, grid.Panel{})}
	if got := v.Is(table); got != "Underway" {
		t.Errorf("a table set as its base with presets active is %q, want Underway", got)
	}
	table.View = Preset{}.Panel(v.Fields, grid.Panel{})
	if got := v.Is(table); got != "" {
		t.Errorf("a table that is the base without the active presets is %q, want none: the stack is in force", got)
	}
	v.Scoped.Active = nil
	if got := v.Is(table); got != "Compact" {
		t.Errorf("with none active, a table as no view has it is as the first it matches: %q, want Compact", got)
	}
}

func TestIsFindsAnotherViewAsTheStack(t *testing.T) {
	v := stackViews()
	compact := v.stacked(Preset{Name: "Compact"})
	table := Table{ViewName: "Underway", View: compact.Panel(v.Fields, grid.Panel{})}
	if got := v.Is(table); got != "Compact" {
		t.Errorf("got %q, want Compact: the table is Compact under the active presets", got)
	}
}

func layersOf(ps []Preset) []Layer {
	var out []Layer
	for _, p := range ps {
		out = append(out, Layer{Name: p.Name, Preset: p})
	}
	return out
}

// Saving what a person changed does not change what they see: the stack with the saved preset in it sets the panel the
// stack with the edit set.
func TestStackedIsTheBaseWhereNothingIsActiveAndTheStackWhereSomethingIs(t *testing.T) {
	v := stackViews()
	base := v.Chosen("Underway")
	got := v.Stacked(base)
	if got.Fields["assignee"].Filter == nil || got.Fields["repo"].Placement != PlaceGroup {
		t.Errorf("the stack: %+v", got)
	}
	v.Scoped.Active = nil
	if got := v.Stacked(base); !reflect.DeepEqual(got, base) {
		t.Errorf("nothing active: %+v", got)
	}
}

func TestToggleActivatesAndDeactivatesAPresetAtALevel(t *testing.T) {
	v := stackViews()
	scoped, err := v.Toggle(LevelGlobal, "Mine")
	if err != nil || slices.Contains(scoped.Active["global"], "Mine") || !slices.Contains(v.Scoped.Active["global"], "Mine") {
		t.Fatalf("off: %v, %v (the views it was asked of: %v)", err, scoped.Active, v.Scoped.Active)
	}
	v.Scoped = scoped
	scoped, _ = v.Toggle(LevelGlobal, "Mine")
	if got := scoped.Active["global"]; !slices.Equal(got, []string{"By org", "Mine"}) {
		t.Errorf("on again goes last: %v", got)
	}
	scoped, _ = v.Toggle(LevelApp, "By repo")
	if len(scoped.Active["app:issues"]) != 0 {
		t.Errorf("the app's: %v", scoped.Active)
	}
	scoped, _ = v.Toggle(LevelTab, "Compact")
	if got := scoped.Active["tab:things"]; !slices.Equal(got, []string{"Wide", "Compact"}) {
		t.Errorf("the table's, of any of its views: %v", got)
	}
	if got, err := v.Toggle(LevelGlobal, "Gone"); err != ErrGone || !reflect.DeepEqual(got, Scoped{}) {
		t.Errorf("a preset that is not there: %v, %+v", err, got)
	}
	if _, err := v.Toggle(LevelEdit, "Mine"); err != ErrScope {
		t.Errorf("an edit: %v", err)
	}
}

func TestRebasedKeepsTheEditOverAChangedStack(t *testing.T) {
	v := stackViews()
	base := "Underway"
	under, _ := v.Applied(base, nil)
	panel := under.Panel(v.Fields, grid.Panel{})
	// the person sorts by title, an edit, then switches Mine off everywhere
	panel = panel.Sorted("title")
	next := v
	next.Scoped, _ = v.Toggle(LevelGlobal, "Mine")
	got := PresetOf(v.Rebased(next, base, panel), v.Fields)
	if got.Fields["assignee"].Filter != nil || got.Fields["title"].Sort != "asc" || got.Fields["state"].Filter == nil {
		t.Errorf("rebased: %+v", got)
	}
}

func TestRestoredPutsTheLastPanelOverTheStackSoDeactivatingStillTakesAwayWhatItGave(t *testing.T) {
	v := stackViews()
	under, _ := v.Applied("Underway", nil)
	last := PresetOf(under.Panel(v.Fields, grid.Panel{}).Sorted("title"), v.Fields)
	last.Name = "Underway"
	got := v.Restored(last)
	if got.Fields["assignee"].Filter == nil || got.Fields["title"].Sort != "asc" {
		t.Fatalf("restored: %+v", got)
	}
	// a view of the person's own, left whole, restores as it was: nothing active, the panel as left
	plain := stackViews()
	plain.Scoped.Active = nil
	whole := PresetOf(plain.Chosen("Underway").Panel(plain.Fields, grid.Panel{}).Sorted("title"), plain.Fields)
	whole.Name = "Underway"
	if got := plain.Restored(whole); !plain.Same(got, whole) {
		t.Errorf("a panel left with nothing active: %+v, want %+v", got, whole)
	}
}

func TestKeepViewsKeepsTheScopedPresetsAndTheTablesApartAndTogether(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	v := stackViews()
	v.Scoped, v.Saved = Scoped{}, nil
	// a scoped change alone leaves the table's presets as they were
	scoped, _ := stackViews().Toggle(LevelGlobal, "Mine")
	all, got, err := KeepViews(path, "things", v, nil, scoped)
	if err != nil || all != nil || !reflect.DeepEqual(got.Active, scoped.Active) {
		t.Fatalf("scoped alone: %v, %v, %+v", err, all, got)
	}
	// both
	v.Scoped = got
	all, got, err = KeepViews(path, "things", v, []Preset{{Name: "Wide"}}, got)
	if err != nil || len(all["things"]) != 1 {
		t.Fatalf("saved: %v, %+v", err, all)
	}
	if read, err := ReadScoped(path); err != nil || !reflect.DeepEqual(read.Active, got.Active) {
		t.Errorf("read back: %v, %+v", err, read)
	}
	// nothing changed writes nothing and gives what it was given
	if all, got2, err := KeepViews(path, "things", v, v.Saved, v.Scoped); err != nil || all != nil || !reflect.DeepEqual(got2, v.Scoped) {
		t.Errorf("nothing: %v, %v, %+v", err, all, got2)
	}
	// a file that does not read is the error, for either part
	bad := filepath.Join(t.TempDir(), "bad.json")
	if err := os.WriteFile(bad, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := KeepViews(bad, "things", v, nil, stackViews().Scoped); err == nil {
		t.Error("a bad file kept a scoped change")
	}
	if _, _, err := KeepViews(bad, "things", v, []Preset{{Name: "x"}}, v.Scoped); err == nil {
		t.Error("a bad file kept a preset")
	}
}
