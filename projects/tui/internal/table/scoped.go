// The presets file keeps the person's presets of global and app scope beside those of each table, and the names of the
// presets active in each scope, in the order the person activated them. Writers merge by name within a scope, so what
// another kittui saved, activated, or deleted since a screen read the file stays as that kittui left it.
package table

import (
	"errors"
	"maps"
	"os"
	"reflect"
	"slices"
)

// Scoped is the person's presets of global and app scope, and which are active: the presets everywhere, the presets of
// each app, by the app's name, and the names of the active presets in each scope, by ScopeKey.
type Scoped struct {
	Global []Preset
	Apps   map[string][]Preset
	Active map[string][]string
}

// ScopeKey gives the key a scope's active names are kept under: global for every table, app:<name> for an app's, and
// tab:<name> for one table's. An edit not yet saved has no key.
func ScopeKey(l Level, name string) string {
	switch l {
	case LevelGlobal:
		return "global"
	case LevelApp:
		return "app:" + name
	case LevelTab:
		return "tab:" + name
	}
	return ""
}

// ReadScoped gives the presets of global and app scope the file keeps, and which are active, its maps never nil; none
// for no file named. A file that is not there is the error, as ReadPresets says, and so is one that does not read.
func ReadScoped(path string) (Scoped, error) {
	file, err := readFile(path)
	return Scoped{Global: file.Global, Apps: file.Apps, Active: file.Active}, err
}

// KeepScoped keeps what a screen did to the presets of global and app scope in the file, from was, as it last read or
// wrote them, to now, as it wants them, as KeepPresets does for a table's: the file is read again, and what the screen
// did to its own copy is done to the lists there, by name within a scope, so what another kittui saved or deleted since
// stays as that kittui left it; then the file is written whole, with its tables' presets, favorites, and last panels as
// they were. It gives the lists as written, those with nothing in them left out. A file that is not there yet, or none
// named, holds nothing another kittui did. A file that does not read is the error, and nothing is written.
func KeepScoped(path string, was, now Scoped) (Scoped, error) {
	defer lock(path)()
	file, err := readFile(path)
	switch {
	case path == "" || errors.Is(err, os.ErrNotExist):
		file.Global, file.Apps, file.Active = was.Global, was.Apps, was.Active
	case err != nil:
		return Scoped{}, err
	}
	file.Global = merged(was.Global, now.Global, file.Global, presetName, presetSame)
	file.Apps = mergedScopes(was.Apps, now.Apps, file.Apps, presetName, presetSame)
	file.Active = mergedScopes(was.Active, now.Active, file.Active, func(n string) string { return n },
		func(a, b string) bool { return a == b })
	if err := writeFile(path, file); err != nil {
		return Scoped{}, err
	}
	return Scoped{Global: file.Global, Apps: file.Apps, Active: file.Active}, nil
}

// presetName and presetSame say how presets are known and when they are alike, as the merge of a scope's list needs.
func presetName(p Preset) string  { return p.Name }
func presetSame(a, b Preset) bool { return reflect.DeepEqual(a, b) }

// mergedScopes merges every scope's list, as merged does one, and leaves out a scope that holds nothing.
func mergedScopes[T any](was, now, file map[string][]T, key func(T) string, same func(a, b T) bool) map[string][]T {
	scopes := map[string]bool{}
	for _, m := range []map[string][]T{was, now, file} {
		for scope := range maps.Keys(m) {
			scopes[scope] = true
		}
	}
	out := map[string][]T{}
	for scope := range scopes {
		if list := merged(was[scope], now[scope], file[scope], key, same); len(list) > 0 {
			out[scope] = slices.Clone(list)
		}
	}
	return out
}
