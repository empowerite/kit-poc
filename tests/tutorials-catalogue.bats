#!/usr/bin/env bats
# tutorials-catalogue.bats - bin/tutorials: the catalogue from the pages' front matter, and the site's copies published
# ----------------------------------------------------------------------------------------------------------------------
# The catalogue's tests run bin/tutorials catalogue over a fixture project. The site's tests publish to a bare
# repository under the test's directory, with a fake gh first on PATH, and say they are on a runner, the only place
# publish and retire run; an address is asked of a fake curl. No test reaches a forge or the network.

bats_require_minimum_version 1.5.0

load helper

repo_root=$(cd "${BATS_TEST_DIRNAME}/.." && pwd)
site=https://empowerite.github.io/kit/tutorials

# catalogue <fixture> runs bin/tutorials catalogue over a fixture project under tests/fixtures/tutorials/, the pages
# that ship with the kit in its shipped/, which most fixtures lack.
catalogue() {
  local fixture="${repo_root}/tests/fixtures/tutorials/$1"
  TUTORIALS_PROJECT="${fixture}" TUTORIALS_SHIPPED="${fixture}/shipped" \
    run --separate-stderr "${repo_root}/bin/tutorials" catalogue
}

# pages makes the bare repository bin/tutorials publishes to, with no gh-pages branch yet, names it in TUTORIALS_PAGES,
# puts a gh that records what it is asked first on PATH, and says the test is on a runner.
pages() {
  export TUTORIALS_PAGES="${BATS_TEST_TMPDIR}/pages.git" FAKES="${BATS_TEST_TMPDIR}/fakes" GITHUB_ACTIONS=true
  git init --quiet --bare "${TUTORIALS_PAGES}"
  mkdir -p "${FAKES}"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "${FAKES}/gh.calls"' > "${FAKES}/gh"
  chmod +x "${FAKES}/gh"
  export PATH="${FAKES}:${PATH}"
}

# built <text> makes a built site whose index.html and 404.html say <text>, and prints its directory.
built() {
  local dist="${BATS_TEST_TMPDIR}/dist-$1"
  mkdir -p "${dist}/assets"
  printf '%s' "$1" > "${dist}/index.html"
  printf '%s' "$1" > "${dist}/404.html"
  printf '%s' "$1" > "${dist}/assets/site.css"
  printf '%s\n' "${dist}"
}

# online <path> prints a file of the published branch, and listed <arguments>… is git ls-tree there.
online() { git --git-dir="${TUTORIALS_PAGES}" show "gh-pages:$1"; }
listed() { git --git-dir="${TUTORIALS_PAGES}" ls-tree "$@"; }

# answering <code>… puts a curl first on PATH that answers each call in turn with the next HTTP status, and every later
# call with the last; 000 is no answer at all, where curl fails. It records each address asked in ${FAKES}/curl.calls.
answering() {
  export FAKES="${BATS_TEST_TMPDIR}/fakes"
  mkdir -p "${FAKES}"
  rm -f "${FAKES}/curl.calls"
  printf '%s\n' "$@" > "${FAKES}/codes"
  cat > "${FAKES}/curl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}" >> "${FAKES}/curl.calls"
code=$(sed -n "$(wc -l < "${FAKES}/curl.calls" | tr -d ' ')p" "${FAKES}/codes")
[[ -n "${code}" ]] || code=$(tail -n 1 "${FAKES}/codes")
printf '%s' "${code}"
[[ "${code}" != 000 ]] || exit 7
SH
  chmod +x "${FAKES}/curl"
  [[ ":${PATH}:" == *":${FAKES}:"* ]] || export PATH="${FAKES}:${PATH}"
}

@test "the catalogue lists the top-level tutorials in order" {
  catalogue ok
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "${output}" | yq -o json -I 0 '.')" = '{"audiences":[{"id":"newcomer","label":"Just starting","color":"#15803d"},{"id":"ui","label":"UI","color":"#1d4ed8"},{"id":"maintainer","label":"Maintainer","color":"#7c3aed"}],"tutorials":[{"id":"beta","path":"beta/","title":"Beta","summary":"The first one.","glyph":"🅱","audience":["maintainer"],"order":10},{"id":"alpha","path":"alpha/","title":"Alpha","summary":"The second one.","glyph":"🅰","audience":["newcomer","ui"],"order":20}]}' ]
  [[ "${output}" != *Deeper* ]]
}

@test "a page that ships with the kit is listed by its file, in order among the others" {
  catalogue shipped
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "${output}" | yq -o json -I 0 '.tutorials')" = '[{"id":"screens","file":"tutorials/screens.md","title":"The screens","summary":"What each screen shows.","glyph":"🧭","audience":["newcomer","ui"],"order":5},{"id":"beta","path":"beta/","title":"Beta","summary":"The first one.","glyph":"🅱","audience":["maintainer"],"order":10}]' ]
}

@test "a page that ships with the kit needs a glyph" {
  catalogue no-shipped-glyph
  [ "$status" -eq 1 ]
  [[ "${stderr}" == *"shipped/screens.md: a tutorial needs a glyph"* ]]
}

@test "an unknown audience is refused, naming the file" {
  catalogue unknown-audience
  [ "$status" -eq 1 ]
  [[ "${stderr}" == *"gamma/index.mdx"* ]]
  [[ "${stderr}" == *"wizard"* ]]
}

@test "an audience needs a color" {
  catalogue no-color
  [ "$status" -eq 1 ]
  [ "$output" = "" ]
  local file="${repo_root}/tests/fixtures/tutorials/no-color/audiences.yml"
  [ "${stderr}" = "❌ ${file}: the audience 'ui' needs a color, as #rrggbb" ]
}

@test "a color is #rrggbb" {
  catalogue bad-color
  [ "$status" -eq 1 ]
  local file="${repo_root}/tests/fixtures/tutorials/bad-color/audiences.yml"
  [ "${stderr}" = "❌ ${file}: the audience 'ui' has the color '#1d4ed', not #rrggbb" ]
  # each color is set as a YAML value, in a copy of the ok project
  local color
  for color in '"blue"' '"#1d4ed8f"' '"1d4ed8"' '"#gggggg"' '"#1d4ed8 "' 12 '[]' '"#1D4ED8"'
  do
    rm -rf "${BATS_TEST_TMPDIR}/project"
    cp -R "${repo_root}/tests/fixtures/tutorials/ok" "${BATS_TEST_TMPDIR}/project"
    yq -i ".[1].color = ${color}" "${BATS_TEST_TMPDIR}/project/audiences.yml"
    TUTORIALS_PROJECT="${BATS_TEST_TMPDIR}/project" run --separate-stderr "${repo_root}/bin/tutorials" catalogue
    if [[ "${color}" == '"#1D4ED8"' ]]
    then
      [ "$status" -eq 0 ]
    else
      [ "$status" -eq 1 ]
      [[ "${stderr}" == *"/project/audiences.yml: the audience 'ui' has the color "*", not #rrggbb" ]]
    fi
  done
}

@test "a top-level page needs a summary" {
  catalogue no-summary
  [ "$status" -eq 1 ]
  [[ "${stderr}" == *"gamma/index.mdx"* ]]
  [[ "${stderr}" == *"summary"* ]]
}

@test "a top-level page needs a glyph" {
  catalogue no-glyph
  [ "$status" -eq 1 ]
  [[ "${stderr}" == *"gamma/index.mdx"* ]]
  [[ "${stderr}" == *"glyph"* ]]
}

@test "a top-level page lives at <id>/index.mdx" {
  catalogue misplaced
  [ "$status" -eq 1 ]
  [[ "${stderr}" == *"a/b.mdx"* ]]
}

@test "the catalogue in kit is current" {
  # A test ends outside the checkout, so the kit runs in a subshell that goes there.
  run bash -c 'cd "$1" && "$2/bin/kit" generate --check kit/modules/tutorials.yml' _ "${repo_root}" "${kit_checkout}"
  [ "$status" -eq 0 ]
}

@test "where kit's source is not, the catalogue's region reprints as it stands, so generate --check holds" {
  fresh-repo >/dev/null
  cp -R "${kit_checkout}" kit
  [ ! -e bin/tutorials ]
  cp kit/modules/tutorials.yml "${BATS_TEST_TMPDIR}/before"
  run "${kit_root}/bin/kit" generate --check kit/modules/tutorials.yml
  [ "$status" -eq 0 ]
  cmp kit/modules/tutorials.yml "${BATS_TEST_TMPDIR}/before"
  run "${kit_root}/bin/kit" generate kit/modules/tutorials.yml
  [ "$status" -eq 0 ]
  cmp kit/modules/tutorials.yml "${BATS_TEST_TMPDIR}/before"
}

@test "a repository's own bin/tutorials is never run by the region, but kit's source fails loudly without its execute bit" {
  fresh-repo >/dev/null
  cp -R "${kit_checkout}" kit
  mkdir bin
  printf '#!/bin/sh\ntouch ran\n' > bin/tutorials
  chmod +x bin/tutorials
  cp kit/modules/tutorials.yml "${BATS_TEST_TMPDIR}/before"
  run "${kit_root}/bin/kit" generate kit/modules/tutorials.yml
  [ "$status" -eq 0 ]
  [ ! -e ran ]
  cmp kit/modules/tutorials.yml "${BATS_TEST_TMPDIR}/before"
  # with a projects/tutorials, as in kit's source, the command runs bin/tutorials, and a lost execute bit fails
  mkdir -p projects/tutorials
  chmod -x bin/tutorials
  run "${kit_root}/bin/kit" generate kit/modules/tutorials.yml
  [ "$status" -ne 0 ]
}

@test "site says which copy a ref builds, and a pre-release never names its line's" {
  run "${repo_root}/bin/tutorials" site release/0.4.7
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' line=0.4 directory=tutorials/0.4 base=/kit/tutorials/0.4/ url="${site}/0.4/")" ]
  # a base for a site served on this machine is kit's to read, never the build's
  KIT_TUTORIALS_BASE=http://localhost:5173/ run "${repo_root}/bin/tutorials" site release/0.5.0-rc.1
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' line=0.5.0-rc.1 directory=tutorials/0.5.0-rc.1 base=/kit/tutorials/0.5.0-rc.1/ \
    url="${site}/0.5.0-rc.1/")" ]
  run "${repo_root}/bin/tutorials" site main
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' line=main directory=tutorials/main base=/kit/tutorials/main/ url="${site}/main/")" ]
  local ref
  for ref in feature/x release/nope release/0.1 release/../0.1.0 ''
  do
    run --separate-stderr "${repo_root}/bin/tutorials" site "${ref}"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"'${ref}' has no copy of the tutorials: main and a release tag have one"* ]]
  done
  run "${repo_root}/bin/tutorials" site
  [ "$status" -eq 2 ]
}

@test "the address kit opens for a version is the directory its ref publishes, on this repository's Pages" {
  local version ref line directory base url opened
  for version in unreleased 0.1.0-rc.7 0.1.0 0.4.12
  do
    ref=release/${version}
    [[ "${version}" != unreleased ]] || ref=main
    # GitHub serves the gh-pages branch of <owner>/<repository> at https://<owner>.github.io/<repository>/
    GITHUB_REPOSITORY=empowerite/kit run "${repo_root}/bin/tutorials" site "${ref}"
    [ "$status" -eq 0 ]
    line='' directory='' base='' url=''
    eval "${output}"
    opened=$(bash -c 'source "$1/modules/bash/1st.sh"; use tutorials; tutorials:base "$2"' _ "${kit_root}" "${version}")
    [ "${url}" = "${opened}" ]
    [ "${url}" = "https://empowerite.github.io/kit/${directory}/" ]
    [ "${base}" = "/kit/${directory}/" ]
    [ "${directory}" = "tutorials/${line}" ]
  done
  # the gate's build is main's copy
  grep --quiet --fixed-strings "TUTORIALS_BASE=${base%/*/}/main/ vite build" "${repo_root}/projects/tutorials/package.json"
  # in a repository whose Pages are at another address, nothing is built for an address kit never opens
  GITHUB_REPOSITORY=someone/fork run --separate-stderr "${repo_root}/bin/tutorials" site main
  [ "$status" -eq 1 ]
  [ "$output" = "" ]
  [[ "$stderr" == *"kit opens its tutorials at ${site}/, and the Pages of someone/fork are at https://someone.github.io/fork/"* ]]
}

@test "the workflow builds the copy site names, and publishes the build to the directory site names" {
  local workflow="${repo_root}/.github/workflows/tutorials.yml" retire="${repo_root}/.github/workflows/retire-pre-releases.yml"
  # the build job only reads, and asks bin/tutorials which copy the ref is
  [ "$(yq -o json -I 0 '.permissions' "${workflow}")" = '{"contents":"read"}' ]
  [ "$(yq -o json -I 0 '.jobs.build.permissions' "${workflow}")" = '{"contents":"read"}' ]
  [ "$(yq '.jobs.build.steps[] | select(.id == "site") | .run' "${workflow}")" \
    = 'bin/tutorials site "${GITHUB_REF_NAME}" >> "${GITHUB_OUTPUT}"' ]
  [ "$(yq -o json -I 0 '.jobs.build.steps[] | select(.name == "build") | .env' "${workflow}")" \
    = '{"TUTORIALS_BASE":"${{ steps.site.outputs.base }}","TUTORIALS_LINE":"${{ steps.site.outputs.line }}"}' ]
  [ "$(yq '.jobs.build.outputs.directory' "${workflow}")" = '${{ steps.site.outputs.directory }}' ]
  # the publish job alone writes, runs no package of npm's, and its step is the one command
  [ "$(yq -o json -I 0 '.jobs.publish.permissions' "${workflow}")" = '{"contents":"write"}' ]
  [ "$(yq '.jobs.publish.needs' "${workflow}")" = build ]
  run ! grep --quiet npm <(yq '.jobs.publish' "${workflow}")
  [ "$(yq '.jobs.publish.steps[] | select(.name == "publish") | .env.DIRECTORY' "${workflow}")" \
    = '${{ needs.build.outputs.directory }}' ]
  [ "$(yq '.jobs.publish.steps[] | select(.name == "publish") | .run' "${workflow}")" \
    = 'bin/tutorials publish "${DIRECTORY}" "${RUNNER_TEMP}/site"' ]
  # and the run then asks the address site named, so a copy Pages does not serve fails it
  [ "$(yq '.jobs.build.outputs.url' "${workflow}")" = '${{ steps.site.outputs.url }}' ]
  [ "$(yq '.jobs.publish.steps[-1].name' "${workflow}")" = answers ]
  [ "$(yq -o json -I 0 '.jobs.publish.steps[-1].env' "${workflow}")" = '{"URL":"${{ needs.build.outputs.url }}"}' ]
  [ "$(yq '.jobs.publish.steps[-1].run' "${workflow}")" = 'bin/tutorials answers "${URL}"' ]
  # what the build uploads is what publish is given
  [ "$(yq '.jobs.build.steps[] | select(.name == "upload") | .with.path' "${workflow}")" = projects/tutorials/dist/ ]
  [ "$(yq '.jobs.publish.steps[] | select(.name == "download") | .with.path' "${workflow}")" \
    = '${{ runner.temp }}/site' ]
  # a deleted branch retires the copies of the pre-releases it retires
  [ "$(yq '.jobs.retire.steps[] | select(.name == "retire-the-tutorials") | .run' "${retire}")" = 'bin/tutorials retire' ]
}

@test "publish and retire run on a runner alone" {
  local verb
  for verb in "publish tutorials/main $(built one)" retire
  do
    # shellcheck disable=SC2086  # the words of one command
    TUTORIALS_PAGES="${BATS_TEST_TMPDIR}/nonesuch.git" run --separate-stderr "${repo_root}/bin/tutorials" ${verb}
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"the tutorials are published by the tutorials workflow, not from a desk"* ]]
  done
}

@test "publish replaces one copy whole, leaves the others, and main's gives the site its 404 page" {
  pages
  local one two three
  one=$(built one) two=$(built two) three=$(built three)
  printf 'old' > "${one}/old.html"
  run "${repo_root}/bin/tutorials" publish tutorials/main "${one}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"published tutorials/main"* ]]
  [ "$(online tutorials/main/old.html)" = old ]
  # the push is git's, with the credentials gh has for the runner's token
  [ "$(cat "${FAKES}/gh.calls")" = 'auth setup-git' ]
  "${repo_root}/bin/tutorials" publish tutorials/main "${three}"
  # the same build again changes nothing, so it commits nothing
  run "${repo_root}/bin/tutorials" publish tutorials/main "${three}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tutorials/main is as published"* ]]
  "${repo_root}/bin/tutorials" publish tutorials/0.1 "${two}"
  [ "$(online tutorials/main/index.html)$(online tutorials/0.1/index.html)$(online 404.html)" = threetwothree ]
  [ "$(online tutorials/0.1/assets/site.css)" = two ]
  [ "$(listed -r --name-only gh-pages | grep -c -e '^\.nojekyll$' -e old.html)" -eq 1 ]
  [ "$(online .nojekyll)" = "" ]
  [ "$(git --git-dir="${TUTORIALS_PAGES}" rev-list --count gh-pages)" -eq 3 ]
  [ "$(git --git-dir="${TUTORIALS_PAGES}" log -1 --format=%an gh-pages)" = 'github-actions[bot]' ]
  # a directory that is no copy of the site is a usage error, and a build with no index.html is refused
  local directory
  for directory in ../x tutorials tutorials/ tutorials/a/b tutorials/.. /tutorials/main
  do
    run "${repo_root}/bin/tutorials" publish "${directory}" "${one}"
    [ "$status" -eq 2 ]
  done
  run --separate-stderr "${repo_root}/bin/tutorials" publish tutorials/0.2 "${BATS_TEST_TMPDIR}"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"no built site at ${BATS_TEST_TMPDIR}: it has no index.html"* ]]
  rm "${one}/404.html"
  run --separate-stderr "${repo_root}/bin/tutorials" publish tutorials/main "${one}"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"no built site at ${one}: it has no 404.html"* ]]
  TUTORIALS_PAGES="${BATS_TEST_TMPDIR}/nonesuch.git" run "${repo_root}/bin/tutorials" publish tutorials/0.2 "${two}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not answer for its gh-pages branch; nothing is changed there"* ]]
  [ "$(git --git-dir="${TUTORIALS_PAGES}" rev-list --count gh-pages)" -eq 3 ]
}

@test "a push that is refused is tried again on the branch as it then stands, five times at most" {
  pages
  "${repo_root}/bin/tutorials" publish tutorials/main "$(built one)"
  # the repository refuses the next push once
  printf '#!/bin/sh\n[ -e refused ] && exit 0\ntouch refused\nexit 1\n' > "${TUTORIALS_PAGES}/hooks/update"
  chmod +x "${TUTORIALS_PAGES}/hooks/update"
  run "${repo_root}/bin/tutorials" publish tutorials/0.1 "$(built two)"
  [ "$status" -eq 0 ]
  [ -e "${TUTORIALS_PAGES}/refused" ]
  [ "$(online tutorials/0.1/index.html)$(online tutorials/main/index.html)" = twoone ]
  # and one that refuses every push is given up after the fifth
  printf '#!/bin/sh\necho x >> refusals\nexit 1\n' > "${TUTORIALS_PAGES}/hooks/update"
  run --separate-stderr "${repo_root}/bin/tutorials" publish tutorials/0.2 "$(built three)"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"tutorials/0.2 is not published: the push to gh-pages was refused 5 times"* ]]
  [ "$(wc -l < "${TUTORIALS_PAGES}/refusals" | tr -d ' ')" -eq 5 ]
  run ! online tutorials/0.2/index.html
}

@test "retire removes the copy of each pre-release whose tag is gone, and nothing else" {
  pages
  # before anything is published there is nothing to retire
  run "${repo_root}/bin/tutorials" retire
  [ "$status" -eq 0 ]
  [[ "$output" == *"copies of the tutorials retired: 0"* ]]
  local directory
  for directory in tutorials/main tutorials/0.1 tutorials/0.1.0-rc.7 tutorials/0.1.0-rc.8 tutorials/0.2.0-beta
  do
    "${repo_root}/bin/tutorials" publish "${directory}" "$(built one)"
  done
  git --git-dir="${TUTORIALS_PAGES}" tag release/0.1.0-rc.8 gh-pages
  # --dry-run says what would go, from a desk too, and changes nothing
  run env -u GITHUB_ACTIONS "${repo_root}/bin/tutorials" retire --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would have retired tutorials/0.1.0-rc.7: the tag release/0.1.0-rc.7 is gone"* ]]
  [[ "$output" == *"copies of the tutorials that would be retired: 2"* ]]
  [ "$(git --git-dir="${TUTORIALS_PAGES}" rev-list --count gh-pages)" -eq 5 ]
  run "${repo_root}/bin/tutorials" retire
  [ "$status" -eq 0 ]
  [[ "$output" == *"retired tutorials/0.1.0-rc.7: the tag release/0.1.0-rc.7 is gone"* ]]
  [[ "$output" == *"retired tutorials/0.2.0-beta"* ]]
  [[ "$output" == *"copies of the tutorials retired: 2"* ]]
  [[ "$output" != *"would"* ]]
  [ "$(listed --name-only gh-pages tutorials/ | LC_ALL=C sort | paste -s -d ' ' -)" \
    = "tutorials/0.1 tutorials/0.1.0-rc.8 tutorials/main" ]
  [ "$(online 404.html)" = one ]
  # the two went in one commit, and a second run finds nothing to do
  [ "$(git --git-dir="${TUTORIALS_PAGES}" rev-list --count gh-pages)" -eq 6 ]
  run "${repo_root}/bin/tutorials" retire
  [ "$status" -eq 0 ]
  [ "$(git --git-dir="${TUTORIALS_PAGES}" rev-list --count gh-pages)" -eq 6 ]
  # a repository that does not answer for its tags retires nothing, where no tag would read as every tag gone
  TUTORIALS_PAGES="${BATS_TEST_TMPDIR}/nonesuch.git" run "${repo_root}/bin/tutorials" retire
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not answer for its tags; nothing is retired"* ]]
  run "${repo_root}/bin/tutorials" retire --nonesuch
  [ "$status" -eq 2 ]
}

@test "answers asks an address until it answers 200, and fails, with the remedy, when it never does" {
  answering 200
  run "${repo_root}/bin/tutorials" answers "${site}/main/"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${site}/main/ answers"* ]]
  [ "$(cat "${FAKES}/curl.calls")" = "${site}/main/" ]
  # Pages takes a while to serve a branch it was just pushed: an address that is not there yet is asked again
  answering 404 000 200
  TUTORIALS_PAUSE=0 run "${repo_root}/bin/tutorials" answers "${site}/0.1/"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${FAKES}/curl.calls" | tr -d ' ')" -eq 3 ]
  # one that never answers fails after the last try, and says who turns Pages on and where that is written
  answering 404
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/summary"
  TUTORIALS_PAUSE=0 TUTORIALS_TRIES=4 run --separate-stderr "${repo_root}/bin/tutorials" answers "${site}/0.1/"
  [ "$status" -eq 1 ]
  [ "$(wc -l < "${FAKES}/curl.calls" | tr -d ' ')" -eq 4 ]
  [[ "$stderr" == *"${site}/0.1/ did not answer 200 in 4 tries; its last answer was 404"* ]]
  [[ "$stderr" == *"an owner of the repository turns Pages on once"*"projects/tutorials/README.md"* ]]
  grep --quiet --fixed-strings "### ❌ ${site}/0.1/ did not answer 200 in 4 tries" "${GITHUB_STEP_SUMMARY}"
  answering 000
  TUTORIALS_PAUSE=0 TUTORIALS_TRIES=2 run --separate-stderr "${repo_root}/bin/tutorials" answers "${site}/0.1/"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"did not answer 200 in 2 tries; it gave no answer at all"* ]]
  # an address is a web address, and one alone
  local words
  for words in '' 'ftp://example.test/' "${site}/main/ ${site}/0.1/" 'tutorials/main'
  do
    # shellcheck disable=SC2086  # the words of one command
    run "${repo_root}/bin/tutorials" answers ${words}
    [ "$status" -eq 2 ]
  done
}
