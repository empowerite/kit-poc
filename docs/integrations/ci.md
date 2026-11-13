# Continuous integration

Continuous integration (CI) is the system that runs a repository's pipeline on each push and each change and reports
the result. To kit it is two things. It is a source of data: the builds stage of `kit flow` lists the runs no change
owns, and the changes stage shows each change's checks. It is also where `kit ci` runs: the delivered GitHub Actions
job runs it on every pull request into the default branch, and any other pipeline can run it too. The index of these
pages is [1st.md](1st.md).

kit reads CI through the code forge seam, `kit/modules/bash/forge.sh`, and two of its calls carry CI data; what a
seam is, [architecture.md](../architecture.md#code-forges-seams-and-providers) says.

- `forge:runs` returns the 20 newest runs that no change owns. The builds stage draws them. On GitHub and GitLab the 5
  newest carry their jobs and the failed step, a call each; a run whose jobs cannot be read carries none, and every
  run on Azure DevOps carries none, since its jobs would cost a call each. Each provider asks its forge for them by
  kind, so a change's runs take no room in what it reads. GitHub cannot be asked for the pushes to a tag alone: kit
  reads the 100 newest pushes for them, and a tag's run older than those is not listed.
- `open-prs` returns each open change with its checks: on GitHub the commit's `statusCheckRollup`, both check runs and
  commit statuses; on GitLab the jobs of the merge request's head pipeline; on Azure DevOps the pull request's policy
  evaluations, build validation and status policies among them. The changes stage draws them.

`forge:marks` also keeps a runs mark, a text that changes when the runs do, so a picture reloads only when it must.

see: [forges.md](forges.md), `kit/modules/bash/builds.sh`

## CI that is not the code forge's own

The seam reads the code forge's own CI: GitHub Actions on GitHub, GitLab CI/CD on GitLab, Azure Pipelines on Azure
DevOps. A repository on GitHub can run its pipeline elsewhere, on Jenkins, CircleCI, Buildkite, or Azure Pipelines.
Two cases follow.

- A change's checks still work. External CI reports into the code forge: it posts a commit status or, as a GitHub
  App, a check run on the commit it built. `open-prs` reads both, so the changes stage shows an external system's
  checks beside the code forge's own with no new code.
- The builds stage does not. `forge:runs` lists the code forge's own runs, and a status on a commit of the default
  branch is not a run. To list an external system's runs, their jobs, and their logs, kit needs a seam of its own,
  a `ci.sh` beside `forge.sh` whose providers answer `runs` in the shape `forge:runs` has today: `{id, number,
  attempt, workflow, branch, tag, event, sha, title, state, age, took, url, jobs}`, each job `{name, state, took,
  step}`. Its enabling point would be a `ci` setting in `kit.yml`, else the code forge's own.

`kit ci` itself runs on any CI system, but `kit linked` needs the change's number. Most external systems check out
a detached HEAD, which has no branch to ask about, and name the change in a variable of their own. `forge:pr-here`
reads that variable first, from the seam's table, `forge_ci_changes` in `kit/modules/bash/forge.sh`:

| CI system | Its marker | Variable | Its value |
| --- | --- | --- | --- |
| Buildkite | `BUILDKITE` | `BUILDKITE_PULL_REQUEST` | the number, or `false` on a run for no change |
| CircleCI | `CIRCLECI` | `CIRCLE_PULL_REQUEST` | the address of the change's page, which the number ends |
| Jenkins, a multibranch pipeline | `JENKINS_URL` | `CHANGE_ID` | the number |
| Azure Pipelines, for a repository on GitHub | `TF_BUILD` | `SYSTEM_PULLREQUEST_PULLREQUESTNUMBER` | the number |
| AWS CodeBuild | `CODEBUILD_BUILD_ID` | `CODEBUILD_WEBHOOK_TRIGGER` | `pr/` and the number |
| Woodpecker | `CI` | `CI_COMMIT_PULL_REQUEST` | the number |
| Drone | `DRONE` | `DRONE_PULL_REQUEST` | the number |

A variable counts only where its system's marker is set, the variable that system sets on every run of its own.
Woodpecker's is `CI`, which every CI system sets. A desk's shell can export a variable of the same name, `CHANGE_ID`
for one, and `kit ready` and `kit settle` write to the change `forge:pr-here` names, so at a desk the table names
none and the branch checked out is asked about. A Jenkins controller with no URL configured sets no `JENKINS_URL`:
set it in the job, or name the change, `kit linked "${CHANGE_ID}"`.

A value that holds no number names no change. With none of them, the provider reads the forge's own runner, else
asks for the open change on the checked-out branch. The same rule holds for a forge's own runner: the provider reads
its variable only where the runner's marker is set, so a desk's shell that exports the variable names no change.

| Forge's runner | Its marker | Variable | Its value |
| --- | --- | --- | --- |
| GitHub Actions | `GITHUB_ACTIONS` | `GITHUB_EVENT_PATH` | the event's payload, a file, whose `pull_request.number` is the number |
| GitLab CI | `GITLAB_CI` | `CI_MERGE_REQUEST_IID` | the number |
| Azure Pipelines, for a repository on Azure DevOps | `TF_BUILD` | `SYSTEM_PULLREQUEST_PULLREQUESTID` | the number |

A runner that names no change, on a detached HEAD, has none, and `kit linked` refuses. Bitbucket Pipelines sets
`BITBUCKET_PR_ID`, which kit does not read: it has no provider for Bitbucket.

`kit policy` and `kit linked` judge the change by the policy on its base, so they need the change's head branch and
its target branch too. GitHub's and GitLab's own runners name both. For the systems above, and for Azure Pipelines
on a repository of Azure DevOps, kit reads them from a second table, `policy_ci_branches` in
`kit/modules/bash/policy.sh`, once a change is named:

| CI system | Head branch | Target branch |
| --- | --- | --- |
| Azure Pipelines | `SYSTEM_PULLREQUEST_SOURCEBRANCH` | `SYSTEM_PULLREQUEST_TARGETBRANCH` |
| Jenkins, a multibranch pipeline | `CHANGE_BRANCH` | `CHANGE_TARGET` |
| Buildkite | `BUILDKITE_BRANCH` | `BUILDKITE_PULL_REQUEST_BASE_BRANCH` |
| AWS CodeBuild | `CODEBUILD_WEBHOOK_HEAD_REF` | `CODEBUILD_WEBHOOK_BASE_REF` |
| Woodpecker | `CI_COMMIT_SOURCE_BRANCH` | `CI_COMMIT_TARGET_BRANCH` |
| Drone | `DRONE_SOURCE_BRANCH` | `DRONE_TARGET_BRANCH` |
| CircleCI | `CIRCLE_BRANCH` | none: the primary's default branch |

A value may be a ref, `refs/heads/<branch>`, and Buildkite writes a fork's head branch as `<owner>:<branch>`. The
head branch is the one the variable names, whatever is checked out: a detached HEAD, or, on Drone, the target with
the change merged in. The base is the tip of the target branch, fetched from the primary every time, forced and with
no tags, so a ref an earlier job left counts for nothing. A change whose head branch or target is not named fails
both verbs. So does a detached HEAD on a runner that names no change, since no branch is there to judge:
[policy.md](../policy.md#what-judges-a-branch) says how a branch is judged. None of these was verified on a live runner;
the variables are as each system documents them.

## Scope

| Capability | Read or write | Where kit uses it |
| --- | --- | --- |
| Recent runs no change owns: pushes to the default branch or a tag, scheduled, and manual runs | read | `forge:runs`, the builds stage |
| A run's jobs and the step that failed | read | `forge:runs` (`jobs[].step`), the builds stage: the 5 newest runs on GitHub and GitLab, none on Azure DevOps |
| Whether the runs changed, read cheaply | read | `forge:marks`, the runs mark |
| A change's checks | read | `open-prs`, the changes stage, `kit changes checks`, kittui's checks tab |
| A run's or a job's log | read | planned |
| A run's artifacts: list | read | `forge:artifacts`, `kit delivery artifacts`: the newest, with digest, size, run, and expiry |
| A run's artifacts: download | read | planned |
| Rerun a run, or its failed jobs | write | planned |
| Cancel a run | write | planned |
| Start a run: a manual run of a workflow on a ref | write | planned |
| Report a status on a commit | write | planned; `kit ci` reports through its job's own result today |
| The pipeline file that runs `kit ci` | write | the `github/ci` package, kept by `kit check` |

### The pipeline file

kit delivers `kit ci` as a file in the repository. The `github/ci` package delivers
`kit/packages/github/ci/templates/repo/.github/workflows/kit-ci.yml` as `.github/workflows/kit-ci.yml`, and `kit
check` fails when it differs from the release. A system that reads a directory of pipeline files can take kit's file
beside the repository's own. A system that reads one root file needs the repository's file to include kit's.

| Provider | Pipeline file | kit's job would live |
| --- | --- | --- |
| GitHub Actions | `.github/workflows/*.yml` | `.github/workflows/kit-ci.yml`, delivered today |
| GitLab CI/CD | `.gitlab-ci.yml`, one root file | a file of kit's that the root file names under `include: local:` |
| Jenkins | `Jenkinsfile`, path set per job | a stage the repository's `Jenkinsfile` calls; no separate file |
| Azure Pipelines | `azure-pipelines.yml` by default; each pipeline names its own YAML path | a file of kit's, with a pipeline of its own or as a `template:` the root file uses |
| CircleCI | `.circleci/config.yml`, one root file | a job in that file |
| AWS CodeBuild | `buildspec.yml` by default; each project names its own path | a buildspec of kit's, with a project of its own |
| Bitbucket Pipelines | `bitbucket-pipelines.yml`, one root file | a step in that file |
| Buildkite | `.buildkite/pipeline.yml`, uploaded by a step | a file of kit's that a step uploads |
| Tekton (Pipelines-as-Code) | `.tekton/*.yaml` | `.tekton/kit-ci.yaml` |
| Argo Workflows | manifests applied to a cluster | a `WorkflowTemplate`; no file in the repository is read on its own |
| Forgejo and Gitea Actions | `.forgejo/workflows/` and `.gitea/workflows/`; Gitea falls back to `.github/workflows/` | `.forgejo/workflows/kit-ci.yml` or `.gitea/workflows/kit-ci.yml`; whether the GitHub file runs there as it is, its actions resolved from the instance's actions source, was not verified |
| Woodpecker CI | `.woodpecker.yml` or `.woodpecker/*.yml` | `.woodpecker/kit-ci.yml` |
| Drone | `.drone.yml`, path set per repository | a pipeline in that file |
| Concourse | any file, set with `fly set-pipeline` | a pipeline of kit's, set from its file |

## Providers

| Provider | Hosting | CLI | kit status | JSON from the CLI | Machine-readable descriptions |
| --- | --- | --- | --- | --- | --- |
| [GitHub Actions](gh.md#github-actions) | SaaS; GitHub Enterprise Server self-hosted; proprietary | `gh`, official, [cli/cli](https://github.com/cli/cli) | `provider`, through `forge/github.sh` | `--json "${fields}"`, `--jq`; `gh api` | REST OpenAPI, GraphQL schema, workflow JSON Schema, webhook JSON Schema |
| [GitLab CI/CD](glab.md#gitlab-cicd) | SaaS; self-managed; open core, the community edition MIT | `glab`, official, [gitlab-org/cli](https://gitlab.com/gitlab-org/cli) | `provider`, through `forge/gitlab.sh` | `-F json`, `--jq`; `glab api` | REST OpenAPI, CI JSON Schema |
| [Jenkins](jenkins.md#jenkins) | self-hosted; open source, MIT | `jenkins-cli.jar`, official, shipped by each controller | `none` | none; REST `/api/json` | none |
| [Azure Pipelines](az.md#azure-pipelines-runs) | SaaS; Azure DevOps Server self-hosted; proprietary | `az` with the `azure-devops` extension, official, [Azure/azure-devops-cli-extension](https://github.com/Azure/azure-devops-cli-extension) | `provider`, through `forge/ado.sh` | `-o json` (the default), `--query` JMESPath; `az devops invoke` | pipeline YAML JSON Schema; REST: none published; a REST reference in prose |
| [CircleCI](circleci.md#circleci) | SaaS; CircleCI server self-hosted; proprietary | `circleci`, official, [CircleCI-Public/circleci-cli](https://github.com/CircleCI-Public/circleci-cli) | `none` | `--json`, `--jq`; `circleci api` | API v2 OpenAPI, config JSON Schema |
| [AWS CodeBuild and CodePipeline](aws.md#aws-codebuild-and-codepipeline) | SaaS; proprietary | `aws`, official, [aws/aws-cli](https://github.com/aws/aws-cli) | `planned`, with an `aws` code forge | `--output json`, `--query` JMESPath | service models (JSON); no buildspec schema |
| [Bitbucket Pipelines](bkt.md#bitbucket-pipelines) | SaaS; proprietary | Atlassian's Teamwork Graph CLI, `twg`, official; status unclear | `none` | not verified | REST OpenAPI, pipeline JSON Schema |
| [Buildkite](bk.md#buildkite) | SaaS control plane, self-hosted agents | `bk`, official, [buildkite/cli](https://github.com/buildkite/cli) | `none` | `-o json`; `bk api` | pipeline JSON Schema, GraphQL schema |
| [Tekton](tkn.md#tekton) | self-hosted on Kubernetes; open source, Apache-2.0 | `tkn`, official, [tektoncd/cli](https://github.com/tektoncd/cli) | `none` | `-o json` | custom resource definitions, Swagger, Tekton Results OpenAPI |
| [Argo Workflows](argo.md#argo-workflows) | self-hosted on Kubernetes; open source, Apache-2.0 | `argo`, official, [argoproj/argo-workflows](https://github.com/argoproj/argo-workflows) | `none` | `-o json` | JSON Schema, Swagger |
| [Forgejo and Gitea Actions](tea.md#forgejo-and-gitea-actions) | self-hosted, or a hosted instance such as Codeberg; Forgejo GPL-3.0, Gitea MIT | `tea`, official to Gitea, [gitea/tea](https://gitea.com/gitea/tea); `fj`, community, [forgejo-contrib/forgejo-cli](https://codeberg.org/forgejo-contrib/forgejo-cli) | `none` | `tea -o json`; `fj` none | REST Swagger; the GitHub workflow JSON Schema |
| [Woodpecker CI](woodpecker-cli.md#woodpecker-ci) | self-hosted; open source, Apache-2.0 | `woodpecker-cli`, official, [woodpecker-ci/woodpecker](https://github.com/woodpecker-ci/woodpecker) | `none` | none; `--output go-template=` | pipeline JSON Schema, Swagger served by the server |
| [Drone](drone.md#drone) | self-hosted; community edition Apache-2.0 | `drone`, official, [harness/drone-cli](https://github.com/harness/drone-cli) | `none` | `--format '{{ jsonify . }}'` | pipeline JSON Schema (SchemaStore) |
| [Concourse](fly.md#concourse) | self-hosted; open source, Apache-2.0 | `fly`, official, [concourse/concourse](https://github.com/concourse/concourse) | `none` | `--json` on list commands; `fly curl` | none |

The table orders providers by how widely they are used, as far as kit can tell; there is no single count to cite.

### Who reports to the code forge

| Provider | What it posts on the commit |
| --- | --- |
| GitHub Actions, GitLab CI/CD, Forgejo and Gitea Actions, Bitbucket Pipelines | nothing to post; each is its code forge's own CI |
| Azure Pipelines | check runs on GitHub, through its GitHub App; on Azure Repos, its own status |
| CircleCI | commit statuses per job; check runs per workflow on GitHub, through its GitHub App |
| Buildkite | commit statuses on GitHub, per build or per job |
| AWS CodeBuild | commit statuses on GitHub, GitLab, and Bitbucket, when the project reports build status |
| AWS CodePipeline | none found; its CodeBuild actions report as CodeBuild does |
| Jenkins | through plugins: commit statuses (GitHub Branch Source), check runs (GitHub Checks) |
| Woodpecker CI, Drone | commit statuses |
| Tekton | through Pipelines-as-Code: check runs on GitHub, statuses on GitLab, Gitea, and Bitbucket |
| Argo Workflows, Concourse | nothing built in; a step or a resource posts it |

Each provider's name leads to its section on its tool's page: what the tool reads and writes
where it meets kit's scope, its gaps, and the descriptions the provider publishes.

## Coverage

`cli` is a command of the provider's CLI, `api` a route reached only through the raw API, and `—` not available.
Bitbucket's `cli` cells are the Teamwork Graph CLI, whose flags were not verified. Reporting a status on the commit
is the code forge's call, not the CI system's; see "Who reports to the code forge".

| Capability | GitHub Actions | GitLab CI/CD | Jenkins | Azure Pipelines | CircleCI | CodeBuild | CodePipeline | Bitbucket | Buildkite | Tekton | Argo | Gitea | Forgejo | Woodpecker | Drone | Concourse |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Recent runs | cli | cli | api | cli | cli | cli | cli | cli | cli | cli | cli | cli | api | cli | cli | cli |
| Runs no change owns, filtered by the server | cli | cli | api | cli | — | — | — | api | — | — | — | cli | api | cli | — | — |
| A run's jobs and failed step | cli | cli | api | api | cli | cli | cli | api | cli | cli | cli | cli | api | cli | cli | api |
| A run's log | cli | cli | cli | api | cli | cli | — | cli | cli | cli | cli | cli | api | cli | cli | cli |
| Artifacts | cli | cli | api | cli | cli | cli | cli | — | cli | — | cli | api | api | — | — | — |
| Rerun | cli | cli | cli | api | cli | cli | cli | cli | cli | cli | cli | api | api | cli | cli | cli |
| Cancel | cli | cli | cli | cli | cli | cli | cli | api | cli | cli | cli | cli | api | cli | cli | cli |
| Start a run | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli | cli |
