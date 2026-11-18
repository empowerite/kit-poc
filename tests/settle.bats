#!/usr/bin/env bats
# settle.bats - kit settle and kit close report each issue they could not change, name which, and exit 1
# ----------------------------------------------------------------------------------------------------------------------
# A world of one GitHub repository and an Azure Boards tracker. Pull request 3 is merged and says Closes AB#4521, as
# GitHub closes its own issues itself; 4 is closed unmerged and says Closes #7. A case takes one route away, and the fake
# fails a call no route answers, so each failure branch of issue:settle is reached.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fresh-repo
  git remote add origin https://github.com/empowerite/example.git
  printf 'forge: github\ntrackers:\n  - prefix: "AB#"\n    provider: ado\n    organization: https://dev.azure.com/example\n' \
    > kit.yml
  printf '    project: Claims Team\n' >> kit.yml
  world
}

# world makes the fake gh, with every route, as it is before a case takes one away.
world() {
  fake-tools gh az
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture merged.json <<<'{"state": "MERGED", "mergeCommit": {"oid": "abcdef0123456789"}}'
  fixture closed.json <<<'{"state": "CLOSED", "mergeCommit": null}'
  fixture body.json <<<'{"body": "Does the work.\nCloses #7"}'
  fixture merged-body.json <<<'{"body": "Does the work.\nCloses AB#4521"}'
  fixture item.json <<'JSON'
{"id": 4521, "fields": {"System.Title": "Fix it", "System.State": "Active"}}
JSON
  fixture author.json <<<'{"user": {"login": "ada"}}'
  fixture closing.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": [
  {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  fixture issue.json <<<'{"title": "Seven", "state": "OPEN", "assignees": [{"login": "ada"}]}'
  fixture user.json <<<'{"login": "ada"}'
  route gh 'api user*' user.json
  route gh 'repo view*' repo.json
  route gh 'pr view 3 --json state,mergeCommit*' merged.json
  route gh 'pr view 4 --json state,mergeCommit*' closed.json
  route gh 'pr view 3 --json body*' merged-body.json
  route gh 'pr view 4 --json body*' body.json
  route gh 'api repos/empowerite/example/pulls/4 *' author.json
  route gh 'api graphql*number=4*' closing.json
  route gh 'issue view 7 *' issue.json
  route gh 'issue comment 7 *' '!0'
  route gh 'issue close 7 *' '!0'
  route gh 'issue edit 7 --remove-assignee ada' '!0'
  route az 'boards work-item show --id 4521 *' item.json
  route az 'boards work-item update --id 4521 --discussion*' '!0'
  route az 'boards work-item update --id 4521 --state*' '!0'
}

# without <tool> <glob> takes the tool's route for <glob> away, so the call it names fails.
without() {
  local tool=${1%% *}
  grep --invert-match --fixed-strings "${1#* }"$'\t' "${FAKE_DIR}/${tool}.routes" > "${FAKE_DIR}/${tool}.routes.new" || true
  mv "${FAKE_DIR}/${tool}.routes.new" "${FAKE_DIR}/${tool}.routes"
}

@test "settling a merged change fails, naming the issue, where its state cannot be read, or it cannot be commented on or closed" {
  local case route line
  for case in "az boards work-item show --id 4521 *|AB#4521 could not be closed: its state could not be read" \
    "az boards work-item update --id 4521 --discussion*|AB#4521 could not be closed" \
    "az boards work-item update --id 4521 --state*|AB#4521 could not be closed"
  do
    route=${case%%|*} line=${case#*|}
    world
    without "${route}"
    run "${kit_root}/bin/kit" settle 3
    [ "$status" -eq 1 ]
    [[ "$output" == *"${line}"* ]]
    [[ "$output" != *"AB#4521 closed: pull request #3 merged"* ]]
  done
}

@test "settling a change closed unmerged fails, naming the issue, where its assignees cannot be read, or it cannot be put back" {
  local case route line
  for case in "gh issue view 7 *|#7 could not be put back: its assignees could not be read" \
    "gh issue comment 7 *|#7 could not be put back" "gh issue edit 7 --remove-assignee ada|#7 could not be put back"
  do
    route=${case%%|*} line=${case#*|}
    world
    without "${route}"
    run "${kit_root}/bin/kit" settle 4
    [ "$status" -eq 1 ]
    [[ "$output" == *"${line}"* ]]
    [[ "$output" != *"#7 is backlog again"* ]]
  done
}

@test "settling reads a change's own state first: a change whose state cannot be read fails with 1" {
  without 'gh pr view 3 --json state,mergeCommit*'
  run "${kit_root}/bin/kit" settle 3
  [ "$status" -eq 1 ]
}

@test "closing an issue fails, naming it, where its state cannot be read, or it cannot be closed, or a duplicate names itself" {
  without 'gh issue view 7 *'
  run "${kit_root}/bin/kit" close --not-planned 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"#7 could not be closed: its state could not be read"* ]]
  world
  without 'gh issue close 7 *'
  run "${kit_root}/bin/kit" close --not-planned 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"#7 could not be closed"* ]]
  [[ "$output" != *"#7 closed as"* ]]
  run "${kit_root}/bin/kit" close --duplicate-of=7 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"#7 cannot be a duplicate of itself"* ]]
}
