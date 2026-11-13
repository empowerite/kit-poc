---
title: The tab bar
summary: The numbered tabs under the menu bar are one per stage, each with its count and its menu.
glyph: 📑
audience: [newcomer, ui]
order: 12
---

```text
  1╶───────────────╮2╶────────────────╮3╶───────────────╮
  │ 🎫 issues  7 : │  🔀 changes  3   │  🏭 builds  4   │
  ╵                ╰──────────────────╰─────────────────╰──
```

Each [app](kittui:welcome/terms/application) has its own tabs: one [stage](kittui:welcome/terms/stage) of kit each.
[Welcome](kittui:welcome) and [Tutorials](kittui:tutorials) have none.

## Reading a tab

- `1`  the selected tab's number, in bold. Its key selects it, and so does a click on it.
- `2`  another tab's number, the key that selects it. Click to select it.
- `🎫`  the stage's glyph
- `3`  how many rows it has. `50+` means kit read only part.
- `•`  yellow dot: the tab is stale. Click it to read it again.
- `:`  the tab menu, on the selected tab

## Keys

- `1`–`9` and `0`  jump to a tab, `0` to the tenth
- `⇥` `⇧⇥`  next and previous tab
- `↓`  down to the [control line](kittui:tutorials/control-line)
- `:`  the tab menu
- `q`  quit, as `⌃Q` does anywhere. `q` quits only while the tab bar has the keyboard.

## The tab menu

- **Maximize** `M`  the rows take the whole screen. **Restore** `M` undoes it.
- **Refresh** `R`  read the stage again
- **Watch** `W`  read it again whenever it changes
- **Open Page** `O`  open the selected [rows](kittui:tutorials/rows) on the forge, or the row under the cursor
- **Select All** `⌃A`
- **Show More** `>` and **Show Less** `<`  open or close a level of the rows
- **Show Selected** and **Hide Selected**

Some stages add their own lines. The issues tab has **New…** `N` and **Assign to Me** `A`. They act on the selected
rows, or on the row under the cursor when none is selected.
