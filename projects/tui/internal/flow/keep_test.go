// The presets file shared: a picture keeps its stage's presets in the file as it stands when it saves, so what
// another screen saved since the picture opened stays.
package flow

import (
	"path/filepath"
	"slices"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/table"
)

func TestAPictureAndAnotherScreenSavingPresetsKeepEachOthers(t *testing.T) {
	file := filepath.Join(t.TempDir(), "presets.json")
	// the picture reads the file as it opens; the welcome guide's terms save a preset of theirs after
	m := onDropdown(t, file)
	glossary := table.Kept{Saved: []table.Preset{{Name: "Glossary"}}}
	if _, _, err := table.KeepPresets(file, "welcome/terms", table.Kept{}, glossary); err != nil {
		t.Fatal(err)
	}
	m.choosePreset(table.ItemSaveAs)
	m.stages[0].Naming = "Mine"
	m = drive(m, press(tea.KeyEnter))
	// the terms save again, after the picture
	terms := table.Kept{Saved: []table.Preset{{Name: "Glossary"}, {Name: "Short"}}}
	if _, _, err := table.KeepPresets(file, "welcome/terms", glossary, terms); err != nil {
		t.Fatal(err)
	}
	all, err := table.ReadPresets(file)
	if err != nil || len(all["issues"]) != 1 || all["issues"][0].Name != "Mine" || len(all["welcome/terms"]) != 2 {
		t.Fatalf("both writers' presets: %v %+v", err, all)
	}
	if m.saved["welcome/terms"] == nil {
		t.Errorf("the picture holds what it wrote: %+v", m.saved)
	}
}

// Two pictures on one file, as two kittui have it, each opened before the other wrote: a preset and a star of
// either's of the same stage stay when the other saves or stars, and each then holds what the file holds.
func TestTwoPicturesKeepEachOthersPresetsAndFavoritesOfOneStage(t *testing.T) {
	file := filepath.Join(t.TempDir(), "presets.json")
	a, b := onDropdown(t, file), onDropdown(t, file)
	save := func(m Model, name string) Model {
		m.choosePreset(table.ItemSaveAs)
		m.stages[0].Naming = name
		return drive(m, press(tea.KeyEnter))
	}
	names := func(ps []table.Preset) []string {
		var out []string
		for _, p := range ps {
			out = append(out, p.Name)
		}
		return out
	}
	a = save(a, "from a")
	b = save(b, "from b")
	all, err := table.ReadPresets(file)
	if want := []string{"from b", "from a"}; err != nil || !slices.Equal(names(all["issues"]), want) ||
		!slices.Equal(names(b.viewsOf(0).Saved), want) {
		t.Fatalf("a saved, then b: %v, the file holds %q, and b %q", err, names(all["issues"]), names(b.viewsOf(0).Saved))
	}
	a.favor("from a", a.viewsOf(0).Star("from a"))
	b.favor("All Issues", b.viewsOf(0).Star("All Issues"))
	if want, got := []string{"All Issues", "from a"}, table.ReadFavorites(file)["issues"]; !slices.Equal(got, want) ||
		!slices.Equal(b.viewsOf(0).Favorites(), want) {
		t.Errorf("a starred its own, then b All Issues: the file holds %q, and b %q", got, b.viewsOf(0).Favorites())
	}
	// a, which read the file before b wrote, saves another: b's preset and b's star stay, and a holds them
	a = save(a, "more of a")
	all, _ = table.ReadPresets(file)
	if want := []string{"from a", "more of a", "from b"}; !slices.Equal(names(all["issues"]), want) ||
		!slices.Equal(names(a.viewsOf(0).Saved), want) ||
		!slices.Equal(a.viewsOf(0).Favorites(), []string{"from a", "All Issues"}) {
		t.Errorf("a saved again: the file holds %q, and a %q, starred %q", names(all["issues"]),
			names(a.viewsOf(0).Saved), a.viewsOf(0).Favorites())
	}
}
