// A table's views are a stack: the presets the person made active everywhere, the presets active in the table's app, the
// table's base view, the presets active on the table, and the edits not yet saved. The stack resolves into the one
// preset the table applies, and a person saves what they changed at a scope: everywhere, in an app, or on a table.
package table

import (
	"errors"
	"maps"
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

// SaveAt gives the presets the person has with a panel saved under a name at a level, and the person's views of the
// table. Everywhere and in an app, it keeps what the panel says that the rest of the stack does not, so a filter the
// table's own view holds never travels to another table, and the preset is active there at once; a preset of the name
// that was there is changed in place, and what it said that the panel no longer says is gone. On the table, it keeps
// what the panel says beyond the presets active everywhere and in the app, as SaveAs keeps the panel where none is. A
// preset saved at a broader scope is beneath the table's own view, so where that view says the same of a field in a
// facet, the view wins. None, the name of a view of the table's own, and a name of any table's own at the broader levels
// are refused, as the team's names are; so is a name of a preset at another level, and an edit as a level.
func (v Views) SaveAt(name string, l Level, base string, p grid.Panel) (Scoped, []Preset, error) {
	switch {
	case l == LevelEdit:
		return Scoped{}, nil, ErrScope
	case name == "":
		return Scoped{}, nil, ErrUnnamed
	case v.Builtin(name), l != LevelTab && slices.Contains(v.Reserved, name):
		return Scoped{}, nil, ErrBuiltin
	case v.teams(name, ""), v.taken(name, l):
		return Scoped{}, nil, ErrTaken
	}
	rest := slices.DeleteFunc(v.layers(v.Chosen(base), nil), func(layer Layer) bool {
		return layer.Level == l && layer.Name == name
	})
	if l == LevelTab {
		rest = slices.DeleteFunc(rest, func(layer Layer) bool { return layer.Level == LevelTab })
	}
	under, _ := Resolve(rest, v.Fields)
	now := Delta(under, p, v.Fields)
	now.Name = name
	if l == LevelTab {
		return v.Scoped, upsert(v.Saved, now), nil
	}
	scoped := cloneScoped(v.Scoped)
	switch l {
	case LevelApp:
		scoped.Apps[v.App] = upsert(scoped.Apps[v.App], now)
	default:
		scoped.Global = upsert(scoped.Global, now)
	}
	key := ScopeKey(l, v.App)
	if !slices.Contains(scoped.Active[key], name) {
		scoped.Active[key] = append(scoped.Active[key], name)
	}
	return scoped, v.Saved, nil
}

// taken says whether the person has a preset of the name at a level other than the one given.
func (v Views) taken(name string, except Level) bool {
	has := func(ps []Preset) bool { return slices.ContainsFunc(ps, func(p Preset) bool { return p.Name == name }) }
	return except != LevelGlobal && has(v.Scoped.Global) || except != LevelApp && has(v.Scoped.Apps[v.App]) ||
		except != LevelTab && has(v.Saved)
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
