---
title: The control line
summary: The line over the rows says how they are grouped, and the preset they are set as.
glyph: 📊
audience: [ui]
order: 13
---

```text
  ▾ source ▾ assignees ▾ 3          📇 Fields  Default ▼
```

## Left: the groups

- `▾ source`  the [rows](kittui:tutorials/rows) are grouped by source. Click the name for its settings.
- `▾`  open. Click to close that level.
- `▸`  closed. Click to open it.
- `3`  how many rows

With no groups, it is the rows' `▾` and their count alone.

## Right: the preset

- `Default ▼`  the preset the table is set as. Click it, or `⏎` on it, for the presets menu.
- A name struck through means you changed the table since.
- Each tab opens as you last left it, your changes kept, even unsaved ones.
- 📇 **Fields**  every field: show, hide, sort, group, filter. `f` on the preset, or in the rows, opens it too.
- Before it: how many rows are selected, and a chip per filter. Click a chip to change its filter.

## The presets menu

- **Save**  keep your changes in this preset
- **Save As…**  keep them as a new preset
- **Manage…**  every preset: star it, order your favorites, rename or delete one of yours
- The presets, to switch to: your favorites first, then your team's, then the built-in ones, then yours

Save is dim on the built-in presets, and they cannot be renamed or deleted. Click a preset's ☆, or press `*` on it, to
make it a favorite; ★ marks one. Your team's presets are files in the repository, under `.kit/presets`; in Manage…,
Share
with team moves one of yours there, for you to commit, and Copy to mine copies one of theirs to yours. A repository
without kit installed has no team presets.

## Presets that follow you

- Presets that apply on every tab, or every tab of an app, stand in the menu under **everywhere** and **in** the app's
  name. A ✔ marks those in force. Click one to turn it on or off, and every tab follows.
- The narrowest wins: the tab's own preset beats them for the same field, and your changes in the rows beat both.
- A setting a tab cannot use, as a filter on a field it has not, shows dim in the line, never dropped. Click it for
  whose it is and why, and to turn it off here, in this app, or everywhere.

## Keys

- `↓` from the [tabs](kittui:tutorials/tab-bar) reaches the line. `↓` again enters the rows.
- `⇥` `⇧⇥`  move between the names, the count, and the preset
- `→` `←`  open and close the level under the cursor
- `⏎`  on a name: its settings. On the preset: the presets menu.
