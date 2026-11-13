# Publishing

A repository publishes its own artifacts in two steps. `kit release` tags a commit and pushes the tag. `kit publish`
then runs on a CI runner and pushes each artifact to its targets. After the push, kit watches whether each source
that consumers pull from serves the release yet.

This page uses two terms:

- A push target is a place a release is sent, such as a GitHub release or an npm registry. kit never searches a
  target.
- The pull path is the ordered list of sources that kit searches when it fetches a tool or a package; see
  [packages.md](packages.md#kinds-and-the-pull-path). Consumers search the pull path, not the targets.

A source can serve a release later than the push, for example after a scan or an approval. That gap is why kit
treats the push and the pull as separate, and it is what "pull behind push" means.

## Tagging a release

`kit release <version>` tags HEAD as `release/<version>` and pushes that tag, and nothing else, to the primary
remote. The pushed tag starts the repository's release workflow, where it has one. A version is
`<major>.<minor>.<patch>`. A pre-release adds `-<suffix>`, such as `0.1.0-rc.7`.

`kit release` refuses:

- a version of the wrong shape
- a tag that already exists
- a release, which is a version with no suffix, whose commit is not on the default branch at the primary remote
- a release whose commit is behind that branch, unless you pass `--behind`
- a version that is not higher than every release on the primary remote, unless you pass `--lower`

A desk that was not pulled after a merge is behind the default branch. The refusal for that case names the commit,
says how many commits behind it is, and names both ways forward: `git pull`, or `--behind`.

`kit release <version> --dry-run` runs every refusal. It then prints the commit, the tag, and what the push would
send. It tags nothing and pushes nothing. `kit help release` has the rest.

## The publish setting

The repository names its artifacts under `publish:` in `kit.yml`:

```yaml
publish:
  kit:
    files: ["dist/kit-{version}.tar.gz"]
    release: empowerite/kit
    tag: release/{version}
    asset: kit-{version}.tar.gz
    targets:
      release: [github-release, vcs-tag]
      prerelease: [github-release]
    verify: [corp-files]
```

Each artifact has a name, `kit` in this example, and these keys:

| Key | Meaning |
| --- | --- |
| `files` | the files the runner built; kit fills in `{version}` |
| `release`, `asset`, `tag` | what the artifact is on the pull path when it is a GitHub release: the repository, the file, and the tag, `v{version}` by default |
| `module`, `module_version` | what it is on the pull path when it is a Go module: the module's path, and its version, `v{version}` by default |
| `npm` | what it is on the pull path when it is an npm package |
| `url` | what it is on the pull path when it is a plain download |
| `targets.release` | the targets a release is pushed to |
| `targets.prerelease` | the targets a pre-release is pushed to |
| `verify` | the pull sources, by name, that kit checks for this artifact; the whole pull path by default |

The pull path keys say what the artifact is the same way a tool pin does; see
[using kit as the tool manager](toolchains/using-kit.md#saying-what-a-tool-is-in-place-of-its-url).

## Targets

A target is written as its kind, or as a map of its kind and its keys, such as
`{kind: artifactory-local, repository: libs-release}`. Each kind is a provider of the `targets` seam, a file
`modules/bash/targets/<kind>.sh`; [architecture.md](architecture.md#code-forges-seams-and-providers) says what a
seam is.

| Kind | Tool it runs | Keys | What it does | What `--retire` does |
| --- | --- | --- | --- | --- |
| `vcs-tag` | `git` | `prefix` | pushes the tag `v<version>` to the primary remote, which is how a Go module is published | refuses, because a pushed tag is never taken back |
| `github-release` | `gh` | `repo` | makes a GitHub release of the tag `release/<version>` with the artifact's files | deletes the release, and a pre-release's tag with it |
| `artifactory-local` | `jf` | `repository`, `path`, `url` | uploads each file to an Artifactory local repository | deletes the uploaded path |
| `npm-publish` | `npm` | `registry` | publishes the package's tarball; a pre-release goes under the dist-tag `next` | deprecates the version |

Each provider runs the tool that its service ships. kit never calls a service's upload API itself, and the runner
carries the credentials.

## kit publish

`kit publish <version>` pushes each artifact to its targets. A version with a suffix goes to the `prerelease`
targets, and any other version to the `release` targets.

It publishes a release only on a CI runner, where `GITHUB_ACTIONS`, `GITLAB_CI`, or `TF_BUILD` is set. A pre-release
may be published from a desk, at your own risk, and kit warns when you do.

Before it pushes to any target, `kit publish` refuses:

- a version whose tag `kit release` has not pushed
- an artifact file that has not been built
- a target whose tool is not on `PATH`
- a target that already holds the version, because a version is never overwritten

When every target has taken the version, `kit publish` tags what it pushed as `release-hashes/<version>` and pushes
that tag. The tag points at one line for each artifact, with the artifact's hash. Anyone who can read the forge can
use it to check that a source serves the same bytes.

`kit publish <version> --retire` takes the version back from each target that can take one back.

## Visibility

The push is done when the targets take it. Whether the pull path serves the release yet is its visibility. kit
watches visibility; a push never waits for it.

kit checks each artifact against each pull source that serves its form, or against only the sources that the
artifact's `verify:` names. For each pair, the release is in one of these states:

| State | Meaning |
| --- | --- |
| visible | the source serves it, with the hash the `release-hashes` tag records, or with any hash where the tag records none |
| pending | it is tagged, and the source does not serve it yet |
| stuck | it has been pending for longer than the source's `expect:` |
| unknown | the source could not be reached; kit asks it again on the next read |
| blocked | the source says it will never serve it, for example because a scan blocked it |
| mismatch | the source serves it with another hash |

kit keeps each answer but unknown under `${XDG_CACHE_HOME:-~/.cache}/kit/visibility/`. It keeps visible, blocked, and
mismatch for good, and pending and stuck for five minutes.

Three commands show visibility:

- `kit flow releases` shows the state of the five newest releases, one on each row, and warns when one is stuck.
  With `--json`, each of those rows carries `visibility`, a state for each artifact and source.
- `kit release <version> --wait=<duration>` waits until every source serves the release. It exits 0 when every source
  serves it, 1 when a source blocks it or serves other bytes, and 3 when the time passes with a source still pending.
  When the tag is already on the primary remote, it tags nothing and only waits.
- In a repository that consumes the artifact, `kit tools --outdated` also lists a version that is tagged upstream and
  that the pull path does not serve yet. A pin to such a version fails, and the error says the version is pending.

see: [the artifact sources design](superpowers/specs/2026-11-12-artifact-sources-design.md)
