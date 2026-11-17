# Menus in the style of macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every menu drawn by `shell.boxIn` gets a check gutter and inline glyphs; Watch and Watch All become toggles;
a menu line can open a submenu.

**Architecture:** `shell.Item` gains a `Check` state and an `Opens` flag; `boxIn` lays each line out from them. The
tab, row and some app lines drop their glyphs. `Dropdown` gains the path of the open submenus, and a `SubBox` draws a
submenu beside its parent line. The three slices are issues #610, #611 and #612, each commit's subject starting with
its issue number.

**Tech Stack:** Go 1.27 in `projects/tui`, Bubble Tea v2, lipgloss v2, `charmbracelet/x/ansi`.

**Spec:** [docs/superpowers/specs/2026-11-16-safari-style-menus-design.md](../specs/2026-11-16-safari-style-menus-design.md)

## Global Constraints

- kittui's Go is held to 100% coverage: `go test ./... -cover` in `projects/tui` shows 100.0% for every package.
- `shell.Item` is compared with `==` and `slices.Contains` (`shell.go` `enabled`, `screenOf`, `choice`), so it must stay
  comparable: no slice, map or func field. A submenu's lines come from its owner, never from `Item`.
- Menu glyphs are two-cell emoji with no U+FE0F; `✔` and `–` are one cell, and the gutter is the mark and a space.
- Every action has a plain click (iTerm swallows modified and right clicks).
- A line that cannot act stays, dim, and the keyboard passes it by; it is never omitted.
- A menu's keys at the right stay `Item.Keys`; the keys bar names only esc, ↑↓ and ⏎ for a menu.
- Commands: `export PATH="$PWD/kit/bin:$PATH"` once, run Go from `projects/tui`, and commit with
  `kit commit --message="#<issue> …" --message="Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" <paths>`
  after `git add <paths>`. Another session may have hunks staged in the same worktree: stage only your own paths.
- `go test ./internal/flow` takes about two minutes; run it once per task, not per step. Golden files are rewritten with
  `go test ./internal/<pkg> -update` and the diff read before it is committed.

## Review Focus

- A menu with no glyph and no check on any line has neither a gutter nor a glyph cell: its lines are as narrow as
  their names and keys need (task 1 test).
- A menu whose widest line is a glyphed one, and one whose widest is a keyless name, both pad every line to one width
  (task 1 test).
- Watch All when no stage is watchable (`all == 0`) is dim and unchecked, and clicking it does nothing (task 3 test).
- → or `.` on a line that has no submenu does nothing: it neither chooses the line nor closes the menu (task 4 test).
- A submenu that would run past the right of the room opens to the left of its parent, and one near the bottom is
  moved up to fit; a dim `Opens` line cannot be opened by key or click (task 4 tests).

---

### Task 1: The gutter and inline glyphs in `boxIn` (#610)

**Files:**

- Modify: `projects/tui/internal/shell/shell.go` (`Item`, `boxIn`, `choice`)
- Test: `projects/tui/internal/shell/shell_test.go`

**Interfaces:**

- Produces: `type Check int` with `NoCheck` (zero), `Off`, `On`, `Mixed`; `Item.Check Check`; `Item.Opens bool` (declared
  here, drawn in task 4); `func NameCol(items []Item, k int) int`, the cells from a box's left edge to where line k's
  name starts.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write the failing tests** in `shell_test.go`:
  - `TestAMenuWithNoGlyphAndNoCheckHasNeitherGutterNorGlyphCell`: `Box` over `{Name:"Refresh"}, {Name:"Quit"}` has
    inner width `len("Refresh")+2` (a cell either side) and its first line is `"│ Refresh │"` stripped of escapes.
  - `TestALineWithACheckStateDrawsItsMarkInATwoCellGutterAndEveryLineLeavesRoomForIt`: items `{Name:"Watch", Check:Off}`,
    `{Name:"Watching", Check:On}`, `{Name:"All", Check:Mixed}`, `{Name:"Other"}`; stripped lines are `│   Watch    │`
    (blank mark), `│ ✔ Watching │`, `│ – All      │`, `│   Other    │` with names starting in one column.
  - `TestAGlyphIsDrawnInlineBeforeItsNameAndNoColumnIsKeptForIt`: `{Glyph:"🏠", Name:"Welcome"}, {Name:"Quit"}` →
    `│ 🏠 Welcome │` and `│ Quit       │` (names start at different columns).
  - `TestNameColIsWhereEachNameStarts`: `NameCol` for the three item sets above gives 2 (no gutter, no glyph), 4, and 5
    for the glyphed line.
  - `TestTheSettingsDialogStandsOnTheNameOfSettings`: the existing `Choice.From` for Settings equals
    `{X: left + NameCol(items,k), Y: Top+1+k}` (update the existing assertion that hard-codes `left + 5`).
- [ ] **Step 2: Run** `go test ./internal/shell -run 'Gutter|Glyph|NameCol|Settings' -v` → FAIL (undefined `Check`).
- [ ] **Step 3: Implement** in `shell.go`. `Item` becomes
  `struct{ Glyph, Name, Keys string; Here bool; Check Check; Opens bool }`. In `boxIn`, a line's left text is a cell,
  the gutter (two cells, only when some item has `Check != NoCheck`, the mark being `✔` for `On`, `–` for `Mixed`, a
  space for `Off` and `NoCheck`), the glyph and a space when the item has a glyph, then the name; `inner` is the widest
  left text plus the keys columns as today (two cells and the widest keys when any line has keys), plus a cell. Dim,
  under-the-keyboard and `Here` styling are unchanged. `choice` uses `NameCol` for Settings' `From.X`.
- [ ] **Step 4: Run** `go test ./internal/shell -cover` → PASS, 100.0% (fix every existing shell test that holds a box's
  lines; they now show the inline layout).
- [ ] **Step 5: Commit** `#610 kittui: a menu draws a check gutter where a line is a toggle, and its glyphs inline`.

### Task 2: Strip the glyphs the person decided against (#610)

**Files:**

- Modify: `projects/tui/internal/tabs/menu.go`, `projects/tui/internal/flow/menu.go`,
  `projects/tui/internal/flow/act.go`, `projects/tui/internal/flow/rowmenu.go`, `projects/tui/internal/shell/shell.go`
  (`Menu.Items`), `projects/tui/internal/flow/watch.go` (`ownItems` glyphs only), `projects/tui/internal/table/presets.go`
- Test: the `_test.go` files and golden files of those packages that hold a menu line

**Interfaces:**

- Consumes: `shell.Item.Check`, `shell.Check` values from task 1.
- Produces: no new names; the tab menu's, the row menu's and these app-menu lines carry no `Glyph`: Settings…, Quit,
  Workspace, Refresh All, Watch All, Stop Watching All. The app menu's twelve screens keep theirs. The presets menu's
  checked view and checked scoped presets use `Check: On` in place of `Glyph: Checked`, and every other preset line
  `Check: Off`; `PresetMenu.Drop` finds the checked line by `Check == On`.

- [ ] **Step 1: Write the failing tests:** in `tabs/menu_test.go` (create if absent), `TestTheTabMenusItemsCarryNoGlyph`
  asserts every item of `SizeItem(false)`, `SizeItem(true)`, `FoldItems()` and `SelectItems()` has `Glyph == ""`; in
  `flow/rowmenu_test.go`, `TestTheRowMenusLinesCarryNoGlyph` for `m.rowItems()` over a row with actions; in
  `shell/shell_test.go`, `TestTheAppMenusOwnLinesAndSettingsAndQuitCarryNoGlyphButTheScreensKeepTheirs`; in
  `table/presets_test.go`, `TestThePresetMenuChecksTheViewTheTableIsSetAs` (a checked line has `Check == On`, the others
  `Off`, and `Drop` puts the keyboard on the checked one).
- [ ] **Step 2: Run** the four tests → FAIL.
- [ ] **Step 3: Implement:** delete the `Glyph:` field from those item literals; delete the constants nothing else
  references (`grep -rn '<Name>' internal` each: `Maximize`, `Restore`, `Reload`, `More`, `Less`, `Expand`, `Collapse`,
  `Every`, `table.Sweep`, `OpenPage`'s `Browse`, and the row menu's glyph constants) but keep any a legend or a table
  still draws (`Unwatched` stays: `flow/legend.go` draws it). Do not touch `StopWatched` yet (task 3).
- [ ] **Step 3b:** Settings' dialog position now follows `NameCol` (task 1); confirm
  `TestTheSettingsDialogStandsOnTheNameOfSettings` still passes.
- [ ] **Step 4: Run** `go test ./internal/tabs ./internal/shell ./internal/table ./internal/workspaces ./internal/opener
  ./internal/welcome ./internal/flow -cover`; for failures that are menus drawn without their glyphs, update the
  assertion; for goldens, `-update` and read the diff. Expected: PASS at 100.0%.
- [ ] **Step 5: Commit** `#610 kittui: the tab, row and some app menu lines carry no glyph; a checked preset is a ✔`.

### Task 3: Watch and Watch All are toggles (#611)

**Files:**

- Modify: `projects/tui/internal/flow/watch.go`, `projects/tui/internal/flow/menu.go`
- Test: `projects/tui/internal/flow/watch_test.go`, `projects/tui/internal/flow/maximize_test.go`

**Interfaces:**

- Consumes: `shell.Item.Check`.
- Produces: constants `WatchIt = "Watch"`, `Watching = "Watching"`, `WatchAll = "Watch All"`,
  `WatchingAll = "Watching All"`; `StopIt`, `StopAll` and `StopWatched` deleted;
  `func (m Model) watchItem(i int) shell.Item` returns `{Name: WatchIt, Keys: "W", Check: Off}` or
  `{Name: Watching, Keys: "W", Check: On}`; `ownItems()` returns Refresh All and one line `{Name: WatchAll, Check: Off}`,
  `{Name: WatchAll, Check: Mixed}` or `{Name: WatchingAll, Check: On}` from `watching()`, dim (`dim` names it) only when
  `all == 0`.

- [ ] **Step 1: Write the failing tests** in `watch_test.go`: `TestWatchInTheTabsMenuIsAToggleThatReadsWatchingWhenOn`
  (the line reads `Watch` with no ✔, then `Watching` with ✔ after choosing, then `Watch` again; replaces
  `TestWatchInTheTabsMenuWatchesTheStageThenReadsStopWatching`); `TestWatchAllIsBlankMixedOrCheckedAndAMixedClickCompletesTheSet`
  (none watched: blank; one of three: `–`; choosing watches the other two and it reads `Watching All` with `✔`; choosing
  again stops all three and it is blank; replaces `TestWatchAllWatchesEveryStageAndStopWatchingAllStopsThemAll`);
  `TestWatchAllIsDimAndDoesNothingWhenNoStageCanBeWatched` (every stage unwatchable: dim, unchecked, choosing returns no
  command and watches none).
- [ ] **Step 2: Run** them → FAIL.
- [ ] **Step 3: Implement:** `acts` and `pick` in `menu.go` match `WatchIt, Watching` together for the tab line, and
  `WatchAll, WatchingAll` for the app line; the app line calls `watchAll(on)` with `on` false only when
  `watched == all && all > 0`. Remove the Stop Watching All line and every reference to the deleted constants.
- [ ] **Step 4: Run** `go test ./internal/flow -cover` → PASS 100.0%; grep `docs/` and `.kit/welcome` pages for
  "Stop Watching" and fix any prose that names the old lines.
- [ ] **Step 5: Commit** `#611 kittui: Watch is a toggle, and Watch All is blank, – or ✔, a mixed click completing the set`.

### Task 4: Submenus (#612)

**Files:**

- Modify: `projects/tui/internal/shell/dropdown.go`, `projects/tui/internal/shell/shell.go` (`boxIn` draws `>`)
- Test: `projects/tui/internal/shell/dropdown_test.go`, `projects/tui/internal/shell/shell_test.go`

**Interfaces:**

- Consumes: `Item.Opens` from task 1.
- Produces:
  - `type Subs func(path []int) (items []Item, enabled func(int) bool)`: the owner's lines for the submenu the path
    names, the path being the line index chosen at each level from the root.
  - `Dropdown.Path []int`: the open submenus, empty when only the root is open. `Opened` leaves it empty.
  - `func (d Dropdown) KeyIn(k tea.KeyPressMsg, items []Item, enabled func(int) bool, subs Subs,
    closes ...string) (Dropdown, []int)` returning the chosen path, nil for none.
    `→`, `.` and enter on an enabled `Opens` line append it to `Path`; `←`
    and esc pop the deepest, and esc with an empty path closes the menu; up, down, shortcuts and typed letters act on
    the deepest open level; `→`/`.` on a line without `Opens` does nothing. `Key` stays and is `KeyIn` with `nil` subs
    returning the root index (or -1).
  - `func (d Dropdown) ClickAt(x, y int, boxes []Placed, items [][]Item,
    enabled []func(int) bool) (Dropdown, []int)` takes the open levels' placed boxes, deepest tested first: a click on a
    line that acts chooses it, on an `Opens` line opens it, on another line of a box does nothing, off every box closes.
  - `type Placed struct{ Top, Left, Width, First, Shown int }`.
  - `func SubBox(items []Item, enabled func(int) bool, at int, parent Placed, row, room int)
    (lines []string, top, left int)`:
    the submenu hangs from its parent's line `row`, its top edge on that line, its left edge on the parent's right edge,
    moved to the parent's left (its right edge on the parent's left edge) when it would run past `room`, and up when it
    would run past the screen's bottom.
  - `boxIn` draws a dim `>` in a column of its own after the keys on every `Opens` line, and leaves the column blank on
    others when any line has `Opens`.

- [ ] **Step 1: Write the failing tests:** `TestAnOpensLineEndsInADimGreaterThan` (box lines), `TestRightDotAndEnterOpenASubmenuAndLeftAndEscClose`
  (path grows and shrinks; esc at the root closes), `TestRightOnALineWithoutASubmenuDoesNothing`,
  `TestADimOpensLineCannotBeOpenedByKeyOrClick`, `TestAClickOnAnOpensLineOpensItAndOnTheParentWhileOpenClosesTheSubmenu`,
  `TestASubmenuOpensToTheLeftWhereItWouldRunPastTheRoomAndUpWhereItWouldRunPastTheBottom`,
  `TestAShortcutAndATypedLetterActInTheDeepestOpenMenu`.
- [ ] **Step 2: Run** `go test ./internal/shell -run 'Opens|Submenu|Dot' -v` → FAIL.
- [ ] **Step 3: Implement** as the Interfaces say. `Dropdown.Key` delegates to `KeyIn` with `nil` subs so no existing
  owner changes; a menu with no `Opens` line behaves exactly as before.
- [ ] **Step 4: Run** `go test ./... -cover` from `projects/tui` → PASS, every package 100.0%.
- [ ] **Step 5: Commit** `#612 kittui: a menu line can open a submenu with →, . or enter, and shows >`.

### Task 5: The gate and the pages

**Files:**

- Modify: any `.kit/welcome` page or `docs/` page the earlier tasks' grep found that names a removed line or glyph.

- [ ] **Step 1:** `grep -rn "Stop Watching\|Stop Watching All" docs kit/packages projects/tui --include=*.md --include=*.go
  --include=*.golden` returns nothing outside `docs/superpowers`.
- [ ] **Step 2:** run `kit gate`; expected: every stage passes. Fix and re-run, never skip.
- [ ] **Step 3: Commit** any page edits under #609: `#609 kittui: pages name the menus' Watch lines as they are`.

---

**Self-review.** Spec coverage: gutter (task 1), sparse glyphs and the person's glyph decisions (tasks 1, 2), Watch and
Watch All with mixed (task 3), `>`, →/`.`/enter/←/esc and click (task 4), top-edge hang kept (`boxIn` mark logic
untouched; `SubBox` hangs from a line), non-goal of no live submenu respected (no owner passes `Opens`), calls in the
spec's list (Show More keeps `>`: untouched; group layering: untouched). The Review Focus items each have a named test.
