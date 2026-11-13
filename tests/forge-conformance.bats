#!/usr/bin/env bats
# forge-conformance.bats - every forge provider answers the seam's calls in the same shape, through a fake of its tool
# ----------------------------------------------------------------------------------------------------------------------
# One world, seen through each forge's own API: the repository empowerite/example, the caller ada, issue 7 "Fix
# the thing" assigned to bob, and change 3 on branch 7-fix-the-thing, opened by ada, closing issue 7, with two
# checks that passed, the slower in fifty seconds, a failed run of one of them from the day before that a rerun
# superseded, and one unresolved review thread. Each provider is driven by tests/fakes/fake-tool
# standing in for its tool, so what is proven is the provider's own folding of its forge's answers into the seam's
# shape. What only a real forge can prove, that the API answers as the fixtures do, is not proven here.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fake-tools gh glab
  fresh-repo
}

# A world on GitHub names its primary's repository in FAKE_GH_REPO, and tests/fakes/fake-tool refuses a gh call that
# names another, or none, and keeps it in gh.unnamed. A provider may hide a call that fails, as a run's jobs that
# cannot be read are none, so every test here ends by looking: no gh call went to a repository gh chose itself.
teardown() {
  helper:outside-checkout || return 1
  if [[ -s "${FAKE_DIR}/gh.unnamed" ]]
  then
    echo "gh was called without the primary's repository, ${FAKE_GH_REPO:-}:" >&2
    cat "${FAKE_DIR}/gh.unnamed" >&2
    return 1
  fi
}

# call <call> <argument>… runs one call of the seam, as a verb would.
call() {
  bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && "forge:$0" "$@"' "$@"
}

# fresh-call <call> <argument>… runs one call of the seam as a stage given --fresh would: after forge:fresh.
fresh-call() {
  bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:fresh && "forge:$0" "$@"' "$@"
}

# reads <forge> prints how many times the provider's tool was asked for the open changes.
reads() {
  if [[ "$1" == github ]]
  then grep --count '^api graphql' "${FAKE_DIR}/gh.calls"
  else grep --count 'merge_requests?state=opened&per_page=100&order_by=' "${FAKE_DIR}/glab.calls"
  fi
}

# snapshot <forge> <call> prints the path of the call's snapshot, which forge:snapshot keeps under the common git
# directory.
snapshot() {
  printf '%s\n' "$(git rev-parse --path-format=absolute --git-common-dir)"/kit/forge/"$1"-*/"$2.json"
}

# provider prints the provider the seam picks here.
provider() {
  bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:provider'
}

# world <forge> makes this repository's origin the forge's, and its tool's routes the world above.
world() {
  git remote remove origin 2>/dev/null || true
  "world-$1"
}

world-github() {
  git remote add origin https://github.com/empowerite/example.git
  export FAKE_GH_REPO=github.com/empowerite/example
  : > "${FAKE_DIR}/gh.routes"
  fixture user.json <<<'{"login": "ada"}'
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture issue.json <<<'{"title": "Fix the thing", "state": "OPEN", "assignees": [{"login": "bob"}]}'
  fixture open-heads.json <<<'[{"headRefName": "9-other"}, {"headRefName": "7-fix-the-thing"}]'
  fixture pr-open.json <<<'[{"number": 3}]'
  fixture pr-all.json <<<'[{"state": "OPEN", "headRefOid": "1f2e3d4"}]'
  fixture pr-url.txt <<<'https://github.com/empowerite/example/pull/3'
  fixture issue-url.txt <<<'https://github.com/empowerite/example/issues/7'
  fixture pr.json <<<'{"title": "Fix the thing", "body": "Closes #7"}'
  fixture pull.json <<<'{"user": {"login": "ada"}}'
  fixture closing.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": [
  {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  fixture closing-none.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": []}}}}}'
  fixture open-prs.json <<'JSON'
{"data": {"repository": {"nameWithOwner": "empowerite/example",
  "issues": {"nodes": [{"number": 7, "assignees": {"nodes": [{"login": "bob"}]}}]},
  "pullRequests": {"nodes": [{
  "number": 3, "title": "Fix the thing", "body": "Closes #7", "isDraft": false, "headRefName": "7-fix-the-thing",
  "url": "https://github.com/empowerite/example/pull/3",
  "createdAt": "2026-10-01T09:00:00Z", "mergeStateStatus": "CLEAN", "reviewDecision": null,
  "author": {"login": "ada"}, "labels": {"nodes": [{"name": "kind=fix", "color": "0E8A16"}]},
  "closingIssuesReferences": {"nodes": [{"number": 7, "title": "Fix the thing", "createdAt": "2026-09-20T09:00:00Z",
                                         "url": "https://github.com/empowerite/example/issues/7",
                                         "repository": {"nameWithOwner": "empowerite/example"},
                                         "labels": {"nodes": [{"name": "bug", "color": "D73A4A"}]}}]},
  "reviewRequests": {"totalCount": 1, "nodes": [{"requestedReviewer": {"login": "bob"}}]},
  "latestOpinionatedReviews": {"totalCount": 1, "nodes": [
    {"author": {"login": "carol"}, "state": "APPROVED", "submittedAt": "2026-10-02T09:00:00Z"}]},
  "latestReviews": {"totalCount": 2, "nodes": [
    {"author": {"login": "ada"}, "state": "COMMENTED", "submittedAt": "2026-10-01T11:00:00Z"},
    {"author": {"login": "carol"}, "state": "COMMENTED", "submittedAt": "2026-10-03T09:00:00Z"}]},
  "reviewThreads": {"nodes": [{"isResolved": true}, {"isResolved": false}]},
  "commits": {"nodes": [{"commit": {"statusCheckRollup": {"contexts": {"nodes": [
    {"__typename": "CheckRun", "name": "a", "status": "COMPLETED", "conclusion": "FAILURE",
     "startedAt": "2026-09-30T10:00:00Z", "completedAt": "2026-09-30T10:05:00Z"},
    {"__typename": "CheckRun", "name": "a", "status": "COMPLETED", "conclusion": "SUCCESS",
     "startedAt": "2026-10-01T10:00:00Z", "completedAt": "2026-10-01T10:00:30Z"},
    {"__typename": "CheckRun", "name": "b", "status": "COMPLETED", "conclusion": "SUCCESS",
     "startedAt": "2026-10-01T10:00:10Z", "completedAt": "2026-10-01T10:01:00Z"}]}}}}]}}]}}}}
JSON
  route gh 'api user*' user.json
  route gh 'repo view*' repo.json
  route gh 'issue view 7 *' issue.json
  route gh 'issue create*' issue-url.txt
  fixture issues.json <<'JSON'
[{"number": 9, "title": "Other thing", "assignees": [], "createdAt": "2026-09-25T09:00:00Z",
  "url": "https://github.com/empowerite/example/issues/9"},
 {"number": 7, "title": "Fix the thing", "assignees": [{"login": "bob"}], "createdAt": "2026-09-20T09:00:00Z",
  "labels": [{"id": "LA_1", "name": "bug", "description": "", "color": "d73a4a"}],
  "milestone": {"number": 2, "title": "v0.1", "description": "", "dueOn": null},
  "url": "https://github.com/empowerite/example/issues/7"}]
JSON
  fixture gh-issue-iterations.json <<'JSON'
{"data": {"repository": {"issues": {"pageInfo": {"hasNextPage": false, "endCursor": "c1"}, "nodes": [
  {"number": 9, "projectItems": {"nodes": []}},
  {"number": 7, "projectItems": {"nodes": [{"fieldValues": {"nodes": [{}, {"title": "Sprint 2"}]}}]}}]}}}}
JSON
  route gh 'issue edit 7 --add-assignee ada' '!0'
  route gh 'issue list --state open --limit 10000 --json *' issues.json
  route gh 'pr list --state open --json headRefName*' open-heads.json
  route gh 'pr list --head 7-fix-the-thing --state open*' pr-open.json
  route gh 'pr list --head 7-fix-the-thing --state all*' pr-all.json
  route gh 'pr create --draft --base main --head 7-fix-the-thing --title Fix the thing*' pr-url.txt
  route gh 'pr view 3 --json *' pr.json
  route gh 'api repos/empowerite/example/pulls/3 *' pull.json
  fixture gh-milestones.json <<'JSON'
[[{"number": 2, "title": "v0.1", "state": "open", "due_on": "2026-12-01T00:00:00Z", "open_issues": 3,
   "closed_issues": 2, "html_url": "https://github.com/empowerite/example/milestone/2"}]]
JSON
  fixture gh-iterations.json <<'JSON'
{"data": {"repository": {"projectsV2": {"totalCount": 1, "nodes": [{"url": "https://github.com/orgs/empowerite/projects/4",
  "fields": {"totalCount": 2, "nodes": [{}, {"configuration": {
    "iterations": [{"id": "PVTI_2", "title": "Sprint 2", "startDate": "2026-11-16", "duration": 14}],
    "completedIterations": [{"id": "PVTI_1", "title": "Sprint 1", "startDate": "2026-11-02", "duration": 14}]}}]}}]}}}}
JSON
  fixture gh-iterations-none.json <<<'{"data": {"repository": {"projectsV2": {"nodes": []}}}}'
  route gh 'api --paginate --slurp repos/{owner}/{repo}/milestones?state=all&per_page=100' gh-milestones.json
  delivery-github
  people-github
  audit-github
  fixture gh-merged.json <<'JSON'
{"data": {"repository": {"pullRequests": {"totalCount": 1, "nodes": [
  {"number": 2, "title": "Do the other thing", "url": "https://github.com/empowerite/example/pull/2",
   "headRefName": "9-other", "mergedAt": "2026-10-03T09:00:00Z", "updatedAt": "2026-10-03T09:00:00Z",
   "author": {"login": "bob"}, "body": "Fixes AB#12",
   "mergedBy": {"login": "ada"}}]}}}}
JSON
  route gh 'api graphql*states: MERGED*' "${GITHUB_MERGED:-gh-merged.json}"
  route gh 'api graphql*deployments(first: 50*' "${GITHUB_DEPLOYMENTS:-gh-deployments.json}"
  route gh 'api graphql*projectsV2*' "${GITHUB_ITERATIONS:-gh-iterations.json}"
  route gh 'api graphql*after=c1*projectItems*' gh-issue-iterations.json
  route gh 'api graphql*projectItems*' "${GITHUB_ISSUE_ITERATIONS:-gh-issue-iterations.json}"
  route gh 'api graphql*number=3*' "${GITHUB_CLOSING:-closing.json}"
  route gh 'api graphql*' open-prs.json
}

world-gitlab() {
  git remote add origin git@gitlab.com:empowerite/example.git
  : > "${FAKE_DIR}/glab.routes"
  local p='projects/empowerite%2Fexample'
  fixture user.json <<<'{"username": "ada"}'
  fixture issue.json <<<'{"iid": 7, "title": "Fix the thing", "state": "opened", "assignees": [{"username": "bob"}]}'
  fixture mrs-open.json <<<'[{"iid": 2, "source_branch": "9-other"}, {"iid": 3, "source_branch": "7-fix-the-thing"}]'
  fixture mrs-list.json <<<'[{"iid": 3}]'
  fixture mr-by-branch.json <<<'[{"iid": 3}]'
  fixture mr-states.json <<<'[{"state": "opened", "sha": "1f2e3d4"}]'
  fixture mr-url.txt <<<'https://gitlab.com/empowerite/example/-/merge_requests/3'
  fixture issue-url.txt <<<'https://gitlab.com/empowerite/example/-/issues/7'
  fixture mr.json <<'JSON'
{"iid": 3, "title": "Fix the thing", "draft": false, "source_branch": "7-fix-the-thing",
 "web_url": "https://gitlab.com/empowerite/example/-/merge_requests/3",
 "references": {"full": "empowerite/example!3"},
 "created_at": "2026-10-01T09:00:00.000Z", "author": {"username": "ada"}, "has_conflicts": false,
 "detailed_merge_status": "mergeable", "description": "Closes #7", "source_project_id": 1, "target_project_id": 1,
 "head_pipeline": {"id": 11, "project_id": 1, "status": "success"}, "labels": ["kind=fix"],
 "reviewers": [{"username": "bob"}, {"username": "carol"}]}
JSON
  fixture approvals.json <<'JSON'
{"approved": true, "approved_by": [{"user": {"username": "carol"}, "approved_at": "2026-10-02T09:00:00.000Z"}]}
JSON
  fixture gl-merged.json <<'JSON'
[{"iid": 2, "title": "Do the other thing", "description": "Fixes AB#12", "author": {"username": "bob"},
  "source_branch": "9-other",
  "merged_at": "2026-10-03T09:00:00.000Z", "merge_user": {"username": "ada"}, "merged_by": {"username": "ada"},
  "web_url": "https://gitlab.com/empowerite/example/-/merge_requests/2"}]
JSON
  fixture jobs.json <<'JSON'
[{"name": "a", "status": "failed",
  "started_at": "2026-09-30T10:00:00.000Z", "finished_at": "2026-09-30T10:05:00.000Z"},
 {"name": "a", "status": "success",
  "started_at": "2026-10-01T10:00:00.120Z", "finished_at": "2026-10-01T10:00:30.000Z"},
 {"name": "b", "status": "success",
  "started_at": "2026-10-01T10:00:10.000Z", "finished_at": "2026-10-01T10:01:00.450Z"}]
JSON
  fixture discussions.json <<'JSON'
[{"notes": [{"resolvable": true, "resolved": true}]}, {"notes": [{"resolvable": true, "resolved": false}]},
 {"notes": [{"resolvable": false, "resolved": false}]}]
JSON
  fixture closes.json <<'JSON'
[{"iid": 7, "title": "Fix the thing", "state": "opened", "references": {"full": "empowerite/example#7"},
  "web_url": "https://gitlab.com/empowerite/example/-/issues/7",
  "created_at": "2026-09-20T09:00:00.000Z", "assignees": [{"username": "bob"}], "labels": ["bug"]}]
JSON
  fixture labels.json <<<'[{"name": "bug", "color": "#D73A4A"}, {"name": "kind=fix", "color": "#0E8A16"}]'
  fixture none.json <<<'[]'
  route glab 'api user' user.json
  fixture gl-milestones.json <<'JSON'
{"data": {"project": {"milestones": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
  {"iid": "2", "title": "v0.1", "state": "active", "dueDate": "2026-12-01",
   "webPath": "/empowerite/example/-/milestones/2", "stats": {"totalIssuesCount": 5, "closedIssuesCount": 2}}]}}}}
JSON
  fixture gl-iterations.json <<'JSON'
[{"id": 31, "iid": 1, "title": "Sprint 1", "start_date": "2026-11-02", "due_date": "2026-11-15",
  "web_url": "https://gitlab.com/groups/empowerite/-/iterations/31"}]
JSON
  fixture gl-forbidden.txt <<<'glab: 403 Forbidden'
  people-gitlab
  audit-gitlab
  route glab 'api graphql*' "${GITLAB_MILESTONES:-gl-milestones.json}"
  route glab "api ${p}/iterations?include_ancestors=true&per_page=100*" "${GITLAB_ITERATIONS:-gl-iterations.json}"
  route glab "api ${p}/issues/7" issue.json
  route glab 'issue create*' issue-url.txt
  fixture issues.json <<'JSON'
[{"iid": 7, "title": "Fix the thing", "assignees": [{"username": "bob"}], "created_at": "2026-09-20T09:00:00.000Z",
  "labels": [{"id": 4, "name": "bug", "color": "#D73A4A", "text_color": "#FFFFFF"}],
  "milestone": {"id": 12, "iid": 2, "title": "v0.1"}, "iteration": {"id": 4, "title": "Sprint 2"},
  "references": {"full": "empowerite/example#7"}, "web_url": "https://gitlab.com/empowerite/example/-/issues/7"},
 {"iid": 9, "title": "Other thing", "assignees": [], "created_at": "2026-09-25T09:00:00.500Z",
  "references": {"full": "empowerite/example#9"}, "web_url": "https://gitlab.com/empowerite/example/-/issues/9"}]
JSON
  route glab 'issue update 7 --assignee +ada' '!0'
  route glab "api ${p}/issues?state=opened&per_page=100&order_by=created_at&sort=asc&with_labels_details=true*" \
    issues.json
  route glab "api ${p}/labels?per_page=100*" labels.json
  route glab "api ${p}/merge_requests?state=opened&per_page=100&order_by=*" mrs-list.json
  route glab "api ${p}/merge_requests?state=opened&per_page=100*" mrs-open.json
  route glab "api ${p}/merge_requests?state=opened&source_branch=7-fix-the-thing" mr-by-branch.json
  route glab "api ${p}/merge_requests?state=all&source_branch=7-fix-the-thing*" mr-states.json
  route glab "api ${p}/merge_requests/3/closes_issues?per_page=100*" "${GITLAB_CLOSES:-closes.json}"
  route glab "api ${p}/merge_requests/3/discussions*" discussions.json
  route glab "api ${p}/merge_requests/3/approvals" "${GITLAB_APPROVALS:-approvals.json}"
  route glab "api ${p}/merge_requests?state=merged&order_by=merged_at&per_page=51" "${GITLAB_MERGED:-gl-merged.json}"
  delivery-gitlab
  route glab "api ${p}/merge_requests/3" mr.json
  route glab 'api projects/1/pipelines/11/jobs*' jobs.json
  route glab "api ${p}/repository/branches --method POST*" '!0'
  route glab 'mr create --draft --source-branch 7-fix-the-thing --target-branch main --title Fix the thing*' mr-url.txt
}

@test "the forge is picked by origin's host, github.com or gitlab.com, and either answers the same plain calls" {
  for forge in github gitlab
  do
    world "${forge}"
    run provider
    [ "$output" = "${forge}" ]
    run call repo
    [ "$output" = "empowerite/example" ]
    run call me
    [ "$output" = "ada" ]
    run call issue-title 7
    [ "$output" = "Fix the thing" ]
    run call issue-state 7
    [ "$output" = "OPEN" ]
    run call issue-assignees 7
    [ "$output" = "bob" ]
    run call issue-create "Fix the thing"
    [ "$output" = "7" ]
    run call issue-assign 7 ada
    [ "$status" -eq 0 ]
  done
}

@test "either forge reads an issue's body as Markdown, and an empty body as nothing" {
  for forge in github gitlab
  do
    world "${forge}"
    run --separate-stderr call issue-body 7
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    fixture issue.json <<<'{"title": "Fix", "state": "OPEN", "body": "## Paths\n\n- `docs/**`", "description": "## Paths"}'
    run call issue-body 7
    [ "$status" -eq 0 ]
    if [[ "${forge}" == github ]]
    then
      [ "$output" = $'## Paths\n\n- `docs/**`' ]
    else
      [ "$output" = '## Paths' ]
    fi
  done
}

@test "every provider unassigns, closes, comments on, and nests issues, and reads a change's state, in its own tool's words" {
  world github
  route gh 'issue edit 7 --remove-assignee bob' '!0'
  route gh 'issue edit 7 --add-sub-issue 9' '!0'
  route gh 'issue close 7 *' '!0'
  route gh 'issue comment 7 *' '!0'
  fixture pr-state.json <<<'{"state": "MERGED", "mergeCommit": {"oid": "abc123"}}'
  route gh 'pr view 5 --json state,mergeCommit*' pr-state.json
  call issue-unassign 7 bob
  call issue-close 7 not-planned
  call issue-close 7 duplicate 9
  call issue-comment 7 "Moved on"
  call issue-add-sub 7 9
  run call pr-state 5
  [ "$output" = $'MERGED\tabc123' ]
  run grep '^issue ' "${FAKE_DIR}/gh.calls"
  [ "$output" = $'issue edit 7 --remove-assignee bob\nissue close 7 --reason not planned\nissue close 7 --reason duplicate --duplicate-of 9\nissue comment 7 --body Moved on\nissue edit 7 --add-sub-issue 9' ]
  world gitlab
  local p='projects/empowerite%2Fexample'
  route glab 'issue update 7 --assignee -bob' '!0'
  route glab 'issue close 7' '!0'
  route glab 'issue note 7 *' '!0'
  route glab "api ${p}/issues/7/links --method POST*" '!0'
  fixture mr-merged.json <<<'{"iid": 3, "state": "merged", "merge_commit_sha": "def456"}'
  route glab "api ${p}/merge_requests/4" mr-merged.json
  : > "${FAKE_DIR}/glab.calls"
  call issue-unassign 7 bob
  call issue-close 7 not-planned
  call issue-close 7 duplicate 9
  call issue-comment 7 "Moved on"
  call issue-add-sub 7 9
  run call pr-state 4
  [ "$output" = $'MERGED\tdef456' ]
  run grep -v '^api user\|^api projects/empowerite%2Fexample/merge_requests/4$' "${FAKE_DIR}/glab.calls"
  [ "$output" = $'issue update 7 --assignee -bob\nissue close 7\nissue note 7 --message /duplicate #9\nissue note 7 --message Moved on\napi projects/empowerite%2Fexample/issues/7/links --method POST --raw-field target_project_id=empowerite/example --raw-field target_issue_iid=9' ]
}

# named prints each repository the gh calls since the last named-afresh named, once: "<host> <repo>".
named() { sort --unique "${FAKE_DIR}/gh.named" | tr '\t' ' '; }

# named-afresh <host/owner/name> holds the gh calls from here on to that repository, and forgets those before.
named-afresh() {
  export FAKE_GH_REPO=$1
  : > "${FAKE_DIR}/gh.named"
  forge-forget
}

@test "GitHub's provider names the primary's repository and host to gh, which would choose a repository of its own" {
  world github
  # a fork's checkout: origin is the fork, and upstream the project, which gh takes before origin
  git remote set-url origin https://github.com/ada/example.git
  git remote add upstream https://github.com/empowerite/example.git
  named-afresh github.com/ada/example
  # reads and changes alike, each way the provider reaches gh
  for call in repo repo-url me 'issue-title 7' 'issue-create Fix' 'issue-assign 7 ada' 'pr-for-branch 7-fix-the-thing' \
    open-prs open-issues milestones merged-prs deployments artifacts environments collaborators teams bots
  do
    # shellcheck disable=SC2086  # a call and its arguments, split on purpose
    run --separate-stderr call ${call}
    [ "$status" -eq 0 ] || { echo "${call}: ${stderr}"; false; }
  done
  run --separate-stderr call pr-create 7-fix-the-thing main "Fix the thing"
  [ "$status" -eq 0 ]
  [ "$(named)" = 'github.com github.com/ada/example' ]
  # the repository's name and page come from the URL, which asks gh, and GitHub, nothing
  run grep '^repo view' "${FAKE_DIR}/gh.calls"
  [ "$status" -eq 1 ]
  # the primary is kit.yml's, where it names one
  printf 'primary: upstream\n' > kit.yml
  named-afresh github.com/empowerite/example
  run --separate-stderr call milestones
  [ "$status" -eq 0 ]
  run --separate-stderr call issue-create Fix
  [ "$status" -eq 0 ]
  [ "$(named)" = 'github.com github.com/empowerite/example' ]
  # a GitHub Enterprise Server, by an ssh URL: gh api goes to its host, not to the host gh logged in to first
  printf 'forge: github\n' > kit.yml
  git remote set-url origin git@ghe.example.com:team/app.git
  named-afresh ghe.example.com/team/app
  run --separate-stderr call milestones
  [ "$status" -eq 0 ]
  [ "$(named)" = 'ghe.example.com ghe.example.com/team/app' ]
  # an ssh URL may name a Host of the ssh configuration: ssh says the host it stands for, as gh asks it
  fake-tools ssh
  fixture ssh-work.txt <<<$'user git\nhostname github.com\nport 22'
  route ssh '-G -- github.com-work' ssh-work.txt
  git remote set-url origin git@github.com-work:team/app.git
  named-afresh github.com/team/app
  run --separate-stderr call milestones
  [ "$status" -eq 0 ]
  # ssh.github.com is github.com's own ssh, on port 443, and a host in capitals is the host
  git remote set-url origin ssh://git@ssh.GitHub.com:443/team/app.git
  run --separate-stderr call milestones
  [ "$status" -eq 0 ]
  [ "$(named)" = 'github.com github.com/team/app' ]
  # a URL that names a host and no <owner>/<name> names no repository: gh is not run
  git remote set-url origin https://github.com/team
  named-afresh github.com/team/app
  run --separate-stderr call milestones
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"https://github.com/team names no repository"* ]]
  [ ! -s "${FAKE_DIR}/gh.named" ]
  # a call that hides what gh says, or keeps it to say why gh failed, says that line too, and never blames the login
  for asked in 'issue-create Fix' marks 'marks issues runs' code-scanning-alerts dependabot-alerts \
    secret-scanning-alerts
  do
    # shellcheck disable=SC2086  # the call and its arguments are words
    run --separate-stderr call ${asked}
    [ "$status" -eq 1 ] || { echo "${asked}: ${status}"; false; }
    [ -z "$output" ] || { echo "${asked}: ${output}"; false; }
    [ "$stderr" = "❌ set the URL of origin to a repository on GitHub, as https://github.com/<owner>/<name> (https://github.com/team names no repository, so GitHub was not asked)" ] \
      || { echo "${asked}: ${stderr}"; false; }
  done
  [ ! -s "${FAKE_DIR}/gh.named" ]
  # a primary on this machine, GitHub's by kit.yml alone, names none: gh runs as the caller's environment has it
  git remote set-url origin "${BATS_TEST_TMPDIR}/mirror.git"
  unset FAKE_GH_REPO
  run --separate-stderr call milestones
  [ "$status" -eq 0 ]
  [ "$(named)" = ' ' ]
}

@test "GitHub's provider sends a repository's owner and name as strings, which --field would type as numbers for 2048" {
  world github
  for call in open-prs open-issues merged-prs deployments bots 'pr-closing-issues 3' iterations
  do
    # shellcheck disable=SC2086  # a call and its arguments, split on purpose
    run --separate-stderr call ${call}
    [ "$status" -eq 0 ] || { echo "${call}: ${stderr}"; false; }
  done
  grep --quiet -- '--raw-field owner=' "${FAKE_DIR}/gh.calls"
  ! grep --extended-regexp -- '--field (owner|name)=' "${FAKE_DIR}/gh.calls"
  ! grep --extended-regexp -- '--field (owner|name)="' "${kit_root}/modules/bash/forge/github.sh"
}

@test "the GitHub provider runs gh in one place, forge/github:gh, so no call can leave the repository unnamed" {
  # what is left of the provider without its comments, its remedies, run: gh …, and the names of its temporary files
  run bash -c 'grep --invert-match --extended-regexp "^[[:space:]]*#" "$1" \
    | sed -E "s/run: gh [a-z]+//g; s/file:temp [a-z_]+ gh//g" \
    | grep --extended-regexp "(^|[^[:alnum:]_:/.-])gh([[:space:]]|\$)"' _ "${kit_root}/modules/bash/forge/github.sh"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == *'gh "$@"' && "${lines[1]}" == *'GH_REPO=${place} gh "$@"' ]]
}

@test "every provider finds, opens, and reads a change by its branch the same way" {
  for forge in github gitlab
  do
    world "${forge}"
    run call branch-for-issue 7
    [ "$output" = "7-fix-the-thing" ]
    run call branch-for-issue 8
    [ -z "$output" ]
    run call pr-for-branch 7-fix-the-thing
    [ "$output" = "3" ]
    run call pr-state-for-branch 7-fix-the-thing
    [ "$output" = "OPEN" ]
    run call pr-head-for-branch 7-fix-the-thing
    [ "$output" = "1f2e3d4" ]
    run call pr-create 7-fix-the-thing main "Fix the thing"
    [ "$output" = "3" ]
    run call pr-closing-issues 3
    [ "$output" = "7 OPEN empowerite/example" ]
    run call pr-title 3
    [ "$output" = "Fix the thing" ]
    run call pr-body 3
    [ "$output" = "Closes #7" ]
    run call pr-author 3
    [ "$output" = "ada" ]
  done
}

# here <NAME=value>… prints what forge:pr-here answers in a shell that sets those variables and no other that names a
# change or marks a CI system: a forge's own, or a CI system's.
here() {
  env -u GITHUB_EVENT_PATH -u CI_MERGE_REQUEST_IID -u SYSTEM_PULLREQUEST_PULLREQUESTID -u BUILDKITE_PULL_REQUEST \
    -u CIRCLE_PULL_REQUEST -u CHANGE_ID -u SYSTEM_PULLREQUEST_PULLREQUESTNUMBER -u CODEBUILD_WEBHOOK_TRIGGER \
    -u CI_COMMIT_PULL_REQUEST -u DRONE_PULL_REQUEST -u BUILDKITE -u CIRCLECI -u JENKINS_URL -u TF_BUILD \
    -u CODEBUILD_BUILD_ID -u CI -u DRONE -u GITHUB_ACTIONS -u GITLAB_CI "$@" \
    bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:pr-here'
}

@test "on a detached HEAD the change is the one the CI system's own variable names, on either forge, and none without one" {
  git commit --quiet --allow-empty --message one
  git checkout --quiet --detach
  for forge in github gitlab
  do
    world "${forge}"
    # Buildkite, Jenkins, Azure Pipelines over GitHub, Woodpecker, and Drone set the number; CircleCI the address of
    # the change's page; CodeBuild pr/ and the number
    for named in 'BUILDKITE=true BUILDKITE_PULL_REQUEST=3' 'JENKINS_URL=https://ci.example/ CHANGE_ID=3' \
      'TF_BUILD=True SYSTEM_PULLREQUEST_PULLREQUESTNUMBER=3' 'CI=woodpecker CI_COMMIT_PULL_REQUEST=3' \
      'DRONE=true DRONE_PULL_REQUEST=3' 'CIRCLECI=true CIRCLE_PULL_REQUEST=https://github.com/empowerite/example/pull/3' \
      'CODEBUILD_BUILD_ID=example:1f2e CODEBUILD_WEBHOOK_TRIGGER=pr/3'
    do
      # shellcheck disable=SC2086  # the marker and the variable are two words
      run --separate-stderr here ${named}
      [ "$status" -eq 0 ] || { echo "${forge} ${named}: ${stderr}"; false; }
      [ "$output" = 3 ] || { echo "${forge} ${named}: ${output}"; false; }
    done
    # a value that holds no number names no change: a run for none, a branch's run, a change that is no number
    for named in 'BUILDKITE=true BUILDKITE_PULL_REQUEST=false' 'CIRCLECI=true CIRCLE_PULL_REQUEST=' \
      'CODEBUILD_BUILD_ID=example:1f2e CODEBUILD_WEBHOOK_TRIGGER=branch/main' \
      'CODEBUILD_BUILD_ID=example:1f2e CODEBUILD_WEBHOOK_TRIGGER=3' 'JENKINS_URL=https://ci.example/ CHANGE_ID=I8f3a2c' \
      'DRONE=true DRONE_PULL_REQUEST='
    do
      # shellcheck disable=SC2086  # the marker and the variable are two words
      run --separate-stderr here ${named}
      [ "$status" -eq 0 ]
      [ -z "$output" ] || { echo "${forge} ${named}: ${output}"; false; }
    done
    # a runner that sets none has none, and the caller refuses
    run --separate-stderr here
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  # the forge was never asked: no branch is checked out to ask about
  ! grep --quiet '^pr list --head' "${FAKE_DIR}/gh.calls"
  # the variable is read before the branch is asked about: Jenkins may check a branch of its own name out
  world github
  git switch --quiet --create PR-3
  run --separate-stderr here JENKINS_URL=https://ci.example/ CHANGE_ID=3
  [ "$status" -eq 0 ]
  [ "$output" = 3 ]
  ! grep --quiet '^pr list --head' "${FAKE_DIR}/gh.calls"
  # and with no variable the branch is asked about, as at a desk
  git switch --quiet --create 7-fix-the-thing
  run --separate-stderr here
  [ "$output" = 3 ]
  grep --quiet '^pr list --head 7-fix-the-thing' "${FAKE_DIR}/gh.calls"
  # a primary with no forge has no change, whatever a variable says
  printf 'forge: none\n' > kit.yml
  run --separate-stderr here DRONE=true DRONE_PULL_REQUEST=3
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "at a desk a CI system's variable names no change: the branch is asked about, and kit ready marks its change" {
  git commit --quiet --allow-empty --message one
  git switch --quiet --create 7-fix-the-thing
  world github
  # a shell that exports a CI system's variable, and not the marker that system sets on its runners, is a desk
  for named in BUILDKITE_PULL_REQUEST=99 CHANGE_ID=99 SYSTEM_PULLREQUEST_PULLREQUESTNUMBER=99 \
    CI_COMMIT_PULL_REQUEST=99 DRONE_PULL_REQUEST=99 CIRCLE_PULL_REQUEST=https://github.com/empowerite/example/pull/99 \
    CODEBUILD_WEBHOOK_TRIGGER=pr/99
  do
    run --separate-stderr here "${named}"
    [ "$status" -eq 0 ] || { echo "${named}: ${stderr}"; false; }
    [ "$output" = 3 ] || { echo "${named}: ${output}"; false; }
  done
  # another system's marker does not make the variable count
  run --separate-stderr here CI=true DRONE=true CHANGE_ID=99
  [ "$output" = 3 ]
  # so a verb that writes takes its change from the branch, never from the variable
  route gh 'pr ready 3' '!0'
  CHANGE_ID=99 run "${kit_root}/bin/kit" ready
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull request #3 is ready for review"* ]]
  grep --quiet --line-regexp 'pr ready 3' "${FAKE_DIR}/gh.calls"
  ! grep --quiet ' 99' "${FAKE_DIR}/gh.calls"
}

@test "a forge's own runner names the change only under that runner's marker, and at a desk the branch is asked about" {
  git commit --quiet --allow-empty --message one
  git switch --quiet --create 7-fix-the-thing
  printf '{"pull_request": {"number": 99}}\n' > "${BATS_TEST_TMPDIR}/event.json"
  for forge in github gitlab
  do
    world "${forge}"
    if [[ "${forge}" == github ]]
    then marker=GITHUB_ACTIONS=true named=GITHUB_EVENT_PATH=${BATS_TEST_TMPDIR}/event.json
    else marker=GITLAB_CI=true named=CI_MERGE_REQUEST_IID=99
    fi
    # a shell that exports the forge's own variable, and not the marker its runner sets on every job, is a desk
    run --separate-stderr here "${named}"
    [ "$status" -eq 0 ] || { echo "${forge}: ${stderr}"; false; }
    [ "$output" = 3 ] || { echo "${forge} at a desk: ${output}"; false; }
    # on the forge's runner the variable names the change, whatever branch is checked out
    run --separate-stderr here "${marker}" "${named}"
    [ "$output" = 99 ] || { echo "${forge} on its runner: ${output}"; false; }
    # and a run there for no change asks about the branch
    run --separate-stderr here "${marker}"
    [ "$output" = 3 ] || { echo "${forge} on its runner, for no change: ${output}"; false; }
  done
  # so a verb that writes takes its change from the branch, never from the variable
  world github
  route gh 'pr ready 3' '!0'
  GITHUB_EVENT_PATH="${BATS_TEST_TMPDIR}/event.json" run "${kit_root}/bin/kit" ready
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull request #3 is ready for review"* ]]
  grep --quiet --line-regexp 'pr ready 3' "${FAKE_DIR}/gh.calls"
  ! grep --quiet ' 99' "${FAKE_DIR}/gh.calls"
}

@test "every provider says where the pages of a remote's repository are, from its URL and for any remote, and a remote with none has none" {
  world github
  run call page-urls origin
  [ "$output" = '{"repository":"https://github.com/empowerite/example","branch":"https://github.com/empowerite/example/tree/","commit":"https://github.com/empowerite/example/commit/","issue":"https://github.com/empowerite/example/issues/"}' ]
  world gitlab
  run call page-urls origin
  [ "$output" = '{"repository":"https://gitlab.com/empowerite/example","branch":"https://gitlab.com/empowerite/example/-/tree/","commit":"https://gitlab.com/empowerite/example/-/commit/","issue":"https://gitlab.com/empowerite/example/-/issues/"}' ]
  # the remote asked for is the one answered, not the primary: a GitLab subgroup, on GitHub's primary
  world github
  git remote add other https://gitlab.com/group/sub/project.git
  run call page-urls other
  [ "$output" = '{"repository":"https://gitlab.com/group/sub/project","branch":"https://gitlab.com/group/sub/project/-/tree/","commit":"https://gitlab.com/group/sub/project/-/commit/","issue":"https://gitlab.com/group/sub/project/-/issues/"}' ]
  # a remote on this machine, or one that is no remote, has no forge and no pages
  git remote add local /srv/example.git
  run call page-urls local
  [ "$status" -eq 0 ]
  [ "$output" = null ]
  run call page-urls nowhere
  [ "$output" = null ]
  # no call went to a forge for any of it
  [ ! -s "${FAKE_DIR}/gh.calls" ] || ! grep --quiet . "${FAKE_DIR}/gh.calls"
  [ ! -s "${FAKE_DIR}/glab.calls" ]
}

@test "with push naming a fork, every provider opens the change from the fork's branch, and a fork with no owner is refused" {
  for forge in github gitlab
  do
    world "${forge}"
    git remote remove fork 2>/dev/null || true
    git remote add fork "https://${forge}.com/ada/example.git"
    printf 'push: fork\n' > kit.yml
    : > "${FAKE_DIR}/gh.calls"
    : > "${FAKE_DIR}/glab.calls"
    route gh 'pr create --draft --base main --head ada:7-fix-the-thing --title Fix the thing*' pr-url.txt
    route glab 'mr create --draft --head ada/example --source-branch 7-fix-the-thing --target-branch main*' mr-url.txt
    run call pr-create 7-fix-the-thing main "Fix the thing"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
    # a fork on this machine names no owner, so nothing is opened
    git remote set-url fork "${BATS_TEST_TMPDIR}/fork.git"
    run call pr-create 7-fix-the-thing main "Fix the thing"
    [ "$status" -eq 1 ]
    [[ "$output" == *"set push in kit.yml to a remote on "*"(its URL, ${BATS_TEST_TMPDIR}/fork.git, names no "* ]]
    [ "$(cat "${FAKE_DIR}/gh.calls" "${FAKE_DIR}/glab.calls" | grep -c ' create ')" -eq 1 ]
    # a push that names no remote is refused before the forge is asked
    printf 'push: nowhere\n' > kit.yml
    run call pr-create 7-fix-the-thing main "Fix the thing"
    [ "$status" -eq 1 ]
    [[ "$output" == *"push 'nowhere' in kit.yml is not a remote; the remotes are: "* ]]
    rm kit.yml
  done
}

@test "every provider folds its open changes into the one document kit flow draws" {
  expected='{"number":3,"branch":"7-fix-the-thing","fork":null,"title":"Fix the thing","author":"ada","pushed":null,'
  expected+='"state":"comments:open","checks":{"state":"SUCCESS","passed":2,"total":2,"failing":"","took":50},'
  expected+='"unresolved":1,"labels":[{"name":"kind=fix","color":"#0e8a16"}],'
  expected+='"closes":[{"number":7,"ref":"#7","title":"Fix the thing","assignees":["bob"],'
  expected+='"labels":[{"name":"bug","color":"#d73a4a"}]}],'
  # the references a closing keyword names in its body, as a tracker the forge does not link reads them
  expected+='"named":["#7"],'
  # the author's own comment is no review; bob is asked and has not answered; carol approved, then commented, and
  # her approval stands
  expected+='"reviewers":[{"login":"bob","state":"requested","at":null},'
  expected+='{"login":"carol","state":"approved","at":1790931600}],'
  # every run on the head commit, the failed one a rerun superseded among them
  # a run's workflow and event are null where the forge names none, as in this world
  expected+='"runs":[{"name":"a","workflow":null,"event":null,"verdict":"failed","at":1790762400,"took":300},'
  expected+='{"name":"a","workflow":null,"event":null,"verdict":"passed","at":1790848800,"took":30},'
  expected+='{"name":"b","workflow":null,"event":null,"verdict":"passed","at":1790848810,"took":50}]}'
  for forge in github gitlab
  do
    world "${forge}"
    run call open-prs
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys \
      'del(.age, .createdAt, .ref, .source, .url, .organization, .repository)
       | .closes |= map(del(.age, .source, .organization, .repository, .url))' \
      <<<"$output")" = "$(jq --compact-output --sort-keys . <<<"${expected}")" ]
    [ "$(jq '.closes[0].age > 0' <<<"$output")" = true ]
    # the change names the forge it is on, and where on it, as the forge names its repository
    [ "$(jq --raw-output '"\(.source) \(.organization)/\(.repository)"' <<<"$output")" \
      = "${forge} empowerite/example" ]
    # each issue a change closes names the tracker that holds it, the forge's own, and where in it the issue is
    [ "$(jq --raw-output '[.closes[].source] | unique | join(" ")' <<<"$output")" = "${forge}" ]
    [ "$(jq --raw-output '[.closes[] | "\(.organization)/\(.repository)"] | unique | join(" ")' <<<"$output")" \
      = empowerite/example ]
  done
}

@test "every provider names a fork's owner and the last push, the same way, and reads a fork's project once" {
  local pushed
  pushed=$(jq --null-input --raw-output 'now - 7200 | todate')
  for forge in github gitlab
  do
    world "${forge}"
    if [[ "${forge}" == github ]]
    then
      jq --arg at "${pushed}" '.data.repository.pullRequests.nodes[0]
            |= (.isCrossRepository = true | .headRepositoryOwner = {login: "cy"}
                | .commits.nodes[0].commit += {committedDate: $at, author: {user: {login: "dee"}}})' \
        "${FAKE_DIR}/open-prs.json" > "${FAKE_DIR}/fork.json"
      mv "${FAKE_DIR}/fork.json" "${FAKE_DIR}/open-prs.json"
    else
      # The same merge request listed twice stands for two from one fork.
      fixture mrs-list.json <<<'[{"iid": 3}, {"iid": 3}]'
      fixture project.json <<<'{"id": 99, "namespace": {"full_path": "cy"}}'
      jq --arg at "${pushed}" '. + {source_project_id: 99, target_project_id: 1}
            | .head_pipeline += {created_at: $at, user: {username: "dee"}}' "${FAKE_DIR}/mr.json" \
        > "${FAKE_DIR}/fork.json"
      mv "${FAKE_DIR}/fork.json" "${FAKE_DIR}/mr.json"
      route glab 'api projects/99' project.json
    fi
    run call open-prs
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output '[.fork, .pushed.by, (.pushed.age >= 7200 and .pushed.age < 7300)]' <<<"${lines[0]}")" \
      = '["cy","dee",true]' ] || { echo "${forge}: ${output}"; return 1; }
  done
  grep --quiet 'isCrossRepository' "${FAKE_DIR}/gh.calls"
  grep --quiet 'headRepositoryOwner { login }' "${FAKE_DIR}/gh.calls"
  grep --quiet 'committedDate author { user { login } }' "${FAKE_DIR}/gh.calls"
  [ "$(grep --count '^api projects/99$' "${FAKE_DIR}/glab.calls")" -eq 1 ]
}

@test "a merge request from a fork the caller cannot read names no owner, and one without a pipeline no push" {
  world gitlab
  jq '. + {source_project_id: 99, target_project_id: 1} | del(.head_pipeline)' "${FAKE_DIR}/mr.json" \
    > "${FAKE_DIR}/fork.json"
  mv "${FAKE_DIR}/fork.json" "${FAKE_DIR}/mr.json"
  route glab 'api projects/99' '!1'
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '[.fork, .pushed, .checks.total]' <<<"$output")" = '[null,null,0]' ]
}

@test "a change that closes many issues is drawn with every one: GitLab's hundred, and GitHub's first ten, then the rest" {
  for forge in github gitlab
  do
    world "${forge}"
    if [[ "${forge}" == github ]]
    then
      # the first page holds ten and says there are more; the rest come in pages of their own, after its cursor
      jq '.data.repository.pullRequests.nodes[0].closingIssuesReferences
            = {pageInfo: {hasNextPage: true, endCursor: "c10"}, nodes: [range(1; 11) | {number: ., title: "Issue \(.)"}]}' \
        "${FAKE_DIR}/open-prs.json" > "${FAKE_DIR}/many.json"
      mv "${FAKE_DIR}/many.json" "${FAKE_DIR}/open-prs.json"
      fixture rest-1.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {
        "pageInfo": {"hasNextPage": true, "endCursor": "c11"}, "nodes": [{"number": 11, "title": "Issue 11"}]}}}}}'
      fixture rest-2.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {
        "pageInfo": {"hasNextPage": false, "endCursor": "c12"}, "nodes": [{"number": 12, "title": "Issue 12"}]}}}}}'
      { printf '%s\t%s\n' 'api graphql*pr=3*after=c10*' rest-1.json 'api graphql*pr=3*after=c11*' rest-2.json
        cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
    else
      jq --null-input '[range(1; 13) | {iid: ., title: "Issue \(.)", state: "opened",
                                        references: {full: "empowerite/example#\(.)"}}]' > "${FAKE_DIR}/closes.json"
    fi
    run call open-prs
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output '[.closes[].number]' <<<"$output")" = "$(jq --null-input --compact-output '[range(1; 13)]')" ]
  done
  # GitHub prices the labels under each issue a change closes by how many issues it may give, so it is asked for ten,
  # and the rest, where there are more, a hundred at a time
  grep --quiet 'closingIssuesReferences(first: 10)' "${FAKE_DIR}/gh.calls"
  [ "$(grep --count 'closingIssuesReferences(first: 100, after: $after)' "${FAKE_DIR}/gh.calls")" -eq 2 ]
  grep --quiet 'merge_requests/3/closes_issues?per_page=100' "${FAKE_DIR}/glab.calls"
}

@test "each provider names the change in its own words, and the rest of the picture is identical" {
  world github
  run call noun
  [ "$output" = "$(printf '#\tpull request')" ]
  run call pr-url 3
  [ "$output" = "https://github.com/empowerite/example/pull/3" ]
  [ "$(call open-prs | jq --raw-output .ref)" = "#3" ]
  world gitlab
  run call noun
  [ "$output" = "$(printf '!\tmerge request')" ]
  run call pr-url 3
  [ "$output" = "https://gitlab.com/empowerite/example/-/merge_requests/3" ]
  [ "$(call open-prs | jq --raw-output .ref)" = "!3" ]
}

@test "every provider gives the page of each open issue, each open change, and each issue a change closes, as its tool reports it" {
  local -A change=([github]=pull/3 [gitlab]=-/merge_requests/3) issues=([github]=issues [gitlab]=-/issues)
  local forge page
  for forge in github gitlab
  do
    world "${forge}"
    page=https://${forge}.com/empowerite/example
    run call open-prs
    [ "$status" -eq 0 ]
    [ "$(jq --raw-output '.url, .closes[].url' <<<"$output")" \
      = "${page}/${change[${forge}]}"$'\n'"${page}/${issues[${forge}]}/7" ]
    run call open-issues
    [ "$status" -eq 0 ]
    [ "$(jq --raw-output .url <<<"$output")" = "${page}/${issues[${forge}]}/7"$'\n'"${page}/${issues[${forge}]}/9" ]
  done
  # the page is the forge's to say, never built from the remote: an issue of another repository that a change closes
  # leads to that repository, and a forge that gives one no page gives kit none
  world github
  jq '.data.repository.pullRequests.nodes[0].closingIssuesReferences.nodes
        = [{number: 9, title: "Nine", url: "https://github.com/other/repo/issues/9",
            repository: {nameWithOwner: "other/repo"}}, {number: 8, title: "Eight"}]' \
    "${FAKE_DIR}/open-prs.json" > "${FAKE_DIR}/far.json" && mv "${FAKE_DIR}/far.json" "${FAKE_DIR}/open-prs.json"
  run fresh-call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '.closes | map(.url)' <<<"$output")" = '["https://github.com/other/repo/issues/9",null]' ]
  # the issue of another repository says where it is, so it is never taken for the issue of its number here
  [ "$(jq --compact-output '.closes | map(.repository)' <<<"$output")" = '["repo",null]' ]
  # GitHub is asked for the page of the pull request and of each issue it closes, the first ten and the rest
  grep --quiet 'number title body url isDraft' "${FAKE_DIR}/gh.calls"
  grep --quiet 'number title createdAt url repository { nameWithOwner }' "${FAKE_DIR}/gh.calls"
  world gitlab
  jq '.[0].web_url = "https://gitlab.com/other/group/repo/-/issues/7"' "${FAKE_DIR}/closes.json" \
    > "${FAKE_DIR}/far.json" && mv "${FAKE_DIR}/far.json" "${FAKE_DIR}/closes.json"
  run fresh-call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.closes[].url' <<<"$output")" = https://gitlab.com/other/group/repo/-/issues/7 ]
}

@test "GitLab makes the branch for an issue as its issue page would, and a self-hosted GitLab is the setting" {
  world gitlab
  run call link-branch 7 main
  [ "$status" -eq 0 ]
  grep --quiet -- '--raw-field branch=7-fix-the-thing --raw-field ref=main' "${FAKE_DIR}/glab.calls"
  git remote set-url origin https://git.example.com/empowerite/example.git
  run provider
  [ "$status" -eq 1 ]
  mkdir .kit && printf 'forge: gitlab\n' > kit.yml
  run provider
  [ "$output" = "gitlab" ]
  run call repo-url
  [ "$output" = "https://git.example.com/empowerite/example" ]
}

@test "GitLab makes a branch for an issue whose title has no letter or digit of ASCII, <iid>-issue, as kit work names it" {
  world gitlab
  fixture issue.json <<<'{"iid": 7, "title": "修复登录问题", "state": "opened", "assignees": []}'
  run call link-branch 7 main
  [ "$status" -eq 0 ]
  grep --quiet -- '--raw-field branch=7-issue --raw-field ref=main' "${FAKE_DIR}/glab.calls"
}

@test "kit linked speaks the forge's words: a merge request on GitLab, its URL in the remedy" {
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/summary.md"
  GITLAB_CLOSES=none.json world gitlab
  run "${kit_root}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"merge request !3 is not linked to any issue"* ]]
  grep --quiet 'https://gitlab.com/empowerite/example/-/merge_requests/3' "${GITHUB_STEP_SUMMARY}"
  world gitlab
  run "${kit_root}/bin/kit" linked 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"merge request !3 is linked to #7"* ]]
}

@test "kit linked passes a change by a login the repository exempts, naming the exemption, and checks any other" {
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/summary.md"
  for forge in github gitlab
  do
    GITHUB_CLOSING=closing-none.json GITLAB_CLOSES=none.json world "${forge}"
    mkdir -p .kit && printf 'linked_exempt:\n  - ada\n' > kit.yml
    : > "${GITHUB_STEP_SUMMARY}"
    run "${kit_root}/bin/kit" linked 3
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 is ada's, exempt from the linked-issue check by kit.yml"* ]]
    grep --quiet "✅ .*3 is ada's, exempt" "${GITHUB_STEP_SUMMARY}"
    printf 'linked_exempt:\n  - bob\n' > kit.yml
    run "${kit_root}/bin/kit" linked 3
    [ "$status" -eq 1 ]
    [[ "$output" == *"3 is not linked to any issue"* ]]
    rm -r .kit
  done
}

@test "every provider lists its open issues in one shape, oldest first, with the assignees by login, the labels, the milestone and iteration, and the repository" {
  expected='[{"number":7,"ref":"#7","title":"Fix the thing","assignees":["bob"],'
  expected+='"labels":[{"name":"bug","color":"#d73a4a"}],"milestone":"v0.1","iteration":"Sprint 2","swimlane":null},'
  expected+='{"number":9,"ref":"#9","title":"Other thing","assignees":[],"labels":[],'
  expected+='"milestone":null,"iteration":null,"swimlane":null}]'
  for forge in github gitlab
  do
    world "${forge}"
    run call open-issues
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys --slurp \
      'map(del(.age, .createdAt, .source, .organization, .repository, .url))' \
      <<<"$output")" = "$(jq --compact-output --sort-keys . <<<"${expected}")" ]
    # each issue names the tracker that holds it, the forge's own, and where in it the issue is
    [ "$(jq --raw-output --slurp 'map(.source) | unique | join(" ")' <<<"$output")" = "${forge}" ]
    [ "$(jq --raw-output --slurp 'map("\(.organization)/\(.repository)") | unique | join(" ")' <<<"$output")" \
      = empowerite/example ]
  done
}

@test "GitHub reads each open issue's iteration from its projects, 100 a page; without read:project it has none" {
  fixture gh-issue-iterations-1.json <<'JSON'
{"data": {"repository": {"issues": {"pageInfo": {"hasNextPage": true, "endCursor": "c1"}, "nodes": [
  {"number": 9, "projectItems": {"nodes": [{"fieldValues": {"nodes": [{"title": "Sprint 1"}]}}]}}]}}}}
JSON
  GITHUB_ISSUE_ITERATIONS=gh-issue-iterations-1.json world github
  run --separate-stderr call open-issues
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output 'map([.number, .iteration])' <<<"$output")" = '[[7,"Sprint 2"],[9,"Sprint 1"]]' ]
  [ "$(grep --count 'projectItems' "${FAKE_DIR}/gh.calls")" -eq 2 ]
  forge-forget
  fixture gh-scope.txt <<<'gh: Your token has not been granted the required scopes to execute this query. The '"'"'projectItems'"'"' field requires one of the following scopes: ['"'"'read:project'"'"'], but your token has only been granted the: ['"'"'repo'"'"'] scopes. (INSUFFICIENT_SCOPES)'
  GITHUB_ISSUE_ITERATIONS='!1 gh-scope.txt' world github
  run --separate-stderr call open-issues
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output 'map([.number, .milestone, .iteration])' <<<"$output")" = '[[7,"v0.1",null],[9,null,null]]' ]
  [ -z "$stderr" ]
  forge-forget
  fixture gh-down.txt <<<'gh: HTTP 502: Bad Gateway'
  GITHUB_ISSUE_ITERATIONS='!1 gh-down.txt' world github
  run --separate-stderr call open-issues
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"run: cd "*" && gh auth status (the issues' iterations could not be read)"* ]]
  # a token that is forbidden the projects, as a fine-grained or installation token may be, has no iterations either
  forge-forget
  fixture gh-forbidden.txt <<<'gh: Resource not accessible by personal access token (FORBIDDEN)'
  GITHUB_ISSUE_ITERATIONS='!1 gh-forbidden.txt' world github
  run --separate-stderr call open-issues
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  # an issue in more projects than the 5 read, or with more field values than the 20, is not read as having none
  forge-forget
  fixture gh-cut.json <<'JSON'
{"data": {"repository": {"issues": {"pageInfo": {"hasNextPage": false}, "nodes": [
  {"number": 7, "projectItems": {"totalCount": 6, "nodes": [{"fieldValues": {"totalCount": 1, "nodes": [{}]}}]}}]}}}}
JSON
  GITHUB_ISSUE_ITERATIONS=gh-cut.json world github
  run --separate-stderr call open-issues
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"at most 5 projects and 20 field values of an issue"* ]]
}

@test "every provider reaches its tool with color forced off, so a desk's CLICOLOR_FORCE cannot color its data" {
  for forge in github gitlab
  do
    world "${forge}"
    CLICOLOR_FORCE=1 GH_FORCE_TTY=1 run call open-issues
    [ "$status" -eq 0 ]
    [ "$(jq --slurp --compact-output 'map(.number)' <<<"$output")" = "[7,9]" ]
  done
}

@test "every provider reads the caller's rate limits in one shape, GitHub's GraphQL first, and kit flow --quota lists them" {
  fixture limits.json <<<'{"resources": {"core": {"limit": 5000, "remaining": 4990, "reset": 1800000000},
    "graphql": {"limit": 5000, "remaining": 4871, "reset": 1800000300}, "search": {"limit": 30, "remaining": 30}}}'
  printf 'HTTP/2.0 200 OK\r\nRatelimit-Limit: 2000\r\nRatelimit-Name: throttle_authenticated_api\r\n%b\r\n\r\n%s\n' \
    'Ratelimit-Remaining: 1998\r\nRatelimit-Reset: 1800000060' '{"username": "ada"}' > "${FAKE_DIR}/user-headers.txt"
  world github
  route gh 'api rate_limit' limits.json
  run call quota
  [ "$status" -eq 0 ]
  [ "$output" = '{"forge":"github","limits":[{"name":"graphql","limit":5000,"remaining":4871,"reset":1800000300},{"name":"rest","limit":5000,"remaining":4990,"reset":1800000000}]}' ]
  run "${kit_root}/bin/kit" flow --quota
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output 'map(.forge) | join(" ")' <<<"$output")" = github ]
  world gitlab
  route glab 'api --include user' user-headers.txt
  run call quota
  [ "$status" -eq 0 ]
  [ "$output" = '{"forge":"gitlab","limits":[{"name":"throttle_authenticated_api","limit":2000,"remaining":1998,"reset":1800000060}]}' ]
}

@test "every provider reads a mark of each kind of its data, and GitHub's marks cost nothing while nothing changed" {
  printf 'HTTP/2.0 200 OK\r\nEtag: W/"%s"\r\n\r\n[]\n' i1 > "${FAKE_DIR}/issues-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n{}\n' r1 > "${FAKE_DIR}/runs-200.txt"
  printf 'HTTP/2.0 200 OK\r\netag: W/"%s"\r\n\r\n[]\n' v1 > "${FAKE_DIR}/releases-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n[]\n' m1 > "${FAKE_DIR}/milestones-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n[]\n' d1 > "${FAKE_DIR}/deployments-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n{}\n' e1 > "${FAKE_DIR}/environments-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n[]\n' c1 > "${FAKE_DIR}/code-200.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"%s"\r\n\r\n[]\n' b1 > "${FAKE_DIR}/dependabot-200.txt"
  printf 'HTTP/2.0 404 Not Found\r\n\r\n{"message":"Secret scanning is disabled on this repository."}\n' \
    > "${FAKE_DIR}/secret-404.txt"
  printf 'HTTP/2.0 304 Not Modified\r\n\r\n' > "${FAKE_DIR}/304.txt"
  local probe='alerts?sort=updated&direction=desc&per_page=1'
  world github
  route gh 'api --include --header If-None-Match: W/"i1" repos/{owner}/{repo}/issues*' '!1 >304.txt'
  route gh 'api --include --header If-None-Match: W/"r1" repos/{owner}/{repo}/actions/runs*' '!1 >304.txt'
  route gh 'api --include --header If-None-Match: W/"m1" repos/{owner}/{repo}/milestones*' '!1 >304.txt'
  route gh 'api --include --header If-None-Match: W/"d1" repos/{owner}/{repo}/deployments*' '!1 >304.txt'
  route gh 'api --include --header If-None-Match: W/"e1" repos/{owner}/{repo}/environments*' '!1 >304.txt'
  route gh 'api --include repos/{owner}/{repo}/issues?state=all&sort=updated&direction=desc&per_page=1' issues-200.txt
  route gh 'api --include repos/{owner}/{repo}/actions/runs?per_page=10' runs-200.txt
  route gh 'api --include*repos/{owner}/{repo}/releases?per_page=1' releases-200.txt
  route gh 'api --include*repos/{owner}/{repo}/milestones?state=all&per_page=100' milestones-200.txt
  route gh 'api --include repos/{owner}/{repo}/deployments?per_page=50' deployments-200.txt
  route gh 'api --include repos/{owner}/{repo}/environments?per_page=100' environments-200.txt
  # the alerts' mark is of the alert each scanner updated last, in any state, and off for a scanner that is off
  route gh "api --include --header If-None-Match: W/\"c1\" repos/{owner}/{repo}/code-scanning/${probe}" '!1 >304.txt'
  route gh "api --include --header If-None-Match: W/\"b1\" repos/{owner}/{repo}/dependabot/${probe}" '!1 >304.txt'
  route gh "api --include repos/{owner}/{repo}/code-scanning/${probe}" code-200.txt
  route gh "api --include repos/{owner}/{repo}/dependabot/${probe}" dependabot-200.txt
  route gh "api --include repos/{owner}/{repo}/secret-scanning/${probe}" '!1 >secret-404.txt'
  local marks='{"issues":"W/\"i1\"","runs":"W/\"r1\"","releases":"W/\"v1\"","milestones":"W/\"m1\"",'
  marks+='"deployments":"W/\"d1\"","environments":"W/\"e1\"","alerts":"W/\"c1\" W/\"b1\" off"}'
  run call marks
  [ "$status" -eq 0 ]
  [ "$output" = "${marks}" ]
  # the second read sends each ETag kept, and a 304 keeps the mark
  : > "${FAKE_DIR}/gh.calls"
  run call marks
  [ "$status" -eq 0 ]
  [ "$output" = "${marks}" ]
  [ "$(grep --count 'If-None-Match' "${FAKE_DIR}/gh.calls")" -eq 8 ]
  # a request a kind, and one a scanner that answers, none asked twice: the scanner off is not asked again yet
  [ "$(grep --count '^api --include' "${FAKE_DIR}/gh.calls")" -eq 8 ]
  ! grep --quiet 'secret-scanning' "${FAKE_DIR}/gh.calls"
  # the kinds named are the only ones read, in the order named
  : > "${FAKE_DIR}/gh.calls"
  run call marks releases issues
  [ "$status" -eq 0 ]
  [ "$output" = '{"releases":"W/\"v1\"","issues":"W/\"i1\""}' ]
  [ "$(grep --count '^api --include' "${FAKE_DIR}/gh.calls")" -eq 2 ]
  # a change gives a new ETag, which is the new mark
  printf 'HTTP/2.0 200 OK\r\nEtag: W/"%s"\r\n\r\n[]\n' i2 > "${FAKE_DIR}/issues-200.txt"
  printf '%s\n' 'api --include --header If-None-Match: W/"i1" repos/{owner}/{repo}/issues*'$'\t''issues-200.txt' \
    > "${FAKE_DIR}/routes.tmp" && grep --invert-match --fixed-strings 'W/"i1"' "${FAKE_DIR}/gh.routes" \
    >> "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
  [ "$(call marks | jq --raw-output .issues)" = 'W/"i2"' ]
  # GitLab's marks say what its newest items say of when they changed
  world gitlab
  local p='projects/empowerite%2Fexample'
  fixture gl-issues.json <<<'[{"iid": 7, "updated_at": "2026-11-01T09:00:00.000Z"}]'
  fixture gl-mrs.json <<<'[{"iid": 3, "updated_at": "2026-11-02T09:00:00.000Z"}]'
  fixture gl-pipelines.json <<<'[{"id": 11, "status": "success", "updated_at": "2026-11-03T09:00:00.000Z"}]'
  fixture gl-releases.json <<<'[{"tag_name": "v1", "released_at": "2026-11-04T09:00:00.000Z"}]'
  fixture gl-milestones.json <<<'[{"iid": 2, "updated_at": "2026-11-05T09:00:00.000Z"}]'
  fixture gl-deployments.json <<<'[{"id": 9, "status": "success", "updated_at": "2026-11-06T09:00:00.000Z"}]'
  fixture gl-environments.json <<<'[{"id": 1, "name": "production", "state": "available", "updated_at": "2026-11-07"}]'
  route glab "api ${p}/issues?order_by=updated_at&sort=desc&per_page=1" gl-issues.json
  route glab "api ${p}/merge_requests?order_by=updated_at&sort=desc&per_page=1" gl-mrs.json
  route glab "api ${p}/pipelines?per_page=10" gl-pipelines.json
  route glab "api ${p}/releases?per_page=1" gl-releases.json
  route glab "api ${p}/milestones?sort=updated_desc&per_page=1" gl-milestones.json
  route glab "api ${p}/deployments?order_by=updated_at&sort=desc&per_page=1" gl-deployments.json
  route glab "api ${p}/environments?per_page=100" gl-environments.json
  run call marks
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.issues, .runs, .releases, .milestones, .deployments, .environments, .alerts' <<<"$output")" = \
    '[[7,"2026-11-01T09:00:00.000Z"],[3,"2026-11-02T09:00:00.000Z"]]
[[11,"success","2026-11-03T09:00:00.000Z"]]
[["v1","2026-11-04T09:00:00.000Z"]]
[[2,"2026-11-05T09:00:00.000Z"],[7,"2026-11-01T09:00:00.000Z"]]
[[9,"success","2026-11-06T09:00:00.000Z"]]
[[1,"production","available","2026-11-07"]]
{"open":{"critical":0,"high":1,"medium":0,"low":0,"info":0,"unknown":0},'\
'"dismissed":{"critical":0,"high":1,"medium":0,"low":0,"info":0,"unknown":0}}' ]
}

@test "GitHub's writes that print nothing say why they failed, once, and print no token and no response body" {
  world github
  fixture refused.txt <<'TXT'
GraphQL: Could not resolve to an Issue with the number of 7. (repository.issue)
{"message": "Resource not accessible by personal access token", "documentation_url": "https://docs.github.com/rest"}
TXT
  fixture leaked.txt <<<'HTTP 401: Bad credentials (token ghp_0123456789abcdefghijklmnopqrstuvwxyz0123 was refused)'
  fixture long.txt <<<"$(printf 'z%.0s' $(seq 1 600))"
  local -a writes=('issue-assign 7 ada' 'issue-unassign 7 bob' 'issue-close 7 completed' 'issue-comment 7 hello'
    'issue-add-sub 7 9' 'pr-ready 3' 'pr-set-title 3 New' 'pr-label-add 3 bug' 'pr-label-remove 3 bug' 'pr-set-body 3 Body')
  local write
  for write in "${writes[@]}"
  do
    : > "${FAKE_DIR}/gh.routes"
    route gh '*' '!1 refused.txt'
    # shellcheck disable=SC2086  # the call and its arguments are words
    run --separate-stderr call ${write}
    [ "$status" -eq 1 ] || { echo "${write}: ${status}"; false; }
    [ -z "$output" ] || { echo "${write}: ${output}"; false; }
    [ "$(wc -l <<<"${stderr}")" -eq 1 ] || { echo "${write}: ${stderr}"; false; }
    [[ "${stderr}" == '❌ run: '*'gh auth status ('*' failed: Resource not accessible by personal access token)' ]] \
      || { echo "${write}: ${stderr}"; false; }
  done
  # a token gh repeats is taken out, and a line that is not a message is cut short
  : > "${FAKE_DIR}/gh.routes"
  route gh '*' '!1 leaked.txt'
  run --separate-stderr call issue-comment 7 hello
  [[ "${stderr}" == *'(token <token> was refused)'* ]]
  [[ "${stderr}" != *ghp_* ]]
  : > "${FAKE_DIR}/gh.routes"
  route gh '*' '!1 long.txt'
  run --separate-stderr call pr-ready 3
  [ "$(grep --only-matching z <<<"${stderr#*gh auth status}" | wc -l)" -eq 200 ]
}

@test "GitLab reads the environments a mark is made from when they are larger than a command line may be" {
  world gitlab
  local p='projects/empowerite%2Fexample' big
  big=$(printf 'x%.0s' $(seq 1 15000))
  jq --null-input --compact-output --arg big "${big}" \
    '[range(100) as $i | {id: $i, name: "env\($i)", state: "available", updated_at: "2026-11-07", note: $big}]' \
    > "${FAKE_DIR}/gl-environments.json"
  route glab "api ${p}/environments?per_page=100" gl-environments.json
  run call marks environments
  [ "$status" -eq 0 ] || { echo "${output}"; false; }
  [ "$(jq --raw-output '.environments | fromjson | length' <<<"$output")" -eq 100 ]
}

@test "a provider that cannot read the rate limits says how to fix it, and kit flow --quota prints nothing" {
  world github
  route gh 'api rate_limit' '!1'
  run call quota
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh auth status"* ]]
  run bash -c '"$0" flow --quota 2>/dev/null' "${kit_root}/bin/kit"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "every provider lists its releases in one shape, newest first, with the kind, the latest, the page, the notes, and the assets" {
  # gh api --paginate prints each page's array after the one before
  fixture gh-releases.json <<'JSON'
[{"tag_name": "release/0.1.0-rc.6", "name": "kit 0.1.0-rc.6", "prerelease": true, "draft": false,
  "published_at": "2026-10-27T07:30:14Z", "created_at": "2026-10-27T07:30:14Z",
  "html_url": "https://example.test/release/0.1.0-rc.6", "body": "notes\r\n* one",
  "assets": [{"name": "kit.tar.gz", "browser_download_url": "https://example.test/kit.tar.gz"}]}]
[{"tag_name": "release/0.0.9", "name": "kit 0.0.9", "prerelease": false, "draft": false,
  "published_at": "2026-10-20T07:30:14Z", "created_at": "2026-10-20T07:30:14Z",
  "html_url": "https://example.test/release/0.0.9", "body": null, "assets": []},
 {"tag_name": "release/0.0.8", "name": "kit 0.0.8", "prerelease": false, "draft": false,
  "published_at": "2026-10-13T07:30:14Z", "created_at": "2026-10-13T07:30:14Z",
  "html_url": "https://example.test/release/0.0.8", "body": "", "assets": []}]
JSON
  # GitLab's own assets are its links; the sources it makes of every tag are no asset of the release's
  fixture gl-releases.json <<'JSON'
[{"tag_name": "release/0.1.0-rc.6", "name": "kit 0.1.0-rc.6", "released_at": "2026-10-27T07:30:14.000Z",
  "upcoming_release": false, "description": "notes\n* one",
  "_links": {"self": "https://example.test/release/0.1.0-rc.6"},
  "assets": {"count": 2, "sources": [{"format": "zip", "url": "https://example.test/source.zip"}],
             "links": [{"name": "kit.tar.gz", "url": "https://example.test/kit.tar.gz?raw",
                        "direct_asset_url": "https://example.test/kit.tar.gz"}]}},
 {"tag_name": "release/0.0.9", "name": "kit 0.0.9", "released_at": "2026-10-20T07:30:14.000Z",
  "upcoming_release": false, "description": null, "_links": {"self": "https://example.test/release/0.0.9"},
  "assets": {"count": 0, "sources": [], "links": []}},
 {"tag_name": "release/0.0.8", "name": "kit 0.0.8", "released_at": "2026-10-13T07:30:14.000Z",
  "upcoming_release": false, "_links": {"self": "https://example.test/release/0.0.8"}}]
JSON
  expected='[{"version":"0.1.0-rc.6","tag":"release/0.1.0-rc.6","name":"kit 0.1.0-rc.6","kind":"pre-release","latest":false,'
  expected+='"url":"https://example.test/release/0.1.0-rc.6","notes":"notes\n* one",'
  expected+='"assets":[{"name":"kit.tar.gz","url":"https://example.test/kit.tar.gz"}]},'
  expected+='{"version":"0.0.9","tag":"release/0.0.9","name":"kit 0.0.9","kind":"release","latest":true,'
  expected+='"url":"https://example.test/release/0.0.9","notes":"","assets":[]},'
  expected+='{"version":"0.0.8","tag":"release/0.0.8","name":"kit 0.0.8","kind":"release","latest":false,'
  expected+='"url":"https://example.test/release/0.0.8","notes":"","assets":[]}]'
  for forge in github gitlab
  do
    world "${forge}"
    route gh 'api --paginate repos/{owner}/{repo}/releases?per_page=100' gh-releases.json
    route glab 'api projects/empowerite%2Fexample/releases?per_page=100*' gl-releases.json
    run call releases
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys --slurp 'map(del(.age, .at))' <<<"$output")" \
      = "$(jq --compact-output --sort-keys . <<<"${expected}")" ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --slurp 'map(.age > 0) | all' <<<"$output")" = true ]
  done
}

@test "every provider lists its milestones in one shape: its number, state, due, issue counts, and page" {
  expected='{"number":2,"title":"v0.1","state":"open","due":1796083200,"open":3,"closed":2,'
  for forge in github gitlab
  do
    world "${forge}"
    run call milestones
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys 'del(.url)' <<<"$output")" \
      = "$(jq --compact-output --sort-keys . <<<"${expected%,}}")" ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --raw-output '.url | startswith("https://")' <<<"$output")" = true ]
  done
}

@test "every provider lists its iterations by start, in one shape, and a forge without them for this repository is off" {
  expected='{"id":"x","title":"Sprint 1","start":1793577600,"end":1794787199}'
  for forge in github gitlab
  do
    world "${forge}"
    run call iterations
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys 'del(.id, .url)' <<<"$(head -n 1 <<<"$output")")" \
      = "$(jq --compact-output --sort-keys 'del(.id)' <<<"${expected}")" ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --raw-output '.url | startswith("https://")' <<<"$(head -n 1 <<<"$output")")" = true ]
  done
  # GitHub's are those of its linked projects, oldest first, and none with no project linked
  world github
  run call iterations
  [ "$(jq --raw-output '.title' <<<"$output" | paste -sd, -)" = 'Sprint 1,Sprint 2' ]
  [ "$(jq --raw-output 'select(.title == "Sprint 2") | .end' <<<"$output")" = 1795996799 ]
  GITHUB_ITERATIONS=gh-iterations-none.json world github
  run call iterations
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # GitLab's tiers without iterations answer 403 or 404, which is off here
  for said in 403 404
  do
    printf 'glab: %s\n' "${said}" > "${FAKE_DIR}/gl-forbidden.txt"
    GITLAB_ITERATIONS='!1 gl-forbidden.txt' world gitlab
    run --separate-stderr call iterations
    [ "$status" -eq 3 ] || { echo "${said}: ${status}"; return 1; }
    [ -z "$output" ]
  done
  GITLAB_ITERATIONS='!1' world gitlab
  run call iterations
  [ "$status" -eq 1 ]
}

@test "every provider lists the changes merged last in one shape, and says when it stopped at 50" {
  local expected='{"number":2,"title":"Do the other thing","author":"bob","branch":"9-other",'
  expected+='"merged":1791018000,"by":"ada","named":["AB#12"]}'
  for forge in github gitlab
  do
    world "${forge}"
    run --separate-stderr call merged-prs
    [ "$status" -eq 0 ] || { echo "${forge}: ${stderr}"; return 1; }
    [ "$(jq --compact-output 'del(.url)' <<<"$output")" = "${expected}" ]
  done
  [ "$(jq --raw-output .url <<<"$output")" = 'https://gitlab.com/empowerite/example/-/merge_requests/2' ]
  grep --quiet 'pullRequests(states: MERGED, first: 50, orderBy: {field: UPDATED_AT, direction: DESC}) {' \
    "${FAKE_DIR}/gh.calls"
  # 51 merged changes on GitLab, merged last first, or GitHub's count past those it read, give the first 50, then
  # limited
  jq '[range(51) as $i | (50 - $i) as $m | .[0] | .iid = (60 - $i)
       | .merged_at = "2026-10-03T09:\(if $m < 10 then "0" else "" end)\($m):00Z"]' \
    "${FAKE_DIR}/gl-merged.json" | fixture gl-merged-51.json
  GITLAB_MERGED=gl-merged-51.json world gitlab
  run --separate-stderr call merged-prs
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output '[length, .[0].number, .[0].merged, .[49].number, .[50]]' <<<"$output")" \
    = '[51,60,1791021000,11,{"limited":50}]' ]
  # past the 50 GitHub read, a change merged before the oldest update among them may be missing, so one merged long ago
  # and updated since is left out, and limited counts those kept
  jq '.data.repository.pullRequests |= (.totalCount = 70 | .nodes += [.nodes[0] | .number = 1
       | .mergedAt = "2026-01-05T09:00:00Z" | .updatedAt = "2026-10-05T09:00:00Z"])' "${FAKE_DIR}/gh-merged.json" \
    | fixture gh-merged-70.json
  GITHUB_MERGED=gh-merged-70.json world github
  run --separate-stderr call merged-prs
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output 'map(.number // .)' <<<"$output")" = '[2,{"limited":1}]' ]
  grep --quiet 'totalCount nodes { number title url body headRefName mergedAt updatedAt author { login }' \
    "${FAKE_DIR}/gh.calls"
}

@test "a GitLab older than 17.2, which refuses order_by=merged_at, has its merged changes read by update instead" {
  local p='projects/empowerite%2Fexample'
  world gitlab
  fixture gl-order.txt <<<'glab: order_by does not have a valid value (HTTP 400)'
  # newest updated first: one merged long ago and updated since, then fifty merged and updated a minute apart
  jq '[(.[0] | .iid = 7 | .merged_at = "2026-01-05T09:00:00Z" | .updated_at = "2026-10-05T09:00:00Z"),
       (range(1; 51) as $i | (50 - $i) as $m | .[0] | .iid = (100 - $i)
        | .merged_at = "2026-10-03T09:\(if $m < 10 then "0" else "" end)\($m):00Z" | .updated_at = .merged_at)]' \
    "${FAKE_DIR}/gl-merged.json" | fixture gl-merged-by-update.json
  : > "${FAKE_DIR}/glab.routes"
  route glab 'api user' user.json
  route glab "api ${p}/merge_requests?state=merged&order_by=merged_at&per_page=51" '!1 gl-order.txt'
  route glab "api ${p}/merge_requests?state=merged&order_by=updated_at&sort=desc&per_page=51" gl-merged-by-update.json
  run --separate-stderr call merged-prs
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  # of the first 50 by update, those merged since the oldest update among them, merged last first, then limited
  [ "$(jq --slurp --compact-output '[length, .[0].number, .[48].number, .[49]]' <<<"$output")" \
    = '[50,99,51,{"limited":49}]' ]
  # any other refusal is no older GitLab: it fails, and asks nothing more
  fixture gl-denied.txt <<<'glab: 401 Unauthorized'
  : > "${FAKE_DIR}/glab.routes"
  route glab "api ${p}/merge_requests?state=merged&order_by=merged_at&per_page=51" '!1 gl-denied.txt'
  run --separate-stderr call merged-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && glab auth status (the merged merge requests could not be read)' ]]
  [ "$(grep -c 'order_by=updated_at' "${FAKE_DIR}/glab.calls")" -eq 1 ]
}

# delivery-github adds to world-github's routes what Delivery reads: artifact 13, kit-0.1.0.tar.gz, from run 103; the
# environment production, which asks ada to review and lets main deploy, beside staging, which asks nothing; and
# deployment 9 of release/0.1.0 to production, by ada, which succeeded.
delivery-github() {
  fixture gh-artifacts.json <<'JSON'
{"total_count": 1, "artifacts": [{"id": 13, "name": "kit-0.1.0.tar.gz", "size_in_bytes": 2048,
  "digest": "sha256:ab12", "expired": false, "created_at": "2026-10-01T10:00:00Z",
  "expires_at": "2026-12-30T10:00:00Z", "workflow_run": {"id": 103, "head_branch": "main", "head_sha": "8e817bf"},
  "archive_download_url": "https://api.github.com/repos/empowerite/example/actions/artifacts/13/zip"},
 {"id": 12, "name": "old.tar.gz", "size_in_bytes": 1024, "digest": null, "expired": true,
  "created_at": "2026-06-01T10:00:00Z", "expires_at": "2026-08-30T10:00:00Z", "workflow_run": {"id": 90},
  "archive_download_url": "https://api.github.com/repos/empowerite/example/actions/artifacts/12/zip"}]}
JSON
  fixture gh-environments.json <<'JSON'
[{"total_count": 2, "environments": [
  {"id": 1, "name": "production",
   "html_url": "https://github.com/empowerite/example/deployments/activity_log?environments_filter=production",
   "protection_rules": [
     {"id": 5, "type": "required_reviewers", "prevent_self_review": false,
      "reviewers": [{"type": "User", "reviewer": {"login": "ada", "id": 1}}]},
     {"id": 6, "type": "branch_policy"}],
   "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}},
  {"id": 2, "name": "staging",
   "html_url": "https://github.com/empowerite/example/deployments/activity_log?environments_filter=staging",
   "protection_rules": [], "deployment_branch_policy": null}]}]
JSON
  fixture gh-branch-policies.json <<'JSON'
{"total_count": 1, "branch_policies": [{"id": 1, "name": "main", "type": "branch"}]}
JSON
  fixture gh-deployments.json <<'JSON'
{"data": {"repository": {"url": "https://github.com/empowerite/example", "deployments": {"totalCount": 1, "nodes": [
  {"databaseId": 9, "environment": "production", "ref": {"name": "release/0.1.0"},
   "commitOid": "8e817bf000000000000000000000000000000000", "state": "ACTIVE", "createdAt": "2026-10-01T10:00:00Z",
   "creator": {"login": "ada"},
   "commit": {"url": "https://github.com/empowerite/example/commit/8e817bf000000000000000000000000000000000"},
   "latestStatus": {"state": "SUCCESS", "logUrl": "https://github.com/empowerite/example/actions/runs/103/job/1",
                    "environmentUrl": null}}]}}}}
JSON
  route gh 'api repos/{owner}/{repo}/actions/artifacts?per_page=100' "${GITHUB_ARTIFACTS:-gh-artifacts.json}"
  route gh 'api --paginate --slurp repos/{owner}/{repo}/environments?per_page=100' \
    "${GITHUB_ENVIRONMENTS:-gh-environments.json}"
  route gh 'api repos/{owner}/{repo}/environments/*/deployment-branch-policies?per_page=100' \
    "${GITHUB_BRANCH_POLICIES:-gh-branch-policies.json}"
}

# delivery-gitlab is delivery-github's world, seen through GitLab: job 13 of pipeline 103 kept kit-0.1.0.tar.gz, and
# job 12 kept nothing; production is a protected environment ada approves.
delivery-gitlab() {
  local p='projects/empowerite%2Fexample'
  fixture gl-jobs.json <<'JSON'
[{"id": 13, "name": "package", "status": "success", "created_at": "2026-10-01T09:58:00.000Z",
  "finished_at": "2026-10-01T10:00:00.000Z", "artifacts_file": {"filename": "kit-0.1.0.tar.gz", "size": 2048},
  "artifacts": [{"file_type": "archive", "size": 2048, "filename": "kit-0.1.0.tar.gz", "file_format": "zip"}],
  "artifacts_expire_at": "2026-12-30T10:00:00.000Z", "pipeline": {"id": 103},
  "web_url": "https://gitlab.com/empowerite/example/-/jobs/13"},
 {"id": 12, "name": "lint", "status": "success", "created_at": "2026-10-01T09:50:00.000Z",
  "finished_at": "2026-10-01T09:51:00.000Z", "artifacts": [], "artifacts_expire_at": null, "pipeline": {"id": 103},
  "web_url": "https://gitlab.com/empowerite/example/-/jobs/12"}]
JSON
  fixture gl-environments.json <<'JSON'
[{"id": 1, "name": "production", "slug": "production", "state": "available", "tier": "production",
  "external_url": null, "created_at": "2026-09-01T09:00:00.000Z", "updated_at": "2026-10-01T10:00:00.000Z"},
 {"id": 2, "name": "staging", "slug": "staging", "state": "available", "tier": "staging",
  "external_url": null, "created_at": "2026-09-01T09:00:00.000Z", "updated_at": "2026-10-01T10:00:00.000Z"}]
JSON
  fixture gl-protected.json <<'JSON'
[{"name": "production",
  "deploy_access_levels": [{"id": 12, "access_level": 40, "access_level_description": "Maintainers",
                            "user_id": null, "group_id": null, "group_inheritance_type": 0}],
  "required_approval_count": 0,
  "approval_rules": [{"id": 1, "user_id": 1, "group_id": null, "access_level": null,
                      "access_level_description": "ada", "required_approvals": 1, "group_inheritance_type": 0}]}]
JSON
  fixture gl-deployments.json <<'JSON'
[{"id": 9, "iid": 1, "ref": "release/0.1.0", "sha": "8e817bf000000000000000000000000000000000",
  "created_at": "2026-10-01T10:00:00.000Z", "updated_at": "2026-10-01T10:05:00.000Z", "status": "success",
  "user": {"username": "ada"}, "environment": {"id": 1, "name": "production", "external_url": null},
  "deployable": {"id": 13, "web_url": "https://gitlab.com/empowerite/example/-/jobs/13"}}]
JSON
  route glab "api ${p}/jobs?scope[]=success&per_page=100" "${GITLAB_JOBS:-gl-jobs.json}"
  route glab "api ${p}/environments?per_page=100 --paginate" gl-environments.json
  route glab "api ${p}/protected_environments?per_page=100 --paginate" "${GITLAB_PROTECTED:-gl-protected.json}"
  route glab "api ${p}/deployments?order_by=created_at&sort=desc&per_page=51" \
    "${GITLAB_DEPLOYMENTS:-gl-deployments.json}"
}

@test "every provider lists its artifacts in one shape, newest first, none expired, and says when it stopped" {
  local expected='{"id":13,"name":"kit-0.1.0.tar.gz","digest":"sha256:ab12","size":2048,"run":103,'
  expected+='"expires":1798624800}'
  for forge in github gitlab
  do
    world "${forge}"
    run --separate-stderr call artifacts
    [ "$status" -eq 0 ] || { echo "${forge}: ${stderr}"; return 1; }
    [ "$(jq --slurp 'length' <<<"$output")" -eq 1 ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --raw-output '.age > 0' <<<"$output")" = true ]
    # GitLab keeps no digest of an artifact that its API shows
    if [[ "${forge}" == github ]]
    then
      [ "$(jq --compact-output 'del(.age, .url)' <<<"$output")" = "${expected}" ]
      [ "$(jq --raw-output .url <<<"$output")" \
        = 'https://github.com/empowerite/example/actions/runs/103/artifacts/13' ]
    else
      # nor names an archive but by its job: most are artifacts.zip
      expected=${expected/'"sha256:ab12"'/null}
      expected=${expected/'"kit-0.1.0.tar.gz"'/'"package: kit-0.1.0.tar.gz"'}
      [ "$(jq --compact-output 'del(.age, .url)' <<<"$output")" = "${expected}" ]
      [ "$(jq --raw-output .url <<<"$output")" = 'https://gitlab.com/empowerite/example/-/jobs/13' ]
    fi
  done
  # GitHub's count past the page read, or a page of 100 of GitLab's jobs, says the list stopped at those drawn
  jq '.total_count = 150' "${FAKE_DIR}/gh-artifacts.json" | fixture gh-artifacts-150.json
  GITHUB_ARTIFACTS=gh-artifacts-150.json world github
  run --separate-stderr call artifacts
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output 'map(.id // .)' <<<"$output")" = '[13,{"limited":1}]' ]
  jq '[range(100) as $i | .[$i % 2] | .id = (200 - $i)]' "${FAKE_DIR}/gl-jobs.json" | fixture gl-jobs-100.json
  GITLAB_JOBS=gl-jobs-100.json world gitlab
  run --separate-stderr call artifacts
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output '[length, .[0].id, .[-1]]' <<<"$output")" = '[51,200,{"limited":50}]' ]
}

@test "every provider lists its environments in one shape: the protection, who approves, and the branches that deploy" {
  for forge in github gitlab
  do
    world "${forge}"
    run --separate-stderr call environments
    [ "$status" -eq 0 ] || { echo "${forge}: ${stderr}"; return 1; }
    [ "$(jq --raw-output '.name' <<<"$output" | paste -sd, -)" = 'production,staging' ]
    [ "$(jq --compact-output 'select(.name == "production") | .approvers' <<<"$output")" = '["ada"]' ]
    [ "$(jq --compact-output 'select(.name == "staging") | [.protection, .approvers, .branches]' <<<"$output")" \
      = '[[],[],null]' ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --raw-output 'select(.name == "production") | .url | startswith("https://")' <<<"$output")" = true ]
  done
  # GitLab keeps no branches an environment takes deployments from; who may deploy there is a protection of its own
  [ "$(jq --compact-output 'select(.name == "production") | [.protection, .branches, .url]' <<<"$output")" \
    = '[["deployers","reviewers"],null,"https://gitlab.com/empowerite/example/-/environments/1"]' ]
  world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call environments
  [ "$(jq --compact-output 'select(.name == "production") | [.protection, .branches]' <<<"$output")" \
    = '[["branches","reviewers"],["main"]]' ]
  # GitHub's branch policies are read only for an environment that has its own, by its name
  [ "$(grep -c 'deployment-branch-policies' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  grep --quiet 'environments/production/deployment-branch-policies' "${FAKE_DIR}/gh.calls"
  # a GitLab tier without protected environments, or a caller who may not read them, leaves the protection unknown
  for said in 403 404
  do
    printf 'glab: %s\n' "${said}" > "${FAKE_DIR}/gl-forbidden.txt"
    GITLAB_PROTECTED='!1 gl-forbidden.txt' world gitlab
    run --separate-stderr call environments
    [ "$status" -eq 0 ] || { echo "${said}: ${stderr}"; return 1; }
    [ "$(jq --compact-output '[.name, .protection, .approvers]' <<<"$output" | paste -sd, -)" \
      = '["production",null,null],["staging",null,null]' ]
  done
  GITLAB_PROTECTED='!1' world gitlab
  run --separate-stderr call environments
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"run: cd "*" && glab auth status (the protected environments could not be read)"* ]]
}

@test "GitHub reads the branch policies of 20 environments at most, and says the list stopped there" {
  world github
  jq '.[0].environments = [range(25) as $i | .[0].environments[0] | .name = "env-\(100 + $i)"]
      | .[0].total_count = 25' "${FAKE_DIR}/gh-environments.json" | fixture gh-environments-25.json
  GITHUB_ENVIRONMENTS=gh-environments-25.json world github
  run --separate-stderr call environments
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output '[length, .[0].name, .[19].name, .[20]]' <<<"$output")" \
    = '[21,"env-100","env-119",{"limited":20}]' ]
  [ "$(grep -c 'deployment-branch-policies' "${FAKE_DIR}/gh.calls")" -eq 20 ]
  # an environment with more branch policies than a page holds fails the read, as it would be partial
  jq '.total_count = 101' "${FAKE_DIR}/gh-branch-policies.json" | fixture gh-branch-policies-101.json
  GITHUB_BRANCH_POLICIES=gh-branch-policies-101.json world github
  run --separate-stderr call environments
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"kit reads at most 100 branch policies of an environment (the environments could not be read)"* ]]
}

@test "every provider lists its deployments in one shape, newest first, and says when it stopped at 50" {
  local expected='{"id":9,"environment":"production","ref":"release/0.1.0",'
  expected+='"sha":"8e817bf000000000000000000000000000000000","state":"success","actor":"ada"}'
  for forge in github gitlab
  do
    world "${forge}"
    run --separate-stderr call deployments
    [ "$status" -eq 0 ] || { echo "${forge}: ${stderr}"; return 1; }
    [ "$(jq --compact-output 'del(.age, .url, .commit)' <<<"$output")" = "${expected}" ] \
      || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --raw-output '.age > 0' <<<"$output")" = true ]
  done
  [ "$(jq --raw-output .url <<<"$output")" = 'https://gitlab.com/empowerite/example/-/jobs/13' ]
  [ "$(jq --raw-output .commit <<<"$output")" \
    = 'https://gitlab.com/empowerite/example/-/commit/8e817bf000000000000000000000000000000000' ]
  grep --quiet 'deployments(first: 50, orderBy: {field: CREATED_AT, direction: DESC}) { totalCount' \
    "${FAKE_DIR}/gh.calls"
  # 60 on GitHub, of which its read holds 50, or GitLab's 51st, give the 50 newest, then limited
  jq '.data.repository.deployments |= (.totalCount = 60
       | .nodes = [range(60) as $i | .nodes[0] | .databaseId = (100 - $i)])' "${FAKE_DIR}/gh-deployments.json" \
    | fixture gh-deployments-60.json
  GITHUB_DEPLOYMENTS=gh-deployments-60.json world github
  run --separate-stderr call deployments
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output '[length, .[0].id, .[49].id, .[50]]' <<<"$output")" = '[51,100,51,{"limited":50}]' ]
  jq '[range(51) as $i | .[0] | .id = (100 - $i)]' "${FAKE_DIR}/gl-deployments.json" | fixture gl-deployments-51.json
  GITLAB_DEPLOYMENTS=gl-deployments-51.json world gitlab
  run --separate-stderr call deployments
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output '[length, .[0].id, .[49].id, .[50]]' <<<"$output")" = '[51,100,51,{"limited":50}]' ]
  # a GitHub answer with no repository could not be read
  fixture gh-null.json <<<'{"data": {"repository": null}}'
  GITHUB_DEPLOYMENTS=gh-null.json world github
  run --separate-stderr call deployments
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"the deployments could not be read"* ]]
}

# people-github adds to world-github's routes what People reads: ada is an admin, bob may write, and so may
# dependabot[bot], a bot; the team core may write, ada and bob its members; and four bots acted: dependabot opened a
# change that was merged, github-actions[bot] committed, Copilot's agent committed, as copilot-swe-agent[bot], and
# opened a change, and Copilot's reviewer reviewed it. A commit by no user GitHub knows, and a review by a deleted
# account, are no one's.
people-github() {
  fixture gh-collaborators.json <<'JSON'
[[{"login": "ada", "id": 1, "type": "User", "name": "Ada", "role_name": "admin",
   "permissions": {"admin": true, "maintain": true, "push": true, "triage": true, "pull": true}},
  {"login": "bob", "id": 2, "type": "User", "role_name": "write",
   "permissions": {"admin": false, "maintain": false, "push": true, "triage": true, "pull": true}},
  {"login": "dependabot[bot]", "id": 3, "type": "Bot", "name": null, "role_name": "write",
   "permissions": {"admin": false, "maintain": false, "push": true, "triage": true, "pull": true}}]]
JSON
  fixture gh-teams.json <<'JSON'
[{"id": 5, "slug": "core", "name": "Core", "permission": "push",
  "html_url": "https://github.com/orgs/empowerite/teams/core"}]
JSON
  fixture gh-team-members.json <<'JSON'
{"data": {"organization": {"t0": {"members": {"totalCount": 2, "nodes": [{"login": "ada"}, {"login": "bob"}]}}}}}
JSON
  fixture gh-bots.json <<'JSON'
{"data": {"repository": {
  "defaultBranchRef": {"target": {"history": {"nodes": [
    {"committedDate": "2026-10-01T09:00:00Z",
     "author": {"name": "github-actions[bot]", "user": {"login": "github-actions[bot]", "__typename": "User"}}},
    {"committedDate": "2026-09-30T09:00:00Z",
     "author": {"name": "copilot-swe-agent[bot]", "user": {"login": "Copilot", "__typename": "User"}}},
    {"committedDate": "2026-09-29T09:00:00Z", "author": {"name": "someone", "user": null}},
    {"committedDate": "2026-09-28T09:00:00Z", "author": null},
    {"committedDate": "2026-09-27T09:00:00Z",
     "author": {"name": "Ada", "user": {"login": "ada", "__typename": "User"}}}]}}},
  "open": {"nodes": [
    {"createdAt": "2026-10-03T10:00:00Z",
     "author": {"__typename": "Bot", "login": "copilot-swe-agent", "url": "https://github.com/apps/copilot-swe-agent"},
     "latestReviews": {"nodes": [
       {"submittedAt": "2026-10-01T00:00:00Z", "author": {"__typename": "Bot", "login": "copilot-pull-request-reviewer",
        "url": "https://github.com/apps/copilot-pull-request-reviewer"}},
       {"submittedAt": "2026-10-04T00:00:00Z", "author": null}]}}]},
  "merged": {"nodes": [
    {"createdAt": "2026-10-02T09:00:00Z",
     "author": {"__typename": "Bot", "login": "dependabot", "url": "https://github.com/apps/dependabot"},
     "latestReviews": {"nodes": [
       {"submittedAt": "2026-10-02T10:00:00Z", "author": {"__typename": "User", "login": "bob",
        "url": "https://github.com/bob"}}]}},
    {"createdAt": "2026-09-01T09:00:00Z", "author": null, "latestReviews": null}]}}}}
JSON
  route gh 'api --paginate --slurp repos/{owner}/{repo}/collaborators?per_page=100' \
    "${GITHUB_COLLABORATORS:-gh-collaborators.json}"
  route gh 'api repos/{owner}/{repo}/teams?per_page=21' "${GITHUB_TEAMS:-gh-teams.json}"
  route gh 'api graphql*team(slug:*' "${GITHUB_TEAM_MEMBERS:-gh-team-members.json}"
  route gh 'api graphql*history(first: 100)*' "${GITHUB_BOTS:-gh-bots.json}"
}

# people-gitlab is people-github's world, seen through GitLab: ada is the owner, bob a developer, inherited too as a
# reporter, and project_1_bot_3f2a, a project access token's bot, a maintainer; the group empowerite/core, shared with
# the project as developers, holds ada and bob.
people-gitlab() {
  fixture gl-members.json <<'JSON'
{"data": {"project": {"projectMembers": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
  {"accessLevel": {"integerValue": 50, "stringValue": "OWNER"}, "user": {"username": "ada", "name": "Ada",
   "bot": false, "lastActivityOn": "2026-10-03", "webUrl": "https://gitlab.com/ada"}},
  {"accessLevel": {"integerValue": 20, "stringValue": "REPORTER"}, "user": {"username": "bob", "name": "Bob",
   "bot": false, "lastActivityOn": null, "webUrl": "https://gitlab.com/bob"}},
  {"accessLevel": {"integerValue": 30, "stringValue": "DEVELOPER"}, "user": {"username": "bob", "name": "Bob",
   "bot": false, "lastActivityOn": null, "webUrl": "https://gitlab.com/bob"}},
  {"accessLevel": {"integerValue": 40, "stringValue": "MAINTAINER"}, "user": {"username": "project_1_bot_3f2a",
   "name": "deploy", "bot": true, "lastActivityOn": "2026-10-01", "webUrl": "https://gitlab.com/project_1_bot_3f2a"}},
  {"accessLevel": null, "user": null}]}}}}
JSON
  fixture gl-project.json <<'JSON'
{"id": 1, "path_with_namespace": "empowerite/example", "shared_with_groups": [
  {"group_id": 5, "group_name": "core", "group_full_path": "empowerite/core", "group_access_level": 30,
   "expires_at": null}]}
JSON
  fixture gl-group-members.json <<'JSON'
{"data": {"g0": {"webUrl": "https://gitlab.com/groups/empowerite/core", "groupMembers": {
  "pageInfo": {"hasNextPage": false}, "nodes": [{"user": {"username": "ada"}}, {"user": {"username": "bob"}}]}}}}
JSON
  route glab 'api graphql*projectMembers*' "${GITLAB_MEMBERS:-gl-members.json}"
  route glab 'api projects/empowerite%2Fexample' "${GITLAB_PROJECT:-gl-project.json}"
  route glab 'api graphql*groupMembers*' "${GITLAB_GROUP_MEMBERS:-gl-group-members.json}"
}

@test "every provider lists who has access in one shape: each one's name, role, and kind, a bot's kind bot" {
  world github
  run --separate-stderr call collaborators
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.login, .name, .role, .kind]' <<<"$output" | paste -sd, -)" \
    = '["ada","Ada","admin","user"],["bob",null,"write","user"],["dependabot[bot]",null,"write","bot"]' ]
  # GitLab names each role as GitLab does, and a member inherited too has the higher of the two
  world gitlab
  run --separate-stderr call collaborators
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.login, .name, .role, .kind]' <<<"$output" | paste -sd, -)" \
    = '["ada","Ada","owner","user"],["bob","Bob","developer","user"],'\
'["project_1_bot_3f2a","deploy","maintainer","bot"]' ]
  grep --quiet 'relations: \[DIRECT, INHERITED, INVITED_GROUPS, SHARED_INTO_ANCESTORS\]' "${FAKE_DIR}/glab.calls"
}

@test "GitHub shows who has access only to who may push, and its teams to some: each refusal names an admin" {
  fixture gh-push.txt <<<'gh: Must have push access to view repository collaborators. (HTTP 403)'
  GITHUB_COLLABORATORS='!1 gh-push.txt' world github
  run --separate-stderr call collaborators
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  local ask='❌ ask an admin of empowerite/example for write access: GitHub shows'
  [ "$stderr" = "${ask} who has access only to who may push (the collaborators could not be read)" ]
  # GitHub says not why it hides a repository's teams, so the line claims no role
  fixture gh-404.txt <<<'gh: Not Found (HTTP 404)'
  GITHUB_TEAMS='!1 gh-404.txt' world github
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  local hidden="❌ GitHub shows a repository's teams only to some who can reach it; ask an admin of empowerite/example"
  [ "$stderr" = "${hidden} (the teams could not be read)" ]
  # a collaborators list GitHub does not find, as for a token without repo on a private one, is no refusal to push
  GITHUB_COLLABORATORS='!1 gh-404.txt' world github
  run --separate-stderr call collaborators
  [ "$status" -eq 1 ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the collaborators could not be read)' ]]
}

@test "every provider lists the teams with access in one shape: the role and the members, 20 teams at most" {
  world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"team":"core","name":"Core","role":"write","members":["ada","bob"],'\
'"url":"https://github.com/orgs/empowerite/teams/core"}' ]
  # the members of every team come in one GraphQL request, the organization's, each team's slug as it is
  [ "$(grep -c '^api graphql' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  grep --quiet -- '--raw-field org=empowerite --raw-field t0=core ' "${FAKE_DIR}/gh.calls"
  world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"team":"empowerite/core","name":"core","role":"developer","members":["ada","bob"],'\
'"url":"https://gitlab.com/groups/empowerite/core"}' ]
  # 25 teams on GitHub, of which kit asks for 21, or 25 groups shared with a GitLab project, give the first 20
  jq '[range(21) as $i | .[0] | .slug = "t\(100 + $i)"]' "${FAKE_DIR}/gh-teams.json" | fixture gh-teams-21.json
  jq '.data.organization = ([range(20) as $i | {key: "t\($i)", value: .data.organization.t0}] | from_entries)' \
    "${FAKE_DIR}/gh-team-members.json" | fixture gh-team-members-20.json
  GITHUB_TEAMS=gh-teams-21.json GITHUB_TEAM_MEMBERS=gh-team-members-20.json world github
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output '[length, .[0].team, .[19].team, .[20]]' <<<"$output")" \
    = '[21,"t100","t119",{"limited":20}]' ]
  jq '.shared_with_groups = [range(25) as $i | .shared_with_groups[0] | .group_full_path = "empowerite/g\(100 + $i)"]' \
    "${FAKE_DIR}/gl-project.json" | fixture gl-project-25.json
  jq '.data = ([range(20) as $i | {key: "g\($i)", value: .data.g0}] | from_entries)' \
    "${FAKE_DIR}/gl-group-members.json" | fixture gl-group-members-20.json
  GITLAB_PROJECT=gl-project-25.json GITLAB_GROUP_MEMBERS=gl-group-members-20.json world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output '[length, .[0].team, .[19].team, .[20]]' <<<"$output")" \
    = '[21,"empowerite/g100","empowerite/g119",{"limited":20}]' ]
}

@test "a team with more than 100 members, or one the caller cannot see, says so, and a user's repository has none" {
  world github
  # a team past its first 100 members is drawn with them, and the list says it stopped
  jq '.data.organization.t0.members.totalCount = 150' "${FAKE_DIR}/gh-team-members.json" \
    | fixture gh-team-members-150.json
  GITHUB_TEAM_MEMBERS=gh-team-members-150.json world github
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output 'map(.members // .)' <<<"$output")" = '[["ada","bob"],{"limited":1}]' ]
  world gitlab
  jq '.data.g0.groupMembers.pageInfo.hasNextPage = true' "${FAKE_DIR}/gl-group-members.json" \
    | fixture gl-group-members-more.json
  GITLAB_GROUP_MEMBERS=gl-group-members-more.json world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output 'map(.members // .)' <<<"$output")" = '[["ada","bob"],{"limited":1}]' ]
  # a team the caller cannot see has its members unknown, null
  fixture gh-team-hidden.json <<<'{"data": {"organization": {"t0": null}}}'
  GITHUB_TEAM_MEMBERS=gh-team-hidden.json world github
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.team, .members]' <<<"$output")" = '["core",null]' ]
  fixture gl-group-hidden.json <<<'{"data": {"g0": null}}'
  GITLAB_GROUP_MEMBERS=gl-group-hidden.json world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.team, .members, .url]' <<<"$output")" \
    = '["empowerite/core",null,"https://gitlab.com/groups/empowerite/core"]' ]
  # a repository a user owns, or a project shared with no group, has no teams, and asks no more
  fixture none.json <<<'[]'
  GITHUB_TEAMS=none.json world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ -z "$output" ]
  ! grep --quiet '^api graphql' "${FAKE_DIR}/gh.calls"
  world gitlab
  jq '.shared_with_groups = []' "${FAKE_DIR}/gl-project.json" | fixture gl-project-alone.json
  GITLAB_PROJECT=gl-project-alone.json world gitlab
  : > "${FAKE_DIR}/glab.calls"
  run --separate-stderr call teams
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ -z "$output" ]
  ! grep --quiet '^api graphql' "${FAKE_DIR}/glab.calls"
}

@test "a team kit cannot name, or a members answer with no data, fails the teams, and never gives one another's" {
  # a team with no slug, or a group with no path, would give the teams after it the members of the one before
  world github
  jq '.[1:] = [.[0] | .slug = "other"] | .[0].slug = null' "${FAKE_DIR}/gh-teams.json" | fixture gh-teams-nameless.json
  GITHUB_TEAMS=gh-teams-nameless.json world github
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the teams could not be read)' ]]
  world gitlab
  jq '.shared_with_groups[0].group_full_path = null' "${FAKE_DIR}/gl-project.json" | fixture gl-project-nameless.json
  GITLAB_PROJECT=gl-project-nameless.json world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && glab auth status (the teams could not be read)' ]]
  # an answer of errors alone, with no data, could not be read
  fixture gql-errors.json <<<'{"errors": [{"message": "Internal server error"}]}'
  GITHUB_TEAM_MEMBERS=gql-errors.json world github
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the teams could not be read)' ]]
  GITLAB_GROUP_MEMBERS=gql-errors.json world gitlab
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && glab auth status (the teams could not be read)' ]]
}

@test "GitHub's team members need the read:org scope, and name the command that adds it" {
  local said="gh: Your token has not been granted the required scopes to execute this query. The 'team' field"
  said+=" requires one of the following scopes: ['read:org'], but your token has only been granted the: ['repo']"
  said+=" scopes. (INSUFFICIENT_SCOPES)"
  printf '%s\n' "${said}" | fixture gh-org.txt
  GITHUB_TEAM_MEMBERS='!1 gh-org.txt' world github
  run --separate-stderr call teams
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth refresh --scopes read:org (the teams could not be read)' ]]
}

@test "every provider lists the bots that acted, in one shape: what each did, and when last, newest first" {
  world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call bots
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  local expected='{"login":"copilot-swe-agent[bot]","acted":["commit","change"],"last":1791021600,'
  expected+='"url":"https://github.com/apps/copilot-swe-agent"}'
  expected+=$'\n''{"login":"dependabot[bot]","acted":["change"],"last":1790931600,'
  expected+='"url":"https://github.com/apps/dependabot"}'
  expected+=$'\n''{"login":"github-actions[bot]","acted":["commit"],"last":1790845200,"url":null}'
  expected+=$'\n''{"login":"copilot-pull-request-reviewer[bot]","acted":["review"],"last":1790812800,'
  expected+='"url":"https://github.com/apps/copilot-pull-request-reviewer"}'
  [ "$output" = "${expected}" ]
  # one GraphQL request reads the commits, the changes, and their reviews
  [ "$(grep -c '^api graphql' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  grep --quiet 'history(first: 100)' "${FAKE_DIR}/gh.calls"
  grep --quiet 'pullRequests(states: MERGED, first: 50, orderBy: {field: UPDATED_AT, direction: DESC})' \
    "${FAKE_DIR}/gh.calls"
  # GitLab's are its bot users among the members, when they last acted, and no more
  world gitlab
  run --separate-stderr call bots
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"login":"project_1_bot_3f2a","acted":null,"last":1790812800,'\
'"url":"https://gitlab.com/project_1_bot_3f2a"}' ]
  # more open changes than the 100 read, or a change with more reviewers than the 20 read, say the list stopped there
  for cut in '.data.repository.open.totalCount = 150' '.data.repository.merged.nodes[0].latestReviews.totalCount = 21'
  do
    jq "${cut}" "${FAKE_DIR}/gh-bots.json" | fixture gh-bots-cut.json
    GITHUB_BOTS=gh-bots-cut.json world github
    run --separate-stderr call bots
    [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
    [ "$(jq --slurp --compact-output '[length, .[-1]]' <<<"$output")" = '[5,{"limited":4}]' ] \
      || { echo "${cut}: ${output}"; return 1; }
  done
  grep --quiet 'latestReviews(first: 20) { totalCount' "${FAKE_DIR}/gh.calls"
  # a repository with no commits has none of them, and an answer with no repository could not be read
  jq '.data.repository.defaultBranchRef = null' "${FAKE_DIR}/gh-bots.json" | fixture gh-bots-empty.json
  GITHUB_BOTS=gh-bots-empty.json world github
  run --separate-stderr call bots
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --raw-output .login <<<"$output" | paste -sd, -)" \
    = 'copilot-swe-agent[bot],dependabot[bot],copilot-pull-request-reviewer[bot]' ]
  fixture gh-null.json <<<'{"data": {"repository": null}}'
  GITHUB_BOTS=gh-null.json world github
  run --separate-stderr call bots
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the bots could not be read)' ]]
}

@test "GitLab's members follow the cursor past a page, and an answer with no project fails the call" {
  world gitlab
  jq '.data.project.projectMembers.pageInfo = {hasNextPage: true, endCursor: "c1"}
      | .data.project.projectMembers.nodes |= .[:1]' "${FAKE_DIR}/gl-members.json" | fixture gl-members-1.json
  jq '.data.project.projectMembers.nodes |= .[1:]' "${FAKE_DIR}/gl-members.json" | fixture gl-members-2.json
  : > "${FAKE_DIR}/glab.routes"
  route glab 'api graphql*after=c1*projectMembers*' gl-members-2.json
  route glab 'api graphql*projectMembers*' gl-members-1.json
  run --separate-stderr call collaborators
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --raw-output .login <<<"$output" | paste -sd, -)" = 'ada,bob,project_1_bot_3f2a' ]
  fixture gl-no-project.json <<<'{"data": {"project": null}}'
  GITLAB_MEMBERS=gl-no-project.json world gitlab
  run --separate-stderr call collaborators
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && glab auth status (the members could not be read)' ]]
}

@test "GitLab's milestones follow the cursor past a page, and a failing page fails the call" {
  world gitlab
  : > "${FAKE_DIR}/glab.routes"
  fixture gl-page1.json <<'JSON'
{"data": {"project": {"milestones": {"pageInfo": {"hasNextPage": true, "endCursor": "c1"}, "nodes": [
  {"iid": "1", "title": "a", "state": "closed", "dueDate": null, "webPath": "/o/e/-/milestones/1",
   "stats": {"totalIssuesCount": 1, "closedIssuesCount": 1}}]}}}}
JSON
  route glab 'api graphql*after=c1*' gl-milestones.json
  route glab 'api graphql*' gl-page1.json
  run call milestones
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.number' <<<"$output" | paste -sd, -)" = '1,2' ]
  [ "$(jq --raw-output 'select(.number == 2) | [.open, .closed, .url] | join(" ")' <<<"$output")" \
    = '3 2 https://gitlab.com/empowerite/example/-/milestones/2' ]
  : > "${FAKE_DIR}/glab.routes"
  route glab 'api graphql*' '!1'
  run --separate-stderr call milestones
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "GitHub's iterations need the read:project scope, and name the command that adds it; a partial read fails" {
  world github
  fixture gh-scope.txt <<<'gh: Your token has not been granted the required scopes to execute this query. The '"'"'id'"'"' field requires one of the following scopes: ['"'"'read:project'"'"'], but your token has only been granted the: ['"'"'repo'"'"'] scopes. (INSUFFICIENT_SCOPES)'
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' '!1 gh-scope.txt'
  run --separate-stderr call iterations
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"run: cd "*" && gh auth refresh --scopes read:project (the iterations could not be read)"* ]]
  [ "$(grep --count '❌' <<<"$stderr")" -eq 1 ]
  fixture gh-many.json <<'JSON'
{"data": {"repository": {"projectsV2": {"totalCount": 21, "nodes": [{"url": "u", "fields": {"totalCount": 1, "nodes": [{}]}}]}}}}
JSON
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' gh-many.json
  run --separate-stderr call iterations
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"at most 20 projects and 50 fields"* ]]
  fixture gh-wide.json <<'JSON'
{"data": {"repository": {"projectsV2": {"totalCount": 1, "nodes": [{"url": "u", "fields": {"totalCount": 51, "nodes": [{}]}}]}}}}
JSON
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' gh-wide.json
  run --separate-stderr call iterations
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"at most 20 projects"* ]]
  # an answer that is not the shape asked for is not a cap
  fixture gh-null.json <<<'{"data": {"repository": null}}'
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' gh-null.json
  run --separate-stderr call iterations
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"the iterations could not be read"* && "$stderr" != *"at most 20"* ]]
}

# runs-world <forge> is world's, with the runs, and the jobs of run 103. gh-runs.json and gl-pipelines.json hold every
# run the forge has, and each tool answers as its forge filters them: asked for a kind, those of that kind; asked for
# none, the 50 newest of any. GitLab's list does not say that a pipeline is a tag's, so its answers leave it out.
runs-world() {
  local dir=${FAKE_DIR} pipelines='api projects/empowerite%2Fexample/pipelines'
  world "$1"
  jq 'map(select(.event == "push" and .headBranch == "main"))' "${dir}/gh-runs.json" > "${dir}/gh-runs-default.json"
  jq 'map(select(.event == "push"))' "${dir}/gh-runs.json" > "${dir}/gh-runs-push.json"
  jq 'map(select(.event == "schedule"))' "${dir}/gh-runs.json" > "${dir}/gh-runs-schedule.json"
  jq 'map(select(.event == "workflow_dispatch"))' "${dir}/gh-runs.json" > "${dir}/gh-runs-manual.json"
  jq 'sort_by(.createdAt) | reverse | .[:50]' "${dir}/gh-runs.json" > "${dir}/gh-runs-any.json"
  route gh 'run list --event push --branch main --limit 20 --json *' gh-runs-default.json
  route gh 'run list --event schedule --limit 20 --json *' gh-runs-schedule.json
  route gh 'run list --event workflow_dispatch --limit 20 --json *' gh-runs-manual.json
  route gh 'run list --event push --limit 100 --json *' gh-runs-push.json
  route gh 'run list --limit 50 --json *' gh-runs-any.json
  route gh 'run view 103 --json jobs' gh-jobs.json
  jq 'map(select(.source == "push" and .ref == "main") | del(.tag))' "${dir}/gl-pipelines.json" > "${dir}/gl-default.json"
  jq 'map(select(.source == "push" and .tag == true) | del(.tag))' "${dir}/gl-pipelines.json" > "${dir}/gl-tags.json"
  jq 'map(select(.source == "schedule") | del(.tag))' "${dir}/gl-pipelines.json" > "${dir}/gl-schedule.json"
  jq 'map(select(.source == "web") | del(.tag))' "${dir}/gl-pipelines.json" > "${dir}/gl-web.json"
  jq 'sort_by(.created_at) | reverse | .[:50] | map(del(.tag))' "${dir}/gl-pipelines.json" > "${dir}/gl-any.json"
  route glab "${pipelines}?source=push&ref=main&per_page=20" gl-default.json
  route glab "${pipelines}?scope=tags&source=push&per_page=20" gl-tags.json
  route glab "${pipelines}?source=schedule&per_page=20" gl-schedule.json
  route glab "${pipelines}?source=web&per_page=20" gl-web.json
  route glab "${pipelines}?per_page=50" gl-any.json
  fixture gl-jobs-103.json <<'JSON'
[{"name": "ci", "status": "success", "started_at": "2026-10-01T10:00:03.000Z", "finished_at": "2026-10-01T10:03:33.000Z"},
 {"name": "lint", "status": "running", "started_at": "2026-10-01T10:00:03.000Z", "finished_at": null}]
JSON
  fixture gl-jobs-102.json <<'JSON'
[{"name": "ci", "status": "failed", "failure_reason": "script_failure", "started_at": "2026-10-01T09:00:00.000Z",
  "finished_at": "2026-10-01T09:04:00.000Z"}]
JSON
  route glab "${pipelines}/103/jobs?per_page=100*" gl-jobs-103.json
  route glab "${pipelines}/102/jobs?per_page=100*" gl-jobs-102.json
}

# runs-fixtures writes every run each forge has, the same six: a pull request's, a push to main, a push to the tag
# release/0.1.0, a scheduled run, a push to a branch, and a manual run; and the jobs of run 103. The checkout has the
# tag, as GitHub's list does not say a run is a tag's.
runs-fixtures() {
  git commit --quiet --allow-empty --message one && git tag release/0.1.0
  fixture gh-runs.json <<'JSON'
[{"databaseId": 104, "number": 50, "headSha": "aaaaaaa0000000000", "displayTitle": "title 104",
  "workflowName": "kit", "headBranch": "7-fix-the-thing", "event": "pull_request",
  "status": "completed", "conclusion": "success", "createdAt": "2026-10-01T11:00:00Z",
  "startedAt": "2026-10-01T11:00:00Z", "updatedAt": "2026-10-01T11:03:00Z", "url": "https://github.com/r/104"},
 {"databaseId": 99, "number": 45, "headSha": "5d376dd0000000000", "displayTitle": "title 99",
  "workflowName": "kit", "headBranch": "9-other", "event": "workflow_dispatch",
  "status": "completed", "conclusion": "cancelled", "createdAt": "2026-10-01T06:00:00Z",
  "startedAt": "2026-10-01T06:00:00Z", "updatedAt": "2026-10-01T06:00:42Z", "url": "https://github.com/r/99"},
 {"databaseId": 103, "number": 49, "headSha": "8e817bf0000000000", "displayTitle": "title 103",
  "workflowName": "kit", "headBranch": "main", "event": "push",
  "status": "completed", "conclusion": "success", "createdAt": "2026-10-01T10:00:00Z",
  "startedAt": "2026-10-01T10:00:00Z", "updatedAt": "2026-10-01T10:03:36Z", "url": "https://github.com/r/103"},
 {"databaseId": 102, "number": 48, "headSha": "1a2b3c40000000000", "displayTitle": "title 102",
  "workflowName": "kit", "headBranch": "release/0.1.0", "event": "push",
  "status": "completed", "conclusion": "failure", "createdAt": "2026-10-01T09:00:00Z",
  "startedAt": "2026-10-01T09:00:00Z", "updatedAt": "2026-10-01T09:04:02Z", "url": "https://github.com/r/102"},
 {"databaseId": 101, "number": 47, "headSha": "8e817bf0000000000", "displayTitle": "title 101",
  "workflowName": "kit", "headBranch": "main", "event": "schedule",
  "status": "in_progress", "conclusion": "", "createdAt": "2026-10-01T08:00:00Z",
  "startedAt": "2026-10-01T08:00:00Z", "updatedAt": "2026-10-01T08:01:00Z", "url": "https://github.com/r/101"},
 {"databaseId": 100, "number": 46, "headSha": "bbbbbbb0000000000", "displayTitle": "title 100",
  "workflowName": "kit", "headBranch": "9-other", "event": "push",
  "status": "completed", "conclusion": "success", "createdAt": "2026-10-01T07:00:00Z",
  "startedAt": "2026-10-01T07:00:00Z", "updatedAt": "2026-10-01T07:01:00Z", "url": "https://github.com/r/100"}]
JSON
  fixture gh-jobs.json <<'JSON'
{"jobs": [{"name": "ci", "status": "completed", "conclusion": "success",
           "startedAt": "2026-10-01T10:00:03Z", "completedAt": "2026-10-01T10:03:33Z", "steps": []},
          {"name": "lint", "status": "in_progress", "conclusion": "",
           "startedAt": "2026-10-01T10:00:03Z", "completedAt": "0001-01-01T00:00:00Z"}]}
JSON
  fixture gl-pipelines.json <<'JSON'
[{"id": 104, "iid": 50, "sha": "aaaaaaa0000000000",
  "name": "kit", "ref": "7-fix-the-thing", "source": "merge_request_event", "status": "success",
  "created_at": "2026-10-01T11:00:00.000Z", "updated_at": "2026-10-01T11:03:00.000Z",
  "web_url": "https://gl.com/p/104"},
 {"id": 103, "iid": 49, "sha": "8e817bf0000000000",
  "name": "kit", "ref": "main", "source": "push", "status": "success",
  "created_at": "2026-10-01T10:00:00.000Z", "updated_at": "2026-10-01T10:03:36.000Z",
  "web_url": "https://gl.com/p/103"},
 {"id": 102, "iid": 48, "sha": "1a2b3c40000000000",
  "name": "kit", "ref": "release/0.1.0", "source": "push", "status": "failed", "tag": true,
  "created_at": "2026-10-01T09:00:00.000Z", "updated_at": "2026-10-01T09:04:02.000Z",
  "web_url": "https://gl.com/p/102"},
 {"id": 101, "iid": 47, "sha": "8e817bf0000000000",
  "name": "kit", "ref": "main", "source": "schedule", "status": "running",
  "created_at": "2026-10-01T08:00:00.000Z", "updated_at": "2026-10-01T08:01:00.000Z",
  "web_url": "https://gl.com/p/101"},
 {"id": 100, "iid": 46, "sha": "bbbbbbb0000000000",
  "name": "kit", "ref": "9-other", "source": "push", "status": "success",
  "created_at": "2026-10-01T07:00:00.000Z", "updated_at": "2026-10-01T07:01:00.000Z",
  "web_url": "https://gl.com/p/100"},
 {"id": 99, "iid": 45, "sha": "5d376dd0000000000",
  "name": "kit", "ref": "9-other", "source": "web", "status": "canceled",
  "created_at": "2026-10-01T06:00:00.000Z", "updated_at": "2026-10-01T06:00:42.000Z",
  "web_url": "https://gl.com/p/99"}]
JSON
}

# runs-expected prints the four runs of runs-fixtures that no pull request owns, newest first, as either forge's
# runs call prints them, less its age, page, jobs, and title.
runs-expected() {
  local expected
  expected='[{"id":103,"number":49,"attempt":1,"workflow":"kit","branch":"main","tag":false,"event":"push",'
  expected+='"sha":"8e817bf","state":"passed","took":216},'
  expected+='{"id":102,"number":48,"attempt":1,"workflow":"kit","branch":"release/0.1.0","tag":true,"event":"push",'
  expected+='"sha":"1a2b3c4","state":"failed","took":242},'
  expected+='{"id":101,"number":47,"attempt":1,"workflow":"kit","branch":"main","tag":false,"event":"schedule",'
  expected+='"sha":"8e817bf","state":"running","took":null},'
  expected+='{"id":99,"number":45,"attempt":1,"workflow":"kit","branch":"9-other","tag":false,'
  expected+='"event":"workflow_dispatch","sha":"5d376dd","state":"cancelled","took":42}]'
  jq --compact-output --sort-keys . <<<"${expected}"
}

@test "every provider lists the runs not owned by any pull request in one shape, newest first, the newest with its jobs" {
  runs-fixtures
  for forge in github gitlab
  do
    runs-world "${forge}"
    run call runs
    [ "$status" -eq 0 ] || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq --compact-output --sort-keys 'map(del(.age, .url, .jobs, .title))' <<<"$output")" = "$(runs-expected)" ] \
      || { echo "${forge}: ${output}"; return 1; }
    [ "$(jq 'map(.age > 0 and (.url | startswith("https://"))) | all' <<<"$output")" = true ]
  done
  # GitLab's list gives no title; each of its newest runs carries its jobs, a call each, a failed job with the reason
  # GitLab gives, and a run whose jobs GitLab did not answer carries none
  [ "$(call runs | jq --compact-output 'map(.title)')" = '["","","",""]' ]
  [ "$(call runs | jq --compact-output 'map(.jobs)')" \
    = '[[{"name":"ci","state":"passed","took":210,"step":null},{"name":"lint","state":"running","took":null,"step":null}],'"\
"'[{"name":"ci","state":"failed","took":240,"step":"script_failure"}],[],[]]' ]
  # GitHub's runs carry their title, and the newest their jobs, a call each
  runs-world github
  [ "$(call runs | jq --compact-output 'map(.title)')" = '["title 103","title 102","title 101","title 99"]' ]
  : > "${FAKE_DIR}/gh.calls"
  [ "$(call runs | jq --compact-output '.[0].jobs')" \
    = '[{"name":"ci","state":"passed","took":210,"step":null},'"\
"'{"name":"lint","state":"running","took":null,"step":null}]' ]
  [ "$(grep -c '^run view ' "${FAKE_DIR}/gh.calls")" -eq 4 ]
}

@test "every provider asks its forge for the runs by kind, so 50 newer runs of pull requests take no run's place" {
  runs-fixtures
  # the 50 newest runs the forge has are pull requests', all newer than the push to main
  jq '[range(50) | {databaseId: (200 + .), number: (100 + .), headSha: "ccccccc0000000000", displayTitle: "a change",
                    workflowName: "kit", headBranch: "7-fix-the-thing", event: "pull_request", status: "completed",
                    conclusion: "success", createdAt: "2026-10-02T11:00:00Z", startedAt: "2026-10-02T11:00:00Z",
                    updatedAt: "2026-10-02T11:03:00Z", url: "https://github.com/r/\(200 + .)"}] + .' \
    "${FAKE_DIR}/gh-runs.json" > "${FAKE_DIR}/gh-more.json"
  mv "${FAKE_DIR}/gh-more.json" "${FAKE_DIR}/gh-runs.json"
  jq '[range(50) | {id: (200 + .), iid: (100 + .), sha: "ccccccc0000000000", name: "kit", ref: "7-fix-the-thing",
                    source: "merge_request_event", status: "success", created_at: "2026-10-02T11:00:00.000Z",
                    updated_at: "2026-10-02T11:03:00.000Z", web_url: "https://gl.com/p/\(200 + .)"}] + .' \
    "${FAKE_DIR}/gl-pipelines.json" > "${FAKE_DIR}/gl-more.json"
  mv "${FAKE_DIR}/gl-more.json" "${FAKE_DIR}/gl-pipelines.json"
  for forge in github gitlab
  do
    runs-world "${forge}"
    run --separate-stderr call runs
    [ "$status" -eq 0 ]
    [ "$(jq --compact-output --sort-keys 'map(del(.age, .url, .jobs, .title))' <<<"$output")" = "$(runs-expected)" ] \
      || { echo "${forge}: ${output}"; return 1; }
  done
  # GitHub is asked four times: the pushes to main, the scheduled, the manual, and the pushes to any ref, for the tags
  [ "$(grep -c '^run list ' "${FAKE_DIR}/gh.calls")" -eq 4 ]
  ! grep --quiet '^run list --limit 50 ' "${FAKE_DIR}/gh.calls"
  # GitLab is asked for a tag's pipelines by their scope, and knows each for a tag's by that, as its list does not say
  grep --quiet 'pipelines?scope=tags&source=push&per_page=20' "${FAKE_DIR}/glab.calls"
  ! grep --quiet 'pipelines?per_page=50' "${FAKE_DIR}/glab.calls"
  git tag --delete release/0.1.0 >/dev/null
  runs-world gitlab
  [ "$(call runs | jq --compact-output 'map(select(.tag) | .branch)')" = '["release/0.1.0"]' ]
  # a default branch is written into the address as an address takes it
  git symbolic-ref refs/remotes/origin/HEAD 'refs/remotes/origin/rel#1'
  route glab 'api projects/empowerite%2Fexample/pipelines?source=push&ref=rel%231&per_page=20' gl-schedule.json
  run --separate-stderr call runs
  [ "$status" -eq 0 ]
  grep --quiet 'pipelines?source=push&ref=rel%231&per_page=20' "${FAKE_DIR}/glab.calls"
}

@test "every provider reads its open changes once a minute: a second call takes the snapshot, an old one is read again" {
  local file
  for forge in github gitlab
  do
    world "${forge}"
    : > "${FAKE_DIR}/gh.calls"
    : > "${FAKE_DIR}/glab.calls"
    first=$(call open-prs)
    [ "$(call open-prs)" = "${first}" ]
    [ "$(reads "${forge}")" -eq 1 ] || { echo "${forge}: $(reads "${forge}") reads"; return 1; }
    # a snapshot is kept under the second its read began; one older than a minute is read again, its ages anew
    file=$(snapshot "${forge}" open-prs)
    [ -f "${file}" ]
    { printf '%s\n' "$(( $(date +%s) - 61 ))"; tail -n +2 "${file}"; } > "${file}.old"
    mv "${file}.old" "${file}"
    [ "$(call open-prs | jq --raw-output .ref)" = "$(jq --raw-output .ref <<<"${first}")" ]
    [ "$(reads "${forge}")" -eq 2 ]
    call open-prs > /dev/null
    [ "$(reads "${forge}")" -eq 2 ]
  done
}

@test "a stage given --fresh reads afresh, and a call that changes the forge drops the snapshot" {
  for forge in github gitlab
  do
    world "${forge}"
    : > "${FAKE_DIR}/gh.calls"
    : > "${FAKE_DIR}/glab.calls"
    call open-prs > /dev/null
    # a snapshot read in the second the stage began counts as fresh, so the stage begins a second later
    sleep 1
    fresh-call open-prs > /dev/null
    [ "$(reads "${forge}")" -eq 2 ]
    # the fresh read is the snapshot now
    call open-prs > /dev/null
    [ "$(reads "${forge}")" -eq 2 ]
    call pr-create 7-fix-the-thing main "Fix the thing" > /dev/null
    [ ! -e "$(snapshot "${forge}" open-prs)" ]
    call open-prs > /dev/null
    [ "$(reads "${forge}")" -eq 3 ]
  done
}

@test "processes that ask at once make one read: the first takes the lock, the others wait for its snapshot" {
  local i
  local -a pids=()
  world github
  # gh answers slowly, so every process asks while the first still reads
  mkdir -p "${FAKE_DIR}/slow"
  mv "${FAKE_DIR}/bin/gh" "${FAKE_DIR}/slow/gh"
  cat > "${FAKE_DIR}/bin/gh" <<'SH'
#!/usr/bin/env bash
sleep 1
exec "${FAKE_DIR}/slow/gh" "$@"
SH
  chmod +x "${FAKE_DIR}/bin/gh"
  : > "${FAKE_DIR}/gh.calls"
  for i in 1 2 3 4
  do
    call open-prs > "${BATS_TEST_TMPDIR}/answer.${i}" 3>&- &
    pids+=("$!")
  done
  # bats has a process of its own in the background, so the wait names the test's
  wait "${pids[@]}"
  [ "$(reads github)" -eq 1 ]
  for i in 2 3 4
  do
    cmp "${BATS_TEST_TMPDIR}/answer.1" "${BATS_TEST_TMPDIR}/answer.${i}"
  done
  [ "$(jq --raw-output .ref "${BATS_TEST_TMPDIR}/answer.4")" = "#3" ]
  # so do the stages of one picture given --fresh, which take no snapshot read before the picture began
  : > "${FAKE_DIR}/gh.calls"
  bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:fresh
    for i in 1 2 3
    do
      forge:open-prs > /dev/null &
    done
    wait' 3>&-
  [ "$(reads github)" -eq 1 ]
  [ ! -e "$(dirname "$(snapshot github open-prs)")/open-prs.lock" ]
}

@test "a lock whose process is gone is taken over, and the open issues are kept as the open changes are" {
  local dir
  world github
  call open-issues > /dev/null
  dir=$(dirname "$(snapshot github open-issues)")
  rm -f "${dir}"/*.json
  # a process that does not exist holds the lock
  ln -s 999999 "${dir}/open-prs.lock"
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output .ref <<<"$output")" = "#3" ]
  [ ! -e "${dir}/open-prs.lock" ]
  : > "${FAKE_DIR}/gh.calls"
  call open-issues > /dev/null
  call open-issues > /dev/null
  [ "$(grep --count '^issue list' "${FAKE_DIR}/gh.calls")" -eq 1 ]
}

@test "GitHub's open changes cost 19 points: closed issues' assignees come from the open issues, labels from each" {
  world github
  run call open-prs
  [ "$status" -eq 0 ]
  # the reviewers are asked in the same request, which costs 3 points more than without them: still one read
  [ "$(reads github)" -eq 1 ]
  grep --quiet 'reviewRequests(first: 20) { totalCount nodes { requestedReviewer {' "${FAKE_DIR}/gh.calls"
  grep --quiet 'latestReviews(first: 20) { totalCount nodes { author { login } state submittedAt } }' \
    "${FAKE_DIR}/gh.calls"
  grep --quiet 'latestOpinionatedReviews(first: 20) { totalCount nodes { author { login } state submittedAt } }' \
    "${FAKE_DIR}/gh.calls"
  [ "$(jq --compact-output '.closes | map(.assignees)' <<<"$output")" = '[["bob"]]' ]
  [ "$(jq --compact-output '[.labels, .closes[0].labels] | map(map(.name))' <<<"$output")" = '[["kind=fix"],["bug"]]' ]
  grep --quiet 'issues(states: OPEN, first: 100, filterBy: {assignee: "\*"}' "${FAKE_DIR}/gh.calls"
  grep --quiet 'closingIssuesReferences(first: 10) { pageInfo { hasNextPage endCursor } nodes {$' "${FAKE_DIR}/gh.calls"
  grep --quiet 'number title createdAt url repository { nameWithOwner } labels(first: 20) { nodes { name color } }' \
    "${FAKE_DIR}/gh.calls"
  [ "$(grep --count 'assignees(first: 10)' "${FAKE_DIR}/gh.calls")" -eq 1 ]
}

@test "a pull request with more reviewers than GitHub's open changes read fails them, saying so" {
  world github
  local what='the pull requests' list
  for list in latestReviews latestOpinionatedReviews
  do
    jq --arg list "${list}" '.data.repository.pullRequests.nodes[0][$list].totalCount = 21' \
      "${FAKE_DIR}/open-prs.json" | fixture open-prs-many.json
    : > "${FAKE_DIR}/gh.routes"
    route gh 'repo view*' repo.json
    route gh 'api graphql*' open-prs-many.json
    run --separate-stderr call open-prs
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "❌ kit reads at most 20 review requests and 20 reviews of a change, and #3 has more (${what} could not be read)" ]
  done
}

@test "a read gh's login lacks a scope for names the command that adds the scope GitHub names" {
  world github
  local said="gh: Your token has not been granted the required scopes to execute this query. The 'pullRequests'"
  said+=" field requires one of the following scopes: ['repo'], but your token has only been granted the: ['gist']"
  said+=" scopes. (INSUFFICIENT_SCOPES)"
  printf '%s\n' "${said}" | fixture gh-repo.txt
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' '!1 gh-repo.txt'
  run --separate-stderr call merged-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth refresh --scopes repo (the merged pull requests could not be read)' ]]
}

@test "a token without read:org still reads the open changes: asked again without teams, it draws none of them" {
  world github
  local said="gh: Your token has not been granted the required scopes to execute this query. The 'slug' field"
  said+=" requires one of the following scopes: ['read:org'], but your token has only been granted the: ['repo']"
  said+=" scopes. (INSUFFICIENT_SCOPES)"
  printf '%s\n' "${said}" | fixture gh-org.txt
  # asked without the team fragment, GitHub gives a team asked as an empty object
  jq '.data.repository.pullRequests.nodes[0].reviewRequests.nodes += [{"requestedReviewer": {}}]' \
    "${FAKE_DIR}/open-prs.json" | fixture open-prs-teamless.json
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*on Team*' '!1 gh-org.txt'
  route gh 'api graphql*' open-prs-teamless.json
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call open-prs
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ -z "$stderr" ]
  [ "$(jq --compact-output '.reviewers | map([.login, .state])' <<<"$output")" \
    = '[["bob","requested"],["carol","approved"]]' ]
  [ "$(reads github)" -eq 2 ]
  [ "$(grep -c 'on Team { slug }' "${FAKE_DIR}/gh.calls")" -eq 1 ]
}

@test "a GitHub answer with no repository says it could not be read, never that a cap was reached" {
  world github
  fixture no-repo.json <<<'{"data": {"repository": null}}'
  : > "${FAKE_DIR}/gh.routes"
  route gh 'repo view*' repo.json
  route gh 'api graphql*' no-repo.json
  run --separate-stderr call open-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the pull requests could not be read)' ]]
}

@test "a read GitHub's rate limit stops says which limit, and when it resets, never gh auth status" {
  local reset
  world github
  reset=$(( $(date +%s) + 700 ))
  fixture limited.txt <<<'gh: API rate limit already exceeded for user ID 1.'
  fixture limits.json <<<"{\"resources\": {\"core\": {\"remaining\": 4990, \"reset\": ${reset}},
    \"graphql\": {\"remaining\": 0, \"reset\": ${reset}}}}"
  printf 'api rate_limit*\tlimits.json\n' > "${FAKE_DIR}/routes.first"
  printf 'api graphql*\t!1 limited.txt\nissue list*\t!1 limited.txt\nrepo view*\t!1 limited.txt\n' >> "${FAKE_DIR}/routes.first"
  cat "${FAKE_DIR}/routes.first" "${FAKE_DIR}/gh.routes" > "${FAKE_DIR}/routes.all"
  mv "${FAKE_DIR}/routes.all" "${FAKE_DIR}/gh.routes"
  run call open-prs
  [ "$status" -eq 1 ]
  [[ "$output" == *"wait until $(jq --null-input --raw-output "${reset} | strflocaltime(\"%H:%M\")"), in 12m, when GitHub's GraphQL rate limit resets (the pull requests could not be read)"* ]]
  [[ "$output" != *"gh auth status"* ]]
  run call open-issues
  [[ "$output" == *"GraphQL rate limit resets (the issues could not be read)"* ]]
  # nothing is kept from a read that failed, so the next process asks again
  [ ! -e "$(snapshot github open-prs)" ]
  # a secondary rate limit names no reset; GitHub asks for a wait of a few minutes
  fixture limited.txt <<<'gh: You have exceeded a secondary rate limit. Please wait a few minutes before you try again.'
  run call open-prs
  [ "$status" -eq 1 ]
  [[ "$output" == *"wait a few minutes: GitHub's secondary rate limit refused the read (the pull requests could not be read)"* ]]
  # any other failure still names gh auth status
  fixture limited.txt <<<'gh: Bad credentials (HTTP 401)'
  run call open-prs
  [ "$status" -eq 1 ]
  [[ "$output" == *"run: cd "*" && gh auth status (the pull requests could not be read)"* ]]
}

@test "a forge that cannot answer fails every read with one line, and never answers nothing" {
  for forge in github gitlab
  do
    world "${forge}"
    printf 'repo view*\trepo.json\n' | tee "${FAKE_DIR}/gh.routes" > "${FAKE_DIR}/glab.routes"
    for call in 'branch-for-issue 7' 'pr-for-branch 7-fix-the-thing' 'pr-last-for-branch 7-fix-the-thing' \
      'pr-state-for-branch 7-fix-the-thing' 'pr-head-for-branch 7-fix-the-thing' pr-here 'pr-title 3' 'pr-body 3' \
      'pr-author 3' 'pr-closing-issues 3' 'pr-state 3' 'issue-state 7' 'issue-assignees 7' 'issue-title 7' open-prs \
      open-issues releases quota runs me
    do
      read -r -a words <<<"${call}" && run --separate-stderr call "${words[@]}"
      [[ "$status" -eq 1 && -z "$output" && "$stderr" == *"could not be read)"* ]] \
        || { echo "${forge} ${call}: exit ${status}, printed '${output}', said '${stderr}'"; return 1; }
    done
    # the marks are read a kind at a time: each kind is null, with its line
    run --separate-stderr call marks issues runs
    [[ "$status" -eq 1 && "$output" == '{"issues":null,"runs":null}' && "$stderr" == *"(the issues mark could not"* \
      && "$stderr" == *"(the runs mark could not be read)" ]] \
      || { echo "${forge} marks: exit ${status}, printed '${output}', said '${stderr}'"; return 1; }
  done
}

@test "one merge request's read that fails fails the open changes, and no part is kept as the snapshot" {
  world gitlab
  local p='projects/empowerite%2Fexample'
  fixture mrs-list.json <<<'[{"iid": 3}, {"iid": 4}]'
  { printf '%s\t%s\n' "api ${p}/merge_requests/4/discussions*" '!1' "api ${p}/merge_requests/4/closes_issues*" \
      closes.json "api ${p}/merge_requests/4" mr.json
    cat "${FAKE_DIR}/glab.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/glab.routes"
  run call open-prs
  [ "$status" -eq 1 ]
  [ ! -f "$(snapshot gitlab open-prs)" ]
}

@test "a merge request's own pipeline whose jobs cannot be read fails the open changes, and says so" {
  world gitlab
  { printf '%s\t%s\n' 'api projects/1/pipelines/11/jobs*' '!1'
    cat "${FAKE_DIR}/glab.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/glab.routes"
  run --separate-stderr call open-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(grep --count '❌' <<<"$stderr")" -eq 1 ]
  [[ "$stderr" == *"run: cd "*" && glab auth status (the jobs of pipeline 11 could not be read)"* ]]
}

@test "a merge request list that is not a list fails the read, never reads as none" {
  world gitlab
  fixture mr-by-branch.json <<<'null'
  fixture mr-states.json <<<'null'
  for call in pr-for-branch pr-last-for-branch pr-state-for-branch pr-head-for-branch
  do
    run --separate-stderr call "${call}" 7-fix-the-thing
    [[ "$status" -eq 1 && -z "$output" && "$stderr" == *"could not be read)"* ]] \
      || { echo "${call}: exit ${status}, printed '${output}', said '${stderr}'"; return 1; }
  done
}

@test "a read stopped by an answer kit cannot use says the remedy, then what could not be read" {
  world github
  printf 'HTTP/2.0 200 OK\r\n\r\n[]\n' > "${FAKE_DIR}/no-etag.txt"
  route gh 'api --include*' no-etag.txt
  run --separate-stderr call marks
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"GitHub gave no ETag for repos/{owner}/{repo}/issues"*"(the issues mark could not be read)"* ]]
  # a GitLab checkout with no origin names the remote to add
  world gitlab
  git remote remove origin
  mkdir -p .kit && printf 'forge: gitlab\n' > kit.yml
  run --separate-stderr call issue-title 7
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"run: cd "*" && git remote add origin <url>"*"(the project could not be read)" ]]
}

@test "a change's state that GitHub's rate limit stops says which limit, never gh auth status" {
  world github
  fixture limited.txt <<<'gh: You have exceeded a secondary rate limit. Please wait a few minutes before you try again.'
  { printf '%s\t%s\n' 'pr view 5 --json state,mergeCommit*' '!1 limited.txt'
    cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
  run --separate-stderr call pr-state 5
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"GitHub's secondary rate limit refused the read (pull request #5 could not be read)"* ]]
  [[ "$stderr" != *"gh auth status"* ]]
}

@test "a list in pages is read whole" {
  world gitlab
  # glab prints each page's array after the one before
  fixture issues.json <<'JSON'
[{"iid": 7, "title": "Fix the thing", "assignees": [], "created_at": "2026-09-20T09:00:00.000Z"}]
[{"iid": 9, "title": "Other thing", "assignees": [], "created_at": "2026-09-25T09:00:00.000Z"}]
JSON
  run call open-issues
  [ "$(jq --slurp length <<<"$output")" -eq 2 ]
  grep --quiet 'issues?state=opened.* --paginate$' "${FAKE_DIR}/glab.calls"
}

@test "a fork's pipeline that cannot be read is one check, the pipeline's own status" {
  world gitlab
  jq '.head_pipeline = {id: 11, project_id: 99, status: "failed"}' "${FAKE_DIR}/mr.json" > "${FAKE_DIR}/fork.json"
  mv "${FAKE_DIR}/fork.json" "${FAKE_DIR}/mr.json"
  route glab 'api projects/99/pipelines/11/jobs*' '!1'
  run call open-prs
  [ "$(jq --compact-output '[.checks.total, .checks.failing]' <<<"$output")" = '[1,"pipeline"]' ]
}

@test "an answer that is not JSON fails the read" {
  world github
  fixture issues.json <<<'<html>'
  run --separate-stderr call open-issues
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"run: cd "*" && gh auth status (the issues could not be read)"* ]]
}

@test "GitHub's open pull requests are read page after page, each after the cursor the one before ended on" {
  world github
  jq '.data.repository.pullRequests.pageInfo = {hasNextPage: true, endCursor: "p1"}' "${FAKE_DIR}/open-prs.json" \
    > "${FAKE_DIR}/page-1.json"
  jq '.data.repository.pullRequests.nodes[0].number = 5
      | .data.repository.pullRequests.pageInfo = {hasNextPage: false, endCursor: "p2"}' "${FAKE_DIR}/open-prs.json" \
    > "${FAKE_DIR}/page-2.json"
  { printf '%s\t%s\n' 'api graphql*after=p1*' page-2.json 'api graphql*' page-1.json
    cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --compact-output 'map(.number)' <<<"$output")" = '[3,5]' ]
}

@test "the issues a pull request closes are read page after page, past the first 100; a missing pull request fails" {
  world github
  fixture closing-1.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {
  "pageInfo": {"hasNextPage": true, "endCursor": "i1"},
  "nodes": [{"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  fixture closing-2.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {
  "pageInfo": {"hasNextPage": false, "endCursor": "i2"},
  "nodes": [{"number": 8, "state": "CLOSED", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  fixture closing-gone.json <<<'{"data": {"repository": {"pullRequest": null}}}'
  { printf '%s\t%s\n' 'api graphql*number=3 --raw-field after=i1 *' closing-2.json 'api graphql*number=3 *' \
      closing-1.json 'api graphql*number=4 *' closing-gone.json
    cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
  run call pr-closing-issues 3
  [ "$status" -eq 0 ]
  [ "$output" = $'7 OPEN empowerite/example\n8 CLOSED empowerite/example' ]
  run --separate-stderr call pr-closing-issues 4
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"(pull request #4 could not be read)"* ]]
}

# many-world makes pull request #3's review threads and checks run past their first page, its head commit abc, and
# routes the second page of each ahead of the world's routes: the checks' at <checks-page>.
many-world() {
  world github
  jq '.data.repository.pullRequests.nodes[0]
      |= (.reviewThreads.pageInfo = {hasNextPage: true, endCursor: "t1"}
          | .commits.nodes[0].commit.oid = "abc"
          | .commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo = {hasNextPage: true, endCursor: "c1"})' \
    "${FAKE_DIR}/open-prs.json" > "${FAKE_DIR}/many.json"
  mv "${FAKE_DIR}/many.json" "${FAKE_DIR}/open-prs.json"
  fixture threads-2.json <<<'{"data": {"repository": {"pullRequest": {"reviewThreads": {
    "pageInfo": {"hasNextPage": false, "endCursor": "t2"}, "nodes": [{"isResolved": false}]}}}}}'
  fixture checks-2.json <<'JSON'
{"data": {"repository": {"pullRequest": {"commits": {"nodes": [{"commit": {"oid": "abc", "statusCheckRollup": {
  "contexts": {"pageInfo": {"hasNextPage": false, "endCursor": "c2"}, "nodes": [
    {"__typename": "CheckRun", "name": "c", "status": "COMPLETED", "conclusion": "FAILURE",
     "startedAt": "2026-10-01T10:02:00Z", "completedAt": "2026-10-01T10:03:00Z"}]}}}}]}}}}}
JSON
  jq '.data.repository.pullRequest.commits.nodes[0].commit.oid = "def"' "${FAKE_DIR}/checks-2.json" \
    > "${FAKE_DIR}/checks-moved.json"
  { printf '%s\t%s\n' 'api graphql*pr=3 *after=t1 *' threads-2.json 'api graphql*pr=3 *after=c1 *' "$1"
    cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
}

@test "a pull request with more review threads or checks than a page holds has the rest of each read" {
  many-world checks-2.json
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.unresolved' <<<"$output")" -eq 2 ]
  [[ "$(jq --compact-output '.checks' <<<"$output")" == *'"failing":"c"'* ]]
  grep --quiet 'pr=3 --raw-field after=t1 ' "${FAKE_DIR}/gh.calls"
  grep --quiet 'pr=3 --raw-field after=c1 ' "${FAKE_DIR}/gh.calls"
  # the checks after the first page are asked their workflow and event as the first page's are
  [ "$(grep --count 'checkSuite { workflowRun { event workflow { name } } }' "${FAKE_DIR}/gh.calls")" -eq 2 ]
}

@test "the rest of a pull request's checks that cannot be read, or that are another commit's, fails the read" {
  many-world '!1'
  run --separate-stderr call open-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"(the checks of #3 could not be read)"* ]]
  many-world checks-moved.json
  run --separate-stderr call open-prs
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"head commit moved"*"(the checks of #3 could not be read)"* ]]
}

# checks-world gives pull request #3's head commit the check runs of a jq array, each [name, workflow, event,
# conclusion, startedAt], a workflow of null a check run of no workflow.
checks-world() {
  world github
  jq --argjson runs "$1" '.data.repository.pullRequests.nodes[0].commits.nodes[0].commit.statusCheckRollup.contexts.nodes
      = [$runs[] | {__typename: "CheckRun", name: .[0], status: "COMPLETED", conclusion: .[3], startedAt: .[4],
                    completedAt: .[4],
                    checkSuite: {workflowRun: (if .[1] == null then null
                                               else {event: .[2], workflow: {name: .[1]}} end)}}]' \
    "${FAKE_DIR}/open-prs.json" > "${FAKE_DIR}/checks.json"
  mv "${FAKE_DIR}/checks.json" "${FAKE_DIR}/open-prs.json"
}

@test "a failed check on GitHub is not hidden by a later check of its name in another workflow, or for another event" {
  # two workflows with a job named test: the first failed, the second started later and passed
  checks-world '[["test", "CI", "pull_request", "FAILURE", "2026-10-01T10:00:00Z"],
                 ["test", "Docs", "pull_request", "SUCCESS", "2026-10-01T10:00:02Z"]]'
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '[.state, .checks.state, .checks.passed, .checks.total, .checks.failing]' <<<"$output")" \
    = '["failing:gate","FAILURE",1,2,"test"]' ]
  # each run says the workflow it is of and the event that started it
  [ "$(jq --compact-output '[.runs[] | [.name, .workflow, .event, .verdict]]' <<<"$output")" \
    = '[["test","CI","pull_request","failed"],["test","Docs","pull_request","passed"]]' ]
  # the query asks them of each check run
  grep --quiet 'checkSuite { workflowRun { event workflow { name } } }' "${FAKE_DIR}/gh.calls"
  # one workflow that runs on a push and on a pull request: the push's failed, the pull request's passed later
  checks-world '[["test", "CI", "push", "FAILURE", "2026-10-01T10:00:00Z"],
                 ["test", "CI", "pull_request", "SUCCESS", "2026-10-01T10:00:02Z"]]'
  forge-forget
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '[.state, .checks.passed, .checks.total, .checks.failing]' <<<"$output")" \
    = '["failing:gate",1,2,"test"]' ]
  # a later run of the same job, in the same workflow for the same event, is a rerun, and supersedes the one before
  checks-world '[["test", "CI", "pull_request", "FAILURE", "2026-10-01T10:00:00Z"],
                 ["test", "CI", "pull_request", "SUCCESS", "2026-10-01T10:00:02Z"],
                 ["lint", null, null, "FAILURE", "2026-10-01T10:00:00Z"],
                 ["lint", null, null, "SUCCESS", "2026-10-01T10:00:02Z"]]'
  forge-forget
  run call open-prs
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '[.checks.state, .checks.passed, .checks.total, .checks.failing]' <<<"$output")" \
    = '["SUCCESS",2,2,""]' ]
}

@test "a list that reaches the most kit reads fails, on either forge, saying so" {
  for forge in github gitlab
  do
    world "${forge}"
    # gh is asked for no more than the most kit reads, and gives its two issues
    route gh 'issue list --state open --limit 2 --json *' issues.json
    run --separate-stderr bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge_list_limit=2 \
      && forge:open-issues'
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *"kit reads at most 2 items of a list (the issues could not be read)"* ]] \
      || { echo "${forge}: ${stderr}"; return 1; }
  done
}

# audit-github adds to world-github's routes what Trust reads: the release v0.1.0 offers kit-0.1.0.tar.gz, whose
# digest, sha256:ab12, the artifact 13 has too, and which the release workflow attested as SLSA provenance; code
# scanning's alert 4 is open, and bob dismissed its alert 2 as a false positive; ada dismissed Dependabot's alert 1 as
# a tolerable risk; secret scanning is off; and the ruleset main guards the default branch with two rules, which the
# team release may bypass, beside the ruleset releases, which guards the release branches alone. The default branch
# has no protection of its own.
audit-github() {
  local statement alerts='sort=updated&direction=desc&per_page=100'
  fixture gh-evidence-releases.json <<'JSON'
[{"tag_name": "v0.1.0", "html_url": "https://github.com/empowerite/example/releases/tag/v0.1.0",
  "assets": [{"name": "kit-0.1.0.tar.gz", "digest": "sha256:ab12", "created_at": "2026-10-01T10:00:00Z"},
             {"name": "notes.txt", "digest": null, "created_at": "2026-10-01T10:00:00Z"}]}]
JSON
  statement=$(jq --null-input --raw-output '{_type: "https://in-toto.io/Statement/v1",
    subject: [{name: "kit-0.1.0.tar.gz", digest: {sha256: "ab12"}}], predicateType: "https://slsa.dev/provenance/v1",
    predicate: {buildDefinition: {externalParameters: {workflow: {ref: "refs/tags/v0.1.0",
      repository: "https://github.com/empowerite/example", path: ".github/workflows/release.yml"}}}}}
    | tojson | @base64')
  jq --null-input --arg payload "${statement}" '[{attestations: [{repository_id: 1, initiator: "user",
    bundle: {mediaType: "application/vnd.dev.sigstore.bundle.v0.3+json",
             verificationMaterial: {tlogEntries: [{integratedTime: "1790845200"}]},
             dsseEnvelope: {payload: $payload, payloadType: "application/vnd.in-toto+json"}}}]}]' \
    | fixture gh-attestations.json
  fixture gh-attest-404.txt <<<'gh: Not Found (HTTP 404)'
  fixture gh-code-open.json <<'JSON'
[[{"number": 4, "state": "open", "created_at": "2026-10-01T09:00:00Z",
   "html_url": "https://github.com/empowerite/example/security/code-scanning/4",
   "rule": {"id": "js/xss", "severity": "error", "security_severity_level": "high"},
   "most_recent_instance": {"location": {"path": "src/app.js"}},
   "dismissed_by": null, "dismissed_reason": null, "dismissed_comment": null}]]
JSON
  fixture gh-code-dismissed.json <<'JSON'
[[{"number": 2, "state": "dismissed", "created_at": "2026-09-01T09:00:00Z",
   "html_url": "https://github.com/empowerite/example/security/code-scanning/2",
   "rule": {"id": "js/unused-local-variable", "severity": "note", "security_severity_level": null},
   "most_recent_instance": {"location": {"path": "src/old.js"}},
   "dismissed_by": {"login": "bob"}, "dismissed_reason": "false positive", "dismissed_comment": null}]]
JSON
  fixture gh-dependabot.json <<'JSON'
[[{"number": 1, "state": "dismissed", "created_at": "2026-09-15T09:00:00Z",
   "html_url": "https://github.com/empowerite/example/security/dependabot/1",
   "dependency": {"package": {"ecosystem": "npm", "name": "lodash"}, "manifest_path": "package-lock.json"},
   "security_advisory": {"ghsa_id": "GHSA-35jh-r3h4-6jhm", "severity": "high"},
   "security_vulnerability": {"severity": "high"},
   "dismissed_by": {"login": "ada"}, "dismissed_reason": "tolerable_risk", "dismissed_comment": "only in tests"}]]
JSON
  fixture gh-secret-off.txt <<<'gh: Secret scanning is disabled on this repository. (HTTP 404)'
  fixture gh-rulesets.json <<'JSON'
{"data": {"repository": {"url": "https://github.com/empowerite/example", "defaultBranchRef": {"name": "main"},
  "rulesets": {"totalCount": 2, "nodes": [
    {"databaseId": 7, "name": "main", "enforcement": "ACTIVE",
     "conditions": {"refName": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
     "rules": {"totalCount": 2, "nodes": [{"type": "PULL_REQUEST", "parameters": {"requiredApprovingReviewCount": 1}},
       {"type": "DELETION", "parameters": null}]},
     "bypassActors": {"totalCount": 1, "nodes": [
       {"bypassMode": "ALWAYS", "organizationAdmin": false, "repositoryRoleName": null, "deployKey": false,
        "enterpriseOwner": false, "actor": {"__typename": "Team", "slug": "release"}}]}},
    {"databaseId": 8, "name": "releases", "enforcement": "EVALUATE",
     "conditions": {"refName": {"include": ["refs/heads/release/*"], "exclude": []}},
     "rules": {"totalCount": 1, "nodes": [{"type": "NON_FAST_FORWARD"}]},
     "bypassActors": {"totalCount": 0, "nodes": []}}]}}}}
JSON
  fixture gh-branch.json <<'JSON'
{"name": "main", "protected": true,
 "protection": {"enabled": false, "required_status_checks": {"enforcement_level": "off", "contexts": [], "checks": []}}}
JSON
  fixture gh-protection.json <<'JSON'
{"required_status_checks": {"strict": true, "contexts": ["ci"]}, "enforce_admins": {"enabled": false},
 "required_pull_request_reviews": {"required_approving_review_count": 1,
   "bypass_pull_request_allowances": {"users": [{"login": "ada"}], "teams": [], "apps": [{"slug": "release-bot"}]}},
 "restrictions": null, "required_linear_history": {"enabled": true}, "allow_force_pushes": {"enabled": false},
 "allow_deletions": {"enabled": false}, "block_creations": {"enabled": false},
 "required_conversation_resolution": {"enabled": false}, "lock_branch": {"enabled": false},
 "required_signatures": {"enabled": false}}
JSON
  route gh 'api repos/{owner}/{repo}/releases?per_page=6' "${GITHUB_EVIDENCE_RELEASES:-gh-evidence-releases.json}"
  route gh 'api repos/{owner}/{repo}/actions/artifacts?per_page=20' "${GITHUB_EVIDENCE_ARTIFACTS:-gh-artifacts.json}"
  route gh 'api --paginate --slurp repos/{owner}/{repo}/attestations/sha256:ab12?per_page=100' \
    "${GITHUB_ATTESTATIONS:-gh-attestations.json}"
  route gh 'api --paginate --slurp repos/{owner}/{repo}/attestations/*' '!1 gh-attest-404.txt'
  route gh "api --paginate --slurp repos/{owner}/{repo}/code-scanning/alerts?state=open&${alerts}" \
    "${GITHUB_CODE_OPEN:-gh-code-open.json}"
  route gh "api --paginate --slurp repos/{owner}/{repo}/code-scanning/alerts?state=dismissed&${alerts}" \
    "${GITHUB_CODE_DISMISSED:-gh-code-dismissed.json}"
  route gh "api --paginate --slurp repos/{owner}/{repo}/dependabot/alerts?state=*&${alerts}" \
    "${GITHUB_DEPENDABOT:-gh-dependabot.json}"
  route gh "api --paginate --slurp repos/{owner}/{repo}/secret-scanning/alerts?state=open&${alerts}" \
    "${GITHUB_SECRET_OPEN:-!1 gh-secret-off.txt}"
  route gh "api --paginate --slurp repos/{owner}/{repo}/secret-scanning/alerts?state=resolved&*" \
    "${GITHUB_SECRET_RESOLVED:-!1 gh-secret-off.txt}"
  route gh 'api graphql*rulesets(first: 100*' "${GITHUB_RULESETS:-gh-rulesets.json}"
  route gh 'api repos/{owner}/{repo}/branches/main' "${GITHUB_BRANCH:-gh-branch.json}"
  route gh 'api repos/{owner}/{repo}/branches/main/protection' "${GITHUB_PROTECTION:-gh-protection.json}"
}

# audit-gitlab is audit-github's world, seen through GitLab's vulnerability report: SAST found alert 4 open, and ada
# dismissed the dependency scanning alert 1 as an acceptable risk; secret detection found nothing. The protected
# branch main, and the wildcard ma*, guard the default branch, release/* does not, and the push rules hold two.
audit-gitlab() {
  local p='projects/empowerite%2Fexample'
  fixture gl-vulns-sast.json <<'JSON'
{"data": {"project": {"vulnerabilities": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
  {"id": "gid://gitlab/Vulnerability/4", "title": "Cross-site scripting", "severity": "HIGH", "state": "DETECTED",
   "detectedAt": "2026-10-01T09:00:00Z", "primaryIdentifier": {"name": "CWE-79"}, "location": {"file": "src/app.js"},
   "dismissedBy": null, "dismissalReason": null, "stateComment": null,
   "webUrl": "https://gitlab.com/empowerite/example/-/security/vulnerabilities/4"}]}}}}
JSON
  fixture gl-vulns-deps.json <<'JSON'
{"data": {"project": {"vulnerabilities": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
  {"id": "gid://gitlab/Vulnerability/1", "title": "Prototype pollution in lodash", "severity": "HIGH",
   "state": "DISMISSED", "detectedAt": "2026-09-15T09:00:00.000Z",
   "primaryIdentifier": {"name": "GHSA-35jh-r3h4-6jhm"}, "location": {"file": "package-lock.json"},
   "dismissedBy": {"username": "ada"}, "dismissalReason": "ACCEPTABLE_RISK", "stateComment": "only in tests",
   "webUrl": "https://gitlab.com/empowerite/example/-/security/vulnerabilities/1"}]}}}}
JSON
  fixture gl-vulns-none.json <<'JSON'
{"data": {"project": {"vulnerabilities": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
JSON
  fixture gl-protected-branches.json <<'JSON'
[{"id": 11, "name": "main", "push_access_levels": [{"access_level": 40, "access_level_description": "Maintainers"}],
  "merge_access_levels": [{"access_level": 30, "access_level_description": "Developers + Maintainers"}],
  "allow_force_push": false, "code_owner_approval_required": true},
 {"id": 12, "name": "release/*",
  "push_access_levels": [{"access_level": 40, "access_level_description": "Maintainers"}],
  "merge_access_levels": [], "allow_force_push": false, "code_owner_approval_required": false},
 {"id": 13, "name": "ma*", "push_access_levels": [{"access_level": 0, "access_level_description": "No one"}],
  "merge_access_levels": [{"access_level": 40, "access_level_description": "Maintainers"}],
  "allow_force_push": true, "code_owner_approval_required": false}]
JSON
  fixture gl-push-rule.json <<'JSON'
{"id": 3, "project_id": 1, "created_at": "2026-09-01T09:00:00.000Z", "commit_message_regex": "",
 "commit_message_negative_regex": null, "branch_name_regex": "", "deny_delete_tag": true, "member_check": false,
 "prevent_secrets": true, "author_email_regex": "", "file_name_regex": "", "max_file_size": 0,
 "commit_committer_check": null, "commit_committer_name_check": false, "reject_unsigned_commits": null,
 "reject_non_dco_commits": null}
JSON
  fixture gl-severities.json <<'JSON'
{"data": {"project": {"open": {"critical": 0, "high": 1, "medium": 0, "low": 0, "info": 0, "unknown": 0},
  "dismissed": {"critical": 0, "high": 1, "medium": 0, "low": 0, "info": 0, "unknown": 0}}}}
JSON
  route glab 'api graphql*vulnerabilitySeveritiesCount*' "${GITLAB_SEVERITIES:-gl-severities.json}"
  route glab 'api graphql*type=SAST*' "${GITLAB_SAST:-gl-vulns-sast.json}"
  route glab 'api graphql*type=DEPENDENCY_SCANNING*' "${GITLAB_DEPENDENCIES:-gl-vulns-deps.json}"
  route glab 'api graphql*type=SECRET_DETECTION*' "${GITLAB_SECRETS:-gl-vulns-none.json}"
  route glab "api ${p}/protected_branches?per_page=100 --paginate" \
    "${GITLAB_PROTECTED_BRANCHES:-gl-protected-branches.json}"
  route glab "api ${p}/push_rule" "${GITLAB_PUSH_RULE:-gl-push-rule.json}"
}

@test "GitHub lists the attestations of its newest releases' assets and artifacts, each digest read once" {
  world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call attestations
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  local expected='{"subject":"kit-0.1.0.tar.gz","digest":"sha256:ab12","kind":"https://slsa.dev/provenance/v1",'
  expected+='"signer":"empowerite/example/.github/workflows/release.yml@refs/tags/v0.1.0",'
  expected+='"url":"https://github.com/empowerite/example/attestations"}'
  [ "$(jq --compact-output 'del(.age)' <<<"$output")" = "${expected}" ] || { echo "${output}"; return 1; }
  # its age is from the transparency log's entry, the attestation's own time
  [ "$(jq --raw-output '.age > 3000000' <<<"$output")" = true ]
  # the release asset and the artifact share the digest, which is asked for once; an asset without one is not
  [ "$(grep -c 'attestations/' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  # GitLab and Azure DevOps keep no attestations kit reads
  world gitlab
  run --separate-stderr call attestations
  [ "$status" -eq 3 ]
  [ -z "$output$stderr" ]
}

@test "an attestation GitHub keeps apart has no kind kit can read, and more releases or artifacts say limited" {
  world github
  # GitHub may answer with no bundle, only a link to one compressed, which kit does not read: the kind and the
  # signer are unknown, but for one GitHub made itself
  jq '.[0].attestations = [{repository_id: 1, initiator: "github", bundle: null, bundle_url: "https://b"}]' \
    "${FAKE_DIR}/gh-attestations.json" | fixture gh-attestations-apart.json
  GITHUB_ATTESTATIONS=gh-attestations-apart.json world github
  run --separate-stderr call attestations
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.subject, .kind, .signer, (.age > 0)]' <<<"$output")" \
    = '["kit-0.1.0.tar.gz",null,"github",true]' ]
  # a sixth release, or more artifacts than the 20 read, say the attestations drawn are not all there are
  jq '. + [range(5) as $i | .[0] | .tag_name = "v0.0.\($i)" | .assets = []]' "${FAKE_DIR}/gh-evidence-releases.json" \
    | fixture gh-evidence-releases-6.json
  GITHUB_EVIDENCE_RELEASES=gh-evidence-releases-6.json world github
  run --separate-stderr call attestations
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output '[length, .[-1]]' <<<"$output")" = '[2,{"limited":1}]' ] \
    || { echo "${output}"; return 1; }
  jq '.total_count = 30' "${FAKE_DIR}/gh-artifacts.json" | fixture gh-artifacts-30.json
  GITHUB_EVIDENCE_ARTIFACTS=gh-artifacts-30.json world github
  run --separate-stderr call attestations
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --slurp --compact-output '[length, .[-1]]' <<<"$output")" = '[2,{"limited":1}]' ]
  # 60 digests are read 50 at most
  jq '.[0].assets[0] as $a
      | .[0].assets = [range(60) as $i | $a | .name = "f\($i)" | .digest = "sha256:\(1000 + $i)"]' \
    "${FAKE_DIR}/gh-evidence-releases.json" | fixture gh-evidence-releases-60.json
  GITHUB_EVIDENCE_RELEASES=gh-evidence-releases-60.json world github
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call attestations
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"limited":0}' ]
  [ "$(grep -c 'attestations/' "${FAKE_DIR}/gh.calls")" -eq 50 ]
  # releases that are not a list, or artifacts with none, could not be read, and print nothing
  fixture gh-object.json <<<'{}'
  GITHUB_EVIDENCE_RELEASES=gh-object.json world github
  run --separate-stderr call attestations
  [ "$status" -eq 1 ] && [ -z "$output" ] || { echo "${output}"; return 1; }
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the attestations could not be read)' ]]
  GITHUB_EVIDENCE_ARTIFACTS=gh-object.json world github
  run --separate-stderr call attestations
  [ "$status" -eq 1 ] && [ -z "$output" ] || { echo "${output}"; return 1; }
  # a read GitHub refuses fails, saying so
  GITHUB_ATTESTATIONS='!1' world github
  run --separate-stderr call attestations
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the attestations of kit-0.1.0.tar.gz could not be read)' ]]
}

@test "every provider lists its alerts in one shape, open and dismissed, and one off here answers 3" {
  world github
  run --separate-stderr call code-scanning-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'del(.age)' <<<"$output" | paste -sd, -)" \
    = '{"number":4,"rule":"js/xss","severity":"high","state":"open","path":"src/app.js",'\
'"url":"https://github.com/empowerite/example/security/code-scanning/4","by":null,"reason":null},'\
'{"number":2,"rule":"js/unused-local-variable","severity":"note","state":"dismissed","path":"src/old.js",'\
'"url":"https://github.com/empowerite/example/security/code-scanning/2","by":"bob","reason":"false positive"}' ]
  [ "$(jq --raw-output '.age > 0' <<<"$output" | sort -u)" = true ]
  run --separate-stderr call dependabot-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'del(.age)' <<<"$output")" \
    = '{"number":1,"rule":"GHSA-35jh-r3h4-6jhm","severity":"high","state":"dismissed","path":"package-lock.json",'\
'"url":"https://github.com/empowerite/example/security/dependabot/1","by":"ada",'\
'"reason":"tolerable_risk: only in tests"}' ]
  # an alert dismissed between the open and the dismissed reads, or updated while its pages are read, is on two
  # pages, and is drawn once, as the last read gives it
  jq '.[0] += [.[0][0] | .state = "dismissed" | .dismissed_by = {login: "ada"}]' "${FAKE_DIR}/gh-code-open.json" \
    | fixture gh-code-twice.json
  GITHUB_CODE_DISMISSED=gh-code-twice.json world github
  run --separate-stderr call code-scanning-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.number, .state, .by]' <<<"$output" | paste -sd, -)" = '[4,"dismissed","ada"]' ]
  world github
  run --separate-stderr call secret-scanning-alerts
  [ "$status" -eq 3 ]
  [ -z "$output$stderr" ]
  # code scanning takes one state a read, so the open and the dismissed are two, each sorted by its update; a
  # dismissed secret is a resolved one, of the resolutions that waive it
  grep --quiet 'code-scanning/alerts?state=open&sort=updated&direction=desc&per_page=100' "${FAKE_DIR}/gh.calls"
  grep --quiet 'dependabot/alerts?state=open,dismissed&sort=updated' "${FAKE_DIR}/gh.calls"
  printf '[[{"number": 9, "state": "resolved", "resolution": "wont_fix", "secret_type": "github_personal_access_token",
    "created_at": "2026-10-01T09:00:00Z", "html_url": "s", "first_location_detected": {"path": ".env"}}]]\n' \
    | fixture gh-secret-resolved.json
  fixture gh-none.json <<<'[[]]'
  GITHUB_SECRET_OPEN=gh-none.json GITHUB_SECRET_RESOLVED=gh-secret-resolved.json world github
  run --separate-stderr call secret-scanning-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'del(.age)' <<<"$output")" \
    = '{"number":9,"rule":"github_personal_access_token","severity":null,"state":"dismissed","path":".env",'\
'"url":"s","by":null,"reason":"wont_fix"}' ]
  grep --quiet 'state=resolved&resolution=false_positive,wont_fix,used_in_tests&sort=updated' "${FAKE_DIR}/gh.calls"
  # GitLab reads its vulnerability report, a scanner each, in GraphQL
  world gitlab
  run --separate-stderr call code-scanning-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'del(.age)' <<<"$output")" \
    = '{"number":4,"rule":"CWE-79","severity":"high","state":"open","path":"src/app.js",'\
'"url":"https://gitlab.com/empowerite/example/-/security/vulnerabilities/4","by":null,"reason":null}' ]
  run --separate-stderr call dependabot-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.number, .state, .path, (.age > 0), .by, .reason]' <<<"$output")" \
    = '[1,"dismissed","package-lock.json",true,"ada","acceptable_risk: only in tests"]' ]
  run --separate-stderr call secret-scanning-alerts
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ -z "$output" ]
  grep --quiet 'state: \[DETECTED, CONFIRMED, DISMISSED\]' "${FAKE_DIR}/glab.calls"
  # a GitLab tier without the vulnerability report, or one that refuses it, has it off
  fixture gl-vulns-null.json <<<'{"data": {"project": {"vulnerabilities": null}}}'
  for said in gl-vulns-null.json '!1 gl-forbidden.txt'
  do
    GITLAB_SAST=${said} world gitlab
    run --separate-stderr call code-scanning-alerts
    [ "$status" -eq 3 ] || { echo "${said}: ${status} ${stderr}"; return 1; }
    [ -z "$output$stderr" ]
  done
}

@test "a GitHub scanner off for the repository is off, and a refusal names who can lift it, never gh auth status" {
  local said
  for said in 'gh: no analysis found (HTTP 404)' 'gh: no default branch found (HTTP 404)' \
    'gh: Code Security must be enabled for this repository to use code scanning. (HTTP 403)' \
    'gh: Advanced Security must be enabled for this repository to use code scanning. (HTTP 403)'
  do
    printf '%s\n' "${said}" | fixture gh-said.txt
    GITHUB_CODE_OPEN='!1 gh-said.txt' world github
    run --separate-stderr call code-scanning-alerts
    [ "$status" -eq 3 ] || { echo "${said}: ${status} ${stderr}"; return 1; }
    [ -z "$output$stderr" ]
  done
  printf '%s\n' 'gh: Dependabot alerts are disabled for this repository. (HTTP 403)' | fixture gh-said.txt
  GITHUB_DEPENDABOT='!1 gh-said.txt' world github
  run --separate-stderr call dependabot-alerts
  [ "$status" -eq 3 ]
  # a rate limit, primary or secondary, answers 403 too, and is named as one, never a refusal
  for said in 'gh: API rate limit exceeded for user ID 1. (HTTP 403)' \
    'gh: You have exceeded a secondary rate limit. Please wait a few minutes before you try again. (HTTP 403)'
  do
    printf '%s\n' "${said}" | fixture gh-said.txt
    GITHUB_DEPENDABOT='!1 gh-said.txt' world github
    route gh 'api rate_limit' '!1'
    run --separate-stderr call dependabot-alerts
    [ "$status" -eq 1 ] || { echo "${said}: ${status}"; return 1; }
    [[ "$stderr" == *'rate limit'*'(the Dependabot alerts could not be read)' ]] || { echo "${stderr}"; return 1; }
    [[ "$stderr" != *'admin'* ]]
    ! grep --quiet 'api --include' "${FAKE_DIR}/gh.calls"
  done
  # a login without a scope GitHub accepts for the alerts is told the one to add
  printf '%s\n' 'gh: Resource not accessible by integration (HTTP 403)' | fixture gh-said.txt
  printf 'HTTP/2.0 403 Forbidden\r\nX-Oauth-Scopes: gist, read:org\r\n%s\r\n\r\n{}\n' \
    'X-Accepted-Oauth-Scopes: repo, security_events' | fixture gh-head-scopes.txt
  GITHUB_DEPENDABOT='!1 gh-said.txt' world github
  route gh 'api --include repos/{owner}/{repo}/dependabot/alerts*' '!1 >gh-head-scopes.txt'
  run --separate-stderr call dependabot-alerts
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth refresh --scopes security_events (the Dependabot alerts could not be read)' ]]
  # a login that has the scope, or a token whose scopes GitHub does not say, is refused the alerts by its role
  printf '%s\n' 'gh: You are not authorized to read code scanning alerts. (HTTP 403)' | fixture gh-said.txt
  printf 'HTTP/2.0 403 Forbidden\r\nX-Oauth-Scopes: repo, read:org\r\n%s\r\n\r\n{}\n' \
    'X-Accepted-Oauth-Scopes: repo, security_events' | fixture gh-head-role.txt
  GITHUB_CODE_OPEN='!1 gh-said.txt' world github
  route gh 'api --include repos/{owner}/{repo}/code-scanning/alerts*' '!1 >gh-head-role.txt'
  run --separate-stderr call code-scanning-alerts
  [ "$status" -eq 1 ]
  [ "$stderr" = '❌ ask an admin of empowerite/example to let you see its security alerts'\
' (the code scanning alerts could not be read)' ]
}

@test "every provider lists the controls on its default branch in one shape: the rules, and how each is enforced" {
  world github
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"id":7,"control":"main","target":["~DEFAULT_BRANCH"],"enforcement":"active",'\
'"rules":["deletion","pull_request"],"checks":[],"reviews":1,"source":"ruleset",'\
'"url":"https://github.com/empowerite/example/rules/7"}' ]
  grep --quiet 'rulesets(first: 100, includeParents: true, targets: \[BRANCH\]) { totalCount' "${FAKE_DIR}/gh.calls"
  # each rule's parameters say the checks and the reviews a merge needs
  grep --quiet 'on RequiredStatusChecksParameters { requiredStatusChecks { context } }' "${FAKE_DIR}/gh.calls"
  grep --quiet 'on PullRequestParameters { requiredApprovingReviewCount }' "${FAKE_DIR}/gh.calls"
  # a branch protection of its own is read for the rules, which GitHub shows only to an admin
  jq '.protection.enabled = true' "${FAKE_DIR}/gh-branch.json" | fixture gh-branch-protected.json
  GITHUB_BRANCH=gh-branch-protected.json world github
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "${lines[1]}" = '{"id":"protection","control":"main","target":["main"],"enforcement":"active",'\
'"rules":["deletion","non_fast_forward","pull_request","required_linear_history","required_status_checks"],'\
'"checks":["ci"],"reviews":1,"source":"protection","url":"https://github.com/empowerite/example/settings/branches"}' ]
  fixture gh-404.txt <<<'gh: Not Found (HTTP 404)'
  GITHUB_BRANCH=gh-branch-protected.json GITHUB_PROTECTION='!1 gh-404.txt' world github
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'select(.source == "protection") | [.id, .rules, .checks, .reviews]' <<<"$output")" \
    = '["protection",null,null,null]' ]
  # a ruleset of a pattern that names the default branch guards it, one that excludes it does not
  jq '.data.repository.rulesets.nodes[1].conditions.refName.include = ["refs/heads/ma*"]
      | .data.repository.rulesets.nodes[0].conditions.refName.exclude = ["refs/heads/main"]' \
    "${FAKE_DIR}/gh-rulesets.json" | fixture gh-rulesets-patterns.json
  GITHUB_RULESETS=gh-rulesets-patterns.json world github
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.id, .enforcement]' <<<"$output")" = '[8,"evaluate"]' ]
  # more rulesets than one read holds fails, as the list would be partial; so does an answer with no repository
  jq '.data.repository.rulesets.totalCount = 101' "${FAKE_DIR}/gh-rulesets.json" | fixture gh-rulesets-101.json
  GITHUB_RULESETS=gh-rulesets-101.json world github
  run --separate-stderr call rulesets
  [ "$status" -eq 1 ]
  [ "$stderr" = '❌ kit reads at most 100 rulesets, and 100 rules and bypass actors of each'\
' (the rulesets could not be read)' ]
  fixture gh-null.json <<<'{"data": {"repository": null}}'
  GITHUB_RULESETS=gh-null.json world github
  run --separate-stderr call rulesets
  [ "$status" -eq 1 ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the rulesets could not be read)' ]]
  # GitLab's are the protected branches that name the default branch, and the push rules
  world gitlab
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  local settings='"url":"https://gitlab.com/empowerite/example/-/settings/repository"}'
  # a merge's checks and approvals are the project's settings, which kit does not read: null, never none
  [ "$output" = '{"id":11,"control":"main","target":["main"],"enforcement":"active",'\
'"rules":["code_owner_review","merge: Developers + Maintainers","non_fast_forward","push: Maintainers"],'\
'"checks":null,"reviews":null,"source":"protection",'"${settings}"$'\n'\
'{"id":13,"control":"ma*","target":["ma*"],"enforcement":"active",'\
'"rules":["merge: Maintainers","push: No one"],"checks":null,"reviews":null,"source":"protection",'"${settings}"$'\n'\
'{"id":"push_rule","control":"push rules","target":["*"],"enforcement":"active",'\
'"rules":["deny_delete_tag","prevent_secrets"],"checks":[],"reviews":0,"source":"ruleset",'"${settings}" ]
  # a project with no push rules answers null, and a tier without them refuses them: either is none
  fixture gl-null.txt <<<'null'
  for said in gl-null.txt '!1 gl-forbidden.txt'
  do
    GITLAB_PUSH_RULE=${said} world gitlab
    run --separate-stderr call rulesets
    [ "$status" -eq 0 ] || { echo "${said}: ${stderr}"; return 1; }
    [ "$(jq --slurp 'length' <<<"$output")" -eq 2 ]
  done
}

@test "GitHub lists who may bypass each control, and the bypassers it hides, or kit cannot name, are one waiver" {
  world github
  run --separate-stderr call bypasses
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$output" = '{"waives":7,"actor":"release","kind":"bypass","reason":"always","by":null,"until":null,'\
'"hidden":null,"url":"https://github.com/empowerite/example/rules/7"}' ] || { echo "${output}"; return 1; }
  # the alerts are not read: a dismissal is a row of the alerts calls
  ! grep --quiet 'alerts' "${FAKE_DIR}/gh.calls"
  # a branch protection's own allowances bypass its pull request rule
  jq '.protection.enabled = true' "${FAKE_DIR}/gh-branch.json" | fixture gh-branch-protected.json
  GITHUB_BRANCH=gh-branch-protected.json world github
  run --separate-stderr call bypasses
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output 'select(.waives == "protection") | [.actor, .reason]' <<<"$output" | paste -sd, -)" \
    = '["ada","pull_request"],["release-bot","pull_request"]' ]
  # GitHub hides a ruleset's bypass actors from who may not edit it: the two hidden are one waiver, by someone
  # unknown, in a mode unknown, which says how many; an organization's admins and a role are named as such
  jq '.data.repository.rulesets.nodes[0].bypassActors.nodes = [null, null,
        {bypassMode: "PULL_REQUEST", organizationAdmin: true, actor: null},
        {bypassMode: "EXEMPT", repositoryRoleName: "maintain", actor: null}]
      | .data.repository.rulesets.nodes[0].bypassActors.totalCount = 4' "${FAKE_DIR}/gh-rulesets.json" \
    | fixture gh-rulesets-hidden.json
  GITHUB_RULESETS=gh-rulesets-hidden.json world github
  run --separate-stderr call bypasses
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.actor, .reason, .hidden]' <<<"$output" | paste -sd, -)" \
    = '["organization admins","pull_request",null],["maintain role","exempt",null],[null,null,2]' ] \
    || { echo "${output}"; return 1; }
  # GitLab keeps no bypasses kit reads
  world gitlab
  run --separate-stderr call bypasses
  [ "$status" -eq 3 ]
}

@test "a login without read:org is asked for the rulesets once more, without the teams, which go unnamed" {
  local said="gh: Your token has not been granted the required scopes to execute this query. The 'slug' field"
  said+=" requires one of the following scopes: ['read:org'], but your token has only been granted the: ['repo']"
  said+=" scopes. (INSUFFICIENT_SCOPES)"
  printf '%s\n' "${said}" | fixture gh-org.txt
  world github
  jq '.data.repository.rulesets.nodes[0].bypassActors.nodes[0].actor = {__typename: "Team"}' \
    "${FAKE_DIR}/gh-rulesets.json" | fixture gh-rulesets-teamless.json
  { printf '%s\t%s\n' 'api graphql*rulesets(first: 100*... on Team { slug }*' '!1 gh-org.txt' \
      'api graphql*rulesets(first: 100*' gh-rulesets-teamless.json
    cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.tmp" && mv "${FAKE_DIR}/routes.tmp" "${FAKE_DIR}/gh.routes"
  : > "${FAKE_DIR}/gh.calls"
  run --separate-stderr call rulesets
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --raw-output .control <<<"$output")" = main ]
  [ -z "$stderr" ]
  # the query spans lines of the calls' record: one rulesets line a request, the second without the team's slug
  [ "$(grep -c 'rulesets(first: 100' "${FAKE_DIR}/gh.calls")" -eq 2 ]
  [ "$(grep -c '... on Team { slug }' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  run --separate-stderr call bypasses
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.waives, .actor, .hidden]' <<<"$output")" = '[7,null,1]' ]
  # a refusal that is not of a team's field fails, naming the scope GitHub names
  printf '%s\n' "${said/'read:org'/'admin:org'}" | sed "s/The 'slug' field/The 'x' field/" | fixture gh-org.txt
  run --separate-stderr call rulesets
  [ "$status" -eq 1 ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth refresh --scopes admin:org (the rulesets could not be read)' ]]
}

@test "a mark that cannot be read is null, its line said, and every other kind is still read" {
  printf 'HTTP/2.0 200 OK\r\nETag: W/"x"\r\n\r\n[]\n' > "${FAKE_DIR}/other-200.txt"
  printf 'HTTP/2.0 404 Not Found\r\n\r\n{"message":"Not Found"}\n' > "${FAKE_DIR}/environments-404.txt"
  world github
  route gh 'api --include repos/{owner}/{repo}/environments?per_page=100' '!1 >environments-404.txt'
  route gh 'api --include*' other-200.txt
  run --separate-stderr call marks issues environments runs
  [ "$status" -eq 1 ]
  [ "$output" = '{"issues":"W/\"x\"","environments":null,"runs":"W/\"x\""}' ]
  [[ "$stderr" == '❌ run: cd '*' && gh auth status (the environments mark could not be read)' ]]
  # GitLab's, the same
  world gitlab
  local p='projects/empowerite%2Fexample'
  fixture gl-pipelines.json <<<'[{"id": 11, "status": "success", "updated_at": "2026-11-03T09:00:00.000Z"}]'
  route glab "api ${p}/environments?per_page=100" '!1'
  route glab "api ${p}/pipelines?per_page=10" gl-pipelines.json
  run --separate-stderr call marks environments runs
  [ "$status" -eq 1 ]
  [ "$output" = '{"environments":null,"runs":"[[11,\"success\",\"2026-11-03T09:00:00.000Z\"]]"}' ]
  [[ "$stderr" == '❌ run: cd '*' && glab auth status (the environments mark could not be read)' ]]
}

@test "a GitHub scanner off or refused is asked again only once ten minutes have passed since it said so" {
  printf 'HTTP/2.0 200 OK\r\nETag: W/"x"\r\n\r\n[]\n' > "${FAKE_DIR}/other-200.txt"
  printf 'HTTP/2.0 404 Not Found\r\n\r\n{"message":"Secret scanning is disabled on this repository."}\n' \
    > "${FAKE_DIR}/secret-404.txt"
  printf 'HTTP/2.0 403 Forbidden\r\n\r\n{"message":"You are not authorized to read code scanning alerts."}\n' \
    > "${FAKE_DIR}/code-403.txt"
  world github
  route gh 'api --include repos/{owner}/{repo}/secret-scanning/*' '!1 >secret-404.txt'
  route gh 'api --include repos/{owner}/{repo}/code-scanning/*' '!1 >code-403.txt'
  route gh 'api --include*' other-200.txt
  run call marks alerts
  [ "$status" -eq 0 ]
  [ "$output" = '{"alerts":"refused W/\"x\" off"}' ]
  run call marks alerts
  [ "$output" = '{"alerts":"refused W/\"x\" off"}' ]
  # two reads, a request each of the scanner that answers, one of each that does not
  [ "$(grep --count 'secret-scanning' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  [ "$(grep --count 'code-scanning' "${FAKE_DIR}/gh.calls")" -eq 1 ]
  [ "$(grep --count 'dependabot' "${FAKE_DIR}/gh.calls")" -eq 2 ]
  # once ten minutes have passed, it is asked again, and a scanner turned on gives its mark
  local kept
  kept=$(bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:snapshots')
  for scanner in secret-scanning code-scanning
  do
    printf '%s %s\n' "$(( $(date +%s) - 601 ))" "$(cut -d ' ' -f 2 "${kept}/marks-${scanner}.verdict")" \
      > "${kept}/marks-${scanner}.verdict"
  done
  : > "${FAKE_DIR}/gh.routes"
  route gh 'api --include*' other-200.txt
  run call marks alerts
  [ "$output" = '{"alerts":"W/\"x\" W/\"x\" W/\"x\""}' ]
  [ "$(grep --count 'secret-scanning' "${FAKE_DIR}/gh.calls")" -eq 2 ]
}

@test "a GitHub scanner that refuses the caller marks the alerts refused, so the mark stays live for the others" {
  printf 'HTTP/2.0 403 Forbidden\r\n\r\n{"message":"You are not authorized to read code scanning alerts."}\n' \
    > "${FAKE_DIR}/code-403.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"x"\r\n\r\n[]\n' > "${FAKE_DIR}/other-200.txt"
  world github
  route gh 'api --include repos/{owner}/{repo}/code-scanning/alerts?sort=updated&direction=desc&per_page=1' \
    '!1 >code-403.txt'
  route gh 'api --include*' other-200.txt
  run --separate-stderr call marks
  [ "$status" -eq 0 ] || { echo "${stderr}"; return 1; }
  [ "$(jq --compact-output '[.alerts, .runs]' <<<"$output")" = '["refused W/\"x\" W/\"x\"","W/\"x\""]' ]
}

# ----------------------------------------------------------------------------------------------------------------------

@test "a scanner's mark that GitHub's rate limit stops fails with the limit named, and keeps no verdict" {
  local verdicts
  printf 'HTTP/2.0 403 Forbidden\r\n\r\n{"message":"API rate limit exceeded for user ID 1."}\n' > "${FAKE_DIR}/code-limit.txt"
  printf 'HTTP/2.0 200 OK\r\nETag: W/"x"\r\n\r\n[]\n' > "${FAKE_DIR}/other-200.txt"
  world github
  route gh 'api rate_limit' '!1'
  route gh 'api --include repos/{owner}/{repo}/code-scanning/alerts?sort=updated&direction=desc&per_page=1' \
    '!1 >code-limit.txt'
  route gh 'api --include*' other-200.txt
  run --separate-stderr call marks
  [[ "${stderr}" == *'rate limit'* ]] || { echo "${status} ${stderr}"; return 1; }
  [[ "${stderr}" != *'gh auth status'* ]]
  verdicts=$(dirname "$(snapshot github open-prs)")
  run compgen -G "${verdicts}/marks-*.verdict"
  [ "$status" -ne 0 ]
}

@test "the primary's repository is read from its URL, so a spent rate limit is never told as a wrong checkout" {
  world github
  route gh 'repo view*' '!1'
  : > "${FAKE_DIR}/gh.calls"
  run call repo
  [ "$output" = empowerite/example ]
  run call repo-url
  [ "$output" = https://github.com/empowerite/example ]
  ! grep --quiet '^repo view' "${FAKE_DIR}/gh.calls"
}

@test "a pull request from a fork whose branch has this branch's name is not this branch's" {
  world github
  fixture pr-open.json <<<'[{"number": 9, "isCrossRepository": true}, {"number": 3, "isCrossRepository": false}]'
  run call pr-for-branch 7-fix-the-thing
  [ "$output" = 3 ]
  fixture pr-open.json <<<'[{"number": 9, "isCrossRepository": true}]'
  run call pr-for-branch 7-fix-the-thing
  [ -z "$output" ]
  fixture open-heads.json <<<'[{"headRefName": "7-from-a-fork", "isCrossRepository": true}]'
  run call branch-for-issue 7
  [ -z "$output" ]
}

@test "a GitHub repository with Issues turned off answers 3 to its open issues, as the contract says, and says nothing" {
  fixture gh-off.txt <<<"the 'empowerite/example' repository has disabled issues"
  world github
  { printf 'issue list --state open*\t!1 gh-off.txt\n'; cat "${FAKE_DIR}/gh.routes"; } > "${FAKE_DIR}/routes.all"
  mv "${FAKE_DIR}/routes.all" "${FAKE_DIR}/gh.routes"
  run --separate-stderr call open-issues
  [ "$status" -eq 3 ] || { echo "${status} ${stderr}"; return 1; }
  [ -z "$output$stderr" ]
}

@test "a lock whose process number a live process has is taken over once the wait runs out, and the read is kept" {
  local dir
  world github
  dir=$(bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:snapshots')
  mkdir -p "${dir}"
  # the number of a process that is alive, as a dead holder's may be once another process has it
  ln -s "$$" "${dir}/open-prs.lock"
  : > "${FAKE_DIR}/gh.calls"
  run bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge_snapshot_wait=2 && forge:open-prs'
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output .ref <<<"$output")" = "#3" ]
  [ -f "${dir}/open-prs.json" ]
  [ ! -e "${dir}/open-prs.lock" ]
  run call open-prs
  [ "$(reads github)" -eq 1 ]
}

@test "a change made while another process reads leaves no snapshot of the read that began before it" {
  local dir
  world github
  dir=$(bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge && forge:snapshots')
  mkdir -p "${dir}"
  # the read has begun when the change drops the snapshots: the answer it then writes is of before the change
  run bash -c 'source "${kit_root}/modules/bash/1st.sh" && use forge
    forge:call() { forge:forget; printf "{}\n"; }
    forge:snapshot-take open-prs "$0"' "${dir}/open-prs.json"
  [ ! -e "${dir}/open-prs.json" ]
}
