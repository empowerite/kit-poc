#!/usr/bin/env bats
# model.bats - model:load: the model's files from the release and the repository, read into one JSON document
# ----------------------------------------------------------------------------------------------------------------------
# The cases are directories under tests/fixtures/model/: each has a release/ of <domain>/<entity>.yml files, and some a
# repo/ beside it, as a repository's .kit/model/ would be.

bats_require_minimum_version 1.5.0

load helper

setup() {
  kit_bash_modules=model
  fixtures=${BATS_TEST_DIRNAME}/fixtures/model
}

@test "model:load reads the release's files in path order" {
  run --separate-stderr kit-bash "model:load '${fixtures}/ok/release' '${fixtures}/none'"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '[.files[] | "\(.domain) \(.origin) \(.path)"] | join(",")' <<<"$output")" \
    = 'code release modules/model/code/commit.yml,code release modules/model/code/domain.yml,git release modules/model/git/branch.yml' ]
  [ "$(jq --raw-output '.files[0].doc.entity' <<<"$output")" = Commit ]
}

@test "a repository's .kit/model files follow the release's" {
  run --separate-stderr kit-bash "model:load '${fixtures}/ok/release' '${fixtures}/ok/repo'"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.files[-1] | "\(.domain) \(.origin) \(.path) \(.doc.entity)"' <<<"$output")" \
    = 'code repository .kit/model/code/extra.yml Extra' ]
  [ "$(jq '.files | length' <<<"$output")" -eq 4 ]
}

@test "a missing directory is an empty set" {
  run --separate-stderr kit-bash "model:load '${fixtures}/none' '${fixtures}/none'"
  [ "$status" -eq 0 ]
  [ "$output" = '{"files":[]}' ]
}

@test "without arguments, the release is the kit's own and the repository's is .kit/model of the repository" {
  fresh-repo
  mkdir -p .kit/model/code
  printf 'entity: Mine\n' > .kit/model/code/mine.yml
  run --separate-stderr kit-bash 'model:load'
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.files[] | select(.origin == "repository") | .path' <<<"$output")" = .kit/model/code/mine.yml ]
}

@test "a file with an anchor is refused with its path" {
  run kit-bash "model:load '${fixtures}/anchor/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"anchor"* ]]
}

@test "a file with an alias is refused with its path" {
  run kit-bash "model:load '${fixtures}/alias/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"alias"* ]]
}

@test "a file with a merge key is refused with its path" {
  run kit-bash "model:load '${fixtures}/merge/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"merge key"* ]]
}

@test "a file with two documents is refused with its path" {
  run kit-bash "model:load '${fixtures}/two/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"two documents"* ]]
}

@test "a file YAML cannot parse is refused with its name" {
  run kit-bash "model:load '${fixtures}/broken/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken.yml"* ]]
}

@test "a file with an anchor on a key is refused with its path" {
  run kit-bash "model:load '${fixtures}/keyanchor/release' '${fixtures}/none'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"anchor"* ]]
}

@test "a quoted \"<<\" key is an ordinary key and loads" {
  run --separate-stderr kit-bash "model:load '${fixtures}/quoted/release' '${fixtures}/none'"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.files[0].doc["<<"]' <<<"$output")" = 2 ]
}

# kit model check: the verb over the same files. A test runs it in a repository of its own, whose .kit/model is the
# repository's, and without --release the release's is the kit's own.

@test "kit model check passes the release's model" {
  fresh-repo
  run kit model check
  [ "$status" -eq 0 ]
  [[ "${lines[-1]}" =~ ^model:\ [0-9]+\ entities,\ [0-9]+\ stubs$ ]]
}

@test "kit model check names a finding and exits 1" {
  fresh-repo
  mkdir -p .kit/model/code
  printf 'entity: Bad\nlayer: logical\nmeans: an entity\nrelations:\n  other: {to: Bad, arity: many}\n' > .kit/model/code/bad.yml
  run kit model check
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == *"Bad.other"* ]]
  [ "${lines[-1]}" = 'model: 1 entities, 0 stubs' ]
}

@test "kit model check counts stubs" {
  fresh-repo
  mkdir -p .kit/model/code
  printf 'entity: Ghost\nstub: true\nmeans: named so others can refer to it\n' > .kit/model/code/ghost.yml
  run kit model check
  [ "$status" -eq 0 ]
  [ "$output" = 'model: 1 entities, 1 stubs' ]
}

@test "kit model --release= reads another directory in place of the release's" {
  fresh-repo
  run kit model "--release=${fixtures}/ok/release" check
  [[ "${lines[-1]}" == 'model: '*' entities, '*' stubs' ]]
  [[ "${lines[-1]}" != 'model: 0 entities'* ]]
}

@test "kit model check with a malformed file exits 1 and prints what model:load printed" {
  fresh-repo
  run kit model "--release=${fixtures}/anchor/release" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"anchor"* ]]
}

@test "an unknown subcommand, or none, exits 2 and says to run kit help model" {
  fresh-repo
  run kit model nope
  [ "$status" -eq 2 ]
  [[ "$output" == *'kit help model'* ]]
  run kit model
  [ "$status" -eq 2 ]
  [[ "$output" == *'kit help model'* ]]
}
