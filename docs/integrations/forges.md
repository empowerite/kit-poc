# Code forges

A code forge is the service that hosts a repository with its branches and its changes: pull requests on GitHub,
merge requests on GitLab, patches on Radicle. kit reaches it for the repository's name and URL, the caller's login and
rate limits, the branch linked to an issue, and a change's draft, title, body, author, state, closing issues, review
threads, and checks. Under every forge is git itself: the checkout, its worktrees, branches, and remotes, the
commits, and the tags, which kit reads with git and never asks a forge for; [git.md](git.md) says what kit runs. The
index of these pages is [1st.md](1st.md).

Every such call goes through one seam, `kit/modules/bash/forge.sh`, whose header is the contract. The `forge` setting
or the primary remote's host picks the provider: `forge/github.sh` over `gh`, `forge/gitlab.sh` over `glab`, or
`forge/ado.sh` over `az`. `kit work` links a branch to an issue and opens a draft change. `kit linked` and
`kit policy` read the change in CI. `kit settle` and `kit tidy` read its state when it closes, and the changes and
issues stages of `kit flow` draw every open change with its checks and threads. The forge seam's issue calls are
on [trackers.md](trackers.md), its `runs` on [ci.md](ci.md), and its `releases` on [cd.md](cd.md).
see: [architecture.md](../architecture.md#code-forges-seams-and-providers), `kit/modules/bash/forge.sh`

## Scope

| Capability | Kind | Used by |
| --- | --- | --- |
| The tool is present and signed in | read | `forge:require`, before every verb that calls the code forge |
| The repository as owner and name | read | `forge:repo`: `kit work`, `kit linked` |
| The repository's and a change's browser URL | read | `forge:repo-url`, `forge:pr-url`: the messages of `kit work` and `kit linked` |
| The change's sigil and name, `#` and pull request | none | `forge:noun`, a constant of the provider |
| The caller's login | read | `forge:me`: `kit work` assigns the caller; the issues stage keeps the caller's issues under `--mine` |
| The caller's rate limits, at most one request | read | `forge:quota`: `kit flow` |
| A cheap mark that changes when issues, changes, runs, or releases do | read | `forge:marks`: `kit flow` reloads a stage when its mark moves |
| Make a branch linked to an issue, from the default branch, pushed | write | `forge:link-branch`: `kit work` |
| The branch an open change for an issue is on | read | `forge:branch-for-issue`: `kit work`, so a second run reuses the branch |
| Open a change as a draft | write | `forge:pr-create`: `kit work` |
| Mark the change ready for review | write | `forge:pr-ready`: `kit ready`, the workflow's last step |
| The change's title | read | `forge:pr-title`: `kit policy` |
| The change's body | read | `forge:pr-body`: `kit linked`, `kit policy`, `kit work` |
| Replace the change's body | write | `forge:pr-set-body`: `kit work` adds its `Closes` lines |
| The change's author, as the forge shows it | read | `forge:pr-author`: `kit linked` (`linked_exempt`), `kit policy` |
| The change's state, and its merge commit once merged | read | `forge:pr-state`: `kit settle`, `kit tidy` |
| The change on a branch: open, latest in any state, its state, its head commit | read | `forge:pr-for-branch`, `pr-last-for-branch`, `pr-state-for-branch`, `pr-head-for-branch`, `pr-here`: `kit commit`, `kit tidy`, `kit linked`, the worktrees stage |
| The issues the change closes, with their state | read | `forge:pr-closing-issues`: `kit linked`, `kit settle` |
| The change's review threads, resolved or not, and its reviewers | read | `forge:open-prs`: the changes stage, and `kit changes reviews`, kittui's reviews tab |
| The change's checks rollup on its head commit | read | `forge:open-prs`: the changes stage, and `kit changes checks`, kittui's checks tab |
| Every open change, whole, with the above | read | `forge:open-prs`: the changes and issues stages |
| The page of each open issue, each open change, and each issue a change closes | read | `forge:open-issues`, `forge:open-prs`, as `url`: what kittui's issues and changes tabs open and copy; no caller builds one |
| Where a remote's branch, commit, and issue pages are | read | `forge:page-urls <remote>`, from the remote's URL with no call to the forge: what `kit workspace` links its rows to; no caller builds one |
| Merged changes | read | `forge:merged-prs`: `kit changes merged`, kittui's merged tab |
| A change's labels, added or removed | write | `forge:pr-label-add`, `forge:pr-label-remove`: the `drafts` stand-in |
| Who has access, which teams, and which bots acted | read | `forge:collaborators`, `forge:teams`, `forge:bots`: `kit people` |
| Attestations, the three kinds of security alert, rulesets, and who may bypass them | read | `forge:attestations`, `forge:code-scanning-alerts`, `forge:dependabot-alerts`, `forge:secret-scanning-alerts`, `forge:rulesets`, `forge:bypasses`: `kit trust` |
| An app the forge signs in as, with a key of its own | write | the `forge:bot-*` calls: `kit bots` |

## Features

The seam groups its calls into features: a set of calls that a forge has whole or not at all. Each provider declares the
features its forge lacks, and a call of a feature the forge lacks answers unsupported; the header of
`kit/modules/bash/forge.sh` says how, and `kit flow --capabilities` prints the declaration of the forge here. The
table lists every feature, the contract version that added it, and what each of kit's three providers says. A test
holds the table to the seam's list and to each provider's declaration.

| Feature | Since | GitHub | GitLab | Azure DevOps |
| --- | --- | --- | --- | --- |
| `issues` | 1 | native | native | native |
| `sub-issues` | 1 | native | native | native |
| `linked-branches` | 1 | native | native | lacks |
| `drafts` | 1 | native | native | native |
| `closing-issues` | 1 | native | native | native |
| `review-threads` | 1 | native | native | native |
| `checks` | 1 | native | native | native |
| `quota` | 1 | native | native | lacks |
| `marks` | 1 | native | native | lacks |
| `releases` | 1 | native | native | lacks |
| `runs` | 1 | native | native | native |
| `labels` | 3 | native | native | native |
| `milestones` | 4 | native | native | lacks |
| `iterations` | 4 | native | native | native |
| `reviewers` | 4 | native | native | native |
| `merged` | 4 | native | native | native |
| `artifacts` | 4 | native | native | native |
| `environments` | 4 | native | native | native |
| `deployments` | 4 | native | native | native |
| `collaborators` | 4 | native | native | native |
| `teams` | 4 | native | native | native |
| `bots` | 4 | native | native | lacks |
| `attestations` | 4 | native | lacks | lacks |
| `code-scanning` | 4 | native | native | lacks |
| `dependabot` | 4 | native | native | lacks |
| `secret-scanning` | 4 | native | native | lacks |
| `rulesets` | 4 | native | native | native |
| `bypasses` | 4 | native | lacks | lacks |
| `check-runs` | 4 | native | native | native |
| `swimlanes` | 5 | lacks | lacks | lacks |
| `bot-accounts` | 6 | native | lacks | lacks |
| `merge-closing` | 8 | native | native | lacks |

Two things the table does not say. `lacks` is what the provider declares, which is not always what the forge cannot
do: Azure DevOps' `linked-branches` is `lacks` because the provider does not write the link, though `az` has the two
commands in [az.md](az.md#write-to-azure-devops-repos), not verified against a live organization. No provider has a
separate state for a feature that is not written yet, so `kit flow --capabilities` says `none` for both; that is a
decision for the seam's owner. `swimlanes` is `lacks` everywhere: no forge kit reaches has a lane it reads the same
way, so a repository names a stand-in in `kit.yml`.

## Providers

| Provider | Hosting | CLI | kit status | JSON output | Machine-readable descriptions |
| --- | --- | --- | --- | --- | --- |
| [GitHub](gh.md#github-pull-requests) | SaaS; GitHub Enterprise Server self-hosted; proprietary | `gh`, official ([cli/cli](https://github.com/cli/cli), MIT) | `provider` | `--json "${fields}"`, `--jq`; `gh api` | REST OpenAPI per product and version, GraphQL schema, webhook schemas |
| [GitLab](glab.md#gitlab-merge-requests) | SaaS; self-managed (Community Edition MIT, Enterprise Edition proprietary) | `glab`, official ([gitlab-org/cli](https://gitlab.com/gitlab-org/cli), MIT) | `provider`, experimental | `--output json` (`-F json`), `--jq`; `glab api` | REST OpenAPI 3.0, GraphQL schema |
| [Azure DevOps Repos](az.md#azure-devops-repos) | SaaS (Azure DevOps Services); Azure DevOps Server self-hosted; proprietary | `az` with the `azure-devops` extension, official ([Azure/azure-devops-cli-extension](https://github.com/Azure/azure-devops-cli-extension), MIT) | `provider`, experimental | `--output json`, `--query`; `az devops invoke`, `az rest` | none published; a REST reference in prose |
| [Bitbucket Cloud](bkt.md#bitbucket-cloud) | SaaS; proprietary | `bkt`, community ([avivsinai/bitbucket-cli](https://github.com/avivsinai/bitbucket-cli), MIT); `twg`, Atlassian's, beta ([atlassian/twg-cli](https://github.com/atlassian/twg-cli)) | `none` | `bkt`: `--json`, `--jq`; `bkt api`. `twg`: `-o json` | REST OpenAPI 3.0 and Swagger 2.0 |
| [Bitbucket Data Center](bkt.md#bitbucket-data-center) | self-hosted; proprietary | `bkt`, community ([avivsinai/bitbucket-cli](https://github.com/avivsinai/bitbucket-cli), MIT) | `none` | `--json`, `--jq`; `bkt api` | REST OpenAPI 3.0 per version |
| [AWS CodeCommit](aws.md#aws-codecommit) | SaaS; proprietary | `aws`, official ([aws/aws-cli](https://github.com/aws/aws-cli), Apache-2.0) | `planned` | JSON by default, `--query` | Smithy model, botocore model |
| [Gitea](tea.md#gitea-pull-requests) | self-hosted, open source (MIT); Gitea Cloud SaaS | `tea`, official ([gitea/tea](https://gitea.com/gitea/tea), MIT) | `none` | `--output json` with `--fields`; `tea api` | Swagger 2.0 and OpenAPI 3.0, served by every instance |
| [Forgejo and Codeberg](fj.md#forgejo-and-codeberg) | self-hosted, open source (GPL-3.0-or-later); Codeberg is a hosted Forgejo | `fj`, community ([forgejo-contrib/forgejo-cli](https://codeberg.org/forgejo-contrib/forgejo-cli), Apache-2.0 or MIT); `tea` for the API Forgejo shares with Gitea | `none` | `fj`: none; `tea` as above | Swagger 2.0, served by every instance |
| [Gerrit](gerrit.md#gerrit) | self-hosted, open source (Apache-2.0) | `git-review`, community ([opendev/git-review](https://opendev.org/opendev/git-review)); `ssh -p 29418 "${host}" gerrit`, built in | `none` | `gerrit query --format=JSON`; REST answers JSON after a `)]}'` line | none |
| [SourceHut](hut.md#sourcehut) | SaaS (sr.ht); self-hosted, open source (AGPL-3.0) | `hut`, community ([~xenrox/hut](https://git.sr.ht/~xenrox/hut), AGPL-3.0) | `none` | none; `hut graphql` prints the API's JSON | GraphQL schema per service |
| [Radicle](rad.md#radicle) | peer-to-peer, open source (MIT or Apache-2.0) | `rad`, official ([radicle-dev/heartwood](https://github.com/radicle-dev/heartwood), a mirror) | `none` | `rad cob show` prints JSON; `rad patch` prints text | none |

Each provider's name leads to its section on its tool's page: what the tool reads and writes
where it meets kit's scope, its gaps, and the descriptions the provider publishes.

GitHub's provider is supported. GitLab's and Azure DevOps' are experimental: each is tested against a fake built
from the tool's documented output, and has not yet run against a live project.

The order is a judgment of how widely each is used, kit's own providers first; no survey backs it. Bitbucket Cloud
and Bitbucket Data Center are two products with two APIs, so they have two rows. Bitbucket Cloud has no issues since
Atlassian removed them on 20 August 2026, so a Bitbucket repository's tracker is Jira or another; see
[trackers.md](trackers.md).

## Coverage

| Capability | GitHub | GitLab | Azure DevOps | Bitbucket Cloud | Bitbucket DC | CodeCommit | Gitea | Forgejo | Gerrit | SourceHut | Radicle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Signed in | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli |
| Owner and name | cli | cli | cli | cli | cli | cli | api | cli | api | cli | cli |
| Browser URL | cli | cli | cli | cli | cli | — | api | api | — | — | — |
| Caller's login | api | api | cli | api | cli | cli | cli | cli | api | cli | cli |
| Rate limits | api | api | — | cli | api | — | — | api | — | — | — |
| Marks | api | api | — | api | api | — | api | api | api | api | — |
| Branch linked to an issue | cli | api | cli | cli | cli | — | — | — | — | — | — |
| Branch for an issue | cli | cli | cli | api | api | cli | cli | api | cli | — | — |
| Open a draft | cli | cli | cli | cli | cli | — | cli | cli | cli | — | cli |
| Mark ready | cli | cli | cli | cli | cli | — | cli | cli | cli | — | cli |
| Title, body | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli |
| Set the body | cli | cli | cli | cli | cli | cli | cli | cli | api | — | cli |
| Author | api | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli |
| State and merge commit | cli | cli | cli | cli | api | cli | api | api | cli | — | cli |
| Change on a branch | cli | cli | cli | api | api | cli | cli | api | cli | — | cli |
| Closing issues | cli | api | cli | — | — | — | — | — | — | — | — |
| Review threads, resolved | api | cli | api | cli | cli | — | cli | api | api | — | cli |
| Checks rollup | cli | cli | cli | cli | cli | — | cli | cli | cli | — | — |
| Open changes | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli |

Notes on the cells:

- GitHub's author is `api` because `gh pr view` names a bot by its app, not by its login.
- Azure DevOps' branch link is `cli` because `az` has the two commands; the provider declares `linked-branches` lacking
  until the link is verified, as the Features table says.
- Azure DevOps' marks are `—`: no read was found that changes on every update to a pull request.
- Bitbucket's branch link and closing issues are Jira's: Bitbucket Cloud has no issues, and Data Center never did.
- Bitbucket Data Center's merge commit is `api` from the activities, and its rate limits `api` (both not verified).
- Gitea's and Forgejo's branch is made through the API with no link to the issue; a closing keyword in the body
  closes it at merge.
- Forgejo's `cli` cells are text alone: `fj` prints no JSON.
- Gerrit's branch for an issue is a topic that names it, a convention rather than a link. Its draft is a change
  marked work in progress.
- SourceHut's open changes are patchsets on a list, and its marks are the patchsets' `updated` in GraphQL.
- Radicle's `cli` reads are `rad cob show` JSON, except open changes, which `rad patch list` prints as text.
