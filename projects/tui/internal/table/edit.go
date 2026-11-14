// A person's edit is a layer. What they changed is the difference between the panel and what the stack beneath already
// sets, so saving it at global or app scope keeps the change alone, and the filter a tab's own base holds never
// travels to another tab.
package table

import (
	"cmp"
	"reflect"
	"slices"

	"github.com/empowerite/kit/projects/tui/internal/grid"
)

// Delta gives what a panel says that a preset the table applies does not, of the table's fields: each setting where it
// differs, and, in the facet, a switch off for what the preset gave and the panel no longer has. A list the panel changed,
// its groups, the order of its columns, or its sort keys, is given whole, as a layer's list replaces the broader ones;
// the preset resolved beneath the delta sets the panel as it stands.
func Delta(applied Preset, p grid.Panel, fields []Field) Preset {
	base := PresetOf(applied.Panel(fields, grid.Panel{}), fields)
	cur := PresetOf(p, fields)
	out := map[string]Setting{}
	edit := func(id string, change func(*Setting)) {
		s := out[id]
		change(&s)
		out[id] = s
	}
	off := func(id string, facet Facet) { edit(id, func(s *Setting) { s.Off |= Facets(facet) }) }

	groups := listed(base, cur, fields, groupIDs)
	for _, id := range groups.now {
		if groups.changed {
			depth := slices.Index(groups.now, id) + 1
			edit(id, func(s *Setting) { s.Placement, s.Depth = PlaceGroup, depth })
		}
	}
	order := listed(base, cur, fields, columnIDs)
	for k, id := range order.now {
		if order.changed {
			edit(id, func(s *Setting) { s.Placement, s.Position = PlaceColumn, k+1 })
		}
	}
	sorts := listed(base, cur, fields, sortIDs)
	for _, id := range sorts.now {
		sorts.changed = sorts.changed || base.Fields[id].Sort != cur.Fields[id].Sort
	}
	for k, id := range sorts.now {
		if sorts.changed {
			dir := cur.Fields[id].Sort
			edit(id, func(s *Setting) { s.Sort, s.Priority = dir, k+1 })
		}
	}
	for _, id := range order.gone {
		off(id, FacetOrder)
	}
	for _, id := range sorts.gone {
		off(id, FacetSort)
	}
	for _, f := range fields {
		b, c := base.Fields[f.ID], cur.Fields[f.ID]
		if from, to := placed(b), placed(c); from != to && to != PlaceGroup {
			switch to {
			case "":
				off(f.ID, FacetPlace)
			default:
				edit(f.ID, func(s *Setting) { s.Placement = to })
			}
		}
		if !reflect.DeepEqual(b.Filter, c.Filter) {
			if c.Filter == nil {
				off(f.ID, FacetFilter)
			} else {
				filter := *c.Filter
				edit(f.ID, func(s *Setting) { s.Filter = &filter })
			}
		}
		if b.Rendering != c.Rendering || b.Flat != c.Flat {
			if c.Rendering == "" && !c.Flat {
				off(f.ID, FacetRender)
			} else {
				edit(f.ID, func(s *Setting) { s.Rendering, s.Flat = c.Rendering, c.Flat })
			}
		}
	}
	for _, id := range groups.gone {
		if placed(cur.Fields[id]) == "" {
			off(id, FacetPlace)
		}
	}
	if len(out) == 0 {
		return Preset{}
	}
	return Preset{Fields: out}
}

// changing is one of a table's lists as a preset says it, the preset the table applies and the preset a panel is read as: the
// entries now, the entries that were and are no longer, and whether the list changed.
type changing struct {
	now, gone []string
	changed   bool
}

// listed compares one of the lists of two presets, of the table's fields.
func listed(was, now Preset, fields []Field, of func(Preset, []Field) []string) changing {
	before, after := of(was, fields), of(now, fields)
	return changing{now: after, changed: !slices.Equal(before, after),
		gone: slices.DeleteFunc(slices.Clone(before), func(id string) bool { return slices.Contains(after, id) })}
}

// placed says how a setting places its field, apart from its position: hidden, a group, or a column shown, none for the
// catalog's.
func placed(s Setting) string {
	switch {
	case s.Placement == PlaceHidden, s.Placement == PlaceGroup:
		return s.Placement
	case s.Placement == PlaceColumn && s.Position == 0:
		return PlaceColumn
	}
	return ""
}

// groupIDs gives the fields a preset groups by, the outermost first.
func groupIDs(p Preset, fields []Field) []string {
	return ordered(p, fields, func(s Setting) (bool, int) { return s.Placement == PlaceGroup, s.Depth })
}

// columnIDs gives the fields a preset positions, in their order.
func columnIDs(p Preset, fields []Field) []string {
	return ordered(p, fields, func(s Setting) (bool, int) { return s.Placement == PlaceColumn && s.Position > 0, s.Position })
}

// sortIDs gives the fields a preset sorts by, the first key first.
func sortIDs(p Preset, fields []Field) []string {
	return ordered(p, fields, func(s Setting) (bool, int) { return s.Sort == "asc" || s.Sort == "desc", s.Priority })
}

// ordered gives the fields whose settings are in a list, by the place each says it has, those that tie in the order of
// the fields.
func ordered(p Preset, fields []Field, in func(Setting) (bool, int)) []string {
	type at struct {
		id    string
		place int
	}
	var found []at
	for _, f := range fields {
		if ok, place := in(p.Fields[f.ID]); ok {
			found = append(found, at{f.ID, place})
		}
	}
	slices.SortStableFunc(found, func(a, b at) int { return cmp.Compare(a.place, b.place) })
	out := make([]string, len(found))
	for k, f := range found {
		out[k] = f.id
	}
	return out
}
