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

Any font that draws emoji works, and a Nerd Font, or any font with the powerline glyphs U+E0B6 and U+E0B4, draws kittui
whole. A label, such as `priority=high` or `bug`, and the preset selector on a table's control line end in half
circles:

```text
 priority  high   bug   All Issues ▼
```

kit cannot tell which glyphs a font has. In a font without them, the ends are boxes or gaps: open the app menu with
`=`, choose Settings…, and turn off Rounded labels. A label is then a block of its color, padded a cell on each side.
kittui keeps the choice in its settings file.

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
