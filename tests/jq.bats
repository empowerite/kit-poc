#!/usr/bin/env bats
# jq.bats - every jq module passes its own tests, tests/jq/<module>.test, run by jq --run-tests, on the jq on PATH
#           and on jq 1.7, the oldest the kit accepts
# ----------------------------------------------------------------------------------------------------------------------

load helper

# modules-pass <jq> runs every module's tests with the jq at <jq>, and fails when a module has no test file, or a
# test fails or does not compile.
modules-pass() {
  local jq=$1 module name status=0
  for module in "${kit_root}"/modules/jq/*.jq
  do
    name=$(basename "${module}" .jq)
    if [[ ! -f "${BATS_TEST_DIRNAME}/jq/${name}.test" ]]
    then
      echo "modules/jq/${name}.jq has no tests/jq/${name}.test"
      status=1
      continue
    fi
    # jq --run-tests then runs jq's own library tests, whose lines follow its summary and say nothing of the
    # module, so the report stops at the summary.
    "${jq}" -L "${kit_root}/modules/jq" --run-tests "${BATS_TEST_DIRNAME}/jq/${name}.test" \
      > "${BATS_TEST_TMPDIR}/out" 2>&1 || status=1
    sed '/tests passed/q' "${BATS_TEST_TMPDIR}/out"
  done
  return "${status}"
}

@test "every jq module has a test file, and passes it" {
  modules-pass "$(command -v jq)"
}

# jq 1.8 reads more than jq 1.7 does: a reduce or an if before `as`, an operator in an object's value, and a sum
# before `as`, which jq 1.7 binds by its last term alone. A module written and tested on jq 1.8 alone can fail to
# compile on jq 1.7, or answer differently. macOS and Ubuntu 24.04 ship jq 1.7.1 at /usr/bin/jq; the test runs where
# that is so, and fetches nothing.
@test "every jq module passes its tests on jq 1.7, the oldest kit accepts, where /usr/bin/jq is one" {
  local version
  version=$(/usr/bin/jq --version 2>/dev/null) || version='not there'
  [[ "${version}" == jq-1.7* ]] || skip "/usr/bin/jq is ${version}, not jq 1.7"
  modules-pass /usr/bin/jq
}

# ----------------------------------------------------------------------------------------------------------------------
