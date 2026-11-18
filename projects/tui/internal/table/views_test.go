// A table's views: which it is set as, and what the person's can be saved, renamed, and deleted as; and the file the
// person's are kept in.
package table

import (
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// views gives a table of state and title, its own views Default and Grouped, and the person's Mine, which hides title.
func views() Views {
	fields := []Field{state, title}
	return Views{Fields: fields,
		Own:   []Preset{{Name: Default}, {Name: "Grouped", Fields: map[string]Setting{"state": {Placement: PlaceGroup, Depth: 1}}}},
		Saved: []Preset{{Name: "Mine", Fields: map[string]Setting{"title": {Placement: PlaceHidden}}}}}
}

// A table opens on the first of its own views, and one without any of its own on Default; a view gone gives way to it.
func TestATableOpensOnTheFirstOfItsOwnViews(t *testing.T) {
	v := views()
	v.Own = v.Own[1:]
	if got := v.Opening().Name; got != "Grouped" || v.Chosen("gone").Name != "Grouped" {
		t.Errorf("opens on %q, a view gone gives %q", got, v.Chosen("gone").Name)
	}
	if got := (Views{}).Opening(); got.Name != Default || len(got.Fields) != 0 {
		t.Errorf("no views of its own: %+v", got)
	}
}

func TestATableIsSetAsTheViewItsPanelIsAs(t *testing.T) {
	v := views()
	if names := slices.Collect(func(yield func(string) bool) {
		for _, p := range v.All() {
			yield(p.Name)
		}
	}); !slices.Equal(names, []string{Default, "Grouped", "Mine"}) {
		t.Errorf("the views: %q", names)
	}
	if !v.Builtin("Grouped") || v.Builtin("Mine") || v.Chosen("gone").Name != Default || v.Chosen("Mine").Name != "Mine" {
		t.Error("builtin, chosen")
	}
	mine := v.Chosen("Mine").Panel(v.Fields, grid.Panel{})
	// chosen Default, the panel as Mine says: it is Mine
	if got := v.Is(Table{ViewName: Default, View: mine}); got != "Mine" {
		t.Errorf("as Mine: %q", got)
	}
	// as it grouped the rows as they loaded, it is the view chosen still
	grouped := v.Chosen("Grouped")
	if got := v.Is(Table{ViewName: Default, View: grouped.Panel(v.Fields, grid.Panel{}), Grouped: &grouped}); got != Default {
		t.Errorf("as it grouped: %q", got)
	}
	// as no view says, it is none
	other := (Preset{Fields: map[string]Setting{"state": {Placement: PlaceHidden}}}).Panel(v.Fields, grid.Panel{})
	if got := v.Is(Table{ViewName: Default, View: other}); got != "" {
		t.Errorf("as none: %q", got)
	}
	if p, ok := v.Mine("Mine"); !ok || p.Name != "Mine" {
		t.Error("the person's view")
	}
	if _, ok := v.Mine("Grouped"); ok {
		t.Error("a table's own view is the person's")
	}
}

func TestThePersonsViewsAreSavedRenamedAndDeleted(t *testing.T) {
	v := views()
	p := v.Chosen("Grouped").Panel(v.Fields, grid.Panel{})
	for name, want := range map[string]error{"": ErrUnnamed, "Grouped": ErrBuiltin} {
		if _, err := v.SaveAs(name, p); !errors.Is(err, want) {
			t.Errorf("save as %q: %v", name, err)
		}
	}
	if saved, err := v.SaveAs("Mine", p); err != nil || len(saved) != 1 || !v.Same(saved[0], v.Chosen("Grouped")) {
		t.Errorf("save over Mine: %v %+v", err, saved)
	}
	if saved, err := v.SaveAs("Yours", p); err != nil || len(saved) != 2 || saved[1].Name != "Yours" {
		t.Errorf("save as Yours: %v %+v", err, saved)
	}
	v.Saved = append(v.Saved, Preset{Name: "Yours"})
	for name, want := range map[string]error{"": ErrUnnamed, Default: ErrBuiltin, "Yours": ErrTaken} {
		if _, err := v.Rename("Mine", name); !errors.Is(err, want) {
			t.Errorf("rename to %q: %v", name, err)
		}
	}
	if saved, err := v.Rename("Mine", "Ours"); err != nil || saved[0].Name != "Ours" || v.Saved[0].Name != "Mine" {
		t.Errorf("rename: %v %+v", err, saved)
	}
	if saved, err := v.Rename("Mine", "Mine"); err != nil || saved[0].Name != "Mine" {
		t.Errorf("rename to the same name: %v %+v", err, saved)
	}
	if saved := v.Delete("Mine"); len(saved) != 1 || saved[0].Name != "Yours" || len(v.Saved) != 2 {
		t.Errorf("delete: %+v", saved)
	}
}

func TestThePersonsPresetsAreKeptInAFileOfTheirOwn(t *testing.T) {
	if got := PresetsPath(); !strings.HasSuffix(got, filepath.Join("kit", "presets.json")) {
		t.Errorf("the presets file: %q", got)
	}
	t.Setenv("XDG_CONFIG_HOME", "/somewhere")
	if got := PresetsPath(); got != "/somewhere/kit/presets.json" {
		t.Errorf("under XDG_CONFIG_HOME: %q", got)
	}
	// with no XDG_CONFIG_HOME, under ~/.config
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("HOME", "/home/ada")
	if got := PresetsPath(); got != "/home/ada/.config/kit/presets.json" {
		t.Errorf("under ~/.config: %q", got)
	}
	t.Setenv("HOME", "")
	if got := PresetsPath(); got != "" {
		t.Errorf("no home: %q", got)
	}
	dir := t.TempDir()
	file := filepath.Join(dir, "kit", "presets.json")
	if got, err := ReadPresets(""); err != nil || len(got) != 0 || WritePresets("", nil) != nil {
		t.Error("no file named")
	}
	if _, err := ReadPresets(file); !os.IsNotExist(err) {
		t.Errorf("no file: %v", err)
	}
	kept := map[string][]Preset{"issues": {{Name: "Mine"}}}
	if err := WritePresets(file, kept); err != nil {
		t.Fatal(err)
	}
	if got, err := ReadPresets(file); err != nil || got["issues"][0].Name != "Mine" {
		t.Errorf("read back: %v %+v", err, got)
	}
	for content, says := range map[string]string{"{not json": "does not read as presets", `{"version": 1}`: "version 1, not 3"} {
		if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := ReadPresets(file); err == nil || !strings.Contains(err.Error(), says) {
			t.Errorf("%s: %v", content, err)
		}
	}
	// the file cannot be written beside, as its folder takes no new file; or replaced, as it is a directory; nor its
	// directory made, as a file stands where it would be
	shut := filepath.Join(dir, "shut")
	if err := os.MkdirAll(shut, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(shut, 0o700) })
	if WritePresets(filepath.Join(shut, "presets.json"), nil) == nil {
		t.Error("a file written in a folder that takes none")
	}
	if err := os.MkdirAll(filepath.Join(dir, "taken.json", "x"), 0o755); err != nil {
		t.Fatal(err)
	}
	if WritePresets(filepath.Join(dir, "taken.json"), nil) == nil {
		t.Error("a directory replaced by the file")
	}
	if left, _ := filepath.Glob(filepath.Join(dir, "taken.json.*.new")); len(left) != 0 {
		t.Errorf("a file left beside it: %q", left)
	}
	if WritePresets(filepath.Join(file, "under-a-file", "presets.json"), nil) == nil {
		t.Error("a directory made under a file")
	}
}

// Writers of one file at once each keep what they wrote: the file stays whole, no write fails, and none loses another's
// table.
func TestWritersOfOneFileAtOnceKeepEachOthersWork(t *testing.T) {
	file := filepath.Join(t.TempDir(), "kit", "presets.json")
	var wg sync.WaitGroup
	errs := make(chan error, 4*50)
	for w := range 4 {
		wg.Go(func() {
			for range 50 {
				errs <- KeepLast(file, "table"+strconv.Itoa(w), Preset{Name: "Mine"})
			}
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	if got := ReadLast(file); len(got) != 4 {
		t.Errorf("the tables kept: %d, not 4", len(got))
	}
	if left, _ := filepath.Glob(file + ".*.new"); len(left) != 0 {
		t.Errorf("files left beside it: %q", left)
	}
	// a lock that cannot be made holds nothing, and the write goes on
	if err := os.Remove(file + ".lock"); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(file+".lock", 0o755); err != nil {
		t.Fatal(err)
	}
	if err := KeepLast(file, "late", Preset{Name: "Mine"}); err != nil || len(ReadLast(file)) != 5 {
		t.Errorf("a write with no lock: %v", err)
	}
}
