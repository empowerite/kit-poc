# Inconsistencies, and documents that disagree with the code

This section covers 250 findings: the 49 of S8, D1, and D2, and every finding of kind inconsistency or
docs-accuracy in the other areas. Before merging they are 10 high, 92 medium, and 148 low. Skeptics checked
the ten high ones: two were confirmed, seven were narrowed, one could not be settled without the network, and
none was refuted. I checked the option counts, the stage orders, the stderr claim, the `--help` hand-off, and
the sibling refusals against the snapshot. The medium and low items are as their reviewers reported them.

## The answer

kit agrees with itself wherever one source drives a fact. The verb header drives help, usage, the argument guard,
kittui's form, and completion, so, without a terminal, all 52 verbs
answer `--help` with 0 and an unknown flag with 2 in one wording.
It disagrees with itself wherever a fact is typed twice: an option's spelling, the app catalogue, the glyphs
outside `glyphs.json`, the provider lists, the refusal for one condition, and the word for a pull request.

The documents are mostly right. D1 and D2 checked about 1,007 claims and 922 held: `README.md` 84 of 96,
`docs/architecture.md` 62 of 74, `docs/features.md` 95 of 108, `docs/modules.md` 62 of 68, and the 32 feature
documents about 428 of 459. Six pages held completely, `docs/serve.md` and `docs/terminals.md` among them. Of
211 relative links, 208 resolve in the commit. Of 261 commands the documents show, the verbs' grammar accepts
258. The wrong claims are where the code moved after the page was written: `kit ready`, the trust gate, the
Azure DevOps provider, the kit toolchain, the `sh` kind, and kittui's screens. Several are promises a newcomer
acts on in the first hour, and those come first.

## High

1. An option's value is written two ways, and the two are not accepted alike (S8-1, U4-6, P6-3, B1-10, R2-48,
   B8-15, B7-24, R2-72). Ten usage lines in eight verbs write nine options with the value as the next word,
   such as `--message <text>` (`kit/bin/kit-commit:5`, `kit-work:6-7`, `kit-tools:5-6`, `kit-welcome:7`).
   About 30 options are written `--name=<value>`, and they refuse the next word with "--owner needs a value"
   (`kit/modules/jq/syntax.jq:166-168`). The skeptic narrowed one point: `kit workspaces` does take the next
   word (`kit/bin/kit-workspaces:91-113`). Write the ten lines with `=`, have `kit syntax --check` refuse the
   spaced form, and make the refusal say "write --owner=bob". This is issue #160.
2. `kit flow --text` writes the picture on stderr, and a stage refuses `--text` (U4-4, D1-7, R1-43,
   R3-19). `flow:heading` and `flow:none` print with `>&2` (`kit/modules/bash/flow.sh:218-229`), so `kit
   flow --text 2>/dev/null` prints nothing and exits 0. `kit flow desk --text` exits 2
   (`kit/bin/kit-flow:18-33`), and `README.md:241`, `docs/architecture.md:147`, and `docs/features.md:116`
   say a stage prints. Print on stdout, as every app verb does, and accept `--text` on a stage line.
3. `kit <verb> --help` on a terminal opens the palette, and the header says it prints (R2-17, U4-1). The
   guard runs `kit-help` with no `--text` (`kit/modules/bash/1st.sh:711`), against `kit/bin/kit-help:9`.
   U4-1, confirmed, adds that the palette's page then never loads. Pass `--text`.
4. With the kit package removed, `kit context`, `kit kinds`, and `kit lint` fail, and the README says they
   work (D1-1, narrowed). `README.md:98` and `:155` and `docs/features.md:292` say the removal is
   supported. After `kit packages remove kit`, each exits 1 with "no kind is defined under .kit/kinds",
   before and after `kit hydrate` (`kit/modules/bash/context.sh:164`). Raise that error only when an
   active package delivers a kinds file, and test a rule lookup after the removal.
5. The first install line has nothing behind it in the tree (D1-2, R3-6, U3-4, U5-4; plausible). `README.md:78`
   and `docs/install.md:22` lead with `brew install empowerite/tap/kit`, and `bin/release` and the workflows hold
   no formula and no tap step. That is by plan: `docs/superpowers/plans/2026-11-10-release-readiness.md:341` puts
   the formula in the tap's repository after the tag, and its box is open. No reviewer could ask the tap, so ask
   it before the tag, and lead with the `gh release download` path until it answers.
6. The welcome page promises Jira and Linear (I5-1, U5-12, narrowed).
   `kit/packages/kit/files/repo/.kit/welcome/1-introduction.md:13` lists trackers "such as Jira and Linear", and
   the only code for them is the `web` provider, which refuses every read
   (`kit/modules/bash/tracker/web.sh:17-56`). A change that links only such an issue fails `kit linked`, whose
   remedy says to run it again "once the tracker answers" (`kit/bin/kit-linked:131`). Say on the welcome page
   what `docs/trackers.md:78-81` says, that kit links to those pages and cannot read them, and reword the remedy.
7. A verb's form takes no click, and the tutorial says every action does (U3-5, U2-8, R2-25, R3-25).
   `form.click` answers on the menu bar only (`projects/tui/internal/form/model.go:172-194`), and no click
   in the palette opens a form (`projects/tui/internal/palette/palette.go:496`).
   `kit/modules/tutorials/screen.md:41` says "Every action also works with a plain click." Give each
   field, `‹ verbs`, and the command line a click, and let a click on a verb's name open its form.
8. `kit work` moves the desk's uncommitted work into the new worktree, and what an agent reads says the
   desk is never changed (U6-3, B7-15, narrowed). `kit/modules/bash/issue.sh:622` sweeps it, and
   `kit/packages/kit/files/repo/.kit/1st.md:27` says the desk is the human's. The MCP `work` tool is
   annotated `idempotentHint` true, though `--title` creates an issue on every call
   (`kit/modules/bash/serve.sh:100`, `docs/serve.md:55-57`). No work is lost and `kit help work` states
   the sweep. State it in `1st.md` and `docs/serve.md` too, and set the hint false.
9. The checks tables credit `kit ci` with what `kit lint` does (R3-7, D1-6, R3-20; the skeptic lowered it
   to medium). `kit ci` runs `linked policy gate check` (`kit/bin/kit-ci:33`), and `docs/features.md:44`
   lists the linters, the `pinned` check, and the templates under its four checks.
   `docs/architecture.md:242` says the gate ran with the pinned tools in CI, and the delivered default is
   `ci_toolchain: ambient` (`kit/packages/github/ci/package.yml:11`). Say in both tables where `kit lint`
   runs, qualify that row, and list all four gaps at `docs/features.md:356`.

## Medium: the command line against itself

- One condition gets three answers (S8-9, B2-17, P6-9). With no change named, `kit settle` says "no pull
  request is named" and exits 2 (`kit/bin/kit-settle:39`), and `kit ready` and `kit linked` say "name the
  change" and exit 1 (`kit/bin/kit-ready:37`, `kit/bin/kit-linked:59`). An unknown name exits 1 in `kit
  toolchains use` and 2 elsewhere, in five wordings. Add `guard:number` and `guard:unknown` to `1st.sh`,
  both exiting 2, and one forge function that names this checkout's change.
- Error lines have two orders, and kittui reads the command out of the prose (S8-10, P6-9, U4-21, G5-9,
  B4-16). Of 461 error calls, 69 lead with the remedy and 64 with the reason. `fix.Command` cuts the
  command out by punctuation (`projects/tui/internal/fix/fix.go:50`), and `ExitError.Error()` gives the
  screen all of stderr (`projects/tui/internal/kit/kit.go:65`). S8 wants the remedy first and P6 the
  reason first. Reason first is better, because the fact stays on screen when a long line is cut. Write
  one function, `refuse <why> [--run=<command>]`, that prints the line and gives a JSON caller `{error,
  run}`, and use it in the nine forge calls that fail silently (`kit/modules/bash/forge/github.sh:231`).
- A relative path is read from two places (S8-4, B3-15). `kit new file` and `kit region` read it from the
  repository root (`kit/bin/kit-new:136-148`, `kit/bin/kit-region:54`), and `kit lint`, `kit context`,
  `kit kinds`, and `kit generate` from the working directory. Resolve both from `kit_invoked_in`.
- An action is a word, a flag, or an option's value (S8-12). `kit packages add style/bash` is written
  beside `kit workspaces --add=team repo`, and `kit trust --list` beside `kit packages`
  (`kit/bin/kit-workspaces:1`, `kit/bin/kit-trust:1`). Make every action a word, here and in
  `projects/tui/internal/workspaces/workspaces.go:366-405`, which builds these commands.
- `--` reaches five verbs as a word (B1-8, R2-19). `kit kinds -- README.md` prints a row for a path named
  `--`, and `kit usage -- version` answers "unknown verb '--'" (`kit/bin/kit-kinds:37`, `kit-usage:24`,
  `kit-help:37`, `kit-linked:43`, `kit-completion:33`). `tests/arguments.bats:128` claims the opposite and
  checks `kit context` only. Read `syntax_operands` in these verbs.
- A list printed as JSON has four shapes (S8-7, D2-12, R2-44). `kit packages --json` prints one object on
  each line, and `kit packages packages --json` prints `{rows, errors}` (`kit/bin/kit-packages:46`). `kit
  flow issues --json` is an array, and `{rows, errors}` under `--workspace=`
  (`kit/modules/bash/flow.sh:1171`). Times, outcome words, and the `repository` key also differ by stage
  (`docs/workspaces.md:147`), and `kit new issue` refuses `--jq` (`kit/bin/kit-new:14`). Settle on `{rows,
  errors}` and one outcome vocabulary before the JSON is released.
- The kit options are on no help page, and a verb that ignores `--workspace=` says nothing (S8-8, D2-2,
  B8-2). The options are described only in the loader's header (`kit/bin/kit:4`). `docs/workspaces.md:83`
  names three verbs that span a workspace, and eleven do. `kit --workspace=acme lint` reads one repository
  and exits 0, and `kit --workspace=acme tui flow` drops the workspace (`kit/bin/kit-tui:53`). Print the
  options in `help:overview` (`kit/modules/bash/help.sh:324`), refuse `--workspace=` where the verb does
  not read it, and pass it in `kit-tui`.
- `kit submit` refuses in `kit commit`'s words (U4-8, R1-30, S7-22). On the desk it says "refusing to
  commit on main" (`kit/modules/bash/commit.sh:72-85`), and a refused push names origin whatever the
  remote is (`commit.sh:575-577`). `kit work` and `bin/release` name `origin` where the primary is meant
  (`kit/modules/bash/issue.sh:383`, `:443`, `:524`, `:606`; `bin/release:88`). Pass the verb's word to
  `commit:branch`, and name the remote.
- A version's shape has three definitions (S7-10, B2-15). `releases:valid` accepts `1.2.3-rc-2`
  (`kit/modules/bash/releases.sh:16`), and the loader and `release:fetch` refuse it
  (`kit/bin/kit:225-230`, `kit/modules/bash/release.sh:99`). Such a pre-release is published and cannot be
  pinned. Keep the stricter pattern in all three.

## Medium: names

- The request to merge has two names (S8-5, P6-10, G2-11). "change" names the verb, the app, the stage,
  and the glyph. Help pages say "pull request" 73 times, and the glossary defines only that
  (`kit/packages/kit/files/repo/.kit/welcome/5-terms.md:103`). An issue's row has `pr` and a review's row
  has `change`, and the changes tab draws `#3` where the three tabs beside it draw `3`
  (`projects/tui/internal/flow/fields.json:630`, `:665`, `:701`). S8 picks "change" and P6 "pull request".
  "change" is right, because every name already uses it and "pull request" is wrong on GitLab. Define it
  in the glossary, rename the row keys, and use `forge:noun` at `kit/bin/kit-settle:39`,
  `kit/modules/bash/across.sh:140`, and `flow.sh:1384`.
- Two apps are not named for their verbs (S8-11, P6-4, U1-10, U4-10, U4-3). Trust's verb is `kit audit`,
  and `kit trust` trusts a clone. Repositories' verb is `kit workspace`, one letter from `kit workspaces`.
  The title line prints `kit trust` and `kit repositories`, which are not the commands
  (`projects/tui/internal/flow/view.go:27`, `apps.go:28-34`). `kit people agents` lists bots, and `kit
  issues` lists no issues (`kit/bin/kit-issues:2`). A released name cannot change, so rename now: `kit
  workspace` to `kit repositories`, one word for Trust and its verb, and `bots` for the People stage.
- The glossary and the product use different words (S8-13, P4-5, P6-10, P7-8, P1-17, P5-14). The table
  gives the counts in help pages, documents, and kittui, in that order, and the word to keep. "Toolchain"
  also needs a sentence: `2-toolchains.md:3-28` and `5-terms.md:265`, both under `welcome/`, define it as
  the tools, and every command uses it for the manager.

| Thing | Words in use | Keep |
| --- | --- | --- |
| Request to merge | pull request 73 and change about 30 in help; `pr` and `change` in JSON | change |
| A top-level screen of kittui | app 1, 54, 213; application 1, 6, 0 | app |
| The unit inside an app | stage 181, 74, 1,002; tab 31, 48, 609 | stage; tab for the widget only |
| The first checkout | desk 54, 88, 79; root checkout 7, 4, 0; main checkout 1, 3, 0 | desk |
| What installs tools | toolchain 61, 247, 15; provider 26, 86, 14; tool manager 1, 3, 0 | toolchain |
| The interface | kittui 43, 65, 168; kit tui 9, 7, 9 | kittui |
| A saved table layout | preset in every string; view 718 and preset 390 in Go comments | preset |
| Work in progress | underway in the legend; "in flight" in the row (`kit/modules/bash/flow.sh:1020`, `projects/tui/internal/flow/rows.go:604`) | underway |
| What `kit check` counts | finding, problem, difference (`kit/bin/kit-check:125`, `kit/modules/bash/welcome.sh:799`) | finding |
| A named set of repositories | "New Workspace…" makes a group (`projects/tui/internal/workspaces/workspaces.go:60`, `:665`) | group |
| An automation account | bot; `kit people agents`; "agent" is a coding agent in the glossary | bot |

## Medium: facts typed in several places

- The app catalogue is typed in at least six places, and two disagree (S8-2, D1-13, U5-23). `kit workspace
  --stages` prints repos, remotes, branches, worktrees, commits, tags (`kit/modules/bash/workspace.sh:15`).
  kittui draws repos, worktrees, branches, commits, tags, remotes, incoming
  (`projects/tui/internal/flow/apps.go:28`), and `docs/apps.md:9` says `--stages` prints the tab order.
  `docs/features.md:97` lists the flow stages in an order `kit flow --stages` does not print. Keep one
  `kit/modules/jq/apps.json`, read by `apps.sh` and embedded by kittui, and generate the document tables from it.
- An app verb is implemented three times (S8-3). Six verbs are three lines over `apps:main`. `kit
  workspace` carries its own copy in about 170 lines (`kit/bin/kit-workspace:160`,
  `kit/modules/bash/workspace.sh:203`), and `kit flow` a third (`kit/bin/kit-flow:296`). The copies answer
  one case two ways: `kit delivery releases --json` names the command to run, and `kit workspace incoming
  --json` says "unknown argument". Move `kit workspace` onto `apps.sh`.
- About 45 glyphs are outside the table, and every clash is among them (S8-6, G2-10, U7-14, U2-18, R2-54).
  `kit help packages` marks an active package ✅ at `kit/bin/kit-packages:11` and 🟢 at `:43`. ⭐ is the
  latest release in the table and a favorite in `projects/tui/internal/shell/books.go:43`, ▼ is a
  descending sort and the presets menu (`projects/tui/internal/table/presets.go:31`), and Azure DevOps has
  no glyph (`projects/tui/internal/flow/quota.go:21`). Give `glyphs.json` sections for the menu, forms,
  welcome, and text verbs, and test that no glyph has two meanings.
- The legend leaves out glyphs its own tab draws (U1-9, G2-8). Issues' legend has no line for 🏁 🔥 🔨 💬, and
  🔗 and † are never explained. Eighteen stages have no legend, and their box is titled by an internal
  name, such as `audit/findings legend` (`projects/tui/internal/flow/legend.go:153`, `:247`). Read a tab's
  legend from its fields, and title it by its label.
- Provider lists are typed by hand and lag the code (S8-14, P6-5, B7-23, D1-9, D1-11, S2-16, P5-7, P2-16,
  I3-18, D2-11). `kit help toolchains` and `kit help tools` omit the kit toolchain, which this repository
  uses (`kit/bin/kit-toolchains:10`, `kit/bin/kit-tools:31`), and so do `docs/architecture.md:159` and
  `docs/features.md:283`. Nine headers and three pages say the forge is GitHub or GitLab
  (`kit/modules/bash/forge.sh:2`, `kit/modules/jq/forge.jq:284`, `docs/trackers.md:4`,
  `docs/install.md:87`). Fill each list from `use:modules` and `forge:providers` in a `kit:generate` region.
- One letter does different things from screen to screen (U2-10, R2-26, U2-17). `r` is Refresh on a Flow tab,
  runs a refused stage's command (`projects/tui/internal/flow/fix.go:75`), runs a check's fix in welcome
  (`projects/tui/internal/welcome/menu.go:22`), and renames a workspace or a preset. `d` deletes a preset at
  once and asks first for a workspace. Keep `r` for Refresh and one letter for each verb on every screen.

## Medium: one call, a different result on each forge

These are bugs, and the forge sections treat them in full. They are here because one call means two things.

| What kit asks | What differs | Where | Findings |
| --- | --- | --- | --- |
| A work item's state | Azure DevOps reads closed only in Closed, Done, or Removed, whatever `closed_state` says, so `kit settle` closes the item again at every run | `kit/modules/jq/forge.jq:448`, `kit/modules/bash/tracker/ado.sh:83` | B5-3, B2-7 |
| Assign | Azure DevOps replaces the assignee, and kit says "adding you as well" | `kit/modules/bash/forge/ado.sh:172`, `kit/modules/bash/issue.sh:87` | B5-6 |
| A member's name | One Azure DevOps repository has three, one for each form of its address | `kit/modules/bash/workspaces.sh:140` | B6-7 |
| `kit policy` on a runner | On Azure Pipelines it judges no branch, commit, or title | `kit/modules/bash/policy.sh:158-179` | B7-8 |
| `forge_settings.ado.team` | The provider reads it, two pages document it, and the delivered schema refuses it | `kit/packages/kit/files/repo/.kit/kit.schema.json:162` | I3-10 |
| What a forge lacks | Azure DevOps declares linked branches lacking though the research gives the commands; `lacks` covers both "cannot" and "not written" | `kit/modules/bash/forge/ado.sh:88` | I4-5 |
| Whether a change is ready | GitLab draws a merge request with changes requested as ready | `kit/modules/jq/forge.jq:272` | I2-4 |
| A change's author | GitHub's reads `dependabot`, and `linked_exempt` and `--owner` use `dependabot[bot]` | `kit/modules/jq/forge.jq:159` | R1-16 |

## Medium: other sibling code that differs

| What differs | Where | Do | Findings |
| --- | --- | --- | --- |
| The pre-commit checks read the disk and the commit takes the index, so a staged file that differs from the disk is committed unchecked | `kit/modules/bash/commit.sh:268`, `:278` | Refuse the difference, or check the index | R1-7 |
| A stage's mark skips linked files, so a policy delivered as links never moves it, against `docs/apps.md:48` | `kit/modules/bash/apps.sh:312` | Use `find -L` | D2-3 |
| `retire` runs when any branch is deleted and removes every pre-release no remote branch reaches, so one a consumer pins is lost; `README.md:333` says this happens when its own branch is deleted | `bin/release:160-166` | Retire only what the deleted branch reached | R3-10, S7-12 |
| The loader stages beside its destination; the tools and `release:fetch` stage under `TMPDIR` and move across file systems (plausible) | `kit/modules/bash/toolchain/kit.sh:373-391`, `kit/modules/bash/release.sh:111-141` | Stage beside the destination | S7-9 |
| The catalogue region tests for kit's source by a directory's name; its header promises a repository's own `bin/tutorials` never runs | `kit/modules/tutorials.yml:7-11` | Test for a file only kit's source has | T1-4 |
| `kit welcome` over a group omits the members not cloned; the same screen opened on that workspace lists them | `projects/tui/internal/welcome/welcome.go:349` | Keep the workspace on `WorkspaceMsg` | G6-7 |
| The Cursor and Copilot mirrors say to read one rule where `1st.md` says to run `kit context`; Copilot's `sh` file has an empty `applyTo` | `kit/packages/agents/copilot/files/repo/.github/instructions/kit-sh.instructions.md:2` | One sentence in each mirror: run `kit context` on the file | U6-10 |

## Medium: documents that say what the code does not do

Each row is a line or a paragraph to correct. A newcomer or a consumer reads the first nine, so correct those
before the release.

| Where | It says | The code | Findings |
| --- | --- | --- | --- |
| `README.md:209`, `.envrc:15` | Setup runs `direnv allow` and never `kit trust` | Both kit calls in `.envrc` refuse in a clone not yet trusted, and no tool is on `PATH` | D1-4, S7-20 |
| `docs/serve.md:163`, `docs/packages/github/ci.md:37`, `docs/packages/agents/claude.md:30` | The server, the hook, and another CI system run kit | The trust gate refuses each, and no feature page names it | D2-1 |
| `README.md:245`, `docs/architecture.md:138`, `docs/features.md:79-95`, `docs/packages/workflow.md:22`, `kit/packages/kit/files/repo/.kit/1st.md:129-132` | The last workflow step is `gh pr ready`, or is missing | `kit ready` exists, and the delivered workflow names it | D1-3, P1-2, D2-6, U3-17, U4-20, U5-19, P4-13 |
| `docs/features.md:323`, `bin/release:133`, `projects/tutorials/src/components/Since.tsx:16` | Pin with mise, Homebrew, or by hand; a plain `kit update` upgrades | The pin is `version:` in `kit.yml`, and `kit --version=0.2.0 update` moves it (`kit/bin/kit-update:7-10`) | D1-10, T1-2 |
| `projects/tutorials/src/content/kit-tutorials/index.mdx:10` | Tutorials are web pages | Nine of ten ship in kit and open in kittui | P4-2 |
| `kit/packages/kit/files/repo/.kit/README.md:12` | `.kit/` commits only `packages/` | Team presets are committed in `.kit/presets/` | P4-3 |
| `kit/bin/kit-welcome:13-23`, `kit/bin/kit-linked:7-10` | Help: welcome opens on the first failed check; an issue counts only when it is this repository's | The screen opens on the introduction; an issue of any declared tracker counts | U3-15, R3-22 |
| `kit/packages/policy/opa/package.yml:5` | The package covers names and files | `kit.rego` has no rule over files | R3-24 |
| `README.md:229`, `docs/modules.md:31`, `kit/packages/kit/files/repo/.kit/welcome/4-customize.md:13-64` | Nine relative links | Three point at files git ignores and six resolve only in kittui; lychee runs hydrated and skips hidden directories (`bin/ci:62`) | D1-5, P1-3, P4-4 |
| `docs/architecture.md:21`, `README.md:253`, `AGENTS.md:15` | A checkout has no `libexec/`; the tarball adds `libexec/kittui`, built from `tui/` | `kit/libexec/kit-call` runs every call; the binary is `kittui-<os>-<arch>`, from `projects/tui/` | D1-8, P1-9, R3-27, P4-16, U6-16 |
| `docs/packages.md:257`, `:271` | 18 settings; kit writes three keys | The schema has 20, and `kit tools update` rewrites `tools:` (`kit/modules/bash/toolchain/kit.sh:152`) | D2-4 |
| `docs/packages/kit.md:15`, `docs/templates.md:6`, `docs/workspaces.md:152` | Seven rules, five templates, eight stages | Eight, six, and seven | P2-8, P2-9, D2-7, D2-8, D2-9 |
| `projects/tui/README.md:7`, `:33`, `:274` | Six screens; `kit tutorials screens`; tutorials tabbed by audience | `shell.go` names thirteen; the id is `screen`, so the example is refused; cards, not tabs; Layout names 15 of 22 packages | D2-5, P4-10, R3-23, S1-18, U2-19 |
| `docs/integrations/1st.md:33`, `forges.md:32-43`, `trackers.md:11`, `ci.md:12-49`, `az.md:23` | Contract 3; five tabs planned; Azure DevOps lacks four features | Contract 6 (`kit/modules/bash/forge.sh:287`); the five tabs ship; `forge/ado.sh:88-91` declares twelve | I4-4, I5-8, P3-1, P3-2 |
| `kit/modules/bash/commit.sh:27`, `kit/modules/bash/workspaces.sh:7` | `kit submit` commits; only kit writes `workspaces.yml` | It commits nothing; the help says you may edit the file | P5-2, B2-27, P5-3 |
| `projects/tui/internal/grid/grid.go:10`, `projects/tui/internal/flow/views.go:5` | A click sorts; ✓ marks a selected row; a panel is beside the rows | A click opens the column's card; the mark is ▣; no panel is drawn | P7-4, P7-5 |
| `docs/delivery.svg:46-84`, `docs/loop.svg:84`, `docs/context.svg:7` | The manifest holds the version and packages; `kit.yml` is never written; the hook runs before every write | The manifest holds digests; kit writes three keys of `kit.yml`; a write through the shell skips the hook | R3-21 |
| `docs/superpowers/`, `kit/packages/workflow/files/repo/.kit/workflow.md:32` | The rule: never commit a spec or a plan as a file | 7 specs and 17 plans are committed, all 567 checkboxes are open, and six spec statements are stale | P8-3, P8-4, P8-5, R3-28 |

## Low: 148 findings

Fifty repeat an item above and are cited there. The other 98, by title:

- Core documents. The jq module table lists 11 of 17 modules (D1-12, P1-12, R3-38). `docs/features.md` lists
  the stages out of order (P1-11). Counts and samples in five pages are stale (D1-14, P1-13, R3-40). The
  README's maintenance lists and the gate list in `docs/testing.md` are short (D1-15, P1-15, R3-42, S4-13;
  P1-14, plausible). Eight `see:` lines break the path rule in `AGENTS.md` (D1-16, R3-29). The loader's `see:`
  names `docs/releases.md`, which is not there (P5-11, S5-19). `kit root`, `kit facts`, `kit template`, and
  the Settle job are in no core document (D1-17). `1st.md` names 11 workflow commands and `kit help` 20
  (R3-39). The welcome pages have small slips (P4-15, R3-43). kit is described in three sentences (P6-17).
- Feature documents and tutorials. `docs/apps.md` and `docs/trackers.md` have small stale lines (D2-10,
  P2-10). The schema names a default for one setting of twenty (D2-13). A merged JSON file is left as `{}`
  after removal (D2-14). The gate skips the house package's `package.yml` (D2-15). `docs/workspaces.md`
  calls the workspace menu the 📚 control (P2-11). Documents and delivered text break the markdown style
  (P2-13; P4-17, plausible). Two tutorials describe the screen wrongly (G6-21, P6-14). The agents tab's
  title promises a count (P6-12). The tutorials site names a script that is gone (T1-12, P7-7, R3-44).
- Integration pages. `gh.md` is stale in eight places and lacks six kinds of call (I1-6, I1-7). `glab.md`
  lacks the label calls and contradicts its schemas (I2-6, I2-7, I2-8, I2-12, P3-10). `az.md` is behind in
  five places (I3-15). `git.md`'s two safety claims have exceptions, and it writes `kit lint --all` (I4-13,
  S8-15). The AWS plan cites contract 3 (I4-14). `kit flow --capabilities` is documented as kittui's, and
  kittui never asks for it (I4-9, S3-12). The thirty pages have small faults (I5-12, P3-8, P3-9).
- Headers and comments. Ten headers say less than the code does, or something else (B6-15, R1-41, R3-41,
  P5-8, P5-9, P5-12, P5-13). Five Exits lines omit exit 2 (S8-15). The release workflows' headers count
  their steps wrong (P5-10). Lines run past column 120 (P5-15). `kit tools update` says mise rewrote the
  pins (R2-51). A delivered module cites a spec the release does not hold (P8-8). Four Go package comments
  are stale (G4-26, P7-6). The components spec and the code differ (R2-61).
- The command line. A fetch that fails exits 128 in git's words (B2-16). A template line that mentions `kit:generate`
  is read as a directive (B3-20). GitLab's writes let glab find the project (B5-18,
  plausible). Azure DevOps reads by the organization's number (B5-20, plausible). The two policy engines
  disagree on the same facts (B7-17, R1-25). `kit syntax --match` skips closed choices, and the syntax
  tool refuses flag words (R2-46, B7-21). Completion ignores the usage line the words chose (R2-47). Bare
  `kit` without a terminal exits 2 (R2-49). welcome's jq check cannot fail (R2-43, plausible). A read in
  flight outlives `forge:forget` (R1-45, plausible). The six seams hold a provider six ways (S2-12).
  Builds and releases spend a request to ask who the caller is (S6-8). Help pages differ in headings and
  case (S8-16). Front matter is parsed four ways (T1-7). The site and the catalogue order tutorials
  differently (T1-8). A commit subject's area label has several spellings (P8-11).
- kittui. The preset operations exist twice, word for word (S8-17). The wheel scrolls the rows under an
  open dialog (G1-15). The preset line can name a view the panel has left (G3-11). ctrl+a drops selected
  rows the search hides (G3-14). `WritePresets` writes over a file it could not read (G3-16). The cursor's
  band stops at kit's reset (G4-17). The filter's none misses an empty string (G4-18). `pane.Window` says
  one row is hidden and `pane.Frame` never does (G4-25). Esc on Open Repository does not take back the ask
  (G5-13). An Azure DevOps HTTPS clone is titled `_git/<repository>` (G5-20). A key the tutorials' search
  does not take moves the cards (G6-10). welcome draws a link it does not follow (G6-16). A click on a
  menu's border closes it, and on a dialog's does nothing (R2-55). The form writes key hints under its
  fields (R2-57). Several marks are in no monospaced font (U7-12).

## Done well, leave alone

- The verb header is the only source of help, usage, the guard, the form, and completion. Do not move help out of
  it. Exit codes hold to one scheme, 0 done, 1 could not, 2 usage, and every verb follows it for a usage error.
- `glyphs.json` with `kit:generate` regions into `flow.sh` and `glyph.go` is the right pattern, and the
  items above ask for more of it. So are `forge:noun` and `apps.sh`, which makes six verbs three lines each.
- `docs/serve.md`, `docs/terminals.md`, and `docs/install.md` match the code line for line. The serve
  groups, wrong in four places on 11-10, now agree.
- Four lists that could drift have not: the 31 forge features in `docs/architecture.md`, the app table in
  `docs/features.md`, the 20 schema keys, and the packages table. `kit syntax --check` holds every header
  in the gate.

## Work items

1. Finish `--name=<value>` in every usage line, refusal, and document. Covers S8-1, U4-6, P6-3, B1-10,
   R2-48, B8-15, B7-24, R2-72. Size S. Depends on nothing. It is issue #160. Before the release.
2. `kit flow` prints on stdout and takes `--text` on a stage, and `--help` prints. Covers U4-4, D1-7,
   R1-43, R3-19, R2-17, U4-1, R2-49. Size S. Depends on nothing. Before.
3. Make the first-hour promises true: the kit package's removal, the trust step in Setup, the Homebrew
   line, the Jira and Linear line, and the checks tables. Covers D1-1, D1-4, S7-20, D2-1, D1-2, R3-6,
   U3-4, U5-4, I5-1, U5-12, R3-7, D1-6, R3-20. Size S. Depends on asking the tap. Before.
4. Choose the names, then rename verbs, stages, and JSON keys. Covers S8-5, S8-11, S8-12, S8-13, P6-4,
   P6-10, U1-10, U4-10, U4-3, G2-11, P4-5, P7-8, P1-17, P5-14. Size M. Depends on the owner's choices. It
   is the prose section's item 8. Before, because a released name cannot change.
5. One refusal function, two guards, and one way to name this checkout's change. Covers S8-9, S8-10,
   B2-17, P6-9, U4-21, U4-8, R1-30, S7-22, G5-9, B4-16, B2-16. Size M. Depends on 4 for the noun. The
   guards and `kit submit`'s words before, the 133 call sites after.
6. One JSON shape and one outcome vocabulary. Covers S8-7, D2-12, R2-44. Size M for five verbs, L with
   `kit flow`. Depends on 4 for the key names. Before, because the JSON is a contract once released.
7. The kit options in help, `--workspace=` refused where unread and passed by `kit tui`, paths read from
   where they were typed, and `--` dropped. Covers S8-8, D2-2, B8-2, S8-4, B3-15, B1-8, R2-19, D1-17. Size
   S. Depends on nothing. Before.
8. Forms take clicks, and a key means one thing. Covers U3-5, U2-8, R2-25, R3-25, U2-10, R2-26, U2-17,
   R2-55, R2-57. Size M. Depends on nothing. The clicks before, or correct
   `kit/modules/tutorials/screen.md:41`. The keys after.
9. State `kit work`'s sweep, and correct the `work` tool's hints. Covers U6-3, B7-15. Size S. Depends on
   nothing. Before.
10. One app catalogue with generated tables, and `kit workspace` on `apps.sh`. Covers S8-2, S8-3, D1-13,
    U5-23, P1-11. Size M. Depends on 4. After.
11. Every glyph in `glyphs.json`, a test for two meanings, and legends read from fields. Covers S8-6,
    G2-10, U7-14, U2-18, R2-54, U7-12, U1-9, G2-8. Size M. Depends on nothing. After, except ✅ and 🟢 in
    `kit help packages`, before.
12. Generate the provider lists. Covers S8-14, P6-5, B7-23, D1-9, D1-11, S2-16, P5-7, P2-16, I3-18, D2-11,
    S2-12. Size S. Depends on nothing. The kit toolchain in the two help pages before, the regions after.
13. Forge parity: the eight rows of the forge table. Covers B5-3, B2-7, B5-6, B6-7, B7-8, I3-10, I4-5, I2-4,
    R1-16, B5-18, B5-20, G5-20. Size M. Depends on the forge sections, which own it. B5-3, I3-10, and I2-4 before.
14. Sibling code brought level. Covers R1-7, D2-3, D2-14, R3-10, S7-12, S7-10, B2-15, S7-9, T1-4, G6-7, U6-10,
    R2-46, R2-47, B7-21, B7-17, R1-25. Size M. Depends on nothing. R1-7, D2-3, S7-10, and R3-10 before.
15. Correct rows three to nine of the documents table. Rows one and two are in item 3. Covers D1-3, P1-2,
    D2-6, U3-17, U4-20, U5-19, P4-13, D1-10, T1-2, P4-2, P4-3, U3-15, R3-22, R3-24, D1-5, P1-3, P4-4,
    R3-43, P4-15, R2-51. Size S. Depends on nothing. It is part of the prose section's item 5. Before.
16. Correct the other nine rows and the low list's documents, pages, headers, and comments. Covers D1-8,
    P1-9, D2-4, P2-8, P2-9, D2-5, P4-10, R3-23, I4-4, I5-8, P3-1, P3-2, P5-2, P5-3, P7-4, P7-5, R3-21,
    P8-3, P8-4, P8-5, and those titles. Size M. Depends on the owner's ruling on specs and plans. After.
17. Checks that stop these returning: lychee with `--hidden` on a clean checkout, `see:` paths, generated
    counts and tables, schema defaults, and every documented command through `kit syntax --match`. Covers
    D1-5, P4-4, S8-15, D1-16, P5-11, S5-19, D1-12, D2-13, D2-15, S4-13. Size M. Depends on 10 and 12 for
    the generated tables. It is the prose section's item 16. After.
