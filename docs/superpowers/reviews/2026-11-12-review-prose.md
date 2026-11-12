# The prose: documents, comments, messages, and commit subjects

This section covers every text a person reads in the tree at 0e76266c, from the eight prose reviews (P1 to
P8) and from findings of other areas about the same text. A skeptic ran one finding, P8-1, and confirmed it
in part. None was refuted. I checked the line numbers, counts, and quotations of the six high prose findings
in the snapshot, and ran the pattern counts again. They hold. No one reproduced a finding marked plausible.

## Verdict

The prose is not padded, and it is not plain. In about 240,000 words of documents, and in the
comments and messages of the code, there is no filler word, no agentic tic, no
summary that restates, and about ten slogans. Every reviewer found the opposite fault: a compressed dialect that
is the repository's own. It packs a table of facts into one sentence, uses "as" for six different words, drops the
noun after a possessive, and almost never says "because". Of 659 sampled passages, 454 pass on one reading (69%).

The short texts value the reader's time: refusals, check lines, rules, styles, toolchain pages, and tab
titles. The long ones do not: the reference pages, the help of the picture verbs, the Go package comments,
and the commit subjects. They do not drone. They make the reader decode them, which costs the same time. The
repository's prose rules stop filler, say nothing about compression, and two of them push writers toward it.

## Pass rate by kind of text

A passage passes when one reading gives its meaning and every sentence in it is worth reading.

| Kind of text | Sampled | Pass | Rate | Where the failures are |
| --- | --- | --- | --- | --- |
| Core documents (P1) | 95 | 63 | 66% | `docs/features.md` 12 of 25; `docs/architecture.md` 8 of 15 |
| Feature documents (P2) | 59 | 49 | 83% | `docs/apps.md` and `docs/workspaces.md` pass 2 of 8 |
| Integration pages (P3) | 140 | 96 | 69% | 33 of 44 failures are in `git.md`, `gh.md`, `glab.md`, and `az.md` |
| Specs, plans, reviews (P8) | 53 | 37 | 70% | the components spec; the plans' Architecture paragraphs |
| Consumer pages (P4) | 52 | 41 | 79% | `kit/packages` passes 36 of 43; `projects/tui/README.md` 4 of 7 |
| Bash comments (P5) | 81 | 60 | 74% | verb headers pass 16 of 23; no failure is padding |
| Go comments (P7) | 85 | 51 | 60% | blocks of 40 words or more pass 4 of 22 |
| Interface copy (P6) | 94 | 57 | 61% | help paragraphs 32 of 56; messages 8 of 14; kittui strings 9 of 15 |
| Commit subjects (P8) | 80 | 65 | 81% | 364 of 400 run past 72 characters; the median is 131 |
| kittui's tab titles (P6) | 32 | 26 | 81% | read whole, not sampled |

## Recurring patterns

Counts are lines. A row that gives a count for each kind of text is
my own grep over the snapshot. The others are the reviewers' counts.

| Pattern | Count | Example |
| --- | --- | --- |
| Filler (ensure, robust, seamless, leverage, crucial, simply, note that) | 0 | none |
| ", as " for such as, because, like, or see | 2,572: Go 1,411, bash 677, specs and plans 227, documents 216, subjects 41 | "as secret scanning disabled" (`kit/bin/kit-audit:32`) |
| "because" | 61 in the tree; 0 in Go comments and in subjects | "as GitLab does not say" (`docs/apps.md:210`) |
| Sentences of 40 words or more | Go 929 of 5,329; bash about 300 of 4,300; feature documents 43 | 282 words (`projects/tui/internal/table/host.go:7`) |
| "names no X", "is no X" for "is not a X" | bash comments 258; help pages 78 | "none names no workspace" (`kit/bin/kit-audit:21`) |
| "stands" for is, shows, or sits | 734: Go 527, documents 76, bash 55, specs and plans 43, subjects 33 | "one kept before stands as that desk" (`docs/workspaces.md:78`) |
| "alone" for only | 495: Go 198, bash 102, specs and plans 93, documents 93, subjects 9 | "commits these paths alone" (`kit/bin/kit-commit:34`) |
| A possessive with its noun dropped | feature documents 49; specs 48; consumer pages 20; chained in Go 66 | "Azure DevOps' are its team's" (`docs/apps.md:88`) |
| A pointer inside a sentence | Go 800; bash about 240 | "as the seam's header says", 45 times in `kit/modules/bash/forge/` |
| One text kept in two or more places | bash 55 lines in 208 places; core documents 16 shared sentences | `kit/modules/bash/commit.sh:9-25` repeats `kit/bin/kit-commit:7-26` |
| A term with no definition on the page | "desk" 42 times in ten feature pages; "mark" 63 times in integration pages | "kept as its repository's desk" (`docs/workspaces.md:78`) |
| Lines past 120 columns | Go comments 99; bash comments 25; `projects/tui/README.md` 33 | 220 columns (`projects/tui/internal/tabs/tabs.go:17`) |

## High: seven texts a reader cannot use as written

1. The help pages of the picture verbs are reference dumps (P5-1, P6-1, U4-13). `kit help flow`
   prints 345 lines and 3,077 words from `kit/bin/kit-flow:21-268`. Its first option is on line
   274, after the JSON of every stage, field by field. Ten verbs hold half of all help text. Keep
   in each header what the verb does, its arguments, and its exits as a list, and move each stage's
   JSON fields to `docs/apps.md`, one field per line, as `kit/bin/kit-welcome:39-51` already does.
2. The second half of the README is for kit's own contributors (P1-5, U5-2). `README.md:198-336`
   sits under "Setup", "Getting started", and "Release", headings a new user reads as theirs,
   and the README never says what kittui is. Move those 139 lines to `CONTRIBUTING.md` and add
   one paragraph on kittui. P1-5 rates this medium and U5-2 high; a first release makes it high.
3. Welcome pages 2 and 3 hold the newcomer's two hardest passages, drawn above the checks (P4-8, U3-3,
   U5-7). In `kit/packages/kit/files/repo/.kit/welcome/`, `3-setup.md:10-12` is a 48-word list item with no
   verb, and `2-toolchains.md:19-23` is a chain of "else" items that `kit/modules/bash/toolchain.sh:197-205`
   states better as a numbered list. Rewrite both as lists, below the checks.
4. `docs/features.md` is a second manual (P1-1). Line 3 promises a list with pointers. Lines 97-258 are the full
   description of forge detection, release JSON, and kittui's crumbs, and 13 of 25 sampled passages fail. The
   welcome guide's Customize page sends newcomers here. Cut the page to about 150 lines of summary and links.
5. `docs/apps.md` cannot be read in one pass (P2-1, U5-24). It is the reference for
   seven verbs' JSON, written as prose: 19 of its 50 passages run 90 words or more.
   The content has columns, so give each stage a table of fields and a table by forge.
6. `docs/workspaces.md` is six documents in one (P2-2). It states the start rule three times with
   different exceptions (`:56-63`, `:65-68`, `:93-95`), and `:180-190` lists eleven menu actions in
   one paragraph of 223 words. Keep the file, the members, the start rule once, and the commands,
   and move `kit workspace` and the welcome checks to their own pages. About 150 of 264 lines stay.
7. `projects/tui/README.md` cannot be read (P4-1, P4-10, D2-5). It is 5,816 words, and `:87-253` is one list item
   of 3,454 words that specifies every key and click. It also states five things the tree does not do, such as
   `kit tutorials screens` at `:33`. Cut it to about 120 lines and move the behaviour to `docs/apps.md` as lists.

## Medium, by theme

The dialect (P1-7, P2-4, P2-6, P3-6, P5-6, P6-8, P7-2, P8-6). One style runs through every kind of
text: "as" for several words, house verbs (names, holds, says, draws, judges, stands), "alone", "one
a row", and dropped nouns. It is densest in `docs/apps.md:53-131`, `kit/bin/kit-flow:38-123`, and
`projects/tui/internal/flow/apps.go:172`. Change the rules first, then the text people read first.

Packed sentences and cells (P1-4, P1-19, P1-26, P2-7, P3-3, P5-5, P7-1). Cases, fields, and steps are
written as one sentence. `docs/policy.md:47` is a table cell of 186 words and `docs/integrations/gh.md:54`
one of 196. `projects/tui/internal/table/host.go:7` is a 282-word comment over a 30-method interface whose
methods have none, and 54 of 66 large Go types are documented that way. `docs/architecture.md:153-215` packs
the forge contract into ten such bullets. Write a list, and move each clause to the member it describes.

Terms and names (P1-8, P2-5, P4-5, P4-9, P6-10, P7-8, S8-5, S8-13). "Desk" has three senses in the feature
documents. "Toolchain" means both the tools and their manager on the page that introduces it
(`kit/packages/kit/files/repo/.kit/welcome/2-toolchains.md:3-28`). One screen says underway and in flight
(`projects/tui/internal/flow/rows.go:604`). The help pages say stage 181 times and tab 31, pull request 73 times
and change about 30. Pick one word for each thing and define it at first use. P6-10 picks "pull request" and S8-5
picks "change"; change is the smaller edit, because the verb, the app, the stage, and the glyph already carry it.

One fact in several homes (P1-6, P3-4, P5-4, P7-3). Module headers restate verb pages, package comments
restate keys, and the pages repeat each other. The copies have drifted: `kit/modules/bash/commit.sh:27` says
`kit submit` commits (P5-2), and `kit/modules/bash/workspaces.sh:7` says only kit edits `workspaces.yml`
(P5-3). Give each fact one home and point to it. The stale statements below sit in copies that no test reads.

Stale statements. Each is a line or two to correct.

| Stale statement | Where | Findings |
| --- | --- | --- |
| `gh pr ready` where `kit ready` exists | `README.md:245`, `docs/architecture.md:138`, `docs/features.md:79-95`, `docs/packages/workflow.md:22` | P1-2, D1-3, D2-6, U3-17, U4-20, U5-19 |
| Links to files git ignores | `README.md:229`, `docs/modules.md:31` | P1-3, D1-5 |
| Six links that resolve only in kittui, unread by lychee | `kit/packages/kit/files/repo/.kit/welcome/4-customize.md:13` | P4-4 |
| `libexec/` described three ways | `docs/architecture.md:19-22`, `README.md:253`; `docs/install.md:8-9` is right | P1-9, D1-8 |
| Seven rule files and five templates (there are eight and six); eight flow stages (there are seven) | `docs/packages/kit.md:15`, `docs/workspaces.md:152` | P2-8, P2-9, D2-7 to D2-9 |
| Shipped tabs called "planned", no Azure DevOps, contract 3 where the code is at 6 | `docs/integrations/forges.md:32-43`, `docs/integrations/1st.md:33` | P3-1, P3-2 |
| 110 function names indexed by hand, one wrong | `docs/integrations/git.md:30-33` | P3-5 |
| "Tutorials are web pages", when nine of ten open in kittui | `projects/tutorials/src/content/kit-tutorials/index.mdx:10` | P4-2, T1-12 |
| "`.kit/` commits only `packages/`", when team presets are committed too | `kit/packages/kit/files/repo/.kit/README.md:12` | P4-3 |
| The kit toolchain left out of two help pages | `kit/bin/kit-toolchains:10`, `kit/bin/kit-tools:31` | P6-5, S8-14 |
| A sort click, a selection mark, and a panel that are gone | `projects/tui/internal/grid/grid.go:10`, `projects/tui/internal/flow/views.go:5` | P7-4, P7-5 |
| Six spec statements the code no longer matches | `docs/superpowers/specs/`; `docs/terminals.md:63` copies one | P8-5 |

Interface copy (P6-2, P6-3, P6-4, P6-6, P6-7, P6-9, S8-1, S8-9, S8-10, S8-11, U4-3, U4-6, U4-17, U4-21).

- `help:page` prints no Arguments heading, so on three pages the
  options read as legend entries (`kit/modules/bash/help.sh:372-376`).
- Ten usage lines write `--title <text>` beside about 30 options written `--owner=<login>`, and the
  refusal for the wrong spelling says the value is missing (`kit/bin/kit-work:6-7`). S8-1 was confirmed
  in part: the grammar documents the difference, so the fault is the two spellings and the false message.
- The title line says `kit repositories` and `kit trust` for the apps that `kit workspace`
  and `kit audit` open (`projects/tui/internal/flow/view.go:27`). `kit issues` lists no
  issues, and its purpose line does not say so (`kit/bin/kit-issues:2`).
- A value outside a closed set gets `<package> 'nope' is not one of the choices`,
  without the choices (`kit/modules/bash/syntax.sh:405`).
- Half the messages lead with what happened and half with the remedy (`kit/bin/kit-settle:39`,
  `kit/bin/kit-ready:37`). Settle on `what happened; run: <command>`.

What every agent reads (P4-6, U5-14, U6-12). `kit/packages/kit/files/repo/.kit/1st.md:143-196` is a package catalogue:
546 words that an agent loads in every session and cannot act on. Replace it with one line that names `kit packages`.

Commit subjects, specs, and plans (P8-1, P8-2, P8-3, P8-4, U6-16). Subjects carry the commit body: 364 of 400
run past 72 characters, and 70 hold a second change after a semicolon. The repository commits 7 specs and 17
plans against its own workflow rule, `kit/packages/workflow/files/repo/.kit/workflow.md:32`. No plan says
whether it is built: all 567 checkboxes are open. P8-1 was rated high, and the skeptic confirmed only this much
of it: the release-readiness plan has no status line, and its boxes are open though one part of one task is built
(`docs/superpowers/plans/2026-11-10-release-readiness.md:62`). The empty `.sha256` it lists belongs to the
release section (R3-1). Decide whether the rule or the files stay, then give each kept file a dated status line.

## Low: 113 findings in the prose areas

Fifty are rewrites of single passages: P1-20 to P1-25, P1-27 to P1-29, P1-31 to P1-38,
P2-18 to P2-39, and P8-13 to P8-23. P2-23, P2-25, and P2-39 are plausible: check their
meaning against the code. The other 63 follow by title, in the order of their numbers.

- Core documents (P1-11 to P1-18): stage order in `docs/features.md`; jq table six modules
  short (D1-12); small counts off; gate list short in `docs/testing.md` (plausible);
  outgrown lists; acronyms and slogans; two names for one thing; cache detail in user lists.
- Feature documents (P2-10 to P2-17): wrong field name for `controls`; stale names; `docs/packages.md` repeats
  itself; markdown style breaks; two rules that hurt; five slogans; forge without Azure DevOps; maintainer detail.
- Integration pages (P3-7 to P3-12): undefined terms; empty pointers in `hut.md`; pages of one shape that
  differ; `glab.md` overstates `glab api`; nine broken sentences; git 2.31 never checked (plausible).
- Consumer pages (P4-11 to P4-19): the glossary's 44 terms (U5-20); sixteen pointer files (U6-10); `1st.md`
  omits `kit ready`; a kit-only paragraph in the bash rule (plausible); small errors on welcome pages; `tui/`
  in `AGENTS.md`; MD013 not strict (plausible); step 3 of `workflow.md`; three sentences on the tutorials site.
- Bash comments (P5-7 to P5-17): two forges where there are three; `kit status`; two outputs misstated in
  `kit help flow`; miscounted workflow steps; a dead `see:` (S8-15, D1-16); two stale reasons; four stale
  signatures; "in flight"; lines past 120; pointers and history; `kit submit` blames origin (U4-8, plausible).
- Interface copy (P6-11 to P6-17): six tab titles; "how often" on the agents tab; eight contorted strings; dim
  for bold; `cd <folder> &&` on every remedy (U4-7); nine long purpose lines; three descriptions of kit (U3-21).
- Go comments (P7-6, P7-7, P7-9 to P7-14): three wrong package comments; a deleted script
  in `reader.tsx`; contorted constructions; capitals left by a rename; 77 pointing
  wrappers; history and a to-do; 99 lines past 120; 215 test comments that repeat the name.
- Subjects, specs, plans (P8-7 to P8-12): a spec that restates code; a delivered module that
  cites a spec; session residue; a one-sentence What's new; varying area labels; style breaks.

## The ten worst passages, rewritten

Each rewrite keeps the facts as its reviewer read them. Check it against the code when you apply it.

1. `kit/bin/kit-flow:260-268`, 150 words on the exits of `kit flow` (P5-1, P6-8). Was: "Exits 0 when the picture
   is drawn, 1 when the forge, the fetch, the workspace file, a member of the workspace, a desk below, or git's
   list of the worktrees, the desks, or the remote branches cannot be read: with --json, ..." Now: "Exits 0 when
   the picture is drawn, and 2 on a usage error. Exits 1 when:" and then one line per case. A read fails, and
   with --json kit prints what it read and marks the rest. git cannot count a checkout's changed lines. A
   setting is wrong. `kit workspaces` refuses the workspace file. With --marks, the forge cannot answer.
2. `docs/apps.md:209-211` (P2-24). Was: "GitLab's are its bot users among the members, as a
   project's or a group's access token makes, `acted` `null`, as GitLab does not say, and `last`
   the day each last acted." Now: "On GitLab, the rows are the bot users among the project's
   members. GitLab creates one for each project or group access token. `acted` is `null`,
   because GitLab does not report what a bot did. `last` is the day of its last activity."
3. `docs/features.md:239-242` (P1-30). Was: "A link to a row of a tab the app does not have opens the app
   built around that tab's entity, on the tab, with the row under the cursor once it loads: from Issues,
   the pull request of an issue underway leads to Changes, ..." Now: "Some values are links to a row in
   another app. Following one opens that app on the right tab, with the cursor on the row. In Issues, an
   issue's pull request opens Changes, and its checkout opens the worktrees tab of Repositories."
4. `docs/workspaces.md:93-95` (P2-30). Was: "With no group used, or with `--workspace=none`, `kit flow` draws
   each desk below, as it does above desks, and `kit workspace` refuses with 2, as it reads a repository."
   Now: "With no last-used group, or with `--workspace=none`, `kit flow` lists each repository it finds under
   the current directory, up to four levels down. `kit workspace` exits 2, because it needs a repository."
5. `docs/modules.md:55-56` (P1-34). Was: "One `yq` cannot parse, or one read where `yq` is
   missing, is refused, and `use` returns 2: the kit's own modules never stand in for a path
   it could not read." Now: "kit reads `bash_path` with `yq`. If `yq` is missing, or cannot
   parse `kit.yml`, `use` fails with status 2. It does not fall back to kit's own modules."
6. `kit/packages/kit/files/repo/.kit/welcome/3-setup.md:10-12` (P4-8). Was: "Each folder, by
   repository, its desk first, then each worktree: kit installed, with the version its `kit.yml`
   declares; `.kit/` in place; the git hooks installed; its project toolchain; ..." Now: "In each
   folder, the desk first and then its worktrees, kit checks that:" and six items. kit is installed
   at the version `kit.yml` declares. `.kit/` is in place. The hooks are installed. The project
   toolchain is usable. The hooks' runner and the linters are installed. `kit check` passes.
7. `projects/tui/README.md:102-105` (P4-1). Was: "After how many rows are selected, a chip per filter,
   which a click opens its field's card under, on its filter, and 📇 Fields, which opens the columns
   dialog, as f on the line does, it names the preset the table is set as and ▼ ..." Now: "On the right,
   in order: how many rows are selected, a chip for each filter, 📇 Fields, and the preset's name with ▼.
   Click a chip to open its field's card. Click 📇 Fields, or press f, to open the columns dialog."
8. `kit/bin/kit-workspaces:51-53` (P5-1, P6-8). Was: "--use remembers a group as the last used, which kit
   starts on outside a repository; given a `<folder>`, keeps the repository whose working tree holds it first
   among the recent ones, by its desk, a linked worktree's its repository's, ten at most, which the workspace
   menu offers". Now: "--use remembers a group as the last one used. kit starts on it outside a repository.
   Given a `<folder>`, it puts that folder's repository first in the list of recent repositories, which the
   workspace menu shows. The list holds ten. A linked worktree counts as its repository's desk."
9. `projects/tui/internal/flow/apps.go:172-174` (P7-2). Was: "verbsOf gives the verbs whose staged
   stages are among the stages, as their catalog entries' commands name them, each once; a verb none of
   whose stages among them kit ever marks, as kit people's, is not, as its --marks would print null for
   each." Now: "verbsOf returns the verb of each given stage that kit marks, each verb once. A stage
   kit never marks, such as kit people's, adds no verb, because --marks would print null for it."
10. The subject of the #116 commit on headings (P8-2). Was: "#116 kittui: what stands
    under a heading that takes levels across steps in once from it, not once a level it
    took". Now: "#116 kittui: indent rows one step under a heading that merges levels".

## Good models to copy, and what to leave alone

- Documents: `install.md`, `completion.md`, `logs.md`, `testing.md`, `policy.md:1-72`, the five
  `toolchains/using-*.md` pages, and `integrations/gerrit.md`, `hut.md`, and `rad.md`, all under `docs/`.
- Consumer pages, under `kit/`: `rules/sh.md`, `rules/jq.md`, `styles/bash.md`, `1st.md:8-53`,
  `workflow.md:35-50`, `welcome/1-introduction.md`, and the tutorials `screen.md` and `control-line.md`.
- Help and bash: `kit-check`, `kit-gate`, `kit-ci`, `kit-submit`, `kit-commit`, and
  `kit-work` in `kit/bin/`, and the headers of `super.sh`, `generate.sh`, and `tracker.sh`.
- Go, TypeScript, and subjects: `pane/pane.go:1`, `source/source.go:1`, and
  `flow/origin.go` in `projects/tui/internal/`, every comment in
  `projects/tutorials/src`, and "#177 kit: kit submit only pushes, and commits nothing".

Leave these as they are.

- There is no filler anywhere. Do not fix compression by adding words that say nothing.
- The documents say what kit does not do (`README.md:50-57`, `docs/architecture.md:236-249`),
  and the integration pages say what was verified and what was not.
- Refusals name what happened and what to run, with the real values in them. None of 491 errors
  says only "failed". The check lines of `kit welcome --checks` are the best copy in the tree.
- A verb's help page, form, completion, and MCP schema come from one source. It needs less
  text, not a second source. Function comments in bash follow one convention and say why.

## What to cut

| Text | Now | Target | The rest goes to |
| --- | --- | --- | --- |
| `kit help flow`, `workspace`, `audit`, `welcome`, `workspaces` | 345, 193, 136, 114, 111 lines | 80, 60, 45, 60, 70 | `docs/apps.md` |
| The help of `delivery`, `changes`, `people`, `issues`, `platform` | 91 to 104 lines each | 40 each | one shared help topic |
| `README.md:198-336` | 139 lines | 2 lines and a link | `CONTRIBUTING.md` |
| `docs/features.md` | 362 lines | about 150 | `docs/apps.md`, `docs/trackers.md`, `docs/architecture.md` |
| `docs/workspaces.md` | 264 lines | about 150 | pages for `kit workspace` and `kit welcome` |
| `projects/tui/README.md` | 5,816 words | about 120 lines | `docs/apps.md` |
| `kit/packages/kit/files/repo/.kit/1st.md:143-196` | 546 words | one line | `kit packages` |
| The glossary, `welcome/5-terms.md` | 44 terms | about 38: cut 11, add 5 | nowhere |
| Module headers that repeat verb pages (forge, policy, serve, welcome, flow, git, commit) | about 250 lines | cut | the verb headers |
| Go package comments (tutorials, tabs, palette, welcome, flow) | 45, 27, 23, 22, 15 lines | 8, 6, 6, 8, 5 | one statement in `shell` |
| `docs/architecture.md:155-169`, on the words "forge" and "seam" | 15 lines | 4 | nowhere |
| `docs/integrations/git.md`, the "Used by" column | 1,140 words | verbs and stages only | nowhere |

Leave the short pages alone. Seven of the ten core pages and the 29 short integration pages are the right length.

## The repository's own rules

`kit/packages/style/prose/files/repo/.kit/styles/prose.md` has five rules. The
text obeys them almost everywhere and three passages in ten still fail, so the
rules do not name the fault (P1-10, P2-3, P4-7). Two of them cause part of it.

Rule 1, "the thing under discussion as the subject", gives passives with no actor ("is refused with exit
2, by the name you typed"), doc comments shaped "X is: a; b, which c; d", subjects that state a fact and
hide the act, and "the caller" in help where "you" is meant (P1-10, P4-7, P6-8, P7-1, P8-12). Rule 3,
"Do not restate what the code or config already states", is read as "say each thing once, in one
sentence". Writers then put a pronoun, a bare possessive, or "as X does" where the noun should be (P5-6,
P6-8). The repetition the rule was written to stop continues in module headers and package comments.

The best writing advice in the tree is `docs/tutorials.md:74`: "Short sentences.
One idea each." It governs tutorials only. Change the prose style to say:

1. One idea to a sentence. Split a sentence at its second colon or
   semicolon, or past about 30 words. Cases, fields, and steps go in a list.
2. Define a term of kit's own where it first appears on a page, or link the glossary. Use one word for one thing.
3. Write "such as" before an example and "because" before a cause. Keep
   "as" for comparison. Write only, per, except, is, shows, and "is not a".
4. Repeat the noun. Do not leave a possessive or a pronoun to carry it across a clause.
5. Name who acts: "kit refuses", not "is refused". Say "you" to the reader, and use
   the imperative for anything the reader does, in the description of a screen too.
6. In place of "do not restate": do not repeat another file's text; point to it with `see:`.

Other styles add to the fault, and each needs a line. The markdown rule "use a table where the content has
columns", with tables never wrapped, puts sentences of 196 words in cells (P3-3): a cell holds a phrase or
a command, and anything longer goes under the table. The snippet rule puts shell quoting in usage lines
(P2-14): a usage line writes `<name>`. The ban on bold would remove the specs' term lists (P8-12): a bold
term in a definition list is not emphasis. The bash style's "(sourced module)" suffix pushes six banners
past column 120 (P5-15): drop it. The workflow rule should say that a subject starts with a verb and fits
72 characters. The prose style ships in the `style/prose` package, so its changes reach every consumer.

## Work items

1. Amend the prose, markdown, and bash styles and the workflow rule. Covers P1-7, P1-10, P2-3, P2-4, P2-6,
   P2-14, P3-3, P3-6, P4-7, P5-6, P6-8, P7-2, P8-6, P8-12. Size S. Depends on nothing. Before the release.
2. Cut the help of the ten picture and app verbs to what a person types, with Arguments and Exits as headings.
   Covers P5-1, P5-9, P6-1, P6-2, P6-16, U4-13, and rewrites 1 and 8. Size M. Depends on 1. Before the release.
3. README: move the contributor half out, introduce kittui, open with one sentence on what kit
   is. Covers P1-5, P1-15, P6-17, U3-21, U5-2. Size S. Depends on nothing. Before the release.
4. Welcome pages 2 and 3, `1st.md`, the glossary, and the pointer files. Covers
   P4-5, P4-6, P4-8, P4-9, P4-11 to P4-15, P4-18, P4-19, U5-14, U5-20, U6-10, U6-12,
   and the text half of U3-3 and U5-7. Size M. Depends on 1. Before the release.
5. Correct the stale statements. Covers the table above and P1-11 to P1-14, P2-10, P2-11, P2-16, P3-8,
   P3-10, P4-16, P5-2, P5-3, P5-7 to P5-13, P6-12, P6-14, P7-6, P7-7, P8-8. Size M. Depends on nothing.
   Before the release for text under `kit/`, the README, and the tutorials site; the rest after.
6. One shape for a refusal, one spelling for an option's value, plain kittui strings.
   Covers P5-17, P6-3, P6-4, P6-6, P6-7, P6-9, P6-11, P6-13, P6-15, S8-1, S8-9, S8-10,
   U4-3, U4-6 to U4-8, U4-17, U4-21. Size M. Depends on kittui reading a remedy from
   data, not from the message (S8-10). P6-3 and P6-7 before the release; the rest after.
7. One word for one thing, in the interface first. Covers P1-8, P1-17, P2-5, P3-7,
   P5-14, P6-10, P7-8, S8-5, S8-11, S8-13. Size M. Depends on the owner choosing the
   words. Before the release for what kit prints and kittui shows; comments after.
8. Specs and plans: keep the rule or keep the files, then put a dated status line on
   each kept file. Covers P8-1, P8-3, P8-4, P8-7, P8-9, P8-10, U6-16, and rewrites
   P8-13 to P8-23. Size S. Depends on the owner's decision. Before the release.
9. Reference documents: `features.md` to a summary, `apps.md` to tables, `workspaces.md` split, the TUI
   README cut. Covers P1-1, P1-4, P1-6, P1-16, P1-18, P2-1, P2-2, P2-7, P2-12, P2-13, P2-15, P2-17, P4-1,
   P4-10, D2-5, U5-24, and rewrites P1-19 to P1-38 and P2-18 to P2-39. Size L. Depends on 1 and 2. After
   the release; `docs/features.md` before it if time allows, because the welcome guide links to it.
10. Comments: in Go, a comment on each member and short package comments; in bash,
    no verb page repeated in a module header. Covers P5-4, P5-5, P5-16, P7-1,
    P7-3, P7-9 to P7-12, P7-14. Size L. Depends on 1, 2, and 7. After the release.
11. Integration pages: cells cut to phrases, one tool paragraph per page, `git.md` generated
    or cut. Covers P3-3, P3-4, P3-9, P3-11. Size M. Depends on 1. After the release.
12. Commit subjects: 72 characters, a verb first, a fixed set of area labels, a cap in
    `policy.commit_subject`. Covers P8-2, P8-11. Size S. Depends on pull request #1
    merging, because `kit.yml:7-10` turns the rule off until then. After the release.
13. Checks the gate lacks: comment width, MD013 strict, lychee over hidden
    directories, `see:` paths, git's version. Covers P1-12, P3-5, P3-12, P4-4, P4-17,
    P5-11, P5-15, P7-13, S8-15, D1-16. Size M. Depends on nothing. After the release.
