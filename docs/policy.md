# Policy

A policy is the set of rules that a branch name, a worktree's path, a commit subject, a change's title, and the tree
of files must meet. A change is a pull request on GitHub or a merge request on GitLab. Run `kit policy` to check the
current branch: its name, its worktree, its commits, its open change, and the tree at HEAD. It prints each refusal
and fails, and it prints each warning too.

```sh
kit policy
```

- `kit policy` gathers the facts once, then the policy engine reports every refusal and every warning.
- `kit ci` runs it, after `kit linked` and before the gate (the repository's own CI command) and `kit check`, so a
  name that breaks the policy fails the delivered check like a failing test. That check blocks a merge only when a
  branch ruleset requires it.
- On a runner, the refusals and the warnings also appear in the step summary.
- `kit work` makes names that pass: it holds the branch and the worktree it would make to the rules first, and
  refuses, naming the pattern, before it assigns or sweeps anything. See [What kit work makes](#what-kit-work-makes).
- A branch past the default one is held to its own lease too, the one of the issue its name starts with, as
  `kit leases --check` holds it: each path the branch changed since its merge base with the base, outside the lease,
  is refused, with the `kit leases take` that claims it. On a runner the lease is the push remote's copy, which
  `kit work` and `kit submit` push; the claim lives in a ref, never in the branch's tree, so no commit on the branch
  widens it. A branch whose issue holds no lease is held to none, and the output says so. See
  [the leases design](superpowers/specs/2026-11-12-leases-design.md).

## The facts

`kit facts` prints the JSON document every engine reads. `kit policy --input` prints the same document.

`kit facts --moment=<moment>` chooses the point the facts are gathered for:

- `ci`, the default: the commits past the fork, the open change, and the tree at HEAD.
- `commit`: the tree in the index, `commits` as `[]`, and `change` as `null`. `kit commit` fills in the commit it makes,
  its trailers read from its message.

```json
{
  "moment": "ci",
  "branch": "7-fix-the-thing",
  "default_branch": "main",
  "worktree": "worktrees/7-fix-the-thing",
  "commits": [{"sha": "56d4f4b…", "subject": "#7 cli: fix the thing", "trailers": []}],
  "change": {"number": 3, "title": "Fix the thing", "body": "Closes #7", "author": "ada"},
  "tree": {
    "kit/bin/kit": {"type": "file", "executable": true, "size": 2048, "blob": "9f2c1a…", "kinds": ["bash"]}
  },
  "policy": {
    "branch": "…", "worktree": "…", "commit_subject": "…", "change_title": "…", "commit_reference": "prefix",
    "remedy": {"branch": "…", "worktree": "…", "commit_subject": "…", "change_title": "…"}
  }
}
```

| Field | Contents |
| --- | --- |
| `moment` | `commit` or `ci`: the point the facts are judged at. |
| `branch` | On a runner, the change's head branch. Elsewhere, at the desk or in any worktree, the current branch. On the default branch, or a detached checkout at a desk, it is `null`, and only the tree is checked. On a runner, a detached checkout that names no change has no branch to judge, and `kit policy` and `kit facts` fail. |
| `default_branch` | The repository's default branch. |
| `worktree` | In a linked worktree, its path from the main checkout's root, as `worktrees/7-fix-the-thing`, or its absolute path where it lies outside that root. `null` in the main checkout, which a runner's checkout is, where `branch` is `null`, and at commit. |
| `commits` | Each commit past the fork from the branch's base, merges excluded, as its `sha`, its `subject`, and its `trailers`, `[{key, value}]` in order, as git reads them from the message's last paragraph: the primary remote's default branch, or on a runner the commit the change's event names as its base. The delivered workflow fetches full history for this. When the fork is not found, as in a shallow clone, `commits` is `null`, the commits cannot be checked, and `kit policy` fails. |
| `change` | The open change, read through the code forge, the service that hosts the repository: an object with its number, title, body, and author's login, or `null`, or `{"error": "<line>"}`. [The `change` fact](#the-change-fact) says when each. |
| `tree` | The files git holds, keyed by path, read from git: the index at commit, and HEAD at ci. At either moment, a kind matched by its first line, such as a script's shebang, reads that line from the disk. |
| `policy` | The patterns, with the defaults and the active packages' filled in, `commit_reference`, and under `remedy` each rule's remedy, `""` where it has none. |

Each entry in `tree` has these fields:

| Field | Contents |
| --- | --- |
| `type` | `file`, `link`, or `submodule`. |
| `executable` | `true` for a file of mode 100755, and `false` for everything else. |
| `size` | The blob's bytes, and 0 for a submodule. |
| `blob` | The blob's object name, or the commit a submodule is at. |
| `kinds` | The kinds of file the path is, such as `bash`, or `[]` for none. On a branch, the kinds are the base's; see below. |
| `text` | The blob's content. Only a file matching a `facts.read` glob has it. |

### The `change` fact

`change` has one of three values.

| Value | When |
| --- | --- |
| an object | The code forge answered that the branch has an open change. |
| `null` | The code forge answered that the branch has no open change; or the repository has no code forge, as when the primary is a path on this machine; or `forge: none` says so; or the moment is `commit`. A `null` change leaves `change_title` unchecked. |
| `{"error": "<line>"}` | The code forge could not answer, for which change is open or for its title, body, or author; or the primary is on a host kit cannot tell the code forge of. |

For the error, `<line>` is what kit says for the read that failed, such as
`run: gh auth status (the open pull request on 7-fix-the-thing could not be read)`. For a host kit cannot tell, it
names the `forge` setting. kit cannot tell a host when nothing names it: neither the `forge` setting, the host, a CI
runner's own server, nor a login of `gh` or `glab`. `forge: none` says the primary has no code forge, and its `change`
is `null`.

`kit policy` refuses facts that hold an error before either engine runs, and so refuses a document given with
`--facts` that holds one.

### What kit commit judges

`kit commit` runs the policy before the commit exists. A plain `git commit` does not: until CI, only a harness's
deny list stops one.

- It judges the tree its own commit will make: HEAD plus the named paths, or the index when no paths are named.
- Its moment is `commit`, and `commits` holds the one commit it makes.
- When the engine errors, because `opa` is missing or a `.rego` file is broken, it refuses the commit. It fails closed.
- The engine and the patterns are read from the tree being judged, so an unstaged edit to `kit.yml` or
  `.kit/policy/` does not change the verdict.
- What `opa` loads is every file that tree holds under `.kit/policy/`, as the tree holds it: the Rego, a data file
  beside it, and a subdirectory, a link resolved in the tree. A file git holds there is never read from the disk, so
  one edited or deleted on the disk and not staged judges as staged.
- Then comes what kit placed under `.kit/policy/`, which git does not hold. A link to a file of the repository's
  own, such as a package of its own, is read as the tree holds that file. A file the release delivers is read as
  placed, since the pinned release cannot change under a commit.
- Warnings print, and the commit still goes through.

### What judges a branch

On a branch past the default one, `kit policy` and `kit linked` judge by the policy on the branch's base, the commit
the commits are counted from. A branch cannot loosen the rule that judges it by what it holds in its files: a
pattern it blanks, a login it adds under `linked_exempt`, an engine it names, a file it stops a rule from reading, a
`forge` it drops or a `forges` entry it changes, a kind it redefines, a file it removes, adds, or edits under
`.kit/policy/`, and a command it carries under `node_modules/.bin` or `.venv/bin` change nothing. The end of this
section says what that does not cover.

The base depends on where the verb runs:

| Where it runs | The base is |
| --- | --- |
| a desk | `refs/remotes/<primary>/<default>`, read in full, so a tag or a branch named `<primary>/<default>` does not stand for it. `<primary>/<default>` is the default branch of the `primary` remote, `origin` unless `kit.yml` names another. |
| a GitHub pull request | the pull request's base commit, `pull_request.base.sha` in the event at `GITHUB_EVENT_PATH` |
| a GitHub merge group | the merge group's base, `merge_group.base_sha` |
| a GitLab merged-results pipeline | `CI_MERGE_REQUEST_TARGET_BRANCH_SHA` |
| any other GitLab pipeline | the tip of the branch `CI_MERGE_REQUEST_TARGET_BRANCH_NAME` names, fetched from the primary every time, forced and with no tags, so a ref an earlier job left counts for nothing |
| a CI system that is no code forge's own, and Azure Pipelines | the target branch's tip, fetched from the primary every time, as on GitLab; the system names the head branch and the target in variables of its own, which [integrations/ci.md](integrations/ci.md#ci-that-is-not-the-code-forges-own) lists |
| CircleCI | the primary's default branch, fetched the same way, because CircleCI names no target |

- On a runner, the base is the one the change's event names, which no command of the branch can move, as the gate could
  move `<primary>/<default>`.
- It is never the merge base, `CI_MERGE_REQUEST_DIFF_BASE_SHA` on GitLab, which a branch chooses by where it forks.
- A runner that names a change and no base it can have fails both verbs, naming what is missing. So does a change whose
  head branch or target the system does not name.
- In a merge queue, the branch is the merge group's head, `gh-readonly-queue/<base>/pr-<n>-<sha>`, which the kit's
  default `branch` pattern refuses. A repository that runs `kit ci` on `merge_group` events sets `policy.branch` to
  allow it.
- `kit ci` runs `kit linked` and `kit policy` first, before the gate and `kit check`, which run commands of the
  branch's own: the gate itself, and the commands the `kit:generate` directives name. On a runner it installs the
  change's tools, `kit tools install`, only after those two, and the delivered workflow installs nothing before
  `kit ci`, so no install script of the branch has run when they judge.
- The two verbs run their tools, `opa`, `jq`, `yq`, `git`, and the code forge's tool, from no directory of the
  checkout, which the branch fills. Each takes every such directory off `PATH` first, `node_modules/.bin` and
  `.venv/bin` among them, whether a pipeline put it there, as `kit tools path` names them, or no one did. `kit
  policy` then puts the chosen toolchain's directories first at a desk. So an `opa` or a `gh` the branch carries in
  its own files never answers for it.
- On a runner, the opa engine is the one the base pins. `kit policy` puts no toolchain directory first there, since
  those tools are the ones the branch's own files pin, and it installs the `opa` the base's `kit.lock` holds, with
  the kit toolchain, into a home and a download cache it makes new for the run. A copy an earlier run left, as the
  runner's cache of `~/.kit/tools` restores one, is never used; the download must have the hash the base's lock
  records, and a branch that pins a different engine in its own `kit.yml` and `kit.lock` changes nothing.
  `jq`, `yq`, `git`, and `gh` are the runner's own. A base whose `kit.lock` holds no `opa` row, as one whose tool
  manager is mise or nix, or the first pull request of a repository, installs nothing: the `opa` on the runner's
  `PATH` judges, and `kit policy` fails, saying so, where there is none. It never takes the branch's.
  A runner image that carries `opa`, or a step of the repository's own before `kit ci` that installs it from the
  base's files, supplies one.
- The delivered workflow takes the kit release from the base's `kit.yml`, the commit the pull request's event names,
  and sets `KIT_VERSION` to it, since kit otherwise chooses its release by the `kit.yml` it is run in, the branch's.
- `policy`, `policy_engine`, `linked_exempt`, `facts`, `forge`, and `forges` come from the base's `kit.yml`. Where
  the base has none of one, it is absent, and the kit's default applies, not the branch's: for `forge` and `forges`,
  the provider the remote's host names.
- `forges`, the map from remotes to providers, is the base's as `forge` is, so a branch cannot point the primary at
  a forge that reads no change.
- Every other setting is the checkout's. `primary` among them names the remote the base is read from, and a `primary`
  that names no remote fails.
- A branch that adds a file to `facts.read`, for a rule of its own, changes nothing until it is merged, as the rule
  itself does not.
- What `opa` loads is exactly the base's, and nothing on the disk under `.kit/policy/` is read: every file the base
  holds under `.kit/policy/`, in a subdirectory too, a data file beside the Rego included, a link resolved in the
  base's tree; and every file a package in the base's `packages:` delivers there, a template rendered with the base's
  answers.
- The `kinds` in the facts are the base's too: the kinds files the base holds under `.kit/kinds/` and those its
  packages deliver there, compiled into a matcher of their own, apart from the disk's. A kind the branch adds or
  redefines, to take a path out of a rule keyed on it, classifies nothing until it is merged.
- A package is looked up as delivery looks it up: in the sources the base's `kit.yml` names, the last first, fetched
  where the cache lacks them; then in the release; then in the repository's own `.kit/packages/`. A package under the
  repository's root, the repository's own or the release in a checkout of the kit, is read as the base holds it.
- A package the base lists that is in none of those places fails both verbs, naming it, so none of its rules is
  dropped.
- The packages are the ones `packages:` lists, as `kit hydrate` delivers them. `kit install` writes every package the
  set needs there; a bundle listed alone, without its members, delivers none of their Rego.
- A change to the policy is judged by the policy before it, and takes effect once it is on the default branch.
- On a runner, the branch is the change's head branch, whatever its name and whatever is checked out, so the
  detached checkout of a pull request is judged the same way. On the default branch, or a detached checkout at a
  desk, both read the disk.
- On a runner, a detached checkout that names no change fails both verbs, and `kit leases --check` and `kit facts`
  too: there is no branch whose base could judge it, and a check that cannot judge never passes. A runner is known
  by `CI`, which most CI systems set, or by its system's own marker, such as `TF_BUILD` or `JENKINS_URL`, which
  [integrations/ci.md](integrations/ci.md#ci-that-is-not-the-code-forges-own) lists. Check the branch out by name
  there, or run the verb in the change's own pipeline.
- A fork's pull request from its own `main` has `main` as its branch, which the default `branch` pattern refuses.
  A `policy.branch` on the default branch that matches `main` allows it.
- `kit policy --input` prints the facts as the base's policy has them, the base's kinds included. `kit facts` prints
  the disk's. `kit policy --facts=<file>` judges by the disk's, since it tests a rule.

A base with no `kit.yml` is one the kit is not installed on. There, both read the checkout's own settings and Rego,
as on the default branch, so the pull request that installs the kit sets its first policy.

The guarantee covers what a branch holds in its files, with the tools a runner starts with. What it does not cover:

- The workflow file. On a `pull_request` event GitHub runs the workflow as the pull request's merge commit holds it,
  so a branch can edit `.github/workflows/kit-ci.yml`, reorder it, or drop `kit ci`. `kit check` reports a delivered
  file that differs, but it runs inside that same job. Hold the workflow with a ruleset that requires a workflow from
  the base repository, or with a code owner's review of `.github/workflows/`. See
  [integrations/gh.md](integrations/gh.md#pull-requests-from-forks-and-the-event-that-runs-the-workflow).
- A base that pins its `opa` outside `kit.lock`, in `mise.toml`, a flake, a Brewfile, or an image, and a runner with
  no `opa`: kit does not install it from there before the judgements, so the engine is the runner's own, or none and
  the judgement fails. Installing the base's `mise.toml` would need `mise trust` on a file kit has not read; that
  is left to the repository's own step.
- A repository whose kit is `unreleased`, the kit's own: the judge is the checkout's `kit/bin`, which a branch edits.
- `jq`, `yq`, `git`, and `gh` are the runner's own, so a self-hosted runner that earlier jobs left tools on is that
  runner's to keep clean.
- The gate and `kit check` run the branch's own commands and tools, as they must. They run after the judgements.

None of this was run on a live GitHub runner: the order and the tools are held by tests that run the delivered
workflow's steps and `kit ci` offline, and what GitHub does with a fork's pull request is as its documentation says.

A base that is not here, as in a clone that lacks `<primary>/<default>` or the event's commit, fails both verbs
wherever they run. They say `the base, <base>, is not here, so its policy cannot be read; fetch it with full
history`, naming the ref or the commit; a change's target that cannot be fetched is named the same way. Where
git has not recorded `<primary>/HEAD`, the default branch is taken to be `main`, and they say
`run: git remote set-head <primary> --auto (<primary>/HEAD is not recorded, so the default branch is taken to be
main)`; where there is no such remote, they say `run: git remote add <primary> <url>`. A read
of the base's files, or of a source it names, that fails, for any reason other than the file not being there, fails
them too.

### Reading a file's text

A rule that judges content needs `text`. Name the files in `kit.yml` by glob:

```yaml
facts:
  read:
    - README.md
```

- A file's `text` is capped at 65536 bytes.
- A binary file or an oversized file has no `text`, and kit warns, naming it.
- A rule should treat a missing `text` as unknown, not as empty.

### Testing a rule

`kit policy --facts=<file>` judges a saved facts document, and does not gather any facts.

```sh
kit facts > fixture.json
kit policy --facts=fixture.json
```

Edit the fixture to test a rule against facts that the repository does not have.

- A relative `<file>` starts from the directory the command was typed in.
- A file that is not a facts document, a JSON object with a `policy` key, is refused.

## The rules

`policy:` in `kit.yml` holds one rule per subject. A rule is an extended regular expression, or a map of a
`pattern` and a `remedy`: what to do instead, which every refusal by the rule names after it, in parentheses.

- A subject that is absent takes the kit's default: the workflow's own naming from `.kit/1st.md`, unless an active
  package sets it; see [Packages that set rules](#packages-that-set-rules). The defaults are data, the `policy:` map
  in the kit package's `package.yml`, with the same keys, so a repository that says nothing gets the loop's names,
  and one that says otherwise gets its own.
- A pattern set without a remedy has none, since the remedy below it was written for another pattern. A remedy set
  alone keeps the pattern below it.
- An empty pattern turns that rule off.
- A pattern bash cannot compile is refused, naming the file that sets it.
- A subject the kit does not know is refused.
- A change whose author is a login under `linked_exempt` in `kit.yml` passes with no rule checked, the tree rules
  included, and `kit policy` says so by name. Its branch, its commits, and its pull request title are a bot's, such as
  `dependabot[bot]`'s. The same setting passes the change through `kit linked`; see
  [packages.md](packages.md#settings).

| Subject | Checks | Default |
| --- | --- | --- |
| `branch` | the branch's name | `^[a-z0-9]+-[a-z0-9][a-z0-9-]*$`, the form `kit work` creates |
| `worktree` | a linked worktree's path from the main checkout | `^worktrees/[a-z0-9]+-[a-z0-9][a-z0-9-]*$`, where `kit work` puts it |
| `commit_subject` | every commit's subject past the fork | `^([A-Z]+)?#[0-9]+ [^ ]`, starting with its issue's reference |
| `change_title` | the open change's title | `^[^[:cntrl:]]{1,120}$`, one line of at most 120 characters |
| `commit_reference` | where each commit carries its issue's reference: `prefix` or `trailer`; see below | `prefix` |

```yaml
policy:
  branch:
    pattern: '^(feature|fix)/[a-z0-9-]+$'
    remedy: 'name the branch feature/<slug> or fix/<slug>'
  commit_subject: ''
```

A refusal then reads `branch 'topic' does not match policy.branch: ^(feature|fix)/[a-z0-9-]+$ (name the branch
feature/<slug> or fix/<slug>)`.

### Packages that set rules

A package's `package.yml` can carry a `policy:` map with the same keys. The rules are layered, a later layer's
winning:

1. the kit's defaults, the kit package's `policy:` in the release
2. each active package's `policy:`, in the order `packages:` in `kit.yml` lists them, which is dependency order as
   `kit install` writes it, so the later package wins
3. `kit.yml`'s `policy:`, which wins over all; an empty pattern turns a rule off

A package that `packages:` lists and that is not in reach fails `kit policy`, naming it, so none of its rules is
dropped. Both engines read the result from `input.policy`. On a branch past the default, the packages are the base's,
each `package.yml` as the base holds it where the package is the repository's own; at commit, as the tree being
committed holds it. So a branch that drops a package, or loosens its rules, changes nothing until it is merged.
[`policy/conventional`](packages/policy/conventional.md) is such a package.

### Where a commit's issue reference goes

`commit_reference` says where each commit carries its issue's reference:

- `prefix`, the kit's default: in front of the subject, as `#7 cli: fix the thing`. The default `commit_subject`
  pattern holds every commit to it, and `kit commit` supplies it from the branch.
- `trailer`: in a `Refs: #7` trailer in the message's last paragraph. Every commit past the fork must carry one that
  names an issue, `#7`, `AB#4521`, or several apart by commas, and is refused without. `kit commit` adds it from the
  branch to a message that has none, and `kit work`'s start commit carries it. The `policy/conventional` package sets
  it, since Conventional Commits keeps references in a footer.

A `Refs:` trailer that names an issue other than the branch's attaches it to the branch's pull request, as a
subject's reference does.

`kit policy --rules` lists each rule, its pattern, and where it is set, then `commit_reference` and its value, and
judges nothing; `kit policy --input` shows the remedies, under `policy.remedy`. `--json` prints an object a line,
`{rule, pattern, from, engine}`, and `--jq` the same formatted by jq. `from` is `kit.yml` where its `policy:` map
sets the rule, an empty pattern included, an active package's name where its `package.yml` does, else `default`;
`engine` is the engine that judges, `patterns` or `opa`. It reads no forge. On a branch past the default it lists the
base's rules, as `kit policy` judges by them, and fails as `kit policy` does when the base cannot be named or read.
The patterns are the same whichever the engine: the opa package's `kit.rego` reads them from the facts.

```sh
kit policy --rules --json
```

A single-quoted pattern is taken literally. Write patterns in the subset that bash's extended regular expressions
and OPA's RE2 share, so both engines read them the same way:

- character classes
- anchors
- alternation
- counted repetition

### What kit work makes

`kit work` holds the names it makes to the rules in the checkout's `kit.yml`, as `kit policy` holds them in CI.

- A branch it names, `<key>-<slug>`, that `policy.branch` refuses is never pushed. A title with no letter or digit
  for the slug gives `<key>-issue`.
- The worktree it would make, `worktrees/<branch>`, that `policy.worktree` refuses is never made.
- Either refusal names the rule's pattern and remedy, and comes before anything is assigned or swept.
- A branch that already exists, one an open change, the forge, or origin holds, and a worktree that already exists,
  are warned of when the rules refuse them, since `kit policy` refuses them in CI.
- A draft's title is the issue's. One that `policy.change_title` refuses is warned of, to retitle.

## The engines

| Engine | How it checks | Chosen by |
| --- | --- | --- |
| `patterns` | Matches each rule in bash. Needs no other tool. | Default. |
| `opa` | Open Policy Agent evaluates every `.rego` file under `.kit/policy/`, package `kit.policy`. The set `deny` of strings is the refusals. | `policy_engine: opa`, or any `.rego` file in `.kit/policy/`, at any depth, when `policy_engine` is not set. |

The `opa` engine needs `opa`. Pin it in the repository's toolchain, then run `kit tools install`.

The `policy/opa` package delivers `.kit/policy/kit.rego`: the patterns engine's rules written in Rego, with the same
refusals, the `Refs:` trailer that `commit_reference: trailer` asks for among them. Because it is a `.rego` file,
adding the package selects the `opa` engine, and the results stay the same.

Rules over `tree` need `opa`. The `patterns` engine ignores `tree`.

### Refusals and warnings

The engine reads two sets of strings from package `kit.policy`:

- `deny` holds refusals. Any one fails `kit policy`. Rego that does not define `deny` at all, as in a misspelled
  package, is refused too, since nothing was judged.
- `warn` holds warnings. They are printed and never fail anything.

### A rule of your own, through a local package

Rego that belongs to one repository ships through a local package, as templates do. Put the file in the package's
source, and kit delivers it as a link:

```text
.kit/packages/house/files/repo/.kit/policy/house.rego   the source
.kit/policy/house.rego                                  delivered by kit, as a link
```

- The package must list `policy/opa` under `depends:`.
- Without it, `kit.rego` is missing. Any `.rego` file selects `opa`, so the naming rules would silently stop.
- `kit packages add` brings in what a package depends on. `kit hydrate` does not: it reads only `packages:` in
  `kit.yml`.
- So a package that is already active, and gains the line, needs one more step. Run `kit packages add policy/opa`,
  or list `policy/opa` under `packages:` in `kit.yml`.

```yaml
description: "This repository's own tree rules"
depends:
  - policy/opa
```

This repository's `house` package holds a rule over `tree`. It refuses a file in `kit/bin/` that is not executable:

```rego
package kit.policy

import rego.v1

bin := "kit/bin/"

# The name after kit/bin/, for a file directly in it.
bin_name(path) := name if {
    startswith(path, bin)
    name := substring(path, count(bin), -1)
    not contains(name, "/")
}

deny contains sprintf("%s is not executable", [path]) if {
    some path, f in input.tree
    bin_name(path)
    not f.executable
}
```

A rule can also judge the commits:

```rego
package kit.policy

import rego.v1

deny contains msg if {
    count(input.commits) > 20
    msg := sprintf("%d commits; split the change", [count(input.commits)])
}
```

`tests/policy.bats` checks that both engines give the same refusals for the same facts.
