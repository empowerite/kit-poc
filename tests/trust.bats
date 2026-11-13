#!/usr/bin/env bats
# trust.bats - kit runs nothing in a clone until you trust it: the loader, kit:enter, the module path, and kit trust
# ----------------------------------------------------------------------------------------------------------------------
# Each test gets an empty git repository and a trust file of its own, empty, so the repository starts untrusted; the
# test helper trusts every clone for every other file. A clone that would run code of its own holds a kit/bin/kit
# that leaves a mark when it runs.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fresh-repo >/dev/null
  kit="${kit_checkout}/bin/kit"
  trusted="${XDG_CONFIG_HOME}/kit/trusted"
  : > "${trusted}"
}

# own-kit makes the clone declare unreleased and hold a kit/ of its own whose bin/kit leaves ${BATS_TEST_TMPDIR}/ran
# when it runs.
own-kit() {
  printf 'version: unreleased\n' > kit.yml
  mkdir -p kit/bin kit/modules/bash
  printf '#!/bin/sh\n: > "%s/ran"\n' "${BATS_TEST_TMPDIR}" > kit/bin/kit
  chmod +x kit/bin/kit
  : > kit/modules/bash/1st.sh
}

# recorded <path> succeeds when the trust file holds one line, a clone's record of <path>: a sha256, two spaces, and
# the path.
recorded() {
  local line
  line=$(cat "${trusted}")
  [[ "${line}" =~ ^[0-9a-f]{64}\ \ (.*)$ && "${BASH_REMATCH[1]}" == "$1" ]]
}

# answering <answer> <command> runs the command on a terminal of its own, and types the answer there once the question
# is up; script gives the command the terminal, as tests/helper.bash's pty does.
answering() {
  local answer=$1
  shift
  { sleep 2; printf '%s\n' "${answer}"; sleep 2; } | if script --version >/dev/null 2>&1
  then
    script --quiet --return --command "$*" /dev/null
  else
    script -q /dev/null bash -c "$*"
  fi
}

@test "in a clone you have not trusted, every verb but help, version, trust, and syntax is refused, by the loader and by the verb" {
  run "${kit}" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it; see what it asks kit to run, and trust it: kit trust"* ]]
  # bare kit, kit tui, off a terminal, where kittui could not ask
  run "${kit}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it"* ]]
  run "${kit_checkout}/bin/kit-check"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it"* ]]
  run "${kit}" version
  [ "$status" -eq 0 ]
  [ "$output" = unreleased ]
  run "${kit}" help
  [ "$status" -eq 0 ]
  run "${kit}" -h
  [ "$status" -eq 0 ]
}

@test "on a terminal, a verb in a clone you have not trusted asks first, and after a yes runs as it was typed" {
  run answering y "'${kit}' root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it"* ]]
  [[ "$output" == *"Trust $(pwd -P)? [y/N]"* ]]
  [[ "$output" == *"kit trusts $(pwd -P), and every worktree of it"* ]]
  [[ "$output" == *"${kit_checkout}"* ]]
  recorded "$(pwd -P)"
}

@test "on a terminal, a no keeps the clone untrusted, and the verb does not run" {
  run answering n "'${kit}' root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not trusted; kit runs nothing there"* ]]
  [[ "$output" != *"${kit_checkout}"* ]]
  [ ! -s "${trusted}" ]
}

@test "outside a clone, a folder with no kit.yml is asked nothing, and names nothing kit trust could record" {
  mkdir "${BATS_TEST_TMPDIR}/plain"
  cd "${BATS_TEST_TMPDIR}/plain"
  run "${kit}" kinds x
  [[ "$output" != *"until you trust it"* ]]
  run "${kit}" trust --check
  [ "$status" -eq 2 ]
  [[ "$output" == *"is in no clone and holds no kit.yml"* ]]
  [ ! -s "${trusted}" ]
}

@test "outside a clone, a folder that holds a kit.yml is held to a trust record of its own: none of its code runs before it" {
  # a forge's Download ZIP, or a source tarball, unpacked: a kit.yml, and no .git at or above it
  folder="${BATS_TEST_TMPDIR}/unpacked"
  mkdir -p "${folder}/mods" "${folder}/bin" "${folder}/below"
  cd "${folder}"
  folder=$(pwd -P)
  printf 'gate: bin/ci\nbash_path:\n  - kit:modules/bash/\n  - mods\n' > kit.yml
  for module in gate help release syntax trust yaml
  do
    printf 'printf "%%s\\n" %s >> "%s/ran"\n' "${module}" "${BATS_TEST_TMPDIR}" > "mods/${module}.sh"
  done
  printf '#!/bin/sh\n: > "%s/gated"\n' "${BATS_TEST_TMPDIR}" > bin/ci
  chmod +x bin/ci
  # the verbs that run before the trust run on the release's own modules
  run "${kit}" version
  [ "$status" -eq 0 ]
  [ "$output" = unreleased ]
  run "${kit}" help --text
  [ "$status" -eq 0 ]
  run "${kit}" syntax commit
  [ "$status" -eq 0 ]
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  [ "$output" = "${folder}" ]
  run "${kit}" trust --asks </dev/null
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'load bash into every kit command from mods (bash_path)' ]
  [ "${lines[1]}" = 'run bin/ci for kit gate (gate)' ]
  run bash -c 'source "$1/modules/bash/1st.sh" && use:path' _ "${kit_checkout}"
  [ "$status" -eq 0 ]
  [ "$output" = "${kit_checkout}/modules/bash" ]
  # every other verb is refused, by the loader and by the verb
  run "${kit}" gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in ${folder} until you trust it; see what it asks kit to run, and trust it: kit trust"* ]]
  run "${kit_checkout}/bin/kit-gate"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in ${folder} until you trust it"* ]]
  run "${kit}" trust </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"${folder} asks kit to:"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  [ ! -e "${BATS_TEST_TMPDIR}/gated" ]
  [ ! -s "${trusted}" ]
  # below it kit reads nothing of the folder, so there is nothing to ask about
  run bash -c 'cd below && "$0" kinds x' "${kit}"
  [[ "$output" != *"until you trust it"* ]]
  run bash -c 'cd below && "$0" trust --check' "${kit}"
  [ "$status" -eq 2 ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  # trusted, by its own path and the digest of what it asks, it runs what it asked
  run "${kit}" trust --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"kit trusts ${folder}, while it asks kit to run the same"* ]]
  recorded "${folder}"
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  run "${kit}" gate
  [ "$status" -eq 0 ]
  [ -e "${BATS_TEST_TMPDIR}/gated" ]
  grep --quiet --line-regexp gate "${BATS_TEST_TMPDIR}/ran"
  # it is asked again when it comes to ask something new, and --revoke takes the trust back
  printf 'gate: bin/other\n' > kit.yml
  run "${kit}" gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"${folder} asks kit to run something new since you trusted it"* ]]
  run "${kit}" trust --revoke
  [ "$status" -eq 0 ]
  run "${kit}" gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in ${folder} until you trust it"* ]]
}

@test "outside a clone, a folder that holds .kit/settings.yml, which kit moves to kit.yml, is held to the same trust, and nothing moves before it" {
  folder="${BATS_TEST_TMPDIR}/earlier"
  mkdir -p "${folder}/.kit" "${folder}/mods"
  cd "${folder}"
  printf 'bash_path:\n  - kit:modules/bash/\n  - mods\n' > .kit/settings.yml
  printf ': > "%s/ran"\n' "${BATS_TEST_TMPDIR}" > mods/help.sh
  run "${kit}" kinds x
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it"* ]]
  run "${kit_checkout}/bin/kit-kinds" x
  [ "$status" -eq 1 ]
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  run "${kit}" trust --asks
  [ "$output" = 'load bash into every kit command from mods (bash_path)' ]
  [ ! -e kit.yml ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "a .kit/settings.yml kit would move to kit.yml is judged and shown as the kit.yml it becomes: a pull that brings one asks again before anything moves" {
  "${kit}" trust --yes
  # a pull brings the settings of an earlier release into a clone with no kit.yml
  mkdir -p .kit mods bin
  printf '# yaml-language-server: $schema=settings.schema.json\ngate: bin/ci\nbash_path:\n  - kit:modules/bash/\n  - mods\n' \
    > .kit/settings.yml
  printf ': > "%s/sourced"\n' "${BATS_TEST_TMPDIR}" > mods/settings.sh
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  run "${kit}" kinds x
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(pwd -P) asks kit to run something new since you trusted it"* ]]
  run "${kit_checkout}/bin/kit-kinds" x
  [ "$status" -eq 1 ]
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  [ ! -e kit.yml ]
  [ ! -e "${BATS_TEST_TMPDIR}/sourced" ]
  # kit trust shows what the file names, and the move, which changes the modeline alone, keeps the trust
  run "${kit}" trust --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"  - load bash into every kit command from mods (bash_path)"* ]]
  [[ "$output" == *"  - run bin/ci for kit gate (gate)"* ]]
  run "${kit}" kinds x
  [[ "$output" == *"kit.yml: the settings moved here from .kit/settings.yml"* ]]
  [ -e "${BATS_TEST_TMPDIR}/sourced" ]
  [ "$(sed -n '1p' kit.yml)" = '# yaml-language-server: $schema=.kit/kit.schema.json' ]
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  # beside a kit.yml, kit reads nothing of .kit/settings.yml, and neither does the trust
  printf 'gate: bin/other\n' > .kit/settings.yml
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
}

@test "the loader and modules/bash/1st.sh hold one awk program for what a clone asks kit to run" {
  loader=$(sed -n "/^trust_text='\$/,/^'\$/p" "${kit_checkout}/bin/kit" | sed 1d)
  module=$(sed -n "/^kit_trust_text='\$/,/^'\$/p" "${kit_checkout}/modules/bash/1st.sh" | sed 1d)
  [ -n "${loader}" ]
  [ "${loader}" = "${module}" ]
}

@test "a release .kit/settings.yml pins, where there is no kit.yml, is the one kit trust shows and the loader runs" {
  own-kit
  mkdir .kit
  mv kit.yml .kit/settings.yml
  run "${kit}" trust --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"  - run its own kit, kit/ in the clone, for every kit command there (version: unreleased)"* ]]
  run "${kit}" kinds x
  [ -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "a clone you have not trusted runs none of its own code: not its kit/, not a release it names, not its bash_path" {
  own-kit
  printf 'version: unreleased\nbash_path:\n  - kit:modules/bash/\n  - lib/bash/\n' > kit.yml
  mkdir -p lib/bash
  printf ': > "%s/sourced"\n' "${BATS_TEST_TMPDIR}" > lib/bash/help.sh
  run "${kit}" version
  [ "$output" = unreleased ]
  run "${kit}" help
  [ "$status" -eq 0 ]
  run "${kit}" --version=9.9.9 version
  [ "$output" = unreleased ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  [ ! -e "${BATS_TEST_TMPDIR}/sourced" ]
}

@test "a clone whose git config names a work tree beside it runs none of that folder's code: kit works in the root it judged" {
  # .git/config is the clone's own: git clone delivers none, an unpacked archive or a synced folder does
  beside="${BATS_TEST_TMPDIR}/beside"
  mkdir -p "${beside}/mods" sub
  printf 'bash_path:\n  - kit:modules/bash/\n  - mods\n' > "${beside}/kit.yml"
  for module in help release syntax trust
  do
    printf 'printf "%%s\\n" %s >> "%s/ran"\n' "${module}" "${BATS_TEST_TMPDIR}" > "${beside}/mods/${module}.sh"
  done
  git config core.worktree "${beside}"
  [ "$(git rev-parse --show-toplevel)" = "$(cd "${beside}" && pwd -P)" ]
  root=$(pwd -P)
  run "${kit}" version
  [ "$status" -eq 0 ]
  [ "$output" = unreleased ]
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  run "${kit}" trust --asks </dev/null
  [ "$status" -eq 0 ]
  run "${kit}" trust </dev/null
  [ "$status" -eq 1 ]
  run "${kit}" syntax commit
  [ "$status" -eq 0 ]
  run "${kit}" help --text
  [ "$status" -eq 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  # the verb, and a script that sources the loader below the root, each stand in and read the root kit judged
  run bash -c 'cd sub && source "$1/modules/bash/1st.sh" && kit:enter --any-clone && pwd -P' _ "${kit_checkout}"
  [ "$status" -eq 0 ]
  [ "$output" = "${root}" ]
  run bash -c 'cd sub && source "$1/modules/bash/1st.sh" && use:path' _ "${kit_checkout}"
  [ "$status" -eq 0 ]
  [ "$output" = "${kit_checkout}/modules/bash" ]
  # trusted, the clone's own kit.yml is the one read, not the folder's
  "${kit}" trust --yes
  run "${kit}" version
  [ "$status" -eq 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  # in no clone, a folder that git reads as a repository names a work tree the same way: kit stays where it was typed
  plain="${BATS_TEST_TMPDIR}/plain/looks-bare"
  git init --quiet --bare "${plain}"
  git -C "${plain}" config core.bare false
  git -C "${plain}" config core.worktree "${beside}"
  cd "${plain}"
  [ "$(git rev-parse --show-toplevel)" = "$(cd "${beside}" && pwd -P)" ]
  run "${kit}" version
  [ "$status" -eq 0 ]
  [ "$output" = unreleased ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  run bash -c 'source "$1/modules/bash/1st.sh" && kit:enter --any-clone && pwd -P' _ "${kit_checkout}"
  [ "$output" = "$(pwd -P)" ]
}

@test "kit trust shows what the clone asks kit to run, and with no terminal and no --yes records nothing" {
  own-kit
  printf 'version: unreleased\ngate: bin/ci\nbash_path:\n  - kit:modules/bash/\n  - lib/bash/\nsources:\n  - name: house\n    url: https://example.com/house.git\n' > kit.yml
  run "${kit}" trust </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(pwd -P) asks kit to:"* ]]
  [[ "$output" == *"  - run its own kit, kit/ in the clone, for every kit command there (version: unreleased)"* ]]
  [[ "$output" == *"  - load bash into every kit command from lib/bash/ (bash_path)"* ]]
  [[ "$output" == *"  - run bin/ci for kit gate (gate)"* ]]
  [[ "$output" == *"  - bring packages from the source house (sources)"* ]]
  [ ! -s "${trusted}" ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "with no terminal, kit trust says the trust is a person's to give, and never names the option that gives it unasked" {
  run "${kit}" trust </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"there is no terminal to ask, and the trust is a person's to give; ask them to run: cd "*" && kit trust $(pwd -P)" ]]
  [[ "$output" != *--yes* ]]
  [[ "$output" != *"kit help trust"* ]]
  # on a runner, where a job trusts its own checkout, it points at the page that says how, and still names no option
  run env GITHUB_ACTIONS=true "${kit}" trust </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"ask them to run: cd "*" && kit trust $(pwd -P); a job on a runner trusts its own checkout, as kit help trust says"* ]]
  [[ "$output" != *--yes* ]]
  for marker in GITLAB_CI TF_BUILD
  do
    run env "${marker}=true" "${kit}" trust </dev/null
    [[ "$output" == *"as kit help trust says"* ]]
  done
  [ ! -s "${trusted}" ]
}

@test "kit trust --yes records the clone, and kit runs there then, its own kit/ included" {
  run "${kit}" trust --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"asks kit to run nothing beyond the kit itself"* ]]
  [[ "$output" == *"kit trusts $(pwd -P), and every worktree of it"* ]]
  recorded "$(pwd -P)"
  run "${kit}" trust --yes
  [[ "$output" == *"kit trusts $(pwd -P) already"* ]]
  [ "$(wc -l < "${trusted}")" -eq 1 ]
  own-kit
  "${kit}" trust --yes
  run "${kit}" check
  [ -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "a worktree is trusted with its desk, wherever the worktree is" {
  git commit --quiet --allow-empty --message init
  git worktree add --quiet "${BATS_TEST_TMPDIR}/away" -b away
  run bash -c 'cd "$1" && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 1 ]
  [ "$output" = "$(pwd -P)" ]
  "${kit}" trust --yes
  run bash -c 'cd "$1" && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 0 ]
  run bash -c 'cd "$1" && "$0" kinds x' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [[ "$output" != *"until you trust it"* ]]
}

@test "a .git file the desk does not confirm borrows none of its trust: a worktree of its own, or a name made up" {
  git commit --quiet --allow-empty --message init
  git worktree add --quiet "${BATS_TEST_TMPDIR}/real" -b real
  "${kit}" trust --yes
  desk=$(pwd -P)
  mkdir "${BATS_TEST_TMPDIR}/spoof"
  printf 'gitdir: %s/.git/worktrees/real\n' "${desk}" > "${BATS_TEST_TMPDIR}/spoof/.git"
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/spoof"
  [ "$status" -eq 1 ]
  [ "$output" = "$(cd "${BATS_TEST_TMPDIR}/spoof" && pwd -P)" ]
  run bash -c 'cd "$1" && "$0" check' "${kit}" "${BATS_TEST_TMPDIR}/spoof"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit runs nothing in $(cd "${BATS_TEST_TMPDIR}/spoof" && pwd -P) until you trust it"* ]]
  printf 'gitdir: %s/.git/worktrees/made-up\n' "${desk}" > "${BATS_TEST_TMPDIR}/spoof/.git"
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/spoof"
  [ "$status" -eq 1 ]
  # an admin directory of the clone's own making, which names the clone back and the desk as its common dir
  mkdir -p "${BATS_TEST_TMPDIR}/spoof/admin/x"
  printf '%s/.git\n' "$(cd "${BATS_TEST_TMPDIR}/spoof" && pwd -P)" > "${BATS_TEST_TMPDIR}/spoof/admin/x/gitdir"
  printf '%s/.git\n' "${desk}" > "${BATS_TEST_TMPDIR}/spoof/admin/x/commondir"
  printf 'gitdir: admin/x\n' > "${BATS_TEST_TMPDIR}/spoof/.git"
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/spoof"
  [ "$status" -eq 1 ]
  [ "$output" = "$(cd "${BATS_TEST_TMPDIR}/spoof" && pwd -P)" ]
  run bash -c 'cd "$1" && "$0" check' "${kit}" "${BATS_TEST_TMPDIR}/spoof"
  [ "$status" -eq 1 ]
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/real"
  [ "$status" -eq 0 ]
  [ "$output" = "${desk}" ]
}

@test "a folder ending in / trusts every clone under it, and none beside it" {
  mkdir -p "${BATS_TEST_TMPDIR}/code/a" "${BATS_TEST_TMPDIR}/codex"
  git init --quiet "${BATS_TEST_TMPDIR}/code/a/one"
  git init --quiet "${BATS_TEST_TMPDIR}/codex/two"
  run "${kit}" trust --yes "${BATS_TEST_TMPDIR}/code/"
  [ "$status" -eq 0 ]
  [[ "$output" == *"trusts every clone under it"* ]]
  [ "$(cat "${trusted}")" = "$(cd "${BATS_TEST_TMPDIR}/code" && pwd -P)/" ]
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/code/a/one"
  [ "$status" -eq 0 ]
  run "${kit}" trust --check "${BATS_TEST_TMPDIR}/codex/two"
  [ "$status" -eq 1 ]
}

@test "the trust file takes comments, blank lines, and ~/ for the home directory" {
  mkdir -p "${HOME}/src"
  git init --quiet "${HOME}/src/mine"
  printf '# mine\n\n~/src/\n' > "${trusted}"
  run "${kit}" trust --check "${HOME}/src/mine"
  [ "$status" -eq 0 ]
  run "${kit}" trust --list
  [ "$output" = "~/src/" ]
}

@test "kit trust --revoke takes the trust back, says when there is none, and warns when a folder still holds the clone" {
  "${kit}" trust --yes
  run "${kit}" trust --revoke
  [ "$status" -eq 0 ]
  [[ "$output" == *"kit no longer trusts $(pwd -P)"* ]]
  run "${kit}" check
  [ "$status" -eq 1 ]
  run "${kit}" trust --revoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit trust holds no record of $(pwd -P)"* ]]
  printf '%s/\n%s\n' "$(cd .. && pwd -P)" "$(pwd -P)" > "${trusted}"
  run "${kit}" trust --revoke
  [[ "$output" == *"a folder you trust still holds $(pwd -P)"* ]]
}

@test "kit trust runs on the installed kit in a trusted clone too, so a clone of its own kit cannot keep its trust" {
  own-kit
  "${kit}" trust --yes
  rm -f "${BATS_TEST_TMPDIR}/ran"
  run "${kit}" trust --list
  [ "$output" = "$(pwd -P)" ]
  run "${kit}" trust --revoke
  [ "$status" -eq 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "kit.yml names a release by its version alone, even in a clone you trust; a path only --version= names" {
  later-release "${BATS_TEST_TMPDIR}/elsewhere" 9.9.7
  printf 'version: %s\n' "${BATS_TEST_TMPDIR}/elsewhere" > kit.yml
  "${kit}" trust --yes
  run "${kit}" version
  [ "$status" -eq 1 ]
  [[ "$output" == *"kit.yml names a release by its version, and a path only --version= or KIT_VERSION names"* ]]
  run "${kit}" --version="${BATS_TEST_TMPDIR}/elsewhere" version
  [ "$output" = 9.9.7 ]
}

@test "a clone that comes to ask kit to run something new is asked again; a change to anything else keeps its trust" {
  printf 'gate: bin/ci\npackages:\n  - kit\n' > kit.yml
  "${kit}" trust --yes
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  # what names no command: the packages, a README, the gate's own script
  printf 'gate: bin/ci\npackages:\n  - kit\n  - workflow\nanswers:\n  x: "1"\n' > kit.yml
  mkdir bin && printf '#!/bin/sh\n' > bin/ci && printf 'hello\n' > README.md
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  run "${kit}" kinds x
  [[ "$output" != *"since you trusted it"* ]]
  # a new gate, by a key written in quotes too
  printf '"gate": bin/other\npackages:\n  - kit\n' > kit.yml
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  [ "$output" = "$(pwd -P)" ]
  run "${kit}" kinds x
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(pwd -P) asks kit to run something new since you trusted it; see what it asks, and trust it again: kit trust"* ]]
  run "${kit_checkout}/bin/kit-kinds" x
  [ "$status" -eq 1 ]
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  run "${kit}" trust --yes
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  # a lint: command in a rule, and in a rule of the clone's own package
  mkdir -p .kit/rules
  printf -- '---\nkind:\n  - text\nlint: touch %s/linted\n---\n# Text\n' "${BATS_TEST_TMPDIR}" > .kit/rules/text.md
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  "${kit}" trust --yes
  printf '# Text\n\nAnother line of prose.\n' >> .kit/rules/text.md
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  mkdir -p .kit/packages/local/files/repo/.kit/styles
  printf -- '---\nkind:\n  - text\nlint: rm -rf /\n---\n' > .kit/packages/local/files/repo/.kit/styles/text.md
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  # a version kit.yml no longer names, which .kit/manifest names in its place
  rm -rf .kit/packages
  "${kit}" trust --yes
  printf 'version 9.9.9\n' > .kit/manifest
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
}

@test "a trusted clone that comes to pin its own kit/ is asked again before the loader runs it" {
  "${kit}" trust --yes
  own-kit
  run "${kit}" kinds x
  [ "$status" -eq 1 ]
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  run answering y "'${kit}' kinds x"
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  [[ "$output" == *"Trust $(pwd -P)? [y/N]"* ]]
  [ -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "a line of a clone's path alone, as kit trust wrote before it kept the digest, trusts it no more; kit trust --yes writes the digest in its place" {
  printf '%s\n' "$(pwd -P)" > "${trusted}"
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  run "${kit}" kinds x
  [[ "$output" == *"asks kit to run something new since you trusted it"* ]]
  "${kit}" trust --yes
  recorded "$(pwd -P)"
  run "${kit}" trust --list
  [ "$output" = "$(pwd -P)" ]
}

@test "two worktrees that ask different things each keep a line of their own, and --revoke takes every line back" {
  git commit --quiet --allow-empty --message init
  git worktree add --quiet "${BATS_TEST_TMPDIR}/away" -b away
  printf 'gate: bin/ci\n' > "${BATS_TEST_TMPDIR}/away/kit.yml"
  "${kit}" trust --yes
  run bash -c 'cd "$1" && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 1 ]
  run bash -c 'cd "$1" && "$0" trust --yes' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${trusted}")" -eq 2 ]
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  run bash -c 'cd "$1" && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 0 ]
  run "${kit}" trust --list
  [ "$output" = "$(pwd -P)" ]
  run "${kit}" trust --revoke
  [ "$status" -eq 0 ]
  [ ! -s "${trusted}" ]
}

@test "kit trust --asks prints what the clone asks, its tools and every lint: command once, and asks nothing" {
  printf 'gate: bin/ci\ntools:\n  jq:\n    version: "1.8.2"\n  yq:\n    version: "4.54.1"\n' > kit.yml
  mkdir -p .kit/rules .kit/styles .kit/packages/local/files/repo/.kit/rules
  printf -- '---\nkind:\n  - bash\nlint: shellcheck --shell=bash\n---\n' > .kit/rules/bash.md
  printf -- '---\nkind:\n  - bash\nlint: shellcheck --shell=bash\n---\n' > .kit/packages/local/files/repo/.kit/rules/bash.md
  printf -- '---\nkind:\n  - text\n---\n' > .kit/styles/text.md
  run "${kit}" trust --asks </dev/null
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'run bin/ci for kit gate (gate)' ]
  [ "${lines[1]}" = 'download and run the tools it pins, from the URLs it names: jq, yq (tools)' ]
  [ "${lines[2]}" = 'run shellcheck --shell=bash for kit lint (lint: in .kit/rules/bash.md)' ]
  [ "${#lines[@]}" -eq 3 ]
  [ ! -s "${trusted}" ]
  run "${kit}" trust --asks "${BATS_TEST_TMPDIR}/"
  [ "$status" -eq 2 ]
}

@test "kit trust shows the release the loader will run, read as the loader reads it: kit.yml's first version: line, then .kit/manifest" {
  own-kit
  rm kit.yml
  mkdir .kit
  printf 'version unreleased\n' > .kit/manifest
  own='run its own kit, kit/ in the clone, for every kit command there (version in .kit/manifest: unreleased)'
  # no kit.yml, and a manifest that records unreleased: the clone's own kit/
  run "${kit}" trust --asks
  [ "$status" -eq 0 ]
  [ "$output" = "${own}" ]
  # a version the loader does not read, a key in quotes or in a flow mapping, leaves the manifest's
  printf '"version": 9.9.9\n' > kit.yml
  run "${kit}" trust --asks
  [ "$output" = "${own}" ]
  printf '{version: 9.9.9}\n' > kit.yml
  run "${kit}" trust --asks
  [ "$output" = "${own}" ]
  run "${kit}" trust --yes
  [[ "$output" == *"  - ${own}"* ]]
  run "${kit}" kinds x
  [ -e "${BATS_TEST_TMPDIR}/ran" ]
  rm "${BATS_TEST_TMPDIR}/ran"
  # the digest holds both lines the loader reads: a change to either asks again
  printf '{version: 9.9.8}\n' > kit.yml
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  "${kit}" trust --yes
  printf 'version 9.9.8\n' > .kit/manifest
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  # a key written twice: the first line, which the loader takes, on one line
  later-release "${XDG_CACHE_HOME}/kit/kit-9.9.9" 9.9.9
  printf 'version: 9.9.9\nversion: unreleased\n' > kit.yml
  run "${kit}" trust --asks
  [ "$output" = 'run kit 9.9.9, downloaded from its release and checked against its digest (version: 9.9.9)' ]
  "${kit}" trust --yes
  run "${kit}" version
  [ "$output" = 9.9.9 ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  # outside a clone the loader runs the kit you installed, whatever a kit.yml there names, and kit trust shows none
  mkdir "${BATS_TEST_TMPDIR}/unpacked"
  cd "${BATS_TEST_TMPDIR}/unpacked"
  printf 'version: 9.9.9\n' > kit.yml
  run "${kit}" trust --asks
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  "${kit}" trust --yes
  run "${kit}" version
  [ "$output" = unreleased ]
}

@test "a clone that declares unreleased is shown to run its own kit/ before it holds one, so a pull that brings one runs what you were shown" {
  printf 'version: unreleased\n' > kit.yml
  run "${kit}" trust --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"  - run its own kit, kit/ in the clone, for every kit command there, once the clone holds one (version: unreleased)"* ]]
  own-kit
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  run "${kit}" trust --asks
  [ "$output" = 'run its own kit, kit/ in the clone, for every kit command there (version: unreleased)' ]
  run "${kit}" kinds x
  [ -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "each line of what a clone asks holds one value whole: a newline or a control character in a value starts no line of its own" {
  printf 'gate: |\n  bin/ci\n  run nothing else\n' > kit.yml
  mkdir -p .kit/rules
  printf -- '---\nkind:\n  - text\nlint: "true\\n\\e[2Krun nothing"\n---\n' > .kit/rules/text.md
  run "${kit}" trust --asks
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = 'run bin/ci\nrun nothing else for kit gate (gate)' ]
  [ "${lines[1]}" = 'run true\n?[2Krun nothing for kit lint (lint: in .kit/rules/text.md)' ]
}

@test "in a clone you have not trusted, every git command a verb runs there ignores the clone's hooks and fsmonitor" {
  git commit --quiet --allow-empty --message init
  printf '#!/bin/sh\n: > "%s/fsmonitor"\n' "${BATS_TEST_TMPDIR}" > "${BATS_TEST_TMPDIR}/monitor"
  chmod +x "${BATS_TEST_TMPDIR}/monitor"
  git config core.fsmonitor "${BATS_TEST_TMPDIR}/monitor"
  touch file
  run bash -c 'source "$1/modules/bash/1st.sh" && kit:enter --any-clone && git config core.hooksPath &&
    git config protocol.allow && printf "%s\n" "${GIT_TERMINAL_PROMPT}" && git status --porcelain' _ "${kit_checkout}"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = /dev/null ]
  [ "${lines[1]}" = never ]
  [ "${lines[2]}" = 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/fsmonitor" ]
  "${kit}" trust --yes
  run bash -c 'source "$1/modules/bash/1st.sh" && kit:enter --any-clone && git config core.hooksPath' _ "${kit_checkout}"
  [ "$status" -eq 1 ]
}

@test "what kit places keeps the trust: an install that writes the version, a worktree that has none of it yet, a clean" {
  "${kit}" trust --yes
  run "${kit}" install agents/claude
  [ "$status" -eq 0 ]
  [ -f .kit/rules/bash.md ]
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  git add kit.yml && git commit --quiet --message init
  git worktree add --quiet "${BATS_TEST_TMPDIR}/away" -b away
  [ ! -e "${BATS_TEST_TMPDIR}/away/.kit/rules" ]
  run bash -c 'cd "$1" && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 0 ]
  run bash -c 'cd "$1" && "$0" hydrate && "$0" trust --check' "${kit}" "${BATS_TEST_TMPDIR}/away"
  [ "$status" -eq 0 ]
  [ -f "${BATS_TEST_TMPDIR}/away/.kit/rules/bash.md" ]
  rm -rf .kit/rules
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  "${kit}" hydrate >/dev/null 2>&1
  # a rule a pull brings, with its write bit, as git checks it out, is the clone's
  printf -- '---\nkind:\n  - bash\nlint: touch %s/linted\n---\n' "${BATS_TEST_TMPDIR}" > .kit/rules/stray.md
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  rm .kit/rules/stray.md
  # and so is a link a pull brings, which a .kit/.gitignore of kit's own does not name
  ln -s ../../README.md .kit/rules/stray.md
  printf -- '---\nlint: touch x\n---\n' > README.md
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
  # a link kit's own .kit/.gitignore names, without its write bit, is kit's; one with its write bit, as a pull brings,
  # names nothing kit placed
  chmod u+w .kit/.gitignore && printf '/rules/stray.md\n' >> .kit/.gitignore && chmod a-w .kit/.gitignore
  run "${kit}" trust --check
  [ "$status" -eq 0 ]
  chmod u+w .kit/.gitignore
  run "${kit}" trust --check
  [ "$status" -eq 1 ]
}

@test "on a terminal, bare kit and kit tui run kittui in a clone you have not trusted, which asks itself" {
  # the fake go and the fake kittui first on PATH, as tests/flow.bats puts them: kit builds kittui with the fake go,
  # and it prints "kittui native-native" and its arguments
  mkdir -p "${BATS_TEST_TMPDIR}/fake"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-kittui" "${BATS_TEST_TMPDIR}/fake/kittui"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-go" "${BATS_TEST_TMPDIR}/fake/go"
  export FAKES="${BATS_TEST_TMPDIR}/fake" PATH="${BATS_TEST_TMPDIR}/fake:${PATH}"
  own-kit
  run pty "'${kit}'"
  [[ "$output" == *"kittui native-native"* ]]
  [[ "$output" != *"until you trust it"* ]]
  run pty "'${kit}' tui -- commit"
  [[ "$output" == *"kittui native-native -- commit"* ]]
  [ ! -s "${trusted}" ]
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
}

@test "kit syntax runs in a clone you have not trusted, on the installed kit, reading its verbs alone, and asks nothing" {
  own-kit
  printf '#!/bin/sh\n: > "%s/ran"\n' "${BATS_TEST_TMPDIR}" > kit/bin/kit-clonefake
  chmod +x kit/bin/kit-clonefake
  printf 'version: unreleased\nbash_path:\n  - kit:modules/bash/\n  - lib/bash/\n' > kit.yml
  mkdir -p lib/bash
  printf ': > "%s/sourced"\n' "${BATS_TEST_TMPDIR}" > lib/bash/syntax.sh
  run "${kit}" syntax --list </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\ntrust\t'* ]]
  [[ "$output" != *clonefake* ]]
  run "${kit}" syntax version </dev/null
  [ "$status" -eq 0 ]
  [ "$(jq -r .verb <<<"$output")" = version ]
  run "${kit_checkout}/bin/kit-syntax" version
  [ "$status" -eq 0 ]
  # what runs what a verb asks to answer refuses, as every other verb does
  for form in --choices=--rule --extend --match
  do
    run "${kit}" syntax new "${form}" </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"kit runs nothing in $(pwd -P) until you trust it"* ]]
  done
  [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
  [ ! -e "${BATS_TEST_TMPDIR}/sourced" ]
  [ ! -s "${trusted}" ]
  # in a clone you trust, it answers what a verb asks, as before
  "${kit}" trust --yes
  run "${kit}" syntax version --match
  [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------------------------------------------------------
