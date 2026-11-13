# kittui

kittui is kit's terminal UI. It is one Go binary, and kit runs it at a terminal for `kit` with no verb, `kit tui`,
`kit help`, `kit welcome`, `kit tutorials`, `kit flow`, and each app verb, such as `kit workspace`.

kittui knows nothing on its own. It runs `kit` for everything it shows, reads the JSON that kit prints, and never
parses kit's text. It holds no verb by name: the verbs, their forms, and their help come from `kit syntax` and
`kit help`.

This page is for someone who changes the Go code. For what a person sees and does, read these:

- [The terminal UI](../../README.md#the-terminal-ui) in the README shows one screen.
- The tutorials in [kit/modules/tutorials/](../../kit/modules/tutorials/) have one page for each part of the
  screen. `kit tutorials` opens them.
- [docs/apps.md](../../docs/apps.md) describes the JSON each app reads, and
  [docs/workspaces.md](../../docs/workspaces.md) describes workspaces and the workspace menu.
- [docs/kittui-needs.md](../../docs/kittui-needs.md) says what kittui needs of the terminal, the font, and the colors.

## Screens

kittui shows one screen at a time. The `=` menu, which every screen has, switches between them. `internal/screens`
makes a screen the first time it is shown, and keeps it as you left it while another screen shows.

| Screen | Opens with | Package | Shows |
| --- | --- | --- | --- |
| Welcome | `kit`, `kit welcome` | `internal/welcome` | a tab for each page under `.kit/welcome/`, with kit's checks |
| Help | `kit help` | `internal/palette` | the palette: a table of every verb but `tui` |
| A verb's form | `kit tui <verb>`, or a verb short of an argument | `internal/form` | the verb's arguments as fields |
| The nine apps | `kit flow`, or an app verb | `internal/flow` | a tab for each stage, each tab a table |
| Tutorials | `kit tutorials` | `internal/tutorials` | a card for each tutorial |
| Workspaces | Manage… in the workspace menu | `internal/workspaces` | the groups of repositories kit keeps |

Two dialogs open over a screen:

- `internal/trust` asks before kittui reads anything in a clone that kit does not trust yet. Trust runs
  `kit trust --yes` on the clone. Not now leaves it untrusted and opens the palette, which an untrusted clone allows.
- `internal/opener` is Open Repository… in the workspace menu. Type a folder, or find the clones under it.

A word after the verb opens the screen at a place:

| Command | Opens |
| --- | --- |
| `kit flow issues` | Flow, with the issues tab maximized |
| `kit flow backlog`, `kit flow underway` | Flow, with the issues tab maximized on its Backlog or Underway preset |
| `kit issues milestones` | Issues, with the milestones tab maximized |
| `kit tutorials screen` | the tutorials, with the cursor on that tutorial's card |
| `kit help commit` | the palette, on the page of `kit commit` |
| `kit tui commit` | the form of `kit commit` |

After `kit --workspace=<workspace>`, kit starts kittui with `--workspace=<workspace>` before the verb. Every screen
then opens over that workspace, and a form shows and runs its verb with the option.

What each screen does beyond the tutorials:

- Welcome. A check that failed offers its fix on the cursor's row: ⧉ or `c` copies it, and ▶️ or `r` runs it where
  kit can. The terms and customize pages are drawn as tables, from `terms.json` and `customize.json`. The setup
  step draws its folders as a table, from `folders.json`.
- Help. `→` opens a row to the verb's help page. `⏎`, or a click on the verb's name, opens the verb's form.
- A form. It builds the command line and shows it. `⏎` on the command line runs the verb. A click on the command
  line gives it the keyboard, and a second click runs it, so no single click runs a command. `esc`, or a click on
  ‹ verbs, goes back to the palette. The verb runs where the form read its choices: in the folder kittui started
  in, in the repository the workspace menu switched to, or over the group shown.
- Tutorials. A tutorial that ships with kit opens as a page in place of the cards. A tutorial online opens in the
  browser. A link on a page to a screen of kittui opens that screen, and leaves a crumb back to the page.
- Workspaces. Each action is a `kit workspaces` command that kittui runs. kittui never writes the workspaces file.

## The apps

An app is one screen, `internal/flow`, over its own tabs. Each tab is a stage of kit. `kit <verb>` opens the app on
its first tab, and `kit <verb> <tab>` opens it on that tab, maximized.

| App | Verb | Tabs |
| --- | --- | --- |
| Flow | `kit flow` | the stages the `flow` setting names: issues, changes, builds, incoming, releases |
| Issues | `kit issues` | issues, milestones, iterations |
| Changes | `kit changes` | changes, reviews, checks, merged |
| Repositories | `kit workspace` | repos, worktrees, branches, commits, tags, remotes, incoming |
| Delivery | `kit delivery` | releases, builds, artifacts, environments, deployments |
| People | `kit people` | people, teams, agents |
| Trust | `kit audit` | evidence, findings, controls, waivers, policy, enforcement |
| Platform | `kit platform` | services, toolchains, tools, settings |
| Packages | `kit packages` | packages |

Some tabs belong to two apps: the issues tab is in Flow and in Issues. `apps` in `internal/flow/apps.go` lists the
tabs of each app. A word that names a tab of kit flow opens the app that holds it: `kit issues issues` opens
Issues on its issues tab.

Over a group of repositories, each tab gathers the rows of every cloned member, and an action runs in the checkout
of each row's member. Start kittui with `kit --workspace=<group> flow`, or pick the group in the workspace menu;
see [docs/workspaces.md](../../docs/workspaces.md).

## How a screen reads kit

- Each tab reads one kit command with `--json`. The catalog, `internal/flow/fields.json`, names the command for
  each stage.
- The catalog states the contract number of the stage documents that kittui reads. A tab whose document states
  another number shows a line with both numbers in place of its rows; see [docs/apps.md](../../docs/apps.md).
- kittui starts every kit with no terminal, in a session of its own, with `GIT_TERMINAL_PROMPT=0`. A git, an ssh,
  or a kit that would ask for a password fails at once, and the screen shows its line. Nothing writes a prompt
  over the screen.
- A stage's read has two minutes, and so has an action. After that, kittui stops kit, and the screen says which
  command it was.
- Two commands keep the terminal, because the person answers them: a fix that the welcome guide runs, and the verb
  that a form runs.
- A stage whose catalog entry takes `cached` opens on the copy kit kept of its last answer, while its first read
  runs. Its tab is stale until the read lands. See `internal/flow/kept.go`.
- kittui reads the stages' marks, such as `kit flow --marks`, after a stage loads and then once a minute. A mark
  that changes makes its tab stale, which the tab shows as a yellow dot. Watch reads a stale tab again at once. A
  stage whose catalog entry says `"marked": false` offers no Watch.
- A tab whose read fails shows kit's line in place of its rows. The rows of the read before are gone until the
  tab is read again, so no key or click reaches a row behind the line.
- A tab that loads again keeps the cursor on the row it was on, wherever the new rows put that row.
- A row opens the page whose address kit printed as `url`. kittui builds no address of its own.
- A filter on a person can name the caller as `@me`. kittui asks kit for the login, with `kit flow --me`, when a
  view first holds `@me`.
- Every action runs a kit verb. kittui changes nothing itself, so a terminal, an agent over `kit serve`, and a
  menu do the same thing. An action that writes asks first, in one dialog that lists what it will change.
- Two tabs act on their rows: issues and packages. Every other tab shows its rows and opens their pages. The issues
  menu leaves out Add to Pull Request in an app with no changes tab, since there is no pull request to add to.
- A row whose link leads to a row of another tab or app, such as an issue's pull request, is followed by a click on
  the link, or by Follow Link in the row's menu.
- A tab that loads again keeps the cursor on the row it was on, wherever the new rows put that row.
- A row opens the page whose address kit printed as `url`. kittui builds no address of its own.
- A filter on a person can name the caller as `@me`. kittui asks kit for the login, with `kit flow --me`, when a
  view first holds `@me`.
- Every action runs a kit verb. kittui changes nothing itself, so a terminal, an agent over `kit serve`, and a
  menu do the same thing. An action that writes asks first, in one dialog that lists what it will change.
- Only two tabs act on their rows: issues, where Add to Pull Request is left out of an app that has no changes tab, and
  packages. Every other tab shows its rows and opens their pages. A row whose link leads to a row of another tab or
  app, such as an issue's pull request, is followed by a click on the link, or by Follow Link in the row's menu.

`internal/source` holds the two kinds of read. A load is a read that a screen shows, such as a stage. A poll is a
read that repeats, such as the marks. Every wait goes through a clock, so a test fires the timers it means to.

## The parts every screen shares

The tutorials describe each part for the person who uses it. This table says where its code is.

| Part | Code | Tutorial |
| --- | --- | --- |
| The screen, top to bottom | `internal/shell/view.go` | [screen.md](../../kit/modules/tutorials/screen.md) |
| Menu bar, kit menu, workspace menu, crumb | `internal/shell` | [menu-bar.md](../../kit/modules/tutorials/menu-bar.md) |
| Search | `internal/shell/search.go` | [search.md](../../kit/modules/tutorials/search.md) |
| Tab bar and the tab's menu | `internal/tabs` | [tab-bar.md](../../kit/modules/tutorials/tab-bar.md) |
| Control line: groups, presets, Fields | `internal/table` | [control-line.md](../../kit/modules/tutorials/control-line.md) |
| Header, rule, rows, selection | `internal/table`, `internal/grid` | [rows.md](../../kit/modules/tutorials/rows.md) |
| Status bar and notices | `internal/shell/keybar.go`, `notice.go` | [status-bar.md](../../kit/modules/tutorials/status-bar.md) |
| Legend | `internal/legend`, and each screen's `legend.go` | [legend.md](../../kit/modules/tutorials/legend.md) |

Other shared code:

- `internal/shell/layers.go`: the menus, dialogs, and cards a screen opens over itself, in one order. The topmost
  open layer takes every key and click.
- `internal/shell/dropdown.go` and `placed.go`: what every menu and every dialog shares.
- `internal/shell/settings.go`: the Settings dialog, with Auto-group, Auto-hide, and Repeated emoji.
- `internal/shell/paste.go`: a paste, which a field types where it would type a key.
- `internal/fix`: the copy and run buttons on a line that names a command.
- `internal/markdown`: a page drawn as text, with its links.

## Tables

Every table is `internal/table`'s, whatever its rows hold. The control line, the Fields dialog, a field's card, the
presets, and the outline of the rows are the same code on every screen.

- A catalog is a JSON file beside the code. It declares a table's fields and its own presets. The catalogs are
  `fields.json` for the apps, `verbs.json` for the palette, `tutorials.json`, `workspaces.json`, `clones.json` for
  Open Repository…, and the three of the welcome guide.
- A field has a stable id, a label, a type, what it can sort, group, and filter by, and its renderings in order.
  Presets and code use the id. Only the header shows the label.
- A renderer is a Go function registered by name, so a catalog stays data. `internal/table/render.go` holds the
  renderers every table shares, and a screen registers its own.
- A stage's `carries` lists the keys its rows hold that no field shows. The bats suite holds the fields and the
  carries to what kit prints; see [Contracts](../../docs/testing.md#contracts).
- The stages of `kit workspace` and of the app verbs are drawn from the catalog alone. Such a stage needs no Go of
  its own.
- A panel, in `internal/grid/panel.go`, is how a table is set now: the placement, sort, and filter of each field.
  A preset sets a panel, and a panel reads back as a preset.
- A screen that shows several tables implements `table.Host` once, for the table selected. `internal/flow` does.
  A `table.Sheet` is one whole table that hosts its own controls. The other screens use it.

A table has three kinds of preset:

| Preset | Kept in | Changes |
| --- | --- | --- |
| built in | the catalog | never |
| the person's | `presets.json` under `~/.config/kit/`, or under `XDG_CONFIG_HOME` | Save, Save As…, Rename…, Delete |
| the team's | `.kit/presets/<stage>/<slug>.json` in the clone | the same, as changes in the working tree |

- `presets.json` is at version 2. It also keeps the person's favorites, and each table as the person last left it,
  so a tab opens as it was. Where there is no `presets.json`, kittui reads an older `views.json` once and leaves
  that file as it is.
- kittui reads the team's presets only in a clone that kit trusts and that has kit installed. A person commits a
  change to them like any other change.
- A screen saves through `table.KeepPresets`. It reads the file again and applies what the screen did, so two
  kittui on one file keep each other's presets.
- The search history is `search-history.json` and the settings are `kittui.json`, both beside `presets.json`.

## Rules a change keeps

- Every action has a path of plain clicks. Some terminals, iTerm among them, keep ⌥, ⌃, and the right button for
  their own selection and menus, and others keep shift. A modified click may add a shortcut, never the only way.
- With `NO_COLOR`, what the keyboard is on is drawn in reverse video: the line in a menu or dialog, the stop in a
  control line, and the row under the cursor. `internal/screens` tells `internal/style` which colors the terminal
  draws.
- Otherwise the band under the cursor follows the terminal's background, which kittui asks for as it starts: dark grey
  on a dark one, light grey on a light one, and reverse video until the terminal answers, or where it never does.
- `esc` goes back one step and never quits. `⌃Q` quits with 0, and `⌃C` quits with 130.
- A menu line that cannot act now stays in the menu, dim.
- A screen never writes its own key hints. It gives the path from the screen to the control that has the keyboard,
  and each control on the path names the keys it answers; see `internal/shell/keybar.go`.
- A sort's mark is a small number on the rule, raised for ascending and lowered for descending. It is never a
  triangle. ▼ is the presets menu.
- Widths are terminal cells, so a two-cell glyph counts as two; see `internal/pane`.
- A paste is typed where a key would be typed. A pasted line break never counts as `⏎`.
- Every glyph a screen draws is in its legend. The glyphs of the apps come from `kit/modules/jq/glyphs.json`, which
  the help of `kit flow` and of each app verb also reads, and a test holds the two together.
- Every statement has a test; see [Testing](#testing).

## Where kit finds it

`kit tui` looks for kittui in this order:

1. In a checkout of kit, with `go` on `PATH`, it builds kittui from this directory into the cache. It builds once
   for each change to these sources or to `go`.
2. In a release, it runs the binary for this platform from `libexec/`. `bin/release` builds those for Linux and
   macOS on amd64 and arm64.
3. Otherwise, it runs a `kittui` on `PATH`.

[kit/modules/bash/tui.sh](../../kit/modules/bash/tui.sh) holds that lookup. kittui needs a terminal on stdin,
stdout, and stderr. Without one it exits 2 and names the command that prints text.

## Packages

| Package | What it is |
| --- | --- |
| `cmd/kittui/` | the binary: it picks a screen from its arguments |
| `internal/screens/` | the root: the screens, one shown at a time, the workspace, and the crumbs |
| `internal/app/` | the Help screen's model: the palette, a verb's form, and the slide between them |
| `internal/palette/` | the table of verbs that `kit help` opens |
| `internal/form/` | a verb's grammar as form fields, and the fields as a command line |
| `internal/syntax/` | the grammar that `kit syntax` prints, decoded |
| `internal/flow/` | the apps: the tab bar, the selected stage's table, the menus, and the actions |
| `internal/welcome/` | `kit welcome`: a tab for each page, its checks, and its fixes |
| `internal/tutorials/` | `kit tutorials`: the cards, and a tutorial's page |
| `internal/workspaces/` | the Workspaces screen |
| `internal/opener/` | the Open Repository… dialog |
| `internal/trust/` | the dialog that asks to trust a clone |
| `internal/table/` | what every table is made of: catalog, values, renderers, presets, controls |
| `internal/grid/` | rows laid out in columns, and a table's panel |
| `internal/tabs/` | the tab bar that the apps and the welcome guide share |
| `internal/shell/` | what every screen shares: menu bar, menus, dialogs, search, settings, status bar |
| `internal/legend/` | the legend that floats over a screen |
| `internal/fix/` | the copy and run buttons of a line that names a command |
| `internal/markdown/` | a markdown page drawn as text |
| `internal/pane/` | text fitted into a space: clipped, wrapped, padded, or scrolled |
| `internal/style/` | the look: the colors, the glyphs, reverse video under `NO_COLOR`, and the pill a label is drawn as, plain unless Rounded labels is on |
| `internal/kit/` | runs the `kit` CLI for every other package |
| `internal/source/` | a screen's reads of kit: loads, polls, and the clock they wait on |
| `internal/transcript/` | writes the command line kittui ran into the scrollback |
| `internal/testkit/` | what the tests share; only tests import it |

Each package's comment, at the top of the file named for it, describes its keys and clicks in full.

## Testing

Run these from this directory:

```sh
test -z "$(gofmt -l .)"
go vet ./...
go test ./...
```

`bin/ci` runs the same three, and then fails on any statement that no test reaches. To see what is not covered:

```sh
go test -coverprofile=cover.out ./...
go tool cover -func=cover.out | awk '$NF != "100.0%"'
```

Only the total line may print, at 100.0%.

### Golden files

A golden file is a screen as text, without its escapes, under a package's `testdata/`. Five packages have them:
flow, form, trust, tutorials, and welcome. After a change you mean to make, rewrite them:

```sh
go test ./internal/flow ./internal/form ./internal/trust ./internal/tutorials ./internal/welcome -update
```

- Name the packages. `./...` fails, because a package that does not import `internal/testkit` has no `-update`
  flag.
- Read every line of the diff. A golden that changed without your meaning it to is a bug.
- The README at the root shows `internal/flow/testdata/issues.golden`. When that file changes, copy it into the
  README's block. `tests/claims.bats` fails until you do.

### Fixtures

- `internal/syntax/testdata/<verb>.json` is a copy of what `kit syntax <verb>` prints, one file for each verb.
  `internal/form/testdata/<verb>.golden` is the form drawn from it. `tests/syntax.bats` fails when a copy is stale
  or a verb has none. `bin/contracts` at the root writes them again; see
  [Contracts](../../docs/testing.md#contracts).
- `internal/flow/testdata/<stage>.json` is what a stage prints, written by hand. The bats suite holds each to what
  kit prints.

### The fake kit

A test that runs kit runs a fake, the `testdata/fake-kit` script of its package, and never the real kit. Three
more rules keep a test from reaching outside itself:

- `testkit.Main` points `HOME` and the XDG directories at a directory of the run's own, so no test reads or writes
  what the person keeps.
- A test's clock fires a timer only when the test says so.
- The legend tests are the exception to the fake. They read the real [kit/bin/kit-flow](../../kit/bin/kit-flow)
  and the header of each app verb, so the screen and the help agree on every glyph.
