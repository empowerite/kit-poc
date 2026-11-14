// A stack of presets resolves into the one preset a table applies. The layers stand from the broadest scope to the
// narrowest, the person's edits last, and the narrowest layer wins, field by field and facet by facet. Resolve gives an
// ordinary Preset, which Preset.Panel applies as it applies any, and says of every constraint a layer gave whether it
// stands, and if it does not, why: a narrower layer decided it, a narrower layer switched it off, or the table cannot
// use it.
package table

import (
	"cmp"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
)

// Facet is one kind of instruction a preset gives about a field: place says whether it is a column, a group, or
// hidden; order, where it stands among the columns; sort, whether the rows sort by it, and at what priority; filter, the
// values the rows must hold; render, how it is drawn.
type Facet string

// The facets. The groups, the order of the columns, and the sort keys are lists; the others are field by field.
const (
	FacetPlace  Facet = "place"
	FacetOrder  Facet = "order"
	FacetSort   Facet = "sort"
	FacetFilter Facet = "filter"
	FacetRender Facet = "render"
)

// facets lists the facets in the order a field's constraints are listed.
var facets = []Facet{FacetPlace, FacetOrder, FacetSort, FacetFilter, FacetRender}

// FacetSet is a set of facets. A preset's Add holds the list facets that append to the broader layers' lists instead of
// replacing them, and a setting's Off the facets it switches off for its field. In a file it is a list of names.
type FacetSet uint8

// Facets gives the set of the facets named; a name that is no facet is left out.
func Facets(fs ...Facet) FacetSet {
	var s FacetSet
	for _, f := range fs {
		if k := slices.Index(facets, f); k >= 0 {
			s |= 1 << k
		}
	}
	return s
}

// Has says whether the set holds the facet.
func (s FacetSet) Has(f Facet) bool {
	k := slices.Index(facets, f)
	return k >= 0 && s&(1<<k) != 0
}

// MarshalJSON gives the set as the list of its facets' names, in the order of the facets.
func (s FacetSet) MarshalJSON() ([]byte, error) {
	names := []Facet{}
	for _, f := range facets {
		if s.Has(f) {
			names = append(names, f)
		}
	}
	return json.Marshal(names)
}

// UnmarshalJSON reads a list of facets' names; a name that is no facet is refused, and says which are.
func (s *FacetSet) UnmarshalJSON(data []byte) error {
	var names []Facet
	if err := json.Unmarshal(data, &names); err != nil {
		return err
	}
	*s = 0
	for _, n := range names {
		if !slices.Contains(facets, n) {
			return fmt.Errorf("%q is not a facet; want one of %s", n, strings.Trim(fmt.Sprint(facets), "[]"))
		}
		*s |= Facets(n)
	}
	return nil
}

// Level is a scope: where in kittui a layer applies. The broader stands first in a stack.
type Level int

// The levels: everywhere, in an app, on a tab, and the person's edits that are not yet saved.
const (
	LevelGlobal Level = iota
	LevelApp
	LevelTab
	LevelEdit
)

// Layer is a preset at a level, in the stack of one table.
type Layer struct {
	Name   string
	Level  Level
	Preset Preset
}

// Status says what became of a constraint: it stands, a narrower layer decided it instead, a narrower layer switched it
// off, or the table cannot use it.
type Status int

// The statuses.
const (
	InForce Status = iota
	Overridden
	Off
	NotApplicable
)

// Constraint is one instruction of a layer about one field in one facet, and what became of it. Off says that the
// instruction is the layer's switch for the facet. Reason says why a constraint is not applicable.
type Constraint struct {
	Layer  string
	Level  Level
	Field  string
	Facet  Facet
	Off    bool
	Status Status
	Reason string
}

// Provenance is every constraint the layers of a stack gave: by layer, broadest first, then by the table's fields, then
// by facet, the instructions for fields the table lacks last.
type Provenance struct{ Constraints []Constraint }

// Why gives the constraint that decided a field's facet, and whether one did: a layer's instruction that stands, or the
// switch that turned the facet off.
func (p Provenance) Why(field string, facet Facet) (Constraint, bool) {
	k := slices.IndexFunc(p.Constraints, func(c Constraint) bool {
		return c.Field == field && c.Facet == facet && c.Status == InForce
	})
	if k < 0 {
		return Constraint{}, false
	}
	return p.Constraints[k], true
}

// slot is one decision: a field's facet.
type slot struct {
	field string
	facet Facet
}

// decider is the layer that last decided a slot, by its place in the stack, and whether it switched the slot off.
type decider struct {
	layer int
	off   bool
}

// resolving is a resolution under way.
type resolving struct {
	fields    []Field
	hidden    map[string]bool // a field a layer placed as hidden, true, or as shown, false
	groups    []string
	order     []string
	sorts     []string
	desc      map[string]bool
	filters   map[string]ValueFilter
	rendering map[string]string
	flat      map[string]bool
	deciders  map[slot]decider
}

// given is one constraint of a layer, with the layer's place in the stack.
type given struct {
	Constraint
	layer int
}

// item is one instruction a layer gave a field the table has, and can use, in a facet.
type item struct {
	field Field
	s     Setting
}

// Resolve gives the preset a stack of layers sets a table as, of the table's fields, and the provenance of every
// constraint in the stack. A field a layer names that the table lacks, and an instruction its field cannot take, are
// not applied and are reported as not applicable. A layer gives a list, the groups, the order of the columns, or the
// sort keys, only through the entries that apply, and replaces the list so far with them, or appends them where it adds
// the facet. A layer's switch removes what the broader layers gave a field in a facet, and holds for every narrower
// layer until one gives it again; where a setting both gives a facet and switches it off, the switch wins.
func Resolve(layers []Layer, fields []Field) (Preset, Provenance) {
	r := resolving{fields: fields, hidden: map[string]bool{}, desc: map[string]bool{}, filters: map[string]ValueFilter{},
		rendering: map[string]string{}, flat: map[string]bool{}, deciders: map[slot]decider{}}
	var all []given
	for i, l := range layers {
		all = append(all, r.apply(i, l)...)
	}
	var out Provenance
	for _, g := range all {
		if g.Status != NotApplicable {
			switch d, ok := r.deciders[slot{g.Field, g.Facet}]; {
			case ok && d.layer == g.layer && d.off == g.Off:
				g.Status = InForce
			case ok && d.off && !g.Off:
				g.Status = Off
			default:
				g.Status = Overridden
			}
		}
		out.Constraints = append(out.Constraints, g.Constraint)
	}
	return r.preset(), out
}

// apply folds one layer into the resolution, and gives the layer's constraints: those for the table's fields, in its
// order, then those for fields it lacks.
func (r *resolving) apply(i int, l Layer) []given {
	var out []given
	byFacet := map[Facet][]item{}
	offs := map[Facet][]string{}
	consider := func(fd Field, known bool, s Setting, facet Facet) {
		off := s.Off.Has(facet)
		if !off && !gives(s, facet) {
			return
		}
		c := Constraint{Layer: l.Name, Level: l.Level, Field: fd.ID, Facet: facet, Off: off}
		if reason := cannot(fd, known, s, facet, off); reason != "" {
			c.Status, c.Reason = NotApplicable, reason
		} else if off {
			offs[facet] = append(offs[facet], fd.ID)
		} else {
			byFacet[facet] = append(byFacet[facet], item{fd, s})
		}
		out = append(out, given{c, i})
	}
	for _, fd := range r.fields {
		for _, facet := range facets {
			consider(fd, true, l.Preset.Fields[fd.ID], facet)
		}
	}
	var lacked []string
	for id := range l.Preset.Fields {
		if !slices.ContainsFunc(r.fields, func(fd Field) bool { return fd.ID == id }) {
			lacked = append(lacked, id)
		}
	}
	slices.Sort(lacked)
	for _, id := range lacked {
		for _, facet := range facets {
			consider(Field{ID: id}, false, l.Preset.Fields[id], facet)
		}
	}
	for _, facet := range facets {
		for _, id := range offs[facet] {
			r.off(i, id, facet)
		}
	}
	r.place(i, byFacet[FacetPlace], l.Preset.Add.Has(FacetPlace))
	r.columns(i, byFacet[FacetOrder], l.Preset.Add.Has(FacetOrder))
	r.sortBy(i, byFacet[FacetSort], l.Preset.Add.Has(FacetSort))
	for _, it := range byFacet[FacetFilter] {
		r.filters[it.field.ID] = ValueFilter{Include: slices.Clone(it.s.Filter.Include),
			Exclude: slices.Clone(it.s.Filter.Exclude)}
		r.deciders[slot{it.field.ID, FacetFilter}] = decider{layer: i}
	}
	for _, it := range byFacet[FacetRender] {
		r.render(i, it)
	}
	return out
}

// gives says whether a setting instructs its field in a facet.
func gives(s Setting, facet Facet) bool {
	switch facet {
	case FacetPlace:
		return s.Placement == PlaceHidden || s.Placement == PlaceGroup || s.Placement == PlaceColumn && s.Position == 0
	case FacetOrder:
		return s.Position > 0 && s.Placement != PlaceHidden && s.Placement != PlaceGroup
	case FacetSort:
		return s.Sort == "asc" || s.Sort == "desc"
	case FacetFilter:
		return s.Filter != nil && (len(s.Filter.Include) > 0 || len(s.Filter.Exclude) > 0)
	}
	return s.Rendering != "" || s.Flat
}

// cannot gives the reason a table cannot use an instruction, none for one it can. A switch can always be used on a
// field the table has. An instruction to draw a field says what it can: it is applicable when its rendering is one of
// the field's, or it flattens a field that holds a list.
func cannot(f Field, known bool, s Setting, facet Facet, off bool) string {
	switch {
	case !known:
		return "no such field"
	case off:
		return ""
	}
	switch facet {
	case FacetPlace:
		if s.Placement == PlaceGroup {
			return map[bool]string{true: "", false: "cannot group"}[f.Group]
		}
		return noLabel(f)
	case FacetOrder:
		return noLabel(f)
	case FacetSort:
		return map[bool]string{true: "", false: "cannot sort"}[f.Sort || f.One != ""]
	case FacetFilter:
		return map[bool]string{true: "", false: "cannot filter"}[f.Filter]
	}
	switch {
	case renders(f, s), flattens(f, s):
		return ""
	case s.Rendering != "":
		return "no such rendering"
	}
	return "holds no list"
}

// noLabel gives the reason a field with no label cannot be a column or hidden: it is never drawn.
func noLabel(f Field) string {
	if f.Label == "" {
		return "has no label"
	}
	return ""
}

// renders says whether a setting pins a rendering the field has.
func renders(f Field, s Setting) bool {
	return s.Rendering != "" && slices.Contains(f.Renderings, s.Rendering)
}

// flattens says whether a setting flattens a field that holds a list.
func flattens(f Field, s Setting) bool { return s.Flat && f.One != "" }

// off switches a field's facet off: what the broader layers gave it is removed, and the slot is the layer's.
func (r *resolving) off(i int, id string, facet Facet) {
	switch facet {
	case FacetPlace:
		r.groups = without(r.groups, id)
		delete(r.hidden, id)
	case FacetOrder:
		r.order = without(r.order, id)
	case FacetSort:
		r.sorts = without(r.sorts, id)
		delete(r.desc, id)
	case FacetFilter:
		delete(r.filters, id)
	case FacetRender:
		delete(r.rendering, id)
		delete(r.flat, id)
	}
	r.deciders[slot{id, facet}] = decider{layer: i, off: true}
}

// place folds a layer's placements in: a hidden field and a column leave the groups and the order, and the groups the
// layer gives replace the list, or are appended to it where the layer adds the facet.
func (r *resolving) place(i int, items []item, add bool) {
	var groups []item
	for _, it := range items {
		id := it.field.ID
		switch it.s.Placement {
		case PlaceGroup:
			groups = append(groups, it)
			continue
		case PlaceHidden:
			r.hidden[id] = true
			r.order = without(r.order, id)
		default:
			r.hidden[id] = false
		}
		r.groups = without(r.groups, id)
		r.deciders[slot{id, FacetPlace}] = decider{layer: i}
	}
	slices.SortStableFunc(groups, func(a, b item) int { return cmp.Compare(a.s.Depth, b.s.Depth) })
	ids := make([]string, len(groups))
	for k, it := range groups {
		ids[k] = it.field.ID
		delete(r.hidden, ids[k])
		r.order = without(r.order, ids[k])
	}
	r.groups = r.listed(i, FacetPlace, r.groups, ids, add)
}

// columns folds a layer's positions in: a field the layer positions is a column, shown, and no group.
func (r *resolving) columns(i int, items []item, add bool) {
	slices.SortStableFunc(items, func(a, b item) int { return cmp.Compare(a.s.Position, b.s.Position) })
	ids := make([]string, len(items))
	for k, it := range items {
		ids[k] = it.field.ID
		delete(r.hidden, ids[k])
		r.groups = without(r.groups, ids[k])
		r.deciders[slot{ids[k], FacetPlace}] = decider{layer: i}
	}
	r.order = r.listed(i, FacetOrder, r.order, ids, add)
}

// sortBy folds a layer's sort keys in.
func (r *resolving) sortBy(i int, items []item, add bool) {
	slices.SortStableFunc(items, func(a, b item) int { return cmp.Compare(a.s.Priority, b.s.Priority) })
	ids := make([]string, len(items))
	for k, it := range items {
		ids[k] = it.field.ID
	}
	before := slices.Clone(r.sorts)
	r.sorts = r.listed(i, FacetSort, r.sorts, ids, add)
	for _, id := range before {
		if !slices.Contains(r.sorts, id) {
			delete(r.desc, id)
		}
	}
	for _, it := range items {
		if !slices.Contains(before, it.field.ID) || !add {
			r.desc[it.field.ID] = it.s.Sort == "desc"
		}
	}
}

// listed gives a list with a layer's entries in it: the layer's entries alone, which become the layer's, or, where the
// layer adds the facet, the list with the entries it lacks appended, those it has left where they stand. A layer that
// gives no entries leaves the list as it is.
func (r *resolving) listed(i int, facet Facet, list, entries []string, add bool) []string {
	switch {
	case len(entries) == 0:
		return list
	case add:
		for _, id := range entries {
			if !slices.Contains(list, id) {
				list = append(list, id)
				r.deciders[slot{id, facet}] = decider{layer: i}
			}
		}
		return list
	}
	for _, id := range list {
		if !slices.Contains(entries, id) {
			delete(r.deciders, slot{id, facet})
		}
	}
	for _, id := range entries {
		r.deciders[slot{id, facet}] = decider{layer: i}
	}
	return slices.Clone(entries)
}

// render folds a layer's way to draw a field in: it replaces what the broader layers said, and holds the parts the
// field can take, its rendering, and flat where it holds a list.
func (r *resolving) render(i int, it item) {
	id := it.field.ID
	delete(r.rendering, id)
	delete(r.flat, id)
	if renders(it.field, it.s) {
		r.rendering[id] = it.s.Rendering
	}
	if flattens(it.field, it.s) {
		r.flat[id] = true
	}
	r.deciders[slot{id, FacetRender}] = decider{layer: i}
}

// without gives a list without the id.
func without(list []string, id string) []string {
	return slices.DeleteFunc(slices.Clone(list), func(s string) bool { return s == id })
}

// preset gives the resolution as a preset of the table's fields: each placed as a group by its place in the groups, hidden,
// a column at its place in the order, or a column shown; sorted at its place in the sort keys; and filtered and drawn as
// the layers said.
func (r *resolving) preset() Preset {
	var out Preset
	for _, f := range r.fields {
		var s Setting
		switch hidden, said := r.hidden[f.ID]; {
		case slices.Contains(r.groups, f.ID):
			s.Placement, s.Depth = PlaceGroup, slices.Index(r.groups, f.ID)+1
		case said && hidden:
			s.Placement = PlaceHidden
		case slices.Contains(r.order, f.ID):
			s.Placement, s.Position = PlaceColumn, slices.Index(r.order, f.ID)+1
		case said:
			s.Placement = PlaceColumn
		}
		if k := slices.Index(r.sorts, f.ID); k >= 0 {
			s.Sort, s.Priority = "asc", k+1
			if r.desc[f.ID] {
				s.Sort = "desc"
			}
		}
		if v, ok := r.filters[f.ID]; ok {
			s.Filter = &ValueFilter{Include: v.Include, Exclude: v.Exclude}
		}
		s.Rendering, s.Flat = r.rendering[f.ID], r.flat[f.ID]
		if s != (Setting{}) {
			if out.Fields == nil {
				out.Fields = map[string]Setting{}
			}
			out.Fields[f.ID] = s
		}
	}
	return out
}
