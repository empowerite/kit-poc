// The stack line and the constraint card: what the control line says of the presets in force on a table beyond the
// view it is set as. A chip names each preset active everywhere, in the app, or on the table, with its scope; a dim chip
// says a constraint of one of them is not in force here, because the table cannot use it or a narrower layer switched it
// off. A click on a dim chip opens its card, which says whose constraint it is and why it is not in force, and offers to
// switch it off at a level, or, where it was switched off, to switch it on again. A switch is a preset of its own, the
// one a level keeps, active at that level.
package table

import (
	"cmp"
	"errors"
	"slices"
	"strings"

	"github.com/empowerite/kit/projects/tui/internal/style"
)

// The presets that hold what a person switched off, one at each level, and what a card's lines say. LineOffHere also
// says, on a constraint that was switched off, where it was.
const (
	OffHere           = "Off here"
	OffInApp          = "Off in this app"
	OffEverywhere     = "Off everywhere"
	LineOffHere       = "off here"
	LineOffInApp      = "off in this app"
	LineOffEverywhere = "off everywhere"
	OnAgain           = "on again"
)

// ErrNoChoice answers a click or a key on a line of a card that is no choice.
var ErrNoChoice = errors.New("that line is not a choice")

// switchName gives the name of the preset that holds a level's switches.
func switchName(l Level) string {
	return map[Level]string{LevelTab: OffHere, LevelApp: OffInApp, LevelGlobal: OffEverywhere}[l]
}

// switchLine gives the words that say a switch's level.
func switchLine(l Level) string {
	return map[Level]string{LevelTab: LineOffHere, LevelApp: LineOffInApp, LevelGlobal: LineOffEverywhere}[l]
}

// at gives the presets of a level, and the names of those active there.
func (v Views) at(l Level) ([]Preset, []string) {
	switch l {
	case LevelGlobal:
		return v.Scoped.Global, v.Scoped.Active[ScopeKey(l, "")]
	case LevelApp:
		return v.Scoped.Apps[v.App], v.Scoped.Active[ScopeKey(l, v.App)]
	}
	return v.Saved, v.Scoped.Active[ScopeKey(l, v.Tab)]
}

// replace gives the person's presets with a level's presets and active names those given.
func (v Views) replace(l Level, presets []Preset, active []string) (Scoped, []Preset) {
	scoped := cloneScoped(v.Scoped)
	if len(active) == 0 {
		active = nil
	}
	switch l {
	case LevelGlobal:
		scoped.Global = presets
	case LevelApp:
		scoped.Apps[v.App] = presets
	default:
		scoped.Active[ScopeKey(l, v.Tab)] = active
		return scoped, presets
	}
	scoped.Active[ScopeKey(l, v.App)] = active
	if l == LevelGlobal {
		scoped.Active[ScopeKey(l, "")] = active
	}
	return scoped, v.Saved
}

// SwitchOff gives the person's presets with a constraint switched off at a level, for every table the level reaches: the
// level's preset of switches says it, and is active there. What was switched off at the level before stays.
func (v Views) SwitchOff(c Constraint, l Level) (Scoped, []Preset, error) {
	if l == LevelEdit {
		return Scoped{}, nil, ErrScope
	}
	presets, active := v.at(l)
	name := switchName(l)
	p := Preset{Name: name}
	if k := slices.IndexFunc(presets, func(w Preset) bool { return w.Name == name }); k >= 0 {
		p = presets[k]
	}
	fields := map[string]Setting{}
	for id, s := range p.Fields {
		fields[id] = s
	}
	s := fields[c.Field]
	s.Off |= Facets(c.Facet)
	fields[c.Field] = s
	p.Fields = fields
	if !slices.Contains(active, name) {
		active = append(slices.Clone(active), name)
	}
	scoped, saved := v.replace(l, upsert(presets, p), active)
	return scoped, saved, nil
}

// SwitchOn gives the person's presets with a switch taken away: c is the constraint that switched a facet of a field
// off, as the provenance gives it, and the preset of its layer no longer switches that off. A preset left with nothing to
// say is gone, with its active name.
func (v Views) SwitchOn(c Constraint) (Scoped, []Preset, error) {
	if c.Level == LevelEdit {
		return Scoped{}, nil, ErrScope
	}
	presets, active := v.at(c.Level)
	k := slices.IndexFunc(presets, func(p Preset) bool { return p.Name == c.Layer })
	if k < 0 || !presets[k].Fields[c.Field].Off.Has(c.Facet) {
		scoped, saved := v.replace(c.Level, presets, active)
		return scoped, saved, nil
	}
	p := presets[k]
	fields := map[string]Setting{}
	for id, s := range p.Fields {
		fields[id] = s
	}
	s := fields[c.Field]
	s.Off = s.Off.Without(c.Facet)
	if s == (Setting{}) {
		delete(fields, c.Field)
	} else {
		fields[c.Field] = s
	}
	p.Fields = fields
	if len(fields) > 0 || p.Name != switchName(c.Level) {
		scoped, saved := v.replace(c.Level, upsert(presets, p), active)
		return scoped, saved, nil
	}
	scoped, saved := v.replace(c.Level, slices.Delete(slices.Clone(presets), k, k+1),
		slices.DeleteFunc(slices.Clone(active), func(n string) bool { return n == c.Layer }))
	return scoped, saved, nil
}

// StackChip is a chip of the stack line: its text, as drawn; and, for a dim one, the constraint it says is not in force,
// which a click on it opens the card of.
type StackChip struct {
	Text string
	Card *Constraint
}

// scopeWord gives the words that say a level, for a table of an app.
func scopeWord(l Level, app string) string {
	switch l {
	case LevelGlobal:
		return "everywhere"
	case LevelApp:
		return "in " + cmp.Or(app, "this app")
	}
	return "here"
}

// StackChips gives the stack line's chips for the table: a chip per preset active everywhere, in the app, or on the
// table, each with its scope, then a dim one for each constraint of those and of the view the table is set as that is
// not in force: the table has no such field or cannot use the instruction, or a narrower layer switched it off. A
// constraint a narrower layer switched off, that the table could not use anyway, is no longer listed.
func StackChips(h Host) []StackChip {
	v := h.Views()
	base := h.Table().ViewName
	layers := v.Stack(base, nil)
	// the first layer at the table's scope is the view the table is set as, which the selector names
	baseAt := slices.IndexFunc(layers, func(l Layer) bool { return l.Level == LevelTab })
	var out []StackChip
	for k, l := range layers {
		if k != baseAt {
			out = append(out, StackChip{Text: style.Off(l.Name + " (" + scopeWord(l.Level, v.App) + ")")})
		}
	}
	_, prov := v.Applied(base, nil)
	for k, c := range prov.Constraints {
		silenced := c.Status == NotApplicable && slices.ContainsFunc(prov.Constraints[k+1:], func(w Constraint) bool {
			return w.Off && w.Field == c.Field && w.Facet == c.Facet
		})
		if c.Off || c.Status != NotApplicable && c.Status != Off || silenced {
			continue
		}
		c := c
		out = append(out, StackChip{Text: style.Off(constraintText(h, layers, c)), Card: &c})
	}
	return out
}

// constraintText says a constraint as a chip does: the field's label, and for a filter the values, else the facet.
func constraintText(h Host, layers []Layer, c Constraint) string {
	label := c.Field
	if f, ok := field(h, c.Field); ok {
		label = cmp.Or(f.Label, f.ID)
	}
	if c.Facet != FacetFilter {
		return label + " " + string(c.Facet)
	}
	k := slices.IndexFunc(layers, func(l Layer) bool { return l.Name == c.Layer && l.Level == c.Level })
	f := layers[k].Preset.Fields[c.Field].Filter
	values := slices.Clone(f.Include)
	for _, x := range f.Exclude {
		values = append(values, "¬"+x)
	}
	return label + ": " + strings.Join(values, ", ")
}

// ConstraintCard is the card of a dim chip while it is open: the constraint.
type ConstraintCard struct {
	Open bool
	C    Constraint
}

// CardLine is a line of a constraint card: what it draws, and whether a choice acts on it.
type CardLine struct {
	Text string
	Acts bool
}

// switched gives the constraint that switched a card's constraint off, where one did.
func (cc ConstraintCard) switched(h Host) (Constraint, bool) {
	v := h.Views()
	_, prov := v.Applied(h.Table().ViewName, nil)
	return prov.Why(cc.C.Field, cc.C.Facet)
}

// Lines gives the card's lines: whose constraint it is and its scope, why it is not in force, a gap, then a choice per
// level, off here, off in this app, off everywhere; or, for one switched off, where, and a choice to switch it on again.
func (cc ConstraintCard) Lines(h Host) []CardLine {
	owner := style.Off(cc.C.Layer + " (" + scopeWord(cc.C.Level, h.Views().App) + ")")
	if cc.C.Status == Off {
		sw, _ := cc.switched(h)
		return []CardLine{{Text: owner}, {Text: style.Off(switchLine(sw.Level))}, {}, {Text: OnAgain, Acts: true}}
	}
	return []CardLine{{Text: owner}, {Text: style.Off(cc.C.Reason)}, {},
		{Text: LineOffHere, Acts: true}, {Text: LineOffInApp, Acts: true}, {Text: LineOffEverywhere, Acts: true}}
}

// Choose gives the person's presets as the line k of the card changes them, or ErrNoChoice for a line that is none.
func (cc ConstraintCard) Choose(h Host, k int) (Scoped, []Preset, error) {
	lines := cc.Lines(h)
	if k < 0 || k >= len(lines) || !lines[k].Acts {
		return Scoped{}, nil, ErrNoChoice
	}
	v := h.Views()
	if cc.C.Status == Off {
		sw, _ := cc.switched(h)
		return v.SwitchOn(sw)
	}
	return v.SwitchOff(cc.C, []Level{LevelTab, LevelApp, LevelGlobal}[k-3])
}
