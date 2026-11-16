#!/usr/bin/env bats
# model.bats - model:load: the model's files from the release and the repository, read into one JSON document
# ----------------------------------------------------------------------------------------------------------------------
# The cases are directories under tests/fixtures/model/: each has a release/ of <domain>/<entity>.yml files, and some a
# repo/ beside it, as a repository's .kit/model/ would be.

bats_require_minimum_version 1.5.0

load helper

setup_file() {
  world-repo installed
}

setup() {
  kit_bash_modules=model
  fixtures=${BATS_TEST_DIRNAME}/fixtures/model
}

# release-counts sets release_entities and release_stubs: the entities the release's model files define, and the stubs
# among them, counted from the files, so a test that adds a repository's entity knows the total kit model check gives.
release-counts() {
  local -a files
  files=("${kit_root}"/modules/model/*/*.yml)
  release_entities=$(grep --files-with-matches --no-messages '^entity: ' "${files[@]}" | wc -l | tr -d ' ')
  release_stubs=$(grep --files-with-matches --no-messages '^stub: true$' "${files[@]}" | wc -l | tr -d ' ')
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
  [ "$output" = '{"files":[],"strays":[]}' ]
}

@test "outside a repository, model:load reads the release alone" {
  mkdir "${BATS_TEST_TMPDIR}/nowhere"
  cd "${BATS_TEST_TMPDIR}/nowhere"
  run --separate-stderr kit-bash "model:load '${fixtures}/ok/release'"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '[.files[].origin] | unique | join(",")' <<<"$output")" = release ]
}

@test "model:load names every file it does not read, a hidden one aside, and the release's schemas are no strays" {
  mkdir -p release/code repo/code/deep repo/.hidden
  printf 'entity: A\nlayer: logical\n' > release/code/a.yml
  printf '{}\n' > release/model.schema.json
  printf 'x\n' > release/notes.txt
  printf 'entity: B\nlayer: logical\n' > repo/code/b.yml
  printf 'entity: C\n' | tee repo/x.yaml repo/top.yml repo/code/c.yaml repo/code/deep/e.yml repo/code/.swap.yml \
    repo/.hidden/h.yml repo/model.schema.json > /dev/null
  run --separate-stderr kit-bash "model:load release repo"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.strays | join(",")' <<<"$output")" \
    = 'modules/model/notes.txt,.kit/model/code/c.yaml,.kit/model/code/deep/e.yml,.kit/model/model.schema.json,.kit/model/top.yml,.kit/model/x.yaml' ]
  [ "$(jq --raw-output '[.files[].path] | join(",")' <<<"$output")" = 'modules/model/code/a.yml,.kit/model/code/b.yml' ]
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
  release-counts
  [ "${lines[-1]}" = "model: $((release_entities + 1)) entities, ${release_stubs} stubs" ]
}

@test "kit model check counts stubs" {
  fresh-repo
  mkdir -p .kit/model/code
  printf 'entity: Ghost\nstub: true\nmeans: named so others can refer to it\n' > .kit/model/code/ghost.yml
  run kit model check
  [ "$status" -eq 0 ]
  release-counts
  [ "$output" = "model: $((release_entities + 1)) entities, $((release_stubs + 1)) stubs" ]
}

@test "kit model check names each file of the repository it does not read, and exits 1" {
  fresh-repo
  mkdir -p empty .kit/model/code/deep
  printf 'entity: A\nlayer: logical\n' > .kit/model/code/a.yml
  printf 'entity: B\nlayer: logical\n' | tee .kit/model/x.yaml .kit/model/top.yml .kit/model/code/deep/e.yml > /dev/null
  run kit model --release=empty check
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = '.kit/model/code/deep/e.yml is not read: a model file is <domain>/<entity>.yml or <domain>/domain.yml, one directory down' ]
  [ "${lines[1]}" = '.kit/model/top.yml is not read: a model file is <domain>/<entity>.yml or <domain>/domain.yml, one directory down' ]
  [ "${lines[2]}" = '.kit/model/x.yaml is not read: a model file is <domain>/<entity>.yml or <domain>/domain.yml, one directory down' ]
  [ "${lines[-1]}" = "model: 1 entities, 0 stubs" ]
}

@test "kit model check holds a repository's file to the schema's keys, names, and read-by, naming the file" {
  fresh-repo
  mkdir -p empty .kit/model/code
  cat > .kit/model/code/odd.yml <<'YAML'
entity: lower_case name
layer: logical
meens: a misspelt key
colour: red
fields:
  Bad Name: {type: Text, status: planned}
  count: {type: Int, arrity: many, statuss: held, status: planned}
  kind: {type: Text, sorce: derived, status: planned}
  owner: {type: Text, status: held, read-by: "NOT a verb!!"}
relations:
  peers: {to: lower_case name, arity: many, orderd: true, derived: the others}
YAML
  run kit model --release=empty check
  [ "$status" -eq 1 ]
  local expected
  for expected in \
    '.kit/model/code/odd.yml sets meens, which is not a key of a model file; ' \
    '.kit/model/code/odd.yml sets colour, which is not a key of a model file; ' \
    '.kit/model/code/odd.yml names the entity lower_case name, which does not match ^[A-Z][A-Za-z0-9]*$' \
    '.kit/model/code/odd.yml gives lower_case name the field Bad Name, whose name does not match ^[a-z][a-z0-9-]*$' \
    '.kit/model/code/odd.yml sets arrity on the field lower_case name.count, which is not a key of a field; ' \
    '.kit/model/code/odd.yml sets statuss on the field lower_case name.count, which is not a key of a field; ' \
    '.kit/model/code/odd.yml sets sorce on the field lower_case name.kind, which is not a key of a field; ' \
    '.kit/model/code/odd.yml sets orderd on the relation lower_case name.peers, which is not a key of a relation; ' \
    'lower_case name.owner has read-by NOT a verb!!, which is not "<verb> <key>"'
  do
    [[ "$output" == *"${expected}"* ]] || { echo "missing: ${expected}"; return 1; }
  done
}

@test "a repository's domain.yml adds layout hints, and setting the release's name is a finding" {
  fresh-repo
  mkdir -p .kit/model/code
  printf 'name: Hijacked\nintro: Mine.\nlayout:\n  Ticket: {row: 0, col: 4}\n' > .kit/model/code/domain.yml
  run kit model check
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = '.kit/model/code/domain.yml sets name on the domain code, which modules/model/code/domain.yml sets; a later domain.yml adds only layout hints' ]
  printf 'layout:\n  Ticket: {row: 0, col: 4}\n' > .kit/model/code/domain.yml
  run kit model check
  [ "$status" -eq 0 ]
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

@test "a --release that names a file exits 2 and names it" {
  fresh-repo
  : > plain
  run kit model --release=plain check
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ --release=plain is not a directory; run: "*"kit help model" ]]
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
| path | Path | 1 | stored | held | `work path` | where it is checked out |' ]
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
  grep --quiet '^| path | Path | 1 | stored | held | `work path` |' page.md
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

# kit model page: the body of a domain's page.

@test "kit model page --domain= prints the page of the domain" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" page --domain=git
  [ "$status" -eq 0 ]
  [ "$output" = '![git: the entities of the domain and how they relate](git.svg)

## Relations

| Relation | To | Arity | Ordered | Inverse | Means |
| --- | --- | --- | --- | --- | --- |
| Branch.worktree | Worktree | 1 |  | Worktree.head |  |
| Worktree.head | Branch | 1 |  | Branch.worktree |  |

## Entities

### Branch

Layer: native (git)

| Field | Type | Arity | Source | Status | Read by | Means |
| --- | --- | --- | --- | --- | --- | --- |

### Worktree

a working tree

Layer: native (git)

| Field | Type | Arity | Source | Status | Read by | Means |
| --- | --- | --- | --- | --- | --- | --- |
| branch | Text | 0..1 | stored | planned |  | the branch \| or none |
| name | Text | 1 | derived | unused |  | derived from the path. |
| path | Path | 1 | stored | held | `work path` | where it is checked out |' ]
}

@test "kit model page with no --domain=, or a domain the model does not hold, exits 2 and says so" {
  fresh-repo
  run kit model "--release=${fixtures}/tables/release" page
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ kit model page needs --domain; the domains are: git; run: "*"kit help model" ]]
  run kit model "--release=${fixtures}/tables/release" page --domain=nope
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ no domain named nope; the domains are: git; run: "*"kit help model" ]]
  run kit model "--release=${fixtures}/none-here" page
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "❌ kit model page needs --domain; run: "*"kit help model" ]]
}

@test "a kit:generate region of kit model page is current after kit generate, and stale after the model changes" {
  fresh-repo
  cp -R "${fixtures}/tables/release" model
  printf '# Git\n\n<!-- kit:generate page `kit model --release=model page --domain=git` -->\nold\n<!-- kit:end page -->\n' > page.md
  run "${kit_checkout}/bin/kit" generate page.md
  [ "$status" -eq 0 ]
  grep --quiet '^### Worktree$' page.md
  run "${kit_checkout}/bin/kit" generate --check page.md
  [ "$status" -eq 0 ]
  sed -i.bak 's/a working tree/a tree/' model/git/worktree.yml
  run "${kit_checkout}/bin/kit" generate --check page.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"page.md: stale"* ]]
}

@test "kit model --help leaves no temporary directory behind" {
  fresh-repo
  mkdir "${BATS_TEST_TMPDIR}/private"
  TMPDIR="${BATS_TEST_TMPDIR}/private" run kit model --help
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "${BATS_TEST_TMPDIR}/private")" ]
}

@test "a jq that fails ends kit model page with 1 and jq's message" {
  fresh-repo
  real=$(command -v jq)
  mkdir "${BATS_TEST_TMPDIR}/fake"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do [[ "$a" != *model::page* ]] || { echo "jq: error: boom" >&2; exit 5; }; done\nexec %q "$@"\n' \
    "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" run kit model "--release=${fixtures}/tables/release" page --domain=git
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
  printf '#!/usr/bin/env bash\nfor a in "$@"; do [[ "$a" != *modelsvg::render* ]] || { echo "jq: error: boom" >&2; exit 5; }; done\nexec %q "$@"\n' \
    "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" run kit model "--release=${fixtures}/svg/release" svg --domain=org
  [ "$status" -eq 1 ]
  [ "$output" = 'jq: error: boom' ]
}

# The golden diagram of the lab domain: eleven entities with no hints, so the layout and the router place everything. A
# change to either shows as a diff of tests/fixtures/model/lab/lab.svg. To write it afresh, from the repository root, through
# a scratch file so a failed run leaves the golden as it was:
#   kit/bin/kit model --release=tests/fixtures/model/lab/release svg --domain=lab > "${TMPDIR:-/tmp}/lab.svg" \
#     && mv "${TMPDIR:-/tmp}/lab.svg" tests/fixtures/model/lab/lab.svg
@test "kit model svg --domain=lab prints the golden diagram, byte for byte" {
  fresh-repo
  kit model "--release=${fixtures}/lab/release" svg --domain=lab > lab.svg
  cmp lab.svg "${fixtures}/lab/lab.svg"
}

@test "a warning jq writes to stderr stays out of kit model svg's diagram" {
  fresh-repo
  real=$(command -v jq)
  mkdir "${BATS_TEST_TMPDIR}/fake"
  printf '#!/usr/bin/env bash\necho "jq: warning: noise" >&2\nexec %q "$@"\n' "${real}" > "${BATS_TEST_TMPDIR}/fake/jq"
  chmod +x "${BATS_TEST_TMPDIR}/fake/jq"
  PATH="${BATS_TEST_TMPDIR}/fake:${PATH}" kit model "--release=${fixtures}/lab/release" svg --domain=lab > lab.svg
  cmp lab.svg "${fixtures}/lab/lab.svg"
}

@test "kit model svg names on stderr an entity whose labels it cannot keep clear, keeps them out of the SVG, and exits 0" {
  fresh-repo
  mkdir -p empty .kit/model/crowd
  {
    printf 'entity: A\nlayer: logical\nmeans: thirty relations to B\nrelations:\n'
    for i in $(seq 1 30)
    do
      printf '  toward%s: {to: B, derived: x}\n' "${i}"
    done
  } > .kit/model/crowd/a.yml
  printf 'entity: B\nlayer: logical\nmeans: the end of thirty lines\n' > .kit/model/crowd/b.yml
  run --separate-stderr kit model --release=empty svg --domain=crowd
  [ "$status" -eq 0 ]
  [[ "${stderr}" == *"the labels of B could not all be kept clear"* ]]
  [ "$(grep -c . <<<"${stderr}")" -eq 1 ]
  [[ "${lines[0]}" == '<svg xmlns='* ]]
  [[ "$output" != *"could not"* ]]
  printf '%s\n' "$output" > out.svg
  yq -p=xml . < out.svg > /dev/null
  [ "$(grep -c '<path class="edge' out.svg)" -eq 30 ]
}

# The atk domain's labels have no clear place. tests/jq/modelsvg.test holds that every one of its label boxes still lies
# inside the canvas; this test holds the verb's side: a warning on stderr, a well-formed SVG, and status 0.
@test "kit model svg warns for the atk domain, whose labels no place keeps clear, and exits 0" {
  fresh-repo
  run --separate-stderr kit model "--release=${fixtures}/atk/release" svg --domain=atk
  [ "$status" -eq 0 ]
  [[ "${stderr}" == *"could not all be kept clear"* ]]
  [[ "$output" != *"could not"* ]]
  printf '%s\n' "$output" > atk.svg
  yq -p=xml . < atk.svg > /dev/null
}

# Every fixture of the model is a model that holds, so a test never leans on a broken model by accident, a new one
# included. The fixtures left out are each broken on purpose, and each still exists.
@test "every model fixture passes kit model check, but those broken on purpose" {
  fresh-repo
  local -A broken=(
    [lab]="holds an inverse that names nothing back, Tag.commit, to draw a one-sided arrow"
    [alias]="model:load refuses its alias" [anchor]="model:load refuses its anchor" [broken]="YAML cannot parse it"
    [keyanchor]="model:load refuses the anchor on its key" [merge]="model:load refuses its merge key"
    [two]="model:load refuses its second document" [quoted]="its quoted << key is no key of a model file"
  )
  local fixture name
  for name in "${!broken[@]}"
  do
    [ -d "${fixtures}/${name}/release" ] || { echo "no fixture ${name}, which the list names as broken"; return 1; }
  done
  for fixture in "${fixtures}"/*/release
  do
    name=$(basename "$(dirname "${fixture}")")
    [[ -z "${broken[${name}]:-}" ]] || continue
    run kit model "--release=${fixture}" check
    [ "$status" -eq 0 ] || { echo "${name}: ${output}"; return 1; }
  done
}

# The schema and kit model check hold one set of rules: the check reads its keys, names, and patterns from the schema,
# and these cases hold the rest equal. Each file breaks one rule, or none, and ajv and the check give it the same
# verdict.
@test "ajv with the schema and kit model check give each case the same verdict" {
  PATH="${BATS_TEST_DIRNAME}/../node_modules/.bin:${PATH}"
  needs ajv
  fresh-repo
  mkdir empty
  local base='entity: X
layer: logical
means: an x
fields:
  name: {type: Text, status: held, read-by: workspace repos name}
relations:
  peers: {to: X, arity: many, inverse: X.peers}'
  local -A cases=(
    [good]="${base}"
    [good-sum]=$'entity: X\nlayer: logical\nsum: true\nvariants:\n  One: {x: X}'
    [good-stub]=$'entity: X\nstub: true\nmeans: named only'
    [good-ordered]="${base}"$'\n  list: {to: X, arity: some, ordered: true, derived: the others}'
    [bad-file-key]="${base}"$'\ncolour: red'
    [bad-field-key]="${base/status: held,/status: held, sorce: derived,}"
    [bad-relation-key]="${base/arity: many,/arity: many, orderd: true,}"
    [bad-entity-name]="${base/entity: X/entity: lower_case}"
    [bad-field-name]="${base/  name:/  Bad_Name:}"
    [bad-relation-name]="${base}"$'\n  toMe: {to: X, derived: x}'
    [bad-variant-name]=$'entity: X\nlayer: logical\nsum: true\nvariants:\n  odd: {x: X}'
    [bad-variant-field]=$'entity: X\nlayer: logical\nsum: true\nvariants:\n  One: {Bad: X}'
    [bad-read-by]="${base/read-by: workspace repos name/read-by: \"NOT a verb!!\"}"
    [bad-read-by-star]="${base/read-by: workspace repos name/read-by: workspace repos checkouts.*}"
    [bad-read-by-option]="${base/read-by: workspace repos name/read-by: workspaces --show}"
    [bad-no-status]="${base/status: held, read-by: workspace repos name/}"
    [bad-status]="${base/status: held/status: done}"
    [bad-source]="${base/status: held,/status: held, source: cached,}"
    [bad-arity]="${base/arity: many/arity: several}"
    [bad-native-no-tool]="${base/layer: logical/layer: native}"
    [bad-native-over]="${base/layer: logical/layer: native}"$'\ntool: git\nover: [X]'
    [bad-logical-tool]="${base}"$'\ntool: git'
    [bad-no-layer]="${base/layer: logical/}"
    [bad-stub-fields]="${base}"$'\nstub: true'
    [bad-variants-no-sum]="${base}"$'\nvariants:\n  One: {x: X}'
    [bad-sum-no-variants]="${base}"$'\nsum: true'
    [bad-field-ordered]="${base/status: held,/status: held, ordered: true,}"
    [bad-relation-ordered]="${base}"$'\n  best: {to: X, arity: option, ordered: true, derived: x}'
    [bad-relation-neither]="${base}"$'\n  lone: {to: X}'
    [bad-relation-both]="${base}"$'\n  both: {to: X, inverse: X.both, derived: x}'
    [bad-held-no-read-by]="${base/, read-by: workspace repos name/}"
    [bad-derived-no-from]="${base/status: held,/status: held, source: derived,}"
    [bad-means]="${base/means: an x/means: \"\"}"
    [bad-enum-empty]="${base/type: Text/type: {enum: []\}}"
    [bad-enum-twice]="${base/type: Text/type: {enum: [a, a]\}}"
    [bad-over-twice]="${base}"$'\nover: [X, X]'
  )
  local name ajv_says check_says differ=''
  for name in "${!cases[@]}"
  do
    mkdir -p "cases/${name}/.kit/model/x"
    printf '%s\n' "${cases[${name}]}" > "cases/${name}/.kit/model/x/x.yml"
    ajv validate --spec=draft2020 -s "${kit_root}/modules/model/model.schema.json" -d "cases/${name}/.kit/model/x/x.yml" \
      >/dev/null 2>&1 && ajv_says=holds || ajv_says=refuses
    (cd "cases/${name}" && git init --quiet && kit model "--release=${repo}/empty" check) >/dev/null 2>&1 \
      && check_says=holds || check_says=refuses
    [[ "${ajv_says}" == "${check_says}" && "${ajv_says}" == "$([[ "${name}" == good* ]] && echo holds || echo refuses)" ]] \
      || differ+="${name}: ajv ${ajv_says}, kit model check ${check_says}"$'\n'
  done
  [ -z "${differ}" ] || { printf '%s' "${differ}"; return 1; }
}

# kit check runs kit model check where the repository has a .kit/model, and a repository without one is checked as
# before.
@test "kit check names each finding of the repository's model and fails; a repository with no .kit/model is as before" {
  world-copy-repo installed
  run "${kit_checkout}/bin/kit" check
  [ "$status" -eq 0 ]
  local before=$output
  mkdir -p .kit/model/code
  printf 'entity: Bad\nlayer: logical\nmeens: x\n' > .kit/model/code/bad.yml
  run "${kit_checkout}/bin/kit" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"❌ kit model check: .kit/model/code/bad.yml sets meens, which is not a key of a model file; "* ]]
  [[ "$output" == *"❌ 1 finding(s), each named above"* ]]
  printf 'entity: Good\nlayer: logical\nmeans: x\n' > .kit/model/code/bad.yml
  run "${kit_checkout}/bin/kit" check
  [ "$status" -eq 0 ]
  rm -r .kit/model
  run "${kit_checkout}/bin/kit" check
  [ "$output" = "${before}" ]
}

# The schema's read-by pattern, read from the schema and tried with jq's regex, which reads it as ajv does: a verb of
# lowercase words, any after the first may be an option written without its value, then the key, never an option, whose
# last segment is never a bare *.
@test "the schema's read-by takes an option among the verb's words, and refuses a malformed one, one last, or a last *" {
  local pattern good bad
  pattern=$(jq --raw-output '."$defs".field.properties."read-by".pattern' "${kit_root}/modules/model/model.schema.json")
  for good in 'workspace commits key' 'workspaces --show kind' 'workspaces --current recent.*.checkout' \
    'flow changes pushed.age' 'facts tree.*.blob' 'workspaces --current --show kind' 'workspace repos checkouts'
  do
    jq --exit-status --null-input --arg p "${pattern}" --arg r "${good}" '$r | test($p)' >/dev/null \
      || { echo "refused: ${good}"; return 1; }
  done
  for bad in '--show kind' 'workspaces -- kind' 'workspaces --Show kind' 'workspaces -show kind' \
    'workspaces --show' 'workspaces kind --show' 'workspaces --show=team kind' 'kind' 'facts tree.*' \
    'workspace repos checkouts.*' 'facts *'
  do
    ! jq --exit-status --null-input --arg p "${pattern}" --arg r "${bad}" '$r | test($p)' >/dev/null \
      || { echo "taken: ${bad}"; return 1; }
  done
}
