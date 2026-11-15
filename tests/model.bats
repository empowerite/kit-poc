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
  [ "${lines[0]}" = "Bad.other has neither an inverse nor a derived; it has one" ]
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
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "model: 2 entities, 0 stubs" ]
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

@test "--release= with no value exits 2 and says it needs one" {
  fresh-repo
  run kit model --release= check
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --release needs a value; run: "*"kit help model" ]]
}

@test "a --release directory that is not there exits 2 and names it" {
  fresh-repo
  run kit model "--release=${BATS_TEST_TMPDIR}/nowhere" check
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --release=${BATS_TEST_TMPDIR}/nowhere is not a directory; run: "*"kit help model" ]]
}

@test "--release= given twice exits 2 and says so" {
  fresh-repo
  run kit model "--release=${fixtures}/ok/release" "--release=${fixtures}/two/release" check
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --release is given twice; run: "*"kit help model" ]]
}

# The model's checks guard every shape a file can take, so no fixture makes jq abort. A jq that fails on the model's
# program, and is the real one otherwise, stands in for a jq that cannot load the module or hits a runtime error.
@test "a jq that fails ends kit model check with 1, jq's message, and no count" {
  fresh-repo
  real=$(command -v jq)
  mkdir "${BATS_TEST_TMPDIR}/fake"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do [[ "$a" != *model::check* ]] || { echo "jq: error: boom" >&2; exit 5; }; done\nexec %q "$@"\n' \
    "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" run kit model check
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = 'jq: error: boom' ]
  [[ "$output" != *'model: 0 entities'* ]]
}

# kit model table: a fields table of an entity and a relations table of a domain.

@test "kit model table --entity= prints the entity's fields as a table" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" table --entity=Worktree
  [ "$status" -eq 0 ]
  [ "$output" = '| Field | Type | Arity | Source | Status | Read by | Means |
| --- | --- | --- | --- | --- | --- | --- |
| branch | Text | 0..1 | stored | planned |  | the branch \| or none |
| name | Text | 1 | derived | unused |  | derived from the path. |
| path | Path | 1 | stored | held | work path | where it is checked out |' ]
}

@test "kit model table --domain= prints the domain's relations as a table" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" table --domain=git
  [ "$status" -eq 0 ]
  [ "$output" = '| Relation | To | Arity | Ordered | Inverse | Means |
| --- | --- | --- | --- | --- | --- |
| Branch.worktree | Worktree | 1 |  | Worktree.head |  |
| Worktree.head | Branch | 1 |  | Branch.worktree |  |' ]
}

@test "kit model table with neither --entity= nor --domain=, or both, exits 2 and says so" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" table
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ kit model table needs --entity or --domain; run: "* ]]
  run kit model "--release=${fixtures}/tables/release" table --entity=Worktree --domain=git
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --entity cannot be combined with --domain; run: "* ]]
}

@test "kit model table names the known entities, or domains, for one it does not know" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" table --entity=Nope
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ no entity named Nope; the entities are: Branch, Worktree; run: "* ]]
  run kit model "--release=${fixtures}/tables/release" table --domain=nope
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ no domain named nope; the domains are: git; run: "* ]]
}

@test "a kit:generate region of kit model table is current after kit generate, and stale after the model changes" {
  fresh-repo
  cp -R "${fixtures}/tables/release" model
  printf '<!-- kit:generate fields `kit model --release=model table --entity=Worktree` -->\nold\n<!-- kit:end fields -->\n' > page.md
  run "${kit_checkout}/bin/kit" generate page.md
  [ "$status" -eq 0 ]
  grep --quiet '^| path | Path | 1 | stored | held | work path |' page.md
  run "${kit_checkout}/bin/kit" generate --check page.md
  [ "$status" -eq 0 ]
  sed -i.bak 's/where it is checked out/where it lives/' model/git/worktree.yml
  run "${kit_checkout}/bin/kit" generate --check page.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"page.md: stale"* ]]
  run "${kit_checkout}/bin/kit" generate page.md
  [ "$status" -eq 0 ]
  grep --quiet 'where it lives' page.md
}

@test "a jq that fails ends kit model table with 1 and jq's message" {
  fresh-repo
  real=$(command -v jq)
  mkdir "${BATS_TEST_TMPDIR}/fake"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do [[ "$a" != *model::fields* ]] || { echo "jq: error: boom" >&2; exit 5; }; done\nexec %q "$@"\n' \
    "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" run kit model "--release=${fixtures}/tables/release" table --entity=Worktree
  [ "$status" -eq 1 ]
  [ "$output" = 'jq: error: boom' ]
}

# kit model svg: a diagram of a domain, and an overview of every domain.

@test "kit model svg --domain= prints the domain's diagram, which yq reads as XML" {
  fresh-repo
  run --separate-stderr kit model "--release=${fixtures}/svg/release" svg --domain=org
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == '<svg xmlns="http://www.w3.org/2000/svg" '* ]]
  [ "${lines[-1]}" = '</svg>' ]
  printf '%s\n' "$output" > out.svg
  yq -p=xml . < out.svg > /dev/null
  [[ "$output" == *'>Ghost</text>'* && "$output" == *'>Person</text>'* && "$output" == *'>Team</text>'* ]]
  [[ "$output" == *'>members  1..*</text>'* && "$output" == *'>children  0..* {ordered}</text>'* ]]
  [[ "$output" == *'<tspan class="far">User</tspan>'* && "$output" != *'>User</text>'* ]]
}

@test "kit model svg prints the same bytes on a second run and under another locale" {
  fresh-repo
  LC_ALL=C kit model "--release=${fixtures}/svg/release" svg --domain=org > c.svg
  LC_ALL=en_US.UTF-8 kit model "--release=${fixtures}/svg/release" svg --domain=org > utf8.svg
  LC_ALL=C kit model "--release=${fixtures}/svg/release" svg --domain=org > again.svg
  LC_ALL=C kit model "--release=${fixtures}/svg/release" svg --overview > overview-c.svg
  LC_ALL=en_US.UTF-8 kit model "--release=${fixtures}/svg/release" svg --overview > overview-utf8.svg
  [ -s c.svg ]
  cmp c.svg utf8.svg
  cmp c.svg again.svg
  cmp overview-c.svg overview-utf8.svg
}

@test "kit model svg --overview prints a panel for each domain, which yq reads as XML" {
  fresh-repo
  run --separate-stderr kit model "--release=${fixtures}/svg/release" svg --overview
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > out.svg
  yq -p=xml . < out.svg > /dev/null
  [[ "$output" == *'>Org</text>'* && "$output" == *'>other</text>'* && "$output" == *'>User</text>'* ]]
}

@test "kit model svg escapes a means and a name with <, &, and quotes, so the diagram stays well-formed" {
  fresh-repo
  mkdir -p .kit/model/mine
  printf 'entity: Odd\nlayer: logical\nmeans: '"'"'a <b> & "c"'"'"'\nrelations:\n  "x<y": {to: Odd, derived: '"'"'a & b'"'"'}\n' > .kit/model/mine/odd.yml
  mkdir empty
  run --separate-stderr kit model --release=empty svg --domain=mine
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > out.svg
  yq -p=xml . < out.svg > /dev/null
  [[ "$output" == *'>a &lt;b&gt; &amp; &quot;c&quot;</text>'* ]]
  [[ "$output" == *'>x&lt;y  1  derived</text>'* ]]
}

@test "kit model svg with neither --domain= nor --overview, or both, exits 2 and says so" {
  fresh-repo
  run kit model "--release=${fixtures}/svg/release" svg
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ kit model svg needs --domain or --overview; run: "* ]]
  run kit model "--release=${fixtures}/svg/release" svg --domain=org --overview
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --domain cannot be combined with --overview; run: "* ]]
}

@test "kit model svg names the known domains for one it does not know" {
  fresh-repo
  run kit model "--release=${fixtures}/svg/release" svg --domain=nope
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ no domain named nope; the domains are: org, other; run: "* ]]
}

@test "kit model svg with a malformed file exits 1 and prints what model:load printed" {
  fresh-repo
  run kit model "--release=${fixtures}/anchor/release" svg --overview
  [ "$status" -eq 1 ]
  [[ "$output" == *"modules/model/code/bad.yml"*"anchor"* ]]
}

@test "a jq that fails ends kit model svg with 1 and jq's message" {
  fresh-repo
  real=$(command -v jq)
  mkdir "${BATS_TEST_TMPDIR}/fake"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do [[ "$a" != *modelsvg::domain* ]] || { echo "jq: error: boom" >&2; exit 5; }; done\nexec %q "$@"\n' \
    "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" run kit model "--release=${fixtures}/svg/release" svg --domain=org
  [ "$status" -eq 1 ]
  [ "$output" = 'jq: error: boom' ]
}
