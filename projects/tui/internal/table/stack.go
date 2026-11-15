// A table's views are a stack: the presets the person made active everywhere, the presets active in the table's app, the
// table's base view, the presets active on the table, and the edits not yet saved. The stack resolves into the one
// preset the table applies, and a person saves what they changed at a scope: everywhere, in an app, or on a table.
package table

import (
	"errors"
	"maps"
	"reflect"
	"slices"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// EditName names the layer a person's edits not yet saved make in a stack.
const EditName = "edit"

// ErrScope refuses to save a preset at a scope that is not one: the edits not yet saved.
var ErrScope = errors.New("a preset is saved everywhere, in an app, or on a table")

// Stack gives the layers a table's view is, from the broadest scope to the narrowest, the edits last where there are
// any: the presets active everywhere and those active in the app, each in the order they were activated; the view of
// the name, or the view the table opens on when that is gone; the presets active on the table, of any of its views; and
// the edit. An active name that names a preset since gone is left out.
func (v Views) Stack(base string, edit *Preset) []Layer { return v.layers(v.Chosen(base), edit) }

// layers gives the stack of a view that is the base.
func (v Views) layers(base Preset, edit *Preset) []Layer {
	out := v.actives(LevelGlobal, v.Scoped.Global)
	out = append(out, v.actives(LevelApp, v.Scoped.Apps[v.App])...)
	out = append(out, Layer{Name: base.Name, Level: LevelTab, Preset: base})
	out = append(out, v.actives(LevelTab, v.All())...)
	if edit != nil {
		out = append(out, Layer{Name: EditName, Level: LevelEdit, Preset: *edit})
	}
	return out
}

// actives gives the layers of the presets active at a level, in the order they were activated, found among the presets.
func (v Views) actives(l Level, among []Preset) []Layer {
	name := map[Level]string{LevelApp: v.App, LevelTab: v.Tab}[l]
	var out []Layer
	for _, n := range v.Scoped.Active[ScopeKey(l, name)] {
		if k := slices.IndexFunc(among, func(p Preset) bool { return p.Name == n }); k >= 0 {
			out = append(out, Layer{Name: n, Level: l, Preset: among[k]})
		}
	}
	return out
}

// Applied gives the preset a table applies, and the provenance of every constraint in its stack, with the panel's edit
// on top where a panel is given: what the panel says that the stack beneath does not.
func (v Views) Applied(base string, p *grid.Panel) (Preset, Provenance) {
	if p == nil {
		return Resolve(v.Stack(base, nil), v.Fields)
	}
	under, _ := Resolve(v.Stack(base, nil), v.Fields)
	edit := Delta(under, *p, v.Fields)
	return Resolve(v.Stack(base, &edit), v.Fields)
}

// stacked gives the preset a view sets a table as, with the presets active everywhere, in the app, and on the table
// beneath and beside it; the view as it is where none is active.
func (v Views) stacked(base Preset) Preset {
	layers := v.layers(base, nil)
	if len(layers) == 1 {
		return base
	}
	out, _ := Resolve(layers, v.Fields)
	return out
}

// Stacked gives the preset a view sets a table as, as stacked says: the view itself where nothing is active, else the
// stack beneath and beside it resolved. Hosts apply it where they once applied the view.
func (v Views) Stacked(base Preset) Preset { return v.stacked(base) }

// Rebased gives the panel a table is set as once its views change from v to next, the person's edit kept: what the panel
// says beyond the stack of v is laid over the stack of next, so activating a preset, or no longer, changes what the
// stack gives and leaves what the person changed alone.
func (v Views) Rebased(next Views, base string, p grid.Panel) grid.Panel {
	under, _ := Resolve(v.Stack(base, nil), v.Fields)
	edit := Delta(under, p, v.Fields)
	out, _ := Resolve(next.Stack(base, &edit), next.Fields)
	return out.Panel(next.Fields, p)
}

// Restored gives the preset a table opens as, of the panel it was last left as, named by the view it was set as: the
// stack of that view with what the panel says beyond that stack laid over it. A panel left with no preset active
// restores as it was; one left with some active no longer holds what a preset gave that has since been switched off, as
// far as the panel was left alone by it.
func (v Views) Restored(last Preset) Preset {
	under, _ := Resolve(v.Stack(last.Name, nil), v.Fields)
	edit := Delta(under, last.Panel(v.Fields, grid.Panel{}), v.Fields)
	out, _ := Resolve(v.Stack(last.Name, &edit), v.Fields)
	return out
}

// ErrGone refuses to activate a preset that is not there at the level.
var ErrGone = errors.New("there is no such preset")

// Toggle gives the presets active at a level once the preset of the name is made active, last, or no longer; the views
// it was asked of are as they were. At a table, any of its views may be active. A name no preset of the level has is
// ErrGone.
func (v Views) Toggle(l Level, name string) (Scoped, error) {
	if l == LevelEdit {
		return Scoped{}, ErrScope
	}
	among, active := v.at(l)
	if l == LevelTab {
		among = v.All()
	}
	if !slices.ContainsFunc(among, func(p Preset) bool { return p.Name == name }) {
		return Scoped{}, ErrGone
	}
	if k := slices.Index(active, name); k >= 0 {
		active = slices.Delete(slices.Clone(active), k, k+1)
	} else {
		active = append(slices.Clone(active), name)
	}
	scoped, _ := v.replace(l, among, active)
	return scoped, nil
}

// KeepViews keeps what a screen did to the person's views of a table in the file, from v, as the screen last read or
// wrote them, to the presets of the table, saved, and those of global and app scope with their active names, scoped, as
// it wants them: the file is read again and merged, as KeepPresets and KeepScoped say, so what another kittui did since
// stays. It gives every table's presets, none where the table's own were not changed, and the scoped presets as
// written. A file that does not read is the error, and nothing is written for the part that failed.
func KeepViews(path, store string, v Views, saved []Preset, scoped Scoped) (map[string][]Preset, Scoped, error) {
	got := v.Scoped
	if !reflect.DeepEqual(scoped, v.Scoped) {
		var err error
		if got, err = KeepScoped(path, v.Scoped, scoped); err != nil {
			return nil, Scoped{}, err
		}
	}
	if reflect.DeepEqual(saved, v.Saved) {
		return nil, got, nil
	}
	all, _, err := KeepPresets(path, store, Kept{Saved: v.Saved, Favorites: v.Starred},
		Kept{Saved: saved, Favorites: v.Favorites()})
	if err != nil {
		return nil, Scoped{}, err
	}
	return all, got, nil
}

// upsert gives the presets with the preset in the place of the one of its name, or after them where there is none.
func upsert(presets []Preset, p Preset) []Preset {
	out := slices.Clone(presets)
	if k := slices.IndexFunc(out, func(w Preset) bool { return w.Name == p.Name }); k >= 0 {
		out[k] = p
		return out
	}
	return append(out, p)
}

// cloneScoped gives the presets of global and app scope as their own, so changing them leaves the views' as they were.
func cloneScoped(s Scoped) Scoped {
	out := Scoped{Global: slices.Clone(s.Global), Apps: maps.Clone(s.Apps), Active: map[string][]string{}}
	if out.Apps == nil {
		out.Apps = map[string][]Preset{}
	}
	for scope, names := range s.Active {
		out.Active[scope] = slices.Clone(names)
	}
	return out
}
