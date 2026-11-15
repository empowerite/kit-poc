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
