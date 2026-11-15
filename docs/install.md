# Install

The README gives the install by download. This page has it again with the other ways to install kit, the
toolchains that install a repository's tools, what kit needs on the machine, how kit picks which release to run, and
how trust works.

## What a release is

A release is a tarball with `bin/`, `modules/`, `packages/`, `libexec/` (the loader's helper and the `kittui`
binaries that `kit tui` runs), and a `version` file. Install one release on your machine, the way you install your
other tools.

The `kit` you install is a loader. In each repository it runs the release that repository asks for, so one installed
kit serves every repository, whatever release each one pins.

## Ways to install

### By download

On macOS, Linux, or Windows Subsystem for Linux (WSL). A stable release is named by a version such as `0.1.0`, and a
release candidate by one with a suffix, such as `0.1.0-rc.7`. The [releases](https://github.com/empowerite/kit/releases)
page lists both. With `gh`, set `version` to the newest of either kind:

```sh
# stable
version=$(gh release list --repo empowerite/kit --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("release/")')
# or the newest release candidate
version=$(gh release list --repo empowerite/kit --limit 20 --json tagName,isPrerelease --jq '[.[] | select(.isPrerelease)][0].tagName | ltrimstr("release/")')
```

Without `gh`, set it by hand, as `version=0.1.0`. Until the first stable release is out, the stable line finds nothing;
use a release candidate. Then:

```sh
release="https://github.com/empowerite/kit/releases/download/release/${version}"
curl --fail --location --output "kit-${version}.tar.gz" "${release}/kit-${version}.tar.gz"
curl --fail --location --output "kit-${version}.tar.gz.sha256" "${release}/kit-${version}.tar.gz.sha256"
shasum --algorithm 256 --check "kit-${version}.tar.gz.sha256" &&
  mkdir -p "${HOME}/.local/share" "${HOME}/.local/bin" &&
  tar --extract --gzip --file "kit-${version}.tar.gz" --directory "${HOME}/.local/share" &&
  ln -s -f "${HOME}/.local/share/kit-${version}/bin/kit" "${HOME}/.local/bin/kit"
```

- The two `curl` lines download the release's tarball and the `.sha256` published beside it. With `gh`,
  `gh release download "release/${version}" --repo empowerite/kit` downloads the same two files in their place.
- `shasum` checks the tarball against that digest, and the lines after it run only when the two match, so a tarball
  with other bytes is never unpacked. On a Linux machine with no `shasum`, `sha256sum --check` reads the same file.
- The tarball holds one directory, `kit-<version>/`, which lands in `~/.local/share/`, and `~/.local/bin/kit` is a
  link to its loader. Put `~/.local/bin` on your `PATH` if it is not there.
- The download brings kit alone. [Requirements](#requirements) lists what kit needs beside it.

To move to a later release, run the lines again with its version. The earlier release stays in `~/.local/share/`
until you remove it.

### Homebrew

On macOS or Linux, from the [empowerite tap](https://github.com/empowerite/homebrew-tap):

```sh
brew trust empowerite/tap
brew install empowerite/tap/kit      # stable
brew install empowerite/tap/kit-rc   # or the newest release candidate
```

Until you trust the tap, Homebrew refuses to load any of its formulae, so `brew trust` comes first. The two install
the same command, so only one can be installed at a time; to change channels, `brew uninstall` one and install the
other. `brew upgrade` stays on the channel you chose. Until the first stable release is out, there is only `kit-rc`.
The formulae bring bash, jq, and yq, and keep the one kittui for your machine; see
[using-brew.md](toolchains/using-brew.md#installing-kit-with-brew).

### mise

Add kit as a tool in your own `~/.config/mise/config.toml`:

```toml
[tools]
"github:empowerite/kit" = { version = "0.1.0", version_prefix = "release/" }
```

mise downloads the release's tarball itself, and puts its `bin/` on `PATH`. Name a stable release as `0.1.0` or a
release candidate as `0.1.0-rc.7`; mise's `latest` is the newest stable release, never a candidate.

### Windows

kit runs on Linux and macOS. On Windows, use WSL, which runs it as Linux. Install WSL with `wsl --install` in
PowerShell, then use any of the ways above inside it.

## Toolchains

Installing kit and installing a repository's tools are separate steps. The ways above install kit. A toolchain
installs the tools a repository's work runs with, such as its linters and the tools its gate runs. `kit toolchains`
lists the toolchains kit finds, and `kit tools install` installs what the chosen one pins. kit supports these
toolchains; see [toolchains.md](toolchains.md):

- [kit's own](toolchains/using-kit.md), with `tools:` in `kit.yml`
- [mise](toolchains/using-mise.md)
- [Nix](toolchains/using-nix.md), with flakes
- [Homebrew](toolchains/using-brew.md), with a Brewfile
- [a Docker image](toolchains/using-docker.md)
- [a dev container](toolchains/using-devcontainer.md)
- [apt, dnf, or pacman](toolchains/using-system-packages.md)
- [none](toolchains/using-no-toolchain.md): the tools already on the machine

## Check the install

- `kit version` prints the release.
- `kit help` lists the verbs.
- In a repository that has taken the kit, `kit check` says whether every delivered file matches the release.

## Requirements

- bash 4.4 or later. macOS ships bash 3.2; run `brew install bash`.
- git 2.31 or later.
- `jq` 1.7 or later. Every verb reads its arguments through it.
- `yq` 4, mikefarah's. It reads `kit.yml` and every other YAML file. GitHub's hosted runners have `jq` and `yq`
  already.
- `curl` and `tar`. The loader uses them to download a pinned release, and `kit update` to download the previous
  release for a three-way merge when it is not cached. Each download is checked against the `.sha256` published
  beside the release before kit reads anything in it.
- The linters the delivered rules and styles run. `kit lint` fails, rather than skips, when one is missing, so a team
  needs them before its first commit:
  - `shellcheck`, for the bash rule
  - `actionlint`, for the workflows rule
  - `markdownlint-cli2`, for the markdown style, with the `style/markdown` package
- The code forge's command-line tool. The code forge is the service that hosts the repository. GitHub, through `gh`,
  is supported. GitLab, through `glab`, and Azure DevOps, through `az` with its `azure-devops` extension, are
  experimental: kit's provider for each is tested against a fake built from the tool's documented output, and has
  not yet run against a live project. These verbs need the tool: `kit work`, `kit assign`, `kit unassign`,
  `kit close`, `kit gather`, `kit settle`, `kit flow`, `kit tidy`, `kit linked`, and `kit release`. `kit commit`
  uses it to close an issue its subject names, and `kit policy` uses it in CI to read the pull request.
- For an Azure DevOps tracker beside another code forge: `az`, the Azure CLI, with its `azure-devops` extension.

kit checks bash each time it starts. It finds a missing git, jq, or yq only when it first runs that tool.
`kit welcome` checks all four at once.

## Which release runs

kit uses the first of these that is set:

1. `kit --version=<release> …`, for this call and every kit call it makes in the same clone.
2. `KIT_VERSION=<release>` in the environment, which does the same.
3. `version:` in the `kit.yml` at the root of the clone you are in. Each worktree is its own root. The loader reads
   the first line that starts with `version:`, so write the release on one plain line, from the first column, as
   `version: 0.1.0`. A verb that reads the release refuses a `kit.yml` in which yq finds another version than that
   line gives, such as one under a key in quotes.
4. The kit you installed. This applies outside a clone, and in a clone that pins no version.

A release is named by its version, such as `0.1.0`. `--version=` and `KIT_VERSION` also take the path of a copy of a
release.

The loader keeps every release it runs in `~/.cache/kit/`. It downloads a version the first time a repository asks
for it, and checks it against the `.sha256` published beside it.

The loader refuses a kit option it does not know. A later kit may know it, so update the kit you installed.

## Trust

kit runs nothing in a clone until you trust it.

- `kit trust --clone` shows what the clone asks kit to run: its pinned release, the bash it loads, its gate, the
  sources and tools it downloads, and the `lint:` command of each rule and style. Then it asks you, and remembers your
  answer for the clone and all its worktrees, with a digest of what it asks.
- The release it shows is the one the loader runs: the first `version:` line of `kit.yml`, or else the version
  `.kit/manifest` records. `version: unreleased` names the clone's own `kit/`, and
  `kit trust --clone` shows it whether or not the clone holds a `kit/` yet.
- In a terminal, the first kit command in a clone you have not trusted asks the same question, and runs after a yes.
  Bare `kit` and `kit tui` open kittui, which asks in a dialog before it reads anything: Trust, or Not now, which
  leaves the clone untrusted and opens the help palette. A plain click takes either. `kit syntax`, which the palette
  reads, runs in an untrusted clone too, on the kit you installed.
- An agent's harness runs two commands with no terminal: `kit serve`, and the hook, `kit context --claude`. In a
  clone you have not trusted each says so in the form the harness reads, an MCP error and the hook's JSON: the
  trust is yours to give, and the command is `kit trust --clone`. Neither reads anything of the clone or trusts it, and
  the server answers from the clone once you have trusted it.
- A pull that changes what the clone asks, such as a new gate or a new `lint:` command, withdraws the trust, and kit
  asks again. A pull that changes only the code those name keeps it, and so does what kit writes itself, such as the
  files it places under `.kit/` and the version `kit update` moves.
- `kit trust --clone ~/Code/` trusts every clone under that folder, whatever each one asks.
- Outside a clone, a folder that holds a `kit.yml` is held to the same trust, by its own path. An unpacked archive
  of a repository is such a folder. Until you trust it, kit reads no `bash_path` there and runs nothing its `kit.yml`
  names. kit reads `kit.yml` only in the folder you type in, so a folder below it is asked nothing, and neither is
  a folder with no `kit.yml`.
- Where there is no `kit.yml`, kit reads the `.kit/settings.yml` an earlier release kept, and moves it to `kit.yml`.
  The trust judges that file, and `kit trust --clone` shows what it names, before anything moves: a pull that brings one
  withdraws the trust, and the move itself keeps it. The loader reads the release it pins the same way. A `kit.yml`
  that is a link to nothing stops the move, since kit writes nothing through a link; remove it first.
- `kit trust --clone --list` and `kit trust --clone --revoke` read and change the records, which are plain lines in
  `~/.config/kit/trusted`. `kit trust --clone --check` and `kit trust --clone --asks` answer a screen that asks for the
  trust itself.

Trusting a clone means you accept code from anyone who can push to it. kit does not check each pull; code review and
signed commits do.

In a clone you have not trusted, every git command kit runs ignores the clone's hooks and fsmonitor, and reaches no
remote. kit works in the clone's root as the file system gives it, the nearest folder at or above you that holds
`.git`, which is the root it judged. It never takes the root from git, since a clone's own git config can name any
folder as its work tree. That holds in a clone you trust too. Where no folder at or above you holds `.git`, kit
stays in the folder you typed in.

kit never trusts a toolchain's own config for you: when `mise install` refuses a `mise.toml` mise does not trust, kit
names `mise trust` as the step you take once you have read the file. kit neither writes nor removes a path through a
link under `.kit/`, and writes no log through one.
