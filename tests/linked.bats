#!/usr/bin/env bats
# linked.bats - kit linked names the pull request it needs when none can be found; the forge fakes test the rest
# ----------------------------------------------------------------------------------------------------------------------

load helper

setup() {
  fresh-repo
  git remote add origin https://github.com/empowerite/example.git
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/summary.md"
}

@test "linked names the pull request it needs when none can be found" {
  # gh answers that the branch has no pull request: its filter of an empty list prints nothing
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${BATS_TEST_TMPDIR}/bin/gh" && chmod +x "${BATS_TEST_TMPDIR}/bin/gh"
  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit linked <number>"* ]]
}

# runner-change makes what a CI system that is no forge's own builds a change from: a primary the runner can fetch
# the change's target from, whose forge kit.yml names since its address is a path; a base whose kit.yml exempts bob;
# and a detached checkout of the branch 7-fix-the-thing, whose own kit.yml exempts ada, the change's author.
runner-change() {
  git init --quiet --bare "${BATS_TEST_TMPDIR}/origin.git"
  git remote set-url origin "${BATS_TEST_TMPDIR}/origin.git"
  printf 'forge: github\nlinked_exempt:\n  - bob\n' > kit.yml
  git add kit.yml
  git commit --quiet --message "#1 kit: bob is exempt" && git push --quiet origin main
  git switch --quiet --create 7-fix-the-thing
  printf 'forge: github\nlinked_exempt:\n  - ada\n' > kit.yml
  git commit --quiet --all --message "#7 kit: ada is exempt"
  git checkout --quiet --detach
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture pull.json <<<'{"user": {"login": "ada"}}'
  fixture pr.json <<<'{"body": ""}'
  route gh 'repo view*' repo.json
  route gh 'api repos/empowerite/example/pulls/3 *' pull.json
  route gh 'pr view 3 --json *' pr.json
}

@test "on a detached HEAD, as a CI system that is no forge's own checks one out, linked finds the change it names" {
  fake-tools gh
  runner-change
  fixture closing.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": [
  {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  route gh 'api graphql*' closing.json
  # Drone names the change it builds, its head branch, and its target
  DRONE=true DRONE_PULL_REQUEST=3 DRONE_SOURCE_BRANCH=7-fix-the-thing DRONE_TARGET_BRANCH=main \
    run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull request #3 is linked to #7"* ]]
  # a runner that names none is still refused
  run env -u GITHUB_EVENT_PATH -u DRONE_PULL_REQUEST "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *"name the change: kit linked <number>"* ]]
}

@test "on a CI system that is no forge's own, the logins exempt are the base's: a branch cannot exempt its author" {
  fake-tools gh
  runner-change
  fixture closing.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": []}}}}}'
  route gh 'api graphql*' closing.json
  export DRONE=true DRONE_PULL_REQUEST=3 DRONE_SOURCE_BRANCH=7-fix-the-thing DRONE_TARGET_BRANCH=main
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *"pull request #3 is not linked to any issue"* ]]
  [[ "$output" != *"exempt"* ]]
  # a change whose branches the runner does not name has no base to read, and fails before the forge is asked
  : > "${FAKE_DIR}/gh.calls"
  run env -u GITHUB_EVENT_PATH -u DRONE_SOURCE_BRANCH "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *"the head branch of the change is not in the runner's environment"* ]]
  [ ! -s "${FAKE_DIR}/gh.calls" ]
  # and a runner that names no change at all reads no exemption from a detached checkout, given the number or not
  run env -u GITHUB_EVENT_PATH -u DRONE_PULL_REQUEST "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"HEAD is detached on a CI runner that names no change"* ]]
  [[ "$output" != *"exempt"* ]]
  [ ! -s "${FAKE_DIR}/gh.calls" ]
}

@test "linked fails, naming the read, when the forge cannot say which pull request this checkout is working on" {
  PATH=$(shims gh) run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *"run: cd "*" && gh auth status (the open pull request on main could not be read)"* ]]
  [[ "$output" != *"kit linked <number>"* ]]
}

@test "on a branch, kit linked exempts the logins its base's kit.yml lists, and on the default branch the disk's" {
  fake-tools gh
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture pull.json <<<'{"user": {"login": "ada"}}'
  fixture pr.json <<<'{"body": ""}'
  fixture closing.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": []}}}}}'
  route gh 'repo view*' repo.json
  route gh 'api repos/empowerite/example/pulls/3 *' pull.json
  route gh 'pr view 3 --json *' pr.json
  route gh 'api graphql*' closing.json
  printf 'linked_exempt:\n  - bob\n' > kit.yml
  git add kit.yml
  git commit --quiet --message "#1 kit: bob is exempt"
  git update-ref refs/remotes/origin/main HEAD
  git switch --quiet --create 7-fix-the-thing
  printf 'linked_exempt:\n  - ada\n' > kit.yml
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"pull request #3 is not linked to any issue"* ]]
  [[ "$output" != *"exempt"* ]]
  git switch --quiet main
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull request #3 is ada's, exempt from the linked-issue check by kit.yml"* ]]
}

@test "an issue whose state its tracker cannot read is named, and never called closed" {
  fake-tools gh az
  printf 'trackers:\n  - prefix: "AB#"\n    provider: ado\n    organization: https://dev.azure.com/example\n' > kit.yml
  printf '    project: Claims\n' >> kit.yml
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture closing.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": []}}}}}'
  fixture pr.json <<<'{"body": "Closes AB#4521"}'
  route gh 'repo view*' repo.json
  route gh 'api graphql*' closing.json
  route gh 'pr view 3 --json *' pr.json
  route az 'boards work-item show --id 4521 *' '!1'
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"AB#4521's state could not be read, so it does not count"* ]]
  [[ "$output" == *"the state of 1 linked issue(s) could not be read"* ]]
  [[ "$output" != *"closed"* ]]
  grep --quiet 'boards work-item show --id 4521' "${FAKE_DIR}/az.calls"
  grep --quiet 'could not be read' "${GITHUB_STEP_SUMMARY}"
}

@test "an issue of a tracker kit only opens the pages of never counts, as the introduction says; one kit reads does" {
  # The delivered introduction names the trackers kit reads, then says what kit does with any other: a ticket system
  # with no provider but web is named only there.
  line=$(awk '/^- \[Trackers\]/ { on = 1; print; next } on && /^  / { print; next } { on = 0 }' \
    "${kit_root}/packages/kit/files/repo/.kit/welcome/1-introduction.md" | tr '\n' ' ')
  [[ "${line}" == *"opens the pages"*'`kit linked`'* ]]
  [[ "${line%%opens the pages*}" != *Jira* && "${line%%opens the pages*}" != *Linear* ]]
  fake-tools gh
  printf 'trackers:\n  - prefix: "LIN#"\n    provider: web\n' > kit.yml
  printf '    url: https://linear.app/example/issue/ENG-{id}\n' >> kit.yml
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture closing.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": []}}}}}'
  fixture pr.json <<<'{"body": "Closes LIN#12"}'
  route gh 'repo view*' repo.json
  route gh 'api graphql*' closing.json
  route gh 'pr view 3 --json *' pr.json
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit cannot read its state in the LIN# tracker, which it reaches through its pages alone"* ]]
  [[ "$output" == *"LIN#12's state could not be read, so it does not count"* ]]
  # with an open issue of the repository linked beside it, the change passes
  fixture closing.json <<<'{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": [
    {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}'
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIN#12's state could not be read, so it does not count"* ]]
}

@test "on a branch, kit linked fails when the base is not here, since the logins it exempts cannot be read" {
  fake-tools gh
  git commit --quiet --allow-empty --message "#1 start: the first"
  git switch --quiet --create 7-fix-the-thing
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  # origin's HEAD is not recorded, so the default branch is taken to be main, which is not here either
  [[ "$output" == *"run: cd "*" && git remote set-head origin --auto (origin/HEAD is not recorded"* ]]
  [ ! -s "${FAKE_DIR}/gh.calls" ]
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  run "${kit_checkout}/bin/kit" linked 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"the base, origin/main, is not here, so its policy cannot be read"* ]]
  [ ! -s "${FAKE_DIR}/gh.calls" ]
}

# ----------------------------------------------------------------------------------------------------------------------
