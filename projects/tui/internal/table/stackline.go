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
	"maps"
	"slices"
	"strings"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"

	"github.com/empowerite/kit/projects/tui/internal/shell"
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
	switch l {
	case LevelGlobal:
		return OffEverywhere
	case LevelApp:
		return OffInApp
	}
	return OffHere
}

// switchLine gives the words that say a switch's level.
func switchLine(l Level) string { return strings.ToLower(switchName(l)) }

// scopeName gives the name a level's active names are kept under.
func (v Views) scopeName(l Level) string {
	switch l {
	case LevelApp:
		return v.App
	case LevelTab:
		return v.Tab
	}
	return ""
}

// withSetting gives the preset with the setting of a field as f changes it, the field left out where nothing is left of
// it; the preset it was given is as it was.
func withSetting(p Preset, field string, f func(Setting) Setting) Preset {
	fields := maps.Clone(p.Fields)
	if fields == nil {
		fields = map[string]Setting{}
	}
	if s := f(fields[field]); s == (Setting{}) {
		delete(fields, field)
	} else {
		fields[field] = s
	}
	p.Fields = fields
	return p
}

// at gives the presets of a level, and the names of those active there.
func (v Views) at(l Level) ([]Preset, []string) {
	active := v.Scoped.Active[ScopeKey(l, v.scopeName(l))]
	switch l {
	case LevelGlobal:
		return v.Scoped.Global, active
	case LevelApp:
		return v.Scoped.Apps[v.App], active
	}
	return v.Saved, active
}

// replace gives the person's presets with a level's presets and active names those given.
func (v Views) replace(l Level, presets []Preset, active []string) (Scoped, []Preset) {
	scoped := cloneScoped(v.Scoped)
	if len(active) == 0 {
		active = nil
	}
	scoped.Active[ScopeKey(l, v.scopeName(l))] = active
	switch l {
	case LevelGlobal:
		scoped.Global = presets
	case LevelApp:
		scoped.Apps[v.App] = presets
	default:
		return scoped, presets
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
	p = withSetting(p, c.Field, func(s Setting) Setting {
		s.Off |= Facets(c.Facet)
		return s
	})
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
	p := withSetting(presets[k], c.Field, func(s Setting) Setting {
		s.Off = s.Off.Without(c.Facet)
		return s
	})
	if len(p.Fields) > 0 || p.Name != switchName(c.Level) {
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

// ScopeWord gives the words that say a level, for a table of an app.
func ScopeWord(l Level, app string) string {
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
			out = append(out, StackChip{Text: style.Off(l.Name + " (" + ScopeWord(l.Level, v.App) + ")")})
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

// ConstraintCard is the card of a dim chip while it is open: the constraint; its line under the keyboard, -1 for none;
// and the screen column of the chip it hangs from, which its left edge keeps where the screen is wide enough.
type ConstraintCard struct {
	Open bool
	C    Constraint
	At   int
	X    int
}

// OpenConstraint gives the card of the constraint a click on a dim chip reached, open, hanging from the chip, the first
// choice under the keyboard.
func OpenConstraint(h Host, spot ControlSpot) ConstraintCard {
	cc := ConstraintCard{Open: true, C: *spot.Card, X: spot.From}
	cc.At = slices.IndexFunc(cc.Lines(h), func(l CardLine) bool { return l.Acts })
	return cc
}

// items gives the card's lines as a menu draws them.
func (cc ConstraintCard) items(h Host) []shell.Item {
	var out []shell.Item
	for _, l := range cc.Lines(h) {
		out = append(out, shell.Item{Name: l.Text})
	}
	return out
}

// acts says whether the line k of the card is a choice.
func (cc ConstraintCard) acts(h Host) func(int) bool {
	lines := cc.Lines(h)
	return func(k int) bool { return k >= 0 && k < len(lines) && lines[k].Acts }
}

// Box gives the card's lines, in its tab's color, titled by the facet it is about, as a menu is, and the screen line
// and column it is drawn from: under the control line's top, its left edge on its chip's first column, or as far left as
// the screen needs to show it whole.
func (cc ConstraintCard) Box(h Host) (lines []string, top, left int) {
	width, _ := h.Size()
	color := h.Color()
	lines, _ = shell.BoxColored(cc.items(h), cc.acts(h), cc.At, "", -1, width, color)
	wide := ansi.StringWidth(lines[0])
	lines, left = shell.BoxColored(cc.items(h), cc.acts(h), cc.At, "", -1, max(wide, min(cc.X+wide, width)), color)
	lines[0] = shell.TitledColored(string(cc.C.Facet), ansi.StringWidth(lines[0]), color)
	top, _ = h.Pane()
	return lines, top, left
}

// Keys gives the card's segment of the keys bar: a menu's.
func (cc ConstraintCard) Keys() shell.Segment { return shell.MenuKeys() }

// Key takes a key while the card is open, as a menu does, and gives the line chosen, -1 for none; esc closes it.
func (cc *ConstraintCard) Key(h Host, k tea.KeyPressMsg) int {
	d, chosen := shell.Dropdown{Open: cc.Open, At: cc.At}.Key(k, cc.items(h), cc.acts(h))
	cc.Open, cc.At = d.Open, d.At
	return chosen
}

// Click takes a click while the card is open, as a menu does, and gives the line chosen, -1 for none; a click off the
// card closes it.
func (cc *ConstraintCard) Click(h Host, x, y int) int {
	box, top, left := cc.Box(h)
	d, chosen := shell.Dropdown{Open: cc.Open, At: cc.At}.Click(x, y, top, left, ansi.StringWidth(box[0]), cc.items(h),
		cc.acts(h))
	cc.Open, cc.At = d.Open, d.At
	return chosen
}

// CardLine is a line of a constraint card: what it draws, and whether a choice acts on it.
type CardLine struct {
	Text  string
	Acts  bool
	Level Level // for a choice that switches off, where
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
	owner := style.Off(cc.C.Layer + " (" + ScopeWord(cc.C.Level, h.Views().App) + ")")
	if cc.C.Status == Off {
		sw, _ := cc.switched(h)
		return []CardLine{{Text: owner}, {Text: style.Off(switchLine(sw.Level))}, {}, {Text: OnAgain, Acts: true}}
	}
	return []CardLine{{Text: owner}, {Text: style.Off(cc.C.Reason)}, {},
		{Text: LineOffHere, Acts: true, Level: LevelTab}, {Text: LineOffInApp, Acts: true, Level: LevelApp},
		{Text: LineOffEverywhere, Acts: true, Level: LevelGlobal}}
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
	return v.SwitchOff(cc.C, lines[k].Level)
}
