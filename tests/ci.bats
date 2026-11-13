#!/usr/bin/env bats
# ci.bats - kit ci runs kit linked, kit policy, the gate, and kit check, in that order, and reports every one
# ----------------------------------------------------------------------------------------------------------------------

bats_require_minimum_version 1.5.0

load helper

# ci-world makes the repository every test starts from: origin on GitHub, the kit installed, and gh failing.
ci-world() {
  mkdir shims && printf '#!/usr/bin/env bash\nexit 1\n' > shims/gh && chmod +x shims/gh
  git init --quiet --initial-branch=main repo && cd repo \
    && git remote add origin https://github.com/empowerite/example.git \
    && PATH="${PWD}/../shims:${PATH}" "${kit_checkout}/bin/kit" install
}

setup_file() {
  world-make installed ci-world
}

setup() {
  PATH=$(shims gh)
  world-copy-repo installed
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/summary.md"
}

@test "every check runs and the refusals are counted" {
  printf 'ci:\n  echo gate ran\n' > justfile
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" == *"gate ran"* ]]
  [[ "$output" == *"every delivered file matches"* ]]
  # gh fails, so kit linked cannot tell which pull request this checkout is working on, and refuses, naming the read
  [[ "$output" == *"run: cd "*" && gh auth status (the open pull request on main could not be read)"* ]]
  [[ "$output" == *"the patterns policy allows"* ]]
  [[ "$output" == *"1 of 4 checks refused"* ]]
  # a stray file under a delivered directory: check reports it, and no verb heals it
  printf 'rogue\n' > .kit/rules/rogue.md
  rm justfile
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" == *"3 of 4 checks refused"* ]]
}

@test "the issue link and the policy are judged before the gate and kit check run any command of the branch" {
  printf 'ci:\n  echo gate ran\n' > justfile
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  in-order "$output" "── kit linked ──" "── kit policy ──" "── kit gate ──" "gate ran" \
    "── kit check ──"
}

@test "on a CI system that is no forge's own, kit ci judges the change by its base's policy, or fails" {
  fake-tools gh
  fixture repo.json <<<'{"nameWithOwner": "empowerite/example", "url": "https://github.com/empowerite/example"}'
  fixture pr.json <<<'{"number": 3, "title": "Fix the thing", "body": ""}'
  fixture pull.json <<<'{"user": {"login": "ada"}}'
  fixture closing.json <<'JSON'
{"data": {"repository": {"pullRequest": {"closingIssuesReferences": {"nodes": [
  {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "empowerite/example"}}]}}}}}
JSON
  route gh 'repo view*' repo.json
  route gh 'pr view 3 --json *' pr.json
  route gh 'api repos/empowerite/example/pulls/3 *' pull.json
  route gh 'api graphql*' closing.json
  # the primary is a repository the runner can fetch the change's target from, so kit.yml names its forge
  git init --quiet --bare "${BATS_TEST_TMPDIR}/origin.git"
  git remote set-url origin "${BATS_TEST_TMPDIR}/origin.git"
  printf 'ci:\n  echo gate ran\n' > justfile
  printf 'forge: github\n' >> kit.yml
  git add --all
  git commit --quiet --message "#1 start: the kit" && git push --quiet origin main
  # the branch carries its own judge: it turns off the rule that refuses its commit
  git switch --quiet --create 7-fix-the-thing
  printf 'policy:\n  commit_subject: ""\n' >> kit.yml
  git commit --quiet --all --message "no reference"
  git checkout --quiet --detach
  # Drone checks the change out detached, and names it, its head branch, and its target
  export DRONE=true DRONE_PULL_REQUEST=3 DRONE_SOURCE_BRANCH=7-fix-the-thing DRONE_TARGET_BRANCH=main
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" == *"pull request #3 is linked to #7"* ]]
  [[ "$output" == *"'no reference' does not match policy.commit_subject"* ]]
  [[ "$output" != *"policy allows"* ]]
  [[ "$output" == *"1 of 4 checks refused"* ]]
  # a runner that names no change cannot judge a detached HEAD, so the policy fails beside the issue link
  run env -u GITHUB_EVENT_PATH -u DRONE_PULL_REQUEST "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" == *"HEAD is detached on a CI runner that names no change"* ]]
  [[ "$output" != *"policy allows"* ]]
  [[ "$output" == *"2 of 4 checks refused"* ]]
}

@test "kit lint is not one of the four checks: a workflow kit lint refuses does not fail kit ci" {
  printf 'ci:\n  echo gate ran\n' > justfile
  mkdir -p .github/workflows
  printf 'on: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v7\n' \
    > .github/workflows/w.yml
  # staged, so kit lint with no path, and with --all-files, would each read it
  git add .github/workflows/w.yml
  run "${kit_checkout}/bin/kit" lint
  [ "$status" -eq 1 ]
  [[ "$output" == *"uses: actions/checkout@v7 is not pinned to a commit SHA"* ]]
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  # gh fails, so kit linked refuses, and it alone: no check of kit ci runs a rule's linter or its checks
  [[ "$output" == *"1 of 4 checks refused"* ]]
  [[ "$output" != *"is not pinned to a commit SHA"* ]]
}

# change-of-its-own makes the checkout hold what a change can carry to run before it is judged: a manifest whose
# install script leaves a mark, its lock, and a git and a bash where npm puts a package's commands, each leaving a
# mark before it runs the real one. npm is a stand-in whose ci runs the manifest's install script, as npm's does, and
# gh one that writes to seen every mark that is there when a judgement asks the forge, and fails.
change-of-its-own() {
  local tool
  marks="${BATS_TEST_TMPDIR}/marks" seen="${BATS_TEST_TMPDIR}/seen"
  mkdir -p "${marks}" node_modules/.bin
  : > "${seen}"
  printf '{"name": "x", "scripts": {"postinstall": "touch %s/install-script && echo the install script ran"}}\n' \
    "${marks}" > package.json
  printf '{"packages": {"": {}}}\n' > package-lock.json
  for tool in git bash
  do
    printf '#!/bin/sh\ntouch %s\nexec %s "$@"\n' "${marks}/${tool}" "$(command -v "${tool}")" > "node_modules/.bin/${tool}"
    chmod +x "node_modules/.bin/${tool}"
  done
  printf '#!/usr/bin/env bash\n[[ "$1" != ci ]] || bash -c "$(jq --raw-output .scripts.postinstall package.json)"\n' \
    > "${BATS_TEST_TMPDIR}/shims/npm"
  printf '#!/usr/bin/env bash\nprintf "%%s: %%s\\n" "$*" "$(ls %q | paste -s -d " " -)" >> %q\nexit 1\n' \
    "${marks}" "${seen}" > "${BATS_TEST_TMPDIR}/shims/gh"
  chmod +x "${BATS_TEST_TMPDIR}/shims/npm" "${BATS_TEST_TMPDIR}/shims/gh"
  printf 'ci:\n  echo gate ran\n' > justfile
  git add --force package.json package-lock.json node_modules justfile && git commit --quiet --message "#7 cli: a change with an install script and tools of its own"
}

# run-job <job> runs each step of the delivered workflow's job that is a script, in order, as a runner does: with the
# job's env, each step in a bash found on PATH, and each directory a step writes to GITHUB_PATH put first on PATH for
# the steps after it. A step guarded by if:, as a toolchain's bootstrap, is passed by. It stops at a step that fails.
run-job() {
  local workflow=.github/workflows/kit-ci.yml count i script dir line
  local -a added
  export GITHUB_PATH="${BATS_TEST_TMPDIR}/github-path" GITHUB_WORKSPACE="${PWD}" RUNNER_TEMP="${BATS_TEST_TMPDIR}/runner"
  export GITHUB_ENV="${BATS_TEST_TMPDIR}/github-env"
  export CI=true GH_TOKEN=none KIT_TOOLCHAIN MISE_ENV BASE_SHA="${base_sha}"
  KIT_TOOLCHAIN=$(yq ".jobs.$1.env.KIT_TOOLCHAIN" "${workflow}")
  MISE_ENV=$(yq ".jobs.$1.env.MISE_ENV" "${workflow}")
  mkdir -p "${RUNNER_TEMP}"
  count=$(yq ".jobs.$1.steps | length" "${workflow}")
  for (( i = 0; i < count; i++ ))
  do
    script=$(yq ".jobs.$1.steps[${i}] | select(has(\"run\") and (has(\"if\") | not)) | .run" "${workflow}")
    [[ -n "${script}" ]] || continue
    : > "${GITHUB_PATH}" && : > "${GITHUB_ENV}"
    bash -c "${script}" || return 1
    while IFS= read -r line
    do
      [[ -z "${line}" ]] || export "${line?}"
    done < "${GITHUB_ENV}"
    readarray -t added < "${GITHUB_PATH}"
    for dir in "${added[@]}"
    do
      PATH="${dir}:${PATH}"
    done
  done
}

@test "the delivered job judges before anything of the change's is installed, run, or put on PATH" {
  "${kit_checkout}/bin/kit" packages add github/ci >/dev/null
  # kit.yml declares unreleased, so the job takes the checkout's own kit, as in a checkout of the kit; the base holds it
  mkdir -p kit/bin && ln -s "${kit_checkout}/bin/kit" kit/bin/kit
  git add kit.yml kit .github && git commit --quiet --message "#1 kit: the base"
  base_sha=$(git rev-parse HEAD)
  change-of-its-own
  # the change names a kit release of its own, which no runner has: the release the base declares is the one used
  printf 'version: 9.9.9\npackages:\n  - kit\n  - github/ci\n' > kit.yml
  git commit --quiet --all --message "#7 kit: a release of our own"
  printf '#!/usr/bin/env bash\nexit 1\n' > "${BATS_TEST_TMPDIR}/shims/curl" && chmod +x "${BATS_TEST_TMPDIR}/shims/curl"
  run run-job CI
  [ "$status" -eq 1 ]
  # the forge was asked, and nothing of the change's had run by then: no install script, no git or bash of its own
  [[ "$(head -n 1 "${BATS_TEST_TMPDIR}/seen")" == *": " ]]
  [[ "$output" == *"(the open pull request on main could not be read)"* ]]
  # the change's tools are installed after the two judgements, for the gate, which is the change's own to run
  in-order "$output" "── kit linked ──" "── kit policy ──" "── kit tools install ──" "the install script ran" \
    "── kit gate ──" "gate ran" "── kit check ──"
  [ -e "${BATS_TEST_TMPDIR}/marks/install-script" ]
}

@test "on a runner, kit ci installs the change's tools after the two judgements, and at a desk it installs nothing" {
  change-of-its-own
  run env -u GITHUB_EVENT_PATH "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" != *"kit tools install"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/marks/install-script" ]
  run env -u GITHUB_EVENT_PATH CI=true "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  in-order "$output" "── kit linked ──" "── kit policy ──" "── kit tools install ──" "the install script ran" \
    "── kit gate ──" "gate ran" "── kit check ──"
  [[ "$(head -n 1 "${BATS_TEST_TMPDIR}/seen")" == *": " ]]
  [[ "$output" == *"1 of 4 checks refused"* ]]
}

@test "on a runner, tools that cannot be installed fail kit ci, and every check still runs" {
  printf 'ci:\n  echo gate ran\n' > justfile
  mkdir -p .kit/rules
  printf -- '---\nlint: kit-test-absent-linter --strict\n---\n# Absent\n' > .kit/rules/absent.md
  run env -u GITHUB_EVENT_PATH CI=true KIT_TOOLCHAIN=ambient "${kit_checkout}/bin/kit" ci
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit-test-absent-linter"* ]]
  [[ "$output" == *"gate ran"* ]]
  [[ "$output" == *"the change's tools could not be installed"* ]]
}

# ----------------------------------------------------------------------------------------------------------------------

@test "the CI workflow names the toolchain the ci_toolchain answer gives, ambient by default" {
  fresh-repo other >/dev/null
  "${kit_checkout}/bin/kit" install github/ci >/dev/null
  workflow=.github/workflows/kit-ci.yml
  grep --quiet '^      KIT_TOOLCHAIN: "ambient"$' "${workflow}"
  # actionlint refuses a guard that compares two constants, so each guard reads the env the answer sets
  for toolchain in mise nix devcontainer
  do
    grep --quiet "if: \${{ env.KIT_TOOLCHAIN == '${toolchain}' }}" "${workflow}"
  done
  fresh-repo third >/dev/null
  mkdir .kit && printf 'answers:\n  ci_toolchain: nix\n' > kit.yml
  "${kit_checkout}/bin/kit" install github/ci >/dev/null
  grep --quiet '^      KIT_TOOLCHAIN: "nix"$' "${workflow}"
  # each bootstrap step is pinned: nix by commit SHA, the devcontainer CLI by exact version
  grep --quiet 'uses: DeterminateSystems/nix-installer-action@[0-9a-f]\{40\}  # v[0-9.]*$' "${workflow}"
  grep --quiet 'npm install --global @devcontainers/cli@[0-9][0-9.]*$' "${workflow}"
}

@test "the CI job stops after the minutes the ci_timeout_minutes answer gives, 30 by default" {
  fresh-repo other >/dev/null
  "${kit_checkout}/bin/kit" install github/ci >/dev/null
  workflow=.github/workflows/kit-ci.yml
  grep --quiet "^    timeout-minutes: \${{ fromJSON('30') }}$" "${workflow}"
  fresh-repo third >/dev/null
  mkdir .kit && printf 'answers:\n  ci_timeout_minutes: "12"\n' > kit.yml
  "${kit_checkout}/bin/kit" install github/ci >/dev/null
  grep --quiet "^    timeout-minutes: \${{ fromJSON('12') }}$" "${workflow}"
}

@test "the CI workflow installs nothing before kit ci, and caches the kit toolchain's tools by tools.lock" {
  fresh-repo other >/dev/null
  "${kit_checkout}/bin/kit" install github/ci >/dev/null
  workflow=.github/workflows/kit-ci.yml
  # kit ci installs the change's tools itself, after the two judgements: no step runs kit tools, and the last is kit ci
  run ! grep --quiet 'kit tools' <<<"$(yq '.jobs.CI.steps[].run // ""' "${workflow}")"
  [ "$(yq '.jobs.CI.steps[-1].run' "${workflow}")" = "kit ci" ]
  # the only directory a step puts on the job's PATH is kit's own
  [ "$(grep -c 'GITHUB_PATH' <<<"$(yq '.jobs.CI.steps[].run // ""' "${workflow}")")" -eq 2 ]
  run ! grep --quiet 'kit tools path' "${workflow}"
  # a step runs by the toolchain the answer names, never by which files are here
  run ! grep --quiet 'if: .*hashFiles' "${workflow}"
  grep --quiet "^        if: \${{ env.KIT_TOOLCHAIN == 'kit' }}$" "${workflow}"
  grep --quiet "^          key: kit-tools-\${{ runner.os }}-\${{ runner.arch }}-\${{ hashFiles('tools.lock') }}$" "${workflow}"
}

