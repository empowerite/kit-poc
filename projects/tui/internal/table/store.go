// The person's presets, kept in a file of their own, presets.json under the kit's config directory, so their views
// follow them to every repository: each table's, by the table's name, in the catalog's vocabulary, its fields by id;
// each table's favorites, the names of the views the person starred, in their order; and each table's panel as the
// person last left it, so it opens as it was, named by the view it was set as.
package table

import (
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"syscall"
)

// PresetsVersion is the version of the presets file that holds presets of global and app scope, and which are active.
// A file that holds none of them is written as baseVersion, which every kittui reads.
const (
	PresetsVersion = 3
	baseVersion    = 2
)

// presetsFile is the presets file: its version, the person's presets, by table, their favorites, by table, the panel
// each table was last left as, by table, and, from version 3, the presets of global scope, the presets of each app,
// and the names of the presets active in each scope.
type presetsFile struct {
	Version   int                 `json:"version"`
	Stages    map[string][]Preset `json:"stages"`
	Favorites map[string][]string `json:"favorites,omitempty"`
	Last      map[string]Preset   `json:"last,omitempty"`
	Global    []Preset            `json:"global,omitempty"`
	Apps      map[string][]Preset `json:"apps,omitempty"`
	Active    map[string][]string `json:"active,omitempty"`
}

// PresetsPath gives the file the person's presets are kept in: kit/presets.json under XDG_CONFIG_HOME, else under
// ~/.config; nothing when neither is known.
func PresetsPath() string {
	dir := os.Getenv("XDG_CONFIG_HOME")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		dir = filepath.Join(home, ".config")
	}
	return filepath.Join(dir, "kit", "presets.json")
}

// ReadPresets gives the presets the file keeps, by table; none for no file named. A file that is not there is the
// error, as os.ReadFile says, so a screen can read what it kept before; one that does not read, or is of another
// version, is the error too.
func ReadPresets(path string) (map[string][]Preset, error) {
	file, err := readFile(path)
	return file.Stages, err
}

// ReadFavorites gives the favorites the file keeps, by table, a map never nil; none for no file named, nor for one that
// does not read, which ReadPresets says.
func ReadFavorites(path string) map[string][]string {
	file, _ := readFile(path)
	return file.Favorites
}

// readFile gives the presets file as it reads, its maps never nil; empty for no file named. A file that is not there is
// the error, as os.ReadFile says; one that does not read, or is of another version, is the error too.
func readFile(path string) (presetsFile, error) {
	out := presetsFile{Stages: map[string][]Preset{}, Favorites: map[string][]string{}, Last: map[string]Preset{},
		Apps: map[string][]Preset{}, Active: map[string][]string{}}
	if path == "" {
		return out, nil
	}
	data, err := os.ReadFile(path)
	if err != nil && os.IsNotExist(err) {
		return out, err
	}
	var file presetsFile
	if err == nil {
		err = json.Unmarshal(data, &file)
	}
	if err == nil && file.Version != baseVersion && file.Version != PresetsVersion {
		err = fmt.Errorf("version %d, not %d", file.Version, PresetsVersion)
	}
	if err != nil {
		return out, fmt.Errorf("%s does not read as presets: %w", path, err)
	}
	maps.Copy(out.Stages, file.Stages)
	maps.Copy(out.Favorites, file.Favorites)
	maps.Copy(out.Last, file.Last)
	out.Global = file.Global
	maps.Copy(out.Apps, file.Apps)
	maps.Copy(out.Active, file.Active)
	return out, nil
}

// WritePresets keeps the presets in the file, the favorites as it holds them, written whole beside it first, so a
// reader never sees half of it; none for no file named.
func WritePresets(path string, tables map[string][]Preset) error {
	defer lock(path)()
	file, _ := readFile(path)
	file.Stages = tables
	return writeFile(path, file)
}

// writeFile keeps the presets file whole, written beside it first, so a reader never sees half of it; nothing for no
// file named.
func writeFile(path string, file presetsFile) error {
	if path == "" {
		return nil
	}
	file.Version = baseVersion
	if len(file.Global)+len(file.Apps)+len(file.Active) > 0 {
		file.Version = PresetsVersion
	}
	if len(file.Favorites) == 0 {
		file.Favorites = nil
	}
	if len(file.Last) == 0 {
		file.Last = nil
	}
	// presets are strings, numbers, and maps of them, which always marshal
	data, _ := json.MarshalIndent(file, "", "  ")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return writeWhole(path, append(data, '\n'))
}

// writeWhole keeps a file whole: the data written to a file of its own beside it, whose name no other writer shares,
// then renamed over it, so a reader never sees half of it and two writers never truncate each other's.
func writeWhole(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".*.new")
	if err != nil {
		return err
	}
	_, wrote := tmp.Write(data)
	err = errors.Join(wrote, tmp.Close(), os.Chmod(tmp.Name(), 0o644))
	if err == nil {
		err = os.Rename(tmp.Name(), path)
	}
	if err != nil {
		_ = os.Remove(tmp.Name())
	}
	return err
}

// lock holds the presets file against other writers, until the function it gives is called: an advisory lock on a file
// beside it, so one writer's read, change, and write finish before the next one's read. Where the lock cannot be taken,
// as on a file system that has none, the writer goes on without it.
func lock(path string) (unlock func()) {
	if path == "" {
		return func() {}
	}
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	f, err := os.OpenFile(path+".lock", os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return func() {}
	}
	_ = syscall.Flock(int(f.Fd()), syscall.LOCK_EX)
	return func() { _ = f.Close() } // closing the file lets go of the lock
}

// Kept is one table's presets and its favorites, as a screen holds them.
type Kept struct {
	Saved     []Preset
	Favorites []string
}

// KeepPresets keeps what a screen did to one table's presets and favorites in the file. The screen gives them as it
// last read or wrote them, was, and as it wants them, now. The store reads the file again and does to the table's
// lists there what the screen did to its own, as merged says, so what another kittui saved, starred, or deleted since
// the screen read the file stays as that kittui left it, in this table as in every other; then it writes the file
// whole. A table's favorites are given as they stand, those that name a view since gone already dropped, so saving
// drops them. It gives every table's presets and the table's favorites, as written, which the screen then holds. A
// file that is not there yet, or none named, holds nothing another kittui did: the table's lists are then as the
// screen wants them, and the file is written new. A file that does not read is the error, and nothing is written.
func KeepPresets(path, name string, was, now Kept) (map[string][]Preset, []string, error) {
	defer lock(path)()
	file, err := readFile(path)
	switch {
	case path == "" || errors.Is(err, os.ErrNotExist):
		file.Stages[name], file.Favorites[name] = was.Saved, was.Favorites
	case err != nil:
		return nil, nil, err
	}
	file.Stages[name] = merged(was.Saved, now.Saved, file.Stages[name], func(p Preset) string { return p.Name },
		func(a, b Preset) bool { return reflect.DeepEqual(a, b) })
	favorites := merged(was.Favorites, now.Favorites, file.Favorites[name], func(n string) string { return n },
		func(a, b string) bool { return a == b })
	file.Favorites[name] = favorites
	if len(favorites) == 0 {
		delete(file.Favorites, name)
	}
	if err := writeFile(path, file); err != nil {
		return nil, nil, err
	}
	return file.Stages, favorites, nil
}

// merged gives one of a table's lists as the file is to hold it: the list the file holds now, with what a screen did
// to its own copy, from was to now, done to it. An item is known by its key. One the screen added or changed is the
// screen's. One the screen left as it was is the file's: as the file holds it now, and gone where the file no longer
// holds it, because another kittui deleted it. One the file alone holds stays where the screen never held it, because
// another kittui added it, and is gone where the screen held it and took it away. The screen's items stand first, in
// its order, then those another kittui added, in the file's, so with no other writer the list is the screen's, now,
// as given.
func merged[T any](was, now, file []T, key func(T) string, same func(a, b T) bool) []T {
	find := func(list []T, k string) (T, bool) {
		at := slices.IndexFunc(list, func(t T) bool { return key(t) == k })
		if at < 0 {
			var none T
			return none, false
		}
		return list[at], true
	}
	var out []T
	for _, mine := range now {
		before, known := find(was, key(mine))
		theirs, held := find(file, key(mine))
		switch {
		case !known || !same(before, mine):
			out = append(out, mine)
		case held:
			out = append(out, theirs)
		}
	}
	for _, theirs := range file {
		_, mine := find(now, key(theirs))
		if _, known := find(was, key(theirs)); !mine && !known {
			out = append(out, theirs)
		}
	}
	return out
}

// ReadLast gives the panel each table was last left as, by table, a map never nil, each named by the view it was set
// as; none for no file named, nor for one that does not read, which ReadPresets says.
func ReadLast(path string) map[string]Preset {
	file, _ := readFile(path)
	return file.Last
}

// KeepLast keeps the panel one table was last left as in the file, named by the view it was set as, the rest as the
// file holds it; a file that does not read is the error, and nothing is written.
func KeepLast(path, name string, last Preset) error {
	defer lock(path)()
	file, err := readFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	file.Last[name] = last
	return writeFile(path, file)
}

// KeepFavorites keeps what a screen did to one table's favorites in the file, from was to now, as KeepPresets does,
// the table's presets as the file holds them. It gives the table's favorites, as written.
func KeepFavorites(path, name string, was, now []string) ([]string, error) {
	file, err := readFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	saved := file.Stages[name]
	_, favorites, err := KeepPresets(path, name, Kept{Saved: saved, Favorites: was}, Kept{Saved: saved, Favorites: now})
	return favorites, err
}
