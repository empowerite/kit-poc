# How much of the integrations research the product uses

## The answer

No. The product uses the research on git and on the three forges it has providers for:
GitHub, GitLab, and Azure DevOps. It uses that research as reference for whoever writes a
provider. No code, test, or generator reads a research file. The one exception is a gate
loop that checks each schema against the examples inside the same file (bin/ci:54-61).

The research is 40 pages (3,803 lines) and 79 schema files. Outside git it holds 708 capability rows. 156 of them
have code, whole or in part: 59 of 91 for `gh`, 56 of 79 for `glab`, and 41 of 71 for `az`. The other 552 have none:
85 on the three forges, 42 for AWS, and all 425 on the thirty other tool pages, whose 34 services kit never calls.

Where a provider exists, the research and the code fit closely. Each of the 79 schemas describes
a call a provider makes, and every example validates. The tests do not use them. Their fixtures
were typed apart from the examples, and 20 of 62 now fail the schema of the command they fake: 3
of 14 for GitHub, 10 of 29 for GitLab, and 7 of 19 for Azure DevOps (I1-1, I2-1, I3-8).

Two lines of the delivered welcome page promise more than the code holds: trackers "such as Jira and Linear",
and `kit ci` "in any CI system" (kit/packages/kit/files/repo/.kit/welcome/1-introduction.md:13, :15).

This section rests on the findings of I1 to I5 and on the skeptics' verdicts on five of their six high
findings. I read the code at every place cited under High and at most of those cited under Medium. In the
citations, github.sh, gitlab.sh, and ado.sh are in kit/modules/bash/forge/, forge.sh, git.sh, and tracker.sh
are in kit/modules/bash/, forge.jq is in kit/modules/jq/, and a page such as gh.md is in docs/integrations/.

## The research set

| Integration | Gathered | What the product uses | What it leaves unused |
| --- | --- | --- | --- |
| git | `git.md`, 424 lines; no schemas | The whole page, as a catalogue of what kit runs: 46 of 46 sampled command forms are in the code | Nothing. Five forms kit runs are not in the page, and nothing checks for the git 2.31 the page says kit needs |
| GitHub (`gh`) | `gh.md`, 350 lines, 91 rows; 34 schemas | 59 rows: pull requests 29 of 29, issues 18 of 23, Projects 2 of 9, Actions 5 of 10, releases and deployments 5 of 20. Contract 6, lacking only swimlanes | 32 rows: rerun, cancel, and the log of a failed run; who must approve a waiting deployment; what is live in each environment; the Projects Status field; sub-issue reads; all 15 writes to Projects, Actions, releases, and deployments |
| GitLab (`glab`) | `glab.md`, 267 lines, 79 rows; 26 schemas; links to GitLab's published OpenAPI and GraphQL descriptions | 55 rows, and 1 in part: merge requests 28 of 28, issues 18 of 24, CI 3 of 9, releases and deployments 6 of 18. Contract 5, lacking attestations, bypasses, and swimlanes | 23 rows: a build's jobs and why one failed; a job's log; what is live where; a deployment's approvals; all 12 CI and deployment writes; linked items, epics, and milestone and iteration writes. Nothing fetches the published descriptions |
| Azure DevOps (`az`) | `az.md`, 250 lines, 71 rows; 19 schemas | 34 rows, and 7 in part: Repos 19 of 27, Boards 17 of 21, runs 2 of 9, environments and releases 3 of 14. Contract 5, lacking 12 features | 26 rows, and 4 the forge cannot give: work item transition and `pr work-item add`; sign-in by token; the build timeline; pending approvals; work item relations; `System.BoardColumn`; classic releases; linked branches |
| AWS (`aws`) | `aws.md`, 258 lines, 42 rows for CodeCommit, CodeBuild, CodePipeline, and CodeDeploy, and a plan for a provider; no schema files | Nothing. No `aws` call exists in kit or kittui | All of it. The plan is written against contract 3 and names 9 of the contract's 31 features |
| The index and the category pages | `1st.md`, `forges.md`, `trackers.md`, `ci.md`, `cd.md`: 562 lines, 739 coverage cells | The columns of kit's three providers: 56 of 57 forge cells agree with what the providers declare | 553 cells are for providers with no code. In kit's own columns, 3 of 8 CI rows and 3 of 11 CD rows are used. 13 of the contract's 31 features are in no matrix |
| Other forges | `bkt` (Bitbucket Cloud and Data Center, 40 rows), `hut` (SourceHut, 21), `fj` (Forgejo and Codeberg, 20), `gerrit` (20), `rad` (Radicle, 20), `tea` (Gitea, 20) | Nothing | All 141 rows |
| Trackers | `jira` (20 rows), `linear` (20), `short` (Shortcut, 17), `yt` (YouTrack, 16), `bugzilla` (15), `tea` (Gitea and Forgejo issues, 15), `redmine` (12), `op` (OpenProject, 11), `plane` (9), `taiga` (7) | Nothing. The `web` provider opens two pages of any tracker and reads nothing from it | All 142 rows. `jira.md` and `linear.md` give a command for each of the eleven tracker calls |
| CI systems | `jenkins`, `circleci`, `bk` (Buildkite), `drone`, `woodpecker-cli`, `tkn` (Tekton), `argo` (Argo Workflows), `fly` (Concourse), and the Pipelines and Actions sections of `bkt` and `tea`: 8 rows each | Nothing directly. Their checks reach `kit changes checks` through GitHub's check rollup | All 80 rows, and the eight pull request variables at ci.md:37-40 |
| CD systems | `octopus` (11 rows), `harness` (10), `argocd` (9), `spin` (Spinnaker, 9), `flux` (8), `kargo` (8), `kubectl` (Argo Rollouts and Kubernetes resources, 7) | Nothing directly. Argo CD's GitHub deployments reach `kit delivery deployments` | All 62 rows |

The thirty other pages have no schema files. They carry 83 links to schemas
published on the network, and the gate, which runs offline, fetches none (I5-9).

## The design that makes the research drive code

Three things stop the research from driving code today (I1-5, I2-5, I4-16, I5-7).

- A capability row is keyed by a name in prose, such as "Checks rollup", where the seam
  call is `open-prs`. One cell holds both what the tool can do and what kit runs
  (glab.md:43). Of the thirty pages' 425 rows, 125 hold several commands and 38 hold none.
- A schema names its provider function and its jq fold in a sentence of its
  `description`. Three GitHub schemas name a fold that does not exist, and seven
  GitLab schemas name `gitlab_marks` where the fold is `gitlab_mark` (forge.jq:237).
- The contract is three bash arrays (forge.sh:287-309), stated again in the header's prose. What a forge is
  called, which tool signs in, and where its pages are sit in fourteen places outside the providers (I5-6).

The five reviewers each proposed a design, and they agree in substance. They differ on where a
schema is tied to a call: in a key inside the schema (I1-5, I3-8, I4-16), in a file per provider
(I2-5), or in a file beside each tool page (I5-7). One schema can serve five calls
(docs/integrations/glab/api-merge-requests.schema.json), so the tie belongs with the call. I settle
it as one row format in one file per tool. A schema keeps its command, its types, and its examples.

1. State the contract once. Move `forge_features`, `forge_feature_of`, and
   `forge_call_since` (forge.sh:287-309) and the header's two tables into one data file of
   call, feature, version, and kind. forge.sh reads it, a loop defines the plain wrappers,
   and the 13 `return 3` stubs go. One test holds each provider to it. (S2-5, S4-5, I4-16)
2. Give each tool one declaration. A provider's file ships beside its module, as
   kit/modules/bash/forge/gitlab.json. It holds the contract version, what the forge lacks, what kit has not
   written, and one row per seam call: read or write, the arguments kit runs, the fold, the schema, and whether
   a live run verified it. It also holds the facts now typed outside the providers: hosts, the runner's
   variable for the change number, the tool, the sign-in check, the noun, the page addresses, and the glyph. A
   researched tool with no code keeps the same rows in a file beside its page. (I2-5, I5-6, I5-7, S2-4, B8-3)
3. Draw the tests from the schemas. The gate checks four things. Each schema example folds to a document that
   fits a schema of the seam call's output. Each answer the fake served fits the schema of its row. Each call
   the fake logged matches one declared row, and each row was called. Each status a schema enumerates goes
   through its fold. A helper beside `fixture` (tests/helper.bash:293) writes a schema's first example,
   edited for the case, so a new fixture is not typed. (I1-1, I2-1, I2-3, I3-8, I4-8, I5-9, S4-2)
4. Generate the pages' tables. `kit generate` regions fill each page's schema table, a column
   for what kit uses, and the category matrices, all from the declarations. (I4-4, I4-7, I5-8)
5. Run a provider that is rows alone. One generic module runs a declaration whose rows give the arguments and
   a jq read for each call. Jira and Linear then need a declaration and examples, and no bash. The command
   provider of the entities specification (docs/superpowers/specs/2026-11-09-entities-design.md:105-109)
   covers a tool that rows cannot express. (I5-7)
6. Add an opt-in live run. It makes each read once against a real repository or
   organization and keeps the answers as the schemas' examples. (I1-5, I3-1)

The first check of step 3 needs no declaration. The GitHub reviewer folded
23 examples by hand, and all gave the seam's documents. Take it first.

Step 3 would have caught the drifted fixtures, the fold that does not exist, and
the GitLab status drawn as failed. Step 2 would have caught the welcome checks
that skip Azure DevOps. Step 4 would have caught the pages that state contract 3.

## The order to build providers

Finish the three providers that ship before adding a fourth. The order merges the reviewers' rankings.
I4-15 puts Gitea and Forgejo ahead of Bitbucket. I follow I5-3, whose reviewer read those pages whole.

1. Three uses of research already written, each under a day: builds filtered by the server (High 1), the change
   number from other CI systems' variables (High 3), and a link from an external check to its run (I5-11).
2. Depth in GitHub, GitLab, and Azure DevOps, in this order: the jobs and failed step
   of a build on GitLab and Azure DevOps; the log, rerun, and cancel of a failed run,
   which all three tools have; what is live where and who must approve; the Projects
   Status field and `System.BoardColumn` as a native lane. (I1-4, I2-11, I3-13, I4-15)
3. The tracker seam: a version, `lacks`, exit 3, a call that
   lists issues, and a reference pattern per record. (I5-4, I5-5)
4. Jira, then Linear. The welcome page names them, and each page holds a
   command for all eleven tracker calls (jira.md:35-59, linear.md:26-50).
5. Bitbucket Cloud through `bkt`, with Pipelines.
6. Gitea and Forgejo through `tea`, once the runner is told apart from GitHub's (I5-10).
7. A CD seam, then Argo CD reads.
8. A CI seam, then CircleCI and Buildkite, then Jenkins.
9. Flux, Kargo, YouTrack, and Shortcut. AWS follows once its plan is restated against the 31 features (I4-14).

Leave Gerrit, SourceHut, Radicle, and the trackers with no
command line tool to the `web` provider or a command provider.

## High findings

The five areas hold 70 findings: no critical, 6 high, 36 medium, and 28 low. The skeptics refuted none. They
confirmed one high finding and narrowed four. They did not check the sixth, I3-3, so I read its code myself.

1. The builds stage misses builds. Each provider asks for the 50 newest runs of every kind and filters
   afterwards (github.sh:796, gitlab.sh:589, ado.sh:504, forge.jq:387-391), so a repository whose pull
   requests run CI gets a short or empty list, with exit 0 and no `limited` mark. The Azure DevOps read
   also keeps the runs of other repositories in the project. The research lists the server's filter for
   each forge (gh.md:215, az.md:146, ci.md:131): ask per kind, merge, and print `{"limited": N}` when
   the window ran out. Confirmed, and known since 11-10. (I4-1, I1-3, B4-4, B5-5)
2. The welcome page names Jira and Linear, and the only code for either is the `web` provider, which
   builds two page addresses and refuses the other nine calls (kit/modules/bash/tracker/web.sh:17-56).
   A pull request whose only linked issue is in such a tracker fails `kit linked` with "run: kit linked
   again once the tracker answers", which cannot happen (kit/bin/kit-linked:116-131), and `kit settle`
   exits 1 on it. The skeptic narrowed the finding: `kit linked` passes when a forge issue is linked
   too, and docs/trackers.md:78-81 states the limit. Reword the welcome line, and let the tracker seam
   answer 3 for a call a provider cannot make, so both verbs say what is true. (I5-1, B5-7)
3. `kit ci` cannot find the pull request on Jenkins, CircleCI, Buildkite, Drone, or Woodpecker when
   the checkout is a detached HEAD. `forge/github:pr-here` reads GitHub's event file and then the
   branch (github.sh:681-694), and kit reads none of the eight variables ci.md:37-40 lists. The
   skeptic narrowed the finding: with the branch checked out the read works, and ci.md states the gap,
   so only the welcome line overstates. Read the number in the seam from a table of those variables
   before the branch is asked about, and keep the refusal for a runner that sets none. (I5-2)
4. The Azure DevOps provider is tested against its own fake alone. The research says its
   `az devops invoke` routes were never tried against a live organization (az.md:70, :163, :211), and
   five such calls carry the Delivery app, the unresolved count, and the labels (ado.sh:129, :158, :322,
   :636, :679). The skeptic's verdict is partly: the gap is disclosed, and the tree cannot show that no
   other call ran live. Run each seam call once against a throwaway organization and keep the answers as
   the schemas' examples, or call `ado` experimental in the release notes and in 1st.md. (I3-1)
5. On Azure DevOps a merged pull request can leave its work items open. `forge/ado:pr-create` links only
   the number the branch starts with and never passes `--transition-work-items` (ado.sh:360-367). A second
   issue gets a `Closes #8` line, which the research says Azure DevOps ignores (az.md:68-69), and
   `kit settle` closes neither. kit's side is reproduced; that the items stay open is plausible, since it
   depends on how the person completes the pull request. Link every issue with `az repos pr work-item add`
   (az.md:118, never called), and have `kit settle` close what the forge left open. (I3-2, B5-2)
6. A close that Azure Boards refuses prints only "#7 could not be closed". `forge/ado:issue-close`
   discards az's output (ado.sh:198), so the user sees neither az's reason nor the setting that
   fixes it. The defaults, Closed and Removed (ado.sh:189, :192), are plausibly not states of the
   Basic process a new organization gets. On a failed state change print the remedy,
   `forge_settings.ado.closed_state` or `removed_state`, and then az's last line. (I3-3)

## Medium findings

The research reaches neither the code nor the tests. The loop at bin/ci:54-61 is the only reader of a schema.
1st.md:117 says a schema is what a provider's fixtures can be checked against, and nothing makes that check.
Schemas lack fields the providers read (github.sh:485, forge.jq:335-336, ado.sh:297), and one GitHub read has no
schema (github.sh:881). The design above is the fix. (I1-1, I1-5, I2-1, I2-5, I3-8, I4-8, I4-16, I5-7, I5-9, S4-2)

The pages lag the code. Three pages state contract 3 where the code is at 6 (1st.md:33, az.md:23,
aws.md:186, against forge.sh:287). forges.md:32 and :40 and docs/integrations/trackers.md:11 call
shipped tabs planned. ci.md:12 says each run comes with its jobs, which holds for five GitHub runs and
for no other. az.md:23 lists four lacking features where the provider declares twelve (ado.sh:88-91).
Correct the rows by hand now, and generate kit's columns later. (I4-4, I5-8, P3-1, P3-2)

The code gets wrong five things the research records.

1. A repository or owner named in digits breaks ten GraphQL reads, because
   `--field` sends 2048 as a number (github.sh:106 and nine more). gh.md:317
   teaches the flag. Use `--raw-field` in both. Known since 11-10. (I1-2, B4-8)
2. A GitLab job that is `waiting_for_callback` is drawn failed or cancelled. The
   schemas list 13 statuses, and the folds name fewer (forge.jq:249-250, :418-421).
   Add the status, and feed every enumerated value to the folds in a test. (I2-3)
3. A GitLab merge request with changes requested is drawn ready, because approval tests
   `not_approved` alone (forge.jq:272). Add `requested_changes`. Known since 11-10. (I2-4, B5-12)
4. A failed build names no job on GitLab or Azure DevOps (gitlab.sh:585-594,
   ado.sh:498-500), though glab.md:149 and az.md:147 give the read and GitHub's
   builds carry jobs. Read the jobs of the few newest or failed runs. (I2-2, I3-17)
5. `az boards query` answers 1000 work items at most, as its schema says
   (docs/integrations/az/boards-query.schema.json:4), and `open-issues` takes a
   list of 1000 as whole (ado.sh:301). Fail at 1000, or read the items in batches.
   The cap is plausible until a live az shows it. High in its own area. (B5-1)

Azure DevOps has six more faults.

1. A work item closed to a configured state reads OPEN for ever, because the closing states
   are a literal list in three places (forge.jq:448, kit/modules/bash/tracker/ado.sh:83,
   ado.sh:298). Define them once, the two settings included. (I3-5, B5-3, S2-1)
2. Azure Boards is implemented twice, and the copies differ. The tracker's `create` drops
   the body, so `kit gather` makes an empty parent (kit/modules/bash/tracker/ado.sh:62).
   Write one boards module that both call. (I3-7, I3-9, S2-2, B5-8, B5-17)
3. Sign-in by token is unsupported, plausibly: `require` and `me` run `az account show`
   (ado.sh:261, :478), which a token alone does not satisfy, as on an Azure Pipelines
   job. Read the caller from the organization's connection data. (I3-6, B5-9)
4. `kit issues iterations` passes `--team` only when a setting names one (ado.sh:246), and az plausibly requires
   it. The delivered schema refuses that setting (kit/packages/kit/files/repo/.kit/kit.schema.json:162-164).
   Read the project's default team, and add `team` to the schema. (I3-4, I3-10, B5-10)
5. A project with a non-ASCII name is decoded byte by byte, and
   every call then fails (ado.sh:571). Use jq's `@urid`. (I3-11)
6. Each open pull request costs three `az` processes in sequence (ado.sh:317), so 20 pull requests
   plausibly take about a minute. Read the place once, and run the reads a few at a time. (I3-12, B5-11)

The seams and the matrices are not ready for a fourth provider.

1. `lacks` says both "the forge cannot" and "kit has not written it". Azure DevOps declares linked branches
   lacking (ado.sh:88-91) where forges.md:79 says its tool makes them. Add a third state, unwritten. (I4-5)
2. A tracker reference cannot be `ENG-123`. A prefix must be letters and an optional `#`
   (kit/modules/bash/settings.sh:106), while jira.md:14 and linear.md:13 tell the reader to
   write `ENG-`. Let a record carry its pattern, its branch key, and its closing line. (I5-4)
3. The tracker seam has no version, no `lacks`, no exit 3, and no call that lists
   issues (tracker.sh:34-49). Give it what the forge seam has. (I5-5, S2-12)
4. Facts about each forge are decided by name in fourteen places outside the providers, so `kit welcome`
   plans no check for Azure DevOps (forge.sh:406-415, kit/modules/bash/welcome.sh:454-458,
   projects/tui/internal/flow/rows.go:556). Move them into the provider's declaration. (I5-6, S2-4, B8-3)
5. The closing-issues stand-in returns 1 and says nothing on a forge without issues, the
   case the AWS plan relies on (forge.sh:822). Ask the tracker seam for the state. (I4-6)
6. Thirteen of the contract's 31 features are in no category matrix, and no row names a seam call
   (forges.md:71). Key every row by feature, and add a category for people and controls. (I4-7)

git has two faults. On git older than 2.31, `kit rebase` rebases and force-pushes the root checkout it
promises to refuse (git.sh:47, :458). git.md:18 records that kit checks no version, so refuse an older
git in `guard:require` and in `kit welcome`. `kit tidy` stops with git's exit 128 when one remote
cannot be fetched (git.sh:314). Warn, skip that remote's branches, and go on. (I4-2, I4-3, P3-12)

About a third of what was researched for each of the three forges is unused, and
all of the thirty other pages. The order above ranks it. (I1-4, I3-13, I4-15, I5-3)

## Low findings

The 28 low findings, by title:

- gh.md and its schema descriptions are stale in eight places (gh.md:16, :104, :346). (I1-6)
- Six kinds of call the product makes are not in gh.md (github.sh:697, :1427). (I1-7)
- The zero time gh prints for a missing time fails the runs read (forge.jq:377, :409). (I1-8)
- The latest release is guessed from creation dates; plausible (forge.jq:357). (I1-9)
- A Dependabot finding is drawn without its package (forge.jq:1037). (I1-10)
- A fork's pull request on a branch of the same name answers
  for the branch; plausible (github.sh:919). (I1-11, B4-12)
- kit's GitLab label calls are in no research page (gitlab.sh:478-484). (I2-6)
- The GitLab schemas miss five fields kit reads and type about twenty it does not (forge.jq:335-336). (I2-7)
- glab.md contradicts the provider or itself in four statements (glab.md:6, :30, :35). (I2-8, P3-10)
- Editing a GitLab release's notes does not move the releases mark (forge.jq:240). (I2-9)
- The GitLab milestones mark relies on a `sort` parameter
  the route may not take; plausible (gitlab.sh:237). (I2-10)
- GitLab serves 55 of 79 researched capabilities, and no published schema is consumed (glab.md:28-216). (I2-11)
- All but two of the GitLab provider's calls are in the research (gitlab.sh:29-799). (I2-12)
- What the product shows from GitLab, with no change asked (forge.sh:60-186). (I2-13)
- Every Azure DevOps failure says "run: az login", whatever az said (ado.sh:592). (I3-14)
- az.md is behind the provider in five places and omits two calls (az.md:23, :100, :117). (I3-15)
- Two older Azure DevOps remote forms are refused or misread (ado.sh:559). (I3-16, B5-14)
- A failed Azure Pipelines run names no job and no failed step (ado.sh:498). (I3-17)
- docs/trackers.md names GitHub and GitLab alone as the code forge (docs/trackers.md:4, :21). (I3-18)
- `kit flow --capabilities` is documented as kittui's, and
  kittui never asks for it (docs/architecture.md:193). (I4-9)
- A fractional marks interval passes validation and breaks the arithmetic (forge.sh:721). (I4-10, B4-18, B5-16)
- A branch that shares its name with a tag is read as `heads/v1` (git.sh:112, :452). (I4-11)
- The fetches of `kit flow` can ask for a password under kittui;
  plausible (kit/modules/bash/flow.sh:580, :1349). (I4-12)
- git.md's two safety claims have exceptions, and it omits five
  call forms (kit/modules/bash/policy.sh:304, :366). (I4-13)
- The AWS plan is written against contract 3 and omits labels (aws.md:186, :219). (I4-14)
- On a Forgejo or Gitea Actions runner kit takes the forge for GitHub (forge.sh:404-408). (I5-10)
- A check from another CI system has no link to its run (github.sh:546-547). (I5-11)
- Three small faults in the thirty pages (hut.md:58, circleci.md:33, kubectl.md:12). (I5-12, P3-8)

## What is done well

- The schemas match the providers one to one, with no orphan, and every example validates. The
  examples are good enough to become the tests' fixtures. Leave their titles as the command kit runs.
- The research says what it did not verify, in the pages and inside the schema
  descriptions. All 34 other services have a status of none, which is true.
- The forge contract is the right base for declarations: a version, `lacks`, exit 3, stand-ins, and
  `kit flow --capabilities`. A lacked feature is answered without running the provider, and nothing is faked.
- The code honors constraints the research recorded, each with a test: GitLab's `merged_at` ordering from
  17.2, a tier without a feature answering 403 or 404 as off, and a capped list saying `{"limited": N}`.
- git.md is accurate as a catalogue of what kit runs, and it states its own hazards.
- The sections on other forges use the same 15 reads and 5 writes in
  the same words. That is the model for the tracker, CI, and CD pages.
- tests/forge-conformance.bats drives each provider through one world with
  a fake that logs every call. The schema checks need exactly that log.

## Work items

1. Ask each forge for builds by kind, and keep Azure DevOps to its own repository.
   Covers I4-1, I1-3, B4-4, B5-5. Size S. Depends on nothing. Before the release.
2. Make the tracker claim true: reword the welcome line, answer 3 from a `web` tracker, and correct
   what `kit linked` and `kit settle` say. Covers I5-1, B5-7. Size S. Depends on nothing. Before.
3. Read the change number from other CI systems' variables, tell a Gitea or Forgejo
   runner from GitHub's, and link an external check to its run. Covers I5-2, I5-10,
   I5-11. Size S. Depends on nothing. Before for I5-2, after for the rest.
4. Run the Azure DevOps provider against a live organization, or call it
   experimental. Covers I3-1, and settles what is plausible in I3-2, I3-3, I3-4,
   I3-6, I3-12, and B5-1. Size M. Depends on an organization to test in. Before.
5. Close Azure DevOps work items correctly: link every issue, close after a merge, name the remedy on a
   refused close, define the closing states once, and write one boards module. Covers I3-2, B5-2, I3-3, I3-5,
   B5-3, S2-1, I3-7, I3-9, S2-2, B5-8, B5-17, I3-14. Size M. Depends on item 4 for the live answers. Before.
6. Fix the other Azure DevOps reads: sign-in by token, the default team and its schema key, non-ASCII names,
   the 1000 work items, older remote forms, and the cost of a pull request. Covers I3-6, B5-9, I3-4, I3-10,
   B5-10, I3-11, B5-1, I3-16, B5-14, I3-12, B5-11. Size M. Depends on item 4. Before, except I3-12 and I3-16.
7. Correct the GitHub and GitLab reads. Covers I1-2, B4-8, I2-3, I2-4, B5-12, I1-8, I1-9, I1-10, I1-11,
   B4-12, I2-9, I2-10. Size M. Depends on nothing. Before for I1-2, I2-3, and I2-4, after for the rest.
8. Make the git calls safe: refuse git below 2.31, survive an unreachable remote in
   `kit tidy`, read a branch that shares its name with a tag, and stop fetches from
   prompting. Covers I4-2, I4-3, I4-11, I4-12, P3-12. Size S. Depends on nothing. Before.
9. Bring the research pages level with the code by hand. Covers I4-4, I5-8, P3-1, P3-2, I1-6, I1-7, I2-6,
   I2-7, I2-8, P3-10, I3-15, I3-18, I4-9, I4-13, I4-14, I5-12, P3-8. Size M. Depends on nothing. Before.
10. Repair the forge seam's small faults: an integer marks interval, the closing-issues
    stand-in through the tracker seam, and an unwritten state beside `lacks`. Covers I4-10,
    B4-18, B5-16, I4-6, I4-5. Size S. Depends on nothing. Before for I4-10, after for the rest.
11. Fold every schema example in the gate, feed each enumerated status to its fold, and
    add the fields the providers read to the schemas. Covers the first check of design
    step 3, I2-7, and part of I1-1, I2-3, and I3-8. Size S. Depends on nothing. Before.
12. State the contract and each provider's declaration as data. Covers S2-5,
    S4-5, I1-5, I2-5, I4-16, I5-6, S2-4, B8-3. Size M. Depends on nothing. After.
13. Draw the tests' fixtures from the schemas, and check the fake's calls and answers
    in the gate. Covers I1-1, I2-1, I3-8, I4-8, I5-9, S4-2. Size M for the helper and
    the gate, L to move all 351 inline fixtures. Depends on items 11 and 12. After.
14. Put the research rows in data, and generate the pages' tables and the category matrices.
    Covers I5-7, I4-7, I2-12, and keeps item 9 true. Size M. Depends on item 12. After.
15. Give the tracker seam a version, `lacks`, a call that lists issues, and a reference
    pattern per record. Covers I5-4, I5-5, S2-12. Size M. Depends on item 2. After.
16. Deepen the three providers: jobs on GitLab and Azure DevOps, a failed run's log,
    rerun, and cancel, what is live where, approvals, and native lanes. Covers I1-4,
    I2-2, I2-11, I2-13, I3-13, I3-17, I4-15. Size L. Depends on items 1 and 13. After.
17. Write the generic provider that runs a declaration, then Jira and Linear on
    it. Covers I5-3 and design step 5. Size L. Depends on items 13 and 15. After.
18. Build Bitbucket Cloud, then Gitea and Forgejo. Covers I5-3. Size L. Depends on items 12, 13, and 14. After.
19. Add a CD seam and a CI seam, then Argo CD reads, CircleCI, Buildkite, and
    Jenkins. Covers I5-3, I5-5. Size L. Depends on items 12 and 13. After.
