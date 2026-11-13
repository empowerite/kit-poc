#!/usr/bin/env bats
# helper.bats - helper:isolate leaves no variable of the caller's environment that a test would read by mistake
# ----------------------------------------------------------------------------------------------------------------------

bats_require_minimum_version 1.5.0

load helper

@test "git's own variables, the forge tokens, and the markers of a desk are unset in a test, whatever the caller set" {
  local names=() name
  while IFS= read -r name
  do
    names+=("${name}")
  done < <(git rev-parse --local-env-vars)
  names+=(GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL GH_TOKEN GITHUB_TOKEN GH_HOST KIT_BASE IN_NIX_SHELL CODESPACES DOCKER_HOST)
  run env "${names[@]/%/=x}" bash -c 'source "$1/helper.bash"; helper:isolate-in "$2"; env' _ "${BATS_TEST_DIRNAME}" \
    "${BATS_TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  local seen=${output}
  for name in "${names[@]}"
  do
    run ! grep --quiet "^${name}=" <<<"${seen}"
  done
}

@test "needs skips a test for a tool that is not on PATH, and fails it where kit.yml pins the tool" {
  # the nested file finds its checkout by its own directory, so it sits in a tests/ beside a kit/ that is this one
  mkdir -p "${BATS_TEST_TMPDIR}/nest/tests"
  ln -s "${kit_root}" "${BATS_TEST_TMPDIR}/nest/kit"
  printf '%s\n' 'load "'"${BATS_TEST_DIRNAME}"'/helper"' '@test "t" { needs sh nonesuch-tool; false; }' \
    > "${BATS_TEST_TMPDIR}/nest/tests/needs.bats"
  run timeout 60 env -u BATS_TEST_TMPDIR bats --tap "${BATS_TEST_TMPDIR}/nest/tests/needs.bats"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok 1 t # skip nonesuch-tool is not on PATH"* ]]
  run timeout 60 env -u BATS_TEST_TMPDIR KIT_TESTS_REQUIRE='sh nonesuch-tool' bats --tap \
    "${BATS_TEST_TMPDIR}/nest/tests/needs.bats"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nonesuch-tool is pinned by kit.yml and is not on PATH, so the toolchain is broken"* ]]
}

@test "a forge tool no test faked fails, naming itself, and a fake put first on PATH answers" {
  local tool
  for tool in gh glab az
  do
    run "${tool}" --version
    [ "$status" -eq 97 ]
    [[ "$output" == *"a test reached the real ${tool}"* ]]
  done
  # the teardown fails a test that reached one, though the test passed over its failure
  run helper:outside-checkout
  [ "$status" -eq 1 ]
  [[ "$output" == *"the test called a forge tool no test faked"* && "$output" == *"az --version"* ]]
  : > "${BATS_TEST_TMPDIR}/unfaked.calls"
  fake-tools gh
  route gh 'api user*' '!0'
  run gh api user
  [ "$status" -eq 0 ]
}
