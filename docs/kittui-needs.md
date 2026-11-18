# What kittui needs from the terminal

kittui is a full-screen program. This page says what it asks of the terminal, the font, and the colors, and what it
draws where one of them is missing. [terminals.md](terminals.md) lists, for each terminal, the settings that make
kittui slow or wrong; `kit welcome` judges the terminal against it.

## The terminal

kittui needs these from the terminal it runs in:

- the alternate screen, and a mouse that reports clicks, drags, and the wheel. Every action has a path of plain
  left clicks, since some terminals keep ⌥, ⌃, and the right button for themselves;
- the kitty keyboard protocol where the terminal has it, for keys that plain terminals cannot tell apart; kittui runs
  without it;
- emoji that take two cells, and arrows and rules that take one, so columns stay in place. kittui draws its menus
  with two-cell emoji. It uses no circled glyphs, since they are unreadable in many fonts.

## The font

Any font that draws emoji works. A label, such as `priority=high` or `bug`, and the preset selector on a table's control
line are drawn one of two ways. With a Nerd Font, or any font with the powerline glyphs U+E0B6 and U+E0B4, they end in
half circles:

```text
 priority  high   bug   All Issues ▼
```

Without one, each is a block of its color, padded a cell on each side. kit cannot ask a terminal whether its font has
the glyphs, so it looks for a Nerd Font: in the terminal's own font setting where it can read that, else among the fonts
installed ([terminals.md](terminals.md#fonts) says how). Where it finds one, labels start rounded; else square. `kit
welcome` says which, in the terminal's line of its setup step. Open the app menu with `=`, choose Settings…, and turn
Rounded labels on or off to choose for yourself: kittui keeps the choice in its settings file, and it wins over what
kit finds. In a font without the glyphs, a rounded label's ends are boxes or gaps.

Where the terminal draws no color, a label with a key and a value is one block, and keeps its `=` or `:`, so it reads
`priority=high` and not `priorityhigh`.

## The colors

kittui asks the terminal for its background color when it starts, and reads how many colors it draws from the
environment, as other terminal programs do (`COLORTERM`, `TERM`, and `NO_COLOR`).

| The terminal | The row under the cursor |
| --- | --- |
| has a dark background | a dark grey band |
| has a light background | a light grey band |
| has not said, or never does | reverse video, which reads on either |
| draws no color (`NO_COLOR`, `TERM=dumb`) | reverse video |

With `NO_COLOR` the colors go, and what the keyboard is on is drawn in reverse video: the line under it in a menu or a
dialog, the stop under it in a table's control line, and the preset selector, as well as the row under the cursor.
Bold, underline, and dim stay where the terminal draws them. A terminal that draws no text attributes at all, such as
`TERM=dumb`, cannot show dim, so a menu line that cannot act now looks like the others there.

The colors of the tabs and menus are chosen for dark backgrounds. On a light background, use a terminal theme with
enough contrast, or run kittui in a dark profile.
