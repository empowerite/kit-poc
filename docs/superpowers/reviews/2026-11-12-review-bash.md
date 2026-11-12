# Bugs and broken guarantees in the bash CLI

## The answer

v0.1.0 can be tagged and published today, and no loader will install it. `bin/release pack` writes a digest
file with no digest in it, the gate is red on one test, and the stated minimum jq fails `kit check` on a
correct file. The first fix is one word. The release-readiness plan has nine tasks, and none is finished.

Past the release, the serious defects are of four kinds. Trust fails in three places, and the base-policy
guarantee can be bypassed in two. Five verbs change the wrong thing or lose work: `kit work`, `kit commit`,
`kit hydrate`, `kit update`, and `kit packages add`. Five forge and workspace paths act on the wrong thing,
or give a wrong answer, and say nothing. `kit tools` refuses ordinary input in three ways.

The twelve reviews behind this section hold 300 findings: 4 critical, 32 high, 124 medium, and 140 low.
Many report one defect several times. Merged, they are 2 critical, 22 high, 76 medium, and 106 low. The
skeptics refuted none and narrowed nine; each of those is given in its narrower form, and what nobody
ran is marked plausible. An item that cites an R1, R2, or R3 finding was known on 2026-11-10. I opened
the cited lines of every critical and high item in the snapshot, and they read as described.

Of the 202 findings the 2026-11-10 review made in the seven bash-side areas, 63 are fixed, 118 are
open, 18 are partly fixed, and 3 were not rechecked. The table is under "The 2026-11-10 review".

## The release cannot be installed

1. `bin/release pack` publishes a `.sha256` with no digest in it, and exits 0: line 116 calls `release:digest`,
   which nothing defines (bin/release:116). The loader, `release:fetch`, and each consumer's `kit-ci.yml`
   refuse the tarball (kit/bin/kit:257, kit/modules/bash/release.sh:125, .github/workflows/kit-ci.yml:94).
   Narrowed: `kit update` goes on without its base, and mise never reads the file. Call `file:digest`, fail
   unless it prints 64 hex digits, and assert that in tests/release.bats:59. Critical. (B2-1, S5-3, S7-1, R3-1)
2. The bats suite fails at this commit. The forge seam's header lists six `bot-*` calls among
   those every provider implements, and the `forge-provider` template holds none
   (kit/modules/bash/forge.sh:175, tests/template.bats:281). Mark the six as calls a provider
   may implement, or add them to the template and to the other two providers. (R3-2, B3-12)
3. On jq 1.7.1, which macOS ships and kit accepts, `kit check` and `kit lint` refuse a correct file that
   holds non-ASCII text: `match` mixes byte offsets with code-point slices
   (kit/modules/jq/template.jq:169). Match on code points, or require jq 1.8 in
   kit/modules/bash/syntax.sh:335, kit/modules/bash/welcome.sh:386, and docs/install.md:76. (R1-5, R3-3)
4. Nothing in this tree stands behind `brew install empowerite/tap/kit`, the install the README
   leads with (README.md:78). Narrowed: the plan puts the formula in the tap's own repository,
   and nobody could ask whether the tap is empty, so plausible. Have the release open the tap's
   bump and install from it in a job, or lead with the download by hand. (S7-2, R3-6)
5. Nothing deploys the tutorials site that v0.1.0 links to (kit/modules/bash/tutorials.sh:27). Narrowed: nine of
   the ten tutorials ship in the kit; only `kit-tutorials`, the first one listed, opens the site, and whether
   its address answers is unseen. Add the deploy to release.yml, or ship the tenth page in the kit. (B8-1, R3-8)

## Trust and policy fail open

1. A clone you have not trusted runs its own bash. The verbs allowed before trust ask
   `git rev-parse --show-toplevel`, which answers from the clone's `.git/config`: with
   `core.worktree` set, another folder's `bash_path` is sourced (kit/modules/bash/1st.sh:59, :198,
   :218). An unpacked archive or a synced folder can carry that config; a `git clone` cannot. Run
   no git before the trust check passes, and take the root from `kit:clone-root`. Critical. (S5-1)
2. A folder with a `kit.yml` and no `.git` has its `bash_path` loaded by `kit help`,
   `kit version`, and `kit trust`, unasked (kit/modules/bash/1st.sh:138). Narrowed: this is
   the designed rule, and it fires only in the folder that holds `kit.yml`. A downloaded
   source archive still runs its code on `kit help`, and `kit trust` cannot record it. Outside
   a clone, read no `bash_path`, or hold the folder to a trust record of its own. (S5-2, B1-2)
3. `kit trust` can name one release while the loader runs another: `trust:asks` reads `version` with yq, and
   the loader reads the first `version:` line with sed, then `.kit/manifest` (kit/modules/bash/trust.sh:26,
   kit/bin/kit:189). A clone with no `kit.yml` and a manifest that says `unreleased` is said to ask for
   nothing, and its own `kit/` then runs. Use one reader for both. (B1-1, S5-6)
4. `kit policy` judges a branch by its base's rules, and runs `opa`, `jq`, and `yq` from
   directories the branch fills (kit/bin/kit-policy:64, kit/modules/bash/dependencies.sh:109). A
   branch whose `package.json` brings a bin named `opa` turned a refusal into a pass after
   `kit tools install`, which the delivered workflow runs before `kit ci`. For the two judgements,
   keep the branch's directories off the front of PATH, and correct docs/policy.md:77. (B7-1)
5. `kit commit` judges by the `.kit/policy/` on the disk, not the one being committed, and
   leaves out data files and subdirectories (kit/modules/bash/policy.sh:410). A tracked rule
   that refuses everything, emptied on the disk and left unstaged, lets the commit land.
   Build the commit's Rego with the reader the base uses, with the index as its tree. (B7-2)

## A verb changes the wrong thing or loses work

1. `kit work 7` adopts any branch whose last path part starts with `7-`. With
   `release/7-0` on origin it made the worktree there, pushed a start commit onto that
   branch, and opened a draft pull request from it (kit/modules/bash/issue.sh:365, :372).
   Ask for `refs/heads/7-*` and keep only names that start with the key. (B2-2, R1-6)
2. `kit commit` undoes a path that two commits changed behind a stale index, against its own page
   (kit/bin/kit-commit:20). `commit:behind` compares the staged blob only with the blob before the last commit
   that touched the path (kit/modules/bash/commit.sh:301). It takes a second session with an index of its own.
   Refuse when the staged blob equals the path's blob at any earlier commit and the disk differs. (B2-3, R1-2)
3. A repository's own file at a delivered path under `.kit/` is left alone for one command and
   replaced by the next, with no copy kept: `materialize:all` skips it, then `manifest:write` records
   the path (kit/modules/bash/materialize.sh:320, :498, kit/bin/kit-update:234). Leave the refused
   paths out of the manifest, and exit 1 from `kit hydrate` while one is refused. (B3-2, R1-3)
4. Every verb that hydrates rewrites `.kit/manifest` from what the release delivers, so `kit update`
   cannot apply a changed answer. After one `kit context`, which the Claude hook runs, the update reports
   a three-way merge and changes nothing (kit/modules/bash/materialize.sh:498, kit/bin/kit-update:217).
   Write a record when a path is placed, never from the release. That also closes the item above. (B3-1)
5. `kit packages add` breaks a `kit.yml` whose lists are not indented two spaces, which is valid YAML.
   The rewrite takes only lines that start with two spaces as the block's items, so the old items stay
   after the new block and yq can no longer read the file (kit/modules/bash/settings.sh:218). Take
   every following line that is indented or starts with a dash as the block. (R1-4, B1-5)

## A wrong answer, and nothing said

1. The GitHub provider never tells `gh` which repository is the primary. With `origin` a fork and
   `upstream` the project, kit read and wrote the project, `issue create` included
   (kit/modules/bash/forge/github.sh:762). `gh api` also goes to gh's default host, so an Enterprise
   primary is read from github.com (kit/modules/bash/forge/github.sh:433). Run every `gh` through
   one wrapper that exports `GH_REPO` and `GH_HOST` from the primary's URL. (B4-1, B4-3, R1-18)
2. A failed check is hidden by a check of the same name that started later. `checks` keeps one run per
   name, and GitHub names a check run by its job alone, so two workflows with a `test` job show one
   passed check (kit/modules/jq/forge.jq:79, kit/modules/bash/forge/github.sh:544). Ask for the check
   suite's workflow and event, and group by all three. Not run against a real GitHub. (B4-2, R1-1)
3. `--jq` after `kit --workspace=` drops the workspace: `guard:jq` runs the verb again with `--json` and
   no `--workspace=`, so the answer is this repository's alone, with exit 0 (kit/modules/bash/1st.sh:655).
   Hand the workspace on, and test it in tests/across.bats. `kit --workspace=` with no verb, or with
   `tui`, loses it the same way (kit/bin/kit-tui:53). (B6-1, B8-2)
4. On Azure DevOps, `open-issues` reads one `az boards query` and checks only for 10,000
   items, while the extension stops at 1,000 (kit/modules/bash/forge/ado.sh:292, :301). A
   project past that would list its oldest 1,000 with exit 0. The cap was not seen on a live
   organization, so plausible. Fail at 1,000, or page through `az devops invoke`. (B5-1)
5. On GitLab, a change `kit work` opens carries no closing line for its primary issue: `issue:start`
   writes `Closes` only for another tracker's issue, and the merge request gets an empty description
   (kit/modules/bash/issue.sh:603, kit/modules/bash/forge/gitlab.sh:451). `kit linked` would then
   fail on every such change; that needs a live GitLab, so plausible. Narrowed: Azure DevOps links
   the work item at creation. Always write the line for the primary. (B5-2, B2-10, R1-27)

## `kit tools` and `kit ci`

1. `kit tools run` takes kit tools' own option names in the command for its own:
   `kit tools run prettier --check .` answers "needs --outdated", and `--help`
   prints kit's page (kit/bin/kit-tools:5, kit/modules/jq/syntax.jq:74). Narrowed:
   other dash-words pass, and `run -- prettier --check .` works. Once the literal
   `run` is seen, give every later word to the command. (B1-3, B7-3, R3-4)
2. A large `uv.lock` makes `kit tools` fail: the whole lock goes to jq as one argument
   (kit/modules/bash/dependencies/uv.sh:36). Narrowed: on macOS it fails past 1 MiB; Linux's
   limit of 128 KiB on one argument was not run. Feed the lock on stdin. (B7-4, R3-5)
3. Every package in `uv.lock` is expected in `.venv`, those a platform marker excludes among them
   (kit/modules/bash/dependencies/uv.sh:39). With real uv, a dependency held for `win32` is a row that
   fails for good, and the welcome check never holds. Judge with `uv sync --frozen --check`. (B7-5, R3-5)
4. The documents let a reader think CI runs `kit lint`. `kit ci` runs linked, policy, gate,
   and check, and the table under "The four checks are fixed" lists the linters and the
   `pinned` check (kit/bin/kit-ci:33, docs/features.md:44). Narrowed from high: no document
   says CI runs lint. Say in the table that it does not, or make lint a fifth check. (R3-7)

## Medium

The 63 rows are the merged findings; a row that joins two defects joins them by
their place or their fix. Plausible means nobody ran it against the real tool.

| Area | What is wrong | Where | What to do | Findings |
| --- | --- | --- | --- | --- |
| Release | The digest check passes when both sides are empty: with no sha tool on PATH, today's empty `.sha256` lets an unverified tarball run | kit/bin/kit:257, kit/modules/bash/release.sh:125 | Refuse unless both values are 64 hex digits | S5-4 |
| Release | `pack` copies the working tree, not the tag, and `publish` lets gh make a missing tag | bin/release:107, :138 | Pack from `git archive` of the tag; pass `--verify-tag` | B2-9, S7-6, R3-9 |
| Release | `retire` deletes a pre-release that branches still reach when git dies of SIGPIPE (20 of 20 runs at 3,000 branches), and prints "retired 0" with exit 0 when gh fails | bin/release:160, :168 | Capture each command's output, fail on a failed read, then test it | B2-6, S7-7, S7-8, S5-18, R3-30 |
| Release | `retire` deletes every pre-release no remote branch reaches, whichever branch was deleted, so a consumer pinned to one gets a 404 | bin/release:160, README.md:333 | Retire only what the deleted branch reached, or keep one until a later release exists | S7-12, R3-10 |
| Release | A release has no attestation, `verify` is the tagged commit's own script, and `kit.yml` pins kit by version alone (plausible: the tag ruleset could not be read) | .github/workflows/release.yml:58, bin/release:82 | A tag ruleset for `release/*`, verify from the default branch, attest the tarball | S5-8, S7-11, R3-11 |
| Release | `kit release` accepts `1.2.3-rc-2`, and the loader and `kit update` refuse it | kit/modules/bash/releases.sh:16, kit/bin/kit:227 | One pattern, the stricter one, in all four places | S7-10, B2-15 |
| Release | Dependabot bumps the installed `kit-ci.yml`, never the template, so `kit check` fails its pull request here and in every consumer | .github/dependabot.yml:19 | Ignore `kit-ci.yml` in Dependabot; move the template's pins by release | S7-5, R3-12 |
| Release | The Settle job gets a read-only token for a fork's or Dependabot's pull request (plausible) | kit/packages/github/ci/templates/repo/.github/workflows/kit-ci.yml:128 | Run it on `pull_request_target` with the base's checkout | R3-18, S7-13 |
| Release | On bash 4.4, the stated minimum, the terminal probe dies on `EPOCHREALTIME` after it has written its queries to the terminal | kit/modules/bash/terminal.sh:278 | Take the time through `log:now`; run the terminal suite under bash 4.4 | S7-4 |
| Security | Before trust, kit appends its log through a symbolic link the clone commits, into a file outside the clone | kit/libexec/kit-call:60, kit/modules/bash/log.sh:60 | Write no log in a clone not trusted; refuse a linked `.kit/logs` | S5-5 |
| Security | A source whose digest holds `..` is read from wherever it points, and its URL reaches curl with no `--` before it | kit/modules/bash/sources.sh:147, :96, kit/modules/bash/resolve.sh:81 | Drop a record whose digest is not `sha256:` and 64 hex digits; add the `--` | S5-7, R1-11 |
| Security | Ambient `kit tools` puts an empty element first on PATH, so an executable at the repository's root runs | kit/bin/kit-tools:241 | Join the directories first, as `toolchain:run` does | B7-9 |
| Security | A cached tool download is installed without being hashed; downloads are staged in TMPDIR, and `.kit-sha256` is written before the move (the staging half plausible) | kit/modules/bash/toolchain/kit.sh:340, :390 | Hash the cached file; stage beside the destination; stamp after the move | S7-3, B7-10, S7-9 |
| Security | `kit trust` says it trusts a clone when the trust file's last line had no newline; the record joins that line, and both clones are then untrusted | kit/modules/bash/trust.sh:75, kit/bin/kit-trust:127 | End the old text with a newline; check the record holds before the success line | B1-6 |
| Security | The agents' deny lists stop one spelling of each command: `git checkout -B`, `git -C x commit`, and `git switch --create` pass (plausible) | kit/packages/agents/claude/files/repo/.claude/settings.json:4 | Add the capital and long forms, or refuse in a hook that parses the command | S5-10, R3-13 |
| Commit | `kit commit` cannot commit a file taken out of tracking, and the remedy it prints for a placed file is refused | kit/modules/bash/commit.sh:304, :99 | Pass a staged deletion when the disk holds HEAD's blob; guard only added or changed paths | B2-4 |
| Commit | The pre-commit checks lint the disk, and the commit takes the index | kit/modules/bash/commit.sh:255 | Refuse a staged path whose disk copy differs, or lint a checkout of the index | B2-5, R1-7 |
| Commit | Every failed rebase is called a conflict, a real conflict has no supported way forward, and the default branch is guessed as `main` | kit/modules/bash/git.sh:495, :38 | Tell a conflict by its unmerged paths and name the remedy; read the remote's HEAD | B2-8, R1-29, R1-32 |
| Commit | A title with no ASCII letter or digit gives the branch `<key>-`, which the default policy refuses for every later commit | kit/modules/bash/issue.sh:380, kit/modules/bash/forge/gitlab.sh:196 | One slug function with a fallback word | B2-11, R1-26 |
| Guard | Ctrl-C does not stop a loop, or `kit ci`, that calls kit: `kit-call` traps INT and exits 130 normally | kit/libexec/kit-call:65, kit/bin/kit-ci:36 | After the log line, reset the trap and send the signal to itself | B1-4 |
| Guard | A `--` the guard accepts reaches kinds, help, usage, completion, and workspaces as a word | kit/bin/kit-kinds:37, kit/bin/kit-help:37, kit/bin/kit-workspaces:123 | Read `syntax_operands` in these verbs, as 18 verbs do | B1-8, B6-10 |
| Delivery | `kit packages add` does not place a path the new package overrides, `remove` does not restore it, and `kit update` repairs neither | kit/modules/bash/package.sh:119, :201 | Place again every path whose winning source changed | B3-3, R1-37 |
| Delivery | Under `kit serve`, a second hydrate reuses the first one's caches, and `kit hydrate` and `kit new` say a file is in place when nothing was placed | kit/modules/bash/place.sh:67, kit/modules/bash/materialize.sh:471 | One function that empties the three caches; let an explicit hydrate through | B3-4, B3-5 |
| Delivery | A kind a file gets from its first line is read from the disk, not from the staged blob the facts describe | kit/modules/bash/facts.sh:216 | Read the blob's first line with `git cat-file --batch` | B3-6 |
| Delivery | `kit context` exits 0 with no rules when a rule's frontmatter cannot be read, in the Claude hook too | kit/modules/bash/context.sh:176 | Read with `list:read` and return 1 | B3-7 |
| Delivery | `kit new kind` writes a pattern in YAML double quotes, so a backslash breaks every classifying verb, and a glob with an unclosed `[` hangs them | kit/modules/bash/new.sh:236, kit/modules/bash/context.sh:229 | Write single-quoted scalars; take an unclosed `[` as a literal; compile before writing | B3-8, B3-9, R1-10, R1-34 |
| Delivery | A source tarball laid out as the header says is cached empty and never fetched again | kit/modules/bash/sources.sh:110 | Refuse, and do not cache, a source with no `packages/` | B3-10, R1-11 |
| Delivery | A retired file is never removed in a fresh clone, and a release that drops a package leaves no verb that works | kit/modules/bash/place.sh:371, kit/bin/kit-update:66 | Add the base release's paths to the candidates; let update drop the package and say so | R1-8, R1-9 |
| Delivery | A kept YAML result is replayed for another expression, and every release shares the cache for seven days | kit/modules/bash/yaml.sh:133 | Put a digest of the expression and the release in the entry's name, before 0.1.0 fixes the format | B1-7, R1-38 |
| Delivery | Latent in 0.1.0: home delivery keeps no count of who uses it, and a JSON merge keeps a key the new release dropped | kit/modules/bash/uninstall.sh:38, kit/modules/jq/merge.jq:12 | Match whole record lines and record the users; remove the dropped keys before applying | B3-11, B1-9 |
| GitHub | `builds` keeps what is left of the 50 newest runs of any kind, so steady pull request traffic empties the table; GitLab does the same | kit/modules/bash/forge/github.sh:796, kit/modules/bash/forge/gitlab.sh:589 | Ask by event and branch, 20 each | B4-4, R1-17 |
| GitHub | A change made while another process reads leaves the old snapshot for up to a minute, and a lock whose process number is reused stalls every read 120 seconds | kit/modules/bash/forge.sh:902, :942 | Stamp the time of `forge:forget` and refuse an older snapshot; take the lock over when the wait runs out | B4-5, B4-10, R1-45 |
| GitHub | A spent rate limit reads as "this checkout does not resolve to a GitHub repository" at 14 call sites, and as `gh auth status` on a mark, which is then kept as refused for ten minutes | kit/modules/bash/forge/github.sh:762, :948 | Read owner and name from the URL, with no request; give a 403 or 429 to `forge/github:limited` first | B4-6, B4-7 |
| GitHub | A repository or owner named in digits fails every GraphQL read, because `--field` sends a number | kit/modules/bash/forge/github.sh:106, :557 | `--raw-field` for owner and name at the eleven call sites | B4-8, R3-17 |
| GitHub | One pull request with more than 20 reviewers fails the open changes of the whole repository, and an issue's iteration past 5 projects is cut in silence (the second plausible) | kit/modules/bash/forge/github.sh:584, :884 | Read on by cursor, or draw the first 20 and name the number | B4-11, B4-13 |
| GitHub | A fork's pull request whose branch has this branch's name is taken for this branch's, and drawn as checked out here | kit/modules/bash/forge/github.sh:919, kit/modules/jq/underway.jq:16 | Keep only pull requests that are not cross-repository | B4-12, R1-15 |
| GitHub | A repository with Issues off fails `open-issues` with `gh auth status`, and the snapshot cannot pass a 3 on (plausible) | kit/modules/bash/forge/github.sh:484, kit/modules/bash/forge.sh:974 | Answer 3 on "has disabled issues"; carry the status through the snapshot | B4-9 |
| GitHub | A bot's login lacks `[bot]` in the open changes, and `closes` takes closed issues too (the second plausible) | kit/modules/jq/forge.jq:159, :179 | Fold the author through `github_bot`; ask each issue's state | R1-16, R1-19 |
| Other forges | Azure DevOps reads a work item as closed only in Closed, Done, or Removed, whatever `closed_state` says, so `kit settle` closes it again at every run | kit/modules/jq/forge.jq:448, kit/modules/bash/tracker/ado.sh:83 | One list of closing states for the three readers | B5-3, B2-7 |
| Other forges | GitLab counts unresolved notes where the others count threads, fails the gate on a job allowed to fail, and does not block on `requested_changes` | kit/modules/jq/forge.jq:274, :249 | Count discussions; count an allowed failure as passed; add `requested_changes` to approval | B5-4, B5-12, R1-14 |
| Other forges | Azure DevOps builds and artifacts are the whole project's, other repositories' among them | kit/modules/bash/forge/ado.sh:504 | Keep the runs whose `repository.name` is this repository's | B5-5 |
| Other forges | Assigning on Azure DevOps replaces the assignee while kit says it adds one | kit/modules/bash/forge/ado.sh:172, kit/modules/bash/issue.sh:87 | Let a tracker say it holds one assignee, then say so or refuse | B5-6 |
| Other forges | A web tracker's issue in a change's body fails `kit settle` in CI at every such merge, and `kit linked` names a remedy that cannot work | kit/modules/bash/tracker/web.sh:46, kit/modules/bash/issue.sh:284 | Give the tracker seam the forge seam's unsupported answer, 3 | B5-7 |
| Other forges | `tracker/ado.sh` drops a new issue's body, prints `null` with exit 0, takes a failed read for an unassignment, and exits 127 without az; `forge/ado.sh` holds the same ten calls | kit/modules/bash/tracker/ado.sh:62, :92, :26 | One set of work item functions for both seams | B5-8, B2-22, B5-17 |
| Other forges | A personal access token does not satisfy `forge/ado:require`, and iterations need a team kit passes only from a setting (both plausible) | kit/modules/bash/forge/ado.sh:259, :242 | Read the caller through `az devops invoke`; pass the project's default team | B5-9, B5-10 |
| Other forges | The open changes cost five glab or three az processes each, one after another, and a read past 60 seconds is stale when kept (plausible, not timed) | kit/modules/bash/forge/gitlab.sh:376, kit/modules/bash/forge/ado.sh:317 | GraphQL for GitLab; parallel reads for Azure DevOps | B5-11, R1-20 |
| Other forges | On an Azure Pipelines pull request build, `kit policy` judges no branch, commit, or title, and `kit welcome` has no forge check for Azure DevOps | kit/modules/bash/policy.sh:158, kit/modules/bash/welcome.sh:454 | Read the pipeline's source branch; let each provider state its tool and login check as data | B7-8, B8-3 |
| Flow | The first fetch of a remote is drawn as its branches pruned | kit/modules/bash/flow.sh:285 | `FILENAME == ARGV[1]` in the awk; add a first-fetch test | B6-2, R1-13 |
| Flow | Three marks do not move when their stage does: desk and worktrees hash `git status`, and workspace's worktrees mark leaves out the base | kit/modules/bash/marks.sh:83, kit/modules/bash/workspace.sh:187 | Add the numstat and the base ref's commit to what is hashed | B6-3 |
| Flow | Above desks, `--json` leaves out a desk whose `kit flow` printed nothing | kit/modules/bash/flow.sh:1529 | Test that the output file is not empty before the first jq | B6-4 |
| Flow | A change that closes another repository's issue hides the local issue of that number | kit/modules/jq/backlog.jq:12, kit/modules/jq/issues.jq:23, kit/modules/jq/changes.jq:9 | Match on repository and number | B6-5, R1-12 |
| Flow | Two local branches on one upstream give incoming two rows with one key | kit/modules/bash/flow.sh:462 | Key a tracking row by its local branch | B6-6 |
| Flow | One Azure DevOps repository has three member names, one for each form of its URL | kit/modules/bash/workspaces.sh:140, kit/modules/jq/forge.jq:39 | Spell the member one way from any form | B6-7 |
| Policy | Rego held only in a subdirectory of `.kit/policy/` is never judged; the patterns engine runs in its place | kit/modules/bash/policy.sh:189 | Look for a `.rego` file at any depth | B7-7 |
| Serve | `kit serve` exits with the request unanswered when a watched file changes while `kit.yml` cannot be placed, and its packages tool refuses a package added after the schema was built | kit/modules/bash/serve.sh:258, :498 | In a resumed process, go on serving unplaced; drop the kept schemas when `.kit/` is placed again | B7-6, B7-14 |
| Serve | The work tool says it is idempotent, and its `title` argument creates an issue on every call | kit/modules/bash/serve.sh:100, docs/serve.md:55 | Set `idempotentHint` false; name the sweep and the push on the page | B7-15 |
| Serve | A tool's verb has no deadline, and a cancellation is dropped (plausible) | kit/modules/bash/serve.sh:361 | Run the verb under a deadline; honor `notifications/cancelled` | B7-16, R2-9 |
| Tools | `kit tools update` moves a pin down to the source's latest, and a failed install leaves `kit.yml` moved without its lock | kit/modules/bash/toolchain/kit.sh:86, :144 | Compare by version sort; replace `kit.yml` and `tools.lock` together | B7-11 |
| Tools | `kit toolchains use brew` is refused where brew is the only project toolchain, and `use` reports success while an active toolchain overrides the choice | kit/modules/bash/toolchain.sh:336, :330 | Refuse only when brew is not usable; say that the active one wins | B7-12, B7-13, R2-11, R2-12 |
| Terminal | kittui's build digest reads no source under a path with a space, leaves out the seven embedded JSON files, and nothing prunes old builds | kit/modules/bash/tui.sh:41 | `find -print0` with `xargs -0`; digest every file the build reads; remove older builds | B8-4, B8-5, R2-15 |
| Terminal | With a kittui that does not build, `kit welcome`, `kit tutorials`, and `kit help` exit 1 on a terminal | kit/modules/bash/tui.sh:54 | Warn and fall through to the text form | B8-10, R2-16 |
| Terminal | Three terminal readers give false findings: a failed reader leaves `{config}` in a fix, Windows Terminal's `defaultProfile` is never found, and the Warp and Alacritty readers match lines | kit/modules/jq/terminal.jq:78, kit/modules/bash/terminal/wt.sh:48, kit/modules/bash/terminal/warp.sh:25 | Word a missing key; bind `.defaultProfile` before the select; read TOML through yq | B8-6, B8-7, B8-8 |
| Terminal | `kit welcome --keep=` writes a keep for another terminal's finding or for a check that holds, and `kit welcome --checks` piped to `cat` carries colour escapes | kit/modules/bash/welcome.sh:836, :961 | Refuse an id that is not among the checks given now; have stdout's writers test `-t 1` | B8-9, B8-12, R2-13 |

Thirteen more medium findings belong to other sections and are only named here. Structure: `gh` is run
from 33 places through four wrappers, and the hand-off to kittui is written nine times (B4-15,
kit/modules/bash/forge/github.sh:1212; B8-11 and B6-14, kit/bin/kit-tui:50). Tests: one test runs the
real `gh`, `helper:isolate` leaves git's variables set, and eleven assertions cannot fail (R3-14 to
R3-16; tests/across.bats:495, tests/helper.bash:32, tests/toolchains.bats:103). Documents: six statements
the code contradicts (R3-19 to R3-24; README.md:241, docs/architecture.md:242, docs/delivery.svg:46,
kit/bin/kit-linked:7, projects/tui/README.md:7, kit/packages/policy/opa/package.yml:5). kittui: three of
the owner's rules are broken (R3-25, projects/tui/internal/form/model.go:173). Gaps: eight items are in
no plan, a smoke test of the packed tarball among them (R3-26, bin/release:133).

## Low

There are 106 low findings after merging. The table gives their titles alone.

| Area | Count | Titles |
| --- | --- | --- |
| Loader and core | 12 | option values in two forms (B1-10, B7-24, B8-15); `secrets:foreign` un-hexes a hex secret (B1-11, S5-13); three verbs stay in POSIX mode (B1-12); `kit trust --revoke` of a clone that is gone (B1-13); `file:replace` turns a link into a file (B1-14); `log_days: 0` logs until the day ends (B1-15); an empty first word runs `kit tui` (B1-16); key tables written twice (B1-17); `secrets:put` writes its names unquoted (S5-14); two fetches leave a stray `tree/` (S5-15); the log keeps every command line (S5-16); the loader names a missing docs/releases.md (S5-19, S7-22) |
| Workflow verbs | 18 | `kit rebase` reads a relative path from the root (B2-12, R1-23); a reference's shape written three times (B2-13); `kit gather` exits 0 on a failure (B2-14); a failed fetch exits with git's 128 (B2-16); a change's number read four ways (B2-17); settling a closed change unassigns too much (B2-18, R1-28); `kit work` starts a closed issue (B2-19, R1-24); a staged type change is invisible (B2-20, R1-21); `kit gate` probes just outside the toolchain (B2-21, R1-31); the swept stash dropped by its slot (B2-23); `kit submit` blames origin (B2-24); `kit linked` lists closed and foreign issues (B2-25); `kit commit --all` stages before any check (B2-26); a header says `kit submit` commits (B2-27); five readers of the worktree list (B2-28); a path that starts with a dash (R1-22); `kit work` names origin for the primary (R1-30); a leading blank line in a change's body (R1-33) |
| Delivery | 16 | `kit template fix` exits 1 in silence (B3-13, R1-35); a rendered template loses its mode (B3-14, R1-37); `kit new file` reads a relative path from the root (B3-15); a one-byte `kit.yml` after uninstall (B3-16, R1-39); a removed region moves blank lines (B3-17, R1-39); a new template variant becomes the default (B3-18); three unguarded inputs of `kit generate` (B3-19); a mention of `kit:generate` read as a directive (B3-20); tables written several times (B3-21); `lint:pinned` reads `uses:` by regex (R1-36); `bind_parts` drops a newline (R1-40); two headers and a message are wrong (R1-41); two templates the linters refuse (R3-31); the kinds miss `Justfile` and `action.yml` (R3-32); the Claude hook answers outside the repository (R3-33); hand-copied Cursor and Copilot rules (R3-34) |
| Forges and trackers | 15 | a title that holds "rate limit" (B4-14); changing calls fail in different words (B4-16); a host in capitals, and ssh.github.com (B4-17, S5-17); a marks stand-in of `every: 12.5` (B4-18, B5-16); labels and assignees cut in silence (B4-19); hidden bypasses not counted (B4-20); `forge:unlock` in two steps (B4-21); a name part of `.`, fixed in e4ab3b99 (B4-22); GitLab's path and branch unencoded (B5-13, R1-44); `forge/ado:place` misreads three URL forms (B5-14); the closing keyword has no word boundary (B5-15); GitLab's writes name no project (B5-18); GitLab's smaller differences (B5-19); Azure DevOps numbers are the organization's (B5-20); what the provider tests cannot see (B5-21) |
| Flow and workspaces | 8 | `--add` of an excluded member (B6-8); `--use` says kept when it was not (B6-9); a path with a space keeps git's quotes (B6-11); the checks cell's test pins a count (B6-12, R1-46); the stages spelled out a dozen times (B6-13); three wrong headers (B6-15); widths in characters, not columns (R1-42); `kit flow <stage> --text` refused (R1-43) |
| Policy, serve, and tools | 12 | the two engines disagree (B7-17, R1-25); an invalid pattern reported as no match (B7-18); `kit tools update` drops blank lines (B7-19); a URL kit cannot ask fails `--outdated` (B7-20); the syntax tool refuses flags (B7-21); batches and deleted files in `kit serve` (B7-22); headers omit the kit toolchain (B7-23); apt, dnf, and pacman written three times (B7-25, S7-19); three test files lack the bats minimum (B7-26); a tool installed by its folder (S5-9); xz, bzip2, and unzip unchecked (S7-14); a failed lock leaves downloads (S7-15) |
| Terminal and welcome | 8 | no cursor report read as a good measure (B8-13); an unreadable settings file hides the checks (B8-14); no `--version` reads as not installed (B8-16, R2-14); `welcome:fix-one` splits at blanks (B8-17); offline reads as not logged in (B8-18); six missing tests (B8-19); any link opened (S5-11); control characters from the forge (S5-12) |
| Release and CI | 9 | `bin/tutorials` writes an empty catalogue (S7-16); a silent gofmt failure (S7-17); the release fetch written four times (S7-18); direnv before `kit trust` in the README (S7-20); six infrastructure gaps (R3-35, S7-21); ajv skips the house package (R3-36); `bin/tutorials catalogue` takes bad pages (R3-37); plans committed against the rule (R3-28); delivered files name paths a consumer lacks (R3-29) |
| Documents | 8 | "libexec/kittui, built from tui/" (R3-27); the jq module table (R3-38); the command list of `1st.md` (R3-39); two samples (R3-40); four headers (R3-41); four lists (R3-42); the notice at the prompt (R3-43); a comment that names a lost script (R3-44) |

## Seven findings the sections passed over

The kittui section left the Serve and Command line findings of the earlier review to this one, and seven
of them reached no section. They are still open at this commit.

- Medium: `kit new --package=x kind foo` loses its option. `kit new` dispatches on `$1`, while the guard
  takes an option anywhere (kit/bin/kit-new:104-117; R2-18). It belongs with work item 23.
- Medium: a credential in an argument is written to the log in full and kept 14 days
  (kit/libexec/kit-call:48-49, kit/modules/bash/serve.sh:604-605; R2-10, S5-16). The security reviewer
  rated it low and the earlier review's reader medium. Take it as medium: it belongs with work item 5.
- Low: some invalid requests to `kit serve` are not refused with -32600 (R2-39); `kit serve` has no
  `resources/templates/list`, and a missing resource is -32602 (R2-40); its reload misses a deleted file
  (R2-41). They belong with work item 21.
- Low: a refusal names the same flag twice (kit/modules/jq/syntax.jq:92; R2-45), and `kit toolchains use
  ambient` outside a repository fails in git's words (kit/modules/bash/toolchain.sh:385-389; R2-50).

## The 2026-11-10 review

| Area | Findings | Fixed | Open | Partly fixed | Not rechecked |
| --- | --- | --- | --- | --- | --- |
| Workflow | 27 | 11 | 13 | 3 | 0 |
| Delivery | 30 | 12 | 17 | 1 | 0 |
| Flow | 29 | 8 | 20 | 1 | 0 |
| Serve | 27 | 20 | 5 | 2 | 0 |
| Command line | 28 | 4 | 19 | 2 | 3 |
| Infrastructure | 32 | 6 | 21 | 5 | 0 |
| Documents | 29 | 2 | 23 | 4 | 0 |
| All | 202 | 63 | 118 | 18 | 3 |

Serve had a plan, and it holds. The destructive verbs hold too: rebase, tidy, the sweep, regions, and
cycles. The release script, the workflows, the test helpers, and the documents are nearly as they were.

Still open and high, by their earlier names: Infrastructure 1 (the empty digest), Infrastructure 2 (a red
suite, now on another test), Infrastructure 4 (Homebrew), Delivery 3 (a repository's file replaced), Delivery
4 (the lists of `kit.yml`), Delivery 6 (jq 1.7), Workflow 3 (two commits undone), Workflow 8 (`kit work`
adopts a branch), Flow 1 (same-named checks), Command line 1, 3, and 4 (`kit tools run` and the uv lock), and
the filed issues #68 and #50 (the primary). The release-readiness plan covers the digest, the gate, the tag,
retiring, and the jq minimum, and is unbuilt. Workflow 3, Delivery 3, Delivery 4, and Flow 1 are in no plan.

Of the nine items on the earlier page's list "The release cannot ship", one is
fixed (the first `kit tools install` no longer skips npm and uv), one is partly
fixed (one tutorial link of ten is left), six are open, and one was not checked.

## Done well, leave alone

- The loader is POSIX sh with sed as its only process. It checks trust before it reads the release a
  clone names, checks the digest before unpacking, and unpacks beside its cache (kit/bin/kit:402). A
  worktree's trust is confirmed from the desk's side, and three spoofs fail in tests/trust.bats.
- With a sha tool present, the release's digest checks fail closed: the loader, `release:fetch`, and `kit-ci.yml` each
  refused the empty digest. Every action is pinned to a commit, and `tools.lock` pins four platforms by sha256.
- The destructive verbs are safe by construction. The sweep in `kit work` knows its stash by hash and
  restores at exit. `kit rebase` leases on the tip it fetched (kit/modules/bash/git.sh:487); do not go back
  to a lease on the commit read before the fetch. `kit tidy` keeps a worktree when the forge cannot be read.
- A refusal changes nothing: `region:has` and `place:refusals` judge every
  region before the first write, `file:replace` writes whole or not at all, and
  `list:read` carries a command's status, so a failed read is not an empty list.
- The forge seam's contract is exact enough to test against: a long list is whole or the call fails,
  an unsupported call answers 3 before the provider runs, and the App's token never enters argv.
  `kit serve` was rebuilt on the earlier findings, and its path guard held against every case tried.
- The policy engines fail closed in three cases: a missing opa, Rego with no `deny`, and a failing jq each
  refuse. `terminals.json` is one table for every terminal, finding, and probe, and kit
  never writes a terminal's settings. The workspace file's lock held twelve edits at once.

## Work items

1. Publish a real digest, and have the release workflow install its own release. Covers B2-1,
   S5-3, S7-1, R3-1, S5-4, B2-9, S7-6, R3-9, S7-10, B2-15. S, no dependency, before the release.
2. Make the gate green: settle the six `bot-*` calls. Covers R3-2, B3-12. S, no dependency, before.
3. Hold the stated minimums: jq 1.7 in `match`, bash 4.4 in the
   terminal probe. Covers R1-5, R3-3, S7-4. S, no dependency, before.
4. Put something behind the Homebrew install and the first tutorial.
   Covers S7-2, R3-6, B8-1, R3-8. M, depends on item 1, before.
5. Close the trust check: no git before trust, a `kit.yml` outside a clone, one reader of the release, no
   log before trust. Covers S5-1, S5-2, B1-2, B1-1, S5-6, S5-5, B1-6, B1-13. M, no dependency, before.
6. Judge policy with the base's tools and the index's Rego. Covers
   B7-1, B7-2, B7-7, B7-17, B7-18. M, no dependency, before.
7. Make `kit work` and `kit commit` safe. Covers B2-2, R1-6, B2-11, R1-26,
   B2-3, R1-2, B2-4, B2-5, R1-7, B2-19, B2-20, B2-26. M, no dependency, before.
8. Record in `.kit/manifest` what kit placed. Covers B3-1, B3-2,
   R1-3, B3-3, R1-37, R1-8, R1-9. M, no dependency, before.
9. Rewrite `kit.yml` without breaking it. Covers R1-4, B1-5, B3-16, B7-19. S, no dependency, before.
10. Run `gh` through one wrapper that names the repository and the host and
    classifies a failure. Covers B4-1, B4-3, R1-18, R1-30, B5-18, B4-6, B4-7,
    B4-8, R3-17, B4-9, B4-14, B4-15, B4-16, B2-24. M, no dependency, before.
11. Read checks, builds, and links by what they belong to. Covers B4-2, R1-1,
    B4-4, R1-17, B4-11, B4-12, B4-13, R1-15, R1-16, R1-19, B6-5, R1-12. M, depends
    on item 10; the checks and the cross-repository match before, the rest after.
12. Carry `--workspace=` through `--jq` and through one hand-off to kittui.
    Covers B6-1, B8-2, B8-11, B6-14, B8-4, B8-5, B8-10. M, no dependency, before.
13. Fix `kit tools`: `run`, the uv lock, the ambient PATH, the cached download, `update`, and `use`. Covers
    B1-3, B7-3, R3-4, B7-4, B7-5, R3-5, B7-9, B7-10, S7-3, S7-9, B7-11, B7-12, B7-13. M, no dependency, before.
14. Harden `retire` and the delivered workflow, and say what `kit ci` leaves to `kit lint`.
    Covers R3-7, B2-6, S7-7, S7-8, S5-18, R3-30, S7-12, R3-10, S7-5, R3-12, R3-18, S7-13, S5-8,
    S7-11, R3-11. M, depends on item 1; before, except the attestation and the tag ruleset.
15. Settle GitLab against a live project: the closing line, threads, allowed failures, the
    project path. Covers B5-2, B2-10, R1-27, B5-4, B5-12, R1-14, B5-13, R1-44, B5-19, B5-11,
    R1-20. M, depends on a GitLab project to test against; before, if 0.1.0 names GitLab.
16. Settle Azure DevOps against a live organization, with one work item implementation. Covers
    B5-1, B5-3, B2-7, B5-5, B5-6, B5-8, B2-22, B5-17, B5-9, B5-10, B5-14, B5-20, B6-7, B7-8,
    B8-3. L, depends on an organization to test against; after, unless 0.1.0 names Azure DevOps.
17. Give the tracker seam an unsupported answer, and one reader of a reference.
    Covers B5-7, B5-15, B2-13, B2-17, B2-18, B2-25. S, no dependency, after.
18. Finish the delivery edge cases. Covers B3-4 to B3-11, R1-10, R1-11, R1-34, S5-7, B1-7, R1-38,
    B1-9. M, depends on item 8; after, except the YAML cache key, which must precede 0.1.0.
19. Keep the forge snapshot honest. Covers B4-5, B4-10, B4-21, R1-45. S, no dependency, after.
20. Fix the flow stages. Covers B6-2, R1-13, B6-3, B6-4, B6-6. S, no dependency, after.
21. Keep `kit serve` alive and its schema current. Covers B7-6, B7-14, B7-15,
    B7-16, B7-21, B7-22. M, no dependency; after, except the work tool's hint.
22. Fix the terminal readers and welcome. Covers B8-6 to B8-9, B8-12 to B8-18. M, no dependency, after.
23. Signals and the guard: Ctrl-C, `--`, one form for an option's value, the words of a failed rebase. Covers
    B1-4, B1-8, B6-10, B1-10, B7-24, B8-15, B1-12, B1-16, B2-8, R1-29, R1-32. M, no dependency, after.
24. Work through the other low findings, the deny lists, and the three test faults, each fix with its
    test. Covers S5-10, R3-13, R3-14 to R3-16, and the lows no item above names. L, no dependency, after.
25. Decide which of the eight unplanned gaps 0.1.0 needs, and correct the six
    document statements. Covers R3-26, R3-19 to R3-24. S, no dependency, before.
