# Views: Scoped Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person's presets stack at global, app, and tab scope, fold into the one preset a tab applies, and each tab
says what it applied and why.

**Architecture:** A pure fold in `projects/tui/internal/table` turns an ordered stack of layers into an ordinary
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
5. A global name equal to a built-in's name on any tab is refused (Task 3).

---

## File structure

- `table/fold.go`, `table/fold_test.go`: the layers, the fold, and the provenance. Pure; no I/O.
- `table/catalog.go`: `Preset` gains `Add`, `Setting` gains `Off`.
- `table/store.go`, `table/store_test.go`: the file's version 3 and its scopes.
- `table/views.go`, `table/views_test.go`: `Views` builds the stack and saves at a scope.
- `table/presets.go`, `table/draw.go`: the stack line and the constraint card (Task 4).
- `flow/views.go`, `table/sheet.go`: the two hosts load and keep the scopes (Task 5).

## Task 1: The fold

**Files:** Create `table/fold.go`, `table/fold_test.go`. Modify `table/catalog.go` (the `Preset` and `Setting` structs).

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
func Fold(layers []Layer, fields []Field) (Preset, Provenance)
func (p Provenance) Why(field string, facet Facet) (Constraint, bool) // the one in force
```

- `Preset` gains `Add []Facet` (`json:"add,omitempty"`), the list facets, `FacetPlace`, `FacetOrder`, or `FacetSort`,
  that append instead of replace. `Setting` gains `Off []Facet` (`json:"off,omitempty"`).

- [ ] **Step 1: Write the failing tests** in `fold_test.go`, table-driven, each with its stack and the folded preset:
  `TestFoldNarrowestWins` (a tab's filter on `state` replaces a global one on `state`; a filter on `assignee` beside it
  stands), `TestFoldListReplaces` (global groups `org`, `repo`; a tab layer groups `state`: the result groups `state`
  alone), `TestFoldListAdds` (the same with `Add: [FacetPlace]` groups `org`, `repo`, `state`, depths 1 to 3),
  `TestFoldOff` (a tab layer with `Off: [FacetFilter]` on `assignee` removes the global filter, and a later layer that
  gives it again restores it), `TestFoldHiddenStays` (hidden until a later layer places the field),
  `TestFoldAbsentFieldNotApplicable` (a global filter on a field `fields` lacks gives a `NotApplicable` constraint
  with Reason "no such field", and the folded preset has no filter), `TestFoldCannotSort` (a sort on a field with
  `Sort: false` and `One: ""` is `NotApplicable`, Reason "cannot sort"), `TestFoldInapplicableListKeepsBroader` (Review
  Focus 1), `TestFoldProvenance` (each of `InForce`, `Overridden`, `Off` is reported for the layer that gave it),
  and `TestFoldFoldedPanelEqualsApplied` (`Preset.Panel` of the fold's preset sets the same panel as a single layer
  stating the same).
- [ ] **Step 2: Run them to see them fail:** `cd projects/tui && go test ./internal/table -run TestFold` fails to build.
- [ ] **Step 3: Implement `Fold`.** Gather each layer's settings for the fields `fields` has, in `fields` order, judging
  applicability as `Preset.Panel` does: hidden needs a label, a group needs `Group`, a sort needs `Sort` or `One`, a
  filter needs `Filter`, a rendering must be one of `Renderings`, flat needs `One`. A layer's list facet gives entries
  only through applicable settings. Keep state per facet, with the owner layer of each entry; a layer's `Off` clears the
  facet first, and the setting's own value for it is ignored. Build the result as a `Preset` with groups numbered from
  1 by depth, sorts from 1 by priority, positions from 1.
- [ ] **Step 4: Run the tests:** `go test -cover ./internal/table` passes, and `fold.go` is covered whole.
- [ ] **Step 5: Commit** `table/fold.go`, `table/fold_test.go`, `table/catalog.go`: `#590 kittui: a stack of presets
  folds into the one preset a tab applies, and says what each layer decided`.

## Task 2: The file keeps scopes

**Files:** Modify `table/store.go`, `table/store_test.go`.

**Interfaces:**

- Consumes: `Preset`, with `Add`.
- Produces:

```go
const PresetsVersion = 3
type Scoped struct {
    Global []Preset            // the person's presets at global scope
    Apps   map[string][]Preset // by app
    Active map[string][]string // active names, by scope key: "global", "app:<name>", "tab:<stage>"
}
func ReadScoped(path string) (Scoped, error)
func KeepScoped(path string, was, now Scoped) (Scoped, error) // merges by name within a scope, as KeepPresets does
func ScopeKey(l Level, name string) string
```

- [ ] **Step 1: Write the failing tests:** `TestReadVersionTwo` (a version 2 file reads: its tab presets as today,
  `Scoped` empty), `TestReadScopedRoundTrip`, `TestKeepScopedMergesByName` (Review Focus 4: another kittui's global
  preset stays when this one saves a different one; a preset this kittui deleted stays gone), `TestKeepScopedActive`
  (active names keep their order), `TestWriteVersionThree`.
- [ ] **Step 2: Run them to see them fail:** `go test ./internal/table -run 'TestRead|TestKeepScoped|TestWrite'`.
- [ ] **Step 3: Implement.** `readFile` accepts versions 2 and 3 and holds the new keys, never nil; `writeFile` writes 3.
  `KeepScoped` reuses `merged` and the lock `KeepPresets` uses, keyed by preset name within each list.
- [ ] **Step 4: Run the package's tests**, coverage whole on the new code.
- [ ] **Step 5: Commit** both files: `#590 kittui: the presets file keeps global and app presets, and which are active`.

## Task 3: Views on the stack

**Files:** Modify `table/views.go`, `table/views_test.go`.

**Interfaces:**

- Consumes: `Fold`, `Scoped`, `Layer`.
- Produces:

```go
type Views struct { /* today's fields */; Scoped Scoped; App string; Tab string; Reserved []string }
func (v Views) Stack(edit *Preset) []Layer // global actives, app actives, the base, tab actives, the edit
func (v Views) Applied(edit *Preset) (Preset, Provenance)
func (v Views) SaveAt(name string, l Level, p grid.Panel) (Scoped, []Preset, error)
```

  `Reserved` is every built-in name of every tab, which a global name may not equal.

- [ ] **Step 1: Write the failing tests:** `TestStackOrder`, `TestApplied` equals the base when nothing is active,
  `TestSaveAtGlobalRefusesReservedName` (Review Focus 5), `TestSaveAtOverwritesByName`, `TestIsComparesApplicablePart`
  (a view with a global constraint the tab lacks is still checked as the preset it was set as).
- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement.** `Is` compares the applied preset's applicable part, so a partly applicable preset is
  checked. `SaveAt` at the tab scope behaves as `SaveAs` does today.
- [ ] **Step 4: Run the package's tests.** Existing `views_test.go` cases pass unchanged.
- [ ] **Step 5: Commit** the files: `#590 kittui: a table's views are a stack, and a preset saves at a scope`.

## Task 4: The stack line and the card

Held until no peer has work under `projects/tui/` uncommitted, because it changes goldens.

**Files:** Modify `table/presets.go`, `table/draw.go`, `table/popover.go`, and their tests and goldens.

**Interfaces:** Consumes `Views.Applied`. Produces `StackLine(h Host) string`, the chips of the layers in force, each with
its scope; `ConstraintCard`, the popover that says a constraint's layer and offers off here, off in this app, off
everywhere.

- [ ] **Step 1: Write the failing tests:** the stack line for a stack of three, a dim not-applicable chip with its reason,
  a plain click on a chip opening its card, and each off choice writing a layer with `Off`.
- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement** from the sketch in the design, plain clicks only.
- [ ] **Step 4: Run all tests**; regenerate goldens only on a tree with no peer work, and read each diff.
- [ ] **Step 5: Commit** the files.

## Task 5: The selection follows

**Files:** Modify `flow/views.go`, `table/sheet.go`, their tests.

**Interfaces:** Consumes `ReadScoped`, `KeepScoped`, `Views.Scoped`. Produces the hosts' loading of the scopes and the
keeping of active names when a person activates or deactivates a preset.

- [ ] **Step 1: Write the failing tests:** activating a global preset on one tab applies it on another tab of the same
  file; deactivating on one removes it on the other; a second screen's save is kept.
- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement** the hosts' calls.
- [ ] **Step 4: Run all tests.**
- [ ] **Step 5: Commit** the files.

## Task 6: The page that says so

**Files:** Modify `docs/apps.md` (the presets chapter), the tutorial for views.

- [ ] **Step 1:** Describe the stack, the scopes, and the cues as the screens draw them, in the present tense.
- [ ] **Step 2:** `kit lint` over the files passes, and every relative link resolves.
- [ ] **Step 3: Commit** the files.
