package table

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
)

func scopedFile(t *testing.T, text string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "presets.json")
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func fileText(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func named(names ...string) []Preset {
	var out []Preset
	for _, n := range names {
		out = append(out, Preset{Name: n, Fields: map[string]Setting{"assignee": {Filter: inc("@me")}}})
	}
	return out
}

func TestScopeKey(t *testing.T) {
	for _, c := range []struct {
		level Level
		name  string
		want  string
	}{
		{LevelGlobal, "ignored", "global"},
		{LevelApp, "issues", "app:issues"},
		{LevelTab, "things", "tab:things"},
		{LevelEdit, "things", ""},
	} {
		if got := ScopeKey(c.level, c.name); got != c.want {
			t.Errorf("ScopeKey(%v, %q) is %q, want %q", c.level, c.name, got, c.want)
		}
	}
}

func TestReadScopedFromAVersionTwoFile(t *testing.T) {
	path := scopedFile(t, `{"version": 2, "stages": {"things": [{"name": "x"}]}}`)
	got, err := ReadScoped(path)
	if err != nil || len(got.Global) != 0 || got.Apps == nil || got.Active == nil || len(got.Apps)+len(got.Active) != 0 {
		t.Errorf("a version 2 file reads as no scoped presets, maps never nil: %+v, %v", got, err)
	}
	if all, err := ReadPresets(path); err != nil || len(all["things"]) != 1 {
		t.Errorf("its tab presets read as ever: %+v, %v", all, err)
	}
}

func TestReadScopedWithNoFile(t *testing.T) {
	if got, err := ReadScoped(""); err != nil || got.Apps == nil || got.Active == nil {
		t.Errorf("no file named: %+v, %v, want empty, maps never nil", got, err)
	}
	if _, err := ReadScoped(filepath.Join(t.TempDir(), "none.json")); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("a file that is not there: %v, want os.ErrNotExist as ReadPresets says", err)
	}
}

func TestReadScopedRefusesAnotherVersion(t *testing.T) {
	_, err := ReadScoped(scopedFile(t, `{"version": 4}`))
	if err == nil || !strings.Contains(err.Error(), "version 4, not 3") {
		t.Errorf("got %v, want the file's version and the one read", err)
	}
	if _, err := ReadScoped(scopedFile(t, `not json`)); err == nil {
		t.Error("a file that is not JSON was read")
	}
}

func TestScopedPresetsRoundTripAsVersionThree(t *testing.T) {
	path := filepath.Join(t.TempDir(), "kit", "presets.json")
	want := Scoped{Global: named("Mine"), Apps: map[string][]Preset{"issues": named("By org")},
		Active: map[string][]string{"global": {"Mine"}, "app:issues": {"By org"}}}
	got, err := KeepScoped(path, Scoped{}, want)
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Fatalf("kept: %+v, %v, want %+v", got, err, want)
	}
	if read, err := ReadScoped(path); err != nil || !reflect.DeepEqual(read, want) {
		t.Errorf("read back: %+v, %v, want %+v", read, err, want)
	}
	if !strings.Contains(fileText(t, path), `"version": 3`) {
		t.Errorf("a file with scoped presets is version 3: %s", fileText(t, path))
	}
}

func TestAFileWithNoScopedPresetsStaysVersionTwo(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	if err := WritePresets(path, map[string][]Preset{"things": named("x")}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(fileText(t, path), `"version": 2`) {
		t.Errorf("an older kittui reads a file that has none: %s", fileText(t, path))
	}
	if _, err := KeepScoped(path, Scoped{}, Scoped{}); err != nil || !strings.Contains(fileText(t, path), `"version": 2`) {
		t.Errorf("keeping none changed the version: %v %s", err, fileText(t, path))
	}
}

func TestKeepScopedKeepsWhatTheFileHoldsOfTheRest(t *testing.T) {
	path := scopedFile(t, `{"version": 2, "stages": {"things": [{"name": "x"}]}, "favorites": {"things": ["x"]},
		"last": {"things": {"name": "x"}}}`)
	if _, err := KeepScoped(path, Scoped{}, Scoped{Global: named("Mine")}); err != nil {
		t.Fatal(err)
	}
	all, _ := ReadPresets(path)
	if len(all["things"]) != 1 || !slices.Equal(ReadFavorites(path)["things"], []string{"x"}) || ReadLast(path)["things"].Name != "x" {
		t.Errorf("saving a global preset dropped a table's presets, favorites, or last panel: %+v", all)
	}
	if _, _, err := KeepPresets(path, "things", Kept{Saved: all["things"]}, Kept{Saved: all["things"]}); err != nil {
		t.Fatal(err)
	}
	if got, _ := ReadScoped(path); len(got.Global) != 1 {
		t.Errorf("saving a table's presets dropped the global ones: %+v", got)
	}
}

// Two kittuis read the file, each saves a global preset of its own, and a third deletes one: each keeps the others' work.
func TestTwoWritersKeepEachOthersScopedPresets(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	a, err := KeepScoped(path, Scoped{}, Scoped{Global: named("A"), Apps: map[string][]Preset{"issues": named("A app")},
		Active: map[string][]string{"global": {"A"}}})
	if err != nil {
		t.Fatal(err)
	}
	// b read the file before a wrote it, and saves its own
	b, err := KeepScoped(path, Scoped{}, Scoped{Global: named("B"), Apps: map[string][]Preset{"changes": named("B app")},
		Active: map[string][]string{"global": {"B"}, "app:changes": {"B app"}}})
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"A", "B"} {
		if !slices.ContainsFunc(b.Global, func(p Preset) bool { return p.Name == name }) {
			t.Errorf("b's save lost the global preset %q: %+v", name, b.Global)
		}
	}
	if len(b.Apps["issues"]) != 1 || len(b.Apps["changes"]) != 1 {
		t.Errorf("each app's presets stay: %+v", b.Apps)
	}
	if got := b.Active["global"]; len(got) != 2 {
		t.Errorf("both writers' active names stay, a scope's names merged: %q", got)
	}
	// a deletes its preset and its active name: the other's stay, and the deleted one is gone
	c, err := KeepScoped(path, a, Scoped{Apps: map[string][]Preset{"issues": named("A app")}})
	if err != nil {
		t.Fatal(err)
	}
	if len(c.Global) != 1 || c.Global[0].Name != "B" || !slices.Equal(c.Active["global"], []string{"B"}) {
		t.Errorf("a deleted A and left B: %+v %q", c.Global, c.Active["global"])
	}
	if len(c.Apps["changes"]) != 1 {
		t.Errorf("another writer's app presets stay: %+v", c.Apps)
	}
}

func TestKeepScopedDropsAScopeThatHoldsNothing(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	first := Scoped{Apps: map[string][]Preset{"issues": named("x")}, Active: map[string][]string{"app:issues": {"x"}}}
	if _, err := KeepScoped(path, Scoped{}, first); err != nil {
		t.Fatal(err)
	}
	got, err := KeepScoped(path, first, Scoped{})
	if err != nil || len(got.Apps) != 0 || len(got.Active) != 0 {
		t.Errorf("an app with no presets, and a scope with no names, stay in the file: %+v, %v", got, err)
	}
	if strings.Contains(fileText(t, path), "apps") || strings.Contains(fileText(t, path), "active") {
		t.Errorf("the file keeps empty scopes: %s", fileText(t, path))
	}
}

func TestKeepScopedKeepsActiveNamesInTheirOrder(t *testing.T) {
	path := filepath.Join(t.TempDir(), "presets.json")
	got, err := KeepScoped(path, Scoped{}, Scoped{Active: map[string][]string{"global": {"C", "A", "B"}}})
	if err != nil || !slices.Equal(got.Active["global"], []string{"C", "A", "B"}) {
		t.Errorf("got %q, %v, want the order C, A, B", got.Active["global"], err)
	}
	if read, _ := ReadScoped(path); !slices.Equal(read.Active["global"], []string{"C", "A", "B"}) {
		t.Errorf("the file kept %q, want the order C, A, B", read.Active["global"])
	}
	// names the screen left as they were stay where they stand when it adds one
	more := Scoped{Active: map[string][]string{"global": {"C", "A", "B", "D"}}}
	if got, err := KeepScoped(path, got, more); err != nil || !slices.Equal(got.Active["global"], []string{"C", "A", "B", "D"}) {
		t.Errorf("adding D: got %q, %v", got.Active["global"], err)
	}
}

func TestKeepScopedWithNoFileNamedHoldsNothingElse(t *testing.T) {
	was := Scoped{Global: named("A")}
	now := Scoped{Global: named("A", "B")}
	got, err := KeepScoped("", was, now)
	if err != nil || len(got.Global) != 2 {
		t.Errorf("got %+v, %v, want the screen's own lists, as it wants them", got, err)
	}
}

func TestKeepScopedDoesNotWriteOverAFileThatDoesNotRead(t *testing.T) {
	path := scopedFile(t, `{"version": 9}`)
	if _, err := KeepScoped(path, Scoped{}, Scoped{Global: named("A")}); err == nil {
		t.Fatal("a file that does not read was written over")
	}
	if got := fileText(t, path); got != `{"version": 9}` {
		t.Errorf("the file changed: %s", got)
	}
}

func TestKeepScopedReportsAFileItCannotWrite(t *testing.T) {
	dir := t.TempDir()
	if err := os.Chmod(dir, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) })
	if _, err := KeepScoped(filepath.Join(dir, "presets.json"), Scoped{}, Scoped{Global: named("A")}); err == nil {
		t.Error("a folder that takes no new file was not reported")
	}
}
