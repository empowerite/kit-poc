# The interface: how good it is, how it will be received, and what to change

This section covers what a person and an agent meet at 0e76266c: kittui's screens, the command line, the
first run, what the terminal must provide, and the words on the screen. It rests on reviews U1 to U7 and P6,
and on findings of the Go and bash areas about the same screens. Skeptics checked 17 of the 31 high
findings. Nine are confirmed, seven hold in a narrower form, one needs the network to settle, and none was
refuted. I checked the other 14 against the snapshot, and each holds. The medium and low items stand as
their reviewers reported them. A path under `projects/tui/internal/` is written from that folder, such as
`flow/flow.go:816`. Every other path is written from the repository's root.

## Is the interface good or terrible?

It is good, and a stranger will find it broken. The design is right and
should stay. The first hour is not ready for 0.1.0.

The command line is good now. Without a terminal, all 52
verbs answer `--help` from one source. A refusal is one line that
says what is wrong and names the command that fixes it. `kit work`, `kit commit`, and `kit submit` are
exact and quiet. kittui's table is the strongest part of the product. Grouping, filters, saved presets,
frozen headings, and a keys bar computed from where the keyboard is put it ahead of lazygit, k9s, and gh
dash (U1). It drew correctly at every size from 200x50 to 2x1 (U7).

The frame around the table fails a newcomer in the first ten minutes. ⏎ on a row does nothing. Nothing
on the screen says how to quit. A paste types nothing. One unshifted key assigns every selected issue.
`kit commit --help` opens a page that never loads. The welcome guide crashes on PgDn after a search that
finds nothing. On a light theme the cursor's row cannot be read. A dead key says nothing, so a newcomer
takes each of these for a defect, not for a habit to learn. The faults are small: of the first six work
items below, five take under a day each, and none changes the design.

## How will it be received?

- A first-time user at the keyboard meets four walls in one session: ⏎, quit, paste,
  and → on the tab bar. U1's reviewer got out with ⌃C.
- A first-time user with a mouse likes sorting, folding, and filtering, each one click. Then no row can be
  selected, every action is dim, and a dialog opened by a click cannot be answered by one (U2-3, U2-5).
- A person who reads the nine tutorial pages first finds the screens coherent and fast, but nothing
  points to them (U2-12, U3-7). A new contributor is productive within a day once told three things:
  ␣ before an action, ⌃Q, and ⇥ before a form's first field (U5).
- A senior engineer trusts the README because it says what kit does not enforce, and pilots
  the rules, not the workflow. The first objection is what kit adds to AGENTS.md,
  pre-commit, and one required check, and no page answers it (U5-17).
- A platform engineer runs kit in two repositories behind a check that is not required, then asks for a way to
  update a fleet and a way to switch `kit linked` off (U5-13, U5-16).
- A person on a light theme, without a Nerd Font, or on Linux or Windows sees an unreadable cursor row, boxes
  around every label, and names of keys the keyboard lacks. No page states what kittui needs (U7-1, U7-3, U7-7).
- An agent starts, commits, and submits, and can act on every refusal. But kit starts it at
  the desk, where the lint tool says "nothing to lint" and the hook names the wrong rules,
  and the workflow demands a report that no verb writes (U6).
- Beside gh dash and lazygit, kittui shows rows and never an issue's text, a diff, or a check's log (U5-15). What
  it alone has is one row for the issue, its pull request, its checks, and its worktree, on three forges.

## What to change, ranked by help to a first-time user

Twelve changes, in the order a first-time user feels them: an install line that works, ⏎ and the cursor's
row, quit on the screen, a question before a write to the forge, paste, `--help`, a form's first field, the
welcome guide, the terminal, the read verbs, keys from the rows, and the reason a pull request is blocked.
The work items at the end of this section keep that order and those numbers. Items 13 to 19 serve the mouse,
the second day, the agent, and the team that decides whether to adopt kit.

## Actions that are not obvious

The table lists what a person cannot learn from the screen. It is built from U2's inventory
of 86 actions and from the runs of U1, U3, U4, U5, and U7.

| Action | How it is done at this commit | Where the screen names it | Findings |
| --- | --- | --- | --- |
| Quit | ⌃Q; `q` and esc do nothing | the last line of the `=` menu | U1-4, U2-12, U5-11 |
| Act on one row | ␣ to select it, then the action's key; without ␣ the key does nothing and says nothing | nowhere | U1-3, U2-4, U5-5 |
| Open a row's page in the browser | ␣ then `o`, or a click on its glyph; ⏎ does nothing | the last line of the tab menu | U2-4, U7-6 |
| Follow a link to another tab or app | a click only; the link is drawn as plain text | the legend's †, which the legend does not explain | U1-6, U1-9 |
| Select a row with the mouse | cannot be done in the nine apps | nowhere | U2-3 |
| Answer an action's dialog with the mouse | cannot be done; esc or ⏎ only | the keys bar; nowhere with key hints off | U2-5 |
| Open Fields | `f`, only while the keyboard is on the preset pill | the keys bar, only there | U1-5, U2-6 |
| Sort by a column | Fields, ↓ to the column, `s`; or a click on the `·` under its name | the legend | U2-6, U5-21 |
| Clear a search | ⌃U while the search has the keyboard; esc keeps it | the keys bar, once something is typed | U1-7 |
| Refresh one tab | `r`, or a click on the yellow `•` | the tab menu draws `R`, and a typed `R` does nothing | U2-7 |
| Move along the tabs | ⇥, ⇧⇥, or a digit; ← and → do nothing | the keys bar, which reads "⇥·⇧⇥ tab" | U1-13, U2-11 |
| See what the keys do | no screen lists them; `?` explains glyphs, in the nine apps only | nine tutorial pages under `=` | U2-12, U5-10 |
| Paste | cannot be done | nowhere | U2-2 |
| Type into a form's first field | ⇥, then ␣ or ⏎, then type | the keys bar says "␣ choose", which does nothing there | U3-2, U5-3 |
| Copy from kittui inside tmux | `set -g set-clipboard on` first; the notice says "copied" either way | nowhere | U7-9 |
| Read a verb's help on a terminal | `kit help --text commit`; `kit commit --help` opens a page that never loads | nowhere | U4-1 |
| List the issues from a shell | `kit flow issues`; `kit issues` prints milestones and iterations | the refusal of `kit issues issues` | U4-3, P6-6 |
| Pipe or page the picture | `kit flow --json`; `--text` goes to stderr | nowhere | U4-4 |
| Run a tool with `--check` or `--json` | `kit tools run -- prettier --check .` | not in `kit help tools` | U4-5 |
| Give an option its value | `--owner=bob`; `--owner bob` is refused as "needs a value" for 32 options and taken for 9 | the usage line | U4-6, P6-3, S8-1 |
| Write the report in the pull request | the forge's own tool or page; no verb sets the body | nowhere | U6-5, U4-9 |
| Find the pull request's address | `kit work` and `kit submit` do not print it | only when `kit ready` fails | U4-9 |
| Release what was merged | `git pull` at the desk first; `kit release` tags the desk's commit | nowhere | U4-2 |

## Tasks that take more steps than expected

| Task | Keyboard | Mouse | For comparison | Findings |
| --- | --- | --- | --- | --- |
| Start work on one issue from Flow | 12 to 14 keys | cannot select the row | 12 keys for `kit work 46` in a shell; one key in lazygit, k9s, or gh dash | U1-3, U5-5 |
| Go from the welcome guide to a running `kit work 7`, through the palette and the form | 34 keys | no click opens a form | 11 keys in a shell | U3-6 |
| Type a commit message in the commit form | ⇥ ⏎, the text, ⏎ four times | cannot be done | type it | U5-3 |
| Open the issue under the cursor in the browser | 2 (␣ `o`) | 1, on a two-cell glyph | 1 (⏎) | U2-4 |
| Sort the issues by age | 13 to 19 | 1, on a one-cell dot | one key in k9s | U2-6, U5-21, U7-6 |
| Open Fields | 6 from the tab bar, 7 from a row | 1 | one key | U1-5 |
| Close one issue as not planned | 6 | cannot be done | two keys and a yes | U2-5 |
| Learn why a pull request is blocked | 3 keys and the login, then 3 more for the failing check | the same | the check's name shows only at 200 columns | U1-2 |
| Clear a search | 3 (`/` ⌃U ⏎); esc three times does nothing | cannot be done | esc | U1-7 |
| Read one glossary term | 5 keys; 44 presses of → for them all | a click on each ▸ | a page | U3-13, U5-20 |
| Quit without knowing ⌃Q | 3 (`=` `q` ⏎) | 2 | `q` | U2-12 |
| Do a day's work, from an issue to a release | 11 to 12 kit commands and 4 to 5 steps outside kit | not applicable | 12 to 14 with git and gh; 4 to 5 with Graphite | U4-23 |
| An agent's first task | 13 tool calls, about 18 in practice, after 8,500 tokens of reading | not applicable | 41% of the reading is needed | U6 |

The counts of a sort differ because each reviewer's table had another number of
groups and fields: 13 (U5), 15 (U7), and 17 to 19 (U2).

## High items

Items 1 to 12 are kittui, 13 to 15 the terminal, 16 to 20 the command line, 21
to 23 the first impression, and 24 to 28 the agent.

1. The welcome guide crashes on PgDn, PgUp, Home, or End after a search that finds no check (U3-1, G6-1, R2-3).
   `page` indexes `rows[len(rows)-1]` unguarded (`welcome/welcome.go:961`). Return when there are no rows, and add
   the test. The kittui section holds five more crashes from keys or clicks (G1-1, G1-3, G3-1, G4-1, G6-2).
2. Three actions write with no question (U2-1, U7-4). Assign to Me, on `a`, assigns the whole selection
   (`flow/act.go:295`). Start Local Work for Each makes a branch, a worktree, and a draft pull request per issue
   (`flow/act.go:275`). Add on Packages runs at once (`flow/packages.go:135`). Give each the dialog Unassign has.
3. ⏎ on a row does nothing, and an action ignores the row under the cursor (U1-3, U2-4, U5-5,
   U7-6). `key` has no case for enter (`flow/flow.go:816`), and `acting` disables every action
   while nothing is selected (`flow/act.go:201`). In that case act on the cursor's row. The
   reviewers split on ⏎: a menu of the row's actions (U1), its page (U2, U7), or a detail pane
   (U5). Take the menu, Open Page first: it works in all nine apps.
4. A row cannot be selected with the mouse in the nine apps (U2-3). Only `table/sheet.go:724`
   calls `table.BoxAt`, and Flow's click handler does not (`flow/flow.go:1283`). Call it
   there, and draw a dim ☐ in the gutter of the cursor's row.
5. Nothing on the screen says how to leave (U1-4, U2-12, U5-11, U7-6). `ScreenKeys` names `=` and `/`
   (`shell/keybar.go:247`), and quit is ⌃Q on the last line of the `=` menu (`shell/shell.go:168`). Add "⌃Q quit"
   to the screen's segment, which the form already shows, and answer `q` with a hint for five seconds.
6. A paste types nothing (U2-2, G1-10, G4-2, G5-2, G6-3, R2-8). No code handles `tea.PasteMsg`, so a commit
   message, a login, or a git URL cannot be pasted (`shell/search.go:69`, `form/model.go:130`, `flow/act.go:461`).
   Have `shell.Type` take a paste as typed text. Known since 11-10.
7. A form's first row ignores typing, ␣, and ⏎ until ⇥ is pressed (U3-2, U5-3). On a one-of row `enter` sets the
   cursor to `f.Chosen`, which is -1 (`form/model.go:372`), and the forms of `kit work` and `kit commit` open on
   such a row. Start the cursor on the first option, and let a typed character choose an option that takes text.
8. A form takes no click, and no click opens one from the palette (U3-5, U2-8, R2-25). `form.click` handles the
   menu bar alone (`form/model.go:174`), and the palette opens a form on ⏎ alone (`palette/palette.go:496`),
   against `kit/modules/tutorials/screen.md:41`. Let each field, `‹ verbs`, and a verb's name take a click.
9. `kit commit --help` on a terminal opens a palette whose page never loads (U4-1, R2-17). `screens.New` drops the
   command that fetches the page (`screens/screens.go:76`), and `kit/modules/bash/1st.sh:711` hands `--help` to
   `kit-help` with no `--text`. Print the page for `--help` and `-h`, which is what git and gh do.
10. The checks of the toolchains and setup steps sit under 464 and 260 words of prose (U3-3, U5-7). `stepHead`
    draws the whole page first (`welcome/view.go:334`), so at 80x24 the first check is 42 lines down. The goldens
    draw a three-line fixture page. Draw the checks first, and add goldens over the shipped pages.
11. A preset that filters by @me opens an empty table (U1-1). kittui asks for the caller's login when a card, a
    chip, or the issues tab menu opens (`flow/flow.go:740`), never in `Init` (`flow/flow.go:328`). Ask `kit flow
    --me` in `Init`, and draw "loading" until it answers.
12. Changes does not say why a pull request is blocked (U1-2, U7-5). At 80 and 120 columns its state and checks
    are lone glyphs (`flow/testdata/changes.golden:11`) that the Issues legend omits (`flow/legend.go:156`). Add a
    line for each blocker to the open row (`flow/rows.go:602`).
13. The cursor's row is unreadable on a light theme (U7-1). The band is 256-color 236 whatever the background is
    (`style/style.go:44`): black text on it has a contrast of 1.59:1, and on Nord the band is 1.06:1 from the
    background. Ask the terminal for its background, keep two palettes, and mark the cursor's row in the gutter.
14. Under NO_COLOR the focus cannot be seen in a menu, a dialog, or the control line (U7-2). `style.Selected` is
    two colors and nothing else (`style/style.go:46`), though `projects/tui/README.md:309` says the style honors
    NO_COLOR. Draw it in reverse video where the terminal has no color, and add a golden.
15. Every label and the preset selector need a Nerd Font (U7-3, U5-8). A pill's ends are U+E0B6 and U+E0B4
    (`style/pill.go:19`), and the second replaces the `=`, so without color `priority=high` reads "priorityhigh".
    Draw a pill as a padded block without caps, keep the `=`, and name the font in `docs/terminals.md`, whose line
    23 says a font is not a finding. What a terminal draws for the missing glyph is plausible, not seen.
16. `kit issues` does not list issues (U4-3, P6-6). It prints milestones and iterations (`kit/bin/kit-issues:2`),
    and `kit issues issues --text` is refused with a remedy that names `--json` (`kit/modules/bash/apps.sh:63`).
    `kit changes` and `kit delivery` omit their first tabs too. Let each print that tab first.
17. `kit flow --text` prints the picture on stderr (U4-4). `flow:heading` and `flow:none` write
    with `>&2` (`kit/modules/bash/flow.sh:218-229`), so `kit flow --text | less` shows nothing.
    Print the stages on stdout, and keep stderr for warnings.
18. `kit tools run` refuses a command that holds one of its own flags (U4-5, B1-3, B7-3, R2-5, R3-4). The skeptic
    narrowed it: `kit tools run prettier --check .` is refused (`kit/modules/jq/syntax.jq:74-81`), and the same
    line after `--` works, which `kit help tools` does not say (`kit/bin/kit-tools:6`). Mend the matcher.
19. The help of the picture verbs is a reference manual (P6-1, U4-13, P5-1). `kit help flow` prints 345 lines, and
    its options start near line 270 (`kit/bin/kit-flow:21-268`). The prose section's work item 2 covers the cut.
20. `kit release` tags a desk that is behind its remote, without a word (U4-2). The skeptic narrowed it: the check
    is the documented rule, and the step line names the commit. Missing are a notice that HEAD is behind the
    default branch's tip (`kit/modules/bash/releases.sh:58-70`) and a `--dry-run`. A slip spends the version.
21. The Homebrew line the README leads with may install nothing (U3-4, U5-4, D1-2, R3-6). Plausible: nothing in
    the tree writes the formula behind `README.md:78` or deploys the tutorials site (B8-1, T1-1, R3-8). Publish
    both before the tag, or lead with `gh release download`.
22. `kit install` ends "Every agent reads .kit/1st.md first." when no agent is sent there (U5-1). The skeptic
    narrowed it: the bare default is documented, and the closing line is the defect
    (`kit/modules/bash/release.sh:149`). Name `kit packages add agents/claude` there instead.
23. The README never says what kittui is and shows no screen (U5-2). It names kittui on lines 92, 253,
    and 327 alone, and `README.md:198-336` is for kit's maintainers. Open with a screenshot of Flow and
    one of a refusal. The prose section's work item 3 covers the text.
24. The workflow requires a report in the pull request's body, and no verb writes one (U6-5, U4-9).
    `forge:pr-set-body` has one caller (`kit/modules/bash/issue.sh:561`), `kit ready` takes only a number
    (`kit/bin/kit-ready:4`), and no verb prints the pull request's address. Add `kit ready --report-file=`.
25. The MCP lint tool answers for the desk (U6-1). The skeptic narrowed it: with no path, `lint` reads the root
    checkout (`kit/modules/bash/serve.sh:606`) and says "nothing to lint" while a bad file is staged in a
    worktree. A path under the worktree works. Give lint, check, context, and settle a worktree property.
26. A worktree's file is classified from the desk's root (U6-2). `context:relative` strips only the current root
    (`kit/modules/bash/context.sh:72`), so from the desk a workflow file under `worktrees/` misses the workflow
    and bash rules, in the CLI, the hook, and the MCP tool. Find the root from the path itself.
27. `kit work` moves the human's uncommitted desk work into the agent's worktree (U6-3). The skeptic narrowed it:
    `kit help work` states the sweep, and no work is lost. `kit/packages/kit/files/repo/.kit/1st.md:27` says an
    agent never changes the desk. Make `--no-sweep` the tool's default (`kit/modules/bash/serve.sh:100`).
28. An untrusted clone hands an agent the command that trusts it (U6-4). Plausible, and lower than high. Without a
    terminal, `kit trust` prints the `kit trust --yes` line (`kit/bin/kit-trust:116`), and no rule says the
    decision is a person's. Say so in the AGENTS.md region, and deny `kit trust` to agents.

## Medium items

- Keys in kittui (U1-5, U1-6, U1-7, U2-6, U2-7, U2-9, U2-10, U2-11, U2-13, U7-7). `f` opens Fields only on
  the preset pill, and no key sorts or drops the presets from the rows (`table/keys.go:236`). Only a click
  follows a link (`flow/flow.go:1294`). esc keeps a search (`flow/flow.go:821`). A menu draws `R` and takes
  `r` alone (`shell/shell.go:328`). In a form ↓ skips the options under the cursor (`form/model.go:406`).
  `r` has five meanings (`welcome/menu.go:22`), and ← and → do nothing on the tab bar (`tabs/tabs.go:108`).
  At 80 columns the keys bar clips the keys that act (`shell/keybar.go:110`), and it names them in macOS
  glyphs everywhere (`table/keys.go:46`). Fixes: work items 7, 9, and 11.
- Dialogs and presets (U2-5, U2-14, G3-13). The ask layer has no `Click` (`flow/layers.go:20`), so a dialog
  takes esc or ⏎ alone, where the workspaces prompt gives a line to click for each answer
  (`workspaces/prompt.go:125`). `d` deletes a preset at once, and Save As… replaces a preset of the same
  name (`flow/views.go:363`, `table/views.go:216`). Fix: work item 13.
- What the tables show (U1-8, U1-9, U1-10, U1-11, U1-12, U5-10, U5-15, U7-10, G2-8, P6-4). At 80x24 twelve lines
  of chrome stand above the first row (`flow/view.go:31`). The legend omits glyphs its tab draws, explains neither
  🔗 nor †, and takes PgUp and PgDn from the rows (`flow/legend.go:153`, `flow/legend.go:46`). The title bar reads
  "kit trust" and "kit repositories", which are not the apps' verbs (`flow/view.go:27`). Seven of the nine apps
  have no action (`flow/act.go:43`), and no screen shows an issue's text, a diff, or a check's log
  (`table/keys.go:66`). The controls fixture holds `source` where kit prints `kind`
  (`flow/testdata/audit-controls.json:1`). Fixes: work items 12 and 19.
- The welcome guide and the palette (U3-6 to U3-15, U5-6, U5-12). A search for "work" keeps all 20 workflow verbs,
  with `kit work` 18th (`palette/palette.go:355`). No page says what to do next (`kit/bin/kit-welcome:2`), and
  outside a repository the guide does not say so (`welcome/view.go:243`). A folder with no `kit.yml` shows its kit
  as "no…" (`welcome/setup.go:104`). A missing linter fails a repository that has no file it lints
  (`kit/modules/bash/welcome.sh:426`). A check's sentence is clipped (`welcome/view.go:388`), and a form's refusal
  goes stale (`form/model.go:745`). Terms and Customize are tables that cut every meaning short
  (`welcome/sections.go:181`, `welcome/customize.go:90`). The goldens draw fixture pages
  (`welcome/testdata/setup.golden:7`), and `kit help welcome` describes buttons that are gone
  (`kit/bin/kit-welcome:13`). The first page says kit works with Jira and Linear, whose pages kit can only open
  (`kit/packages/kit/files/repo/.kit/welcome/1-introduction.md:13`). Fixes: work items 7 and 8.
- The command line (U4-6, U4-7, U4-8, U4-10, U4-11, U4-12, U4-14, U4-15, U4-23). `--owner bob` is refused as
  "needs a value" (`kit/modules/jq/syntax.jq:166-168`). Every remedy starts `cd <folder> &&`, even before `kit
  help` (`kit/modules/bash/1st.sh:521-533`). `kit submit` refuses in the words of `kit commit`
  (`kit/modules/bash/commit.sh:72`). `kit status`, `kit push`, and `kit init` get no pointer to kit's word
  (`kit/modules/bash/1st.sh:662-691`). `kit help` lists 20 workflow verbs by alphabet
  (`kit/modules/bash/help.sh:325-341`). `kit install` outside a repository writes `kit.yml` there
  (`kit/bin/kit-install:26-66`). A text table pads every row to its widest cell, 2,475 columns at worst
  (`kit/modules/jq/apps.jq:189-198`). git's own errors print where there is no remote
  (`kit/modules/bash/releases.sh:54`). No output names the next step (`kit/modules/bash/issue.sh:652-654`). Fixes:
  work items 10, 14, 15, and 17. The prose section covers P6-2, P6-3, P6-5, and P6-7 to P6-10.
- Terminals (U5-9, U7-8, U7-9). kittui has no mode without emoji and reads no probe: bash alone reads
  `KIT_TERMINAL_PROBES`, against `docs/terminals.md:34`. The width probe prints 📚 while kittui draws
  the newer 🟢 and ▶️ (`kit/modules/bash/terminal.sh:264`). Copy Links says "copied" where tmux
  discards the request (`flow/act.go:311`). Fixes: work items 9 and 19.
- Adoption (U5-13, U5-14, U5-16, U5-17, U5-18, U6-12). `kit ci` always runs `kit linked`, so the delivered job
  demands an issue for every pull request (`kit/bin/kit-ci:33`). Plausible: nothing opens the pull request that
  moves a repository to the next release (`README.md:180`). No page places kit beside gh, lazygit, mise,
  pre-commit, or Renovate (`README.md:15`). Half of the file every agent reads first is about packaging
  (`kit/packages/kit/files/repo/.kit/1st.md:116`). Fixes: work items 16 and 19.
- The agent (U6-6 to U6-11, U6-13). `kit commit -m` is refused without naming `--message`
  (`kit/modules/jq/syntax.jq:227`). The deny lists stop `git checkout -b` and not `gh pr merge` or `kit trust`
  (`kit/packages/agents/claude/files/repo/.claude/settings.json:3`). The tool list costs about 4,100 tokens
  (`kit/modules/bash/serve.sh:81`). The Cursor and Copilot mirrors say less than `1st.md`
  (`kit/packages/agents/cursor/files/repo/.cursor/rules/kit-bash.mdc:6`). Step 2 of the workflow says to run `kit
  work`, and contract item 3 says never to (`kit/packages/workflow/files/repo/.kit/workflow.md:11`). Plausible: a
  hosted agent is pointed at `.kit/` files that git ignores (`docs/packages/agents/copilot.md:14`), and the Claude
  hook fails open and silent (`kit/modules/bash/context.sh:522`). Fixes: work items 14 and 18.

## Low items

There are 46 low findings. Three pairs report one thing.

- Flow (U1-13 to U1-16, U2-15 to U2-19, U7-15): ⇥ means five things; Fields dialog surprises; a hidden fifth tab
  with no ▹; Flow's README is nested prose; esc in the rows resets the cursor; the palette does not filter on
  typing; no click moves a column; small disagreements on screen; the README calls the tutorials tabbed.
- First run (U3-16 to U3-21, U5-19, P6-17): two setup columns headed "kit"; the README names `gh pr ready` where
  `kit ready` exists; a tutorial's link has no key; `kit help` never points at the welcome; `kit welcome` without
  a terminal prints 479 lines; three sentences say what kit is.
- Command line (U4-16 to U4-22): `kit new issue --list` prints a refusal as a row; no short flag and no nearest
  flag; a first run and a passing commit say too much; bare `kit` always opens the introduction;
  `docs/features.md` omits `kit ready`; small disagreements in kit's words; completion is zsh alone.
- Reception (U5-20 to U5-25): the glossary lacks ten words the screens use; a sort takes
  thirteen keys; small things a first look meets; the README disagrees with itself twice;
  chained clauses in the reference pages; circled tab digits (plausible).
- Agent (U6-14 to U6-16): resource descriptions lose the kind on macOS; tool descriptions promise what
  the tool refuses; this repository's own agent files are stale.
- Terminals (U7-11 to U7-14, U7-16, U7-17): the legend takes the paging keys; marks no
  monospaced font holds; the welcome fails a stock terminal for ⌥; ▼ means two things; a
  wall-clock test fails under load; two prose slips and color 0.
- Words (P6-11 to P6-16): six tab titles; the agents tab says "how often"; eight contorted kittui strings; a
  tutorial says dim for bold; `cd` before every remedy; nine purpose lines past 80 columns.

## What is done well and should stay

- The keys bar is computed from where the keyboard is (`shell/keybar.go`), and every key it named
  worked. Add to it; do not replace it with a static help page.
- One table serves the nine apps, the palette, the welcome, the tutorials, and the workspaces screen, with one
  control line, Fields dialog, set of presets, and search.
- esc never quits. The trust question comes
  first, and a check's fix is shown whole before `r` runs it.
- One source, the verb's header, feeds the help page, the form, completion, the argument check,
  and the MCP tool. It needs less text, not a second source.
- A refusal is one line: what is wrong, the command to run, exit 2 for usage and 1 for a refusal.
- `kit work` gives a worktree, a branch, a start commit, a draft pull request, and the
  `cd` to paste, in seven lines. No compared tool does this.
- The layout held at every size and across a live resize. Selection, folds, and
  staleness each have a glyph, not a color alone.

## Work items

Items 1 to 12 are in ranked order. Each item gives the findings it covers, its size (S under a day, M a few days, L a
week or more), what it depends on, and whether it comes before the first release.

1. Make the install line true: publish the formula and the site, or lead with the download lines. Covers U3-4,
   U5-4, D1-2, R3-6, B8-1, T1-1, R3-8. S. Depends on the digest fix and the Homebrew decision. Before.
2. ⏎ opens a row's menu, an action falls back to the cursor's row, and a click on the gutter selects.
   Covers U1-3, U2-3, U2-4, U5-5, U7-6. M. No dependency. Before.
3. Quit and the keys' help on the screen: "⌃Q quit" on the keys bar, an answer to `q`, `?` on every screen, and a
   legend footer that points to the tutorials. Covers U1-4, U2-12, U5-11. S. No dependency. Before.
4. Ask before a write to the forge. Covers U2-1, U7-4. S. No dependency. Before.
5. Take a paste in every field that types. Covers U2-2, G1-10, G4-2, G5-2, G6-3, R2-8. S. No dependency. Before.
6. `--help` and `-h` print the page. Covers U4-1, R2-17. S. No dependency. Before.
7. The form and the palette: the first row types, a field takes a click, and a search ranks the verb's name first.
   Covers U3-2, U5-3, U3-5, U2-8, U2-9, U2-16, U3-6, U3-12, R2-25. M. Depends on G4-1. Before.
8. The welcome guide: guard `page`, draw the checks first, add a page for the first change, and draw goldens over
   the shipped pages. Covers U3-1, G6-1, R2-3, U3-3, U5-7, U3-7 to U3-11, U3-14, U3-15, U5-12, and, as pages in
   place of tables, U3-13, U5-6, U5-20. M. No dependency. Before, except the last three.
9. The terminal: two palettes and a gutter mark, reverse video under NO_COLOR, pills without caps, plain key
   names off macOS, and a page that states what kittui needs. Covers U7-1, U7-2, U7-3, U5-8, U7-7, U7-9,
   U7-12, U7-13, U7-17. M. No dependency. Before for the first four.
10. The read verbs print their first tabs, `kit flow --text` prints on stdout, and a text cell is
    capped. Covers U4-3, P6-6, U4-4, U4-14. M. No dependency. Before.
11. Keys from the rows: `f`, `p`, and `s`, ← and → on the tab bar, esc clears a search, a capital works, one
    letter keeps one meaning, and a key follows a link. Covers U1-5, U1-6, U1-7, U1-13, U2-6, U2-7, U2-10, U2-11,
    U2-13, U2-15, U3-18, U5-21. M. Depends on 2. Before for `f`, the arrows, the capital, and esc.
12. Flow says what it holds: the @me login in `Init`, a line for each blocker, the legend's states and
    link marks, the app's verb in the title, and a fixture from kit. Covers U1-1, U1-2, U7-5, U1-9,
    U1-10, U1-12, U5-10, U7-11, G2-8, P6-4. M. No dependency. Before.
13. Dialogs take a click, and a deleted preset can be brought back. Covers U2-5, U2-14, G3-13. M. No dependency.
    Before for the click, which the project's own rule requires.
14. Refusals and the grammar: `kit tools run`, an option's value, other tools' words, `-m`, and `kit install`.
    Covers U4-5, B1-3, B7-3, R2-5, R3-4, U4-6, P6-3, S8-1, U4-7, P6-15, U4-8, U4-10, U4-12, U4-15, U4-17, U4-22,
    U6-6. M. Depends on the prose section's item 9. Before for the first two, `-m`, and `kit install`.
15. The workflow verbs print the address and the next step, `kit ready` takes a report, and `kit release` warns.
    Covers U4-2, U4-9, U4-18, U4-19, U4-23, U6-5. M. No dependency. Before for the report and the notice.
16. The README shows kittui, and `kit install` ends on a true line. Covers U5-1, U5-2, U5-17, U5-18, U5-19, U5-23,
    U3-17, U3-21, P6-17. S. Depends on the prose section's item 3. Before.
17. Help pages: cut the picture verbs' pages, list the workflow verbs in the day's order, and point `kit help` at
    the welcome. Covers P6-1, P6-16, U4-11, U4-13, U3-19, U3-20. M. Depends on the prose section's item 2. Before.
18. The agent at the desk: classify a path from its own checkout, a worktree property on the tools, `--no-sweep`,
    the trust rule, the deny lists, a smaller tool list, and one-sentence mirrors. Covers U6-1 to U6-4, U6-7 to
    U6-11, U6-13 to U6-16. M. No dependency. Before for U6-1 to U6-4 and U6-7.
19. Later work: short screens (U1-8, U1-15, U5-22, U7-10, U7-15), a detail pane and actions on Changes (U1-11,
    U5-15), a mode without emoji that reads the probes (U5-9, U7-8), a `checks:` setting and a fleet update
    (U5-13, U5-16), a shorter `1st.md` (U5-14, U6-12), and the small items U1-14, U1-16, U2-17 to U2-19, U3-16,
    U4-16, U4-20, U4-21, U5-24, U5-25, U7-14, U7-16, and P6-11 to P6-14. L. Depends on 2 and 12. After.
