# Bugs in kittui and the tutorials site

## The answer

This section has eleven high items: ten in kittui and one in the tutorials site. Two act on the wrong thing: a
form's verb runs in the repository kittui started in, and an issue action runs on this repository's issue when
the row is another repository's. Four crash kittui from keys or clicks alone. No field takes a paste. A kit child
that asks for a password is stopped behind the screen. The site's own code is sound, and nothing publishes it.

The seven areas hold 139 findings, and the recheck of the 11-10 review (R2) adds 72, of which 44
concern kittui. Skeptics tried the 24 high findings of these areas, confirmed 19, narrowed 5, and
refuted none. With duplicates merged, this section reports 11 high items, 4 narrowed below high, 49
medium, and 81 low. The reviewers reproduced the medium items or read them in the code, and no skeptic
ran them. I checked the cited lines of the high items and of eight medium ones in the snapshot.

Of the 58 findings the 11-10 review made in Components and Apps, 12 are fixed, 32 are open, 11 are
partly fixed, and 3 were not rechecked. One of its three criticals is still open: the form's choice
kept by ordinal. In the tutorials site, the four site bugs are fixed and three findings are open.

A path that starts with a package name, such as flow/rows.go:475, is under projects/tui/internal/.

## High

1. A form's verb runs where kittui started, not in the workspace the person switched to. `main` execs with the
   runner it made at the start (projects/tui/cmd/kittui/main.go:55, :75), while the root moves its own copy to
   the picked checkout (screens/screens.go:234-239). After a pick of repository B, `kit commit`, `kit submit`,
   or `kit tidy` reads its choices in B and runs in A. Have the root expose its runner, or carry it in the
   form's result, and exec with that. Confirmed end to end. Known since 11-10 (Apps 3). (G5-1, R2-2)
2. An action on another repository's issue runs on this repository's issue of the same number.
   `issueRows` keys a row by its number alone and drops the organization and repository that kit prints
   (flow/rows.go:475, :510, flow/fields.json:43). With jig's #7 selected in kit's picture, Close as Not
   Planned shows jig's title and runs `kit close --not-planned #7` in kit. The reach is the underway
   rows, where kit lists an issue of another repository that a pull request closes, and where kit's jq
   matches by number alone too (kit/modules/jq/backlog.jq:12). Key a row by organization, repository,
   and number, and dim the actions on a row this checkout does not hold. Confirmed. (G2-1, B6-5)
3. Nothing publishes the tutorials site. `kit tutorials kit-tutorials` opens
   `https://empowerite.github.io/kit/tutorials/0.1/kit-tutorials/` (kit/modules/bash/tutorials.sh:27). No workflow
   in the tree deploys a page, `bin/tutorials` takes `catalogue` alone (bin/tutorials:95-100), and the publishing
   plan has 33 steps, none ticked (docs/superpowers/plans/2026-11-10-tutorials-2-published.md). No reviewer had a
   network to ask the address, and the 11-10 review saw it answer 404. Carry out the plan before the release, or
   ship kit-tutorials as a page in the kit, as the other nine are. Confirmed for the tree. (T1-1, B8-1, R3-8)
4. The form panics from keys alone, and where it survives it writes a choice nobody made. `Collect` keeps a
   one-of row's choice by the row's ordinal in the walk, `choose` returns it unchecked
   (form/fields.go:289-293), and `group` indexes with it (form/fields.go:265). In the form of `kit flow`,
   `--jq` on the second usage line and then `issues` on the first ends kittui with
   `index out of range [2] with length 2`, and in `kit packages` the same steps leave `kit packages add` on
   the command line. Key a choice by its group's path in the grammar, drop the choices of rows that left, and
   bound the index in `choose`. Confirmed twice. Known since 11-10 (Components 1, critical then). (G4-1, R2-1)
5. PgUp, PgDn, Home, or End crashes `kit welcome` on a step whose search shows no check. The keys
   are `2`, `/`, `zzzz`, Enter, PgDn. `page` indexes `rows[len(rows)-1]` with no guard for an empty
   list (welcome/welcome.go:961-969), and leaving the search gives the pane the keyboard whether or
   not it has a row (welcome/welcome.go:667). Return from `page` when the step has no rows, as
   `down` does at line 948. Confirmed three times. Known since 11-10 (Apps 4). (G6-1, R2-3, U3-1)
6. The fields dialog panics on a table with no rows and no groups, because `Columns.Keys` and `Columns.Act` index
   `Listed()[At]` with no bound (table/columns.go:331, :220). `f` opens the dialog, and so does a click on the
   blank cells where the hidden Fields button would be: on the workspaces screen with no group yet, its first-run
   state (workspaces/workspaces.go:612), and on tutorials before kit answers (tutorials/tutorials.go:648). Clamp
   `At` as `Columns.Card` does at table/columns.go:48, and pass no key or click to a sheet that is not drawn.
   Confirmed on both screens. An empty Flow tab is plausible and was not run. (G3-1, G6-2)
7. A failed reload keeps the old rows behind the refusal: `take` leaves them (flow/flow.go:1042-1048), though
   flow/rows.go:278 promises none. At 53 columns or fewer, with frozen headings that take more lines than the
   refusal, the next draw slices past the end and kittui dies (table/view.go:97). At any width the keys still act:
   `a` ran `kit assign #7` on a row nobody sees, and Select All then Assign to Me ran on six. Give no rows for a
   stage that is loading or refused, and clamp the skip in `ScrollLines` and `Laid`. Confirmed. (G1-1, G1-2, G2-3)
8. A paste types nothing anywhere in kittui. Bubble Tea 2.1.1 delivers a paste as `tea.PasteMsg`,
   because `shell.View` leaves bracketed paste on (shell/view.go:15), and no file under projects/tui
   handles that message. A commit subject in a form (form/model.go:130), a git URL in a workspaces
   prompt (workspaces/prompt.go:74), a path in Open Repository (opener/open.go:249), and a word in a
   search (shell/search.go:69) or the palette (palette/palette.go:382) all vanish. Have `shell.Type`
   take a paste as typed text with its newlines dropped, and give the message to the open dialog first.
   Confirmed five times. Known since 11-10 (Components 4). (G4-2, G5-2, G6-3, G1-10, R2-8, U2-2)
9. A kit child that asks on the terminal is stopped, and its prompt is drawn over the screen. `grouped` starts kit
   with `Setpgid`, in a background process group of kittui's terminal (kit/kit.go:424), and of kit's fetches only
   `marks:incoming` tells git not to prompt (kit/modules/bash/marks.sh:119, against kit/modules/bash/flow.sh:580).
   A read of /dev/tty there gets SIGTTIN, so the stage hangs for its two-minute limit, and an action hangs for
   good, since `Act` has no limit. Use `Setsid`, which the reviewer ran with the package's tests passing, and add
   `GIT_TERMINAL_PROMPT=0` to the client's environment. Confirmed under a pty. (G5-3, I4-12)
10. A view that filters by `@me` opens empty. kittui asks kit who the caller is only when a card, a
    chip, or the issues tab's menu opens (flow/flow.go:740), never in `Init` (flow/flow.go:328), so a
    kept panel or a saved preset with `author: @me` draws `no row matches the panel`. A failed
    `kit flow --me` is dropped and never asked for again (flow/flow.go:403-407), and `@me` then matches
    nothing for the session. Ask in `Init`, draw `loading` until kit answers, and on a failure say so
    and clear `asked`. Confirmed. The second half is known since 11-10 (Apps 25). (U1-1, G1-12, R2-68)
11. Group values that differ only by case interleave into several headings with one key. Labels `Bug`, `bug`,
    `Bug`, `bug` give four headings and two keys, because entries sort by `natural`, which ignores case
    (grid/panel.go:607), and headings are cut by exact value (grid/panel.go:626). It needs the variants to
    alternate in the input, as labels across a workspace's members can. Break the ties of `natural` by the
    exact text. Confirmed. G4 rates it high and R2 medium. Known since 11-10 (Components 6). (G4-5, R2-21)

## Narrowed by the skeptics

These four were reported high. Each skeptic reproduced the facts and judged the claim too wide.

1. Links to issues and pull requests are guessed from `origin`. kit prints no address for an issue or a
   change (kit/modules/jq/forge.jq:285), so kittui builds one from the last two path segments of
   `git remote get-url origin`, in GitLab's shape only where the host's name contains `gitlab`
   (flow/origin.go:17, :43, :73). Azure DevOps gets `dev.azure.com/_git/policy/pull/7`, a GitLab subgroup
   loses its group, and a fork's `origin` is used whatever `primary` says. The narrower claim is medium:
   only the links a person opens or copies are wrong, GitHub is right, and no kit verb uses them. Have kit
   print each row's page, as builds and releases do. Known since 11-10 (Apps 8). (G2-2, S1-1, S3-1, R2-31)
2. Two kittui on one presets file drop each other's presets and favorites of the same table, because
   `KeepPresets` reads the file again and then writes this table's list as the caller built it
   (table/store.go:123-137, table/sheet.go:916-929). The writers also share one temporary name and take no lock:
   of 2,000 writes by four writers, 1,099 failed (table/store.go:110-114, table/team.go:85-88), and Flow drops
   that error (flow/flow.go:655). The narrower claim: the loss needs two processes saving the same table, and the
   store promises only that other tables' presets stay. Pass `KeepPresets` a function to apply to the list the
   file holds, name the temporary file with `os.CreateTemp`, and lock around the read and the write. (G3-2, G3-4)
3. An optional pick cannot be cleared once taken: in `kit new file`, one Enter on `--rule` writes `--rule=a` for
   good. Enter taking the row under the cursor is designed and tested (form/model.go:976). What stands is that
   the keys bar calls Enter `next` on that field (form/model.go:245), and that backspace erases the filter alone
   (form/model.go:532). Let backspace on an empty filter clear the pick, and name Enter for what it does. (G4-3)
4. `r` can run the fix of a check the step does not show, because `find` gives index 0 when the step
   has no row and `fixUnder` reads that check (welcome/welcome.go:561-573, :843). It is latent:
   kit's first check is always `tool-bash`, which has no fix (kit/modules/bash/welcome.sh:517), so
   today `r` and `c` do nothing. Have `fixUnder` and `keeping` require that the cursor is among the
   step's rows. Known since 11-10 (Apps 5). (R2-4, G6-4)

## Medium

There are 49 medium items. The table gives each with its place and its fix. A number such as Apps 11
after the ids is the finding's number in the 11-10 review, where it is still open or partly fixed.

| Part | What is wrong | Where | What to do | Findings |
| --- | --- | --- | --- | --- |
| Flow | With no stage in the picture, as `flow: [desk]` gives, tab, shift-tab, alt-right, and alt-left crash kittui | flow/flow.go:856-858, :873-876 | Guard the four keys as `[` and `]` are guarded | G1-3 |
| Flow | A watched stage whose reload fails once is never read again, and the keys bar still says `watching` | flow/marks.go:33 | Let a refused stage take marks, and clear the refusal when a read lands | G1-4 |
| Flow | Going back along a crumb puts back each stage's whole table, so a load that landed meanwhile loses its blank columns and its automatic grouping | flow/crumb.go:63-67 | Restore only what the person set | G1-5 |
| Flow | A workspace told after the rows were built does not rebuild them, so the rows keep the long member names | flow/flow.go:417-421 | Call `rebuild` there, as the settings message does | G1-6 |
| Flow | A reload keeps the cursor's index, not its row. Watched stages reload by themselves, so space or `a` then acts on another issue | flow/flow.go:1050-1056 | Keep the row's key across the decode | G1-7, R2-33; Apps 11 |
| Flow | Add to Pull Request… can never be enabled in the Issues app, because `mine` reads a changes stage the app lacks | flow/act.go:169-186, flow/apps.go:26 | Read the caller's pull requests from kit, or leave the line out | G1-9, R2-30; Apps 7 |
| Flow | A jump to a row that a closed group or a filter hides lands nowhere and says nothing | flow/flow.go:1383-1395 | Search every row, open the headings over it, and say when the panel hides it | R2-32; Apps 10 |
| Flow | A `row:` link reaches only a stage of the row's own verb, so no row of `kit changes`, `kit issues`, or `kit delivery` leads to its app's home tab | flow/workspace.go:91, :103 | Let a link name its verb | G2-6 |
| Flow | Twenty of the 32 tabs have no legend, tab glyph, or color, because those are Go tables generated from glyphs.json, which names 14 stages | flow/glyph.go:67, flow/legend.go:153 | Read a tab's legend from its own catalog fields | G2-4, S1-3, S3-5 |
| Table | Starring a view moves the view and leaves the cursor, so a second space stars another view | table/manage.go:222-223, table/presets.go:168-173 | Move `At` with the view | G3-3 |
| Table | A workspace path with `[` in it hides every team preset, and Share with Team then makes the view vanish | table/team.go:54 | Read the folder with `os.ReadDir`, and report a folder that does not read | G3-6 |
| Table | Two groups whose names read alike share one spot in the heading, so the second takes no click. The packages table ships such a pair | table/heading.go:48-72 | Have the grid give each name's span as it draws it | G3-7; the rest of Components 5 |
| Table | A level's fold is kept by its depth, so it lands on another level once the groups change | table/heading.go:149-160, grid/panel.go:811 | Key a level by its field's id | G3-8, R2-23; Components 8 |
| Table | A column moves by shift and an arrow alone, with no menu line and no click, against the plain-clicks rule | table/column.go:74-95 | Add Move Left and Move Right lines, and a click in the dialog | R2-26, U2-17; Components 11 |
| Grid | Closing the rows' level folds nothing when every innermost heading stands on its parent's line, because `Levels` is then one short | grid/panel.go:849, :861, :753 | Take the level from the panel's groups | G4-4 |
| Grid | A cell's summary does not count toward its column's width, so `~/code/kit +1` draws as `~/code/ki…` | grid/grid.go:741 | Take the larger of the summary and the first value | G4-6 |
| Grid | A title of several lines needs the sum of its lines, so the columns beside it are cut with room to spare | grid/grid.go:744, :801 | Measure the widest line | G4-7 |
| Grid | Hiding down to one column makes every row an aside: folds, the header, and parents stop working | grid/panel.go:861, :1304, grid/grid.go:186 | Tell a row from an aside by `Row.Aside` | G4-9, R2-22; Components 7 |
| Tabs | A click anywhere right of the last tab selects it, or drops its menu | tabs/tabs.go:589 | Return -1 past the tabs' width | G4-10, R2-24; Components 9 |
| Shell | A search longer than the screen loses its caret, and the menu bar is one cell too wide | shell/menubar.go:107-113 | Keep the tail of what is typed, and count the two gap cells | R2-29, G5-22; Components 18 |
| Form | A flag chosen in a one-of row adds a required, inert toggle: an unseen stop under a vertical row, a second block under a side-by-side one | form/fields.go:144, form/render.go:84, :401 | Add no field for that flag | G4-8 |
| Form | A literal after leading optional groups opens no alternative, so `kit tui tools run` opens the wrong form | form/fields.go:317 | Skip the optional nodes before the first required one | G4-12, R2-27; Components 12 |
| Form | The form takes no click and no wheel below the menu bar | form/model.go:172-194 | Have `Layout` give each field's lines, so a click focuses and acts | R2-25, U2-8, U3-5; Components 10 |
| Form | The grammar is walked three times, each counting groups its own way. High item 4 and G4-11 are that convention failing | form/fields.go:232, form/command.go:100, form/render.go:221 | Walk once, and give each row its group's path | G4-13 |
| Screens | A workspace that changes its folder or members, but not its name, remakes nothing. Open Repository on a worktree of the repository shown leaves earlier screens reading the old folder | screens/screens.go:226, :241 | Compare the checkout and the members too | G5-4 |
| Screens | `kit --workspace=none welcome` opens with a refusal in the workspace menu, because the root takes `none` for a group and runs `kit workspaces --use=none` | screens/screens.go:123, kit/bin/kit-welcome:173 | Keep no last group for `none` | G5-10 |
| Client | A kit that exits 0 while a grandchild holds its pipes is reported as failed two seconds later, its output dropped | kit/kit.go:430, :735 | Treat `exec.ErrWaitDelay` with a successful exit as success | G5-5 |
| Client | kit's stderr reaches the screen whole: several lines break the frame, a long line loses its remedy, an empty one says nothing | kit/kit.go:65, :408, screens/screens.go:295, :557 | Have one function give kit's last ❌ line, and wrap it at the root | G5-9 |
| Client | A folder that is gone, as a worktree `kit tidy` removed, reads as `kit: no such file or directory` | kit/kit.go:729, :740 | Stat the folder and name it | G5-12 |
| Sources | A poll whose first read fails stops for the session and tells no one, and one verb's failed marks drop the other's. Watch then waits on nothing | source/poll.go:96, flow/flow.go:267-282 | Ask again after a wait, and keep what answered | G5-6, R2-65; Apps 15 |
| Sources | A refresh does not end a stage's first read, so two fetches of the same remotes run at once | source/load.go:46, :92 | Give the first read a cancel of its own | G5-8, R2-34; Apps 12 |
| Opener | Find clones under a folder that is a symbolic link finds nothing, though the dialog lists its folders | opener/open.go:337, :170 | Resolve the root before the walk | G5-11 |
| Workspaces | A dialog cuts what is typed at its right edge, the cursor with it, and cuts kit's refusal before its reason | workspaces/prompt.go:92, :109 | Draw the typed text with `pane.Tail`, and wrap the rest | G6-5 |
| Welcome | Customize's links are joined to the folder the command was typed in, so from a subfolder each is dead | welcome/sections.go:209, welcome/customize.go:51 | Root the links where the pages were read | G6-6 |
| Welcome | Started over a group, the guide never names the members that are not cloned, because the workspace's answer changes the title alone | welcome/welcome.go:349, :204 | Keep the workspace from the message | G6-7 |
| Welcome | A `##` inside a code block is read as a section of a terms or customize page. No shipped page has one, and a house package's can | welcome/sections.go:62, :105 | Track the fence | G6-8 |
| Cost | An open tab menu passes over every row for each line on each draw: 152 ms at 1,000 issues and 1.9 s at 10,000, on a loaded machine | flow/menu.go:119-142, flow/act.go:191-209 | Compute the menu's facts once a draw | G1-8, R2-20; Components 3 |
| Cost | In a Sheet a move of the cursor draws every row again, 74 ms at 3,000 rows, and `Selected` is quadratic | table/sheet.go:353-358, table/view.go:30-59 | Key the line cache by row | G3-9, S6-5 |
| Cost | kit runs on the update loop when an app, Help, or the palette's search opens, and when a form extends itself. The screen takes no key for 0.6 to 1.3 s | screens/screens.go:451, app/app.go:145, form/model.go:802 | Make each a command and a message | G5-7, R2-35, G4-14, R2-28, S6-4; Apps 13, Components 13 |
| Tests | The fixtures are not what kit prints: 27 of 32 lack source, organization, and repository, and one puts a control's kind under `source` | flow/testdata/audit-controls.json:2 | Generate them from kit over the fake forge, or hold their keys to kit's output in bats | G2-5, R2-36, S4-1, S3-3; Apps 17 |
| Tests | Two tests bound a wheel turn at 8 ms of wall time and failed 14 runs of 14 on a busy machine. No test fails a reload over shown rows, or lands a load between `Spot` and `Restore` | table/cost_test.go:45-66, flow/cost_test.go:211-231, flow/edges_test.go:21-30 | Count the rows drawn, and add the cases | G3-5, G1-17, S4-3, S1-17, U7-16 |
| Site | `<Since>` tells a reader on an older kit to run a plain `kit update`, which moves nothing | projects/tutorials/src/components/Since.tsx:16, projects/tutorials/README.md:95 | Print the command with the passage's version, as `kit --version=0.2.0 update` | T1-2 |
| Site | The catalogue takes an online page and a shipped page with one id. `kit tutorials` then prints both and opens an address that starts with a newline | bin/tutorials:66-86, kit/bin/kit-tutorials:78-92 | Refuse the second, naming both files | T1-3 |
| Site | The catalogue region takes any `projects/tutorials` folder for kit's source. There `kit generate --check` fails, or kit runs that repository's `bin/tutorials` and empties the region | kit/modules/tutorials.yml:7-11 | Test for a file only kit's source has | T1-4; known since 11-10 |

The other five are about structure or reach, and the architecture and experience sections own them:
the tab menu written as five switches on its labels (flow/menu.go:119-178, G1-19), the catalog's
repeated fields (flow/fields.json:48, G2-7), the keeping of presets written in Flow and in Sheet
(table/sheet.go:810-948, G3-10), the chain of menus repeated in three screens (welcome/welcome.go:634,
G6-9), and three actions with one way in (flow/flow.go:1294-1296, R2-37; Apps 18).

## Low

There are 81 low findings. Their titles follow, by package. Those marked plausible were read, not run.

- Flow, 15: Watch is offered while the marks cannot be read (G1-11); an action's answer clears a
  selection made meanwhile, and actions overlap with no limit (G1-13, R2-70); the trackers' answer
  replaces a dialog opened meanwhile (G1-14); the wheel scrolls the rows under an open dialog (G1-15);
  a jump to a missing row waits forever on a stale stage (G1-16); a long refusal is cut where its
  remedy is (G1-18); who has the keyboard is four fields set by hand in ten places (G1-20); an issue's
  reference is rebuilt as `#N`, not read from kit, plausible (G1-21); the legend omits glyphs its tab
  draws and is titled by the stage's internal name (G2-8, R2-66); a click on the legend over a refusal
  goes to the refusal (G2-9); Azure DevOps has no glyph (G2-10, S3-11); a change is `#3` on one tab
  and `3` on three (G2-11); a date that is not seconds draws as 1970-01-01, plausible (G2-12); desk
  and worktrees are left in the glyph maps (R2-64); circled glyphs are still drawn (R2-54).
- Table, grid, and tabs, 19: the preset line can name a view the panel has left (G3-11); a view's name is
  not unique once files change (G3-12); `d` deletes a preset at once and leaves the cursor past the end
  (G3-13); ctrl+a drops selected rows the search hides (G3-14); the catalog's check passes an unregistered
  rendering, and a null stage panics (G3-15, R2-52); `WritePresets` writes over a file that does not read
  (G3-16); team presets are found by file and removed by slug (G3-17); folds switch on menu words, a long
  label is not clipped, and three exports are unused (G3-18, R2-56, R2-62); the filter's `none` misses an
  empty string (G4-18); a filter value shaped like a range is a range on any field (G4-19); a click before
  a cut, right-aligned, linked cell opens its link (G4-21); a wide group heading loses its indent (G4-22);
  `natural` misorders negative and fractional numbers (G4-24, R2-59); `pane.Window` spends a line to hide
  one row (G4-25); the tabs' package comment describes another layout (G4-26); three small duplications
  (G4-27); a click on a menu's border closes it, and on a dialog's does nothing (R2-55); the keys bar
  never names 0 for the tenth tab (R2-58); the table still names Flow's words (R2-63).
- Form and palette, 11: the drawer finds a row's alternatives by another count (G4-11); the palette
  panics on a page with no newline (G4-15); the palette's wrap squashes the argument columns (G4-16);
  the cursor's band stops at kit's own reset (G4-17); a wildcard field's lines change order, and a
  line without `--` is dropped (G4-20); a list's answer writes its note under another field, plausible
  (G4-23); Enter twice on a verb opens its form twice, plausible (G5-15); the emitter writes a literal
  inside `[ ]` with no answer (R2-53); the form writes key hints under its fields (R2-57); a form's
  lines run past the edge under 44 cells (R2-60); the components spec and the code differ (R2-61).
- Shell, client, and opener, 14: esc on Open Repository does not take back the ask, and ctrl+q does not quit
  under a dialog (G5-13); the error path skips `root.Close()`, and an outside SIGINT exits 1 (G5-14, R2-69); a
  submodule is drawn as a worktree (G5-16); tab completion can cut a character in half (G5-17); Open Repository
  reads its folder twice a frame (G5-18); a call past its limit names the option, not the verb (G5-19); an Azure
  DevOps repository is titled `_git/repo` (G5-20, G6-22, B6-7); `shell.Over` trusts its top line, plausible
  (G5-21); `testkit.Drive` treats a batch differently (G5-23); the client runs kit three ways (G5-24); two small
  tables are written as code (G5-25); an opener that exits non-zero is never seen (R2-67); three 11-10 findings
  stand unrun, plausible (R2-71); `Runner.Tutorials` builds `--tag <tag>`, which kit refuses (R2-72).
- Welcome, tutorials, workspaces, and markdown, 13: in tutorials a key the search does not take moves the cards
  (G6-10); a click under the tutorials pane opens the clipped card (G6-11); the wheel scrolls welcome's pane
  under the open tab menu (G6-12); a step's search keeps the keyboard after a click on another tab (G6-13); a
  code block inside a comment is drawn (G6-14); a web address wider than the pane is cut (G6-15); welcome draws
  a `kittui:` link and follows none (G6-16); 12 of 52 verbs have no syntax fixture (G6-17, S4-7, S3-13, R2-42);
  the workspaces keys bar sends esc to tabs it does not have (G6-18); the workspaces screen's last line is not
  clipped (G6-19); Add an Owner's Repositories lists 1,000 at most, and GitHub's alone, plausible (G6-20); the
  tab-bar tutorial says welcome has no tabs (G6-21); a check id's meaning is written in three places (G6-23).
- The tutorials site, 9: the link check reads `src=` in a page's words (T1-5); two failures of
  `bin/tutorials catalogue` exit 0 (T1-6, S7-16); front matter is parsed four ways (T1-7); the home page
  and the catalogue order ids differently (T1-8); the catalogue passes what the schema and the site refuse
  (T1-9); an empty catalogue file prints an empty line and exits 0 (T1-10); `filled` keeps the generic
  title (T1-11); three passages no longer match (T1-12); the ordering rule is in four places (T1-13).

## The 11-10 findings

R2 rechecked the 58 findings of Components and Apps. It itemizes those that are not
fixed. The fixed numbers below are the ones it does not list, and they match its counts.

| Area | Fixed | Partly fixed | Open | Not rechecked |
| --- | --- | --- | --- | --- |
| Components, 30 | 2, 5, 16, 21 | 3, 10, 15, 28, 30 | 1, 4, 6, 7, 8, 9, 11, 12, 13, 17, 18, 19, 20, 22, 23, 25, 26, 27, 29 | 14, 24 |
| Apps, 28 | 1, 2, 6, 9, 16, 19, 22, 24 | 7, 14, 15, 17, 20, 23 | 3, 4, 5, 8, 10, 11, 12, 13, 18, 21, 25, 26, 27 | 28 |

The thirteen that 11-10 rated critical or high stand as follows. The other
open numbers are in the medium table, or are R2-52 to R2-72 in the low list.

| 11-10 finding | Then | Now | In this section |
| --- | --- | --- | --- |
| Components 1, a form's choice kept by ordinal | Critical | Open | High 4 |
| Components 2, the column menu over no header | Critical | Fixed; `shell.Over` still has no guard | Low, G5-21 |
| Components 3, the tab menu's cost | High | Partly: linear now, 0.15 s a frame at 500 rows | Medium, G1-8 |
| Components 4, paste | High | Open | High 8 |
| Components 5, group names in the heading | High | Fixed; same-named groups remain | Medium, G3-7 |
| Components 6, groups that differ by case | High | Open | High 11 |
| Components 7, one column left | High | Open | Medium, G4-9 |
| Apps 1, a reload decoded into the old rows | Critical | Fixed | |
| Apps 2, a document printed with exit 1 | High | Fixed | |
| Apps 3, a form runs in the wrong repository | High | Open | High 1 |
| Apps 4, welcome's page keys | High | Open | High 5 |
| Apps 5, the fix of a hidden check | High | Open, latent | Narrowed 4 |
| Apps 6, kit flow's words reach one app | High | Fixed | |

In the tutorials site, the four site bugs of 11-10 are fixed: the build's check of its output, a pre-release
meeting its own version, a dead link from MDX, and a base without its slash. Three are open: publication
(high 3), the catalogue region (T1-4), and the catalogue passing pages it should refuse (T1-9, R3-37).

R2 also rechecked Serve (20 fixed, 5 open, 2 partly) and the command line (4 fixed, 19 open, 2 partly, 3 not
rechecked). Those are bash, and the bash section reports them: R2-9 to R2-19 medium, R2-38 to R2-51 low, and
three high. `kit tools run` refuses a command that holds one of kit tools' own flags, such as `--check`
(kit/modules/jq/syntax.jq:74-77; R2-5, B1-3, B7-3, R3-4, U4-5). A uv.lock goes to jq as one argument and
fails past the argument limit (kit/modules/bash/dependencies/uv.sh:33-40), which the skeptic narrowed to a
1.4 MB lock on macOS (R2-6, B7-4, R3-5). A package that a platform marker excludes is expected in .venv, so
welcome's uv check never holds (kit/modules/bash/dependencies.sh:131-135; R2-7, B7-5).

## What is done well

- A click lands on the row drawn: 1,243 of 1,243 clicks, at six sizes,
  with rows open, scrolled, paged, and maximized.
- Late answers are dropped by number: a load's generation, the root's
  `asked`, a screen's epochs. The same pattern fixes G5-13 and G5-15.
- Every load decodes into fresh values, a document of another shape is refused with its command named, and
  `kit.partial` keeps the document of a call that exits 1. That removed Apps 1, 2, and 22 at the root.
- Answers go to kit as arguments after `--`, never through a shell. Every read that can hang has
  a limit (an action has none; see High), and a call that ends
  takes its process group with it. Keep the group kill when item 8
  moves the child to a session. `fix.Words` runs plain words alone and copies anything else.
- A preset restores its panel exactly: 3,000 random panels round-tripped. The writers
  never write over a file they could not read, and `Slug` keeps a name out of the path.
- Most actions list what they will change before they ask, and refuse where kit has not said the member's
  checkout. Assign to Me and two others run at once; the interface section's item 4 covers them.
- All 23 packages are at 100% of statements and clean under `-race`
  and `go vet`. The form has a golden for each of 40 verbs.
- The site's build checks what it built: a missing route, a dead `href`, and a link
  outside the base each fail by name. `bin/tutorials` refuses each bad input by file
  and reason, with a fixture for each. The verb's exit codes held in every case run.

## Work items

1. Run a form's verb in the workspace shown. Covers G5-1, R2-2. Size S. Depends on nothing. Before.
2. Key issue rows by repository, and dim actions on rows this checkout does not hold. Covers G2-1,
   G1-21. Size S. Depends on the bash fix of B6-5 for a reference that names the repository. Before.
3. Publish the tutorials site, or ship kit-tutorials in the kit. Covers T1-1, B8-1,
   R3-8. Size M for the plan, S for the fallback. Depends on nothing. Before.
4. Walk the form's grammar once, with a row's identity as its group's path. Covers
   G4-1, R2-1, G4-13, G4-11, G4-12, R2-27, G4-8, G4-3, G4-20, R2-53. Size M. Depends on
   nothing. Before for the bound in `choose` and the keyed choice, after for the rest.
5. Guard the empty cases that panic. Covers G6-1, R2-3, U3-1, G3-1, G6-2, G1-3,
   R2-4, G6-4, G4-15, G5-21, G3-15, R2-52. Size S. Depends on nothing. Before.
6. Give no rows for a stage that is loading or refused, and let a refused stage reload. Covers
   G1-1, G1-2, G2-3, G1-4, and the missing tests of G1-17. Size S. Depends on nothing. Before.
7. Take a paste in every control that types. Covers G4-2, G5-2, G6-3,
   G1-10, R2-8, U2-2. Size S. Depends on nothing. Before.
8. Start kit's children without a terminal, and run kit through one client call with one
   error. Covers G5-3, I4-12, G5-5, G5-9, G5-12, G5-19, G5-24, G5-14, R2-69, G1-13, R2-70.
   Size M. Depends on nothing. Before for G5-3, G5-5, and G5-12, after for the rest.
9. Ask who the caller is at the start, and again after a failure.
   Covers U1-1, G1-12, R2-68. Size S. Depends on nothing. Before.
10. Have kit print each row's page and reference, and stop building addresses in Go. Covers
    G2-2, S1-1, S3-1, R2-31, G2-11, G5-20, G6-22. Size M. Depends on a `url` in kit's issue and
    change documents, which is bash. Before, since the release names GitLab and Azure DevOps.
11. Keep Flow's state true across reloads, crumbs, and late answers. Covers G1-5, G1-6, G1-7,
    R2-33, G1-9, R2-30, R2-32, G1-16, G2-6, G1-11, G1-14, G1-15, G5-4, G5-6, R2-65, G5-8,
    R2-34. Size M. Depends on item 6. Before for G1-6, G1-7, and G5-4, after for the rest.
12. Make the presets store safe for two writers, and repair the presets' dialogs. Covers G3-2, G3-4, G3-3, G3-6,
    G3-11, G3-12, G3-13, G3-16, G3-17. Size M. Depends on nothing. Before for G3-3 and G3-6, after for the rest.
13. Correct what the grid, the table, and the tab bar draw and read. Covers G4-5, R2-21, G3-7, G3-8, R2-23, G4-4,
    G4-6, G4-7, G4-9, R2-22, G4-10, R2-24, R2-29, G5-22, G3-14, G4-18, G4-19, G4-21, G4-22, G4-24, R2-59, G4-25.
    Size M. Depends on nothing. Before for G4-5, G4-6, and G4-10, which are a line each, after for the rest.
14. Repair the welcome, workspaces, tutorials, and opener screens. Covers G6-5 to
    G6-8, G6-10 to G6-16, G6-18, G6-19, G5-10, G5-11, G5-13, G5-16, G5-17, G5-18.
    Size M. Depends on nothing. Before for G5-10, G6-5, and G6-7, after for the rest.
15. Give every tab its legend, glyph, and color from the catalog. Covers G2-4, S1-3,
    S3-5, G2-8, R2-66, G2-9, G2-10, S3-11, R2-64, R2-54. Size M. Depends on the
    architecture section's catalog work. Before if the nine apps ship in v0.1.0.
16. Take kit off the update loop, and cut the costs that grow with the rows. Covers G5-7,
    R2-35, G4-14, R2-28, S6-4, G1-8, R2-20, G3-9, S6-5. Size M. Depends on nothing. After.
17. Hold the tests to kit and to work done, not to the clock. Covers G2-5, R2-36, S4-1,
    S3-3, G3-5, G1-17, S4-3, S1-17, U7-16, G6-17, S4-7, S3-13, R2-42, G5-23. Size M. Depends
    on nothing. Before for the two clock tests and the syntax loop, after for the fixtures.
18. Give the form and the columns their clicks. Covers R2-25, U2-8, U3-5,
    R2-26, U2-17, R2-55, R2-57, R2-58, R2-60. Size M. Depends on item 4. After.
19. Correct the tutorials catalogue and the site's small faults. Covers T1-2 to T1-13, S7-16, R3-37.
    Size M. Depends on item 3 for T1-2 to matter. Before for T1-2, T1-3, and T1-4, after for the rest.
20. Clear the remaining low findings. Covers G1-18, G1-20, G2-12, G3-18, R2-56, R2-62,
    R2-63, G4-16, G4-17, G4-23, G4-26, G4-27, G5-15, G5-25, G6-20, G6-21, G6-23,
    R2-61, R2-67, R2-71, R2-72. Size M in all, S each. Depends on nothing. After.
