// A team's presets: checked into the workspace, so everyone who works in it has them, under .kit/presets at its root,
// in a folder per table, a file per preset, so two people adding presets never touch one file. A file is named by its
// preset's slug, as Slug gives it, and holds the preset, its name among it. A screen reads them only in a clone kit
// trusts and the kit is installed in; writing one is a change in the working tree, which the person commits as any other.
package table

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"unicode"
)

// TeamDir is the folder, under a workspace's root, its team's presets are kept in.
const TeamDir = ".kit/presets"

// Slug gives a preset's name as its file is named: lower case, each run of what is no letter or digit a dash, with
// none at either end; preset for a name with neither.
func Slug(name string) string {
	var b strings.Builder
	dash := false
	for _, r := range strings.ToLower(name) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			if dash && b.Len() > 0 {
				b.WriteByte('-')
			}
			b.WriteRune(r)
			dash = false
		default:
			dash = true
		}
	}
	if b.Len() == 0 {
		return "preset"
	}
	return b.String()
}

// teamFile gives the file a table's team preset of the name is kept in, under dir.
func teamFile(dir, table, name string) string {
	return filepath.Join(dir, filepath.FromSlash(table), Slug(name)+".json")
}

// ReadTeam gives a table's team presets, kept under dir, by their names' order; none for no folder named, nor for a
// table with none. A folder that does not read, or a file that does not read as a preset, is the error, and the rest are
// given.
func ReadTeam(dir, table string) ([]Preset, error) {
	if dir == "" {
		return nil, nil
	}
	folder := filepath.Join(dir, filepath.FromSlash(table))
	entries, err := os.ReadDir(folder)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	var out []Preset
	var errs []error
	for _, entry := range entries {
		file := filepath.Join(folder, entry.Name())
		if entry.IsDir() || filepath.Ext(file) != ".json" {
			continue
		}
		var p Preset
		data, err := os.ReadFile(file)
		if err == nil {
			err = json.Unmarshal(data, &p)
		}
		if err == nil && p.Name == "" {
			err = errors.New("names no preset")
		}
		if err != nil {
			errs = append(errs, errors.New(file+" does not read as a preset: "+err.Error()))
			continue
		}
		out = append(out, p)
	}
	slices.SortFunc(out, func(a, b Preset) int { return strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name)) })
	return out, errors.Join(errs...)
}

// WriteTeam keeps a team preset of a table under dir, in its file, written beside it first, so a reader never sees half
// of it.
func WriteTeam(dir, table string, p Preset) error {
	file := teamFile(dir, table, p.Name)
	if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
		return err
	}
	// presets are strings, numbers, and maps of them, which always marshal
	data, _ := json.MarshalIndent(p, "", "  ")
	return writeWhole(file, append(data, '\n'))
}

// RemoveTeam takes a team preset of a table, kept under dir, away, its file removed.
func RemoveTeam(dir, table, name string) error { return os.Remove(teamFile(dir, table, name)) }
