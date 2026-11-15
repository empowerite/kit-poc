// A sheet's presets that stand beyond its table: saved everywhere or in the app, active, and followed from one sheet to
// another through the file, and the card of a dim chip of the stack line.
package table

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// itemAt gives the line of the sheet's presets' menu named name.
func itemAt(t *testing.T, s *Sheet, name string) int {
	t.Helper()
	for k, it := range PresetItems(s) {
		if it.Name == name {
			return k
		}
	}
	t.Fatalf("no line %q in %q", name, itemNames(s))
	return -1
}

func TestAPresetSavedEverywhereIsActiveAtOnceAndFollowsToAnotherSheet(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	s := sheet(path)
	s.SetPanel(s.Panel().Placed("note", grid.Hidden))
	s.choose(itemAt(t, &s, SaveEverywhere))
	if !s.tbl.SavingAs || !s.tbl.Scoped || s.tbl.Scope != LevelGlobal {
		t.Fatalf("naming: %+v", s.tbl)
	}
	s.tbl.Naming = "Quiet"
	pressed(&s, "enter")
	if text := s.Notice().Text; !strings.Contains(text, "saved the preset Quiet everywhere") || s.tbl.SavingAs || s.tbl.Scoped {
		t.Fatalf("saved: %q, %+v", text, s.tbl)
	}
	// saving changed nothing the person sees: the line still names the view, not struck
	if got := s.Views().Is(s.tbl); got != Default || s.tbl.ViewName != Default {
		t.Errorf("the line names %q, set as %q", got, s.tbl.ViewName)
	}
	read, err := ReadScoped(path)
	if err != nil || len(read.Global) != 1 || read.Global[0].Name != "Quiet" || !slices.Equal(read.Active["global"], []string{"Quiet"}) {
		t.Fatalf("the file: %v, %+v", err, read)
	}
	// another sheet of the file opens with it applied
	other := sheet(path)
	if slices.Contains(other.ShownColumns(), "note") {
		t.Fatalf("another sheet: %q", other.ShownColumns())
	}
	// ✅ on its line, and a click on it stops it being active; the note shows again, and the file says so
	k := itemAt(t, &other, "Quiet")
	if PresetItems(&other)[k].Glyph != Checked {
		t.Error("no ✅")
	}
	other.choose(k)
	if !slices.Contains(other.ShownColumns(), "note") || !strings.Contains(other.Notice().Text, "stopped Quiet being active everywhere") {
		t.Errorf("off: %q, %q", other.ShownColumns(), other.Notice().Text)
	}
	if read, _ := ReadScoped(path); len(read.Active["global"]) != 0 || len(read.Global) != 1 {
		t.Errorf("the file: %+v", read)
	}
	other.choose(itemAt(t, &other, "Quiet"))
	if slices.Contains(other.ShownColumns(), "note") || !strings.Contains(other.Notice().Text, "made Quiet active everywhere") {
		t.Errorf("on again: %q, %q", other.ShownColumns(), other.Notice().Text)
	}
	// what the person changed stays where the stack changes beneath it
	other.SetPanel(other.Panel().Placed("kind", grid.Hidden))
	other.choose(itemAt(t, &other, "Quiet"))
	if !slices.Contains(other.ShownColumns(), "note") || slices.Contains(other.ShownColumns(), "kind") {
		t.Errorf("the edit under a changed stack: %q", other.ShownColumns())
	}
}

func TestAPresetSavedInTheAppSaysSoAndSavingRefusesWhatItShould(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	s := sheet(path)
	s.choose(itemAt(t, &s, SaveInApp("things")))
	if !s.tbl.Scoped || s.tbl.Scope != LevelApp {
		t.Fatalf("naming: %+v", s.tbl)
	}
	// a name that is none, and one that is the table's own, are refused, and the naming goes on
	for name, want := range map[string]string{"": "needs a name", "Default": "the table's own"} {
		s.tbl.Naming = name
		if pressed(&s, "enter"); !strings.Contains(s.Notice().Text, want) || !s.tbl.SavingAs {
			t.Errorf("%q: %q", name, s.Notice().Text)
		}
	}
	s.tbl.Naming = "By kind"
	s.SetPanel(s.Panel().Placed("note", grid.Hidden))
	pressed(&s, "enter")
	if text := s.Notice().Text; !strings.Contains(text, "saved the preset By kind in things") {
		t.Errorf("saved: %q", text)
	}
	if read, _ := ReadScoped(path); len(read.Apps["things"]) != 1 || !slices.Equal(read.Active["app:things"], []string{"By kind"}) {
		t.Errorf("the file: %+v", read)
	}
	// a file that no longer reads is not written over, and the sheet says so
	if err := os.WriteFile(path, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	s.choose(itemAt(t, &s, SaveEverywhere))
	s.tbl.Naming = "Other"
	if pressed(&s, "enter"); !strings.Contains(s.Notice().Text, "could not be saved") || !s.tbl.SavingAs {
		t.Errorf("a bad file: %q", s.Notice().Text)
	}
	s.toggle(LevelApp, "By kind")
	if !strings.Contains(s.Notice().Text, "could not be changed") {
		t.Errorf("toggle on a bad file: %q", s.Notice().Text)
	}
	// a preset that is not there is left alone
	before := s.Notice().Text
	s.toggle(LevelGlobal, "ghost")
	if s.Notice().Text != before {
		t.Errorf("ghost: %q", s.Notice().Text)
	}
}

// reviewing is a file with an active preset everywhere that filters a field the things lack, so the sheet's stack line
// carries a dim chip.
func reviewing(t *testing.T) (string, Sheet) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "presets.json")
	if _, err := KeepScoped(path, Scoped{}, Scoped{Global: []Preset{{Name: "Reviewed",
		Fields: map[string]Setting{"reviewer": {Filter: inc("@me")}}}}, Active: map[string][]string{"global": {"Reviewed"}}}); err != nil {
		t.Fatal(err)
	}
	s := sheet(path)
	s.Place(4, 16, 160, 24)
	return path, s
}

func dimChip(s Sheet) (ControlSpot, bool) {
	for _, spot := range ControlSpots(&s, s.controlLeft(), s.presetLine()) {
		if spot.Card != nil {
			return spot, true
		}
	}
	return ControlSpot{}, false
}

func TestAClickOnADimChipOpensItsCardAndAChoiceSwitchesTheConstraintOff(t *testing.T) {
	path, s := reviewing(t)
	spot, ok := dimChip(s)
	if !ok {
		t.Fatalf("no dim chip in %q", screenOf(s)[4])
	}
	s.controlClick(spot.From)
	if !s.card.Open || !s.Layered() {
		t.Fatalf("the card: %+v", s.card)
	}
	// enter takes the first choice, off here: a preset of the table's own, active on it
	pressed(&s, "enter")
	if s.card.Open || !strings.Contains(s.Notice().Text, "changed Reviewed's filter of reviewer") {
		t.Fatalf("chosen: %+v, %q", s.card, s.Notice().Text)
	}
	if _, ok := dimChip(s); ok {
		t.Error("the chip stays")
	}
	read, _ := ReadScoped(path)
	saved, _ := ReadPresets(path)
	if !slices.Equal(read.Active["tab:things"], []string{OffHere}) || len(saved["things"]) != 1 {
		t.Errorf("the file: %+v, %+v", read, saved)
	}
}

func TestAClickOnAChoiceOfTheCardSwitchesOffEverywhere(t *testing.T) {
	path, s := reviewing(t)
	spot, _ := dimChip(s)
	s.controlClick(spot.From)
	if !clickOn(t, &s, LineOffEverywhere, 1) || s.card.Open {
		t.Fatalf("clicked: %+v", s.card)
	}
	if read, _ := ReadScoped(path); !slices.Contains(read.Active["global"], OffEverywhere) {
		t.Errorf("the file: %+v", read)
	}
	// the table could not use it anyway, so with it switched off its chip is no longer listed
	if _, ok := dimChip(s); ok {
		t.Fatal("a constraint the table cannot use, switched off, is no longer listed")
	}
}

func TestACardChoiceOnAFileThatNoLongerReadsSaysSo(t *testing.T) {
	path, s := reviewing(t)
	spot, _ := dimChip(s)
	s.controlClick(spot.From)
	if err := os.WriteFile(path, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	pressed(&s, "enter")
	if !strings.Contains(s.Notice().Text, "could not be changed") {
		t.Errorf("the notice: %q", s.Notice().Text)
	}
}
