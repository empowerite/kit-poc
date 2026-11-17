#!/usr/bin/env bats
# release.bats - bin/release verifies a tag and packs a checkout as a release that installs from its unpacked directory
# ----------------------------------------------------------------------------------------------------------------------

bats_require_minimum_version 1.5.0

load helper

# bin/release packs the commit a tag names, from the repository it is in, so the tests run it in a copy of this one,
# tagged for each version a test packs. Only the copy is changed, and teardown puts it back.
setup_file() {
  export RELEASE_REPO="${BATS_FILE_TMPDIR}/repo"
  release-repo "${RELEASE_REPO}" release/9.9.9 release/9.9.5 release/9.9.9-rc.1 \
    "release/$(sed -n 's/^version=//p' "${BATS_TEST_DIRNAME}/../README.md" | head -n 1)"
}

teardown() {
  git -C "${RELEASE_REPO}" checkout --quiet -- . && git -C "${RELEASE_REPO}" clean --quiet --force -d
  helper:outside-checkout
}

setup() {
  repo_bin=${RELEASE_REPO}/bin
  # go is a fake: each build writes, at its -o path, a script that names the platform it was built for
  fakes="${BATS_TEST_TMPDIR}/fakes"
  mkdir -p "${fakes}"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-go" "${fakes}/go"
  export FAKES="${fakes}" PATH="${fakes}:${PATH}"
  work=$(mktemp -d)
  cd "${work}"
}

@test "verify holds a tag to its shape, and a release tag to the default branch" {
  git init --quiet --bare --initial-branch=main origin.git && git clone --quiet origin.git desk 2>/dev/null && cd desk
  printf 'one\n' > a && git add a && git commit --quiet --message one && git push --quiet origin main
  git remote set-head origin main
  git tag release/1.2.3 && git tag release/1.2.3-rc.1 && git tag release/nope && git tag v1.2.3
  git switch --quiet --create topic && printf 'two\n' > b && git add b && git commit --quiet --message two
  git tag release/1.2.4 && git tag release/1.2.4-rc.1
  run "${repo_bin}/release" verify release/1.2.3
  [ "$status" -eq 0 ]
  run "${repo_bin}/release" verify release/1.2.4-rc.1
  [ "$status" -eq 0 ]
  run "${repo_bin}/release" verify release/1.2.3-rc.1
  [ "$status" -eq 0 ]
  # the loader, kit update, and the release's download read a suffix of letters, digits, and dots alone, so a tag with
  # a hyphen in it would be published and could never be pinned
  git tag release/1.2.3-rc-2 main
  run "${repo_bin}/release" verify release/1.2.3-rc-2
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a release tag"* ]]
  run "${repo_bin}/release" verify release/1.2.4
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not on main"* ]]
  run "${repo_bin}/release" verify release/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a release tag"* ]]
  run "${repo_bin}/release" verify v1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a release tag"* ]]
}

# retire-world <release-list-json> makes a desk with an origin, a pre-release tagged on a commit of a branch that origin
# has deleted or kept, as the test says, and a gh that answers the list and records the deletes. It runs in the desk.
retire-world() {
  git init --quiet --bare --initial-branch=main origin.git && git clone --quiet origin.git desk 2>/dev/null && cd desk
  printf 'one\n' > a && git add a && git commit --quiet --message one && git push --quiet origin main
  git remote set-head origin main
  git switch --quiet --create topic
  printf 'two\n' > b && git add b && git commit --quiet --message two
  git tag release/1.0.0-rc.1 && git push --quiet origin topic release/1.0.0-rc.1
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "${FAKES}/gh.calls"' \
    '[[ "$1 $2" == "release list" ]] && cat "${FAKES}/gh.list"; exit "${FAKE_GH_STATUS:-0}"' > "${fakes}/gh"
  chmod +x "${fakes}/gh"
  printf '%s\n' "$1" > "${fakes}/gh.list"
}

@test "retire deletes a pre-release no branch reaches, and keeps one a branch still reaches" {
  retire-world '[{"tagName":"release/1.0.0-rc.1","isPrerelease":true},{"tagName":"release/1.0.0","isPrerelease":false}]'
  run env GITHUB_ACTIONS=true "${repo_bin}/release" retire
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping release/1.0.0-rc.1: a branch still reaches"* ]]
  [[ "$output" == *"retired 0 pre-release(s)"* ]]
  git push --quiet origin --delete topic
  run env GITHUB_ACTIONS=true "${repo_bin}/release" retire topic
  [ "$status" -eq 0 ]
  [[ "$output" == *"retired release/1.0.0-rc.1: no branch reaches"* ]]
  grep -q '^release delete release/1.0.0-rc.1 --cleanup-tag --yes$' "${fakes}/gh.calls"
  [ "$(grep -c '^release delete' "${fakes}/gh.calls")" -eq 1 ]
}

@test "retire keeps a pre-release when the branches that reach it fill more than a pipe holds" {
  retire-world '[{"tagName":"release/1.0.0-rc.1","isPrerelease":true}]'
  # a git whose branch listing is long, its first branch one that reaches the commit
  real=$(command -v git)
  printf '%s\n' '#!/usr/bin/env bash' \
    "[[ \"\$*\" == *--contains* ]] || exec ${real} \"\$@\"" \
    'echo "  origin/topic"; yes "  origin/another-branch-of-a-long-name" | head -c 400000' > "${fakes}/git"
  chmod +x "${fakes}/git"
  run env GITHUB_ACTIONS=true "${repo_bin}/release" retire
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping release/1.0.0-rc.1"* ]]
  run -1 grep -q '^release delete' "${fakes}/gh.calls"
}

@test "retire fails, and deletes nothing, when the releases cannot be listed" {
  retire-world '[]'
  printf 'HTTP 401: Bad credentials\n' > "${fakes}/gh.list"
  run env GITHUB_ACTIONS=true FAKE_GH_STATUS=1 "${repo_bin}/release" retire
  [ "$status" -eq 1 ]
  [[ "$output" == *"the releases could not be listed"* ]]
  [[ "$output" != *"retired 0"* ]]
}

@test "retire says when the list is at its limit, so older pre-releases may be unread" {
  retire-world "$(jq -n '[range(1000) | {tagName: "release/1.0.0-rc.\(.)", isPrerelease: false}]')"
  run env GITHUB_ACTIONS=true "${repo_bin}/release" retire
  [ "$status" -eq 0 ]
  [[ "$output" == *"the list holds 1000 releases, the most gh is asked for; older pre-releases are not read"* ]]
}

# tap-world makes a tap, a bare repository with a formula of an older release on main, and a gh that answers what tap
# asks of it: the digest beside the release, a clone of the tap, and a pull request, which it records and merges.
tap-world() {
  git init --quiet --bare --initial-branch=main tap.git && git clone --quiet tap.git seed 2>/dev/null
  mkdir -p seed/Formula && printf 'old\n' > seed/Formula/kit.rb
  git -C seed add Formula && git -C seed -c user.name=a -c user.email=a@b commit --quiet --message seed && git -C seed push --quiet origin main
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "${FAKES}/gh.calls"' \
    'case "$1 $2" in' \
    '  "release download") printf "%s  kit-%s.tar.gz\n" "${FAKE_DIGEST}" "${3#release/}" > "$(sed "s/.*--dir //;s/ .*//" <<<"$*")/kit-${3#release/}.tar.gz.sha256" ;;' \
    '  "repo clone") git clone --quiet "${FAKE_TAP}" "$4" ;;' \
    'esac' > "${fakes}/gh"
  chmod +x "${fakes}/gh"
  export FAKE_TAP="${PWD}/tap.git" FAKE_DIGEST=$(printf 'x%.0s' {1..64} | tr x a)
}

@test "formula writes kit.rb for the version, with the digest, and refuses a digest that is not one" {
  digest=$(printf 'b%.0s' {1..64})
  run "${repo_bin}/release" formula release/1.2.3 "${digest}"
  [ "$status" -eq 0 ]
  [[ "$output" == "# kit - "* ]]
  [[ "$output" == *"class Kit < Formula"* ]]
  [[ "$output" == *'generate_completions_from_executable(bin/"kit", "completion", shells: [:zsh])'* ]]
  [[ "$output" == *'url "https://github.com/empowerite/kit/releases/download/release/1.2.3/kit-1.2.3.tar.gz"'* ]]
  [[ "$output" == *"sha256 \"${digest}\""* ]]
  [[ "$output" != *"{{"* ]]
  run "${repo_bin}/release" formula release/1.2.3 not-a-digest
  [ "$status" -eq 1 ]
  [[ "$output" == *"not-a-digest is not a sha256 digest"* ]]
}

@test "tap writes the formula with the digest published beside the release, and merges the pull request that carries it" {
  tap-world
  run env GITHUB_ACTIONS=true KIT_TAP=empowerite/homebrew-tap "${repo_bin}/release" tap release/9.9.9
  [ "$status" -eq 0 ]
  [[ "$output" == *"holds kit 9.9.9"* ]]
  git -C tap.git show kit-9.9.9:Formula/kit.rb | grep -q "sha256 \"${FAKE_DIGEST}\""
  git -C tap.git show kit-9.9.9:Formula/kit.rb | grep -q 'class Kit < Formula'
  grep -q '^pr create --repo empowerite/homebrew-tap --base main --head kit-9.9.9 ' "${fakes}/gh.calls"
  grep -q '^pr merge kit-9.9.9 --repo empowerite/homebrew-tap --squash --delete-branch$' "${fakes}/gh.calls"
}

@test "tap writes nothing when the tap already holds the formula" {
  tap-world
  "${repo_bin}/release" formula release/9.9.9 "${FAKE_DIGEST}" > seed/Formula/kit.rb
  git -C seed add Formula && git -C seed -c user.name=a -c user.email=a@b commit --quiet --message same && git -C seed push --quiet origin main
  run env GITHUB_ACTIONS=true "${repo_bin}/release" tap release/9.9.9
  [ "$status" -eq 0 ]
  [[ "$output" == *"holds kit 9.9.9 already"* ]]
  run -1 grep -q '^pr ' "${fakes}/gh.calls"
}

@test "tap leaves a pre-release out of the tap, and touches nothing" {
  tap-world
  run env GITHUB_ACTIONS=true "${repo_bin}/release" tap release/9.9.9-rc.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"release/9.9.9-rc.1 is a pre-release; the tap carries stable releases only"* ]]
  [ ! -e "${fakes}/gh.calls" ]
}

@test "tap refuses a release from a desk, as publish does" {
  run env -u GITHUB_ACTIONS "${repo_bin}/release" tap release/1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"a release reaches the tap from the release workflow, not from a desk"* ]]
}

@test "publish refuses a release from a desk, and names the push that has the runner publish it" {
  run env -u GITHUB_ACTIONS "${repo_bin}/release" publish release/1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"a release is published by the release workflow, not from a desk"* ]]
  [[ "$output" == *"git push origin release/1.2.3"* ]]
}

@test "pack makes one directory with the release's layout and the version stamped in, which installs a repository" {
  version=9.9.9
  run "${repo_bin}/release" pack "release/${version}" "${work}"
  [ "$status" -eq 0 ]
  [[ "$(cat "kit-${version}.tar.gz.sha256")" =~ ^[0-9a-f]{64}\ \ kit-9\.9\.9\.tar\.gz$ ]]
  shasum --algorithm 256 --check --status "kit-${version}.tar.gz.sha256"
  mkdir unpacked && tar --extract --gzip --file "kit-${version}.tar.gz" --directory unpacked
  [ "$(ls unpacked)" = "kit-${version}" ]
  [ -x "unpacked/kit-${version}/bin/kit" ]
  [ -x "unpacked/kit-${version}/bin/kit-install" ]
  [ -f "unpacked/kit-${version}/packages/agents/claude/package.yml" ]
  [ "$(ls "unpacked/kit-${version}/libexec")" = \
    $'kit-call\nkittui-darwin-amd64\nkittui-darwin-arm64\nkittui-linux-amd64\nkittui-linux-arm64' ]
  [ "$("unpacked/kit-${version}/libexec/kittui-linux-arm64" x)" = "kittui linux-arm64 x" ]
  grep -q '^linux amd64 0 build -trimpath -ldflags -s -w -X main.version=9.9.9 -o .*/libexec/kittui-linux-amd64 ./cmd/kittui$' "${fakes}/go.calls"
  mkdir fresh && git -C fresh init --quiet --initial-branch=main
  cd fresh
  run "${work}/unpacked/kit-${version}/bin/kit" install agents/claude
  [ "$status" -eq 0 ]
  run "${work}/unpacked/kit-${version}/bin/kit" check
  [ "$status" -eq 0 ]
  [ "$("${work}/unpacked/kit-${version}/bin/kit" version)" = "${version}" ]
  grep --quiet "^version: ${version}$" kit.yml
}

@test "pack packs the tag's commit, not the disk: an edit made since and a file never committed are not in it" {
  printf '# edited after the tag\n' >> "${RELEASE_REPO}/kit/bin/kit-version"
  printf 'x\n' > "${RELEASE_REPO}/kit/modules/bash/stray.sh"
  run "${repo_bin}/release" pack release/9.9.9 "${work}"
  [ "$status" -eq 0 ]
  mkdir unpacked && tar --extract --gzip --file kit-9.9.9.tar.gz --directory unpacked
  [ ! -e unpacked/kit-9.9.9/modules/bash/stray.sh ]
  git -C "${RELEASE_REPO}" show release/9.9.9:kit/bin/kit-version | cmp - unpacked/kit-9.9.9/bin/kit-version
}

@test "pack refuses a tag the repository does not have, and leaves neither file" {
  run "${repo_bin}/release" pack release/9.9.8 "${work}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"release/9.9.8 is not a tag in this repository; tag the commit to release first"* ]]
  [ -z "$(ls "${work}")" ]
}

@test "pack refuses, and leaves neither file, when no digest comes back" {
  printf '%s\n' '#!/usr/bin/env bash' > "${fakes}/sha256sum"
  cp "${fakes}/sha256sum" "${fakes}/shasum"
  chmod +x "${fakes}/sha256sum" "${fakes}/shasum"
  run "${repo_bin}/release" pack release/9.9.9 "${work}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit-9.9.9.tar.gz has no sha256 digest; nothing is packed"* ]]
  [ -z "$(ls "${work}")" ]
}

@test "the loader fetches the release pack wrote: its digest holds, and the release runs as its version" {
  export FAKE_RELEASES="${work}/releases"
  mkdir -p "${FAKE_RELEASES}"
  run "${repo_bin}/release" pack release/9.9.5 "${FAKE_RELEASES}"
  [ "$status" -eq 0 ]
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-curl" "${fakes}/curl"
  mkdir clone && git -C clone init --quiet --initial-branch=main
  cd clone
  printf 'version: 9.9.5\n' > kit.yml
  run "${kit_checkout}/bin/kit" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fetching kit 9.9.5 from its release"* ]]
  [ "${lines[-1]}" = 9.9.5 ]
  [ -x "${XDG_CACHE_HOME}/kit/kit-9.9.5/bin/kit" ]
}

@test "fetch takes the published release through the loader, and refuses one whose bytes are not the digest's" {
  export FAKE_RELEASES="${work}/releases"
  mkdir -p "${FAKE_RELEASES}"
  "${repo_bin}/release" pack release/9.9.5 "${FAKE_RELEASES}"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-curl" "${fakes}/curl"
  run "${repo_bin}/release" fetch release/9.9.5
  [ "$status" -eq 0 ]
  [[ "$output" == *"kit 9.9.5 fetches from its release, with the digest published beside it, and runs as 9.9.5"* ]]
  grep -q '/releases/download/release/9\.9\.5/kit-9\.9\.5\.tar\.gz\.sha256$' "${FAKE_RELEASES}/curl.calls"
  [ ! -e "${XDG_CACHE_HOME}/kit/kit-9.9.5" ]
  printf 'x' >> "${FAKE_RELEASES}/kit-9.9.5.tar.gz"
  run "${repo_bin}/release" fetch release/9.9.5
  [ "$status" -eq 1 ]
  [[ "$output" == *"not the "*" its release publishes; it is not unpacked"* ]]
  [[ "$output" == *"kit 9.9.5 cannot be fetched from its release, so no machine can install it"* ]]
  run "${repo_bin}/release" fetch v9.9.5
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a release tag"* ]]
}

# install-lines <page> <heading> prints the first sh block under the page's heading: the lines a reader pastes.
install-lines() {
  awk -v heading="$2" '
    $0 == heading { under = 1; next }
    under && /^```sh$/ { inside = 1; next }
    inside && /^```$/ { exit }
    inside { print }
  ' "${BATS_TEST_DIRNAME}/../$1"
}

@test "the install lines the pages give install the release pack wrote, and unpack nothing its digest does not hold" {
  pasted=$(install-lines README.md '## Install')
  [[ "${pasted}" == *curl* && "${pasted}" != *brew* ]]
  [ "$(install-lines docs/install.md '### By download')" = "${pasted}" ]
  version=$(sed -n 's/^version=//p' <<<"${pasted}")
  export FAKE_RELEASES="${work}/releases"
  mkdir -p "${FAKE_RELEASES}"
  "${repo_bin}/release" pack "release/${version}" "${FAKE_RELEASES}"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-curl" "${fakes}/curl"
  cp "${FAKE_RELEASES}/kit-${version}.tar.gz" "${work}/packed.tar.gz"
  cp "${FAKE_RELEASES}/kit-${version}.tar.gz.sha256" "${work}/packed.sha256"
  # The page names shasum, and sha256sum for a Linux machine without it; GNU's is the one such a machine has.
  checks=('shasum --algorithm 256 --check')
  ! sha256sum --version 2>/dev/null | grep --quiet GNU || checks+=('sha256sum --check')
  [[ "${pasted}" == *'shasum --algorithm 256 --check'* ]]
  for check in "${checks[@]}"
  do
    # Pasted lines run one by one, whatever the line before did, so the file is run without errexit.
    printf '%s\n' "${pasted//shasum --algorithm 256 --check/${check}}" > "${work}/install.sh"
    rm -rf "${HOME}/.local" "${work}/downloads" && mkdir "${work}/downloads" && cd "${work}/downloads"
    cp "${work}/packed.tar.gz" "${FAKE_RELEASES}/kit-${version}.tar.gz"
    cp "${work}/packed.sha256" "${FAKE_RELEASES}/kit-${version}.tar.gz.sha256"
    run bash "${work}/install.sh"
    [ "$status" -eq 0 ]
    grep -q "/releases/download/release/${version}/kit-${version}\.tar\.gz\.sha256\$" "${FAKE_RELEASES}/curl.calls"
    [ "$(readlink "${HOME}/.local/bin/kit")" = "${HOME}/.local/share/kit-${version}/bin/kit" ]
    [ "$("${HOME}/.local/bin/kit" version)" = "${version}" ]
    # bytes that are not the digest's, then a .sha256 with no digest in it: nothing is unpacked, and nothing linked
    rm -rf "${HOME}/.local" "${work}/downloads" && mkdir "${work}/downloads" && cd "${work}/downloads"
    printf 'x' >> "${FAKE_RELEASES}/kit-${version}.tar.gz"
    run bash "${work}/install.sh"
    [ "$status" -ne 0 ]
    [ ! -e "${HOME}/.local" ]
    rm -rf "${work}/downloads" && mkdir "${work}/downloads" && cd "${work}/downloads"
    : > "${FAKE_RELEASES}/kit-${version}.tar.gz.sha256"
    run bash "${work}/install.sh"
    [ "$status" -ne 0 ]
    [ ! -e "${HOME}/.local" ]
  done
}

@test "publish uploads the tarball, kittui inside it, and its digest, and nothing beside them" {
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "${FAKES}/gh.calls"' \
    'tar -tzf "$4" > "${FAKES}/listing"' > "${fakes}/gh"
  chmod +x "${fakes}/gh"
  run env GITHUB_ACTIONS=true "${repo_bin}/release" publish release/9.9.9
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${fakes}/go.calls" | tr -d ' ')" -eq 4 ]
  # the tag must exist already: gh would otherwise make one at the default branch's head
  grep -q '^release create release/9\.9\.9 /[^ ]*/kit-9\.9\.9\.tar\.gz /[^ ]*/kit-9\.9\.9\.tar\.gz\.sha256 --verify-tag --title' "${fakes}/gh.calls"
  run -1 grep -q 'kittui' "${fakes}/gh.calls"
  grep -q '^kit-9\.9\.9/libexec/kittui-darwin-arm64$' "${fakes}/listing"
}

@test "the notes of a release give the download lines the pages lead with, for that version, then the mise pin" {
  printf '%s\n' '#!/usr/bin/env bash' 'while (( $# )); do [[ "$1" == --notes ]] && printf "%s\n" "$2" > "${FAKES}/notes"; shift; done' \
    > "${fakes}/gh"
  chmod +x "${fakes}/gh"
  run env GITHUB_ACTIONS=true "${repo_bin}/release" publish release/9.9.9
  [ "$status" -eq 0 ]
  # the lines are the pages' with version set to this release's; the README's are the install page's, as another test holds
  pasted=$(install-lines README.md '## Install')
  expected=$(sed 's/^version=.*/version=9.9.9/' <<<"${pasted}")
  [ "$(install-lines docs/install.md '### By download' | sed 's/^version=.*/version=9.9.9/')" = "${expected}" ]
  lines=$(sed -n '/^    version=9.9.9$/,/^      ln -s -f /p' "${fakes}/notes" | sed 's/^    //')
  [ "${lines}" = "${expected}" ]
  # the pin follows, for the person's own mise config and not the repository's, and kit install after it
  [[ "$(<"${fakes}/notes")" == *'Or add it to your own ~/.config/mise/config.toml:'* ]]
  [[ "$(<"${fakes}/notes")" != *'mise.toml'* ]]
  [[ "$(<"${fakes}/notes")" == *'"github:empowerite/kit" = { version = "9.9.9", version_prefix = "release/" }'* ]]
  [[ "$(<"${fakes}/notes")" == *'kit install'* ]]
  # a pre-release's notes name its own version
  run env GITHUB_ACTIONS=true "${repo_bin}/release" publish release/9.9.9-rc.1
  [ "$status" -eq 0 ]
  grep -q '^    version=9\.9\.9-rc\.1$' "${fakes}/notes"
}

# ----------------------------------------------------------------------------------------------------------------------
