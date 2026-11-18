# The plans against the code

The 17 plans under `docs/superpowers/plans/` hold 119 tasks. Read against the code at `0e76266c`, 84 are built,
7 are built in part, and 28 are not built. A state is judged from the code and its tests, never from a checkbox,
and no test was run. The open tasks are in six plans: Release readiness, Contracts, Entities first-release
decisions, Tutorials 2, Bots 1, and one task of Apps' tabs. [The review's page](2026-11-12-review.md) says which
of its plan items those tasks already cover.

## The first nine plans

These are the first nine plans by file name, 56 tasks, read against the code at `0e76266c`. A ticked box counted for
nothing. A task is built when the code and the tests it names are there. It is "built, another way" when later work
delivers the same result in a different shape; the last column then says how. Paths are from the root of the tree.

Two plans are not built at all, Contracts and Entities first-release decisions: 11 tasks. One more task is not
built, and four are built in part. The other 40 are built.

### 2026-11-06-tutorials-index.md

It builds the tutorials site, its generated catalogue, `kit tutorials`, and kittui's tutorials screen.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. The site, `projects/tutorials` | built | `projects/tutorials/vite.config.ts:26` | Nothing. The check of `dist/` is `verify` in `projects/tutorials/src/build.ts:46`, not `scripts/verify-dist.mjs`. |
| 2. The catalogue, generated | partly | `bin/tutorials:91` | The refusal of two pages with one id. A site page `same/index.mdx` and a shipped page `same.md` are both listed and it exits 0, as a run in scratch showed. No test covers it. |
| 3. The verb, `kit tutorials` | built | `kit/bin/kit-tutorials:5` | Nothing. |
| 4. The screen, `internal/tutorials` | built | `projects/tui/internal/tutorials/tutorials.go:179` | Nothing. Audiences are filters of a table now, not tabs, so the tab's test and `tutorials-ui.golden` went by design. The gate holds every statement covered (`bin/ci:79`). |
| 5. Wiring the screen into kittui | built | `projects/tui/cmd/kittui/main.go:94` | `projects/tui/README.md:25` and `:274` still say the cards are tabbed by audience. |

### 2026-11-08-workspaces-1-kit-workspaces.md

It builds `kit workspaces`: the workspace file, members and their checkouts, the startup rule, and the edits.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. Move the desk walker to `git.sh` | built | `kit/modules/bash/git.sh:15` | Nothing. |
| 2. Members and checkouts | built | `kit/modules/bash/workspaces.sh:252` | Nothing. |
| 3. The verb, listing and showing | built | `kit/bin/kit-workspaces:5` | Nothing. An option with a value is `--show=<workspace>` now. |
| 4. The startup rule | built | `kit/modules/bash/workspaces.sh:626` | Nothing. |
| 5. Editing the file | built | `kit/modules/bash/workspaces.sh:830` | Nothing. |
| 6. The page, and the gate | built | `docs/workspaces.md:1` | Nothing. |

### 2026-11-08-workspaces-2-the-books-control.md

It makes the title's workspace control in kittui, has the root load and switch the workspace, and shows a group in
Welcome.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. `kit workspaces --current --json` carries what the control needs | built | `kit/modules/bash/workspaces.sh:692` | Nothing. |
| 2. kittui reads the workspace from kit | built | `projects/tui/internal/kit/workspace.go:59` | Nothing. |
| 3. `shell.BooksMenu`, the control | built | `projects/tui/internal/shell/books.go:96` | Nothing. |
| 4. Welcome's title is the control | built | `projects/tui/internal/welcome/welcome.go:169` | Nothing. |
| 5. The root loads the workspace, tells the screens, and switches | built | `projects/tui/internal/screens/screens.go:218` | Nothing. |
| 6. Welcome over a group shows every member's checks together | built, another way | `projects/tui/internal/welcome/members.go:23` | Nothing. kit judges the whole group in one read, `kit --workspace=<group> welcome --checks`. Go has no `compose`, and the plan's six tests of it do not exist. |
| 7. Flow's title is the control | built | `projects/tui/internal/flow/flow.go:207` | Nothing. |

### 2026-11-09-workspaces-3a-kit-flow-across-a-workspace.md

It makes `kit flow` draw every stage across a workspace's cloned members, and adds a stage that lists the members.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. Members, their checkouts, and the merge | built | `kit/modules/bash/across.sh:37` | Nothing. |
| 2. One stage across a workspace | built | `kit/modules/bash/across.sh:161` | Nothing. The option is kit's, before the verb: `kit --workspace=<w> flow`. |
| 3. The repos stage | built, another way | `kit/bin/kit-workspace:251` | Nothing. It is `kit workspace repos`, not `kit flow repos`. |
| 4. The picture, marks, and quota across a workspace | partly | `kit/modules/bash/across.sh:221` | The code is there, and `--me` now refuses in its own words (`kit/bin/kit-flow:289`). One test the plan names is not: a `--quota` that passes over a fake `gh`. Only the merge (`tests/across.bats:311`) and a read that fails (`tests/across.bats:340`) are tested. |

### 2026-11-09-workspaces-3b-kittui-flow-across-a-workspace.md

It makes kittui's Flow draw a group: every tab's rows from every member, a member field, a repos tab, and acting per
member.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. Flow's reads span the workspace kit says | built | `projects/tui/internal/kit/kit.go:36` | Nothing. |
| 2. Every stage's rows across the members | built | `projects/tui/internal/flow/flow.go:1115` | Nothing. |
| 3. `member`, a field of every stage | built | `projects/tui/internal/flow/fields.json:48` | Nothing. |
| 4. The repos tab | partly | `projects/tui/internal/flow/repos.go:20` | The tab is built, as the first of the Repositories app. Its count per other tab, and the link that opens that tab filtered to the member, are not: there is no `countOf` or `onlyTo`, and `projects/tui/internal/flow/repos_test.go:106` pins that the tab counts no other tab. This was dropped on purpose when the tabs moved into apps (#138). Decision 5 of the workspaces spec still asks for the counts. |
| 5. Acting from a row runs in its member | built | `projects/tui/internal/flow/act.go:123` | Nothing. |

### 2026-11-10-apps-tabs-read-kit.md

It makes each kittui tab one catalog entry that names the kit command printing its rows, and removes what the old one
picture left.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. A schema names its command, and table reads its records | built | `projects/tui/internal/table/read.go:61` | Nothing. |
| 2. What #138 left of the one picture goes | built | `projects/tui/internal/flow/rows.go:532` | Nothing. |
| 3. Every stage is read as its catalog entry says | built | `projects/tui/internal/flow/rows.go:325` | Nothing. |
| 4. kit flow's words reach every app | built | `projects/tui/internal/flow/apps.go:129` | Nothing. |
| 5. Platform's toolchains tab | built, another way | `projects/tui/internal/flow/fields.json:1131` | Nothing. It reads `kit platform toolchains --json`, a staged command, not `kit toolchains --json`. |
| 6. Platform's tools tab | built, another way | `projects/tui/internal/flow/fields.json:1163` | Nothing. It reads `kit platform tools --json`. |
| 7. `kit policy --rules`, and Trust's policy tab | built | `kit/bin/kit-policy:79` | Nothing. The tab reads `kit audit policy --json` (`projects/tui/internal/flow/fields.json:1066`), which lists what `kit policy --rules` prints. |
| 8. Add to Pull Request… asks kit for the caller's pull requests | not built | `projects/tui/internal/flow/act.go:169` | All of it. `mine()` still reads the screen's own `changes` stage, and there is no `pullsMsg`. The Issues app has no changes tab, so its line is always dim. It acts in Flow alone, once changes has loaded. |
| 9. A tab or an app with nothing says so, and offers only what can apply | partly | `projects/tui/internal/flow/host.go:43` | A dialog is still titled by the stage's whole name: `Name()`, and `projects/tui/internal/flow/legend.go:247`, give `audit/policy legend`, not `policy legend`. The other rules are met or have nothing to act on: no tab is planned (`projects/tui/internal/flow/apps_test.go:132`), no app is empty, and a tab never marked offers no Watch (`projects/tui/internal/flow/menu.go:50`). |
| 10. `kit tui --app <app> [<tab>]`, and the README | built, another way | `projects/tui/cmd/kittui/main.go:86` | Nothing. The owner's other choice was taken: each app has its own verb, and `kit platform tools` opens Platform on tools. `kit tui` takes no `--app`. |

Every row of the plan's table "Tabs that need a kit stage first" now has its stage: all 32 catalog entries name a
command.

### 2026-11-10-contracts.md

It holds kit's public surface by tests: snapshots of each verb's syntax and the MCP tools, the JSON kittui reads, the
docs' claims, and exit statuses.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. A snapshot helper, and every verb's syntax | not built | `tests/syntax.bats:283` | All of it: `snapshot`, `KIT_SNAPSHOTS`, `tests/snapshots/verbs.tsv`. The older test checks only the fixtures that exist, and 12 verbs have none: assign, close, facts, gather, ready, settle, trust, tutorials, unassign, uninstall, workspace, workspaces. |
| 2. The MCP surface | not built | `kit/bin/kit-serve:20` | All of it: no snapshot of `tools/list` or `resources/list`, and no test that each verb is a tool or is named as withheld. |
| 3. The JSON kittui reads | not built | `projects/tui/internal/flow/rows.go:51` | All of it: `shape`, `same-keys`, `fields-hold`, `carries`, and `pr.ref`. `projects/tui/internal/flow/testdata/changes.json` still lacks `fork` and `pushed`. The plan counts 13 stages; the catalog has 32. |
| 4. The commands the docs name | not built | `kit/bin/kit-syntax:8` | All of it: `tests/claims.bats` and its awk and jq. `kit syntax --match`, which it calls, exists. |
| 5. Settings, paths, lists, and counts | not built | `docs/modules.md:253` | All of it. What it would catch still stands: `docs/modules.md` lists 11 of the 17 jq modules, and `docs/features.md:266` says "two checks". |
| 6. Exit statuses | not built | `tests/exits.bats:7` | The test of the rule, and six `Exits` lines. `kit/bin/kit-check:26`, `kit/bin/kit-gate:22`, `kit/bin/kit-hydrate:26`, and `kit/bin/kit-update:38` name no 2. `kit/bin/kit-help:24` and `kit/bin/kit-serve:44` name no 1. |

### 2026-11-10-entities-first-release-decisions.md

It settles the entities spec's four first-release decisions: full references, a person's file by reach, one contract
for the seams, a signable verdict.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. Every row kit prints carries its reference, and a forge's row its page | not built | `kit/modules/jq/workspace.jq:32` | All of it. There is no `reference.jq`, no row has `reference`, and `kit workspace`'s rows keep `key` and `row:<stage>/<key>` links. |
| 2. kittui keys and links rows by kit's references | not built | `projects/tui/internal/flow/rows.go:434` | All of it. There is no `internal/reference`, and `originOf` still builds a page's address in Go. |
| 3. The person's file, by reach, with each key's kind and the system toolchain | not built | `kit/modules/bash/toolchain.sh:392` | All of it: `config.sh`, `config.yml`, `docs/configuration.md`, and the schema's marks. The system toolchain is still read from `~/.kit/settings.yml`. |
| 4. One contract for the five seams, and a suite that holds every provider to it | not built | `kit/modules/bash/forge.sh:43` | `kit/modules/seams.json`, `docs/seams.md`, `tests/seams.bats`, and a conformance test of `require` and `pr-set-body`. Two parts are already held elsewhere: each seam's header against its provider template (`tests/template.bats:281`), and `pr-here` and `pr-last-for-branch` on a forge that fails (`tests/forge-conformance.bats:1751`). |
| 5. `kit ci --json` prints its verdict as an unsigned in-toto statement | not built | `kit/bin/kit-ci:5` | All of it: `--json`, `verdict.sh`, and `policy:digest`. |

### 2026-11-10-fail-closed.md

It makes a read, a sub-command, or a check that fails stop its verb with exit 1, and has CI judge a branch by its
base's policy.

The four scans of Tasks 1 to 3 were run here against the tree, and each printed nothing.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1. `list:read`, and every `< <(` | built | `kit/modules/bash/1st.sh:393` | Nothing. Its scan is `tests/modules.bats:29`. |
| 2. A function that leaned on errexit | built | `tests/modules.bats:42` | Nothing. |
| 3. Two idioms that hide a status | built | `tests/modules.bats:53` | Nothing. |
| 4. The forge seam's contract, and the test that holds every provider to it | built | `kit/modules/bash/forge/gitlab.sh:672` | Nothing. |
| 5. What the verbs do with a forge that cannot answer | built | `kit/modules/bash/facts.sh:114` | Nothing. The plan's test in `tests/linked.bats` has another title, at line 22. |
| 6. A check that classified or read nothing says so | built | `kit/modules/bash/context.sh:102` | Nothing. |
| 7. One exit contract for the verbs that print JSON, and kittui's Runner | built | `projects/tui/internal/kit/kit.go:316` | Nothing. |
| 8. CI judges a pull request by its base branch's policy | built | `kit/modules/bash/policy.sh:441` | Nothing in the task. Outside it, the delivered workflow still takes the kit's version from the branch's `kit.yml` (`kit/packages/github/ci/templates/repo/.github/workflows/kit-ci.yml:75`), which the review page lists as open. |

### The count of the first nine

"Built" includes the five tasks built another way.

| Plan | Tasks | Built | Partly | Not built |
| --- | --- | --- | --- | --- |
| 2026-11-06-tutorials-index.md | 5 | 4 | 1 | 0 |
| 2026-11-08-workspaces-1-kit-workspaces.md | 6 | 6 | 0 | 0 |
| 2026-11-08-workspaces-2-the-books-control.md | 7 | 7 | 0 | 0 |
| 2026-11-09-workspaces-3a-kit-flow-across-a-workspace.md | 4 | 3 | 1 | 0 |
| 2026-11-09-workspaces-3b-kittui-flow-across-a-workspace.md | 5 | 4 | 1 | 0 |
| 2026-11-10-apps-tabs-read-kit.md | 10 | 8 | 1 | 1 |
| 2026-11-10-contracts.md | 6 | 0 | 0 | 6 |
| 2026-11-10-entities-first-release-decisions.md | 5 | 0 | 0 | 5 |
| 2026-11-10-fail-closed.md | 8 | 8 | 0 | 0 |
| Total | 56 | 40 | 4 | 12 |

## The last eight plans

These are the tenth to the seventeenth plan under `docs/superpowers/plans/`, in file-name order, read whole and held
against the tree at `0e76266c`. A state is judged from the code and its tests, never from a checkbox. No test was run:
"built" means the code and a test that names the behavior are both there. Paths are from the tree's root. Where a
later ruling changed what a task asked for, the row says so, and the code as it stands is the reference.

### 2026-11-10-planned-tabs.md

Each of kittui's 20 planned tabs reads a kit stage: forge contract 4, six app verbs, and a catalog entry per tab.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 Forge contract 4 declares the new features | built | `kit/modules/bash/forge.sh:290` | nothing; the contract is 6 today |
| 2 The app verbs' runner, and kit platform | built | `kit/modules/bash/apps.sh:34` | nothing |
| 3 kit policy --rules | built | `kit/modules/bash/policy.sh:138` | nothing |
| 4 kit issues: milestones and iterations | built | `kit/modules/bash/apps/issues.sh:29` | nothing |
| 5 kit changes: reviews, checks, and merged | built | `kit/modules/bash/apps/changes.sh:30` | nothing |
| 6 kit delivery: artifacts, environments, deployments | built | `kit/modules/bash/apps/delivery.sh:29` | nothing |
| 7 kit people: people, teams, and agents | built | `kit/modules/bash/apps/people.sh:23` | nothing |
| 8 kit audit: evidence, findings, controls, waivers, policy | built | `kit/modules/bash/apps/audit.sh:34` | nothing |
| 9 The catalog reads kit | built | `projects/tui/internal/table/catalog.go:28` | nothing; the catalog moved to `internal/table` |
| 10 Every planned tab is a catalog entry | built | `projects/tui/internal/flow/fields.json:561` | nothing |
| 11 The verbs open their apps | built | `projects/tui/internal/flow/apps.go:57` | nothing |

### 2026-11-10-refusals-that-hold.md

Every verb that promises not to destroy or not to write keeps the promise: rebase, tidy, serve, regions, packages
remove, work, commit, and submit.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 kit rebase takes origin's commits, and pushes by name | built | `kit/modules/bash/git.sh:506` | nothing |
| 2 kit tidy keeps commits no remote ever had | built | `kit/modules/bash/git.sh:126` | nothing |
| 3 kit serve's contract, stated and enforced | built | `kit/modules/bash/serve.sh:637` | nothing; ruled to seven tools that read only, with `toolchains` and `tools` beside `check` and `lint` |
| 4 A region's markers are judged once, before any write | built | `kit/modules/bash/region.sh:75` | nothing |
| 5 kit packages remove leaves an edited copy | built | `kit/modules/bash/place.sh:311` | nothing |
| 6 kit work never works on the desk, nor loses a stash | built | `kit/modules/bash/issue.sh:617` | nothing |
| 7 kit commit and kit submit push by name, sign, keep the subject | built | `kit/modules/bash/commit.sh:532` | nothing |
| 8 kit serve outlives a malformed or oversized message | built | `kit/modules/bash/serve.sh:372` | nothing |

The review page lists what this plan left as it is (`docs/superpowers/reviews/2026-11-10-code-review.md:200`).

### 2026-11-10-release-readiness.md

Nothing stands between the branch and a `release/0.1.0` a stranger can install: a digest that verifies, a green gate,
a release packed from its tag and run before it is published, and true documents.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| A1 The packed tarball's digest verifies | not built | `bin/release:116` | `pack` still calls `release:digest`, which no file defines; `file:digest` is at `kit/modules/bash/file.sh:175`. The digest check, the refusal, and both tests |
| A2 The gate is green at HEAD | built, overtaken | `tests/issues-underway.bats:250` | `tests/underway.bats` is gone and its legend test rewritten to match `kit/bin/kit-flow:136`. The suite was not run here |
| A3 A release is its tag, and a pre-release outlives its branch | not built | `bin/release:107` | `pack` copies the working tree; `publish` has no HEAD check and no `--verify-tag` (`:138`); `retire` deletes on branch reach alone (`:160`); no `tag-checkout` helper |
| A4 The packed release runs before it is published | not built | `bin/release:37` | `kittui --version`, `bin/release smoke`, `publish <tag> <directory>`, and `release.yml`'s pack, timeout, and concurrency |
| A5 The minimums are checked, and a remedy names no tool manager | partly built | `kit/libexec/kit-call:24` | built: the bash 4.4 refusal and `guard:remedy` (`kit/modules/bash/1st.sh:606`). Left: `template.jq:169` still uses `indices`, bytes on jq 1.7; git is not held to 2.31 (`kit/modules/bash/welcome.sh:856`); the jq 1.7 test; the README's git minimum |
| A6 CI covers what ships, and a test stands apart from its caller | not built | `kit/packages/github/ci/templates/repo/.github/workflows/kit-ci.yml:28` | `macos.yml`; origin's HEAD, concurrency, and `pull_request_target` in the template; Dependabot for gomod and npm; `validate` in `bin/ci`; the unsets in `helper:isolate-in`; the test-line fixes |
| A7 kit update holds across two packed releases | not built | `kit/bin/kit-update:66` | a dropped package still stops at `resolve:require`; `place:retire` reads the manifest alone (`kit/modules/bash/place.sh:371`); the test |
| A8 A release needs its changelog entry | not built | `bin/release:133` | the `changelog` key, `kit release`'s refusal, and notes from the entry |
| A9 The documents that describe the release are true | not built | `AGENTS.md:16` | `SECURITY.md`; `libexec/kittui-<os>-<arch>` and `projects/tui/` in `AGENTS.md` and `README.md:253`; the Release section; the gate's list |
| Part B: the owner's checklist, 7 steps | not checkable | `.github/workflows/release.yml:61` | acts on GitHub and other repositories; the one step in this tree, an attestation in `release.yml`, is not there |

### 2026-11-10-tutorials-2-published.md

Every link `kit tutorials` opens leads to a page: the site is built and published per line, its build refuses broken
pages, and kit and kittui say only what happened.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 kit tutorials links to one site, and exits as its header says | built | `kit/modules/bash/tutorials.sh:27` | nothing |
| 2 The build checks what it built | built | `projects/tutorials/src/build.ts:46` | nothing |
| 3 Links from the page, a not-found page, and `<Since>` | built | `projects/tutorials/src/reader.tsx:44` | nothing |
| 4 bin/tutorials refuses a page it cannot place, and gains site, publish, retire | not built | `bin/tutorials:96` | `catalogue` is the one subcommand; the three refusals (`:69` reads `top: "true"` as true); `site`, `publish`, `retire`; their tests; the README's `bin/` row (`README.md:257`) |
| 5 The workflow | not built | `.github/workflows/retire-pre-releases.yml:33` | `.github/workflows/tutorials.yml`; the `retire the tutorials` step; the two README passages |
| 6 kittui's screen says what happened, and takes a list's keys | partly built | `projects/tui/internal/tutorials/tutorials.go:190` | built: `--tag=<audience>`, and the page keys through the table (`projects/tui/internal/table/keys.go:46`). Left: `reachable` and its HEAD before the browser (`tutorials.go:700`), the refusal of a card with no link, the "Not in the catalogue" notice, and the four tests |
| 7 The first real tutorial | not built | `kit/modules/tutorials.yml:22` | `first-change/index.mdx` and `refusals.mdx`; the links from What's new and the changelog |
| The owner's checklist, 5 steps | not checkable | none | Pages and DNS, outside the tree; it needs tasks 4 and 5 first |

### 2026-11-10-workspaces-4-says-what-it-does.md

Every workspace input kit accepts does what its page says or is refused by name, a failed member is seen and counted,
and the docs say what is built.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 The workspace file is checked wherever it is read | built | `kit/modules/bash/workspaces.sh:411` | nothing |
| 2 One startup rule for every verb | built | `kit/modules/bash/workspaces.sh:671` | nothing |
| 3 The registry survives two writers, and has verbs to manage it | built | `kit/modules/bash/workspaces.sh:775` | nothing; options are `--rename=<name>`, by the owner's rule |
| 4 A member that fails is visible and counts | built | `kit/modules/bash/across.sh:490` | nothing; JSON exits 1 too, as Fail closed ruled |
| 5 kittui's workspace menu and repos tab | built | `projects/tui/internal/flow/repos.go:29` | nothing; later work added Open Repository… and Manage…, which act (`projects/tui/internal/shell/books.go:53`) |
| 6 The docs and the spec say what is true | built | `docs/workspaces.md:253` | nothing |

The plan's closing list, spec steps 4 to 7, is not built and is no task of it.

### 2026-11-11-terminal-checks.md

`kit welcome` judges the terminal kit runs in, from its settings and from probes, for ten terminals, with a docs page.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 The findings table and its judge | built | `kit/modules/jq/terminal.jq:49` | nothing |
| 2 terminal.sh: detection, readers, bad, kept, and the checks | built | `kit/modules/bash/terminal.sh:463` | nothing |
| 3 Probes, and the hand-off that carries them | built | `kit/modules/bash/terminal.sh:380` | nothing; the real-terminal trial of step 5 leaves no trace to check |
| 4 kit welcome judges the terminal, keeps, and folds what holds | built | `kit/modules/bash/welcome.sh:540` | nothing |
| 5 iTerm2 | built | `tests/terminal.bats:280` | nothing; the kitty fix is the `apps-change-keys` finding's, not a probe row |
| 6 Terminal | built | `tests/terminal.bats:361` | nothing; the by-hand check of the keys leaves no trace |
| 7 Ghostty and kitty | built | `tests/terminal.bats:409` | nothing |
| 8 WezTerm, Alacritty, and Warp | partly built | `kit/modules/bash/terminal/wezterm.sh:21` | WezTerm's `mouse` finding: the reader prints no `mouse_reporting_bound` and `terminals.json` has no row; the spec lists it (`docs/superpowers/specs/2026-11-11-terminal-checks-design.md:335`) and `docs/terminals.md:155` has it as prose |
| 9 Windows Terminal, the Windows console, and Tabby | built | `kit/modules/bash/terminal.sh:85` | nothing |
| 10 kittui folds what holds and offers keep | built | `projects/tui/internal/welcome/welcome.go:131` | nothing; a failed finding offers copy and keep, not later and keep (`projects/tui/internal/welcome/terminal_test.go:66`) |
| 11 docs/terminals.md | built | `tests/terminal.bats:615` | nothing |

### 2026-11-11-verb-headers-through-a-template.md

A verb's header has one schema, the `verb` template, which `kit lint` holds and kit help, syntax, and serve read.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 A block also ends at a reserved line | built | `kit/modules/jq/template.jq:116` | nothing |
| 2 The verb template, the readers, and the 52 headers | built | `kit/modules/bash/help.sh:31` | nothing; all 52 files under `kit/bin/` hold `# Usage:` and `# Arguments:` |
| 3 kit new verb makes the header from the template | built | `kit/modules/bash/new.sh:688` | nothing |

### 2026-11-12-bots-1-kit-bots.md

A `kit bots` verb adopts a GitHub App as the person's bot, keeps its key in the system's secret store, mints tokens
for the repository, runs a command as the bot, and tells the bot from its person.

| Task | State | Evidence | What is left |
| --- | --- | --- | --- |
| 1 The secret store | built | `kit/modules/bash/secrets.sh:32` | nothing |
| 2 The forge seam's bot-accounts | built | `kit/modules/bash/forge/github.sh:1289` | nothing; a sixth call, `bot-installations`, is there too |
| 3 bots.sh and kit bots, --add, --remove | not built | `kit/modules/bash/forge.sh:701` | the seam's calls have no caller: no `kit/modules/bash/bots.sh`, `kit/bin/kit-bots`, or `tests/bots.bats`; no `bot` key in `settings.sh` or the schema |
| 4 --check and token | not built | `kit/modules/bash/forge.sh:702` | `bots:check`, `bots:token`, and their tests |
| 5 run | not built | `kit/modules/bash/forge.sh:706` | `bots:run`, the `gh` shim, the credential helper, the revoke at exit |
| 6 kit tells the bot from its person | not built | `kit/modules/bash/forge.sh:700` | `forge:me` under `KIT_BOT_LOGIN`, `forge:principal`, its three callers, the `Agent:` trailer in `commit.sh` |
| 7 The Welcome check | not built | `kit/modules/bash/welcome.sh:517` | the `bot` check and `welcome:bot` |
| 8 Docs, the gate, and empowerite-jig | not built | `docs/superpowers/specs/2026-11-12-bots-design.md:3` | the Bots section of `docs/features.md`, `docs/integrations/gh.md`, the spec's status, the trial against the real App |

### The count of the last eight

| Plan | Tasks | Built | Partly | Not built |
| --- | --- | --- | --- | --- |
| 2026-11-10-planned-tabs.md | 11 | 11 | 0 | 0 |
| 2026-11-10-refusals-that-hold.md | 8 | 8 | 0 | 0 |
| 2026-11-10-release-readiness.md | 9 | 1 | 1 | 7 |
| 2026-11-10-tutorials-2-published.md | 7 | 3 | 1 | 3 |
| 2026-11-10-workspaces-4-says-what-it-does.md | 6 | 6 | 0 | 0 |
| 2026-11-11-terminal-checks.md | 11 | 10 | 1 | 0 |
| 2026-11-11-verb-headers-through-a-template.md | 3 | 3 | 0 | 0 |
| 2026-11-12-bots-1-kit-bots.md | 8 | 2 | 0 | 6 |
| Total | 63 | 44 | 3 | 16 |

The two owner's checklists are not counted. A new plan must not repeat the 44 built tasks. The 19 open tasks are
already written, test first, in four plans: Release readiness (8), Bots 1 (6), Tutorials 2 (4), and Terminal checks
(1). A new plan should name those tasks, not rewrite them, and should take its line numbers from the tree as it is now,
since the plans' own are stale: `tests/underway.bats` is `tests/issues-underway.bats`, `kit/bin/kit` is a POSIX sh
loader over `kit/libexec/kit-call`, and kittui's tutorials screen is drawn by `internal/table`.
