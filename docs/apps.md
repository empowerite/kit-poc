# App verbs

kittui is kit's terminal UI. It has nine apps, and each app has a verb. Each tab of an app shows one stage: one list
that kit reads and prints. At a terminal, the verb opens the app. Off a terminal, or with an output option, the verb
prints its stages as text or as JSON.

This page is the reference for what the app verbs print: the options they share, the JSON of a stage, and the fields
of every stage. `kit tutorials` teaches the screens, and `kit help <verb>` lists a verb's options.

## The nine apps

| App | Verb | Tabs, in order |
| --- | --- | --- |
| Flow | `kit flow` | issues, changes, builds, incoming, releases |
| [Issues](#issues-kit-issues) | `kit issues` | issues (from `kit flow`), milestones, iterations |
| [Changes](#changes-kit-changes) | `kit changes` | changes (from `kit flow`), reviews, checks, merged |
| [Repositories](#repositories-kit-workspace) | `kit workspace` | repos, worktrees, branches, commits, tags, remotes, incoming (from `kit flow`) |
| [Delivery](#delivery-kit-delivery) | `kit delivery` | releases and builds (from `kit flow`), artifacts, environments, deployments |
| [People](#people-kit-people) | `kit people` | people, teams, agents |
| [Trust](#trust-kit-audit) | `kit audit` | evidence, findings, controls, waivers, policy, enforcement |
| [Platform](#platform-kit-platform) | `kit platform` | services, toolchains, tools, settings |
| [Packages](#packages-kit-packages) | `kit packages` | packages |

- A tab marked "from `kit flow`" shows a stage of `kit flow`. Its app's verb prints it too; see
  [Tabs that show a stage of kit flow](#tabs-that-show-a-stage-of-kit-flow).
- The Flow app shows the stages that the `flow` setting in `kit.yml` names, in that order. `kit help flow` describes
  what `kit flow` prints. The rest of this page is about the other eight verbs.
- Two apps are not named for their verbs. The verb of Trust is `kit audit`, because `kit trust` is the verb that
  trusts a clone. The verb of Repositories is `kit workspace`.

## The shape every app verb shares

In this section, `<verb>` is any of the eight verbs after `kit flow`, and `<stage>` is one of its stages.

| Command | At a terminal | Off a terminal |
| --- | --- | --- |
| `kit <verb>` | opens the app in kittui | prints every stage as text |
| `kit <verb> <stage>` | opens the app on that tab, maximized | prints that stage as text |

A verb opens kittui only when its input, its output, and its error stream are all a terminal, and kittui is
installed.

| Option | What the verb prints |
| --- | --- |
| `--text` | text, at a terminal too |
| `--json` | with a stage, the stage's document; with no stage, one object that holds every stage's document |
| `--jq` | the same JSON, formatted by `jq` for a person |
| `--stages` | the names of the verb's own stages, one per line |
| `--marks` | one JSON object that holds a mark for each stage |

- With `--json` and no stage, the object is `{contract, stages, <stage>: document, …}`. A stage that kit could not
  read is `null`.
- `--stages` leaves out a tab that shows a stage of `kit flow`.
- `kit packages` with no stage is different: it lists the packages. See [Packages](#packages-kit-packages).

### Marks

A mark is a short string that changes when the content of its stage changes. kittui compares marks to decide when to
load a tab again. A stage that never has a mark prints `null`. kittui loads the tab of such a stage again only when
you choose Refresh, and its tab menu has no Watch.

### Exit status

| Status | When |
| --- | --- |
| 0 | kit printed every stage you asked for |
| 1 | kit could not read a stage, and printed the stages it could read |
| 2 | a usage error, or the command ran outside a repository with no workspace |

A bare repository and a `.git` directory have no working tree, so both count as outside a repository.

### Over a workspace

A workspace is one repository, or a named group of repositories; see [workspaces.md](workspaces.md). A member is one
repository of a group, named by its host and path, such as `github.com/empowerite/edge`.

`kit --workspace=<group> <verb>` runs the verb in the checkout of every cloned member at once, and prints one
document for each stage.

- Each row and each error gains `member`, the member's host and path.
- A member that kit could not read is `{member, error}` under `errors`. The other members still print, and the verb
  exits 1.
- Each member answers with the release of kit that its own `kit.yml` pins.

## The JSON of a stage

`kit <verb> <stage> --json` prints one object, the stage's document.

| Key | Meaning |
| --- | --- |
| `contract` | the number of the contract of the stage documents, 1 in this release |
| `rows` | the stage's rows, in the stage's order |
| `errors` | what kit could not read; empty when kit read everything |
| `limited` | present only when kit stopped at a cap: how many rows kit read, when the forge holds more |

### Rows

Every row holds its stage's own fields and these keys:

| Key | Meaning |
| --- | --- |
| `key` | identifies the row within its stage |
| `links` | where a value leads: an object from a field's name to a link |
| `organization` | the owner of the repository kit read the row in |
| `repository` | the name of that repository |
| `source` | what kit read the row from |
| `member` | over a workspace only: the member's host and path |

- A link is the URL of a page on the forge, or `row:<stage>/<key>`, which is a row of another stage. kittui follows
  the links that kit prints, and builds none of its own.
- The primary remote is the remote that kit reads issues and pull requests from. It is `origin`, unless `primary` in
  `kit.yml` names another. `organization` and `repository` come from the path of the primary remote's URL, after the
  host. On GitLab, `organization` is the group with its subgroups.
- When the primary remote is a path on this machine, `organization` is `null`, and `repository` is the name of the
  folder.
- `source` is the forge: `github`, `gitlab`, or `ado` for Azure DevOps. It is `kit` for a row that kit reads on this
  machine, such as a row of `kit platform`, and `git` for a row of `kit workspace`.
- A row that already has these three fields keeps its own values. For example, a row of `kit audit policy` names the
  place where the rule applies.

### Errors

A stage that reads the forge goes through the forge seam, `modules/bash/forge.sh`. The seam has one provider for
each forge, and a provider can lack a feature.

| Case | `rows` | `errors` | Exit |
| --- | --- | --- | --- |
| the primary remote is on no forge | empty | empty | 0 |
| the provider lacks the stage's feature | empty | empty | 0 |
| the forge has the feature off for this repository | empty | `{feature, off: true}` | 0 |

None of the three is a failure. When a read of the forge fails, kit prints no document for the stage. It says why
in one line, and the verb exits 1. Some stages add entries of their own to `errors`, and their sections say which.

## The contract of the stage documents

`contract` is one number. It is 1 in this release. kit prints it first in every stage document that is an object,
and in every picture. A picture is the object a verb prints with `--json` and no stage.

| Document | Printed by |
| --- | --- |
| `{contract, rows, errors}` | an app verb or `kit workspace`, for a stage; `kit flow`, for a stage over a workspace |
| the object for incoming | `kit flow incoming --json`, in one repository |
| `{contract, stages, …}` | `kit flow --json`, `kit workspace --json`, and `kit <verb> --json` |

The number changes when a document changes so that a reader of the old document would misread the new one: a key is
renamed, removed, or given another meaning. Adding a key does not change the number.

Two readers check the number:

- kit, over a workspace. Each member answers with the release its own `kit.yml` pins. When a member's document states
  another contract, kit merges none of that member's rows. The member is `{member, error}` under `errors`. The error
  gives both numbers and says which side to update. The verb exits 1.
- kittui. Its catalog, `projects/tui/internal/flow/fields.json`, states the number that kittui reads. kittui refuses
  a stage whose document states another number.

Both readers accept a document that states no contract.

`kit flow issues`, `kit flow changes`, `kit flow builds`, and `kit flow releases` print an array in one repository.
An array has no place for the number. So over a workspace, kit reads the array of such a member without the check.

## Moving between apps

Some values in a row are links to a row in another app. Following one opens the app built around that row's thing,
on the right tab, with the cursor on the row once the rows load. In Issues, the pull request of an underway issue opens
Changes, and the checkout the issue is worked in opens the worktrees tab of Repositories. In any app except
Repositories, a member's name over a group opens the repos tab of Repositories.

A link to another app leaves a crumb on the title line of the app it opens. The crumb comes after the workspace menu,
and after the maximized tab's name when a tab is maximized. It shows a dim `·` and `↩`, then the app and tab where you
followed the link.

- Click the crumb, or press `⌫` while the keys bar names it, to go back. kittui puts the view back as you left it: the
  tab, whether it was maximized, the preset, the sort, the filters, the groups, the row under the cursor, and the
  scroll.
- That place keeps its own crumb, so crumbs chain, each one a level deep.
- The workspace menu's Manage… leaves a crumb as a link does.
- The app menu, `=`, opens an app with no crumb and drops the chain. Switching to another workspace does the same,
  because it makes the apps anew there.
- Switching tabs inside an app keeps its crumb. Crumbs last for the session.

## Tabs that show a stage of kit flow

Issues, Changes, and Delivery each have a tab that shows a stage of `kit flow`. The app's verb takes the tab's name
too. At a terminal, it opens the app on that tab. Off a terminal, or with an output option, it prints what `kit flow`
prints for the stage. The incoming tab of Repositories is different: `kit workspace` does not take its name, and
`kit flow incoming` prints it.

| Command | Prints what this prints |
| --- | --- |
| `kit issues issues` | `kit flow issues` |
| `kit issues backlog` | `kit flow issues`, only the issues in the backlog |
| `kit issues underway` | `kit flow issues`, only the issues underway |
| `kit changes changes` | `kit flow changes` |
| `kit delivery releases` | `kit flow releases` |
| `kit delivery builds` | `kit flow builds` |

- With `--json`, each prints an array in one repository. Over a workspace, each prints `{contract, rows, errors}`,
  and every row has its `member`.
- At a terminal, `kit issues backlog` and `kit issues underway` open the issues tab on its Backlog or Underway
  preset.
- The app's verb with no tab named prints only its own stages. `kit issues` prints the milestones and the
  iterations, not the issues.

## Issues: kit issues

`kit issues` prints the planning that the forge keeps. The first tab of the Issues app, issues, shows every open
issue, and it is a stage of `kit flow`. That tab has seven presets: All Issues, which it opens on, Backlog, Underway,
By Milestone, By Iteration, By Swimlane, and Compact.

| Stage | A row for each | Order | Key | Mark |
| --- | --- | --- | --- | --- |
| `milestones` | milestone, open or closed | by number | `number` | the forge's mark of its milestones |
| `iterations` | iteration | by start | `id` | none |

### milestones

| Field | Meaning |
| --- | --- |
| `number` | the milestone's number |
| `title` | its title, which links to the milestone's page |
| `state` | `open` or `closed` |
| `due` | when it is due, in seconds since the epoch, or `null` |
| `open`, `closed` | how many of the milestone's issues are open, and how many are closed |

| Forge | Rows | Mark |
| --- | --- | --- |
| GitHub | the repository's milestones | the ETag of the first 100 milestones |
| GitLab | the project's milestones | the newest `updated_at` of a milestone and of an issue |
| Azure DevOps | none, and no error | none |

Azure DevOps has no milestones.

### iterations

| Field | Meaning |
| --- | --- |
| `id` | the iteration's id |
| `title` | its title, which links to a page on the forge |
| `start`, `end` | seconds since the epoch, or `null` for an iteration with no dates |
| `current` | `true` for the iteration that contains now |

`end` is the last second of the iteration's last day.

| Forge | Iterations kit reads | The title links to |
| --- | --- | --- |
| GitHub | those of the projects linked to the repository | the project |
| GitLab | the project's, and those of its groups | the iteration |
| Azure DevOps | those of one team | the team's sprints |

- On GitHub, a repository with no linked project has no rows. Reading a project needs the `read:project` scope for
  `gh`.
- On GitLab, a tier without iterations gives the error `{feature: iterations, off: true}`.
- On Azure DevOps, the team is the one that `forge_settings.ado.team` in `kit.yml` names. Without that setting, it is
  the project's default team.

## Changes: kit changes

`kit changes` prints what the forge reports about the repository's changes. A change is a pull request, which GitLab
calls a merge request. The first tab of the Changes app, changes, shows every open change, and it is a stage of
`kit flow`.

| Stage | A row for each | Key | Mark |
| --- | --- | --- | --- |
| `reviews` | open change and reviewer | the change's number and the login: `3 bob` | the forge's issues and runs |
| `checks` | open change and check | the change's number and the check's name: `3 a` | the same |
| `merged` | merged change, the 50 merged last | the change's number | the same |

The mark joins two of the forge's marks: the mark of its issues, which changes when a change does, and the mark of
its runs. Azure DevOps has no marks, so each mark is `null` there.

### How reviews and checks read the open changes

`reviews` and `checks` read the snapshot of the open changes that `kit flow changes` reads. kit reads that snapshot
from the forge at most once a minute, so both stages cost no extra request. With `--fresh`, each stage reads the
open changes again, as `kit flow changes --fresh` does. kittui's Refresh does the same, so it shows a review that was
given within the last minute.

| Forge | What one read of the open changes costs |
| --- | --- |
| GitHub | one GraphQL request |
| GitLab | the list, then two requests for each open merge request: its approvals and its discussions |
| Azure DevOps | the list of pull requests, which names the reviewers |

- On GitLab, every read of the open changes pays for the approvals, so `kit flow changes` and `kit flow issues` pay
  for them too.
- On GitHub, a token without the `read:org` scope cannot read a team that is asked to review. kit then reads again
  without teams, and the rows include no team.

### reviews

| Field | Meaning |
| --- | --- |
| `change` | the change's number |
| `title` | the change's title |
| `login` | the reviewer's login |
| `state` | `requested`, `approved`, `changes`, or `commented` |
| `at` | when the reviewer answered, in seconds since the epoch; `null` while `state` is `requested` |
| `unresolved` | how many threads on the change are unresolved; the same on each row of the change |

`state` is `requested` while the reviewer is asked and has not answered. Otherwise it is the reviewer's latest
review. The author's own comments are not a review.

| Forge | How kit decides `state` |
| --- | --- |
| GitHub | the latest approval or request for changes counts, even when a comment follows it |
| GitLab | `approved` when the reviewer approved, otherwise `requested` |
| Azure DevOps | a vote of 10 or 5 is `approved`, -5 or -10 is `changes`, and 0 is `requested` |

- On GitHub, a dismissed review counts as `commented`. A team that is asked to review is named by its slug.
- On Azure DevOps, `at` is always `null`, because Azure DevOps keeps no time for a vote.

### checks

| Field | Meaning |
| --- | --- |
| `change` | the change's number |
| `title` | the change's title |
| `name` | the check's name |
| `workflow` | the workflow that holds the check, or `null` |
| `event` | the event that started the run, or `null` |
| `verdict` | `passed`, `failed`, or `pending` |
| `at` | when the run started, in seconds since the epoch, or `null` |
| `took` | how long the run took, in seconds; `null` while it runs |

A check can run more than once on the head commit. Only its latest run counts, by start time. So a rerun that passed
replaces a run that failed.

GitHub names a check by its job only. So on GitHub, a row also gives the `workflow` that holds the job and the
`event` that started it, and the key holds both: `3 CI/pull_request a`. A job named `test` in two workflows is two
checks. A job that runs for a push and for a pull request is two checks as well. A `test` that passed later never
hides another `test` that failed. `workflow` and `event` are `null` for a check that belongs to no workflow, and on a
forge that names neither.

A provider written for a version of the forge contract before 4 does not have the `check-runs` call. On such a forge
the stage has no rows, and `errors` holds `{feature: check-runs, off: true, lacked: true}`. `kit flow changes` still
shows how many checks each change has.

### merged

| Field | Meaning |
| --- | --- |
| `number` | the change's number |
| `title` | its title, which links to the change's page |
| `author` | who opened it |
| `branch` | the branch it was on |
| `merged` | when it was merged, in seconds since the epoch |
| `by` | who merged it |
| `named` | the references that a closing keyword names in its body, such as `AB#12` in `Fixes AB#12` |

| Forge | How kit reads the 50 merged last |
| --- | --- |
| GitHub | the 50 pull requests updated last, sorted by merge time |
| GitLab | the 50 merged last, sorted by `merged_at` |
| Azure DevOps | the completed pull requests, in the order Azure DevOps returns them |

- A merge updates a pull request, which is why a list read by update finds the newest merges. Such a list can still
  miss a change that was merged before the oldest update in the list. So kit keeps only the changes merged since
  that update.
- GitLab sorts by `merged_at` from version 17.2. kit reads an older GitLab by update, in the way it reads GitHub.
- Where the forge holds more than kit read, the document is `limited`. Its value is the number of rows kit kept.
- No parameter sets the order of Azure DevOps' list. The examples in its reference show the newest first.

## Repositories: kit workspace

`kit workspace` prints what git holds: the members of the workspace, then one stage for each kind of thing git
keeps. It reads only git, from the main checkout of each repository, and asks no remote. So what a row says about a
remote is what the last fetch left. [workspaces.md](workspaces.md#look-at-git-across-a-group) shows how to use it
across a group.

The desk is a repository's root checkout, where you cloned it. A linked worktree prints what its desk prints.

| Stage | A row for each | Order | Cap |
| --- | --- | --- | --- |
| `repos` | member of the workspace, cloned or not | the workspace's order | none |
| `remotes` | remote | the primary remote first | none |
| `branches` | branch on a remote, and local branch with no branch on a remote | those on a remote first | none |
| `worktrees` | worktree | the desk first | none |
| `commits` | commit that a local branch holds and the default branch does not | the newest first | 200 |
| `tags` | tag | the newest first | 100 |

- Every stage has a mark: a hash of what git holds for that stage.
- The key of a row is the remote's name, the worktree's path, the commit's full hash, or the tag's name. For a branch
  on a remote, and for a local branch whose upstream is gone, it is `<remote>/<branch>`. For a local branch with no
  upstream, it is the branch's name. A row of `repos` has no key.
- An age is in seconds.
- `kit workspace --stages` prints the stages in the order of this table. The tabs of the Repositories app are in
  another order, and its last tab, incoming, is a stage of `kit flow`.
- HEAD is not a stage. A remote's HEAD is its default branch: `default` names it on the remote's row, and marks it
  on the branch's row. A worktree's HEAD is its branch, or its commit when it is detached.
- A member answers with the release its own `kit.yml` pins. When its document states another contract, kit does not
  merge it; see [The contract of the stage documents](#the-contract-of-the-stage-documents). For `repos`, the line
  is the `error` of the member's row.

### repos

A row of `repos` is different from every other row. It has no `key`, no `links`, and no `member`, and its
`repository` is the member's host and path. With no `--workspace=`, the stage has one row, for the repository you are
in.

| Field | Meaning |
| --- | --- |
| `repository` | the member: its host and path |
| `host`, `path` | the two parts of `repository` |
| `forge` | the member's forge |
| `remotes` | its remotes: `[{name, url, forge}]` |
| `checkout` | the folder of its clone, which is its desk |
| `checkouts` | the folder of every clone of the member |
| `by` | `fixed` for a member of a group, `given` for a repository you named, `here` for the one you are in |
| `branch` | the branch of its desk |
| `ahead`, `behind` | how far the desk is ahead of and behind the primary remote's default branch |
| `worktrees` | its linked worktrees: `[{branch, path}]` |
| `branches` | its local branches that no checkout has |
| `error` | kit's line when it could not read the member's desk |

`checkout`, `branch`, `ahead`, `behind`, `worktrees`, and `branches` are `null` for a member that is not cloned.

### remotes

| Field | Meaning |
| --- | --- |
| `remote` | the remote's name |
| `forge` | its forge |
| `organization`, `repository` | the path its URL names after the host: all but the last segment, and the last segment |
| `host` | the host its URL names |
| `url` | its URL |
| `push` | its push URL, or `null` when that is the same URL |
| `default` | its default branch, which links to that row of `branches` |
| `branches` | how many branches it has |
| `primary` | `primary` for the primary remote, otherwise `null` |

### branches

| Field | Meaning |
| --- | --- |
| `kind` | `remote`, `gone`, or `local` |
| `branch` | the branch's name, which links to its page on the forge |
| `remote` | the remote that has it |
| `local` | the local branches that pull from it |
| `upstream` | `[ahead, behind]` of the first of those local branches, or `null` |
| `default` | `default` for the remote's default branch, otherwise `null` |
| `commit` | its newest commit, which links to the commit's page |
| `age` | the age of that commit |
| `subject` | the subject of that commit |
| `worktree` | the paths of the worktrees that have it checked out; it links to the first one's row of `worktrees` |

A `gone` row is a local branch whose upstream is gone. A `local` row is a local branch that has no upstream on a
remote.

### worktrees

| Field | Meaning |
| --- | --- |
| `kind` | `desk` or `linked` |
| `path` | the worktree's folder |
| `branch` | its branch |
| `detached` | set when its HEAD is detached |
| `head` | the commit it is on |
| `upstream` | the upstream of its branch |
| `track` | `[ahead, behind]` of the upstream, or `null` |
| `base` | `[ahead, behind]` of the primary remote's default branch, or `null` |
| `changes` | how many paths are changed |
| `untracked` | how many paths are untracked |
| `locked`, `prunable` | set when git says the worktree is locked, or can be pruned |

### commits

| Field | Meaning |
| --- | --- |
| `commit` | the commit's short hash |
| `subject` | its subject |
| `author` | its author |
| `age` | its age |
| `issue` | the `#<number>` its subject starts with, or `null` |
| `branches` | the local branches that hold it |
| `pushed` | `pushed` when a remote has it, otherwise `local` |
| `worktrees` | the paths of the worktrees whose HEAD it is |

### tags

| Field | Meaning |
| --- | --- |
| `tag` | the tag's name |
| `kind` | `annotated` or `lightweight` |
| `commit` | the commit it names |
| `tagger` | who made it; `null` for a lightweight tag |
| `age` | its age |
| `subject` | its subject |

## Delivery: kit delivery

`kit delivery` prints what the forge holds of the repository's delivery. Two tabs of the Delivery app, releases and
builds, are stages of `kit flow`.

| Stage | A row for each | Cap | Key | Mark |
| --- | --- | --- | --- | --- |
| `artifacts` | artifact that a run kept | the newest 100 | `id` | the forge's runs |
| `environments` | deployment environment | see below | `name` | the forge's environments and runs |
| `deployments` | deployment | the newest 50 | `id` | the forge's deployments and runs |

### artifacts

| Field | Meaning |
| --- | --- |
| `id` | the artifact's id; `<run>/<id>` on Azure DevOps |
| `name` | its name, which links to the artifact's page |
| `digest` | the forge's digest, `sha256:…`, or `null` |
| `size` | its size in bytes |
| `run` | the run that kept it |
| `age` | seconds since it was made |
| `expires` | when it expires, in seconds since the epoch, or `null` |

| Forge | Artifacts kit reads | Requests | Notes |
| --- | --- | --- | --- |
| GitHub | the 100 newest, less the expired | one | an expired artifact no longer downloads |
| GitLab | the archives of the 100 newest successful jobs | one | `digest` is `null` |
| Azure DevOps | those of the 20 newest runs, 100 at most | one for each run | `digest` and `expires` are `null` |

- GitLab names an artifact for its job and its file, such as `package: artifacts.zip`.
- Azure DevOps numbers an artifact within its run, which is why the id there is `<run>/<id>`.
- Where the forge holds more, the document is `limited`, at the number of rows printed.

### environments

| Field | Meaning |
| --- | --- |
| `name` | the environment's name, which links to its page |
| `protection` | the kinds of rule that guard it, sorted |
| `approvers` | who may approve a deployment: logins, or the forge's name for a team or a role |
| `branches` | the refs that may deploy there, or `null` when any ref may |

- A kind in `protection` is `reviewers`, `wait`, `branches`, `deployers`, or the forge's own name for another kind.
- In `branches`, a tag is written `refs/tags/…`, and `protected branches` means GitHub's rule of that name.

| Forge | What kit reads | Cap |
| --- | --- | --- |
| GitHub | the environments, then the branch policies of each one that has its own, one request each | 20 environments |
| GitLab | the environments, with the protected environments on Premium and Ultimate | none |
| Azure DevOps | the environments, and their checks in one request | 100 environments |

- On GitHub, the list stops before a 21st environment, and the document is `limited`.
- On GitLab, a tier or a caller that cannot read protected environments leaves `protection` and `approvers` `null`.
  GitLab restricts no branch, so `branches` is always `null`.
- On Azure DevOps, `approvers` are those of an Approval check, and `branches` are those of a branch control check.

### deployments

| Field | Meaning |
| --- | --- |
| `id` | the deployment's id |
| `environment` | its environment, which links to that row of `environments`: `row:environments/<name>` |
| `ref` | the ref that was deployed |
| `sha` | the commit, which links to the commit's page |
| `state` | `success`, `failure`, `running`, `waiting`, `cancelled`, or `inactive`; it links to the log or the page |
| `actor` | who made the deployment |
| `age` | seconds since it was made |

| Forge | Deployments kit reads | Requests |
| --- | --- | --- |
| GitHub | the 50 newest, each with its latest status | one GraphQL request |
| GitLab | the 51 newest | one |
| Azure DevOps | the newest 51 records of each of the 20 environments changed last | one for each environment |

- Azure DevOps keeps deployments as the deployment records of each environment. kit takes each record's ref, commit,
  and actor from its run, among the project's 100 newest runs. They are `null` for a run older than those.
- Past 50 deployments, or past 20 environments on Azure DevOps, the document is `limited`.

### The marks of Delivery

Every stage's mark holds the forge's mark of its runs, because a run makes artifacts and deployments.

| Stage | Its mark also holds | Why |
| --- | --- | --- |
| `environments` | the forge's mark of its environments | a person can edit an environment |
| `deployments` | the forge's mark of its deployments | another tool can deploy, and a status can change |

| Forge | Mark of the environments | Mark of the deployments |
| --- | --- | --- |
| GitHub | the ETag of the first 100 | the ETag of the newest 50 |
| GitLab | their ids, states, and update times | the deployment updated last |
| Azure DevOps | none | none |

Azure DevOps has no marks, so every mark is `null` there. On GitLab, a change to a protected environment changes no
mark.

## People: kit people

`kit people` prints who has access to the repository, and which bots acted in it. Every tab of the People app is a
stage of this verb.

| Stage | A row for each | Cap | Key | Mark |
| --- | --- | --- | --- | --- |
| `people` | person or bot with access | none | `login` | none |
| `teams` | team with access | 20 teams, 100 members each | `team` | none |
| `agents` | bot that acted | see below | `login` | none |

No stage has a mark. kit reads the forge's marks for every app at once, and a mark of who has access would cost each
app one more request. The forge would also refuse that request to a caller who may not push. So kittui loads these
tabs again only on Refresh.

### people

| Field | Meaning |
| --- | --- |
| `login` | the login |
| `name` | the name, or `null` where the forge shows none |
| `role` | the forge's own name for the role |
| `kind` | `user`, `bot`, or, on Azure DevOps, `group` for a group that a team holds |

| Forge | Values of `role` | Which role, when several apply |
| --- | --- | --- |
| GitHub | `admin`, `maintain`, `write`, `triage`, `read`, or a custom role | the highest that any source gives |
| GitLab | `owner`, `maintainer`, `developer`, `reporter`, `planner`, or `guest` | the highest of the member's memberships |
| Azure DevOps | `admin` or `member` | `admin` for an administrator of one of the project's teams |

- On GitHub, kit reads every page of the collaborators. The list mostly shows no name. GitHub shows the
  collaborators only to a caller who may push, and kit tells any other caller to ask an admin for write access.
- On GitLab, kit reads the members through GraphQL, 100 to a page, because GraphQL says which member is a bot. A
  member's memberships are its own, those of its groups, and those of the groups that the project is shared with or
  invited to.
- Azure DevOps lists users only for the whole organization. So the rows are the members of the project's teams, as
  `teams` reads them, and the document is `limited` where that read is.

### teams

| Field | Meaning |
| --- | --- |
| `team` | the team, which links to its page |
| `name` | the team's name |
| `role` | the access the team has, or `null` |
| `members` | the logins of its first 100 members, or `null` for a team the caller cannot see |

| Forge | A team is | `team` holds | `role` | Requests |
| --- | --- | --- | --- | --- |
| GitHub | a team with access | its slug | a role, named as in `people` | one, then one GraphQL request for all members |
| GitLab | a group the project is shared with | the group's path | the role of the share | the same |
| Azure DevOps | a team of the project | its name | `null` | one, then one for each team's members |

- On GitHub, reading the members needs the `read:org` scope. Without it, kit's line names
  `gh auth refresh --scopes read:org`. A repository that a user owns has no teams.
- Azure DevOps' teams hold no access of their own, which is why `role` is `null` there.
- Past 20 teams, or past 100 members of one team, the document is `limited`, at the number of teams printed.

### agents

| Field | Meaning |
| --- | --- |
| `login` | the bot's login, which links to its page where the forge gives one |
| `acted` | what it did: a list of `commit`, `change`, and `review`, or `null` |
| `last` | when it last acted, in seconds since the epoch |

The bot that acted last comes first.

| Forge | Bots kit reads |
| --- | --- |
| GitHub | the bots among the authors of the newest commits, changes, and reviews, in one GraphQL request |
| GitLab | the bot users among the project's members |
| Azure DevOps | none |

On GitHub:

- kit reads the authors of the 100 newest commits on the default branch, of the 100 open changes, and of the 50
  merged changes updated last, with the latest reviews of each change.
- A bot is a `Bot` account, or a login that ends in `[bot]`, such as `dependabot[bot]`. A commit also counts as a
  bot's when its author names itself a bot. An agent's commit under a person's account is one example.
- A bot that acted only before those commits and changes is not listed.
- Past 100 open changes, or past 20 reviewers of one change, the document is `limited`, at the number of bots
  printed.
- A bot seen only in commits has no link, because a commit's author carries no page.

On GitLab, the rows are the bot users among the project's members. GitLab creates one bot user for each access
token of a project or a group. `acted` is `null`, because GitLab does not report what a bot did. `last` is the day of
the bot's last activity.

Azure DevOps names no bots, so the stage has no rows there.

## Trust: kit audit

`kit audit` prints what the repository can be trusted for:

- what the forge attests and finds
- what guards the default branch, and who may get past it
- the rules that kit's policy judges by
- what holds an agent to those rules

Every tab of the Trust app is a stage of this verb. The verb is not `kit trust`, which trusts a clone.

| Stage | A row for each | Key | Mark |
| --- | --- | --- | --- |
| `evidence` | attestation of a release's asset or of an artifact | the digest and the kind | the forge's runs and releases |
| `findings` | alert, open or dismissed | the tool and the number | the forge's runs and alerts |
| `controls` | ruleset or protection that guards the default branch | `id` | none |
| `waivers` | bypass of a control, and dismissed alert | what it waives and the actor | none |
| `policy` | rule that `kit policy` judges by, in each place it applies | the rule and the place | a hash of files |
| `enforcement` | mechanism that holds an agent to the rules | the harness and the mechanism | a hash of files |

### evidence

An attestation is a signed statement about how a file was built.

| Field | Meaning |
| --- | --- |
| `subject` | the name of the asset or the artifact; it links to the repository's attestations |
| `digest` | the file's digest, `sha256:…` |
| `kind` | the predicate type of the in-toto statement, such as `https://slsa.dev/provenance/v1`, or `null` |
| `signer` | the workflow that signed it, `<owner>/<repo>/<path>@<ref>`; `github`; or `null` |
| `age` | seconds since it was made |

| Forge | What kit reads | Cap |
| --- | --- | --- |
| GitHub | the attestations of each digest, one request each | 5 releases, 20 artifacts, 50 digests |
| GitLab | nothing | |
| Azure DevOps | nothing | |

- On GitHub, kit takes the digests of the assets of the 5 newest releases and of the 20 newest artifacts. It asks
  for the attestations of each digest once. Past any of the three caps, the document is `limited`.
- `signer` is `github` for an attestation that GitHub made itself, such as the one for an immutable release.
- GitHub can keep an attestation's bundle apart, compressed. kit does not read such a bundle, so its `kind` is
  `null`.
- GitLab and Azure DevOps keep no attestations that kit reads.

### findings

| Field | Meaning |
| --- | --- |
| `tool` | the scanner: `code-scanning`, `dependabot`, or `secret-scanning` |
| `number` | the alert's number |
| `rule` | what found it: a rule's id, an advisory's GHSA id, or a secret's type; it links to the alert's page |
| `severity` | the severity in lower case; `null` for a secret |
| `state` | `open` or `dismissed` |
| `path` | where it was found |
| `age` | seconds since it was made |

GHSA is GitHub Security Advisory. A secret that was resolved as a false positive, as "won't fix", or as used in
tests is `dismissed`.

kit reads each of the three scanners on its own, and merges the rows.

| A scanner that | Is under `errors` as | Exit |
| --- | --- | --- |
| the forge has off for this repository | `{feature, off: true}` | 0 |
| refuses the caller | `{feature, error}` | 1 |

In both cases the other scanners still print. For a scanner that is off, the tab says that it is off here.

| Forge | What kit reads |
| --- | --- |
| GitHub | every page of each scanner's alerts |
| GitLab | the vulnerability report |
| Azure DevOps | nothing |

- On GitHub, a refusal names `gh auth refresh --scopes security_events` when the login lacks the scope. Otherwise
  it says that an admin of the repository can grant the access.
- On GitLab, kit reads static application security testing (SAST) as code scanning, dependency scanning as
  Dependabot, and secret detection as secret scanning. On a tier without the report, each scanner is off.
- GitLab leaves out a vulnerability that the caller may not see, and refuses nothing. So the tab is empty for such a
  caller.

### controls

A control is a ruleset or a branch protection that guards the default branch.

| Field | Meaning |
| --- | --- |
| `id` | the control's id |
| `control` | its name, which links to its page |
| `target` | the refs it names |
| `enforcement` | `active`, `evaluate`, or `disabled` |
| `rules` | its kinds of rule, sorted, or `null` where only an admin may see them |
| `kind` | `ruleset` or `protection` |

| Forge | Controls kit reads |
| --- | --- |
| GitHub | the rulesets whose patterns name the default branch, then the branch's own protection |
| GitLab | the protected branches that name the default branch, and the push rules |
| Azure DevOps | the policies of the default branch |

- GitHub's rulesets are the repository's and its organization's. kit reads them in one GraphQL request.
- `rules` is `null` for GitHub's branch protection when the caller is not an admin.
- On Azure DevOps, an optional policy has the enforcement `evaluate`.

### waivers

A waiver is a way past a control or an alert: a bypass of a control, or the dismissal of an alert.

| Field | Meaning |
| --- | --- |
| `waives` | a control's id, or an alert as `<tool> <number>` |
| `actor` | who may bypass; `null` for a dismissal |
| `kind` | `bypass` or `dismissal` |
| `reason` | for a bypass, its mode; for a dismissal, its reason and its comment |
| `by` | who dismissed the alert, or who granted the bypass; `null` where the forge does not say |
| `until` | when the waiver ends, or `null` for never |
| `hidden` | on a row for hidden actors, how many they are; otherwise `null` |

- `waives` links to the row it names: a row of `controls` for a bypass, a row of `findings` for a dismissal.
  `reason` links to the waiver's page.
- A bypass's mode is `always`, `pull_request`, or `exempt`.
- GitHub hides bypass actors from a caller who may not edit the ruleset. kit also cannot name a team for a login
  without the `read:org` scope. All such actors of one control are one row. Its key is `<id> hidden`, its `actor` is
  `null`, and `hidden` is their number.

| Forge | Bypasses | Dismissals |
| --- | --- | --- |
| GitHub | the bypass actors of its rulesets, and the pull request allowances of its protection | the dismissed alerts |
| GitLab | none | the dismissed vulnerabilities |
| Azure DevOps | none | none |

The dismissals are the dismissed alerts that `findings` reads. kit reads each scanner once in a process, for both
stages. A scanner that is off, or that refuses the caller, is under `errors` in the same way as in `findings`, and
the rest still print.

### policy

The stage runs `kit policy --rules --json` in each checkout of the clone that is on a branch: the checkout you are
in, and each worktree. For the checkout you are in, the branch is the one `kit policy` judges.

The policy that applies depends on the branch. On the default branch, it is the checkout's own policy. On any other
branch, it is the policy of the branch's base.

| Field | Meaning |
| --- | --- |
| `source` | the forge of the primary remote: `github`, `gitlab`, or `ado` |
| `organization` | the path before the repository; on GitLab, the group and its subgroups |
| `repository` | the repository's name |
| `branch` | the branch |
| `scope` | the level at which the row applies; see below |
| `rule` | the rule's name |
| `pattern` | the pattern that a name must match |
| `from` | where the pattern is set, such as `default` or `kit.yml` |
| `engine` | the policy engine that judges the rule, such as `opa` |

The first four fields say where the rule applies. They have two special values:

- `""` means the clone has no such place. `organization` is `""` for a clone with no remote, and `source` is `""`
  for a remote on no forge. For a clone with no remote on a forge, `repository` is the name of the main checkout's
  folder.
- `null` means that a merged row covers every value of the field.

kit merges the rows of one rule that have the same `pattern`, `from`, and `engine`. It merges at the widest level
where every row agrees. `scope` names that level: `branch`, `repository`, `organization`, `source`, or `workspace`
where even the sources differ. The fields narrower than the scope are `null`.

- A rule that is the same on every branch of a repository is one row, with the scope `repository` and the branch
  `null`.
- Over a workspace, a rule that is the same in every member is one row, wider than any member.

kit reads another checkout as it is, and places no files in it. A checkout that fails is `{branch, error}` under
`errors`, and the rest still print.

The mark is a hash of each checkout's `kit.yml` and `.kit/policy/`. On a branch other than the default, it also
covers the base's files, which a fetch can change.

### enforcement

A harness is the program that runs an agent, such as Claude Code. The stage has a row for each mechanism that holds
an agent to the rules.

| Field | Meaning |
| --- | --- |
| `harness` | `generic`, `claude`, `copilot`, `cursor`, `gemini`, or `repository` |
| `tier` | `advisory`, `best-effort`, `local floor`, or `authoritative` |
| `mechanism` | what does the holding, such as the pre-commit hook |
| `status` | `active`, `missing`, or `unknown` |
| `evidence` | `probed`, `documented`, or `unverified` |
| `detail` | one sentence that says why the status is what it is |
| `passes` | what gets past the mechanism, or `null` where kit cannot tell |

There is a harness for each active agent package. `generic` is any agent that reads `AGENTS.md`. `repository` is for
what holds every agent.

| `tier` | What is in it |
| --- | --- |
| `advisory` | the instructions that an agent reads |
| `best-effort` | a harness's deny list or hook, which fails open |
| `local floor` | the pre-commit hook in this clone |
| `authoritative` | kit's CI job, and a control on the default branch that requires its check and a review |

[architecture.md](architecture.md#enforcement-tiers) describes the tiers.

| `evidence` | Meaning |
| --- | --- |
| `probed` | kit read what decides the status: a file, git's hooks, or the forge's answer |
| `documented` | the status rests on what the harness or the forge documents |
| `unverified` | neither |

`status` is never a guess. This is how kit decides it for three kinds of mechanism:

| Mechanism | `active` | `missing` | `unknown` |
| --- | --- | --- | --- |
| a deny list or a hook in a harness's settings | never | an entry the package merges is absent | otherwise |
| the pre-commit hook | git runs lefthook in this clone, and lefthook is on `PATH` | | otherwise |
| the required check and the required review | an active control requires it | no active control requires it | kit cannot see |

- A deny list or a hook is `unknown` at best, because kit cannot probe that the harness runs it.
- The required check is `CI`, which kit's CI job reports. The row links to the control's row in `controls`.
- For a required row, `passes` lists who may bypass every control that requires it. That includes the admins of a
  protection that does not bind its admins.
- A control that only evaluates binds nothing, so it does not make a row `active`.
- A required row is `unknown` when the forge does not show a control's checks or reviews. That is so for a GitHub
  rule whose parameters GitHub hides, and for a protection that only an admin may read. It is also so on GitLab,
  whose merge checks are settings of the project, which kit does not read.
- A forge read that fails also leaves the required rows `unknown`. `errors` then holds `{feature, error}`, and the
  stage exits 1.
- A repository on no forge has both required rows `missing`.

### The marks of Trust

| Stage | Its mark changes with |
| --- | --- |
| `evidence` | the forge's runs and releases |
| `findings` | the forge's runs and alerts |
| `controls`, `waivers` | nothing: neither has a mark, so kittui loads them again only on Refresh |
| `policy` | each checkout's `kit.yml` and `.kit/policy/` |
| `enforcement` | `kit.yml`, each harness's files, git's pre-commit hook, `lefthook.yml`, and kit's CI job |

- A run makes an attestation and a scan, which is why both forge marks hold the runs.
- GitHub's mark of the alerts is the alert updated last for each scanner. A dismissal or a new advisory changes it
  without a run. A scanner that is off or that refuses is `off` or `refused` in the mark, so the other scanners
  still change it.
- GitLab's mark of the alerts is its count of open and dismissed vulnerabilities.
- The required rows of `enforcement` come from the forge, as `controls` does. No file changes them, so the mark
  does not change with them.

## Platform: kit platform

`kit platform` prints what kit runs with in this repository. It asks the forge only whether the forge's tool is
signed in.

| Stage | A row for each | Key | Mark |
| --- | --- | --- | --- |
| `services` | capability that kit fills | the capability | a hash of files; see below |
| `toolchains` | toolchain and role, in each checkout | the checkout, the provider, and the role | a hash of the pin files |
| `tools` | pinned tool, in each checkout | the checkout, where the tool is pinned, and its name | the same |
| `settings` | key of the settings schema | the key | a hash of `kit.yml` |

`toolchains` and `tools` read every checkout of the clone: the one you are in, and each linked worktree.

### services

| Field | Meaning |
| --- | --- |
| `capability` | what kit needs done; see the next table |
| `service` | what answers it, such as `github`, `mise`, or `patterns`; `null` for nothing |
| `provider` | kit's module that reaches the service, such as `forge/github` |
| `chosen` | `set` where `kit.yml` or a recorded choice names the service, otherwise `inferred` |
| `ready` | whether the service's tool is installed and signed in |

| `capability` | Answered by |
| --- | --- |
| `hosting`, `review`, `ci`, `releases` | the forge of the primary remote |
| `tracking <prefix>` | the tracker of each prefix, such as `tracking #` |
| `toolchain` | the project's tool manager |
| `dependencies <provider>` | each dependency provider whose manifest and lock file are here |
| `dependencies` | one row with no service, when no provider's files are here |
| `policy` | the policy engine |

- `service` is `null` for the forge's capabilities when there is no remote, and for `ci` on a forge that has none.
- A forge whose tool is not signed in is not `ready`. The stage still prints.
- A forge or a policy engine that `kit.yml` names wrongly is `{error}` under `errors`. The rest still prints, and
  the stage exits 1.

### toolchains

The rows are those `kit toolchains --json` prints, read in each checkout.

| Field | Meaning |
| --- | --- |
| `provider` | the manager, such as `mise` or `brew` |
| `role` | `project` or `system` |
| `usable` | its tool is installed, and for the project role its file is here |
| `active` | the run is already inside it |
| `chosen` | kit uses it for the role |
| `fills` | it is brew, and it installs the Brewfile's tools that the chosen manager does not pin |
| `worktree` | the name of the checkout's folder |
| `branch` | the checkout's branch, or `null` when it is detached |

A linked worktree in which `kit toolchains` fails is `{worktree, error}` under `errors`. The rest still print, and
the stage exits 1.

### tools

The rows are those `kit tools --json` prints, read in each checkout.

| Field | Meaning |
| --- | --- |
| `name` | the tool's name |
| `pinned` | the version that is pinned |
| `installed` | the version that is installed |
| `from` | where the tool is pinned |
| `path` | only with no tool manager chosen: where the tool is on `PATH` |
| `worktree`, `branch` | as in `toolchains` |

- With no tool manager chosen, which kit calls ambient, a row is `{name, path, from}`.
- `kit tools` can refuse in the checkout you are in. It does when several tool managers are usable and none is
  chosen. The stage then prints kit's line and exits 1. `toolchains` still prints.
- A linked worktree in which `kit tools` fails is `{worktree, error}` under `errors`, as in `toolchains`.

### settings

The stage lists every key of the settings schema, `.kit/kit.schema.json`, in the schema's order.

| Field | Meaning |
| --- | --- |
| `setting` | the key |
| `value` | the value `kit.yml` sets; otherwise the schema's default, or `null` where the schema names none |
| `from` | `set` or `default` |

### The marks of Platform

| Stage | Its mark is a hash of |
| --- | --- |
| `settings` | `kit.yml` |
| `toolchains`, `tools` | the pin files, and the files that keep kit's choice of toolchain |
| `services` | all of those, the clone's git configuration, and `.kit/policy` |

- A pin file is a file that a toolchain or a dependency provider pins versions from.
- kit's choice of toolchain is kept in three files: this checkout's, the clone's, and yours, `~/.kit/settings.yml`.
- The git configuration holds the remotes, so adding a remote changes the mark of `services`.

## Packages: kit packages

`kit packages` has commands of its own beside the ones every app verb shares; see [packages.md](packages.md).

| Command | What it does |
| --- | --- |
| `kit packages` | at a terminal, opens Packages in kittui; off a terminal, lists the packages as text |
| `kit packages <filter>`, `kit packages --text` | lists the packages as text, at a terminal too |
| `kit packages --json` | prints one object for each package of the repository you are in |
| `kit packages select`, `add`, `remove` | change which packages are active |
| `kit packages packages` | the stage, as for every app verb |
| `kit packages --stages`, `--marks` | as for every app verb |

| Stage | A row for each | Key | Mark |
| --- | --- | --- | --- |
| `packages` | package in reach | `name` | a hash of `kit.yml` and `.kit/packages/` |

| Field | Meaning |
| --- | --- |
| `name` | the package's name |
| `state` | `active`, `inactive`, or `excluded` |
| `origin` | `release`, `repository`, or the name of a source |
| `depends` | the packages it depends on |
| `includes` | the packages it includes |
| `dependents` | the active packages that depend on it |
| `bundles` | the active bundles that include it |
| `description` | its description |

`kit packages remove` refuses a package that has `dependents`. Where kit was never installed, the stage fails with
the line that `kit packages` prints.

### The actions of the Packages app

The tab menu of Packages has three actions. Each acts on the selected packages, or on the package under the cursor
when none is selected. Each asks first, in a dialog that lists what it will change.

| Action | The dialog lists | Then kittui runs |
| --- | --- | --- |
| Add | the packages that are not active | `kit packages add` |
| Remove… | the packages that are active | `kit packages remove`, which takes their files out |
| Make Only These Active… | what it keeps, adds, and takes out | `kit packages select` |

Over a workspace, each action runs in the checkout of the package's member.

## In kittui

Every app is the same screen over its own tabs. Each tab loads one stage with `--json`. kittui's catalog,
`projects/tui/internal/flow/fields.json`, names the command, the fields, and the presets of each tab. The tutorials
teach the rows, the menus, and the keys: run `kit tutorials rows`.

## Where the code is

| What | Where |
| --- | --- |
| the runner of the seven verbs that are not `kit flow` or `kit workspace` | `modules/bash/apps.sh` |
| a verb's stages and marks | `modules/bash/apps/<verb>.sh` |
| the rows of each stage, made from what a forge call prints | `modules/jq/apps.jq` |
| the stages of `kit workspace` | `modules/bash/workspace.sh` |
| the seam to the forge | `modules/bash/forge.sh` |
| kittui's catalog of stages | `projects/tui/internal/flow/fields.json` |

## The fields of kit flow, kit workspace, kit workspaces, and kit welcome

The help pages of these verbs name this section for the JSON they print. One field a line.

### Where a row is from, and the contract

Every row of `kit flow`'s `issues`, `changes`, `builds`, `releases`, and `incoming`, and of every `kit workspace`
stage, says where it is from:

- `organization`: the owner of the repository kit read it in, as its primary remote's URL names it past the host. It is
  `null` for a primary on this machine.
- `repository`: that repository's name.
- `source`: the forge, `github`, `gitlab`, or `ado`; `git` for `incoming`'s rows; `kit` for a member that `kit workspace
  repos` lists and is not cloned.

An issue keeps the `organization`, `repository`, and `source` of the tracker that holds it, and a change those of the
repository its forge names it by. On GitHub, the organization is the owner and the repository the name. On GitLab, the
organization is the group, with its subgroups, and the repository is the project. On Azure DevOps, they are the project
and the repository, and a tracker's work item has none. Each is `null` where the tracker has none.

Over a workspace, `kit flow` prints `{contract, rows, errors}` for a stage, and `{contract, stages, <stage>…}` for the
picture. Each row, or each `incoming` object, gains `member`, its host and path. A member that cannot be read is
`{member, error}` under `errors`, and every other member still draws. A member whose `incoming`, or whose picture,
states another contract than this kit reads is `{member, error}` too, the line saying both numbers. A member's array
states no contract and is read. As text, the picture draws each cloned member's picture under its name. `--marks` and
`--quota` span the members: a member that cannot be read is `{member, error}` under `errors` beside the others' marks,
and its rate limits are left out. kit flow exits 1 after the rest. A member with no checkout draws nothing: `kit
workspace repos` lists every member, cloned or not. A pull request's number names one repository's, and is refused.

Above desks, `kit flow --json` prints an array with one `{path, status}` per desk.

### kit flow: issues

`kit flow issues --json` prints an array, oldest issue first. Each row is:

- `number`, `ref`: the issue's number, and its reference, `#7` or `AB#4521`, its tracker's prefix first
- `tracker`: that prefix
- `title`, `assignees`, `labels`, `age`
- `source`, `organization`, `repository`: where the issue is, as above
- `milestone`, `iteration`, `swimlane`: each a name, or `null`. The forge's own, or what a stand-in in `kit.yml` chooses,
  as `modules/bash/forge.sh` says.
- `status`: `underway` or `backlog`
- `branch`: the pull request's branch, or the branch named for an issue that no pull request closes, a checked-out one
  first, then the desk's, then the primary's. `null` in the backlog.
- `pr`: `null` for an issue no pull request closes, else the pull request, `{number, source, title, author, state,
  branch, fork, pushed, url}`
- `here`: true when a checkout on this desk has the branch. `null` in the backlog.
- `local`: true when the desk has the branch and no checkout has it. `null` in the backlog.
- `worktree`: the path of the checkout that has the branch, or `null`. `null` in the backlog.
- `url`: the issue's page, as the forge's provider or the tracker gives it, another repository's for an issue there, or
  `null` where neither gives one

A pull request's fields:

- `source`: the forge the change is on, `github`, `gitlab`, or `ado`
- `fork`: the owner of the repository the branch lives in when that is not the base repository, a login on GitHub and a
  namespace's path on GitLab, or `null`
- `pushed`: `{age, by}` of the branch's last push, or `null` when the forge does not say it cheaply. `age` is in
  seconds, `by` a login or `null`. GitHub's is the head commit's, and GitLab's the head pipeline's.
- `url`: the change's page, as the forge's provider gives it, or `null`

No page is built from a remote's URL by what reads the JSON: the provider gives each.

An issue's status:

- It lists every open issue of every tracker, the oldest first: the forge's own, and those of each tracker `kit.yml`
  declares under `trackers`, as its provider lists them. A web tracker lists none. A tracker that cannot be read fails
  the stage.
- An issue is `underway`, with a row for each pull request that closes it. It is `underway` too, with no pull request,
  when no open pull request closes it and a branch is named for it: its key and a dash, such as `9-other` or
  `ab4521-fix`, on the desk or the primary as of the last fetch. Otherwise it is `backlog`.
- The forge closes no issue of another tracker on a merge, so kit stands in. A pull request closes an issue when its
  branch starts with the issue's key and a dash, or a closing keyword in its body names it, `Closes AB#4521`. An issue
  that one of the 50 pull requests merged last names is closed and left out, whether or not its tracker closed it.
- The owner flags match the issue's assignees.
- A pull request closes an issue where that issue is. An issue of another repository that a pull request here closes is
  a row of its own, which its `organization` and `repository` tell from the issue of that number here, and that issue
  keeps its own status. `kit flow changes <number>` lists the changes that close the issue of that number here.

### kit flow: changes

`kit flow changes --json` prints an array of pull requests. Each carries the `source`, `fork`, `pushed`, and `url` above,
and `named`, the references a closing keyword names in its body. Each issue a change closes says its own `url`, `source`,
`organization`, and `repository`.

### kit flow: incoming

`kit flow incoming --json` prints `{contract, fetched, primary, remotes, rows}`.

- Each remote is `{name, forge, host, default, commits, branches, tags}`. `forge` and `host` are `null` when it has none.
  `branches` is `{new, updated, gone}`.
- A remote whose fetch failed adds `error`, git's line, and the stage exits 1.
- With `--no-fetch`, `fetched` is false and each remote is `{name, forge, host}`. Each remote's row says `not fetched`,
  and the tracking rows stand as the last fetch left them.
- `rows` is everything incoming, flat, one row a thing, every remote's, the primary's first. Each row is `{key, remote,
  primary, forge, host, url, default, kind, change, ref, sha, old, commits, author, age, subject, local, worktrees,
  ahead, behind, issues}`, `null` or an empty list where a row has no value. A row may carry keys this list does not
  name; kittui shows them under more.
- `kind` is one of:
  - `remote`: a remote. Its `change` is `fetched`, `unchanged`, `not fetched`, or `failed`, and its `subject` is git's
    line when it failed.
  - `commit`: a commit new on the default branch.
  - `branch`: a branch that is `new`, `updated`, `forced`, or `gone`. `commits` is how far it moved or, for a new one,
    how many commits are not on the default branch.
  - `tag`: a tag that is `new` or `moved`.
  - `tracking`: a local branch whose upstream is ahead of it. `change` is `behind`, with `ahead` and `behind`.
- `issues` are the issues a branch's name starts with and a subject names, as `#12`.
- `local` is the local branches on a branch, and `worktrees` the linked worktrees they are checked out in.

### kit flow: builds

`kit flow builds --json` prints an array of the 20 newest runs that no pull request owns: pushes to the default branch or
a tag, and scheduled or manual runs.

- `id`, `number`, `attempt`, `workflow`, `branch`, `tag`, `event`, `sha`, `title`, `state`, `age`, `took`, `url`, `jobs`
- `number` is the forge's count of the workflow's runs, or `null`. `attempt` is 1 for a first run.
- `tag` is true for a run on a tag.
- `sha` is the commit's short hash, and `title` the forge's headline for the run. Each is empty when the forge gives none.
- `state` is `running`, `passed`, `failed`, or `cancelled`.
- `took` is `null` while the run runs.
- `jobs` is empty when the forge does not report them cheaply. Each is `{name, state, took, step}`, `step` the failed
  step's name, or `null`.

### kit flow: releases

`kit flow releases --json` prints an array of the forge's releases, newest first, one flat row a release.

- `key`: its tag. `version`: the tag without `release/`. `tag`, `name`.
- `kind`: `release`, `pre-release`, or `draft`
- `latest`: `"latest"` for the forge's latest release, else `null`
- `at`: when it was published, or made, for a draft. `age`.
- `url`: its page. `notes`: its text, empty for none.
- `assets`: the name of each file it offers. `downloads`: where each downloads, in the same order.
- `links`: where a value leads, by its field. `kind` and `url` lead to the page, and `assets` and `downloads`, each a
  list, each lead to its download.

### kit flow: the other forms

- `--stages` prints the stages the picture draws, one per line, in order.
- `--me` prints the caller's login on the primary's forge. `--mine` and `--others` match it. It takes no workspace.
- `--quota` prints the caller's rate limits on the primary's forge as one JSON array. Each forge's entry is `{forge,
  limits}`, and each limit `{name, limit, remaining, reset}`. Reading them costs a request at most. A forge without rate
  limits gives none, and asks nothing.
- `--capabilities` prints what the primary's forge can do as one JSON object: `{contract, forge, provider, features,
  stand_ins}`. `provider` is the version the provider implements, each feature is `native`, `none`, or `stand-in`, and
  `stand_ins` is the repository's choices. A primary with no forge has every feature `none`. It asks nothing, and takes
  no workspace.
- `--marks` prints a mark per stage as one JSON object. A mark changes when what the stage draws does: read again, a mark
  that differs says the stage is stale. On GitHub, nothing changed costs no request. When the forge cannot answer, its
  stages' marks are `null` beside every local stage's, and kit flow exits 1.

### kit workspace: the stages

`kit workspace --json` prints `{contract, stages, <stage>…}`. Each stage is `{contract, rows, errors}`, a row is
`{key, …, links}`, and an age is in seconds. `commits` lists at most 200, and `tags` the newest 100. A remote's row
says the organization and the repository it is, and `repos`' repository is the member, host and path. The row's `links`
give where a value leads, by its field: a page on the forge, or `row:<stage>/<key>`, a row of another stage.

- `repos`: `{repository, host, path, forge, remotes, checkout, checkouts, by, branch, ahead, behind, worktrees, branches,
  error}`. Its rows have no `key` or `links`.
  - `remotes` is `[{name, url, forge}]`.
  - `by` is `fixed` for a group's member, `given` for a repository named, and `here` for the one kit runs in.
  - `checkout` is the clone, also from one of its linked worktrees.
  - `branch`, `ahead`, and `behind` are its desk's.
  - `worktrees` is `[{branch, path}]`.
  - `branches` is the local branches no checkout has.
  - Each is `null` for a member not cloned.
  - `error` is the desk's line where it could not be read, as for a clone whose `kit.yml` does not parse.
- `remotes`: `{remote, forge, organization, repository, host, url, push, default, branches, primary}`
  - `organization` and `repository` are the path the URL names past its host, up to its last segment and that segment.
  - `push` is `null` where it is the URL.
  - `primary` is `"primary"` or `null`.
- `branches`: `{kind, branch, remote, local, upstream, default, commit, age, subject, worktree}`
  - `kind` is `remote`, `gone`, or `local`.
  - `local` is the local branches.
  - `upstream` is `[ahead, behind]` of the first, or `null`.
  - `default` is `"default"` for the remote's default branch, else `null`.
  - `worktree` is the paths.
- `worktrees`: `{kind, path, branch, detached, head, upstream, track, base, changes, untracked, locked, prunable}`
  - `kind` is `desk` or `linked`.
  - `track` and `base` are `[ahead, behind]` of the upstream and of the primary's default branch, or `null`.
- `commits`: `{commit, subject, author, age, issue, branches, pushed, worktrees}`
  - `issue` is the `#<number>` the subject starts with, or `null`.
  - `pushed` is `pushed` or `local`.
  - `worktrees` is the paths whose HEAD it is.
- `tags`: `{tag, kind, commit, tagger, age, subject}`
  - `kind` is `annotated` or `lightweight`.
  - `tagger` is `null` for a lightweight tag.

HEAD is no stage of its own. A remote's HEAD is its default branch, `⚓` on its row and on the branch's. A worktree's is
its branch, or its commit where it is detached, and a commit's row names the worktrees whose HEAD it is.

`kit workspace` reads the repository from its main checkout, so a linked worktree draws what the desk draws, and `repos`
lists it alone. It asks no remote: what a remote has is what the last fetch left. A document that states no contract is
read. A member answers with the release its own `kit.yml` pins; one whose document states another contract is not
merged, and is `{member, error}` too, its line saying both numbers and which side to update. For `repos`, the line is
its row's `error`. `--marks` over a workspace names a member that could not be read under `errors` beside the marks.

### kit workspaces: the JSON

- The list, `kit workspaces --json`, is `{file, roots, favorites, workspaces}`. Each group is `{name, members, repos,
  favorite}`, `members` a count and `repos` the members.
- `--show=<workspace>` is `{name, kind, members}`. `kind` is `group` or `repository`. Each member is `{repository, host,
  path, forge, remotes, checkout, checkouts, by}`. `remotes` is `[{name, url, forge}]`, the primary first. `checkout` is
  a path or `null`. `by` is `fixed` for a group's member, `given` for a repository named.
- `--current` is `{kind, name, member, checkout, why, members, groups, workspaces, favorites, recent}`.
  - `kind` is `repository`, `group`, or `none`.
  - `why` is `given`, `repository`, `last`, or `none`.
  - `members` is a group's, as `--show` gives each.
  - `groups`, for a repository, is each group that holds it, `{name, members}`, `members` a count.
  - `workspaces` is every group in the file, as the list gives each.
  - `favorites` is `{name, kind, members, checkout}`.
  - `recent` is the repositories `--use` kept by their folder whose working trees are still there, the newest first,
    `{name, member, checkout}`.
- Only the JSON looks for checkouts. The text names the workspace alone.
- The forms that edit print one line, which says what changed, or that nothing needed to, and take no `--json`.

### kit welcome: a check in the JSON

`kit welcome --checks --json` prints an array. A check is `{id, step, ok, line, fix, interactive, more, runs, folder,
repository, desk, branch, kit}`.

- `step` is `toolchains` or `setup`.
- `fix` is the command that fixes it, or `null` when it holds or kit knows none.
- `interactive` is true when the fix needs you at the terminal, as `gh auth login` does.
- `more` is where to read, or the other commands beside the fix, or `null`.
- `runs` is false when kit only shows the fix and never runs it, as for a line that must run in your own shell
  (`brew-path`). It is true for every other check. `--fix` refuses a check whose `runs` is false, with exit 2.
- `folder` is the absolute path of a folder's check, and `null` for a machine check. The machine checks are bash, git,
  jq, yq, `brew-path`, the machine's package manager, and each forge host's tool and login, once per host among every
  folder's remotes.
- `repository` is the folder's member, host and path, or its desk's folder name where it has no remote.
- `desk` is true for the desk and false for a worktree.
- `branch` is the folder's branch, and `kit` is the kit version its `kit.yml` declares.
- Each of the last four is `null` where there is none, and for a machine check.

A folder's check has the same id in every folder: `kit welcome --fix=kit-hydrated --folder=<path>` names one.

A missing tool's fix comes from the toolchains kit found, and never from one it assumes. For the machine, it is the
package manager's command. For a folder, it is `kit tools install`, from that folder's tool manager, or, when the tool is
ambient, the package manager's command.

`kit welcome --keep=<check> --json` and `--unkeep=<check> --json` print the check as it now is, one JSON object, or `null`
where kit did not ask the terminal. `--progress`, with `--checks`, says on stderr what is being checked as it goes:
`⏳ checking <check>`, followed by `in <folder>` for a folder's, as each check starts, and `⏳ checked`, followed by
`<folder>` for a folder, as the machine's checks or a folder's end. kittui shows them while the checks run.

The pages of the guide are under `.kit/welcome/`, from the `kit` package, named for their order and step:
`2-toolchains.md`. A house package replaces a page by placing one of the same name, or adds one.

### The gaps in the app verbs' help

The stage tables above hold the rest. Two facts the help pages held are here:

- `changes`' `merged` stage has one more field, `named`: the references a closing keyword names in the change's body,
  such as `Fixes AB#12`.
- `kit issues issues`, `backlog`, and `underway` print what `kit flow issues --json` prints: an array of issues, and
  over a workspace `{contract, rows, errors}`, each row with its member. `kit changes changes`, `kit delivery releases`,
  and `kit delivery builds` print what `kit flow changes`, `releases`, and `builds` print, the same way.

see: [toolchains.md](toolchains.md), [workspaces.md](workspaces.md), [integrations/gh.md](integrations/gh.md),
[integrations/glab.md](integrations/glab.md), [integrations/az.md](integrations/az.md)
