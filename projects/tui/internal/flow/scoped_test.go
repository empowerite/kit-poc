// The presets that stand beyond one stage: saved everywhere or in the app, active across every stage of the file, and
// kept as the stages were left, so a stage opens as the presets now say.
package flow

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/grid"
	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/table"
)

// noAge is a file with a preset active everywhere that hides the age, which most stages have.
func noAge(t *testing.T) string {
	t.Helper()
	file := filepath.Join(t.TempDir(), "kit", "presets.json")
	_, err := table.KeepScoped(file, table.Scoped{}, table.Scoped{
		Global: []table.Preset{{Name: "No age", Fields: map[string]table.Setting{"age": {Placement: table.PlaceHidden}}}},
		Active: map[string][]string{"global": {"No age"}}})
	if err != nil {
		t.Fatal(err)
	}
	return file
}

func ageShown(m Model) (shown []bool) {
	for i := range m.stages {
		shown = append(shown, slices.Contains(m.shownColumns(i), "age"))
	}
	return shown
}

func TestAPresetActiveEverywhereAppliesOnEveryStageAndFollowsTheToggleAndARestart(t *testing.T) {
	file := noAge(t)
	m := loaded(t, viewing(file))
	if got := ageShown(m); slices.Contains(got, true) {
		t.Fatalf("opened with No age active, the age shows: %v", got)
	}
	// the menu lists it under everywhere, with its ✅; a choice makes it no longer active, on every stage
	m = toPresets(m)
	k := slices.IndexFunc(table.PresetItems(&m), func(it shell.Item) bool { return it.Name == "No age" })
	if k < 0 || table.PresetItems(&m)[k].Glyph != Checked {
		t.Fatalf("the menu: %+v", table.PresetItems(&m))
	}
	m.choosePreset(k)
	if got := ageShown(m); slices.Contains(got, false) || !strings.Contains(keysOf(m), "stopped No age being active everywhere") {
		t.Fatalf("off: %v, %q", got, keysOf(m))
	}
	read, _ := table.ReadScoped(file)
	if len(read.Active["global"]) != 0 || len(read.Global) != 1 {
		t.Errorf("the file: %+v", read)
	}
	// a stage opens as the presets now say, however it was left: the other stages were kept again
	if again := loaded(t, viewing(file)); slices.Contains(ageShown(again), false) {
		t.Errorf("reopened: %v", ageShown(again))
	}
	// on again, and the person's own change on a stage stays
	m.setPanel(m.panel(0).Placed("title", grid.Hidden))
	m.choosePreset(k)
	if got := ageShown(m); slices.Contains(got, true) || slices.Contains(m.shownColumns(0), "title") {
		t.Errorf("on again: %v, %q", got, m.shownColumns(0))
	}
	if again := loaded(t, viewing(file)); slices.Contains(ageShown(again), true) {
		t.Errorf("reopened with it active: %v", ageShown(again))
	}
}

func TestAPresetSavedEverywhereFromAStageIsActiveAtOnceAndNotStruckThrough(t *testing.T) {
	file := filepath.Join(t.TempDir(), "kit", "presets.json")
	m := onDropdown(t, file)
	m.setPanel(m.panel(0).Placed("age", grid.Hidden))
	m.choosePreset(slices.IndexFunc(table.PresetItems(&m), func(it shell.Item) bool { return it.Name == table.SaveEverywhere }))
	if !m.stages[0].SavingAs || !m.stages[0].Scoped || !strings.Contains(presetText(m), table.SavingEverywhere) {
		t.Fatalf("naming: %q", presetText(m))
	}
	m = drive(m, typed("No age")...)
	m = drive(m, press(tea.KeyEnter))
	if !strings.Contains(keysOf(m), "saved the preset No age everywhere") || m.stages[0].ViewName != "All Issues" ||
		m.stages[0].SavingAs || m.is(0) != "All Issues" {
		t.Fatalf("saved: %q, %q, is %q", keysOf(m), m.stages[0].ViewName, m.is(0))
	}
	// the other stages follow, as does a stage opened afterwards
	if got := ageShown(m); slices.Contains(got, true) {
		t.Errorf("the stages: %v", got)
	}
	if again := loaded(t, viewing(file)); slices.Contains(ageShown(again), true) {
		t.Errorf("reopened: %v", ageShown(again))
	}
	// a name the stage's own views have is refused, and the naming goes on
	m.choosePreset(slices.IndexFunc(table.PresetItems(&m), func(it shell.Item) bool { return it.Name == table.SaveEverywhere }))
	m = drive(m, typed("Backlog")...)
	if m = drive(m, press(tea.KeyEnter)); !strings.Contains(keysOf(m), "is the stage's own") || !m.stages[0].SavingAs {
		t.Errorf("a name of a view of the stage's own: %q", keysOf(m))
	}
}

func TestADimChipsCardSwitchesAConstraintOffForEveryStage(t *testing.T) {
	file := filepath.Join(t.TempDir(), "kit", "presets.json")
	_, err := table.KeepScoped(file, table.Scoped{}, table.Scoped{
		Global: []table.Preset{{Name: "Reviewed", Fields: map[string]table.Setting{"reviewer": {Filter: &table.ValueFilter{Include: []string{"@me"}}}}}},
		Active: map[string][]string{"global": {"Reviewed"}}})
	if err != nil {
		t.Fatal(err)
	}
	m := loaded(t, viewing(file), tea.WindowSizeMsg{Width: 200, Height: 40})
	var spot table.ControlSpot
	for _, s := range m.spots() {
		if s.Card != nil {
			spot = s
		}
	}
	if spot.Card == nil {
		t.Fatalf("no dim chip: %q", presetText(m))
	}
	m.controlClick(spot.From)
	if !m.card.Open {
		t.Fatal("the card did not open")
	}
	m = drive(m, press(tea.KeyEnter))
	if m.card.Open || !strings.Contains(keysOf(m), "changed Reviewed's filter of reviewer") {
		t.Fatalf("chosen: %+v, %q", m.card, keysOf(m))
	}
	read, _ := table.ReadScoped(file)
	if !slices.Equal(read.Active["tab:issues"], []string{table.OffHere}) {
		t.Errorf("the file: %+v", read)
	}
	// the chip is gone
	for _, s := range m.spots() {
		if s.Card != nil {
			t.Errorf("the chip stays: %+v", s)
		}
	}
}

func TestAFileThatNoLongerReadsIsNotWrittenOverByASaveASwitchOrAToggle(t *testing.T) {
	file := noAge(t)
	o := viewing(file)
	// a stage the catalog does not know stands beside the issues, and follows nothing
	o.Stages = []string{"issues", "nonesuch"}
	m := loaded(t, o, tea.WindowSizeMsg{Width: 200, Height: 40})
	if m.toggle(table.LevelGlobal, "No age"); !strings.Contains(keysOf(m), "stopped No age") {
		t.Fatalf("toggle beside a stage the catalog does not know: %q", keysOf(m))
	}
	if err := os.WriteFile(file, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	m.toggle(table.LevelGlobal, "No age")
	if !strings.Contains(keysOf(m), "could not be changed") {
		t.Errorf("toggle: %q", keysOf(m))
	}
	m.stages[0].SavingAs, m.stages[0].Scoped, m.stages[0].Scope, m.stages[0].Naming = true, true, table.LevelApp, "Other"
	m.saveNamed("Other")
	if !strings.Contains(keysOf(m), "could not be saved") || !m.stages[0].SavingAs {
		t.Errorf("save: %q", keysOf(m))
	}
	card := table.ConstraintCard{Open: true, C: table.Constraint{Layer: "No age", Level: table.LevelGlobal, Field: "gone",
		Facet: table.FacetFilter, Status: table.NotApplicable, Reason: "no such field"}}
	m.switched(card, 3)
	if !strings.Contains(keysOf(m), "could not be changed") {
		t.Errorf("switch: %q", keysOf(m))
	}
	// a line that is no choice, and a preset that is not there, change nothing
	before := keysOf(m)
	m.switched(card, 0)
	m.toggle(table.LevelGlobal, "ghost")
	if keysOf(m) != before {
		t.Errorf("nothing: %q", keysOf(m))
	}
}

func TestEveryNameOfAStagesOwnViewsIsReservedAndOnlyOnce(t *testing.T) {
	names := reserved()
	if !slices.Contains(names, "Backlog") || !slices.Contains(names, table.Default) || !slices.IsSorted(names) ||
		len(slices.Compact(slices.Clone(names))) != len(names) {
		t.Errorf("reserved: %q", names)
	}
}
