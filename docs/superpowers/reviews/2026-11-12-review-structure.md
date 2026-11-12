# Modularity, structure, data-driven components, tests, and performance

This section rests on five reviews of the tree at 0e76266c: kittui's architecture (S1), the bash architecture
(S2), the contract between kit and kittui (S3), the tests (S4), and performance (S6). It adds the 93 findings of
kind structure, data-driven, test, or performance from the other areas: 166 in all, 7 high, 93 medium, and 66 low.

Skeptics refuted none of the high findings and narrowed two: the guessed links (S3-1, G2-2) and the Azure
DevOps provider (I3-1). Where reviewers' numbers differ, I give the one the snapshot bears out. Timings
were taken at a load average of 37 to 85, so each is an upper bound; process counts do not depend on load.
Paths are shortened: a `.sh` file is under `kit/modules/bash/`, a `.jq` file under `kit/modules/jq/`, and
a `.go` file or a `testdata` path under `projects/tui/internal/`. Every other path is whole.

## The answer

Neither side needs a new design. kittui's packages are layered and have no cycle. The bash has one loader, one
`use`, one verb preamble, and a forge contract with versions. What both sides lack is one home for each fact.

- Modularity. The table has two hosts, Flow's own and `table.Sheet`, and they have drifted. Six screens wire the
  menu bar and the search by hand. In bash, Azure Boards is written twice, and the hand-off to kittui ten times.
- Data. 22 definitions live in both kit and kittui, and a test or a read at run time holds 4 of
  them. The table below names one home for each of 14 facts that are typed in several places.
- Tests. The suites are large: 1,261 bats tests and 1,022 Go tests. But each side of a seam is tested
  against a hand-kept copy of the other side. Three copies have drifted, and one test fails at this commit.
- Time. It goes to starting processes. A text table forks about 23 shells a row, every kit call
  parses its verb's grammar again, and kittui starts 11 to 17 kit processes to open an app.

Before the release, make the gate green and honest, hold kittui's fixtures to kit,
let kit print the links, number the stage documents, and take the small speed fixes.
The data files, the chrome, Flow on `Sheet`, and the row cache follow in that order.

## High findings

1. The suite fails at this commit, at `tests/template.bats:281`. `forge.sh:175-185` lists six
   `bot-*` calls among the calls every provider implements, and the provider template and the GitLab
   and Azure DevOps providers lack them. No verb calls the six, or any function of `secrets.sh`, so
   about 310 lines that mint and revoke tokens would ship untried. Land the verb, or mark the six
   optional and leave the feature out of this release's contract. Confirmed. (R3-2, B3-12, S2-17)
2. Nothing holds kittui's stage fixtures to what kit prints, and they have drifted. Only `kit syntax` is
   compared with the real kit (`tests/syntax.bats:283`). 27 of 32 fixtures under `flow/testdata` lack
   `source`, `organization`, and `repository`, which kit prints on every row, and `audit-controls.json:2`
   keeps a control's kind under `source` where `apps.jq:115` prints `kind`. kit and the catalog agree
   today; only the fixtures are wrong. Add a bats test per app verb that compares its rows' keys and
   types with the fixture and the catalog, then regenerate the fixtures. Size S for the 13 stages that
   read no forge, M with the 19 that do. Known since 11-10. (S4-1, S3-3, G2-5, R2-36, U1-12)
3. A text table forks about 23 shells a row, and text is what an agent, a pipe, and CI read.
   `kit flow issues` starts about 7,000 bash processes for 300 issues and takes 19 to 20 s of CPU,
   against 254 processes and under 2 s with `--json`. Each cell is drawn by a helper whose output `$(…)`
   captures (`flow.sh:214`, `issues.sh:101`). Give the five cell helpers a form that sets a variable
   with `printf -v`, size S. Later, draw every table with one jq function, size M. Confirmed. (S6-1)
4. kittui guesses every issue and pull request link from `git remote get-url origin`
   (`flow/origin.go:16-81`), because kit's issue and change documents carry no `url` (`forge.jq:120-127`,
   `:285-289`). The link is wrong for a GitLab subgroup, Azure DevOps, a GitLab under another host name, and
   a primary that is not `origin`. The skeptics rate it medium: only a link that is opened or copied is
   wrong, and GitHub is right. Have `kit flow issues` and `changes` print `links` by field, which every
   newer stage does (`apps.jq:39`), and delete the guess. Size M. Known since 11-10. (S1-1, S3-1, G2-2, I5-6)
5. The stage documents carry no version. Plausible: read from the code, not run. A workspace reads each member
   with the release that member pins (`across.sh:210`, `kit/bin/kit:437`), and kittui reads every answer with
   the one `fields.json` in its binary (`flow/fields.go:27`). After v0.1.0, a key that a later release renames
   becomes a blank column with no message (`table/read.go:185`). Put a `contract` number in every stage
   document and in `fields.json`, and name a member whose number differs under `errors`. Size S. (S3-2)
6. The Azure DevOps provider has met only its own fake. The skeptic calls it a disclosed gap: the tree says so
   itself (`docs/integrations/az.md:70`, `tests/forge-ado.bats:8`). The integrations section carries it. (I3-1)

## Facts typed in several places

Each row merges medium findings. `kit/modules/jq/glyphs.json` is the pattern to copy: one
table that `kit generate` writes into bash and Go, held by `kit generate --check`.

| Fact | Typed in | Drift found | One home | Findings |
| --- | --- | --- | --- | --- |
| An app's name, glyph, verb, and tabs | `flow/apps.go:25`, `shell/shell.go:38-103`, `apps/*.sh`, `workspace.sh:15`, the verb headers, `fields.json`, two fake kits, `docs/apps.md:9` | `kit workspace --stages` lists remotes second and Repositories draws it sixth; `kit workspace incoming` exits 2 | `kit/modules/jq/apps.json`, read by `apps.sh`, generated into Go | S3-4, S8-2, S1-9, S2-8 |
| A tab's glyph, color, and legend | `kit/modules/jq/glyphs.json:81` names 14 stages; `flow/glyph.go:67-254`; `flow/legend.go:153` | 20 of 32 tabs have none; on four of them `?` cannot explain the glyphs the rows draw | glyph and color on the catalog entry; the legend derived from the fields' glyphs | S1-3, S3-5, G2-4, R2-64 |
| Glyphs outside the glyph table | about 45 literals in verb headers, `style/style.go:22`, `shell/books.go:43`, `opener/open.go:38`; 146 in `fields.json` | ✅ and 🟢 both mark an active package (`kit/bin/kit-packages:11`, `:43`); ⭐ means latest release and favorite | sections in `glyphs.json`, glyphs named in the catalog, a test that no glyph has two meanings | S8-6, S3-7 |
| The four fields every stage repeats | `projects/tui/internal/flow/fields.json:48` and on: 127 of 361 fields (35%) copy member, source, organization, and repository | none yet | a `shared` block that `table/catalog.go:147` expands | S1-7, S3-7, G2-7 |
| Flow's seven stages, and which read the forge | `flow.sh:153`, `:1197`, `:1270`, `:1331`, `:1394`, `:1459`, `across.sh:131`, `marks.sh:37`, beside `settings.sh:313` | none yet | one row a stage, which `glyphs.json` already has | S3-15, B6-13 |
| The forge contract's 60 calls | `forge.sh:60-235`, `:288-309`, 60 wrappers, 13 stubs (`forge/ado.sh:74-95`, `forge/gitlab.sh:37-55`), the provider template | high finding 1; `pr-create` is "since 3" in the header and in no table | one table of call, feature, since, and kind | S2-5, S4-5, I4-16, I2-5 |
| What each forge is: hosts, tool, sigil, pages, glyph | `forge.sh:404-476`, `welcome.sh:444-466`, `workspace.jq:24-29`, `tracker/forge.sh:33`, `issues.sh:117`, `flow/rows.go:556`, `flow/quota.go:21`, nine headers | Azure DevOps has no welcome check, no page link, and no glyph | `kit/modules/jq/forges.json` | S2-4, I5-6, S3-11, S8-14, S2-16 |
| Azure Boards' calls and closing states | `tracker/ado.sh:23-131`, `forge/ado.sh:167-238`, `forge.jq:448` | `closed_state: Resolved` closes an issue that then reads OPEN; the tracker's create drops the body | one `boards.sh` that both seams call | S2-1, S2-2, B5-17, I3-9 |
| The apt, dnf, and pacman providers | `toolchain/apt.sh:12`, `toolchain/dnf.sh:12`, `toolchain/pacman.sh:12`, `welcome.sh:126` | none | a table of manager, install words, and packages | S2-11, B7-25, S7-19 |
| The hand-off to kittui | ten sites: in `kit/bin`, `kit-flow:304`, `:320`, `:391`, `kit-workspace:183`, `kit-help:77`, `kit-tutorials:64`, `kit-welcome:172`, and `kit-tui:51`; `apps.sh:52`; `1st.sh:737` | `kit tui` passes no workspace; `kit welcome --fix` skips the probes | `tui:exec` in `tui.sh` | S2-9, B8-11, B6-14 |
| The stage protocol: `--stages`, `--marks`, a stage's JSON | `apps.sh:34`, `kit/bin/kit-workspace:155-260`, `kit/bin/kit-flow:250` | three envelopes: an array, an object, and `{rows, errors}` (`flow/flow.go:1115`) | `kit workspace` on `apps:main`; one envelope | S3-6, S8-3 |
| The welcome's pages, steps, and check ids | `welcome/source.go:30`, `welcome/welcome.go:60`, `welcome/setup.go:33`, against `welcome.sh:107`, `:1046` | none yet | `kit welcome --pages --json`; kit names each check's column | S3-9, G6-23, S1-15 |
| Words both sides derive: sigil, where, event, checks cell | `flow/rows.go:216-235`, `:487-528`, `:556`, `:656`, against `issues.sh:117`, `builds.sh:51`, `flow.sh:912` | a built field's path is never read, so a wrong path fails nothing (`flow/rows.go:248`) | kit prints the word, and the four Go builders go | S3-8, G2-7 |
| A forge tool's answers | 351 inline fixtures in 23 bats files, beside 79 schemas that `bin/ci:53` checks against their own examples | 12 of 42 schemas reject a fixture | fixtures drawn from the schemas' examples | S4-2, I1-1, I2-1, I3-8, I4-8, I5-9 |

The integrations section designs the forge rows, the last row, and the research pages (I1-5, I4-7, I5-7).

## Structure

1. The table has two hosts. Five screens and dialogs stand on `table.Sheet` (`table/sheet.go:41-969`). Flow
   implements `table.Host` itself in about 1,050 lines (`flow/host.go:10-132`, `flow/views.go:198-446`).
   Sixteen functions have a twin, and the twins differ: the last-left panel, team presets, and `@me` exist only
   in Flow (`table/sheet.go:251`). Every preset fix is owed twice. Give `Sheet` what only Flow has, make each
   stage hold a `Sheet`, then delete the twins and move their tests to `table`. Size L. (S1-2, G3-10, S8-17)
2. `table.Host` asks a screen for 30 methods (`table/host.go:20-51`), a dozen of which the table can compute.
   Remove the three that only forward (`table/sheet.go:269-275`), size S, and the rest after item 1. (S1-8)
3. Six screens wire the menu bar and the search by hand (`palette/palette.go:415-521`,
   `tutorials/tutorials.go:463-632`, `welcome/welcome.go:626-700`,
   `workspaces/workspaces.go:506-560`, `flow/layers.go:44-111`, `form/model.go:74-96`). Workspaces
   already remembers no search and swallows ⌃R (`workspaces/workspaces.go:540`). Add a
   `shell.Chrome` that owns them and answers a key, a click, and a wheel turn. Size M. (S1-4, G6-9)
4. The tab menu and Maximize are written in Flow and again in the welcome (`flow/menu.go:60-82`, `:212-269`,
   `welcome/menu.go:71-168`). Flow's menu matches its lines by their English labels in five switches, and an
   unknown label clears the selection (`flow/menu.go:119-178`). Add a `tabs.Frame`, and make the menu one
   slice of items, each with an id, an enabled function, and a run function. Size M. (S1-5, G1-19)
5. The reader that turns kit's JSON into records by the catalog's paths belongs to Flow's model
   (`flow/flow.go:1115-1166`). So tutorials and workspaces build records by hand (`tutorials/tutorials.go:375`,
   `workspaces/workspaces.go:238`). Lift the reader into `table` as `(*Schema).Read`. Size M. (S1-6)
6. The table knows Flow's command line, and Flow holds what every table could use. `table.Schema` carries
   `Command`, `Takes`, `Staged`, `Marked`, `Forge`, and `Slurp` (`table/catalog.go:26-45`), and the
   renderers date, day, bytes, path, and track are registered from Flow (`flow/fields.go:66-87`). Split a
   `Source` struct out of `Schema`, and move the five renderers to `table`. Size S. (S1-11, S3-14, R2-63)
7. kittui reads git and the repository's files itself in five places, with two parsers of a remote's
   URL (`flow/origin.go:16`, `flow/team.go:37`, `welcome/source.go:29-110`, `kit/installed.go:14`).
   Its README says it reads everything from kit. Take the host and path from the `kit.Workspace` the
   root holds, and let kit say whether it is installed and where team presets are. Size M. (S1-10)
8. The form walks a verb's grammar three times, and each walk counts groups its own way
   (`form/fields.go:232`, `form/command.go:100`, `form/render.go:221`). Two of the form's
   bugs are those counts disagreeing. Make one walk that gives each row an identity. (G4-13)
9. The grid tells a row from a heading by its number of cells (`grid/panel.go:861`, `:1304`),
   so hiding down to one column breaks folds, the header, and parents. Known since 11-10. Tell
   them apart by `Row.Aside`, and until then refuse the hide that leaves one column. (G4-9)
10. An error line comes in five shapes, and kittui cuts the command back out of the prose
    (`1st.sh:521`, `:598`, `fix/fix.go:50`). Write one `refuse` function that takes the
    reason, `--run=`, and `--see=`, and hands a JSON caller `{error, run}`. Size M. (S8-10)
11. The providers repeat five patterns. The GraphQL cursor loop is written eight times, and `gh` runs from 33
    places, each with its own idea of a failure (`forge/github.sh:555-580`, `:1212`, `:1239`,
    `forge/gitlab.sh:319-328`). Add `forge:pages`, `forge:marks-of`, `forge:here`, and `forge:off` to `forge.sh`,
    and one `forge/github:gh` that sets the repository and classifies a failure. Size M. (S2-6, B4-15)
12. `flow.sh` holds three stages, the shared cells, and two other stages' tables, so five modules
    use each other in a ring (`flow.sh:65`, `:198-262`, `:912-1066`, `changes.sh:14`). Move the
    cells, incoming, the checkouts, and the change table to modules of their own. Size M. (S2-7)
13. Four verbs keep their logic in `kit/bin`, so a module reaches it by starting
    kit again (`kit/bin/kit-tools:62-440`, `kit/bin/kit-workspaces:160`,
    `kit/bin/kit-update:107-120`, `apps/platform.sh:160`, `apps/audit.sh:181`).
    Move the bodies to modules. Size S for tools, M for all four. (S2-10)
14. The tracker seam has no version, no `lacks`, and no exit 3, and a reference written `ENG-123` is refused
    (`tracker.sh:34-49`, `settings.sh:102-111`). The integrations section carries both. (I5-4, I5-5)

## What the tests miss

Each side is tested well. The seams between the sides are not.

| Seam | What stands in for the other side | Held by | State |
| --- | --- | --- | --- |
| `kit syntax` to kittui's forms | 40 fixtures under `syntax/testdata` | `tests/syntax.bats:283` | exact today; 12 of 52 verbs have no fixture |
| kit's stage JSON to kittui's catalog | 35 fixtures under `flow/testdata`, four fake kits | nothing | 27 of 32 stage fixtures lack three keys kit prints |
| A forge tool to its provider | 351 inline fixtures, 451 routes | nothing | 12 of 42 schemas reject a fixture |
| The seam's header to the provider template | the template | `tests/template.bats:281` | fails at this commit |
| Each call on each provider | loops over github and gitlab; Azure DevOps apart | no table of calls | `pr-set-body` is tested for GitHub alone, `require` for none |
| The welcome's pages to its goldens | fixture pages under `welcome/testdata/release` | nothing | the fixture's toolchains page has 3 lines, the shipped one 46 |
| Azure DevOps to a live organization | its own fake | nothing | never run, and the documents say so |
| The bash to its tests | no coverage figure | nothing | 198 of 448 error lines have a fragment in any test |

1. Four tests hold a wall-clock bound of 8 ms (`table/cost_test.go:45`, `flow/cost_test.go:71`, `:143`, `:211`).
   The two wheel tests failed for five reviewers, at 11 to 44 ms, and the gate runs every package side by side
   (`bin/ci:76`). Nobody ran them on an idle machine, so whether the project's runner fails is not known. Keep
   each test's structural half, and count work in place of time. Size S. (S4-3, G3-5, S1-17, G1-17, U7-16)
2. The gate neither fails on a skip nor counts one. Plausible: no CI log was read. 23 places skip when a tool
   is missing, `bin/ci:75` reads only bats' status, and `tests/loader.bats:235` skips on every Linux runner.
   Add `needs <tool>` to `tests/helper.bash`: fail for a tool `kit.yml` pins, skip otherwise. Size S. (S4-6)
3. Three tests run the `gh` on `PATH` and pass whatever it answers. `tests/across.bats:495` made
   24 calls to it, and `tests/platform.bats:100` and `:174` one each. On a runner they reach
   github.com. `helper:isolate` also leaves `GIT_DIR`, `GH_TOKEN`, and eight more variables set
   (`tests/helper.bash:32`). Give the three a fake `gh`, and unset the variables. (R3-14, R3-15)
4. Some assertions cannot fail. Eleven `[ a ] && [ b ]` lines stand in the middle of a
   test (`tests/toolchains.bats:103`, `tests/uninstall.bats:26`, `tests/serve.bats:239`), and
   39 `run ! grep` lines pass when the file is missing. Write one assertion a line. (R3-16)
5. The syntax fixtures cover 40 of 52 verbs, and the test walks the fixtures, not the verbs
   (`tests/syntax.bats:283`). Four of the twelve missing verbs are ones kittui's menus run:
   assign, unassign, close, and gather. Loop over `kit syntax --list`, and snapshot the
   serve tools' list the same way (`serve.sh:81`). Size S. (S4-7, S3-13, G6-17, R2-42)
6. The verbs that change the forge are tested on the good path. `kit settle` closes issues and unassigns
   people, and has one test (`tests/tracker.bats:229`). The failure lines at `issue.sh:164`, `:286`, and
   `:322` are asserted nowhere. Add `tests/settle.bats` with the failures as a table. Size S. (S4-8)
7. Each bats file rebuilds the same worlds. `call()` is word for word in five forge files, and one world is
   written ten times (`tests/forge-conformance.bats:21`, `tests/forge-ado.bats:22`, `tests/flow.bats:116`). Move
   the helpers into `tests/helper.bash`, and make a world a directory of routes and answers. Size M. (S4-4)
8. "Every provider" is two providers in a loop (`tests/forge-conformance.bats:244`), and Azure DevOps
   in a file of its own with its own copy of the expected documents (`tests/forge-ado.bats:238`). Once
   the contract is a table, one test fails when a provider implements a call no test names. (S4-5)
9. The welcome's goldens are drawn from fixture pages that no longer match the shipped ones
   (`welcome/testdata/setup.golden:7`). Add goldens over the shipped pages at 80x24 and 120x40. (U3-14)

## Where time goes

Time goes to starting processes: a kit call spends about 300 ms of CPU before it does its work.
Process counts are exact, and two figures in a cell are the reviewer's run and the skeptic's.

| Read | bash processes | CPU |
| --- | --- | --- |
| `kit flow issues` as text, 30 issues | 967 to 988 | not taken |
| The same, 300 issues | 6,992 to 7,473 | 19 to 20 s |
| The same with `--json`, 300 issues | 254 | 1.6 to 1.9 s |
| `kit flow changes` as text, 30 changes | 1,437 | 4.4 to 5.0 s |
| `kit flow --json`, the whole picture | 589, and 313 with the provider kept | 3.1 s, and 2.1 s |
| One `--cached` read from kittui | 56 | 0.27 s |

In kittui the cost is per key. The middle column is 2,000 rows for the first three lines and 3,000 for the last two.

| kittui at 160x50 | 300 rows | 2,000 or 3,000 rows | 10,000 rows |
| --- | --- | --- | --- |
| A typed character and its draw, in Flow | 67 ms | 193 to 422 ms | 1,559 ms |
| ↓ in Flow | 20 ms | 51 ms | 427 ms |
| A load landing | 53 ms | 353 ms | 1,492 ms |
| ↓ on a `Sheet` | 3.4 ms | 74 ms | 232 ms |
| A draw with the tab menu open | 39 ms | 659 ms | 1,880 ms |

1. Every call parses its verb's grammar again from the header (`1st.sh:703`, `help.sh:31`, `syntax.sh:316`).
   That is 109 to 118 ms of the 296 ms in `kit flow --stages`, though the grammar changes only with a release.
   Keep it compiled: a file per verb that `bin/release` writes and `kit lint` checks. Size S to M. (S6-2)
2. The forge seam works out the primary and the provider on every call (`forge.sh:539-551`). One
   `kit flow --json` runs `forge:primary` 56 times, because a value kept in a variable dies inside
   `$(…)`. Set them once in the verb's main shell, keyed by the settings file. Size S. (S6-3, S2-3)
3. `use` forks once per module (`1st.sh:326`). With the loop inline, the 18 modules
   of `kit flow` load in 57 to 63 ms, down from 131 to 154. An hour's work. (S6-6)
4. kittui pays kit's start-up 11 to 17 times to open an app, two or three in sequence before it draws
   (`flow/apps.go:83`, `flow/flow.go:244`). On a first switch to an app the same calls run inside `Update`, so the
   screen takes no key for 0.6 to 1.3 s (`screens/screens.go:451`, `app/app.go:145`, `form/model.go:802`). Known
   since 11-10. Run them as commands, at once, size S. Later, one call answers all, size M. (S6-4, G5-7, G4-14)
5. One cache generation covers every stage (`flow/flow.go:235`, `:636`). A typed character lays out every
   record of every stage again. The line cache's key holds the cursor, so ↓ draws every row, in Flow and on
   a `Sheet` (`table/build.go:65`, `table/sheet.go:353-358`). Keep three tiers for each stage, each with
   its own key: the cells laid out, the rows shown, and the window's lines. Size M twice. (S6-5, G3-9)
6. An open tab menu walks every row for each of its lines on every draw (`flow/menu.go:119-142`,
   `flow/act.go:123-137`). Compute the menu's facts once a draw, and use a set in `refs`. (G1-8, R2-20)
7. The sub-reads of one answer run one after another. Plausible: not timed against a real forge. GitLab
   makes five reads a merge request (`forge/gitlab.sh:376`), Azure DevOps three a pull request
   (`forge/ado.sh:317`), and GitHub one for each of five runs (`forge/github.sh:802`). 30 open changes are
   152 `glab` or 91 `az` processes. Start them in the background with a bound. (S6-7, B5-11, I3-12, R1-20)
8. The MCP tool list costs 4,100 tokens a session, and a bare `syntax` returns 147 KB
   (`serve.sh:81`, `serve.jq:66`). Require a verb, and hide the flags a person uses. Size S. (U6-8)

## Documents

The prose section carries seven medium findings: the README's contributor half (`README.md:198-336`; P1-5), sentences
kept in two documents (`docs/architecture.md:127`; P1-6), reference packed into one cell (`docs/policy.md:47`; P2-7),
research pages that repeat (`docs/integrations/gh.md:89`; P3-4), a hand index (`docs/integrations/git.md:30`; P3-5),
module headers that restate verb pages (`commit.sh:9`; P5-4), and the packaging half of
`kit/packages/kit/files/repo/.kit/1st.md:116` (U5-14). It also holds the low P2-17, P4-14, and P7-14.

## Low findings

Of 66, the items above merge 22 and the prose section holds 3. The other 41 follow by theme, each with a place.

- kittui's layout: four import edges point the wrong way (`grid/panel.go:12`; S1-12); five source files
  exceed 1,000 lines (`flow/flow.go`; S1-13); `grid.Panel` is five things in one struct (`grid/panel.go:67`;
  S1-14); code reads file formats no release shipped (`flow/views.go:47`; S1-16); four variables say who has
  the keyboard (`flow/flow.go:177`; G1-20); folds switch on the menu's words (`table/outline.go:354`; G3-18);
  three helpers are copied between packages (`palette/palette.go:69`; G4-27); the client runs kit three ways
  (`kit/kit.go:348`; G5-24); two small tables are code (`projects/tui/cmd/kittui/main.go:139`; G5-25).
- The contract: a change with no check draws "NONE" (`projects/tui/internal/flow/fields.json:142`;
  S3-10); three statements about it are untrue (`forge.sh:256`; S3-12); the README describes an
  earlier kittui (`projects/tui/README.md:4`; S1-18).
- The bash's layout: the six seams hold a provider six ways (`tracker.sh:135`; S2-12); `forge.jq` and `github.sh`
  are each several components (`forge.jq:1`; S2-13); modules call modules they do not `use` (`workspaces.sh:16`;
  S2-15); five readers parse `git worktree list` (`git.sh:53`; B2-28); the removal walk is written three times,
  plausible (`region.sh:42`; B3-21); the release fetch is written four times (`kit/bin/kit:236`; S7-18).
- Small tables typed twice: `kit.yml`'s keys (`settings.sh:55`; B1-17); a reference's pattern, three ways that
  disagree (`commit.sh:123`; B2-13); the tutorials' ordering rule (`bin/tutorials:75`; T1-13); the kinds'
  globs in the Cursor rule files (`kit/packages/agents/cursor/files/repo/.cursor/rules/kit-just.mdc:3`;
  R3-34); the settings' defaults, in prose and not in the schema (`docs/apps.md:63`; D2-13).
- Tests: four fake kits re-implement kit's protocol (`flow/testdata/fake-kit:140`; S4-9); screen goldens repeat
  the chrome, and the form's pin a function only tests call (`testkit/testkit.go:193`; S4-10, R2-62); a catch-all
  route answers any query (`tests/forge-conformance.bats:151`; S4-11); 64 tests install kit as set-up
  (`tests/kit.bats:15`; S4-12); `docs/testing.md:8` leaves out part of the gate (S4-13); jq that shapes rows sits
  inline in bash (`flow.sh:465`; S2-14); the checks cell's test pins a count, not a name (`tests/flow.bats:820`;
  B6-12, R1-46); three files lack bats' minimum-version line (`tests/dependencies.bats:234`; B7-26); six welcome
  and terminal cases have no test (`tests/terminal.bats:551`; B8-19); the GitLab and Azure DevOps defects pass
  their test files (`tests/forge-ado.bats:179`; B5-21); `testkit.Drive` treats a batch unlike one command
  (`testkit/testkit.go:68`; G5-23); ajv never validates the house package (`bin/ci:28`; R3-36).
- Time: builds and releases spend a request on who the caller is (`builds.sh:22`; S6-8);
  `kit flow --marks` reads marks no app draws (`marks.sh:28`; S6-9); nothing removes kept JSON, plausible
  (`flow.sh:1211`; S6-10); the opener reads its folder twice a frame (`opener/open.go:157`; G5-18).

## Done well, leave alone

- kittui's package graph: layered, with no cycle, and no screen imports another.
- `source.Load`, `source.Poll`, `shell.Layers`, and `table.Overlays`: small, generic, and tested with a clock.
- The catalog reader: it refuses unknown keys and names every fault at once.
  27 of 32 stages are drawn from the catalog alone.
- `table.Sheet`: the palette is 647 lines and gets presets, sort, group, filter, and selection.
- `glyphs.json` with `kit generate`, and `terminals.json` with its one-call readers.
- The loader, `use`, the verb header as data, and the verb preamble, which should not be folded into one call.
- The forge contract: four answers, versions, `lacks`, and a snapshot shared across processes.
- `yaml.sh`'s cache by the file's text, `materialize:hydrated`, and the one `sed` in `bin/kit`.
- `helper:isolate`, the world helpers, a `fake-tool` that fails an unrouted call, and `tests/jq.bats`.
- The rule at `bin/ci:79` that fails any function under 100.0%, and each cost test's structural half.

## Work items

The gate comes first, because every later move leans on the tests. The contract test makes each change
that crosses kit and kittui safe. Items 4 and 5 change what kit prints, so they land before v0.1.0 fixes
that shape. After the release the app manifest comes first, because the catalog and the fake kits read
it. Flow moves onto `Sheet` once its builders and chrome have gone, and the row cache is then written
once. "Before" and "after" mean the first release. S is under a day, M a few days, L a week or more.

1. Make the suite green: the six `bot-*` calls. Covers R3-2, B3-12, S2-17. Size S. Depends on nothing. Before.
2. Make the gate honest: `needs <tool>`, work counted in place of time, a fake `gh` for three
   tests, a fuller `helper:isolate`, one assertion a line. Covers S4-6, S4-3, G3-5, S1-17,
   G1-17, U7-16, R3-14, R3-15, R3-16, B7-26, G5-23, R3-36. Size M. Depends on nothing. Before.
3. Hold kittui's fixtures and catalog to kit: the bats contract test, regenerated fixtures, a
   syntax fixture for every verb. Covers S4-1, S3-3, G2-5, R2-36, U1-12, S4-7, S3-13, G6-17,
   R2-42, S3-10, B6-12, R1-46. Size S, then M for the forge stages. Depends on 1. Before.
4. kit prints the links of issues and changes. Covers S1-1, S3-1, G2-2. Size M. Depends on 3. Before.
5. Fix the stage document's shape: a `contract` number, and one envelope for every stage. Covers
   S3-2 and the envelope of S3-6. Size S for the number, M for the envelope. Depends on 3. Before.
6. The small bash speed fixes: `use` without a fork, the forge's context kept once, cell helpers that set a
   variable. Covers S6-6, S6-3, S2-3, S6-8, S6-9, and the first step of S6-1. Size S. Depends on nothing. Before.
7. Take kit off kittui's update loop, and start its opening calls at once. Covers
   G5-7, G4-14, G5-18, and the first step of S6-4. Size S. Depends on nothing. Before.
8. Test the verbs that change the forge on their failures, then on each forge. Covers S4-8,
   B5-21, B8-19. Size S, then M. Depends on 2. Before for settle and close, after for the rest.
9. Delete the code for file formats no release shipped, and the exports only tests call. Covers
   S1-16, R2-62. Size S. Depends on nothing. Before: after v0.1.0 someone may hold such a file.
10. One hand-off, and `kit workspace` on `apps:main`. Covers S2-9, B8-11, B6-14, S3-6, S8-3. Size
    S, then M. Depends on 5 for `kit workspace`. Before for the hand-off, after for the rest.
11. One app manifest, `apps.json`. Covers S3-4, S8-2, S1-9, S2-8, S4-9. Size M. Depends on 10. After.
12. The catalog: shared fields, a glyph and color for each stage, a derived legend, glyphs by name.
    Covers S1-7, S3-7, S1-3, S3-5, G2-4, S8-6, S3-11, R2-64, D2-13. Size M. Depends on 3 and 11. After.
13. kit prints the words kittui derives, the Go builders go, the stage roster is a table, and `flow.sh` is
    split. Covers S3-8, G2-7, S3-15, B6-13, S2-7, and the jq table of S6-1. Size M. Depends on 4 and 12. After.
14. The forge layer: the contract as one table, shared provider helpers, one `boards.sh`, and `forges.json`.
    Covers S2-5, S4-5, S2-6, B4-15, S2-13, S2-12, S2-1, S2-2, B5-17, I3-9, S2-4, I5-6, S8-14, S2-16, I2-5, I4-16.
    Size M. Shared with items 5 and 12 of the integrations section. Before for `boards.sh`, after for the rest.
15. Test worlds as data: shared helpers, a directory for each world, fixtures from the schemas,
    one fake kit, pane goldens, goldens of the shipped welcome. Covers S4-4, S4-2, I1-1, I2-1,
    I3-8, I4-8, I5-9, S4-10, S4-11, S4-12, S4-13, U3-14, S2-14. Size M, and L to move all 351
    fixtures. Depends on 14. Shared with item 13 of the integrations section. After.
16. kittui's small moves: import edges, the `Source` struct, renderers, large files. Covers S1-12, S1-11, S3-14,
    R2-63, S1-13, G4-27, G3-18, G5-24, G5-25, G1-20, S1-18, S3-12. Size S each. Depends on nothing. After.
17. `shell.Chrome`, `tabs.Frame`, and the tab menu as one table. Covers
    S1-4, G6-9, S1-5, G1-19, G1-8, R2-20. Size M. Depends on 16. After.
18. Flow onto `Sheet`. Covers S1-2, G3-10, S8-17, S1-8, S1-6, S1-14,
    S1-15, G6-23, S1-10, S3-9. Size L. Depends on 13 and 17. After.
19. Three cache tiers for each stage. Covers S6-5, G3-9. Size M twice. Depends on 18. After.
20. The larger performance work: a compiled grammar, one opening call, sub-reads in parallel, a smaller tool
    list. Covers S6-2, S6-4, S6-7, B5-11, I3-12, R1-20, S6-10, U6-8. Size M. Depends on 6 and 7. After.
21. Bash moves: verbs' logic in modules, one `refuse` function, the small tables. Covers S2-10, B3-21, S8-10,
    S2-15, B2-28, S7-18, B1-17, B2-13, T1-13, R3-34, S2-11, B7-25, S7-19. Size M. Depends on nothing. After.
22. One walk of the form's grammar, and `Row.Aside` in the grid. Covers G4-13, G4-9. Size M. Depends on
    nothing. After. These are items 4 and 13 of the kittui section, which fixes the form's panic first.

The integrations section holds I3-1, I1-5, I4-7, I5-7, I5-4, and I5-5, in its items 4, 12, 14, and 15.
