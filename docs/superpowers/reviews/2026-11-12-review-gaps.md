# What is promised and not built

No. Of 174 promises checked, 123 are built (71 percent), 22 are built in part, and 29 are not built. The README and
`docs/features.md` are 87 percent built (88 of 101), the seven specs are 52 percent built (35 of 67), and six
items of the release-readiness plan, which the tag waits on, are not built. The holes cluster in five places:
the release itself, GitLab and Azure DevOps beside GitHub, steps 4 to 7 of the workspaces spec, the four decisions
the entities spec gives the first release, and the bots spec, which is dated the day of the snapshot.

A promise here is one sentence, bullet, or table of the README or `docs/features.md` that says what kit does, or one
goal or design decision of a spec. "Built" means the code is in the snapshot and no finding says it breaks the
promise. I opened the code for every row below and ran none of it. A bug in a built feature belongs to the other
sections.

Built, partly, and not built, by source: README and `docs/features.md` 88, 12, 1; tutorials spec 7, 2, 4;
workspaces spec 12, 2, 8; components spec 4, 4, 0; entities spec, its four first-release decisions, 0, 1, 3;
planned-tabs spec 5, 0, 0; terminal-checks spec 7, 0, 0; bots spec 0, 1, 7; release-readiness plan 0, 0, 6.

In the table, `bash/` is `kit/modules/bash/`, `jq/` is `kit/modules/jq/`, `tui/` is `projects/tui/internal/`, and
`welcome/` is `kit/packages/kit/files/repo/.kit/welcome/`. A source under `docs/superpowers/` goes by one word:
`tutorials`, `workspaces`, `components`, `entities`, and `bots` are the specs of those names, and `readiness` is
`plans/2026-11-10-release-readiness.md`. A number in square brackets says how many promises a row holds, when
more than one. A finding id in round brackets is not of kind "gap".

| Promise | Source | State | Evidence | Findings |
| --- | --- | --- | --- | --- |
| `brew install empowerite/tap/kit`, the README's one install line | README.md:78 | not built | no code: `bin/release` and the three workflows hold no formula step; the tap was empty on 11-10 (docs/superpowers/reviews/2026-11-10-code-review.md:66); planned at readiness:341, in the tap's repository | D1-2, S7-2, U5-4, R3-26, (R3-6) |
| `bin/release publish` packs the tarball and its digest | README.md:326 | partly | bin/release:116 calls `release:digest`, which no module defines (`file:digest` is bash/file.sh:175), so the `.sha256` holds no digest and `pack` exits 0 | P8-1, (R3-1) |
| The tutorials site is published: a copy per minor line at `kit.empowerite.dev`, `main`'s copy on every push, a pre-release's copy removed when it retires | tutorials:20, :118, :120 | not built [3] | no code: `.github/workflows/` holds `kit-ci.yml`, `release.yml`, and `retire-pre-releases.yml`, and none deploys; `bin/tutorials` has no `publish` | B8-1, R3-8, T1-1 |
| kit picks the site from its version, on a domain empowerite owns | tutorials:111 | partly | bash/tutorials.sh:27 names one host, `empowerite.github.io`, for every version; the line by version is built (tutorials.sh:31-41) | T1-1 |
| `kit tutorials` lists the tutorials and opens one | README.md:93 | partly | nine of ten ship in the kit (kit/modules/tutorials/) and open offline; `kit-tutorials`, first in the list (kit/modules/tutorials.yml:23), opens the unpublished site | B8-1, R3-8, T1-1 |
| `kit release` refuses a version with no changelog entry; the entry is the release's notes | tutorials:89, readiness:297 | not built | no code: no "changelog" in `bin/`, `kit/bin/`, or `bash/`; the entry is written (projects/tutorials/src/changelog/0.1.0.mdx); a release's notes are the mise pin (bin/release:133-135) | R3-26, P8-1 |
| The packed release runs before it is published | readiness:134 | not built | bin/release:120-139: `publish` packs and uploads; there is no `smoke` | R3-26 |
| macOS in CI; Dependabot for `go.mod` and npm | readiness:194 | not built | .github/workflows/kit-ci.yml:40, :130 and release.yml:33 say `ubuntu-latest`; .github/dependabot.yml:19 is `github-actions` alone | R3-26, R3-35, S7-21 |
| `SECURITY.md` | readiness:301 | not built | no file | R3-26, P8-1 |
| An attestation of kit's own tarball | readiness:327 | not built | no attest step in .github/workflows/release.yml | R3-26, (R3-11) |
| `kit welcome` holds git to 2.31 | readiness:171 | not built | bash/welcome.sh:330-346 asks only that `--version` runs; bash/git.sh:47 calls an option git 2.31 added | P3-12 |
| `kit update` holds across two packed releases, and drops a package the release dropped | readiness:239 | not built | tests/release.bats has four tests and none updates; kit/bin/kit-update:66 refuses the dropped package | R1-9 |
| "Any other pipeline can run it too"; `kit ci` "in any CI system" | README.md:26, docs/features.md:31, welcome/1-introduction.md:15 | partly | bash/forge/github.sh:681-694 reads `GITHUB_EVENT_PATH`, then the branch; a detached checkout on Jenkins, CircleCI, or Buildkite names no change, no variable of theirs is read, and kit/bin/kit-ci:33 always runs `kit linked` | I5-2, I4-15, D2-1 |
| `kit ci --json` prints a verdict a CI run can sign | entities:459 | not built | kit/bin/kit-ci:5: the usage is `kit ci`; no `in-toto` in `kit/bin/` or `bash/` | R3-26 |
| `kit welcome` checks your code forge logins | README.md:90, docs/features.md:170 | partly | bash/welcome.sh:454-458 keeps `github` and `gitlab` and skips any other forge, so Azure DevOps gets no check | B8-3 |
| Welcome "explains how work flows" | README.md:91 | partly | `welcome/` holds five pages; `kit work`, `kit commit`, and `kit submit` appear in 4-customize.md and 5-terms.md alone, in notes on settings and in the glossary | U3-7 |
| "The pull request body is the report" | README.md:246, kit/packages/workflow/files/repo/.kit/workflow.md:24 | partly | no verb writes a body: bash/issue.sh:561 is the one caller of `forge:pr-set-body`, and kit/bin/kit-ready:5 takes a number alone | U6-5, U4-9 |
| `kit rebase` brings a branch up to date | docs/features.md:90 | partly | bash/git.sh:497-503 aborts on any failure and names no next step; the delivered deny list refuses `git rebase` (kit/packages/agents/claude/files/repo/.claude/settings.json:6) | B2-8 |
| The adapters put the rules where each agent looks | README.md:50 | partly | every adapter sends the agent to `.kit/1st.md` (kit/packages/agents/generic/regions/repo/AGENTS.md:3), which git ignores (docs/features.md:328); Copilot on GitHub.com has no kit to place it (docs/packages/agents/copilot.md:14) | U6-9 |
| `kit work` makes a linked branch, and the merge closes the issue, on each forge | README.md:34, docs/trackers.md:50 | partly | bash/issue.sh:603 writes no `Closes` for the forge's own issue; bash/forge/gitlab.sh:451 opens the merge request with an empty description; bash/forge/ado.sh never passes `--transition-work-items`. Not run on a real GitLab or Azure DevOps | B5-2, R1-27 |
| GitHub, GitLab, and Azure DevOps: "the same picture on each" | docs/features.md:263, welcome/1-introduction.md:12 | partly | runs on GitLab and Azure DevOps carry `jobs: []` (jq/forge.jq:382, bash/forge/ado.sh:499), so "a failed job names the step" (docs/features.md:112) holds on GitHub alone; Azure DevOps needs `az login` where a token would do (bash/forge/ado.sh:261) and has no glyph (tui/flow/quota.go:21) | I2-2, I3-17, I3-6, I3-13, S3-11 |
| A repository uses more than one tracker; "others such as Jira and Linear" | docs/features.md:265, welcome/1-introduction.md:13 | partly | `kit work` and `kit linked` take `AB#4521`; the issues stage reads `forge:open-issues` alone (bash/issues.sh:69); kittui rebuilds a reference as `#<number>` (tui/flow/rows.go:475); Jira and Linear get the `web` provider, which opens pages and reads nothing (bash/tracker/web.sh:14) | G1-21, I4-15, I5-3 |
| A link opens the app built around the row's entity | docs/features.md:239 | partly | tui/flow/workspace.go:91-98 resolves a `row:` link among the stages of the row's own verb; the home tabs of Issues, Changes, and Delivery are `kit flow`'s (tui/flow/apps.go:26-30) | G2-6 |
| A tutorial's audience tags come from a closed list, checked | tutorials:150 | partly | bin/ci:69-70 holds the site's `.mdx` pages to the schema; the nine shipped pages are held to four fields (bin/tutorials:79-86) | T1-9 |
| A group by `match:` queries, by `topic:` or `label:`, by a GitHub `project:` | workspaces:113, :118, :122 | not built [3] | bash/workspaces.sh:433-435 refuses `match` and `project` by name; no `topic`, `label`, or `kit.workspace` in bash/workspaces.sh | none |
| A member with no checkout is counted from the forge; an action on one asks, then clones | workspaces:225, :245 | not built [2] | bash/across.sh:172-175 runs kit in cloned members alone; tui/flow/act.go:211-213 refuses to act where there is no checkout | none |
| A Project narrows backlog and underway; an issue shared by members appears once | workspaces:234, :238 | not built [2] | no code | none |
| Forge stages read in batches per forge and owner; resolved members kept, queries read hourly | workspaces:260, :268 | not built [1], partly [1] | bash/across.sh:172-175 runs one `kit flow` per member and stage; bash/workspaces.sh:592-616 keeps the last group and nothing else | none |
| Browse…, with groups suggested from owners | workspaces:198 | partly | Manage… and New Workspace… are built (tui/workspaces/workspaces.go:1-10); Open Repository… takes a folder (tui/shell/books.go:6); no owner is suggested, and Add an Owner's Repositories… asks `gh` alone, 1,000 at most (tui/workspaces/workspaces.go:392) | G6-20 |
| One ordered list of open controls on every screen | components:58 | partly | `shell.Layers` is used in tui/flow/layers.go and in tui/table/layers.go and sheet.go, and by no other screen | none |
| An alert stays until esc; every wait goes through `source.Clock` | components:147, :284 | partly [2] | tui/shell/notice.go:1-2: an alert "stays until a key"; notice.go:42 fades on a raw `tea.Tick` | none |
| The spec's terms replace the old names where code is touched | components:157 | partly | Go files still say "keys bar" 162 times, "preset line" 108, and "app's menu" 107 | none |
| A full reference on every row kit prints | entities:452 | not built | rows carry `ref: "#7"` (jq/forge.jq:159, :286) and links `row:<stage>/<key>` (jq/apps.jq:5); planned in plans/2026-11-10-entities-first-release-decisions.md:6 | G1-21 |
| A person's file by owner and reach; each key a setting or a preference | entities:454 | not built | nothing reads `~/.config/kit/config.yml`; the system toolchain is still in `~/.kit/settings.yml` (bash/toolchain.sh:391-393); the schema marks no key | none |
| Each seam's contract written down, JSON in and out | entities:457 | partly | the forge's is in the header of bash/forge.sh and docs/architecture.md:165-187, held by tests/forge-conformance.bats; the other seams have bash headers; nothing reads `provider: command` | none |
| `kit bots`: set up or adopt a bot, hold its permissions to its jobs, run a command as the bot | bots:37, :39, :40 | partly [1], not built [2] | six `bot-*` calls (bash/forge.sh:176-185) and bash/secrets.sh exist, with tests/forge-bots.bats and tests/secrets.bats; there is no kit/bin/kit-bots, so no command reaches them | S2-17 |
| Hand an issue to the bot; queue, claim, and ask; `kit review`; court; pick up on the desk and in CI | bots:41-45 | not built [5] | no code: kit/bin/kit-assign:5 takes `--to <login>`; there is no kit/bin/kit-review, jq/court.jq, or kit/packages/github/bot | none |

## Planned nowhere

The earlier review listed twelve such items, and R3-26 calls eight of them still in no plan. Six of the eight have a
task in the release-readiness plan and are rows above: the Homebrew formula (readiness:341), macOS in CI (:196), the
smoke test (:134), release notes (:297), `SECURITY.md` (:301), and attestation (:327). Two more of the twelve are
planned there: the upgrade test (:239), and a new body for pull request #2 (:334), which only the forge can show.
These are in no document, spec, or plan:

- `CONTRIBUTING.md` and `CODEOWNERS`. Neither file exists.
- Completion for bash and fish. kit/bin/kit-completion:5 takes `zsh` alone (U4-22).
- A live run against GitLab and Azure DevOps. Both providers are tested on fakes, tests/forge-ado.bats:9 says only a
  live organization can prove them, and no reviewer called `glab`.
- A version for the person's files. `presets.json` has one (tui/table/store.go:17). `kittui.json`,
  `search-history.json`, and `workspaces.yml` have none, and the entities plan moves `~/.kit/settings.yml` beside them.
- Paste. No Go file under `projects/tui` handles `tea.PasteMsg`, so a URL pasted into a dialog or a search types
  nothing (G1-10, G6-3).
- A screen for a terminal without a Nerd Font or two-cell emoji. A pill's ends are U+E0B6 and U+E0B4
  (tui/style/pill.go:20-21), and nothing under `projects/tui` reads `KIT_TERMINAL_PROBES` (U5-8, U5-9, U7-8).
- What is behind a row: an issue's text, a diff, a check's log, a review thread (U5-15). An act on a pull request:
  tui/flow/act.go:43-49 gives actions on the issues stage and on Packages alone (U1-11). The planned-tabs spec rules
  writes out for its tabs.
- A failed run's log, a rerun, a cancel, a pending approval, what is live where, and a link to another CI system's
  run. They are rows of the research under `docs/integrations/` and of no plan (I1-4, I2-11, I5-11).
- A deadline and a cancellation in `kit serve`. bash/serve.sh:607-611 runs a verb with no limit, so one stalled verb
  blocks every later message (B7-16, R2-9). The server also answers no `resources/templates/list` (R2-40).
- The pull request that moves a repository to the next release. README.md:67 says a pull request does it, and a
  person runs `kit --version=<release> update` in each repository (U5-16).
- The CI job without an issue for every pull request. kit/bin/kit-ci:33 always runs all four checks (U5-13).
- A deny list that stops a merge. The 13 Claude patterns are `git` commands, so `gh pr merge` passes (U6-7).
- Smaller: `kit trust --revoke` for a clone that is gone (B1-13); a word when `kit work` starts a closed issue (B2-19,
  R1-24); a check for xz, bzip2, and unzip before the kit toolchain unpacks (S7-14); a tool whose latest version kit
  cannot ask for (B7-20); Settle on a fork's pull request (S7-13); a key a release dropped, which `kit update` keeps
  (B1-9).

## Promised in the specs, unchecked

R3 left 33 of the 63 rows of the earlier Gaps tables unchecked. I checked each one that a search or one file settles.

- Workspaces, 11 rows. Five are fixed. `match` and `project` are refused by name, not ignored (bash/workspaces.sh:433).
  `kit flow` outside a repository starts on the last group and takes `--workspace=none` (kit/bin/kit-flow:293-297).
  The repos tab reads `checkouts` (tui/flow/repos.go:29, :56). `--me` with a workspace is refused in plain words
  (kit/bin/kit-flow:287-289). The Workspaces screen exists (tui/workspaces/). Five are still not built and are rows
  above. `--quota` over a group has a test of the merge alone (tests/across.bats:311). I did not read
  `docs/workspaces.md` against the code.
- Components, 8 rows. Two are fixed: seven packages import `tui/table` and `incoming` is in the catalog
  (tui/flow/fields.json:206), and nine packages handle the mouse wheel. Three are open and are rows above. Double
  click and drag have no handler; only tui/testkit/testkit.go:168 makes a drag. Not checked: the cost of a large
  table, which needs a timed run; which keys each terminal sends; and `NO_COLOR`, which no kittui code reads though
  projects/tui/README.md:309 says pills honor it.
- Entities, 5 rows. References and contracts are rows above. The tracker's keys hold no `map`
  (kit/packages/kit/files/repo/.kit/kit.schema.json), `bash/toolchain.sh` has no catalog, and no code is about
  conversation. The spec defers all three, with five more domains. `kit verify` and `kit config` do not exist.
  `kit people`, `kit delivery`, `kit audit`, and `kit platform` give four of the domains a first reading from the forge.
- Release, 6 rows; tutorials, 1; design issues, 2. The tag, CI on the pushed head, a second consumer, and the body of
  pull request #2 need the forge. No test updates across two releases. The tutorials package's coverage needs a run.
  Issues #63 and #68 are questions for the owner. Whether the manifest now meets #20 I did not check.
- Three specs are newer than the earlier review. The planned-tabs spec is built: no tab is `planned/`
  (tui/flow/apps.go:25-38), and the seam calls of its table are in bash/forge.sh:118-174. The terminal-checks spec
  is built: ten readers under `bash/terminal/`, and `--keep` and `--unkeep` (kit/bin/kit-welcome:8-9); it leaves
  multiplexers for later. The bots spec is the two rows above.
- Checked by no one: the nine rules for keys in the components spec, except where a finding of U1 to U7 or G1 to G6
  touches one, and the fields of the repos tab.

## The 74 gap findings

58 are cited above. Nine faults were found more than once: the Homebrew line (D1-2, S7-2, U5-4), the
tutorials site (B8-1, R3-8, T1-1), the missing `Closes` line (B5-2, R1-27), a build's jobs off GitHub (I2-2, I3-17),
the report (U6-5, U4-9), paste (G1-10, G6-3), the probes kittui ignores (U5-9, U7-8), the deadline in `kit serve`
(B7-16, R2-9), and the closed issue (B2-19, R1-24). The other 16 name no promise. Three are one rule the prose style
lacks (P1-10, P2-3, P4-7). Two are about tests (S4-6, S4-8). Seven are limits or checks in built code (B1-7, B4-11,
B4-19, B4-20, G3-15, R2-52, S6-10). Three are things built and not documented or not explained on screen (D1-17,
S8-8, U7-5). One is a count with no change asked (I2-13).
