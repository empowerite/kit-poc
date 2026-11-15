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

// quiet is a file with a preset active everywhere that hides the note.
func quiet(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "presets.json")
	if _, err := KeepScoped(path, Scoped{}, Scoped{Global: []Preset{{Name: "Quiet",
		Fields: map[string]Setting{"note": {Placement: PlaceHidden}}}}, Active: map[string][]string{"global": {"Quiet"}}}); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestAPresetActiveEverywhereAppliesOnOpeningAndAClickTurnsItOffAndOn(t *testing.T) {
	path := quiet(t)
	s := sheet(path)
	if slices.Contains(s.ShownColumns(), "note") {
		t.Fatalf("opened with Quiet active: %q", s.ShownColumns())
	}
	// ✅ on its line; a click on it stops it being active; the note shows again, and the file says so
	k := itemAt(t, &s, "Quiet")
	if PresetItems(&s)[k].Glyph != Checked {
		t.Error("no ✅")
	}
	s.choose(k)
	if !slices.Contains(s.ShownColumns(), "note") || !strings.Contains(s.Notice().Text, "stopped Quiet being active everywhere") {
		t.Errorf("off: %q, %q", s.ShownColumns(), s.Notice().Text)
	}
	if read, _ := ReadScoped(path); len(read.Active["global"]) != 0 || len(read.Global) != 1 {
		t.Errorf("the file: %+v", read)
	}
	s.choose(itemAt(t, &s, "Quiet"))
	if slices.Contains(s.ShownColumns(), "note") || !strings.Contains(s.Notice().Text, "made Quiet active everywhere") {
		t.Errorf("on again: %q, %q", s.ShownColumns(), s.Notice().Text)
	}
	// what the person changed stays where the stack changes beneath it
	s.SetPanel(s.Panel().Placed("kind", grid.Hidden))
	s.choose(itemAt(t, &s, "Quiet"))
	if !slices.Contains(s.ShownColumns(), "note") || slices.Contains(s.ShownColumns(), "kind") {
		t.Errorf("the edit under a changed stack: %q", s.ShownColumns())
	}
	// another sheet of the file opens as the file says
	if other := sheet(path); !slices.Contains(other.ShownColumns(), "note") {
		t.Errorf("another sheet: %q", other.ShownColumns())
	}
}

func TestAFileThatNoLongerReadsIsNotWrittenOverByAToggleAndAGhostIsLeftAlone(t *testing.T) {
	path := quiet(t)
	s := sheet(path)
	if err := os.WriteFile(path, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	s.toggle(LevelGlobal, "Quiet")
	if !strings.Contains(s.Notice().Text, "could not be changed") {
		t.Errorf("toggle on a bad file: %q", s.Notice().Text)
	}
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
