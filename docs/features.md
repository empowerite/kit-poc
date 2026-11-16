# Features

kit is a versioned release of house rules for AI coding agents, and of the checks that hold agents
and people to those rules. This page lists what kit does, by purpose. Each section says what a
feature is and what it does for you, and ends with the page that describes the feature in full.

Three other places hold what this page leaves out:

- [README.md](../README.md) shows how to install kit and how to add it to a repository.
- [architecture.md](architecture.md) explains how the parts fit together.
- `kit help <verb>` prints the reference for one command: its arguments, what it refuses, and its exit statuses.

## Rules where agents look

kit writes each rule once and points every agent at it.

- `.kit/1st.md` is the file every agent reads first. It holds the integrity rules for reporting
  work, the rule that no agent changes the desk, the kit commands that replace raw git
  commands, and the rules by kind of file. The desk is the root checkout on a person's machine.
- A rule, `.kit/rules/<kind>.md`, says what work on one kind of file must do to
  be trusted. A kind, such as `bash` or `markdown`, is defined once, in a file
  under `.kit/kinds/`, by the paths and the first lines that mark its files.
- A style, `.kit/styles/<kind>.md`, says how a file of one kind looks.
  Styles are optional: each comes from a `style/<kind>` package.
- `kit context <path>` prints the rules and styles that
  govern a file, so an agent reads only the rules that apply.
- An adapter puts a pointer to `.kit/1st.md` where one agent tool looks for its instructions. kit has an adapter
  for Claude Code, Cursor, GitHub Copilot, and Gemini CLI. Each adapter is an `agents/<harness>` package. Each
  depends on `agents/generic`, which writes a short region into `AGENTS.md` for any agent that reads that file.
- The Claude Code adapter also calls `kit context` from a hook before
  each edit, so Claude Code is shown a file's rules without asking.
- `kit serve` offers the rules and some of kit's commands to an agent over the
  Model Context Protocol (MCP). Each adapter registers it with its agent tool.
- A repository's own rules sit beside the delivered rules, in
  `AGENTS.md` or in a package of its own. An update leaves them alone.

see: [context.md](context.md), [serve.md](serve.md)

## Checks

`kit ci` runs four checks and reports each one:

| Check | Fails when |
| --- | --- |
| `kit gate` | the repository's gate fails, or the repository has no gate |
| `kit check` | a delivered file differs from the release, or a generated region differs from its command's output |
| `kit linked` | the pull request is not linked to an open issue |
| `kit policy` | a branch name, worktree, commit subject, pull request title, or file in the tree breaks the policy |

The gate is the repository's own CI command. The `github/ci` package delivers a GitHub Actions job
that runs `kit ci` on every pull request, and any other pipeline can run `kit ci` too. At a desk,
`kit ci` passes only after the branch has a pull request, because `kit linked` fails without one.

`kit lint` is not one of the four checks, and `kit ci` never runs it. `kit lint` runs each rule's linter, kit's
own checks that a rule names, and each style's templates, over the staged files or over the files you name. One
of kit's own checks is `pinned`, which refuses a workflow action that is not pinned to a full commit SHA.

`kit commit` runs `kit lint` over the staged paths, and the `hooks/lefthook` package
runs it from a pre-commit hook. In CI, `kit lint` runs only where the repository's
gate runs it, for example where the `gate` setting is `kit lint --all-files`.

The four checks are fixed. What each one runs is found at run time, from the repository's files:

| What | Run by | Found from |
| --- | --- | --- |
| the gate | `kit gate` | the `gate` setting; else a `ci` recipe in the root justfile, a `ci` target in a Makefile, or a `ci` script in `package.json` |
| the policy engine | `kit policy` | the `policy_engine` setting; else Open Policy Agent when `.kit/policy/` holds a `.rego` file; else the patterns in `kit.yml` |
| the toolchain | `kit gate`, `kit policy`, and `kit lint` | the toolchain that is active or usable where kit runs, such as mise with a `mise.toml`; else your choice |
| the linters | `kit lint` | the `lint:` command in the frontmatter of each rule and style that governs a file |
| kit's own checks | `kit lint` | the names under `checks:` in that frontmatter |
| the templates | `kit lint` | the `templates:` list in that frontmatter |

A repository that adds a rule or a style adds its linter, its
checks, and its templates with it, and `kit lint` runs them.

see: [architecture.md](architecture.md#the-checks), [policy.md](policy.md)

## Templates

A template is a file written in kit's template language, which has one construct:
the hole, `«name»`. The same template both creates a file and checks one.

- `kit new file "${path}"` creates a file from the template of the style that governs the path. It
  fills the holes from the path and from flags, and prints the rules to read before you write the rest.
- `kit lint` checks every governed file against its style's templates. When a file does
  not match, `kit lint` names the line where the file leaves the closest template.
- A style package delivers the templates for its kind of file, such as a bash script, a justfile, or a workflow.
  A repository replaces a template through a package of its own, the same way it replaces any delivered file.

see: [templates.md](templates.md)

## The workflow

An agent takes an issue to a merged pull request, in a git worktree of its own.
It never changes the desk. A person at the desk is not bound by that limit.

1. `kit work <N>` starts issue N. It creates the worktree `worktrees/<N>-<slug>`, a branch linked to the
   issue, and a draft pull request. It never switches the desk's branch. At a terminal, it moves uncommitted
   work on the desk into the new worktree. An agent passes `--no-sweep`, and that work stays on the desk.
2. `kit commit` commits what is staged. First it runs the linters over the staged
   paths and checks the subject against the policy. It adds the issue's reference
   from the branch name. It refuses to run at the desk or on the default branch.
3. `kit submit` pushes the branch and commits nothing. It
   never forces. When the remote has moved, run `kit rebase`.
4. `kit rebase` rebases the branch onto the default branch and pushes it. It forces only over
   the tip it read, so it never overwrites a commit that someone pushed in the meantime.
5. `kit gate` runs the gate locally, with the same tools CI uses.
6. `kit ready` marks the draft pull request ready for review. With
   `--report-file=<path>`, it first writes your report into the pull request's body.
7. A person merges the pull request. `kit tidy` then removes the finished worktree
   and its branch, and settles the issues that the code forge did not close. `kit
   tidy --wait=7` waits for the pull request of issue 7 to merge first.

The `workflow` package delivers these steps to agents as `.kit/workflow.md`, with the worker
contract. A repository that leaves the package out writes its own steps in `AGENTS.md`.

The `agents/claude` and `agents/gemini` packages each deliver a deny list. The list refuses the
raw git commands that these verbs replace, such as `git commit`, `git push`, `git rebase`, `git
worktree add`, and `git branch -D`, and the merge commands of each forge. It matches literal patterns, so a form it
does not list passes: Claude Code's list names `git -C <dir>` before the writing commands, and Gemini's, which matches
a prefix, does not. The other agent tools get no deny list. `kit trust enforcement`
shows what binds an agent and what is only advice, for the repository and for each agent tool.

see: `kit help <verb>` for each verb, [architecture.md](architecture.md#the-workflow-and-the-gate),
[architecture.md](architecture.md#enforcement-tiers)

### Leases

Leases let sessions that work at the same time tell who is changing which paths. A lease records
the paths that the work on an issue claims, who took the lease, and when it expires, which by
default is an hour after it is taken or renewed. `kit work <N>` takes a lease for the paths the
issue lists under a `Paths` heading, and `kit leases` lists the leases and changes them.

kit holds work to the leases in three places. `kit leases take` refuses a claim that may overlap
the live lease of another issue. `kit commit` refuses a staged path that the lease of another
issue on the branch holds, unless the commit names that issue. In CI, `kit policy` refuses a path
that the branch changed outside its own lease. A lease is not a lock: it only says who holds what.

see: `kit help leases`, [the leases design](superpowers/specs/2026-11-12-leases-design.md)

### Where the work stands

`kit flow` shows where the work stands, in five stages: issues, changes, builds, incoming, and releases.

| Stage | What it lists |
| --- | --- |
| `issues` | every open issue of every tracker, oldest first, each in the backlog or underway |
| `changes` | every open pull request, with its state, its checks, and the issues it closes |
| `builds` | the newest CI runs that no pull request owns: pushes to the default branch or a tag, and scheduled or manual runs |
| `incoming` | what a fetch of every remote brought: new commits, branches, and tags; it never rebases, merges, or pulls |
| `releases` | the releases on the code forge, newest first |

An issue is underway when an open pull request closes it, or when
a branch is named for it. Otherwise the issue is in the backlog.

At a terminal, `kit flow` opens the Flow app in kittui; see [The terminal UI](#the-terminal-ui).
Without a terminal, or with `--text`, it prints each stage under a heading, so you can pipe, page,
or save the output. `--json` prints the same facts as JSON. At a terminal, `kit flow <stage>` opens that
one stage; without one it prints the stage, and `--json` prints it as JSON. The `flow` setting in `kit.yml` names the
stages that `kit flow` draws, and their order.

`kit workspace` shows what git holds: remotes, branches, worktrees, commits, and tags. It
reads only the local repository, so what it shows of a remote is what the last fetch left. The
desk and its worktrees are not a stage of `kit flow`: `kit workspace worktrees` lists them.

see: `kit help flow`, [apps.md](apps.md), [workspaces.md](workspaces.md#look-at-git-across-a-group)

### Publishing, and pull behind push

`kit release <version>` tags HEAD as `release/<version>` and pushes only that tag, which starts the repository's
release workflow. It refuses, for example, a tag that already exists, and a version that is not higher than
every earlier release. `kit publish <version>` then runs on a CI runner. It pushes each artifact that the
repository names under `publish:` in `kit.yml` to its targets, such as a GitHub release or an npm registry.

A source that consumers pull from can serve a release later than the push, for example after a
scan. kit watches that gap. `kit flow releases` shows whether each source serves each of the
newest releases yet, and `kit release <version> --wait=<duration>` waits until every source does.

see: [publishing.md](publishing.md)

## Welcome

`kit welcome` is where a newcomer starts. It is a guide in five steps:

1. Introduction: what kit is, where it works, and who it is for.
2. Toolchains: checks for bash, git, jq, and yq, which kit runs on, and for the machine's package manager.
3. Setup: checks for your login on each code forge, and then for each folder of the workspace. In a folder,
   it checks kit and the files kit places, the git hooks, the tool manager, the linters, and `kit check`.
4. Customize: how kit is designed to be changed without forking it: packages, a house package, and updates.
5. Terms: the words kit uses, by topic.

At a terminal, `kit welcome` opens in kittui. Each failed check shows its fix, and you can copy the fix or
have kit run it. A check that passes can still offer a fix, which kit draws with 💡. For example, a folder
whose `kit.yml` declares no kit version passes, and offers `kit install`. Without a terminal, or with
`--text`, `kit welcome` prints each page with its checks, runs nothing, and exits 1 when a check fails.

Each step is a page under `.kit/welcome/`, from the `kit` package. A house package can replace a page or add one.

`kit tutorials` lists short lessons and opens one. One of them, `kit tutorials applications`, tours kittui's apps.

see: `kit help welcome`, [workspaces.md](workspaces.md#check-the-setup-of-a-group), [tutorials.md](tutorials.md)

## The terminal UI

kittui is kit's terminal UI. `kit` typed with no verb opens it on the welcome guide. Every action
in kittui works with a key or with a plain click. Without a terminal on stdin, stdout, and stderr,
kit never opens kittui: it prints text, and a verb that lacks an argument refuses in one line.

Help and forms:

- `kit help` at a terminal opens a palette, which is a table of every verb with its group and its
  one-line purpose. Type to filter the table, and press → on a row to read the verb's help page.
- Press Enter on a verb to open its form. The form has one field for each part of the verb's usage
  line, and it offers the values the repository has, such as changed paths, packages, and templates.
  A field that the command line needs carries a dim `required` tag until it has an answer.
- The form shows the command line it builds. Press Enter on that line to run it.
- A verb that you run at a terminal without an argument it needs opens the same
  form, filled with what you gave. `kit commit` with no message is an example.

kittui builds each form from the verb's header, so a new verb gets a form
with no code of its own; see [modules.md](modules.md#writing-a-verb).

Apps:

kittui has nine apps. Press `=` on any screen for the menu of apps. Flow is the picture that `kit flow` draws.
Each other app is built around one thing, such as the issue or the release. Each tab of an app shows one stage.
Each app has a verb: at a terminal, the verb opens its app, and `kit <verb> <tab>` opens the app on that tab.

| App | Verb | Built around | Tabs |
| --- | --- | --- | --- |
| Flow | `kit flow` | the work, from issues to releases | the stages the `flow` setting names: issues, changes, builds, incoming, releases |
| Issues | `kit issues` | the issue | issues, milestones, iterations |
| Changes | `kit changes` | the pull request | changes, reviews, checks, merged |
| Repositories | `kit workspace` | the repository | repos, worktrees, branches, commits, tags, remotes, incoming |
| Delivery | `kit delivery` | the release | releases, builds, artifacts, environments, deployments |
| People | `kit people` | the person | people, teams, agents |
| Trust | `kit trust` | the evidence | evidence, findings, controls, waivers, policy, enforcement |
| Platform | `kit platform` | the service | services, toolchains, tools, settings |
| Packages | `kit packages` | the package | packages |

Some values on a row are links to a row in another app. Follow a link, and kittui opens
that app on the right tab, with the cursor on the row. The link leaves a crumb on the
title line: ↩ and the name of the place you came from. Click the crumb, or press ⌫, to go
back to the view as you left it. See [Moving between apps](apps.md#moving-between-apps).

`kit tui` runs `kittui`, a Go binary that each release carries for Linux and macOS, on amd64 and arm64.

see: [apps.md](apps.md), [the kittui README](../projects/tui/README.md), [terminals.md](terminals.md)

## Code forges and trackers

- A code forge is the service that hosts the repository. kit supports GitHub, through `gh`. Its providers
  for GitLab, through `glab`, and for Azure DevOps, through `az`, are experimental: each is tested
  against a fake built from the tool's documented output, and has not yet run against a live project.
- Every provider answers in the same shape, so the commands and the screens are the same on each code forge.
- A tracker holds the issues. The form of an issue's reference picks the tracker: `#7` names an issue on the
  code forge, and `AB#4521` names an Azure DevOps work item. A repository can use more than one tracker at once.
- A repository can have several remotes, such as a fork as `origin` and the shared repository
  as `upstream`. kit reads pull requests, builds, releases, and issues from the primary
  remote, and pushes branches to the push remote. The `primary` and `push` settings in
  `kit.yml` name them. `primary` defaults to `origin`, and `push` defaults to the primary.
- kit finds the code forge of each remote from the `forge` and `forges` settings,
  and otherwise from the remote's host. `forge: none` says that the primary
  remote has no code forge kit knows, such as Bitbucket or a plain git server.
- Only the workflow verbs and two checks, `kit linked` and `kit policy`, call a code forge.
  A repository with no code forge can still install, update, check, and run `kit context`.

see: [trackers.md](trackers.md), [architecture.md](architecture.md#remotes-and-their-code-forges),
[integrations/1st.md](integrations/1st.md)

## Workspaces

- A workspace is what kit looks at: one repository, or a named group of repositories.
- `kit workspaces` lists your groups and favorites, and shows the members of a group with their checkouts.
  It edits `${XDG_CONFIG_HOME:-~/.config}/kit/workspaces.yml`, and keeps your comments when it does.
- Inside a repository, kit starts on that repository. Outside a repository, kit starts on the group you used last.
- `kit --workspace=<group> flow` shows the work of every member of a group at once.

see: [workspaces.md](workspaces.md)

## Bots

A bot is a GitHub App that you set up to act for you. What an agent does through the bot, such as a
label, a comment, or a pull request, shows on GitHub as the work of `<slug>[bot]`, and not as yours.

- `kit bots` lists your bots, and `kit bots --add=<name> --app=<id> --key=<source>` adopts an App that already
  exists. kit keeps the private key in the macOS keychain or the Linux Secret Service, and no command prints it.
- `kit bots --check` compares the App's permissions with the jobs the bot is set
  up for. It also says whether the App's installation reaches this repository.
- `kit bots run <command>…` runs a command as the bot. The command gets a fresh token
  that reaches only this repository, and kit revokes the token when the command ends.
- Under `kit bots run`, `kit commit` adds the trailer `Agent: <name>[bot]` to the
  commit message. You stay the author and the committer, so signing keeps working.

kit cannot yet register a new App, and a bot cannot yet pick up issues or review pull requests by itself.

see: `kit help bots`, [integrations/gh.md](integrations/gh.md#a-github-apps-bot),
[the design](superpowers/specs/2026-11-12-bots-design.md)

## Toolchains

- A toolchain supplies the tools that a repository's work
  runs with, such as its linters and the tools its gate runs.
- `kit toolchains` lists the toolchains kit finds where it runs, and records which one to use.
- `kit tools` lists, installs, and updates the tools that the chosen toolchain
  pins. It does the same for the packages that npm or uv pins on top.
- kit works with its own tool pins, under `tools:` in `kit.yml`, and with mise, Nix, Homebrew,
  a Docker image, or a dev container. apt, dnf, and pacman can supply what kit itself runs on.
- The gate runs with the same pinned tools on the desk and in a worktree. On a CI runner it does so when the job names a
  toolchain; the delivered job's default, `ambient`, installs nothing and uses the tools the runner has.

see: [toolchains.md](toolchains.md)

## Packages

Everything kit delivers comes from a package.

- The `kit` package holds the entry file and the rules. It
  is the default: `kit install` with no names installs it.
- Every other package is optional. There is the `workflow` package, a style package for each
  kind of file, the CI job, the pre-commit hook, two policy packages, and the four adapters. A
  bundle, such as `empowerite`, activates its members, and you can remove any member on its own.
- `kit install` and `kit packages add` activate packages, along with the packages
  they depend on. `kit packages remove` deactivates a package and takes out
  everything it placed. `kit packages` lists the packages and shows which are active.
- A repository defines packages of its own under `.kit/packages/<name>/`, in the same
  format. Such a package can add rules, styles, or templates that the release does not have.
- To replace a delivered file, a repository's package depends on the package that delivers
  the file, and places its own file at the same path. The repository's file wins, because
  it comes later in dependency order, and every other file still comes from the release.
- A delivered template can ask for a value, such as the CI runner. Set the value under `answers:` in `kit.yml`.

kit changes a file that it shares with the repository in the least intrusive way the file's format allows:

| When the file | kit uses |
| --- | --- |
| has a format that supports includes, such as `lefthook.yml` | an include line that the repository adds, and that `kit check` requires |
| has a format with comments, such as `AGENTS.md` | a region |
| supports neither, such as `.claude/settings.json` | a merge by key, which keeps the repository's own keys |
| belongs entirely to kit | a link or a read-only copy under `.kit/` |

see: [packages.md](packages.md), the "Changing what kit adds" section of `.kit/1st.md`

## Releases and updates

- A kit release is one tarball, `kit-<version>.tar.gz`, published from the tag `release/<version>`.
- A repository pins the release it uses with `version:` in `kit.yml`. The `kit` you
  install is a loader: in each repository, it runs the release that the repository pins.
- `kit update` moves a repository to a new release. It replaces a delivered file that is
  still as kit placed it, and merges an edited file three ways, with the previous release
  as the base. It keeps the repository's own deny list entries and settings keys.
- When `kit update` lacks the previous release for a file it must merge, it refuses before it writes anything.
- git ignores what kit places under `.kit/`. `kit.yml` declares the active packages, and `kit hydrate`
  places their files in a fresh clone or worktree. Every verb that reads a delivered file hydrates first.
- kit runs nothing in a clone until you trust it. `kit trust --clone`
  shows what the clone asks kit to run, and records your answer.

see: [install.md](install.md), [packages.md](packages.md),
[CONTRIBUTING.md](../CONTRIBUTING.md#release) for how kit itself is released

## Regions

- A region is a part of a file that a command writes. It sits between a `kit:generate`
  line and a `kit:end` line, and the rest of the file stays the repository's own.
- `kit generate` rewrites every region from its command. `kit check` fails on a stale region.
- kit's block in `AGENTS.md` is a region, and so is its `/worktrees/` line in `.gitignore`.
  A repository can add regions of its own, such as a table built from its manifests.

see: [generate.md](generate.md)

## The model

- `kit model check` checks the model of kit's entities, one YAML file each: the release's and the repository's
  `.kit/model/`. It prints each finding, then how many entities and stubs there are, and fails the gate on a finding.
- `kit model table --entity=<name>` and `--domain=<name>` print an entity's fields and a domain's relations as markdown
  tables, for a page that holds them in a `kit:generate` region.
- `kit model svg --domain=<name>` prints a diagram of a domain's entities and the relations between them, with the arity
  at each end, and `kit model svg --overview` a panel for each domain. The same model gives the same bytes.
- `kit model page --domain=<name>` prints the body of a domain's page: its intro, its diagram, its relations, and each
  entity with what it means, its layer, and its fields. The pages of the Git, Git repository, Git configuration, and
  Code domains in `docs/entities/` are written by it, and the gate holds them and their diagrams to the model.

see: [model.md](model.md)

## Extending

- A package extends what kit delivers to a repository. A module extends how kit itself works.
- The verbs share modules, in one directory for each language under `modules/`. A verb loads
  a bash module with `use`. The jq programs that the bash modules run import the jq modules.
- A repository can add a bash module, or override a function, in a directory of its own on the module path.
- Each code forge, tracker, toolchain, dependency provider, artifact source, push target, and policy
  engine sits behind a seam. A seam is one file whose header lists the calls a provider answers, and
  whose code picks the provider at run time. A new provider is a module that answers those calls.

see: [modules.md](modules.md), [architecture.md](architecture.md#code-forges-seams-and-providers)

## Logs and shell completion

- Once kit has hydrated a repository, it logs every kit call, and every message that `kit
  serve` answers, as a line in a daily log under `.kit/logs/`; see [logs.md](logs.md).
- `kit completion zsh` prints zsh completion for the verbs, their
  flags, and their values; see [completion.md](completion.md).

## What no check covers

`kit ci` does not run `kit lint`. A rule's linter, a check such as `pinned`, and a style's templates hold
in CI only where the repository's gate runs `kit lint`. Elsewhere they hold for a commit made with `kit
commit` or through the lefthook hook. A commit made any other way reaches the default branch without them.

Three more claims have no check. Nothing verifies that an agent was asked for the rules of a file: `kit context`
logs each request, and nothing reads the log. Nothing verifies that the forbidden git commands were not used: a deny
list prevents them where the harness has one, and elsewhere the report in the pull request body is all there is.
Nothing verifies that the desk was not changed: `kit work` never switches its branch, and the deny lists refuse raw
git commands that would.

No check verifies that an agent followed a rule after reading it. The linters and the templates
cover the mechanical part, for the kinds of file they handle, where `kit lint` runs. The rest
depends on the report in the pull request body, which the integrity rules in `.kit/1st.md` govern.

see: [architecture.md](architecture.md#what-verifies-what)
