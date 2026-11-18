# Menus in the style of macOS: a check gutter, sparse glyphs, and submenus

kittui's menus are one drawing function, `boxIn` in `projects/tui/internal/shell/shell.go`, over `shell.Item`. This
design changes how every menu looks and adds two things a macOS menu has and kittui's does not: a line that is a
toggle, with its state in a gutter, and a line that opens a submenu.

## Intent

The person who uses kittui finds a macOS menu, Safari's in particular, cleaner than kittui's, and wants parts of it.
Today every line reserves a two-cell glyph column whether it has a glyph or not, a toggle is two names that swap
(Watch, Stop Watching), and nothing nests. The look to adopt, from the screenshots the person gave:

- a gutter for a ✔ that is there only when some line of the menu is a toggle;
- glyphs used sparsely, drawn inline before the name, with no column reserved for them;
- dim keys at the right, as kittui already draws them, and `>` after them on a line that opens a submenu.

## Goals

- Every menu, the app's, the tab's, a row's, the column menu's and the field popover's where they go through
  `boxIn`, draws in the new look.
- A line is a toggle when it has a check state: off (blank), on (`✔`), or mixed (`–`). The gutter is two cells, the mark
  and a space, and is drawn only where some line of that menu has a check state; lines without one leave it blank.
- Watch is one line: `Watch`, and while the selected stage is watched, `Watching` with `✔`. Stop Watching is gone.
- Watch All is one line in the app's menu: blank when no watchable stage is watched, `–` when some are, `✔` when
  every watchable stage is. Choosing it watches every watchable stage not yet watched when not all are, so a mixed
  click completes the set, and stops them all when all are. Stop Watching All is gone. A stage that cannot be watched,
  as `watchable` says, is left out of the count, as `watching` leaves it out now.
- A line with sub-items ends in a dim `>`, after the keys. → or `.` or enter on it, or a click, opens its submenu to
  the right of the line, hung from that line; ← or esc closes the submenu and returns to the line, and esc on the first
  level closes the menu. `.` does what → does and is not named on the keys bar.
- A menu's top edge keeps hanging from the glyph or label of what invoked it, as it does now. A submenu's edge hangs from
  the line it opened from.

- Which glyphs stay, as the person decided: the tab menu (:) and the row menu keep none, and the app menu keeps those of
  its twelve screens, losing the glyphs of Settings…, Quit, Workspace, Refresh All, Watch All and Stop Watching All. Every
  other menu through `boxIn`, the workspace group, books, recent, clones, presets and constraint card menus, keeps the
  glyphs it has, drawn inline; thinning them is a later taste decision, menu by menu.

## Non-goals

- No live submenu in this change: no menu needs one yet. The mechanism ships, tested, and the first use is a later
  request.
- No change to what any line does, other than the two Watch lines and Watch All.
- No icon column, no two-cell white icons: kittui keeps its two-cell color emoji where a line has a glyph.

## Anti-goals

- A second menu component beside the old one, or two looks at once.
- A circled glyph that is unreadable in iTerm with Meslo, or a menu glyph that is not two cells (see the menu-glyph
  rules in the person's notes: menus use two-cell emoji; the column menu and popover keep their one-cell symbols).
- Hiding a line that cannot act: a line that cannot act now stays, dim, and the keyboard passes it by.

## Constraints

- Plain clicks only: every action has a plain click, as iTerm swallows modified and right clicks.
- A menu's keys at its right stay `Item.Keys`, a letter in upper case as macOS draws it; the keys bar names only
  esc, ↑↓ and ⏎ for a menu.
- kittui's Go is held to 100% coverage, and a known wrong case is fixed, not reported.
- Options and wording follow the repository's own rules; a commit's subject starts with its issue number.

## Approaches

- **A. Extend `Item` and `boxIn` in place.** `Item` gains a check state and a list of sub-items; `boxIn` draws the gutter
  and the glyph inline; `Dropdown` gains the path of the open submenus. One drawing function, so every menu changes at
  once. **Picked.**
- **B. A second menu component beside the old.** Two looks live together while screens move over. Rejected.
- **C. Replace `Item` with a menu tree type** built by every caller. Cleaner at the end, but touches every construction
  site at once, and the toggle and the gutter do not need it. Rejected.

## The design

`Item` becomes `Glyph, Name, Keys string; Here bool; Check Check; Sub []Item`, `Check` being `None` (the zero value, no
toggle), `Off`, `On`, `Mixed`.

**Slice 1, the look.** `boxIn` lays a line out as: a cell, the gutter (two cells, only when some item has a check
state), the glyph and a space when the line has one, the name, then, where any line has keys or a submenu, two cells,
the keys flush right, and a cell for `>` where any line has a submenu. Every existing test that holds a menu's lines
changes to the new look. Click and keyboard positions follow `boxIn`'s geometry, so `Dropdown.Click`'s hit test
changes with it.

**Slice 2, Watch.** `watchItem` returns `Watch` (check `Off`) or `Watching` (check `On`), key `W`. `ownItems` returns
Refresh All and one Watch All line whose check is `Off`, `Mixed` or `On` from `watching()`; its dim state is "nothing
watchable". Choosing Watch All calls `watchAll(on)` with `on` false only when every watchable stage is watched. The
keys bar's right end, which says "watching" while the selected stage is watched, is unchanged.

**Slice 3, submenus.** A line with `Sub` shows `>`. `Dropdown` holds the open path, a list of line indexes. →, `.` and
enter on such a line push it, ← and esc pop it, and up, down, shortcuts and typed letters act in the deepest open
menu. A click on a line of any open level chooses it; a click on a `>` line opens it; a click off every box closes
all. Each submenu is drawn by `boxIn` hung from its parent line, to the right where it fits and to the left where it
does not, and over the parent menu.

## Calls made without the person (marked for checking)

- Show More and Show Less keep `>` and `<` as their keys. A submenu opens on →, `.` and enter, not on `>`, so the two do
  not meet today: no menu has both. When one does, Show More's key is rethought then.
- Existing owners keep their click geometry; submenu hit-testing is added in slice 3, and only for menus that use `Sub`.
- The workspaces group menu, dropped over the app menu, keeps its own layering and is not moved onto `Sub`.
- A `Sub` line only opens its submenu and never acts itself; dim, it cannot open; the keyboard moves over it as over any
  line.
- `Watch` reads `Watching` when on, and `Watch All` reads `Watching All` when every watchable stage is watched; the name
  checks match both, and `StopIt`, `StopAll`, `Unwatched` and `StopWatched` are deleted.
- The columns dialog, the field popover and the manage dialog draw their own boxes, not `boxIn`, and are unchanged.

## Left to the builder

Exact column widths and the wording of each test; how the submenu's box avoids the screen's edges beyond "right if it
fits, else left"; whether `Dropdown`'s path is a slice or a small struct; the order of the slices' commits.
