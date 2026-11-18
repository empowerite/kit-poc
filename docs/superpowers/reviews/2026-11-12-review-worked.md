# What became of the 107 high findings

The review of 2026-11-12 found 107 high findings and 4 critical ones. This page says what was done about them.
Each fix has its own issue, test and commit; `git log f7547dbb..HEAD` lists them, 131 commits at the time of
writing. The full gate passes at the last one: 1,643 bats tests, every kittui package at 100 percent of statements,
and `kit check`.

Nothing was run against a real forge, a CI runner or a real terminal. Every forge call is a fake built from the
tool's documented output, and every screen was tested at the model level.

## Count

| State | Findings |
| --- | --- |
| Fixed | 105 |
| Partly fixed | 2 |
| Not done | 0 |

The criticals were two bugs: the release digest (#298) and the untrusted clone that ran its own bash (#299, #303).

## Partly fixed

- **U4-3.** `kit issues issues`, `backlog`, `underway`, `kit changes changes` and `kit delivery releases|builds` print
  lists. Bare `kit issues`, `kit changes` and `kit delivery` still print the stages. Closing it needs three decisions:
  the shape of the bare `--json`, what a repository with no forge prints, and whether `--marks` gains the tab.
- **S3-2.** Every `{rows, errors}` stage document carries `contract: 1`, and a workspace member on another contract is
  named under `errors`. The four array stages (`kit flow issues`, `changes`, `builds`, `releases`) carry no number.
  Giving them the envelope is finding S3-6, which must be decided before v0.1.0 because the shape freezes.

## Choices that are yours to confirm

1. GitHub is named supported; GitLab and Azure DevOps are experimental until each has run against a live project.
2. Flag names `--sweep`, `--no-sweep` and `--behind`, and the rule that `kit work` without a terminal refuses a dirty
   desk until one is given.
3. `git rm --cached x` with `x` kept on disk is refused by a pathless `kit commit`.
4. `kit ready --report` keeps kit's `Closes` lines and replaces everything else in the body.
5. `kit tools run <command>` gives every word after the command's name to the command, which reverses an older test.
6. The MCP error code `-32003` for "not trusted", and the loader reading `version:` from `.kit/settings.yml`.
7. In CI, a base that pins `opa` only through mise, nix, a Brewfile or an image makes `kit policy` fail closed unless
   the runner supplies `opa`. CircleCI judges against the default branch. A GitLab push or tag pipeline with a
   detached HEAD fails standalone `kit policy`.
8. `Closes #N` is now written in the pull request bodies of `kit work` on every forge, GitHub included. The forge
   contract is version 8, with the feature `merge-closing`.
9. In kittui: Enter on an optional row only goes on; the form's command line runs only on a click while it has the
   keyboard; `q` quits only where a tab bar exists; a click on the cursor's row opens its menu; Packages' Add asks
   before it writes.
10. Over a group, a verb that writes still runs in the folder kittui started in, with `--workspace=<group>`.
11. kit names an issue of another repository `#5`, so kittui still tells "here" from "elsewhere" by path. The
    alternative, `other/repo#5`, redraws every issues golden. The patch is kept in the scratch folder of the run.
12. Whether 30 words is a hard limit in the prose style. A machine check over documents needs that decision.
13. The tab and menu colors are still dark-theme colors, and the radio, filter-mark and `⊘` glyphs are left alone.

## Known gaps the work found and left

- On `pull_request` the delivered workflow file is the branch's own, so a branch can drop `kit ci`. A ruleset that
  requires a workflow from the base repository closes it. The Settle job still reads the kit version from the
  branch's `kit.yml`, and the loader picks its release by the checkout's `kit.yml` on any CI.
- `kit update` in a same-version case says what to do and does not apply a changed answer; applying it needs the old
  answers kept somewhere git carries.
- Dropped packages are not retired by `kit update` (release-readiness plan, Task 7, second half).
- GitLab's `issue-assign`, `issue-close` and `issue-comment` discard their output on failure.
- Other whole-file `yq` writes (`~/.kit/settings.yml`, `workspaces.yml`, `bots.yml`) drop blank lines.
- `kit --workspace=nosuch kinds README.md` exits 0 and ignores the option (D2-2).
- Platform's settings tab shows `null` for `primary`, `flow` and `policy_engine` (D2-13).
- `kit/bin/kit` cites `docs/releases.md`, which does not exist (P1-15).
- The release-readiness plan still has Tasks 3, 4, 6, 7 (second half), 8 and 9 unbuilt: `pack` from the tag, a smoke
  test before publish, CI on macOS, the changelog gate and `SECURITY.md`.
- The tutorials site has not been published. Its one-time steps are in `projects/tutorials/README.md`.

## Live checks that lift "experimental"

### Azure DevOps, in a throwaway organization

1. Sign-in: run `kit flow` after `az login`, and again with only `AZURE_DEVOPS_EXT_PAT` set. `forge/ado:require`
   runs `az account show`, which a token alone is expected to fail (I3-6, B5-9).
2. Each read once, keeping the raw answer as the example in `docs/integrations/az/`:
   - `repos pr list`, active and `--status completed --top 51`; is the completed list newest first?
   - `repos pr show`, `repos pr policy list`, `repos pr work-item list`
   - `boards work-item show`
   - `boards query`, including one that finds nothing: does az print nothing?
   - `pipelines runs list --reason` for each of the four reasons, and `pipelines runs artifact list`
   - `devops team list` and `devops team list-member`
   - `boards iteration team list` with no `--team` (I3-4, B5-10)
   - `repos policy list --branch --repository-id` and `repos show`
3. The five `az devops invoke` routes, with the names kit writes: `git`/`pullRequestThreads`;
   `git`/`pullRequestLabels`, POST and DELETE; `distributedtask`/`environments` with `$top=101`;
   `distributedtask`/`environmentdeploymentrecords` with `top=51`, and its order;
   `PipelinesChecks`/`queryconfigurations`,
   POST with `$expand=settings`.
4. The 1000 cap: in a project past 1000 open work items, does `az boards query` answer exactly 1000, and does
   `kit flow issues` then list them all (#343)?
5. Closing states: in a Basic-process project, does a completed close go to Done after Closed is refused? What does
   az print and exit with on a refused state? Is `kit close --not-planned` refused with the new line (#376)?
6. Merge: run `kit work 7 8`, then complete the pull request with and without "complete associated work items".
   Does `kit settle` close 7 and 8 once each? Does `Closes #8` in the description link item 8 by itself? Does
   `kit linked` pass on an Azure Pipelines pull request build (B7-8)?
7. Remote forms: `<org>.visualstudio.com`, with and without `DefaultCollection`; `vs-ssh.visualstudio.com`; a project
   name with a space; a non-ASCII name (I3-11, I3-16, B5-14).
8. Ids: are pull request and work item ids organization-wide (B5-20)?
9. Cost: time `kit flow changes` with 20 open pull requests (I3-12, B5-11).
10. Writes: `kit work`, `kit ready`, `kit assign` (replaces the assignee, B5-6), label add and remove; do builds and
    artifacts include other repositories of the project (B5-5)?

### GitLab, in a throwaway project

1. Closing line: after `kit work 7`, does the merge request description hold `Closes #7`, does
   `merge_requests/<n>/closes_issues` list 7, does `kit linked` pass, and does the merge close the issue? Also confirm
   the premise: does a `7-<slug>` branch with an empty description give an empty `closes_issues`?
2. Threads: is the unresolved count discussions, not notes (B5-4, R1-14)?
3. Checks and reviews: a failed job with `allow_failure` (B5-12), a reviewer who requests changes (I2-4), and a job
   that is `waiting_for_callback` (I2-3).
4. Project path: a checkout with two GitLab remotes and `primary: upstream`: do writes go to the primary's project
   (B5-18)? Try subgroup paths, ssh with a port, and a branch name with `/` (B5-13, R1-44).
5. Builds: the `scope=tags` and `source=` pipeline reads from eb13c9a0.
6. Smaller answers: a merged request's merge commit under squash and fast-forward, a 403 or 404 on iterations read
   as off, group milestones (B5-19).
7. Cost: time `kit flow changes` with 20 open merge requests (B5-11, R1-20).
