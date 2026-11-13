# The github/ci package

Delivers `.github/workflows/kit-ci.yml`: one GitHub Actions job, `CI`, that runs for each pull request into the
default branch. The job:

1. Fetches the full history, which `kit policy` reads.
2. Puts `kit` on `PATH`. Where the target branch's `kit.yml` declares `unreleased`, it uses the kit's own checkout.
   Where the runner already has a `kit` on `PATH`, it uses that one, whatever its version. Otherwise it downloads the
   release the target branch's `kit.yml` declares, never the change's, with the `.sha256` published beside it, and
   unpacks the tarball only when its bytes have that digest. It sets `KIT_VERSION` to that release, so kit does not
   choose another by the change's `kit.yml`. The first pull request of a repository, whose target has no `kit.yml`,
   declares its own.
3. Runs `kit ci`, which runs `kit linked` and `kit policy`, then, on a runner, installs the gate's tools with
   `kit tools install`, through the toolchain `ci_toolchain` names: kit itself, mise, nix, Homebrew, a Docker image, a
   dev container, or the tools already on the runner. Then it runs the gate, the repository's own CI command such as
   `just ci`, and `kit check`, with those tools first on `PATH`, and reports each result.

The job installs nothing and puts nothing on `PATH` before the two judgements, and it has no `kit tools` step. So
when they judge, no install script of the branch, as npm's `postinstall`, has run, and no `node_modules/.bin` is on
`PATH`. On a runner the opa engine is the one the target's `tools.lock` pins, installed new for the run.
[policy.md](../../policy.md#what-judges-a-branch) says what that covers and what it leaves open.

The pull request's own workflow file runs: on a `pull_request` event GitHub takes the workflow from the pull request's
merge commit, from a fork's too. The job asks for no more permission than before (`contents`, `issues`, and
`pull-requests`, read), and a fork's pull request gets a read-only token and no secrets. Do not move the job to
`pull_request_target` to get write access: it runs the base's workflow with secrets, and `kit ci` would then run the
fork's code, the gate, with them. Only `Settle` runs on `pull_request_target`, because it runs none of the change's
code.

GitHub's hosted runners already have Homebrew and Docker. The job sets `KIT_TOOLCHAIN` to the `ci_toolchain` answer, so
kit uses that toolchain and refuses, never replaces, one the runner cannot use. One bootstrap step runs for the
toolchain named, and none for the others:

| `ci_toolchain` | Step | What it does |
| --- | --- | --- |
| `kit` | `kit-tools-cache` | `actions/cache`, pinned by commit, keeps `~/.kit/tools` between runs while `tools.lock` is as it was |
| `mise` | `mise-on-path` | `jdx/mise-action`, pinned by commit, with its own install turned off |
| `nix` | `nix-on-path` | `DeterminateSystems/nix-installer-action`, pinned by commit |
| `devcontainer` | `devcontainer-on-path` | `npm install --global @devcontainers/cli`, exact version; needs npm |
| `brew`, `docker`, `ambient` | none | the runner already has them, or the tools are on `PATH` |

The job needs `jq` and `yq` on the runner, which the hosted runners have; a runner of the repository's own needs both.

When a pull request closes, a second job, `Settle`, which runs on `pull_request_target` so that a fork's or
Dependabot's pull request gets a token that can write and the secrets, puts `kit` on `PATH` the same way and runs `kit
settle` on it. An issue in another tracker that a merged pull request's body closes (`Closes AB#4521`) is closed with
a comment naming the merge commit; the issues of a pull request closed without merging get a comment and lose its
author, so they are backlog again. `Settle` alone may write to issues. For an Azure DevOps tracker it reads the
repository's `AZURE_DEVOPS_EXT_PAT` secret, which `az` takes as its token.

A repository on another CI system calls `kit ci` from its own pipeline, with nothing of the change's installed before
it; on a runner `kit ci` installs the tools after the two judgements.

The workflow is a template with three keys, all under `answers:` in `kit.yml`:

- `ci_runner` is the label of the runner the job runs on. The default is `ubuntu-latest`. A repository with its own
  runners sets it.
- `ci_timeout_minutes` is how long the job may run before GitHub stops it and fails it. The default is `"30"`.
  Without it, a hung step runs for GitHub's limit of six hours. Set it to about twice a usual run, in quotes:
  `ci_timeout_minutes: "20"`. This repository sets `"35"`.
- `ci_toolchain` is the toolchain the job installs with. The default is `ambient`: kit does not install anything.
  `kit ci` then fails when it installs the change's tools, after the two judgements, naming each tool the rules need
  that is missing, unless the runner already has them. To have CI install the tools, name a toolchain, such as
  `ci_toolchain: kit`, `mise`, or `nix`. This repository sets `kit`. `ci_toolchain: devcontainer` needs Node and npm
  on the runner; GitHub's hosted runners have both.
