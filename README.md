# empowerite/kit: **k**eep **i**t **t**rustworthy

[![kit CI][ci-badge]][ci] [![release][release-badge]][releases] [![license: MIT][license-badge]](LICENSE)

[ci-badge]: https://github.com/empowerite/kit/actions/workflows/kit-ci.yml/badge.svg?event=pull_request
[ci]: https://github.com/empowerite/kit/actions/workflows/kit-ci.yml
[release-badge]: https://img.shields.io/github/v/release/empowerite/kit?include_prereleases&display_name=release
[releases]: https://github.com/empowerite/kit/releases
[license-badge]: https://img.shields.io/badge/license-MIT-blue

AI coding agents take the same shortcuts people do: they call work done when it is not, skip tests, and rewrite
other people's branches. kit writes down the rules an agent must follow, puts them where each agent reads, and checks
them in CI. It ships as a versioned release that any repository can install and keep up to date.

kit also takes the work from an issue to a merged pull request, with the same few commands wherever the repository
is hosted. kittui, its terminal UI, shows where that work is.

## The terminal UI

Type `kit` at a terminal, and kit opens kittui on the welcome guide. kittui has nine apps, one for each part of the
work. The first is Flow, which follows the work from an issue to a release. This is `kit flow` in a terminal 80
columns wide, drawn from the sample data that kittui's tests use:

```text
  = kit flow · - empowerite/kit                                      🔎 /search
  ➊╶───────────────╮➁╶────────────────╮➂╶───────────────╮➃╶──────────────────╮➄╶
  │ 🎫 issues  7 : │  🔀 changes  3   │  🏭 builds  4   │  🛬 incoming  7    │
  ╵                ╰──────────────────╰─────────────────╰────────────────────╰──
  Issues — What is open, who has it, and where the work on it stands

  ▾ source · organization · repository ▾ 7            📇 Fields  All Issues ▼
    ·────────·──────────────·─────────────
  ▾ github · empowerite 7

      ▸ id   status  assign  age  change  state  where    labels   title
        ·────·───────×·──────·────·───────·──────·────────×·───────·───────────
    ▾ jig 1
      ▸ #7   💤      ada +1  40d                                   🎫 Fix the …
    ▾ kit 6
      ▸ #1   🛫      jeffr…   8d  🔀 #2   🏁     🌿 here  p… +1  🎫 The firs…
      ▸ #8   🛫               2d  🔀 #4   🔥     👤 bob            🎫 Lint the…
      ▸ #8   🛫               2d  🔀 #11  🔨     🌱 loc…           🎫 Lint the…
      ▸ #46  💤      jeffr…   2d                          bug    🎫 A noun l…
      ▸ #31  🛫      ada      3h  🔀 #12  💬     👤 ada            🎫 kit comm…
      ▸ #45  💤               2h                          k… +2  🎫 kit flow…


 = menu - workspace / search ? legend ⌃Q quit │ ⇥·⇧⇥ tab ↓ groups 1-5 jump : ta…
```

To read the screen:

- The first line is the menu bar. Press `=` for the menu of apps, `-` for the menu of workspaces, and `/` to
  search. A workspace is what kit looks at: one repository, or a group of them.
- Each tab is a stage of the work, with a count of its rows. The fifth tab, releases, runs past the right edge
  at this width.
- The rows are the open issues, grouped by repository. 💤 marks an issue in the backlog, and 🛫 one that is
  underway. An issue underway shows its pull request and the state of that pull request.
- The last line names the keys that work now. Press `?` for a legend of every glyph on the screen. `esc` goes
  back one step and never quits. `⌃Q` quits.

Every action also works with a plain click. Beyond Flow:

- The other eight apps are Issues, Changes, Repositories, Delivery, People, Trust, Platform, and Packages. Open
  one from the `=` menu, or run its verb, such as `kit changes`; see [docs/apps.md](docs/apps.md).
- `kit help` lists every verb. Pick one, and kittui opens a form that builds its command line. A verb that you run
  without an argument it needs opens the same form.
- `kit tutorials` teaches the parts of the screen; see [docs/tutorials.md](docs/tutorials.md).

kittui shows only what kit prints. Each screen reads the JSON of a kit command, so a script or an agent can read
the same facts, for example with `kit flow --json`. Without a terminal, such as in a pipe or in CI, kit never opens
kittui, and `kit flow` prints its picture as text.

## What kit does

Checks:

- `kit ci` runs four checks and fails a pull request when any of them fails:
  - `kit gate`: the repository's own gate fails, or it has none.
  - `kit check`: a delivered file differs from the release, or a generated region differs from its command's output.
  - `kit linked`: the pull request is not linked to an open issue.
  - `kit policy`: the branch name, a commit subject, the pull request title, or a file in the tree breaks the
    naming policy.

  The delivered GitHub Actions job runs `kit ci`. Any other pipeline can run it too.
- `kit lint` runs each rule's linter over the files the rule covers. It also refuses a workflow action that is not
  pinned to a full commit SHA. `kit ci` does not run it: `kit commit` and the lefthook hook do, and CI does where
  your gate runs it.

Everything else:

- `.kit/1st.md`, the file every agent reads first, and a rule file for each kind of file that has rules. Style, how a
  file looks, is optional: one style package per kind of file.
- `kit work` turns an issue into a worktree, a linked branch, and a draft pull request.
- kit reaches the code forge, the service that hosts the repository, through the forge's own command-line tool.
  GitHub is supported. GitLab and Azure DevOps are experimental: kit's provider for each is tested against a fake
  built from the tool's documented output, and has not yet run against a live project.
- `kit toolchains` lists the toolchains kit finds. A toolchain supplies the tools a repository's work runs with, such
  as its linters and the tools its gate runs. `kit tools` installs and updates the tools the chosen toolchain pins,
  along with the packages npm or uv pins, and runs commands with them. kit supports these toolchains; see
  [docs/toolchains.md](docs/toolchains.md):
  - [kit's own](docs/toolchains/using-kit.md), with `tools:` in `kit.yml`
  - [mise](docs/toolchains/using-mise.md)
  - [Nix](docs/toolchains/using-nix.md), with flakes
  - [Homebrew](docs/toolchains/using-brew.md), with a Brewfile
  - [a Docker image](docs/toolchains/using-docker.md)
  - [a dev container](docs/toolchains/using-devcontainer.md)
  - [apt, dnf, or pacman](docs/toolchains/using-system-packages.md)
  - [none](docs/toolchains/using-no-toolchain.md): the tools already on the machine
- `kit flow` shows where work stands in five stages: issues, changes, builds, incoming, and releases.
- `kit workspace` shows what git holds across a workspace: remotes, branches, worktrees, commits, and tags.
- Adapters for Claude Code, Cursor, GitHub Copilot, and Gemini CLI put the rules where each one looks. The Claude
  Code and Gemini CLI adapters also deny raw git commands the rules forbid, such as `git rebase`. The deny list
  matches literal patterns, so `git -C <dir> commit` and `git merge` get through.
- A rule that agents never change the desk: the main checkout on your machine, whatever branch it is on.

Only CI, through `kit ci`, holds every agent to the rules. It runs on pull requests into the default branch, and it
blocks a merge only when a branch ruleset requires its check. kit does not ship a ruleset. An adapter's deny list
and hooks work only in that agent.

A repository keeps its own rules next to the ones kit delivers. The design is in
[#1](https://github.com/empowerite/kit/issues/1) and [#4](https://github.com/empowerite/kit/issues/4).

## Why a release, and not a copy

A copied file drifts. A release does not:

- It is pinned, so a repository knows which version of the rules applies.
- A pull request that bumps the version updates it, so every repository gets a change the same way.
- `kit check` fails the build when someone edits a delivered file in place.

Updates leave a repository's own files alone. To change a file kit adds, remove the package that adds it, or replace
the file with a package of your own. `.kit/1st.md` explains how, under "Changing what kit adds".

## Install

macOS and Linux, by download. Set `version` to the release you want: a stable one, such as `0.1.0`, or a release
candidate, such as `0.1.0-rc.7`. The [releases](https://github.com/empowerite/kit/releases) page lists both, and
until the first stable release is out, only release candidates:

```sh
version=0.1.0
release="https://github.com/empowerite/kit/releases/download/release/${version}"
curl --fail --location --output "kit-${version}.tar.gz" "${release}/kit-${version}.tar.gz"
curl --fail --location --output "kit-${version}.tar.gz.sha256" "${release}/kit-${version}.tar.gz.sha256"
shasum --algorithm 256 --check "kit-${version}.tar.gz.sha256" &&
  mkdir -p "${HOME}/.local/share" "${HOME}/.local/bin" &&
  tar --extract --gzip --file "kit-${version}.tar.gz" --directory "${HOME}/.local/share" &&
  ln -s -f "${HOME}/.local/share/kit-${version}/bin/kit" "${HOME}/.local/bin/kit"
```

`shasum` checks the tarball against the digest published beside it, and the lines after it run only when the two
match. The release unpacks as `~/.local/share/kit-<version>/`, and `~/.local/bin/kit` is a link to its loader. Put
`~/.local/bin` on your `PATH` if it is not there.

Windows: kit runs in Windows Subsystem for Linux (WSL). Run `wsl --install` in PowerShell, then run the lines above
inside WSL.

Check it with `kit version` and `kit help`.

With Homebrew, which carries stable releases only: `brew trust empowerite/tap-poc`, then
`brew install empowerite/tap-poc/kit`. Other ways to install, such as mise or a download with `gh`, are in
[docs/install.md](docs/install.md). That page also lists what kit needs on the machine, which the download does not
bring (bash 4.4 or later, git, `jq`, `yq`, and the linters), how kit picks which release to run, and how
and how `kit trust --clone` works.

New to a repository that uses kit? Run `kit trust --clone`, then `kit welcome`. `kit welcome` checks your tools, your code
forge logins, and the repository, and shows how to fix each problem. Then it explains how work flows, the terms, and
what a team can change. It also names terminal settings that make kittui slower or worse; see
[docs/terminals.md](docs/terminals.md), and [docs/kittui-needs.md](docs/kittui-needs.md) says what kittui needs of the
terminal, the font, and the colors. `kit tutorials` lists the tutorials and opens one; see
[docs/tutorials.md](docs/tutorials.md).

## Take the kit

1. Run `kit install` with the packages you want. With no names, it installs the `kit` package: the entry file and
   the rules. That alone sends no agent to the entry file: an `agents/<harness>` package does, and until one is
   active the last line of `kit install` says so and names the command that adds one. `kit packages remove kit`
   removes the `kit` package once no other active package depends on it, and lists it under `excludes:` so
   `kit update` leaves it out. The optional packages are:

   | Package | Delivers |
   | --- | --- |
   | `workflow` | `.kit/workflow.md`: the workflow from an issue to a merged pull request, plans as prose, and the worker contract |
   | `github/ci` | the GitHub Actions workflow that runs `kit ci` |
   | `hooks/lefthook` | a pre-commit hook that runs `kit lint` and `kit generate --check` |
   | `agents/generic` | for any agent that reads `AGENTS.md`: a region there that sends it to `.kit/1st.md` |
   | `agents/claude` | the Claude Code adapter |
   | `agents/cursor` | the Cursor adapter: one rule under `.cursor/rules/` per kit rule, attached by that rule's paths |
   | `agents/copilot` | the GitHub Copilot adapter: one instruction file under `.github/instructions/` per kit rule |
   | `agents/gemini` | the Gemini CLI adapter: `AGENTS.md` among its context files, and the deny list, in `.gemini/settings.json` |
   | `policy/opa` | the naming policy as Open Policy Agent rules |
   | `policy/conventional` | commit subjects and pull request titles held to Conventional Commits, the issue in a `Refs:` trailer |
   | `style/<kind>` | the style for one kind of file, with its templates: `style/bash`, `style/markdown`, `style/just`, `style/workflows`, `style/yaml`, `style/json`, `style/gitignore` |
   | `style/prose` | the style of prose in every text file, documents and comments alike |
   | `empowerite` | the bundle Empowerite's repositories take: every `style/<kind>`, `github/ci`, `agents/claude`, `hooks/lefthook`, and `workflow` |

   For example, `kit install github/ci hooks/lefthook agents/claude`. A team on Cursor adds `agents/cursor`.
   `kit packages add` adds one later. `kit install empowerite` takes the bundle, and you can remove any member of
   it on its own.

   `kit install` adds `/worktrees/` to `.gitignore`. Every `agents/<harness>` package, through `agents/generic`,
   writes a short region into `AGENTS.md` that sends every agent to `.kit/1st.md`. Each region starts at a line
   with `kit:generate` and ends at a line with `kit:end`, and the rest of the file is yours. The `.gitignore` region
   can sit anywhere; the `AGENTS.md` and `.claude/CLAUDE.md` regions sit where their host template puts them.
   `kit generate` rewrites a region from its command, and `kit check` fails when one is out of date. Your own files
   can hold regions too; see [docs/generate.md](docs/generate.md).
2. Commit what `kit install` wrote. Run `kit commit` on a branch that is not the default one; it refuses the
   default branch, and the Claude Code and Gemini CLI adapters deny an agent `git commit`. Or start an issue with
   `kit work`, which at a terminal moves the uncommitted work into the new worktree, and commit there.
3. Give the repository a gate, the command CI runs. kit takes the first of these it finds:
   - a `gate` command in `kit.yml`
   - a `ci` recipe in the root justfile
   - a `ci` target in a Makefile
   - a `ci` script in `package.json`

   `kit ci` fails when there is no gate. The gate runs with the tools your toolchain manages; see
   [docs/toolchains.md](docs/toolchains.md). The naming policy is in [docs/policy.md](docs/policy.md).
4. Run the linters before each commit. `kit lint` lints the staged files and needs no hook manager. To run it from
   lefthook instead:
   - pin `lefthook`,
   - add `extends: [.kit/lefthook.yml]` to `lefthook.yml`, and
   - run `kit hydrate && lefthook install` once per clone. lefthook silently skips a missing `.kit/lefthook.yml`,
     and `git commit --no-verify` skips the hook.

   With the `hooks/lefthook` package installed, `kit check` fails until `lefthook.yml` has that `extends` line. kit
   never writes it for you.

Claude Code reads `AGENTS.md` only when there is no `CLAUDE.md`. So the `agents/claude` package adds a region to
`.claude/CLAUDE.md` that imports `AGENTS.md`, and Claude reads what every other agent reads. The rest of
`.claude/CLAUDE.md` is yours.

`kit packages` lists the packages. `kit packages add` and `kit packages remove` change which are active. The package
format is in [docs/packages.md](docs/packages.md).

kit works with no packages at all. The workflow verbs, such as `kit flow`, `kit work`, `kit commit`, `kit submit`,
and `kit release`, run without any. So do the checks that read `kit.yml`: `kit gate`, `kit policy`, and
`kit check`. Kinds, rules, and templates come from the `kit` package. Without it, `kit context` names no rule,
`kit kinds` lists no kind, `kit lint` covers no file, and `kit new file` refuses because there is no template.

Once kit has hydrated a repository, every kit call and every message `kit serve` answers is a line in a daily log
under `.kit/logs/`; see [docs/logs.md](docs/logs.md).

`kit completion zsh` prints zsh completion for the verbs, their flags, and their values; see
[docs/completion.md](docs/completion.md).

### Working with the rules

- Before an agent changes a file, it runs `kit context "${path}"` to find the rules that apply. The `agents/claude`
  package makes this call automatically through a Claude Code hook; see [docs/context.md](docs/context.md).
- `kit serve` offers the rules and the verbs to any agent over the Model Context Protocol (MCP), in three groups:
  - read only: `context`, `flow`, `help`, `kinds`, `packages`, `syntax`, and `version`
  - run what the repository's files name: `check`, `lint`, `toolchains`, and `tools`
  - act on issues and pull requests: `assign`, `close`, `gather`, `settle`, `unassign`, and `work`

  Each `agents/<harness>` package registers it with its agent; see [docs/serve.md](docs/serve.md).
- `kit new file "${path}"` creates a file from its style's template, and `kit lint` checks that every file keeps the
  shape of its template; see [docs/templates.md](docs/templates.md).

### Updating

Run the release you want to move to. It updates the repository and writes its version into `kit.yml`:

```sh
kit --version=0.2.0 update
```

For each file:

- A delivered file you never edited is replaced.
- A delivered file you edited is merged three ways, with the previous release as the base. `kit update` downloads
  the previous release from GitHub when it is not on the machine. Where it cannot, set `KIT_BASE` to a copy of it.
- Where the release brings no change to a file, there is nothing to merge. A `kit update` at the same version is
  such a case. A file that differs from what kit placed stays, and `kit update` names it. To take the release's
  file, for example after you change an answer in `kit.yml`, move the file aside or remove it, then run
  `kit update` again.
- Your own deny list entries and settings keys are kept.

`kit uninstall` removes everything kit placed. Add `--dry-run` to see what it would remove first. Your own files,
your own packages under `.kit/packages/`, and any delivered file you edited stay.

## Working on kit

This repository is kit's own source, and it also uses kit. [CONTRIBUTING.md](CONTRIBUTING.md) is the page for
people and agents who change kit itself: the setup, the workflow, the layout, the tests, and how a release is made.
