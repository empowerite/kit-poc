# Contributing to kit

This page is for people and agents who change kit itself. This repository is kit's own source, and it also uses
kit. To use kit in a repository of your own, read the [README](README.md).

## Setup

Tools come from the kit toolchain: `tools:` in `kit.yml` pins them, and direnv puts them on `PATH` through the
`.envrc`. Every commit must be signed, because the branch ruleset rejects unsigned commits. If you have no signing
key that GitHub verifies, create and register one:

- [generating a new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
- [adding a GPG key to your GitHub account](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account)

Then, once per clone, with the key's id in `signing_key`:

```sh
git config gpg.format openpgp
git config user.signingkey "${signing_key}"
git config commit.gpgsign true
brew bundle install
kit/bin/kit trust
direnv allow
kit/bin/kit toolchains use kit
kit tools install
kit hydrate && lefthook install
kit welcome
```

`kit trust` shows what this clone asks kit to run and records your answer. Run it before `direnv allow`: the
`.envrc` calls kit, and kit refuses to run anything in a clone you have not trusted, so without the trust direnv puts
no tool on `PATH`.

`kit tools install` puts each tool that `tools.lock` pins for this platform under `~/.kit/tools/`, where every clone
and worktree shares it. On a desk, the main checkout on your machine, it also installs lefthook, which `kit.yml`
limits to desks. A runner, where `CI` is set, skips lefthook. See
[using kit as the toolchain](docs/toolchains/using-kit.md).

## The workflow

Work here follows the workflow that the `workflow` package delivers as `.kit/workflow.md`; its source is
[workflow.md](kit/packages/workflow/files/repo/.kit/workflow.md).

1. Start from an issue. A change without an issue has not started.
2. Run `kit work <N>`. It creates `worktrees/<N>-<slug>`, links the branch to the issue under Development, and opens
   a draft pull request. It never switches the branch of the checkout you run it from. For an issue in another
   tracker, use that tracker's reference, such as `kit work AB#4521` for an Azure DevOps work item; see
   [docs/trackers.md](docs/trackers.md).
3. Work in that worktree. Commits are signed. Each commit subject starts with its issue's reference, such as
   `#<N> <subject>`, and the policy checks it.
   - `kit commit` commits what is staged. First it runs the linters and the policy, and checks that nothing kit
     placed is in the commit.
   - `kit submit` pushes the branch and commits nothing. `kit rebase` rebases the branch onto `main` and pushes it.
   - `kit flow` shows where work stands. `kit flow <stage>` prints one stage.
4. Run the gate, `kit gate`. It runs `bin/ci`, which lists what it checks.
5. When the work is done, mark the pull request ready for review with its report:
   `kit ready --report-file=<path>`, on any forge. The pull request body is the report, and `kit ready` writes it
   there above the `Closes` lines.
6. A person merges the pull request. Then `kit tidy` removes the worktree and its branch.

## Layout

| Directory | Contents |
| --- | --- |
| `kit/` | the release: everything in it ships |
| `kit/bin/` | the kit CLI, `kit`, and its verbs |
| `kit/libexec/` | `kit-call`, the bash that the loader runs |
| `kit/modules/` | the modules the verbs share, `bash/` and `jq/`, and the tutorials that ship with kit |
| `kit/packages/` | everything a release delivers to a repository |
| `bin/` | this repository's own commands, which are not on `PATH` |
| `docs/` | the documentation, with the packages' pages under `docs/packages/` |
| `projects/tui/` | kittui, the terminal UI, in Go |
| `projects/tutorials/` | the tutorials site |
| `tests/` | the bats suite |

The release tarball is `kit/` with two additions: a generated `version` file, and the `kittui` binaries in
`libexec/`, built from `projects/tui/`.

The commands in `bin/` are:

- `bin/ci`, the gate
- `bin/refresh`, which writes the installed copies
- `bin/release`, which packs and publishes a release
- `bin/tutorials`, which writes the catalogue of the tutorials and publishes their site
- `bin/contracts`, which writes the snapshots of kit's public surface

Three pages describe the design:

- [docs/architecture.md](docs/architecture.md): how the pieces fit, with diagrams
- [docs/packages.md](docs/packages.md): the package format
- [docs/modules.md](docs/modules.md): the bash and jq modules the verbs are built on, and how a repository extends
  them

kittui has a page of its own, [projects/tui/README.md](projects/tui/README.md).

## Installed copies

This repository installs its own kit. What kit places under `.kit/` is a link into the package that delivers it. The
link is live and git ignores it, so an edit through the link edits the source. `bin/refresh` writes the installed
copies outside `.kit/` by running `kit update` from the index. Do not edit those copies by hand.

| Installed copy | Written from |
| --- | --- |
| `.kit/1st.md`, `.kit/README.md`, `.kit/kinds/`, `.kit/rules/`, `.kit/kit.schema.json` | links into `kit/packages/kit/files/repo/.kit/` |
| `.kit/styles/<kind>.md`, `.kit/templates/<kind>/`, `.kit/markdownlint.jsonc` | links into `kit/packages/style/<kind>/files/repo/.kit/` |
| `.kit/templates/bash/`, `.kit/templates/gitignore/file`, `.kit/templates/just/` | links into `.kit/packages/house/files/repo/.kit/templates/` |
| `.kit/styles/house.md` | a link into `.kit/packages/house/files/repo/.kit/styles/` |
| `.kit/lefthook.yml` | a link into `kit/packages/hooks/lefthook/files/repo/.kit/` |
| `.kit/policy/kit.rego` | a link into `kit/packages/policy/opa/files/repo/.kit/policy/` |
| `.kit/policy/house.rego` | a link into `.kit/packages/house/files/repo/.kit/policy/` |
| `.github/workflows/kit-ci.yml` | `kit/packages/github/ci/templates/repo/.github/workflows/kit-ci.yml` |
| `.claude/CLAUDE.md` | `kit/packages/agents/claude/regions/repo/.claude/CLAUDE.md`, a region |
| `.claude/settings.json` | `kit/packages/agents/claude/files/repo/.claude/settings.json`, merged by key |
| `.mcp.json` | `kit/packages/agents/claude/files/repo/.mcp.json` and `.kit/packages/house/files/repo/.mcp.json`, merged by key |
| `AGENTS.md` | `kit/packages/agents/generic/regions/repo/AGENTS.md`, a region |
| `.gitignore` | `kit/packages/kit/regions/repo/.gitignore`, a region |
| `.kit/.gitignore`, `.kit/manifest` | kit itself, beside what it placed under `.kit/` |

Notes on the table:

- The house package, `.kit/packages/house/`, is this repository's own style. Its templates replace the style
  packages' templates, and `house.md` adds to their styles.
- The workflow is the template with `ci_runner`, `ci_timeout_minutes`, and `ci_toolchain` filled in.
- Outside a region, the file belongs to this repository. `.claude/settings.json` holds only kit's entries here.
- `.kit/.gitignore` lists the paths git never sees, and `.kit/manifest` holds a digest for each delivered path.
  git ignores both. `kit.yml` declares the release version, which is `unreleased` here, and the active packages.

`kit.yml` belongs to this repository and is not delivered. kit writes only its `version`, `packages`, and `excludes`
keys. kit moves a `.kit/settings.yml` from an earlier release into `kit.yml` whole, once. A fresh clone or worktree
has nothing else under `.kit/` until a kit verb runs, or until `cd` hydrates it through the `.envrc`.

When a commit changes a file under `kit/` or `.kit/packages/`, or changes `kit.yml`, the installed copies must change
in the same commit:

- With the pre-commit hook installed, this happens on its own. The hook runs `bin/refresh`, which regenerates the
  copies from the index and stages them.
- Without the hook, stage your change, run `bin/refresh`, and commit.

`kit/bin/kit check`, which the gate runs, names any installed copy that does not match its source. Every delivered
file except a template says in its header that kit delivered it. A region's `kit:generate` line is its notice, and
the table above is the notice for `settings.json`.

## Testing

`kit gate` runs the suite the way `bin/ci` does: bats, one job per CPU, on GNU parallel from `kit.yml`. To run one
file, use `kit tools run bats tests/<file>.bats`, which puts the pinned tools first on `PATH`.

Most of the suite's time goes to starting short processes: bash, jq, yq, and git. macOS starts processes more slowly
than Linux, so a test takes 1.5 to 2.4 times as long on a Mac as on a runner. On a Mac, list the terminal and the
editor you run tests from as developer tools. That saves up to about 5 percent of a run.
[docs/testing.md](docs/testing.md) has the numbers, the time limits, and the steps.

kittui's tests are Go tests; see [Testing](projects/tui/README.md#testing) in its page.

## Release

- A release is the tag `release/<version>` on any commit on `main`, not only the latest one.
- A pre-release is `release/<version>-<suffix>`, such as `release/0.1.0-rc.1`, on any commit, on `main` or off it.
  It is published as a GitHub pre-release.
- The tag is the version. The repository has no version file. The release workflow writes the part after `release/`
  into the packed kit and names the release after it.
- Published releases cannot change, so a tag is never reused.

`kit release <version>` checks these rules, then makes the tag and pushes only the tag. It has two more rules:

- A version that is not higher than every release on the primary remote needs `--lower`.
- A release of a commit behind `main` at the primary remote needs `--behind`. A desk that has not pulled since a
  merge is behind in this way.

`kit release <version> --dry-run` checks the rules and tags nothing. It prints the commit, the tag, and what the
push would send. `kit flow releases` lists what the code forge published.

The release workflow runs three commands:

1. `bin/release verify` rejects a tag that is not `release/<version>`, and a release tag on a commit not on `main`.
2. `bin/release publish` packs `kit/`, a `version` file, and the `kittui` binaries into `kit-<version>.tar.gz`. It
   builds `kittui` from `projects/tui/` for Linux and macOS on amd64 and arm64, and puts the binaries in `libexec/`.
   It publishes the tarball with a `.sha256` file that holds the tarball's digest.
3. `bin/release fetch` downloads the published release as any machine does, through the loader, checks it against
   that digest, and runs `kit version` in it. A release that cannot be fetched fails the run.

`bin/release pack` builds the same tarball locally, from what the tag's commit holds and not the files on disk, so
the tag comes first. `bin/release publish` creates the release for a tag that exists and never makes one. It
refuses to publish a release anywhere but the CI runner, so only the workflow publishes releases. A pre-release can
be published from a developer machine.

A release is permanent. A pre-release is deleted, tag and all, once no branch contains its commit, which happens when
the branch it was tagged on is deleted. A pre-release on `main` stays.

The branch ruleset is managed in [empowerite/infrastructure](https://github.com/empowerite/infrastructure).

### The tutorials site

The tutorials workflow publishes the site that `kit tutorials` opens. GitHub Pages serves the `gh-pages` branch, and
each copy of the site is one directory of it:

| Push | Directory | Which kit opens it |
| --- | --- | --- |
| to `main` | `tutorials/main/` | a checkout of this repository |
| of the tag `release/X.Y.Z` | `tutorials/X.Y/` | every `X.Y` release |
| of the tag `release/X.Y.Z-<suffix>` | `tutorials/X.Y.Z-<suffix>/` | that pre-release |

- `bin/tutorials site` names the copy a ref builds, at the address `kit tutorials` opens.
- The build runs with a token that only reads. `bin/tutorials publish` then replaces the copy's directory in one
  commit and pushes it. It refuses to run anywhere but the CI runner, so only the workflow publishes the site.
- `bin/tutorials answers` then requests the copy's address, and the run fails when the address does not answer.
- A pre-release's copy is removed once its tag is deleted.

An owner turns Pages on once, in the repository's settings; see
[Publishing](projects/tutorials/README.md#publishing).
