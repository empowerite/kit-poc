# What became of the medium findings

The review of 2026-11-12 found 436 medium findings, counting six follow-ups. None had a second reader, so each agent
first checked every finding at the current code, then fixed what was real and small enough to test. This page says what
came of them. It follows [the page on the high findings](2026-11-12-review-worked.md).

The full gate passes at the last commit: 1,736 bats tests, every kittui package at 100 percent of statements, and
`kit check`. Nothing was run against a real forge, a CI runner or a real terminal.

## Count

17 agents each took one slice of the findings by the code it touches. The numbers are the agents' own, counting a
finding once when several share a cause. About 220 findings are fixed, in whole or in part. The rest were already
fixed by the work on the high findings, duplicates of a finding fixed, found not real, or are in the two lists below.
Each slice's triage table, with a verdict per finding id, is in the review run's scratch folder; the commits name the
  ids.

| Slice | Findings | Fixed or partly fixed | Commits |
| --- | --- | --- | --- |
| Core bash: loader, policy, commit, issue, tools | 39 | 20 | #424 to #492 |
| Forge seam and providers | 60 | 30 | #423 to #469 |
| The rest of kit's bash | 93 | 49 | #425 to #496 |
| Delivered packages | 25 | 12 | #426 to #490 |
| kittui: Flow | 55 | 19 | #505 to #530 |
| kittui: tables and grid | 27 | 13 | #519 to #522 |
| kittui: shell and forms | 29 | 15 | #500 to #542 |
| kittui: other apps | 22 | 12 | #493 to #553 |
| Documents | 40 | 25 | #497 to #547 |
| Integration research pages | 17 | 9 | #502, #544 |
| Gate, scripts and tests | 29 | 14 | #494 to #560 |

## Decisions for the owner

The agents did not guess at these. Each needs a choice, and the triage table names the options.

- **Names and words:** renaming "pull request" to "change" across help, JSON and kittui; the verb renames (workspace to
  repos, Trust and audit as one word, People's agents stage as bots); one word for each thing across kit's text.
- **Shapes that freeze at v0.1.0:** one JSON list shape across five verbs; actions as words everywhere; whether `kit
  new file` reads its path from the repository root or the working directory.
- **Commit and plan policy:** a 72-character cap for commit subjects; plans in their issues or as files under `docs/`.
- **Safety and release:** how a conflict is resolved when the deny list refuses `git rebase`; a staged path that differs
  from disk; `kit commit`'s behind-check against a deliberate untrack; whether `retire` keeps an unreachable
  pre-release; a tag ruleset and build provenance, which need the forge; Dependabot against the template's pins.
- **Providers:** the Azure DevOps default team and token-only sign-in; a third state "unwritten" in the forge
  capabilities; one GraphQL request for GitLab's merge requests; GitLab reviewer state; the tracker seam's shape.
- **kittui:** the keys bar's segment order and the quit hint; `r` as Refresh on every screen; the twelve lines of
  chrome at
  80x24; whether a preset delete asks first; the tab count showing "1 of 3"; the actions Changes offers; how the
  Customize page and wrapped columns draw; a detail pane; key glyphs for Ctrl and Alt.
- **Documents:** a Renovate manager and update workflow for kit's own version; a "how kit fits with what you have"
  page; the
  welcome introduction's lead; whether Copilot ships `copilot-setup-steps.yml`; a `glyphs: text` mode or dropping the
  `KIT_TERMINAL_PROBES` sentence; whether the loader refuses `--workspace=` for verbs that ignore it.
- **First release scope:** which of the eight release-readiness gaps the first release needs; fixtures built from
  schema examples or schemas narrowed to the fixtures.

## Left for later

These are refactors or whole-document passes, not wrong cases. They need a design first.

- One home for each fact: an app and stage manifest generated into kit and kittui; the catalog's common fields; one
  glyph
  table; the provider declaration as data with generated conformance tests; fixtures drawn from the schemas.
- kittui on shared parts: Flow onto the shared table, `shell.Chrome` and `tabs.Frame`, one walk of the form's grammar,
  one row cache, apps and actions as data, opening an app as a loading source.
- A shared layer across the three forge providers, and one `boards.sh` for Azure Boards.
- Prose passes over the 1,345-line `docs/apps.md`, the long reference pages, about 1,400 comment lines in kittui and
  about
  150 places in the integration pages, best done once each by one writer.
- A sixth welcome page, "your first change", and a display-width function for every table cell.

## Things the work found that were fixed on the way

- A test failed at HEAD after two agents each landed a `|| true` with no reason; a flow test did not compile after two
  patches each added the same test; a screens test and the esc test broke when later commits changed their rules; two
  gate tests failed after the new test helpers landed. Each was fixed forward and the gate rerun.
- The forge contract is at 8; the integration pages said 6 and now state no number, and a test holds them to the code.
