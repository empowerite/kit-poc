# Views: Scoped Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person's presets stack at global, app, and tab scope, resolve into the one preset a tab applies, and each tab
says what it applied and why.

**Architecture:** A pure resolution in `projects/tui/internal/table` turns an ordered stack of layers into an ordinary
`Preset`, which `Preset.Panel` already applies, and reports provenance. The presets file gains scopes and active names,
reading as it does today. `Views` builds the stack, and the preset line draws it.

**Tech Stack:** Go 1.27, Bubble Tea v2, the `table` and `flow` packages of `projects/tui`.

**Spec:** [the views design](../specs/2026-11-14-views-design.md), with
[the audiences design](../specs/2026-11-14-audiences-design.md) for who the stack serves.

## Global Constraints

- kit commit only, never kit submit or push; every subject starts `#590 kittui: …`. `export PATH=$PWD/kit/bin:$PATH`
  before `kit commit`.
- Peers share the worktree: stage named paths only, guard that the index holds only them, never leave anything
  staged.
- Go tests run as `cd projects/tui && go test -cover ./...`, without `-update`; goldens are regenerated only on a tree
  with no peer work under `projects/tui/`. New code is covered whole.
- Lines are 120 cells at most; comments are prose, as the file's neighbors write them.
- Every action is a plain click; a menu line's shortcut stands at its right; no circled glyphs; two-cell emoji in menus.
- Existing files keep their meaning: a presets file written before this change reads as the same views.
- Applying never fails and ignoring is never silent: a constraint that does not apply is reported, never dropped.

## Review Focus

1. A narrower layer whose list entries all name fields the tab lacks leaves the broader list alone (Task 1).
2. A global filter on a field the tab lacks leaves the rows unfiltered and reports the constraint as not applicable
   (Task 1).
3. A version 2 file reads as tab-scoped presets, and a file with no presets reads as empty (Task 2).
4. Two kittuis saving a global preset of one name keep each other's other presets (Task 2).
5. A global name equal to a built-in's name on any tab is refused (Task 4).
6. Saving a global preset from a tab whose base filters state keeps the grouping alone, never the filter (Task 4).

---

## File structure

- `table/resolve.go`, `table/resolve_test.go`: the layers, the resolution, and the provenance. Pure; no I/O.
- `table/catalog.go`: `Preset` gains `Add`, `Setting` gains `Off`.
- `table/scoped.go`, `table/scoped_test.go`, `table/store.go`: the file's version 3 and its scopes.
- `table/edit.go`, `table/edit_test.go`: an unsaved edit as a layer.
- `table/views.go`, `table/views_test.go`: `Views` builds the stack and saves at a scope.
- `table/presets.go`, `table/draw.go`: the stack line and the constraint card (Task 5).
- `flow/views.go`, `table/sheet.go`: the two hosts load and keep the scopes (Task 6).

## Task 1: The resolution

**Files:** Create `table/resolve.go`, `table/resolve_test.go`. Modify `table/catalog.go` (the `Preset` and `Setting` structs).

**Interfaces:**

- Produces:

```go
type Facet string // FacetPlace, FacetOrder, FacetSort, FacetFilter, FacetRender
type Level int    // LevelGlobal, LevelApp, LevelTab, LevelEdit
type Layer struct { Name string; Level Level; Preset Preset }
type Status int   // InForce, Overridden, Off, NotApplicable
type Constraint struct {
    Layer string; Level Level; Field string; Facet Facet
    Off bool; Status Status; Reason string
}
type Provenance struct{ Constraints []Constraint }
func Resolve(layers []Layer, fields []Field) (Preset, Provenance)
func (p Provenance) Why(field string, facet Facet) (Constraint, bool) // the one in force
```

- `type FacetSet uint8`, comparable so `Setting` stays comparable, with `Facets(...Facet) FacetSet`, `Has(Facet) bool`,
  and a JSON form that is a list of facet names. `Preset` gains `Add FacetSet` (`json:"add,omitempty"`), the list
  facets, `FacetPlace`, `FacetOrder`, or `FacetSort`, that append instead of replace. `Setting` gains `Off FacetSet`
  (`json:"off,omitempty"`). The names are `Resolve`, not `Fold`, because the package's `Fold` opens and closes groups.

- [x] **Step 1: Write the failing tests** in `resolve_test.go`, table-driven, each with its stack and the resolved
  preset: `TestResolveNarrowestWins` (a tab's filter on `state` replaces a global one on `state`; a filter on
  `assignee` beside it stands), `TestResolveListReplaces` (global groups `org`, `repo`; a tab layer groups `state`:
  the result groups `state` alone), `TestResolveListAdds` (the same with `Add: [FacetPlace]` groups `org`, `repo`,
  `state`, depths 1 to 3), `TestResolveOff` (a tab layer with `Off: [FacetFilter]` on `assignee` removes the global
  filter, and a later layer that gives it again restores it), `TestResolveHiddenStays` (hidden until a later layer
  places the field), `TestResolveAbsentFieldNotApplicable` (a global filter on a field `fields` lacks gives a
  `NotApplicable` constraint with Reason "no such field", and the resolved preset has no filter),
  `TestResolveCannotSort` (a sort on a field with `Sort: false` and `One: ""` is `NotApplicable`, Reason "cannot
  sort"), `TestResolveInapplicableListKeepsBroader` (Review Focus 1), `TestResolveProvenance` (each of `InForce`,
  `Overridden`, `Off` is reported for the layer that gave it), and `TestResolvedPanelEqualsApplied` (`Preset.Panel` of
  the resolution's preset sets the same panel as a single layer stating the same).
- [x] **Step 2: Run them to see them fail:** `cd projects/tui && go test ./internal/table -run TestResolve` fails to build.
- [x] **Step 3: Implement `Resolve`.** Gather each layer's settings for the fields `fields` has, in `fields` order, judging
  applicability as `Preset.Panel` does: hidden needs a label, a group needs `Group`, a sort needs `Sort` or `One`, a
  filter needs `Filter`, a rendering must be one of `Renderings`, flat needs `One`. A layer's list facet gives entries
  only through applicable settings. Keep state per facet, with the owner layer of each entry; a layer's `Off` clears the
  facet first, and the setting's own value for it is ignored. Build the result as a `Preset` with groups numbered from
  1 by depth, sorts from 1 by priority, positions from 1.
- [x] **Step 4: Run the tests:** `go test -cover ./internal/table` passes, and `resolve.go` is covered whole.
- [x] **Step 5: Commit** `table/resolve.go`, `table/resolve_test.go`, `table/catalog.go`: `#590 kittui: a stack of presets
  resolves into the one preset a tab applies, and says what each layer decided`.

## Task 2: The file keeps scopes

**Files:** Create `table/scoped.go`, `table/scoped_test.go`. Modify `table/store.go`, and the two tests that name the
file's version, `table/views_test.go` and `flow/views_test.go`.

**Interfaces:**

- Consumes: `Preset`, with `Add`, and `merged`, the merge `KeepPresets` uses.
- Produces:

```go
const PresetsVersion = 3 // a file that holds scoped presets; any other is written as version 2, which every kittui reads
type Scoped struct {
    Global []Preset            // the person's presets at global scope
    Apps   map[string][]Preset // by app
    Active map[string][]string // active names in order, by scope key
}
func ScopeKey(l Level, name string) string // "global", "app:<name>", "tab:<name>"; an edit has none
func ReadScoped(path string) (Scoped, error)
func KeepScoped(path string, was, now Scoped) (Scoped, error) // merges by name within a scope, as KeepPresets does
```

- [x] **Step 1: Write the failing tests** in `scoped_test.go`: a version 2 file reads as no scoped presets and keeps
  its tab presets; a missing file is `os.ErrNotExist`; another version is refused and named; a round trip is version 3;
  a file with none stays version 2 (Review Focus 3); two writers keep each other's global and app presets, and one's
  delete stays a delete (Review Focus 4); active names keep their order; a scope with nothing is left out; a file that
  does not read is not written over; a folder that takes no new file is reported.
- [x] **Step 2: Run them to see them fail:** `go test ./internal/table -run Scoped` fails to build.
- [x] **Step 3: Implement.** `readFile` reads versions 2 and 3 and holds the new keys, never nil; `writeFile` writes 3
  only for a file that holds them. `KeepScoped` takes the lock `KeepPresets` takes and merges each list with `merged`.
- [x] **Step 4: Run the package's tests**, coverage whole. The two tests that used a version as an example of another
  one now use versions 1 and 4, because 3 is read.
- [x] **Step 5: Commit** the files: `#590 kittui: the presets file keeps global and app presets, and which are active`.

## Task 3: The edit is a layer

A person's unsaved edit is the difference between the panel and what the stack beneath already gives. Saving at global
or app scope keeps that difference only, so a tab's own base, such as Underway's filter on state, never travels.

**Files:** Create `table/edit.go`, `table/edit_test.go`.

**Interfaces:**

- Consumes: `Resolve`, `PresetOf`, `Layer`, `grid.Panel`.
- Produces:

```go
// Delta gives what a panel says that a preset the table applies does not: its settings where they differ, and a switch
// off, in the facet, for what the preset gave and the panel no longer has.
func Delta(applied Preset, p grid.Panel, fields []Field) Preset
```

- [x] **Step 1: Write the failing tests** in `edit_test.go`: a panel equal to what is applied gives nothing
  (`TestDeltaOfNothingChangedIsEmpty`); a filter added gives that filter alone (`TestDeltaGivesAnAddedFilter`); a filter
  the panel lacks gives `Off` in the filter facet (`TestDeltaSwitchesOffARemovedFilter`); a changed grouping gives the
  panel's whole list of groups, and a grouping removed gives `Off` in the place facet for each group that went
  (`TestDeltaGivesTheWholeListThatChanged`); the same for the sort keys and the columns' order; a column shown that was
  hidden gives a column placement (`TestDeltaShowsAHiddenColumn`); a rendering changed gives it, and one removed gives
  `Off` in the render facet; and resolving the applied preset beneath the delta sets the panel's panel
  (`TestDeltaOverTheAppliedSetsThePanel`, for each case above).
- [x] **Step 2: Run them to see them fail.**
- [x] **Step 3: Implement `Delta`.** Normalize both sides as `Views.Same` does, through `Preset.Panel` and `PresetOf`, then
  compare per field and facet; a list facet that differs is given whole, and a sort key whose direction turned is a
  change. A panel with its columns in another order says every column's position, so the delta lists them all.
- [x] **Step 4: Run the package's tests**, coverage whole.
- [x] **Step 5: Commit** the files.

## Task 4: Views on the stack

**Files:** Modify `table/views.go`, `table/views_test.go`.

**Interfaces:**

- Consumes: `Resolve`, `Delta`, `Scoped`, `Layer`.
- Produces:

```go
type Views struct { /* today's fields */; Scoped Scoped; App string; Tab string; Reserved []string }
func (v Views) Stack(base string, edit *Preset) []Layer // global actives, app actives, the base, tab actives, the edit
func (v Views) Applied(base string, p *grid.Panel) (Preset, Provenance) // the stack resolved, the edit being p's delta
func (v Views) SaveAt(name string, l Level, base string, p grid.Panel) (Scoped, []Preset, error)
```

  `Reserved` is every built-in name of every tab, which a global or app name may not equal. `SaveAt` at global or app
  scope keeps the panel's `Delta` over the whole stack beneath; at tab scope it keeps the panel's `Delta` over the
  global and app layers alone, which with none active is the preset `SaveAs` keeps today.

- [x] **Step 1: Write the failing tests:** `TestStackOrder` (global, app, base, tab, edit, each in the order
  activated), `TestStackSkipsAnActiveNameThatIsGone`, `TestSavingAtAScopeDoesNotChangeTheView` (a saved preset is
  active, and the view after saving is the panel before it), `TestStackWithNothingActiveIsTheBase`,
  `TestAppliedResolvesTheStack`, `TestSaveAtGlobalKeepsTheEditAlone` (a tab whose base filters state saves a global
  grouping without that filter), `TestSaveAtTabWithNothingActiveIsSaveAs`, `TestSaveAtRefusesAReservedName` (Review
  Focus 5), `TestSaveAtRefusals` (unnamed, a team's name, an edit as a scope), `TestIsReadsTheStack` (a table set as
  its base with a global preset active is that base; with none active `Is` is as it is today).
- [x] **Step 2: Run them to see them fail.**
- [x] **Step 3: Implement.** `Is` compares against the stack's applied preset only where a scope has an active name.
- [x] **Step 4: Run the package's tests.** Existing `views_test.go` cases pass unchanged.
- [x] **Step 5: Commit** the files.

## Task 5: The stack line and the card

**Files:** Create `table/stackline.go`, `table/stackline_test.go`. Modify `table/draw.go`, `table/sheet.go`,
`table/resolve.go`.

**Interfaces:** Consumes `Views.Applied`. Produces `StackChips(h Host) []StackChip`, a chip per active layer with its
scope and a dim chip, carrying its `Card`, per constraint not in force; `ConstraintCard`, with `Lines` and `Choose`,
that says a constraint's layer and offers off here, off in this app, off everywhere, or on again; `Views.SwitchOff` and
`Views.SwitchOn`, which keep the switch as a preset of its own at a level ("Off here", "Off in this app", "Off
everywhere"), active there; and `ControlSpot.Card`. The control line draws the chips before the filters' and the dim
ones after, and a click on 📇 Fields still opens the columns dialog.

- [x] **Step 1: Write the failing tests:** the stack chips for a stack of three, a dim chip with its reason, the
  card's lines, each off choice writing a layer with `Off`, and on again taking it away.
- [x] **Step 2: Run them to see them fail.**
- [x] **Step 3: Implement**, plain clicks only. A constraint a narrower layer switched off, that the table could not
  use anyway, is no longer listed.
- [x] **Step 4: Run all tests**; no golden changed, because no screen holds scopes yet.
- [x] **Step 5: Commit** the files.

Left to Task 6, because opening the card and keeping its choice need the host to hold the scopes: the sheet and the
flow screen open `ConstraintCard` on a click on a dim chip, which `Sheet.controlClick` ignores for now, draw it as a
layer, and keep what `Choose` gives with `KeepScoped`. The presets' menu's sections by scope come with it.

## Task 6: The selection follows

**Files:** Create `flow/scoped.go`, `table/sheet_scoped_test.go`, `flow/scoped_test.go`. Modify `table/stack.go`,
`table/presets.go`, `table/layers.go`, `table/table.go`, `table/sheet.go`, `flow/flow.go`, `flow/views.go`,
`flow/layers.go`.

**Interfaces:** Consumes `ReadScoped`, `KeepScoped`, `Views.Scoped`. Produces `Views.Stacked`, `Views.Rebased`,
`Views.Restored`, `Views.Toggle`, `KeepViews`, the presets' menu's sections "everywhere" and "in `app`", whose lines a
click makes active or no longer, its lines "Save everywhere…" and "Save in `app`…", `Table.Scoped` and `Table.Scope`
for the name typed, the card as a layer of `Overlays`, and the two hosts' loading and keeping of the scopes.

- [x] **Step 1: Write the failing tests:** activating a global preset applies it on every stage and in a sheet opened
  after; deactivating removes it; saving everywhere is active at once and the line is not struck through; a stage opens
  as the presets now say, however it was left; a file that does not read is not written over; the card's choice is kept.
- [x] **Step 2: Run them to see them fail.**
- [x] **Step 3: Implement** the hosts' calls. The applying of a view is its stack; a panel left is restored over the
  stack of its view; making a preset active changes the stack beneath what the person changed, which stays.
- [x] **Step 4: Run all tests.** The presets' menu gains two lines at its end, so the tests that named its lines or
  moved by the letter s say so.
- [x] **Step 5: Commit** the files.

Backed out: "Save everywhere…" and "Save in `app`…" did not work in use. Saving kept only what the panel said
beyond the view the tab was set as, which is nothing for a view that already says it, and a click on a preset in the
menu toggled it, so it could not be used. `Views.SaveAt`, `Views.Reserved`, `Table.Scoped`, and the two lines are
gone. The scopes, the stack, the toggle, the dim chips and the card stay, until the way a person makes a preset that
follows them is decided.

Open: a panel left by one kittui and restored by another whose active presets differ keeps what a preset gave that the
other has since made inactive, as the person's own change, because only the panel is kept, never the stack it came of.

## Task 7: The page that says so

**Files:** Modify `docs/apps.md` (the presets chapter), the tutorial for views.

- [ ] **Step 1:** Describe the stack, the scopes, and the cues as the screens draw them, in the present tense.
- [ ] **Step 2:** `kit lint` over the files passes, and every relative link resolves.
- [ ] **Step 3: Commit** the files.
