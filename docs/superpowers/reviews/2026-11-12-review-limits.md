# What the seven sections miss, or get wrong

I read the seven sections and the Coverage note of all 48 areas, listed the snapshot, and opened about 85 of the
places the sections cite. Each reads as described. What follows is only what is missing, weak, or wrong.

Since this page was written, the corrections of parts 4 and 5 were made in the pages, and the plan on
[the review's page](2026-11-12-review.md) gives each item one timing. Parts 1 to 3 stand, less what
[Promised and not built](2026-11-12-review-gaps.md) and [The plans against the code](2026-11-12-review-plans.md)
now answer.

## 1. Parts of the tree no reviewer read whole

1. The tests. They are 81 bats files (23,791 lines), 126 Go test files (32,325 lines), 17 jq test files (1,364
   lines), and 85 goldens: nearly half the code in the tree. S4 read six bats files and the cost and golden tests
   whole and counted the rest by script. 35 bats files and 112 Go test files are named in no finding
   (`tests/workspaces.bats`, 799 lines, and `tests/tools.bats`, 576, among them), and no reviewer read more than 25
   goldens. The table "What the tests miss" in the structure section therefore rests on counts. Follow-up: one
   reader per suite (bats in four parts by area, Go by package) who reads each file for assertions that cannot
   fail, tests that test only the fake, and goldens that hold a wrong screen.
2. The plans. `docs/superpowers/plans/` holds 17 plans (6,443 lines). P8 read two whole, and 10 are named in no
   finding. Only the release-readiness plan was compared with the code. Follow-up: mark each task of each plan
   built, partly built, or not built. The new plan needs this, or it will repeat tasks that 17 plans already hold.
3. `kit/modules/bash/issues.sh`, `changes.sh`, and `builds.sh` (457 lines). B6 says it did not read the first two,
   and no Coverage note claims any of the three. They draw the text tables the structure section calls slow.
   Follow-up: one read, added to B6.
4. Comments, for question 4. P5 read the bodies of 12 of 88 bash modules and the headers of the rest. P7 read every
   comment in 5 of 22 Go packages (3,504 of 8,051 comment lines). No prose reviewer read `kit/modules/jq`, the test
   names and comments in the bats files, or the descriptions in the 79 schemas. Follow-up: say in the prose section
   that the verdict on comments is a sample, and read the jq comments and the bats test names once.
5. Small files named nowhere: the three schemas `kit/packages/{kind,package,rule}.schema.json` (241 lines) and
   the delivered `lefthook.yml` of `kit/packages/hooks/lefthook`. Follow-up: read each against the code that reads it.

Four things were read and never run. They weaken the answers as much as an unread file does.

1. Linux. Every reviewer ran on macOS. `kit-ci.yml` and `release.yml` run on `ubuntu-latest` alone, so nobody ran
   the code where the gate and every consumer's check run it. Follow-up: run `bin/ci` and the reproductions of the
   release and trust items in an Ubuntu container, with bash 4.4 and jq 1.7.1.
2. The gate. No reviewer ran `bin/ci` from end to end, and T1 could not run `npm ci`, `tsc`, the site's tests, or
   its build. "The site's own code is sound" (the kittui section) rests on reading. Follow-up: run both with a network.
3. Time. Every timing was taken at a load average of 37 to 85, with 48 reviewers at work. Follow-up: run S6's
   tables and the four 8 ms tests again on an idle machine before the report quotes seconds or calls a test flaky.
4. The network. No reviewer could see the tap, the published site, the tag rulesets, whether each pinned SHA is the
   tag its comment names, or whether the dependencies in `go.sum` and the two `package-lock.json` files have known
   faults. GitLab was never called at all (glab was not installed). Follow-up: one pass with a network.

## 2. Questions of the owner's that are unanswered, or answered without evidence

1. Comprehensiveness (question 1) has no answer. 74 findings are of kind "gap", and they are spread over the
   sections. The eight missing items of R3-26 are counted in the bash section and not listed: `SECURITY.md`,
   `CONTRIBUTING.md`, `CODEOWNERS`, macOS in CI, a smoke test of the packed tarball, completion for bash and fish,
   attestation, and a verdict CI can sign. R3 left most rows of the specs' Gaps tables unchecked. Follow-up: one
   table of what the README, `docs/features.md`, and the seven specs promise against what is built.
2. The interface was judged on data kit did not print (question 3). U1 and U2 drove kittui against the tests' fake
   kits, and the structure section says those fixtures are not what kit prints (27 of 32 lack three keys). U3 and
   U5 used the real kit with no forge. So nobody saw a forge-backed tab drawn from kit's own rows. U2 read the
   workspaces screen and Open Repository and did not drive them. Every run was in tmux: no iTerm2, no Terminal.app,
   no real mouse, no light theme on a screen, and the Nerd Font item is "plausible, not seen". Follow-up: drive the
   nine apps on the real kit over the conformance tests' fake forge, in iTerm2 and Terminal.app, with a mouse.
3. "How will it be received" has no evidence beyond the reviewers. The comparisons ("ahead of lazygit, k9s, and gh
   dash", "one key in k9s", "4 to 5 with Graphite") come from memory: no reviewer ran those tools. The verdicts by
   kind of reader are U5's projection. Follow-up: run the three tools on the same tasks or drop the numbers, and
   give kittui to two people for an hour before the release and record where each one stops.
4. Question 2 is answered for kit's side. The research's own accuracy is unevidenced: no reviewer ran a researched
   command for glab, az, or the thirty other tools, and the 83 links to published schemas were not fetched.
   Follow-up: extend the live run of the integrations section's item 4 to glab, and check the links with a network.
5. Question 4 has a verdict with numbers. Two weak points: P3's 25 rewrites and its table by page were never saved,
   so the integration pages have no rewrite to apply, and "about 500,000 words" has no source (the markdown alone
   is about 240,000). Follow-up: run P3 again for the rewrites, and say what the word count covers.
6. The plan (question 5) is not yet one plan. The sections hold 135 work items, and 96 say before the release for
   all or part. None totals the work, and none says which few items are the least that lets 0.1.0 ship. 256 finding
   ids sit in the work items of two or more sections. Follow-up: one list in which each finding has one item and one
   timing; a short must-ship cut (the release, trust, the crashes, the acts on the wrong thing) kept apart from the
   rest; and the owner's decisions first: the names, the specs, Homebrew, and which forges 0.1.0 names.
7. Skeptics ran 90 of the 111 critical and high findings and none of the 430 medium ones, and many "before" items
   are medium. Follow-up: a second reader for each medium finding that a must-ship item rests on.

## 3. Sections that contradict each other

1. The release-readiness plan. The bash section says "nine tasks, and none is built". The prose section says "some
   tasks are built". The code: no task is finished, and one of the four changes of Task 5 is in. `guard:missing`
   exists (`kit/modules/bash/1st.sh:598`), the verbs and modules call it, and no `run: mise install` text
   is left. The loader's bash check and the git 2.31 check are not there. Both sections should say that.
2. The tap and the site. The bash, consistency, and interface sections call the empty tap "plausible", and the
   bash section calls the site's address "unseen". The kittui section cites a 404. The tree settles it:
   `docs/superpowers/reviews/2026-11-10-code-review.md:66-67` records that the tap is empty and the page answers
   404, and nothing in the tree since publishes either. Call both confirmed as of 11-10.
3. The same work has two timings. Follow-up: the owner picks one for each.
   - Azure DevOps and GitLab. The bash section's items 15 and 16 say "before, if 0.1.0 names GitLab" and "after,
     unless 0.1.0 names Azure DevOps". The integrations section's items 4 to 6 and the consistency section's item
     13 say before. The delivered welcome page names all three forges
     (`kit/packages/kit/files/repo/.kit/welcome/1-introduction.md:12`), so it is before, or the page changes.
   - kit off kittui's update loop (G5-7, G4-14): before in the structure section's item 7, after in the kittui
     section's item 16.
   - kittui's fixtures drawn from kit (S4-1, G2-5): before in the structure section's item 3, after in the kittui
     section's item 17.
   - Legends for the 20 tabs without one (G2-4, S1-3): "before if the nine apps ship" in the kittui section's item
     15, after in the structure and consistency sections. The apps ship (`projects/tui/internal/flow/apps.go:25`).
4. Two remedies for one fault. For the apps whose title is not their verb, the consistency section renames the
   verbs (`kit workspace` to `kit repositories`), and the interface section's item 12 keeps the verbs and changes
   the title. Follow-up: the owner chooses before either lands, since a released name cannot change.
5. Two ranks for one finding. The guessed links are high finding 4 in the structure section and "narrowed to
   medium" in the kittui section. R3-7 is listed among the high items of the bash and consistency sections, each
   saying the skeptic lowered it. Follow-up: one rank each in the report.
6. Two fixes that are unsafe together. The interface section's item 2 lets an action fall back to the cursor's row
   and names no dependency. The kittui section's G1-7 says a watched reload keeps the cursor's index, not its row.
   Together, one key acts on an issue the person did not choose. Follow-up: make that item depend on G1-7 and on
   the interface section's item 4, the question before a write.
7. Counts that differ. Follow-up: one figure each, with what it counts.
   - Hand-offs to kittui: nine in the bash section, ten in the structure section. The code has nine
     `binary=$(tui:binary)` sites and the bare `kit` path at `kit/modules/bash/1st.sh:737`: ten.
   - Options written `--name=<value>`: "about 30" in the consistency and prose sections, 32 in the interface
     section. The usage lines hold 30, and 9 written with a space.
   - Error calls: 461 in the consistency section, 491 in the prose section, 448 in the structure section. A grep
     for `error "` in `kit/bin`, `kit/modules/bash`, and `kit/libexec` finds 490.
   - Fixtures against schemas: "20 of 62 fixtures fail" in the integrations section and "12 of 42 schemas reject a
     fixture" in the structure section. Both are right and measure different things. Give both once.

## 4. Findings a section dropped without a refutation

No critical or high finding is missing. One hand-off lost seven findings. The kittui section says the bash section
reports R2-9 to R2-19 and R2-38 to R2-51. Of those 25, the bash section names seven and the consistency section nine.

1. R2-18, medium, confirmed, is in no section. `kit new --package=x kind foo` loses its option, because
   `kit/bin/kit-new:106-116` dispatches on `$1` while the guard takes options anywhere. I read the lines, and they
   do. Follow-up: add it to the Guard rows of the bash section's medium table and to its item 23.
2. R2-10, medium, security: a token in a URL argument is written to `.kit/logs` and kept 14 days. The bash section
   has it only as the low title of S5-16 and does not say that R2 rated it medium. Follow-up: settle the rank.
3. R2-39, R2-40, R2-41, R2-45, and R2-50, all low, are in no section's text. Follow-up: add the five titles to the
   bash section's low table.

## 5. Claims that the code in the snapshot shows to be wrong

Follow-up for all seven: correct the sentence in its section. None changes a work item.

1. Structure section, the table of facts: "120 of 361 fields copy member, source, organization, and repository".
   `projects/tui/internal/flow/fields.json` holds 127: three of them in all 32 stages and `member` in 31. That is
   35%, as G2-7 says.
2. Structure section, done well: "28 of 32 stages need no Go". `builders` names five stages
   (`projects/tui/internal/flow/rows.go:325-331`): four build their rows in Go, and `releases` decodes in Go. 27
   are drawn from the catalog alone, as S1 says.
3. kittui section, done well: "Every call that can hang has a limit". `Runner.Act` runs kit with no limit
   (`projects/tui/internal/kit/kit.go:389-395`), which is that section's own high item 9.
4. Interface section, done well: "Nothing runs unasked", and the kittui section's "Actions list what they will
   change before they ask". `Assign to Me` runs at once (`projects/tui/internal/flow/act.go:295-296`), and the
   interface section's high item 2 names two more that do.
5. Interface section, done well: "esc never quits and always goes back one step". In the rows, esc sends the cursor
   to the first row and leaves a search in place (`projects/tui/internal/flow/flow.go:821-826`), which is U1-7.
   G5-13 says esc on Open Repository does not take back the ask.
6. Bash section, done well: "every digest check fails closed". `toolchain/kit:fetch` returns a cached download by
   its name and never hashes it (`kit/modules/bash/toolchain/kit.sh:340-344`), which is that section's own medium
   row. "The policy engines fail closed" stands in a section with the heading "Trust and policy fail open". It is
   true of the three cases it names, and B7-1, B7-2, and B7-7 are ways round it. Reword both bullets.
7. Interface and consistency sections: "all 52 verbs answer `--help`". S8 ran them without a terminal. On a
   terminal the guard runs `kit-help` with no `--text` (`kit/modules/bash/1st.sh:711`), and the interface section's
   item 9 says that page never loads. Say "without a terminal".
