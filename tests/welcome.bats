#!/usr/bin/env bats
# welcome.bats - kit welcome: its steps, its checks as JSON, their fixes, the text guide, and the hand-off to kittui
# ----------------------------------------------------------------------------------------------------------------------
# Each test runs in a fresh repository, with no toolchain file unless the test writes one: its tools are ambient. The
# tools a check looks for are fakes in a directory first on PATH: a failing stand-in hides a real tool. A fake brew
# is there too, so brew is the machine's package manager on any machine; a test that needs none chooses ambient for it.

bats_require_minimum_version 1.5.0

load helper

setup() {
  hide-system-toolchains
  fresh-repo >/dev/null
  fakes="${BATS_TEST_TMPDIR}/fakes"
  mkdir -p "${fakes}"
  # brew is found, so it is the machine's package manager; it is never run, except for --prefix where a test asks
  fake-script brew 'exit 1'
  export PATH="${fakes}:${PATH}"
  # the terminal these tests run in is not judged; a test that wants a terminal's checks sets what it needs
  unset KIT_TERMINAL_PROBES TMUX STY ZELLIJ SSH_CONNECTION SSH_TTY TERM_PROGRAM ITERM_PROFILE KITTY_PID WT_SESSION
}

# fake-script <tool> <body> writes a bash script named <tool> into the fakes directory, first on PATH.
fake-script() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "${fakes}/$1"
  chmod +x "${fakes}/$1"
}

# checks prints the checks as JSON, from kit welcome --checks --json.
checks() {
  "${kit_root}/bin/kit" welcome --checks --json
}

# check <id> prints one check of kit welcome --checks --json.
check() {
  checks | jq --compact-output --arg id "$1" '.[] | select(.id == $id)'
}

# fake-gh writes a gh that runs, and is logged in to github.com once its login has run: auth login touches a file,
# and auth status succeeds while the file is there. Every call is recorded in gh.calls. With LOGIN_FAILS set, the
# login changes nothing.
fake-gh() {
  # shellcheck disable=SC2016  # a fake's body expands when it runs
  fake-script gh '
printf "%s\n" "$*" >> "${BATS_TEST_TMPDIR}/gh.calls"
case "$*" in
  ("--version") echo "gh version 2.103.2" ;;
  ("auth status --hostname github.com") [[ -f "${BATS_TEST_TMPDIR}/logged-in" ]] ;;
  ("auth login --hostname github.com") [[ -n "${LOGIN_FAILS:-}" ]] || touch "${BATS_TEST_TMPDIR}/logged-in" ;;
  (*) exit 1
esac'
}

# outline prints the outline of the text guide on stdin: each page's heading, up to its dash, and ✅ or ❌ for each
# check, a run of the same glyph once.
outline() {
  grep --extended-regexp '^(# |✅|💡|❌)' | sed -E 's/^(✅|💡|❌).*/\1/; s/ — .*//' | uniq | paste -s -d '|' -
}

# under prints "<heading>|<glyph> <word>" for each check in the text guide on stdin: the heading of the page above
# it, up to its dash, and the check's glyph and first word.
under() {
  awk '/^# / { heading = $0; sub(/ — .*/, "", heading) } /^(✅|💡|❌)/ { print heading "|" $1 " " $2 }'
}

# ambient-system chooses ambient for the system role, so no toolchain names a command for a missing tool.
ambient-system() {
  "${kit_root}/bin/kit" toolchains use ambient --system >/dev/null 2>&1
}

@test "the checks are a JSON array, in order, each with its fix and its folder, which is null for the machine's" {
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '[.[] | keys | sort == ["branch", "desk", "fix", "folder", "id", "interactive", "kit", "line",
    "more", "ok", "repository", "runs", "step"]] | all' <<<"$output")" = true ]
  [ "$(jq --raw-output 'map(.id) | (unique | length) == length' <<<"$output")" = true ]
  # the machine's checks, what kit runs on and the machine's package manager, then this repository's one folder, the
  # desk; no kit.yml here, so no check of what kit installs, and the install is offered: the check holds, with its fix
  [ "$(jq --raw-output '.[] | "\(.id) \(.step)"' <<<"$output")" = "$(printf '%s\n' 'tool-bash toolchains' \
    'tool-git toolchains' 'tool-jq toolchains' 'tool-yq toolchains' 'toolchain-system toolchains' \
    'repo-git setup' 'kit-installed setup' 'toolchain-project setup')" ]
  [ "$(jq --raw-output '.[] | select(.id == "kit-installed") | [.ok, .fix] | @tsv' <<<"$output")" = \
    $'true\tkit install' ]
  # a machine check holds nowhere in particular; a folder's names the folder, the desk, on main, with no kit
  [ "$(jq --compact-output '.[] | select(.id == "tool-git") | [.folder, .repository, .desk, .branch, .kit]' \
    <<<"$output")" = '[null,null,null,null,null]' ]
  [ "$(jq --compact-output '[.[] | select(.folder) | [.folder, .repository, .desk, .branch, .kit]] | unique' \
    <<<"$output")" = "$(jq --null-input --compact-output --arg f "$(pwd -P)" '[[$f, "repo", true, "main", null]]')" ]
}

@test "--progress says on stderr each check as it starts, and the end of the machine's and of each folder's" {
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --json --progress
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output 'length' <<<"$output")" -eq 8 ]
  [ "$stderr" = "$(printf '⏳ checking %s\n' tool-bash tool-git tool-jq tool-yq toolchain-system
    printf '⏳ checked\n'
    printf '⏳ checking %s in '"$(pwd -P)"'\n' repo-git kit-installed toolchain-project
    printf '⏳ checked %s' "$(pwd -P)")" ]
  # without it, the checks say nothing on stderr
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  # it goes with --checks alone
  run --separate-stderr "${kit_root}/bin/kit" welcome --text --progress
  [ "$status" -eq 2 ]
}

@test "welcome's steps are introduction, toolchains, setup, customize, terms" {
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  # kit is not installed here, which kit offers to change, and no check fails
  [ "$status" -eq 0 ]
  # each step's page in order, the checks of steps 2 and 3 under their pages, then what is left
  [ "$(outline <<<"$output")" = "$(printf '%s|' '# Introduction' '# Toolchains' ✅ '# Setup' \
    ✅ 💡 ✅ '# Customize' '# Terms' '# What is left' | sed 's/|$//')" ]
  # bash, git, jq, and yq, then the machine's package manager, then the desk's checks, under a line that names it
  [ "$(under <<<"$output")" = "$(printf '%s\n' '# Toolchains|✅ bash' '# Toolchains|✅ git' \
    '# Toolchains|✅ jq' '# Toolchains|✅ yq' '# Toolchains|✅ brew' \
    '# Setup|✅ this' '# Setup|💡 kit' '# Setup|✅ no')" ]
  [[ "$output" == *$'\n'"repo, the desk on main, no kit: $(pwd -P)"$'\n✅ this folder is a git repository\n'* ]]
}

@test "the pages an agent or a newcomer reads first say agent, not harness, adapter, or a draft's stand-in" {
  local page
  for page in "${kit_root}/packages/kit/files/repo/.kit/1st.md" "${kit_root}/packages/kit/files/repo/.kit/welcome/"*.md \
    "${kit_root}/packages/workflow/files/repo/.kit/workflow.md"
  do
    run -1 grep --ignore-case --quiet --extended-regexp "harness|adapter|stand-in" "${page}"
  done
}

@test "the workflow lists kit ready among its commands, says how to file an issue and what no gate means" {
  grep --quiet 'kit ready' "${kit_root}/packages/kit/files/repo/.kit/1st.md"
  run -1 grep --quiet 'exactly as written' "${kit_root}/packages/kit/files/repo/.kit/1st.md"
  grep --quiet 'kit work --title=<text>' "${kit_root}/packages/workflow/files/repo/.kit/workflow.md"
  grep --quiet 'report "no gate"' "${kit_root}/packages/workflow/files/repo/.kit/workflow.md"
}

@test "no line of a page kit ships starts with ✅, 💡, or ❌, which in the text guide starts a check" {
  # The text guide prints a page's lines and its step's checks one after the other, so its readers, outline and under
  # here among them, take a line that starts with a check's glyph for a check. The pages are every package's.
  pages=$(find "${kit_root}/packages" -path '*/files/repo/.kit/welcome/*.md')
  [ "$(grep --count . <<<"${pages}")" -ge 5 ]
  while IFS= read -r page
  do
    run bash -c 'source "${kit_root}/modules/bash/1st.sh" && use welcome && welcome:page "$1"' _ "${page}"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    run grep --line-number --extended-regexp '^(✅|💡|❌)' <<<"$output"
    [ "$status" -eq 1 ] || { echo "${page#"${kit_root}/"} starts a line with a check's glyph: ${output}"; false; }
  done <<<"${pages}"
  # so in the guide the lines that start with one are the checks, and no other line
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  guide=$(grep --extended-regexp '^(✅|💡|❌)' <<<"$output")
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks
  [ "${guide}" = "$(grep --extended-regexp '^(✅|💡|❌)' <<<"$output")" ]
}

@test "the guide's color follows stdout: none into a pipe or a file while stderr is a terminal, some where it is forced" {
  local out="${BATS_TEST_TMPDIR}/checks.txt" esc=$'\x1b'
  # the pseudo-terminal is stderr's, and stdout goes to a file, as in kit welcome --checks | cat
  if script --version >/dev/null 2>&1
  then script --quiet --return --command "env -u NO_COLOR '${kit_root}/bin/kit' welcome --checks > '${out}'" /dev/null </dev/null >/dev/null
  else script -q /dev/null bash -c "env -u NO_COLOR '${kit_root}/bin/kit' welcome --checks > '${out}'" </dev/null >/dev/null
  fi
  [[ "$(cat "${out}")" == *"kit install"* ]]
  [[ "$(cat "${out}")" != *"${esc}"* ]]
  run --separate-stderr env -u NO_COLOR CLICOLOR_FORCE=1 "${kit_root}/bin/kit" welcome --checks
  [[ "$output" == *"${esc}[90mcd "*"kit install${esc}[0m"* ]]
}

@test "welcome offers the shellenv line when brew is at a prefix but not on PATH, and shows no check otherwise" {
  # on PATH: no check
  run --separate-stderr check brew-path
  [ -z "$output" ]
  # off PATH, with none at a prefix: no check
  rm "${fakes}/brew"
  path-without brew
  export KIT_BREW_PREFIXES="${BATS_TEST_TMPDIR}/opt/bin/brew"
  run --separate-stderr check brew-path
  [ -z "$output" ]
  # off PATH, at a prefix: the check fails and names the line
  mkdir -p "${BATS_TEST_TMPDIR}/opt/bin"
  printf '#!/usr/bin/env bash\nexit 1\n' > "${BATS_TEST_TMPDIR}/opt/bin/brew"
  chmod +x "${BATS_TEST_TMPDIR}/opt/bin/brew"
  run --separate-stderr check brew-path
  [ "$(jq --raw-output '[.step, .ok, .line, .fix, .interactive] | @tsv' <<<"$output")" = \
    "$(printf 'toolchains\tfalse\tbrew is installed at %s/opt but not on your PATH\t' "${BATS_TEST_TMPDIR}"
      printf 'eval "$(%s/opt/bin/brew shellenv)"\tfalse' "${BATS_TEST_TMPDIR}")" ]
  [[ "$(jq --raw-output .more <<<"$output")" == *profile* ]]
  # it comes right after yq, before the toolchains' own checks
  run --separate-stderr checks
  [ "$(jq --raw-output 'map(.id) | .[0:6] | join(" ")' <<<"$output")" = \
    "tool-bash tool-git tool-jq tool-yq brew-path toolchain-system" ]
  # --fix does not run it: kit cannot change the shell it was started from
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=brew-path
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"must run in your own shell"* ]]
  # the check says so, and the guide names the line without offering to run it
  run --separate-stderr check brew-path
  [ "$(jq --raw-output .runs <<<"$output")" = false ]
  [ "$(check tool-git | jq --raw-output .runs)" = true ]
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [[ "$output" == *'- brew-path: eval "$('*"kit does not run it"* ]]
}

# brewed-kit <prefix> puts a copy of the release where brew does, <prefix>/Cellar/kit/9.9.9/libexec, with the zsh
# completion's folder beside it, and prints the release's directory.
brewed-kit() {
  local release=$1/Cellar/kit/9.9.9/libexec
  mkdir -p "${release}" "$1/share/zsh/site-functions"
  cp -R "${kit_root}/bin" "${kit_root}/libexec" "${kit_root}/modules" "${kit_root}/packages" "${release}/"
  printf '%s\n' "${release}"
}

@test "welcome asks zsh whether it loads kit's completion, where brew installed kit, and shows no check otherwise" {
  local prefix release dir
  prefix=$(mkdir -p "${BATS_TEST_TMPDIR}/brew" && cd "${BATS_TEST_TMPDIR}/brew" && pwd -P)
  release=$(brewed-kit "${prefix}")
  dir=${prefix}/share/zsh/site-functions
  # an interactive zsh that says what the person's would: compinit ran or not, and the function that completes kit
  fake-script zsh 'printf "a banner\nkit-completion:%s\n" "${PROBE}"'
  export SHELL="${fakes}/zsh" PROBE=1:_kit
  # kit not installed by brew: no check, with the shell zsh all the same
  run --separate-stderr check completion-zsh
  [ -z "$output" ]
  # brew's kit, with another shell: no check
  SHELL=/bin/bash run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output 'map(select(.id == "completion-zsh")) | length' <<<"$output")" = 0 ]
  # brew installed kit and the shell is zsh, but brew put no completion in place: the check says so
  run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | [.step, .ok, .fix, .runs] | @tsv' <<<"$output")" = \
    $'setup\tfalse\tbrew reinstall kit\tfalse' ]
  [[ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | .line' <<<"$output")" == *"${dir}/_kit"* ]]
  # in place, and zsh has the function: it holds, with no fix
  printf '#compdef kit\n' > "${dir}/_kit"
  run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | [.ok, .line, .fix] | @tsv' <<<"$output")" = \
    $'true\tzsh loads kit\'s completion\t' ]
  # no compinit: the fix puts the folder on fpath and runs compinit
  PROBE=0: run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | [.ok, .fix] | @tsv' <<<"$output")" = \
    "$(printf 'false\tFPATH="%s:${FPATH}"; autoload -Uz compinit && compinit' "${dir}")" ]
  [[ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | .line' <<<"$output")" == *compinit* ]]
  # compinit ran without the folder on fpath: the fix is the fpath line alone
  PROBE=1: run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | [.ok, .fix] | @tsv' <<<"$output")" = \
    "$(printf 'false\tFPATH="%s:${FPATH}"' "${dir}")" ]
  [[ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | .more' <<<"$output")" == *.zshrc* ]]
  # it follows the forge checks, and --fix does not run it: kit cannot change the shell it was started from
  fake-gh
  run --separate-stderr "${release}/bin/kit" welcome --checks --json --machine
  [ "$(jq --raw-output 'map(.id) | .[-3:] | join(" ")' <<<"$output")" = \
    "forge-cli-github.com forge-login-github.com completion-zsh" ]
  PROBE=1: run --separate-stderr "${release}/bin/kit" welcome --fix=completion-zsh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"must run in your own shell"* ]]
  # a zsh that does not answer: kit says it could not look, and has no fix
  fake-script zsh 'exit 1'
  run --separate-stderr "${release}/bin/kit" welcome --checks --json
  [ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | [.ok, .fix] | @tsv' <<<"$output")" = $'false\t' ]
  [[ "$(jq --raw-output '.[] | select(.id == "completion-zsh") | .line' <<<"$output")" == "kit could not ask "* ]]
}

@test "welcome refuses a git older than 2.31, which kit's absolute paths need, and accepts 2.31" {
  local real_git
  real_git=$(command -v git)
  fake-script git "[[ \"\$*\" != --version ]] || { echo git version 2.30.2; exit 0; }; exec '${real_git}' \"\$@\""
  run --separate-stderr check tool-git
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = $'false\tgit 2.30.2 is too old; kit needs git 2.31 or later' ]
  fake-script git "[[ \"\$*\" != --version ]] || { echo git version 2.31.0; exit 0; }; exec '${real_git}' \"\$@\""
  run --separate-stderr check tool-git
  [ "$(jq --raw-output .ok <<<"$output")" = true ]
}

@test "welcome checks bash, git, jq, and yq with the toolchains, each fixed by the machine's package manager" {
  local real_jq
  real_jq=$(command -v jq)
  fake-script yq 'exit 1'
  # the machine's package manager names its command for a missing one
  run --separate-stderr check tool-yq
  [ "$(jq --raw-output '[.step, .ok, .line, .fix, .more] | @tsv' <<<"$output")" = \
    $'toolchains\tfalse\tyq is not installed; kit reads its YAML through it\tbrew install yq\t' ]
  # still the package manager's, with tool managers here: kit needs these to look for one
  printf 'brew "yq"\n' > Brewfile
  run --separate-stderr check tool-yq
  [ "$(jq --raw-output .fix <<<"$output")" = "brew install yq" ]
  rm Brewfile "${fakes}/yq"
  # no package manager: no fix, and the tool's site to read
  ambient-system
  fake-script jq "[[ \"\$*\" != --version ]] || { echo jq-1.6; exit 0; }; exec '${real_jq}' \"\$@\""
  run --separate-stderr check tool-jq
  [ "$(jq --raw-output '[.step, .ok, .line, .fix, .more] | @tsv' <<<"$output")" = \
    $'toolchains\tfalse\tjq 1.6 is too old; kit needs jq 1.7 or later\t\thttps://jqlang.org/download/' ]
  run --separate-stderr check toolchain-system
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = \
    $'true\tthe system has no package manager, as chosen, so it is ambient: kit uses what is on PATH' ]
}

@test "with apt the machine's package manager, welcome names its package, or the site for a tool Debian has none for" {
  local sudo='sudo '
  (( EUID != 0 )) || sudo=''
  rm "${fakes}/brew"
  path-without brew
  fake-script apt-get 'exit 1'
  run --separate-stderr check toolchain-system
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = \
    $'true\tapt is the machine\'s package manager; it names the fix for a missing tool' ]
  # Debian's yq is not mikefarah's, so there is no command, and the site to read
  fake-script yq 'exit 1'
  run --separate-stderr check tool-yq
  [ "$(jq --raw-output '[.fix, .more] | @tsv' <<<"$output")" = $'\thttps://github.com/mikefarah/yq#install' ]
  # with no tool manager, a missing linter is apt's to install
  rm "${fakes}/yq"
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  fake-script shellcheck 'exit 1'
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.fix, .runs] | @tsv' <<<"$output")" = "${sudo}apt-get install shellcheck"$'\ttrue' ]
}

@test "welcome names kit check's one finding with its own remedy, and offers a fix only where the finding names one" {
  "${kit_root}/bin/kit" install hooks/lefthook >/dev/null 2>&1
  # the one finding: lefthook.yml lacks the include, which no command fixes
  run --separate-stderr check kit-check
  [ "$(jq --raw-output '[.ok, .fix] | @tsv' <<<"$output")" = $'false\t' ]
  [[ "$(jq --raw-output .line <<<"$output")" == "lefthook.yml: put extends: [.kit/lefthook.yml] in lefthook.yml"* ]]
  # a finding that names a command offers that command
  printf '# lefthook.yml - the git hooks\nextends: [.kit/lefthook.yml]\n' > lefthook.yml
  mv .gitignore "${BATS_TEST_TMPDIR}/gitignore"
  run --separate-stderr check kit-check
  [ "$(jq --raw-output .ok <<<"$output")" = false ]
  [ "$(jq --raw-output .fix <<<"$output")" = "kit update" ]
  [[ "$(jq --raw-output .line <<<"$output")" == ".gitignore "* ]]
  [ "$(jq '.findings' <<<"$output")" = null ]
}

@test "welcome counts kit check's findings and names each, without the fix when they share one" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  # two findings, each with its own remedy: no fix, and each keeps its remedy
  mv .gitignore "${BATS_TEST_TMPDIR}/gitignore"
  rm .kit/1st.md
  run --separate-stderr check kit-check
  [ "$(jq --raw-output '[.ok, .line, .fix // "-"] | @tsv' <<<"$output")" = $'false\tkit check finds 2 problems\t-' ]
  [ "$(jq --raw-output '.findings | map(sub(" run: cd .* && "; " run: ")) | join("|")' <<<"$output")" = \
    '.gitignore is missing; run: kit update|.kit/1st.md is missing; run: kit hydrate' ]
  # two that one command fixes: that command is the fix, and each finding is named without it
  mv "${BATS_TEST_TMPDIR}/gitignore" .gitignore
  rm .kit/README.md
  run --separate-stderr check kit-check
  [ "$(jq --raw-output '[.line, .fix, (.findings | join("|"))] | @tsv' <<<"$output")" = \
    $'kit check finds 2 problems\tkit hydrate\t.kit/1st.md is missing|.kit/README.md is missing' ]
  # the text guide names each finding under the check's line, over its fix
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks
  [[ "$output" == *$'❌ kit check finds 2 problems\n   .kit/1st.md is missing\n   .kit/README.md is missing\n   '*\
'kit hydrate'* ]]
}

@test "welcome checks each dependency provider whose manifest is here: its lock, its tool, and what is installed" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  printf '{"devDependencies": {"left-pad": "^1.3.0"}}\n' > package.json
  fake-script npm 'exit 1'
  # a manifest without its lock pins nothing, and kit can run no fix
  run --separate-stderr check dependencies-npm
  [ "$(jq --raw-output '[.step, .ok, .fix] | @tsv' <<<"$output")" = $'setup\tfalse\t' ]
  [[ "$(jq --raw-output .line <<<"$output")" == "package.json is here without package-lock.json"* ]]
  printf '{"packages": {"node_modules/left-pad": {"version": "1.3.0"}}}\n' > package-lock.json
  # locked, but not installed: kit tools install fixes it
  run --separate-stderr check dependencies-npm
  [ "$(jq --raw-output '[.ok, .line, .fix] | @tsv' <<<"$output")" = \
    $'false\tnpm has not installed every package package-lock.json pins\tkit tools install' ]
  mkdir -p node_modules
  cp package-lock.json node_modules/.package-lock.json
  run --separate-stderr check dependencies-npm
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = $'true\tnpm installed every package package-lock.json pins' ]
  # with no npm on PATH, kit names that
  rm "${fakes}/npm"
  path-without npm
  run --separate-stderr check dependencies-npm
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = $'false\tpackage-lock.json is here, but npm is not on PATH' ]
  # the check comes before the linters, and there is none for uv, whose manifest is not here
  run --separate-stderr checks
  [ "$(jq --raw-output 'map(.id) | (index("dependencies-npm") < (map(startswith("linter-")) | index(true)))' \
    <<<"$output")" = true ]
  [ "$(jq --raw-output 'map(.id) | index("dependencies-uv")' <<<"$output")" = null ]
}

@test "a provider is found whichever the list names first" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  printf '{"devDependencies": {"left-pad": "^1.3.0"}}\n' > package.json
  printf '{"packages": {"node_modules/left-pad": {"version": "1.3.0"}}}\n' > package-lock.json
  printf '[project]\nname = "here"\nversion = "0.1.0"\n' > pyproject.toml
  printf 'version = 1\n' > uv.lock
  fake-script npm 'exit 0'
  fake-script uv 'exit 0'
  run --separate-stderr check dependencies-npm
  [ "$status" -eq 0 ]
  [[ "$(jq --raw-output .line <<<"$output")" != *"is not on PATH"* ]]
  # a read of the list that stops at the first name it wants can lose its race only now and then, so the check is
  # judged twenty times over, in one process with kit welcome's options: twenty kit welcome runs would run kit check
  # twenty times too, and take minutes under load
  kit_bash_modules=welcome run --separate-stderr kit-bash 'set -o errexit -o nounset -o pipefail
    for run in {1..20}; do welcome:dependencies npm; done'
  [ "$status" -eq 0 ]
  [ "$(jq --slurp --raw-output 'map(select(.id == "dependencies-npm")) | length' <<<"$output")" -eq 20 ]
  [[ "$output" != *"is not on PATH"* ]]
}

@test "a tool that answers version or -h but not --version is installed, and one that answers none of them is not" {
  # go and gofmt: go's version is a word, and gofmt has none; neither takes --version
  fake-script go 'case "$1" in version) echo "go version go1.27.3 darwin/arm64" ;; *) echo "flag provided but not defined: -version" >&2; exit 2 ;; esac'
  fake-script gofmt 'echo "usage: gofmt [flags] [path ...]" >&2; exit 2'
  fake-script shim 'exit 1'
  run --separate-stderr kit-bash 'use welcome; welcome:tool t-go go "it formats"; welcome:tool t-gofmt gofmt "it formats"
    welcome:tool t-shim shim "it does nothing"'
  [ "$(jq --slurp --compact-output 'map([.id, .ok])' <<<"$output")" = '[["t-go",true],["t-gofmt",true],["t-shim",false]]' ]
}

@test "welcome holds a linter npm installed, off PATH, since kit lint looks in its directory" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  printf '{"devDependencies": {"shellcheck": "^0.1.0"}}\n' > package.json
  printf '{"packages": {}}\n' > package-lock.json
  fake-script npm 'exit 1'
  # the shellcheck on PATH does not run, as a missing one
  fake-script shellcheck 'exit 1'
  mkdir -p node_modules/.bin
  printf '#!/bin/sh\n' > node_modules/.bin/shellcheck && chmod +x node_modules/.bin/shellcheck
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = \
    $'true\tshellcheck is installed in node_modules/.bin; kit lint runs it for .kit/rules/bash.md' ]
}

@test "welcome fixes a missing tool with kit tools install, or the package manager's command when ambient" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  fake-script shellcheck 'exit 1'
  fake-script actionlint 'exit 0'
  # ambient for the project: the package manager's command
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.step, .ok, .line, .fix, .more] | @tsv' <<<"$output")" = \
    $'setup\tfalse\tshellcheck is not installed; kit lint runs it for .kit/rules/bash.md\tbrew install shellcheck\t' ]
  run --separate-stderr check toolchain-project
  [ "$(jq --raw-output '[.step, .ok, .fix] | @tsv' <<<"$output")" = $'setup\ttrue\t' ]
  [ "$(jq --raw-output .line <<<"$output")" = \
    "no tool manager is usable for the project, so its tools are ambient: kit uses what is on PATH" ]
  # ambient for the system too: no fix, and the tool's site
  ambient-system
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.fix, .more] | @tsv' <<<"$output")" = \
    $'\thttps://github.com/koalaman/shellcheck#installing' ]
  # one tool manager: it installs what it pins; brew reads a Brewfile on macOS alone
  export OSTYPE=darwin24
  printf 'brew "shellcheck"\n' > Brewfile
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.fix, .more] | @tsv' <<<"$output")" = $'kit tools install\t' ]
  run --separate-stderr check toolchain-project
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = \
    $'true\tbrew is the project\'s tool manager; kit tools lists what it pins' ]
  # several, none chosen: the toolchains step asks first, and setup has no fix until then; brew fills in beside them
  touch mise.toml toolchain.Dockerfile
  fake-script mise 'exit 0'
  fake-script docker 'exit 0'
  run --separate-stderr check toolchain-project
  [ "$(jq --raw-output '[.ok, .fix, .interactive, .more] | @tsv' <<<"$output")" = \
    $'false\tkit toolchains use mise\tfalse\tor: kit toolchains use docker' ]
  [ "$(jq --raw-output .line <<<"$output")" = "several tool managers are usable for the project: mise, docker; choose one" ]
  # what is left keeps the other toolchain's command beside the fix, the fix with the cd to its folder in front
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [[ "$output" == *$'\n'"- toolchain-project in $(pwd -P): cd $(pwd -P) && kit toolchains use mise; or: kit toolchains use"\
" docker"$'\n'* ]]
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.fix, .more] | @tsv' <<<"$output")" = \
    $'\thttps://github.com/empowerite/kit/blob/main/docs/toolchains.md' ]
  # the toolchains check's fix records the first; the others' commands stand beside it
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=toolchain-project
  [ "$status" -eq 0 ]
  [ "$output" = "✅ mise is the project's tool manager; kit tools lists what it pins" ]
  # with mise and docker gone, brew is the only one again, and the recorded mise gives way to it
  rm mise.toml toolchain.Dockerfile
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output .fix <<<"$output")" = "kit tools install" ]
  # installed by the toolchain, in a directory not on PATH: kit lint looks there, so it holds
  # shellcheck disable=SC2016  # a fake's body expands when it runs
  fake-script brew '[[ "$*" != --prefix ]] || echo "${BATS_TEST_TMPDIR}/prefix"'
  mkdir -p "${BATS_TEST_TMPDIR}/prefix/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${BATS_TEST_TMPDIR}/prefix/bin/shellcheck"
  chmod +x "${BATS_TEST_TMPDIR}/prefix/bin/shellcheck"
  run --separate-stderr check linter-shellcheck
  [ "$(jq --raw-output '[.ok, .line, .fix] | @tsv' <<<"$output")" = \
    $'true\tshellcheck is installed by brew; kit lint runs it for .kit/rules/bash.md\t' ]
}

@test "a forge host among the remotes gets two checks: its tool installed, and logged in, the login's fix interactive" {
  git remote add origin https://github.com/acme/widget.git
  git remote add mirror git@github.com:acme/widget-mirror.git
  # gh missing: the login cannot be checked, and has no fix
  fake-script gh 'exit 1'
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | .id | select(startswith("forge-"))] | join(" ")' <<<"$output")" = \
    "forge-cli-github.com forge-login-github.com" ]
  [ "$(jq --raw-output '.[] | select(.id == "forge-cli-github.com") | [.ok, .line] | @tsv' <<<"$output")" = \
    $'false\tgh is not installed; kit reaches github.com through it' ]
  [ "$(jq --raw-output '.[] | select(.id == "forge-login-github.com") | [.ok, .fix, .more] | @tsv' \
    <<<"$output")" = $'false\t\thttps://cli.github.com' ]
  # gh installed, not logged in
  fake-gh
  run --separate-stderr check forge-login-github.com
  [ "$(jq --raw-output '[.ok, .line, .fix, .interactive] | @tsv' <<<"$output")" = \
    $'false\tgh is not logged in to github.com\tgh auth login --hostname github.com\ttrue' ]
  # logged in
  touch "${BATS_TEST_TMPDIR}/logged-in"
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | select(.id | startswith("forge-")) | .ok] | all' <<<"$output")" = true ]
  [ "$(jq --raw-output '.[] | select(.id == "forge-login-github.com") | .line' <<<"$output")" = \
    "gh is logged in to github.com" ]
}

@test "a repository on Azure DevOps gets a tool check and a login check, whichever of its three forms the remote is" {
  git remote add origin https://dev.azure.com/acme/shop/_git/web
  git remote add ssh git@ssh.dev.azure.com:v3/acme/shop/web
  git remote add old https://acme.visualstudio.com/shop/_git/web
  # az missing: no fix kit could say right for every package manager, so the site
  fake-script az 'exit 1'
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | .id | select(startswith("forge-"))] | join(" ")' <<<"$output")" = \
    "forge-cli-dev.azure.com forge-login-dev.azure.com" ]
  [ "$(jq --raw-output '.[] | select(.id == "forge-cli-dev.azure.com") | [.ok, .line, .fix, .more] | @tsv' <<<"$output")" = \
    $'false\taz is not installed; kit reaches dev.azure.com through it\t\thttps://learn.microsoft.com/cli/azure/install-azure-cli' ]
  # az without its azure-devops extension, then with it; logged in only after az login
  # shellcheck disable=SC2016  # a fake's body expands when it runs
  fake-script az '
case "$*" in
  ("--version") echo "azure-cli 2.60.0" ;;
  ("extension show --name azure-devops --output none") [[ -f "${BATS_TEST_TMPDIR}/extension" ]] ;;
  ("account show --output none") [[ -f "${BATS_TEST_TMPDIR}/logged-in" ]] ;;
  (*) exit 1
esac'
  run --separate-stderr checks
  [ "$(jq --raw-output '.[] | select(.id == "forge-cli-dev.azure.com") | [.ok, .fix] | @tsv' <<<"$output")" = \
    $'false\taz extension add --name azure-devops' ]
  [ "$(jq --raw-output '.[] | select(.id == "forge-login-dev.azure.com") | [.ok, .fix, .interactive] | @tsv' \
    <<<"$output")" = $'false\taz login\ttrue' ]
  touch "${BATS_TEST_TMPDIR}/extension" "${BATS_TEST_TMPDIR}/logged-in"
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | select(.id | startswith("forge-")) | .ok] | all' <<<"$output")" = true ]
}

@test "--fix runs the check's fix, checks again, and exits 0 when it now holds and 1 when it does not" {
  git remote add origin https://github.com/acme/widget.git
  fake-gh
  run --separate-stderr env LOGIN_FAILS=1 "${kit_root}/bin/kit" welcome --fix=forge-login-github.com
  [ "$status" -eq 1 ]
  [ "$output" = $'❌ gh is not logged in to github.com\n   gh auth login --hostname github.com' ]
  grep --quiet --line-regexp 'auth login --hostname github.com' "${BATS_TEST_TMPDIR}/gh.calls"
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=forge-login-github.com
  [ "$status" -eq 0 ]
  [ "$output" = "✅ gh is logged in to github.com" ]
  [[ "$stderr" == *"→ gh auth login --hostname github.com"* ]]
}

@test "--fix refuses with 2 an unknown check, one that holds, and one kit knows no fix for, and runs nothing" {
  fake-gh
  touch "${BATS_TEST_TMPDIR}/logged-in"
  git remote add origin https://github.com/acme/widget.git
  run "${kit_root}/bin/kit" welcome --fix=tool-nothing
  [ "$status" -eq 2 ]
  [[ "$output" == *"no check is named 'tool-nothing'; the checks are: tool-bash "* ]]
  run "${kit_root}/bin/kit" welcome --fix=forge-login-github.com
  [ "$status" -eq 2 ]
  [[ "$output" == *"forge-login-github.com holds already, so there is nothing to fix"* ]]
  run grep --quiet 'auth login' "${BATS_TEST_TMPDIR}/gh.calls"
  [ "$status" -eq 1 ]
  # gh gone: its login has no fix, only a page to read
  fake-script gh 'exit 1'
  run "${kit_root}/bin/kit" welcome --fix=forge-login-github.com
  [ "$status" -eq 2 ]
  [[ "$output" == *"kit knows no fix for forge-login-github.com; read: https://cli.github.com"* ]]
  run "${kit_root}/bin/kit" welcome --fix
  [ "$status" -eq 2 ]
  [[ "$output" == *"--fix takes its value after =: --fix=<check>; run: cd "*" && kit help welcome"* ]]
}

@test "--fix runs an offer's fix: kit-installed installs the kit, then holds with nothing to offer, and refuses with 2" {
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-installed
  [ "$status" -eq 0 ]
  [[ "$output" == "✅ kit.yml declares kit "* ]]
  [[ "$stderr" == *"→ kit install"* ]]
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-installed
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"kit-installed holds already, so there is nothing to fix"* ]]
}

@test "the text guide prints each page with its step's checks, then what is left, and exits 1 on a failure" {
  fake-script yq 'exit 1'
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "# Introduction — "* ]]
  [[ "$output" == *$'\n❌ yq is not installed; kit reads its YAML through it\n   brew install yq\n'* ]]
  [[ "$output" == *$'# What is left\n\n- tool-yq: brew install yq\n'* ]]
  [[ "$output" != *"kit:generated"* ]]
  # nothing ran: the guide prints the fixes and runs none
  run --separate-stderr "${kit_root}/bin/kit" welcome
  [ "$status" -eq 1 ]
}

@test "with kit installed and every check holding, the text guide says nothing is left and exits 0" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  # the kit package's rules run these linters, so a check stands for each; fakes that run stand in
  fake-script shellcheck 'exit 0'
  fake-script actionlint 'exit 0'
  run --separate-stderr checks
  [ "$(jq --raw-output 'map(.id) | join(" ")' <<<"$output")" = \
    "$(printf '%s ' tool-bash tool-git tool-jq tool-yq toolchain-system repo-git kit-installed kit-hydrated \
      toolchain-project linter-shellcheck linter-actionlint kit-check | sed 's/ $//')" ]
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [ "$status" -eq 0 ]
  # what is left comes last
  [[ "$output" == *$'\n# What is left\n\nNothing is left: every check holds.' ]]
  # a placed file gone: hydrate is the fix
  rm .kit/1st.md
  run --separate-stderr check kit-hydrated
  [ "$(jq --raw-output '[.ok, .fix] | @tsv' <<<"$output")" = $'false\tkit hydrate' ]
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-hydrated
  [ "$status" -eq 0 ]
  [ "$output" = "✅ .kit/ is in place: every file kit placed there is present" ]
}

# installed-desk installs kit here and commits kit.yml, with a commit before it, empty, that a worktree with no kit can
# start from. Fakes stand in for the linters the kit package's rules name, so each holds.
installed-desk() {
  git commit --quiet --allow-empty --message empty
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  git add kit.yml .gitignore && git commit --quiet --message kit
  fake-script shellcheck 'exit 0'
  fake-script actionlint 'exit 0'
}

# folders prints each folder of the checks on stdin once, in order: [folder, repository, desk, branch, kit].
folders() {
  jq --compact-output '[.[] | select(.folder) | [.folder, .repository, .desk, .branch, .kit]]
    | reduce .[] as $f ([]; if index([$f]) then . else . + [$f] end)'
}

@test "each folder of the repository is judged on its own: the desk, then each worktree, with the kit it declares" {
  installed-desk
  local desk
  desk=$(pwd -P)
  # one worktree from before kit was installed, one that pins a later kit, which the cache holds
  git worktree add --quiet -b none worktrees/none HEAD~1
  git worktree add --quiet -b pinned worktrees/pinned
  sed 's/^version: .*/version: 9.9.9/' kit.yml > worktrees/pinned/kit.yml
  later-release "${XDG_CACHE_HOME}/kit/kit-9.9.9"
  # shellcheck disable=SC2016  # the fake's body expands when it runs
  printf '#!/usr/bin/env bash\necho "❌ the 9.9.9 kit check ran in ${PWD##*/}"\nexit 1\n' \
    > "${XDG_CACHE_HOME}/kit/kit-9.9.9/bin/kit-check"
  cd worktrees/none
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  # every folder of the repository, wherever kit runs in it, each with its branch and the kit its kit.yml declares
  [ "$(folders <<<"$output")" = "$(jq --null-input --compact-output --arg d "${desk}" '[[$d, "repo", true, "main",
    "unreleased"], ["\($d)/worktrees/none", "repo", false, "none", null], ["\($d)/worktrees/pinned", "repo", false,
    "pinned", "9.9.9"]]')" ]
  # the machine's checks first, once; then each folder's, the same ids in each, judged there
  [ "$(jq --raw-output '[.[] | select(.folder == null) | .id] | join(" ")' <<<"$output")" = \
    "tool-bash tool-git tool-jq tool-yq toolchain-system" ]
  [ "$(jq --raw-output --arg f "${desk}/worktrees/none" '[.[] | select(.folder == $f) | .id] | join(" ")' \
    <<<"$output")" = "repo-git kit-installed toolchain-project" ]
  # the worktree that declares no kit version offers the install; the other two hold with nothing to offer
  [ "$(jq --raw-output '[.[] | select(.id == "kit-installed") | .fix // "-"] | join(" ")' <<<"$output")" = \
    "- kit install -" ]
  # kit check runs in each folder on the release that folder pins, and once in each
  [ "$(jq --raw-output '[.[] | select(.id == "kit-check") | [.ok, .line] | @tsv] | join("|")' <<<"$output")" = \
    $'true\tkit check finds nothing wrong|false\tthe 9.9.9 kit check ran in pinned' ]
  [ "$(cat "${desk}"/.kit/logs/kit-*.log | grep --count ' kit check$')" -eq 1 ]
  # the text guide names each folder above its checks
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks
  [[ "$output" == *$'\n'"repo, a worktree on none, no kit: ${desk}/worktrees/none"$'\n✅ this folder'* ]]
  [[ "$output" == *$'\n'"repo, a worktree on pinned, kit 9.9.9: ${desk}/worktrees/pinned"$'\n'* ]]
}

@test "a worktree outside its desk's tree, in a temporary folder, is a scratch worktree, a finding whose fix removes it" {
  installed-desk
  local desk
  desk=$(pwd -P)
  git worktree add --quiet -b inside worktrees/inside
  git worktree add --quiet -b scratch "${TMPDIR}/scratch"
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  # the desk, and a worktree in its own tree, are no scratch; the one beside it, in the temporary folder, is
  [ "$(jq --raw-output '[.[] | select(.id == "worktree-scratch") | .folder] | join(" ")' <<<"$output")" = \
    "$(cd "${TMPDIR}/scratch" && pwd -P)" ]
  [ "$(jq --raw-output '.[] | select(.id == "worktree-scratch") | [.ok, .line, .fix] | @tsv' <<<"$output")" = \
    "$(printf 'false\tthis worktree is in a temporary folder, outside %s: a scratch worktree, left behind\t' "${desk}"
      printf 'git -C %s worktree remove %s' "${desk}" "$(cd "${TMPDIR}/scratch" && pwd -P)")" ]
  # the fix removes it, and the check then holds: the folder is gone
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=worktree-scratch --folder="${TMPDIR}/scratch"
  [ "$status" -eq 0 ]
  [ ! -e "${TMPDIR}/scratch" ]
  [ -z "$(git worktree list --porcelain | grep scratch)" ]
}

@test "with no workspace only the machine's checks run, and --workspace=none names no group: the repository here" {
  git remote add origin https://github.com/acme/widget.git
  fake-gh
  touch "${BATS_TEST_TMPDIR}/logged-in"
  # none is no group, as kit flow reads it: inside a repository, that repository
  run --separate-stderr "${kit_root}/bin/kit" --workspace=none welcome --checks --json
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '[.[] | select(.folder) | .folder] | unique | join(" ")' <<<"$output")" = "$(pwd -P)" ]
  # outside one, with no group used, there is no folder: the machine's checks alone, and no forge host to check
  cd "${BATS_TEST_TMPDIR}"
  for workspace in '' none
  do
    run --separate-stderr "${kit_root}/bin/kit" ${workspace:+--workspace="${workspace}"} welcome --checks --json
    [ "$(jq --raw-output 'map(.id) | join(" ")' <<<"$output")" = \
      "tool-bash tool-git tool-jq tool-yq toolchain-system" ]
    [ "$(jq --raw-output 'map(.folder == null) | all' <<<"$output")" = true ]
  done
  # and the text guide's setup step has no check
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [ "$status" -eq 0 ]
  [[ "$output" == *$'# What is left\n\nNothing is left: every check holds.'* ]]
}

@test "--machine judges the machine alone: no folder, and github.com's forge, whatever the repository's remotes are" {
  git remote add origin https://gitlab.example.com/acme/widget.git
  fake-gh
  touch "${BATS_TEST_TMPDIR}/logged-in"
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --json --machine
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output 'map(.id) | join(" ")' <<<"$output")" = \
    "tool-bash tool-git tool-jq tool-yq toolchain-system forge-cli-github.com forge-login-github.com" ]
  [ "$(jq --raw-output 'map(.folder == null) | all' <<<"$output")" = true ]
  # progress names the machine's checks only
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --json --machine --progress
  [[ "$stderr" != *" in "* ]]
  # a fix runs there too, and a login's fix needs no remote
  rm "${BATS_TEST_TMPDIR}/logged-in"
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=forge-login-github.com --machine
  [ "$status" -eq 0 ]
  [ "$output" = "✅ gh is logged in to github.com" ]
  # no folder, and a verb of its own
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --machine --folder="$(pwd -P)"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--folder cannot be combined with --machine"* ]]
  run --separate-stderr "${kit_root}/bin/kit" welcome --machine
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"kit welcome needs --checks"* ]]
}

@test "over a group, every member's desk and worktrees are judged, in its order, and a forge host's login once" {
  local code="${BATS_TEST_TMPDIR}/code" a b
  git init --quiet "${code}/a" && git -C "${code}/a" commit --quiet --allow-empty --message one
  git -C "${code}/a" remote add origin https://github.com/o/a.git
  git -C "${code}/a" worktree add --quiet -b topic "${code}/a/worktrees/topic"
  git init --quiet "${code}/b" && git -C "${code}/b" remote add origin git@github.com:o/b.git
  mkdir -p "${XDG_CONFIG_HOME}/kit"
  printf 'roots: [%s]\nworkspaces:\n  w: {repos: [github.com/o/b, github.com/o/a, github.com/o/c]}\n' "${code}" \
    > "${XDG_CONFIG_HOME}/kit/workspaces.yml"
  a=$(cd "${code}/a" && pwd -P) b=$(cd "${code}/b" && pwd -P)
  fake-gh
  cd "${BATS_TEST_TMPDIR}"
  run --separate-stderr "${kit_root}/bin/kit" --workspace=w welcome --checks --json
  [ "$status" -eq 0 ]
  # the group's order, b first; c has no checkout, so no folder
  [ "$(folders <<<"$output")" = "$(jq --null-input --compact-output --arg a "${a}" --arg b "${b}" \
    '[[$b, "github.com/o/b", true, "main", null], [$a, "github.com/o/a", true, "main", null],
      ["\($a)/worktrees/topic", "github.com/o/a", false, "topic", null]]')" ]
  # both repositories are on github.com: one tool check and one login check for the machine
  [ "$(jq --raw-output '[.[] | select(.id | startswith("forge-")) | "\(.id) \(.folder)"] | join("|")' \
    <<<"$output")" = "forge-cli-github.com null|forge-login-github.com null" ]
  # the last group used is the workspace outside a repository; inside one, it is that repository
  mkdir -p "${XDG_CACHE_HOME}/kit/workspaces"
  printf 'w\n' > "${XDG_CACHE_HOME}/kit/workspaces/last"
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | select(.folder) | .folder] | unique | length' <<<"$output")" -eq 3 ]
  cd "${a}/worktrees/topic"
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | select(.folder) | .folder] | unique | join(" ")' <<<"$output")" = \
    "${a} ${a}/worktrees/topic" ]
}

@test "--fix runs a folder's check's fix in the folder --folder= names, and --checks --folder= judges that one alone" {
  installed-desk
  local desk
  desk=$(pwd -P)
  git worktree add --quiet -b topic worktrees/topic
  # the worktree has kit.yml, but nothing hydrated: its fix runs there, and the desk is left as it is
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --json --folder=./worktrees/topic
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '[.[] | .folder] | unique | join(" ")' <<<"$output")" = "${desk}/worktrees/topic" ]
  [ "$(jq --raw-output '.[] | select(.id == "kit-hydrated") | [.ok, .fix] | @tsv' <<<"$output")" = \
    $'false\tkit hydrate' ]
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-hydrated --folder=./worktrees/topic
  [ "$status" -eq 0 ]
  [ "$output" = "✅ .kit/ is in place: every file kit placed there is present" ]
  [ -e worktrees/topic/.kit/1st.md ]
  # with no folder, a folder's check is the repository's here
  cd worktrees/topic
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-hydrated
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"kit-hydrated holds already"* ]]
  # a machine check takes no folder; outside a repository, a folder's check needs one
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=tool-git --folder=.
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"tool-git is the machine's check, not a folder's, so it takes no --folder="* ]]
  cd "${BATS_TEST_TMPDIR}"
  run --separate-stderr "${kit_root}/bin/kit" welcome --fix=kit-hydrated
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"name the folder: kit welcome --fix=kit-hydrated --folder=<path>"* ]]
  run --separate-stderr "${kit_root}/bin/kit" welcome --checks --folder="${BATS_TEST_TMPDIR}"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"is no git working tree"* ]]
}

@test "a house package that places a page of the same name replaces the kit's, and a new name adds a page" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  mkdir -p .kit/packages/house/files/repo/.kit/welcome
  printf 'description: "our own"\ndepends:\n  - kit\n' > .kit/packages/house/package.yml
  printf '# Our terms\n\nWe say "desk".\n' > .kit/packages/house/files/repo/.kit/welcome/5-terms.md
  printf '# Our team\n\nAsk in #dev.\n' > .kit/packages/house/files/repo/.kit/welcome/7-our-team.md
  "${kit_root}/bin/kit" packages add house >/dev/null 2>&1
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [ "$(grep --extended-regexp '^# ' <<<"$output" | sed 's/ — .*//' | paste -s -d '|' -)" = "$(printf '%s|' \
    '# Introduction' '# Toolchains' '# Setup' '# Customize' '# Our terms' \
    '# Our team' '# What is left' | sed 's/|$//')" ]
  [ "$(readlink .kit/welcome/5-terms.md)" = ../packages/house/files/repo/.kit/welcome/5-terms.md ]
}

@test "the pages go by the number their names start with, so a tenth page comes after the ninth" {
  "${kit_root}/bin/kit" install >/dev/null 2>&1
  mkdir -p .kit/packages/house/files/repo/.kit/welcome
  printf 'description: "our own"\ndepends:\n  - kit\n' > .kit/packages/house/package.yml
  printf '# Ten\n' > .kit/packages/house/files/repo/.kit/welcome/10-ten.md
  printf '# Nine\n' > .kit/packages/house/files/repo/.kit/welcome/9-nine.md
  printf '# Notes\n' > .kit/packages/house/files/repo/.kit/welcome/notes.md
  "${kit_root}/bin/kit" packages add house >/dev/null 2>&1
  run --separate-stderr "${kit_root}/bin/kit" welcome --text
  [[ "$(grep --extended-regexp '^# ' <<<"$output" | sed 's/ — .*//' | paste -s -d '|' -)" == *'# Terms|# Nine|# Ten|# Notes|# What is left' ]]
}

@test "on a terminal, kit welcome hands off to kittui; --text, --checks, or no terminal stays in text" {
  mkdir -p "${BATS_TEST_TMPDIR}/fake"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-kittui" "${BATS_TEST_TMPDIR}/fake/kittui"
  ln -s "${BATS_TEST_DIRNAME}/fakes/fake-go" "${BATS_TEST_TMPDIR}/fake/go"
  export FAKES="${BATS_TEST_TMPDIR}/fake" PATH="${BATS_TEST_TMPDIR}/fake:${PATH}"
  run pty "'${kit_root}/bin/kit' welcome"
  [[ "$output" == *"kittui native-native welcome"* ]]
  [[ "$output" != *"# Introduction — "* ]]
  run pty "'${kit_root}/bin/kit' welcome --text"
  [[ "$output" == *"# Introduction — "* && "$output" != *"kittui native-native"* ]]
  run pty "'${kit_root}/bin/kit' welcome --checks"
  [[ "$output" == *"✅ bash "* && "$output" != *"kittui native-native"* ]]
  run --separate-stderr "${kit_root}/bin/kit" welcome </dev/null
  [[ "${lines[0]}" == "# Introduction — "* ]]
  [[ "$output" != *"kittui native-native"* ]]
}

# good-probes prints what a terminal that gives kittui all it needs answers, with the emoji width given, 2 by default.
good-probes() {
  jq --null-input --compact-output --argjson emoji "${1:-2}" '{answered: true, kitty_keyboard: true,
    grapheme_width: true, emoji_width: $emoji, ambiguous_width: 1, color: "truecolor"}'
}

@test "the terminal's checks are machine checks of setup, after the forge logins, with fixes kit never runs" {
  git remote add origin https://github.com/acme/widget.git
  fake-gh
  export SSH_TTY=/dev/ttys1 KIT_TERMINAL_PROBES
  KIT_TERMINAL_PROBES=$(good-probes 1)
  local want="forge-login-github.com terminal-ssh terminal-probe-kitty-keyboard terminal-probe-emoji-width"
  want+=" terminal-probe-ambiguous-width terminal-probe-color"
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.[] | .id | select(startswith("forge-login-") or startswith("terminal-"))] | join(" ")' <<<"$output")" \
    = "${want}" ]
  [ "$(jq -c '.[] | select(.id == "terminal-probe-emoji-width") | [.ok, .step, .runs, .interactive, .folder]' \
    <<<"$output")" = '[false,"setup",false,false,null]' ]
}

@test "with no terminal and no answers in the environment, no terminal check runs" {
  export SSH_TTY=/dev/ttys1
  run --separate-stderr checks
  [ "$status" -eq 0 ]
  [ "$(jq '[.[] | select(.id | startswith("terminal-"))] | length' <<<"$output")" = 0 ]
}

@test "--keep= keeps a terminal check, which then holds and says kept, and --unkeep= undoes it" {
  export SSH_TTY=/dev/ttys1 KIT_TERMINAL_PROBES
  KIT_TERMINAL_PROBES=$(good-probes 1)
  run "${kit_root}/bin/kit" welcome --keep=terminal-probe-emoji-width
  [ "$status" -eq 0 ]
  run --separate-stderr check terminal-probe-emoji-width
  [ "$(jq -r '.ok' <<<"$output")" = true ]
  [[ "$(jq -r '.line' <<<"$output")" == "kept: "* ]]
  [ "$(jq -r '.more' <<<"$output")" = "kit welcome --unkeep=terminal-probe-emoji-width" ]
  run "${kit_root}/bin/kit" welcome --unkeep=terminal-probe-emoji-width
  [ "$status" -eq 0 ]
  run --separate-stderr check terminal-probe-emoji-width
  [ "$(jq -r '.ok' <<<"$output")" = false ]
}

@test "--keep= says the check as it now holds, --json gives it as --checks does, and --unkeep= says it again" {
  export SSH_TTY=/dev/ttys1 KIT_TERMINAL_PROBES
  KIT_TERMINAL_PROBES=$(good-probes 1)
  run --separate-stderr "${kit_root}/bin/kit" welcome --keep=terminal-probe-emoji-width --json
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.id, .ok, .step, .runs, .folder, (.line | startswith("kept: "))]' <<<"$output")" = \
    '["terminal-probe-emoji-width",true,"setup",false,null,true]' ]
  run --separate-stderr "${kit_root}/bin/kit" welcome --unkeep=terminal-probe-emoji-width
  [ "$status" -eq 0 ]
  [[ "$output" == "❌ "* ]]
}

@test "--keep= refuses with 2 a check that holds, and one of another terminal than the one kit runs in, and writes nothing" {
  export SSH_TTY=/dev/ttys1 KIT_TERMINAL_PROBES
  KIT_TERMINAL_PROBES=$(good-probes 1)
  run --separate-stderr "${kit_root}/bin/kit" welcome --keep=terminal-probe-color
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"terminal-probe-color holds, so there is nothing to keep"* ]]
  run --separate-stderr "${kit_root}/bin/kit" welcome --keep=terminal-iterm-option
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"terminal-iterm-option is not a check of the terminal kit runs in"* ]]
  [ ! -e "${HOME}/.kit/settings.yml" ]
  # a check that is kept holds, and keeping it again is no refusal
  run "${kit_root}/bin/kit" welcome --keep=terminal-probe-emoji-width
  [ "$status" -eq 0 ]
  run "${kit_root}/bin/kit" welcome --keep=terminal-probe-emoji-width
  [ "$status" -eq 0 ]
}

@test "--fix of a check that is not the terminal's leaves the terminal's settings unread" {
  mkdir -p bash/terminal
  printf 'bash_path:\n  - kit:modules/bash/\n  - bash/\n' > kit.yml
  printf 'terminal/iterm:settings() { touch "%s"; return 1; }\n' "${BATS_TEST_TMPDIR}/read" > bash/terminal/iterm.sh
  export TERM_PROGRAM=iTerm.app KIT_TERMINAL_PROBES='{"answered":false}'
  run "${kit_root}/bin/kit" welcome --fix=tool-jq
  [ "$status" -eq 2 ]
  [ ! -e "${BATS_TEST_TMPDIR}/read" ]
  run "${kit_root}/bin/kit" welcome --fix=terminal-iterm-option
  [ "$status" -eq 2 ]
  [ -e "${BATS_TEST_TMPDIR}/read" ]
}

@test "--keep= refuses with 2 a check that is not a terminal finding, and a terminal's heading" {
  export SSH_TTY=/dev/ttys1
  run "${kit_root}/bin/kit" welcome --keep=tool-jq
  [ "$status" -eq 2 ]
  run "${kit_root}/bin/kit" welcome --keep=terminal-ssh
  [ "$status" -eq 2 ]
  run "${kit_root}/bin/kit" welcome --keep=terminal-iterm-nonsense
  [ "$status" -eq 2 ]
  [ ! -e "${HOME}/.kit/settings.yml" ]
}

@test "the text guide shows a terminal's heading, and only the findings that failed or are kept" {
  export SSH_TTY=/dev/ttys1 KIT_TERMINAL_PROBES
  KIT_TERMINAL_PROBES=$(good-probes)
  run "${kit_root}/bin/kit" welcome --text
  [[ "$output" == *"The terminal over ssh: kit cannot read its settings"* ]]
  [[ "$output" != *"draws 📚 in two cells"* ]]
  KIT_TERMINAL_PROBES=$(good-probes 1)
  run "${kit_root}/bin/kit" welcome --text
  [[ "$output" == *"❌ The terminal over ssh draws 📚 in 1 cell(s)"* ]]
}

@test "on a terminal, kit welcome asks it what it does, and judges it, even when it does not answer" {
  run pty "env -u KIT_TERMINAL_PROBES '${kit_root}/bin/kit' welcome --checks --json"
  [[ "$output" == *'"id":"terminal-unknown"'* ]]
  [[ "$output" == *'"id":"terminal-probe-kitty-keyboard"'* ]]
}

@test "a KIT_TERMINAL_PROBES that is no JSON object is ignored, as if it were not set" {
  KIT_TERMINAL_PROBES=nope run --separate-stderr checks
  [ "$status" -eq 0 ]
  [ "$(jq '[.[] | select(.id | startswith("terminal-"))] | length' <<<"$output")" = 0 ]
}

# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# the bot check: a folder's, where the primary remote is on GitHub

# bot-world sets a GitHub remote, curl as a stub routed by URL, the fake keychain, and a bots file with one bot, so the
# bot check can run; curl answers with an App and an installation reaching the repository that holds every permission
# the bot's jobs need.
bot-world() {
  fake-tools gh
  cat > "${FAKE_DIR}/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DIR}/curl.calls"
dump='' write='' args=("$@")
for (( i = 0; i < ${#args[@]}; i++ ))
do
  [[ "${args[i]}" == --dump-header ]] && dump=${args[i + 1]}
  [[ "${args[i]}" == --write-out ]] && write=${args[i + 1]}
done
cat > /dev/null
while IFS=$'\t' read -r glob status code body headers
do
  # shellcheck disable=SC2053  # the route is a glob on purpose
  [[ "$*" == ${glob} ]] || continue
  [[ -z "${dump}" ]] || : > "${dump}"
  [[ -z "${body}" ]] || cat "${FAKE_DIR}/${body}"
  printf '%s' "${write/'%{http_code}'/${code}}"
  exit "${status}"
done < "${FAKE_DIR}/curl.routes"
echo "curl: unrouted call: $*" >&2
exit 99
STUB
  chmod +x "${FAKE_DIR}/bin/curl"
  ln -sf "${BATS_TEST_DIRNAME}/fakes/fake-secrets" "${FAKE_DIR}/bin/security"
  git remote add origin https://github.com/empowerite/kit.git
  openssl genrsa -out "${BATS_TEST_TMPDIR}/app.pem" 2048 2>/dev/null
  mkdir -p "${XDG_CONFIG_HOME}/kit"
  printf 'bots:\n  - name: kit-bot\n    host: github.com\n    app: 12345\n    owner: empowerite\n    jobs: [work, review]\n' \
    > "${XDG_CONFIG_HOME}/kit/bots.yml"
  bot-routes '"metadata":"read","contents":"write","issues":"write","pull_requests":"write","checks":"read","statuses":"read","actions":"read"'
}

# bot-route <glob> <status> <code> [<body>] adds a route for curl.
bot-route() { printf '%s\t%s\t%s\t%s\t\n' "$1" "$2" "$3" "${4:-}" >> "${FAKE_DIR}/curl.routes"; }

# bot-routes <permissions> routes the forge: the App, and its installation on the repository holding the permissions.
bot-routes() {
  fixture app.json <<<'{"slug":"kit-bot","owner":{"login":"empowerite"},"permissions":{},"html_url":"https://github.com/apps/kit-bot"}'
  fixture inst.json <<<"{\"id\":99,\"permissions\":{$1},\"repository_selection\":\"selected\",\"html_url\":\"https://github.com/settings/installations/99\"}"
  : > "${FAKE_DIR}/curl.routes"
  bot-route '*api.github.com/app' 0 200 app.json
  bot-route '*/repos/empowerite/kit/installation' 0 200 inst.json
}

# bot-key puts the bot's key in the fake keychain.
bot-key() {
  kit_bash_modules=secrets kit-bash 'secrets:put kit-bot github.com/12345' < "${BATS_TEST_TMPDIR}/app.pem"
}

@test "the bot check is planned only where the primary remote is GitHub, after the tool manager" {
  fake-tools gh glab  # the check probes the forge tool for its version; no call reaches a real one
  run --separate-stderr checks
  [ "$(jq --raw-output 'map(.id) | index("bot")' <<<"$output")" = null ]
  git remote add origin https://gitlab.com/acme/widget.git
  run --separate-stderr checks
  [ "$(jq --raw-output 'map(.id) | index("bot")' <<<"$output")" = null ]
  git remote remove origin
  git remote add origin https://github.com/acme/widget.git
  run --separate-stderr checks
  [ "$(jq --raw-output '[.[] | select(.folder) | .id] | join(" ")' <<<"$output")" = \
    'repo-git kit-installed toolchain-project bot' ]
}

@test "with no bot for the host, the bot check holds and offers to set one up, which kit never runs" {
  bot-world
  rm "${XDG_CONFIG_HOME}/kit/bots.yml"
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.step, .ok, .line, .fix, .runs, .more] | @tsv' <<<"$output")" = \
    $'setup\ttrue\tno bot acts for you here; set one up to hand it issues\tkit bots --add=<name> --app=<id> --key=<file>\tfalse\thttps://docs.github.com/en/apps/creating-github-apps' ]
  [ -z "$stderr" ]
  # a bot on another host is none here
  printf 'bots:\n  - name: kit-bot\n    host: ghe.example.com\n    app: 1\n' > "${XDG_CONFIG_HOME}/kit/bots.yml"
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = $'true\tno bot acts for you here; set one up to hand it issues' ]
  [ -z "$stderr" ]
}

@test "the bot check fails for two bots on the host with none chosen, naming both, and holds once kit.yml names one" {
  bot-world
  bot-key
  printf '  - name: other-bot\n    host: github.com\n    app: 777\n' >> "${XDG_CONFIG_HOME}/kit/bots.yml"
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .fix] | @tsv' <<<"$output")" = $'false\tkit bots --check' ]
  [ "$(jq --raw-output .line <<<"$output")" = \
    '2 bots are on github.com: kit-bot, other-bot; set bot: in kit.yml to the one that acts here' ]
  [ -z "$stderr" ]
  printf 'bot: kit-bot\n' > kit.yml
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = $'true\tkit-bot[bot] acts for you here, for work, review' ]
}

@test "the bot check fails for a bot kit.yml names that the bots file lacks, with the add as its fix" {
  bot-world
  printf 'bot: ghost\n' > kit.yml
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line, .fix, .runs] | @tsv' <<<"$output")" = \
    $'false\tkit.yml names the bot ghost, which the bots file does not have\tkit bots --add=ghost --app=<id> --key=<file>\tfalse' ]
}

@test "the bot check fails for a bot kit.yml names that is on another host, saying so" {
  bot-world
  printf 'bots:\n  - name: kit-bot\n    host: ghe.example.com\n    app: 1\n' > "${XDG_CONFIG_HOME}/kit/bots.yml"
  printf 'bot: kit-bot\n' > kit.yml
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line] | @tsv' <<<"$output")" = \
    $'false\tkit.yml names the bot kit-bot, which is on ghe.example.com, not on github.com, the primary remote\'s host' ]
  [ -z "$stderr" ]
}

@test "the bot check fails for a bots file kit cannot read, saying why" {
  bot-world
  printf 'bots: 3\n' > "${XDG_CONFIG_HOME}/kit/bots.yml"
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .fix] | @tsv' <<<"$output")" = $'false\tkit bots --check' ]
  [[ "$(jq --raw-output .line <<<"$output")" == *'bots.yml is not {bots:'* ]]
  [ -z "$stderr" ]
}

@test "the bot check fails where the key is missing, with the add as its fix, which kit never runs" {
  bot-world
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line, .fix, .runs] | @tsv' <<<"$output")" = \
    $'false\tthe key of kit-bot is not in the secret store\tkit bots --add=kit-bot --app=12345 --key=<file>\tfalse' ]
  [ -z "$stderr" ]
}

@test "the bot check says the store could not be read, apart from a key not stored, and offers no add" {
  bot-world
  bot-key
  FAKE_SECRETS_FAIL_READ=1 run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .fix, .runs] | @tsv' <<<"$output")" = $'false\t\ttrue' ]
  [[ "$(jq --raw-output .line <<<"$output")" == 'the keychain could not be read for kit-bot github.com/12345 ('* ]]
  [ -z "$stderr" ]
}

@test "the bot check fails where the installation does not reach this repository" {
  bot-world
  bot-key
  fixture none.json <<<'{"message":"Not Found"}'
  fixture list.json <<<'[{"id":99,"account":{"login":"empowerite"},"repository_selection":"selected","html_url":"https://github.com/settings/installations/99"}]'
  : > "${FAKE_DIR}/curl.routes"
  bot-route '*api.github.com/app' 0 200 app.json
  bot-route '*/repos/empowerite/kit/installation' 22 404 none.json
  bot-route '*/app/installations?per_page*' 0 200 list.json
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line, .fix] | @tsv' <<<"$output")" = \
    $'false\tthe installation of kit-bot does not reach empowerite/kit\tkit bots --check' ]
}

@test "the bot check fails where a job lacks a permission, naming the job and the permission" {
  bot-world
  bot-key
  bot-routes '"metadata":"read","contents":"write","issues":"write","pull_requests":"write","statuses":"read","actions":"read"'
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line, .fix] | @tsv' <<<"$output")" = \
    $'false\tkit-bot lacks checks: read (work), checks: read (review)\tkit bots --check' ]
}

@test "the bot check fails with the forge's reason where the forge cannot be asked, and does not hang" {
  bot-world
  bot-key
  : > "${FAKE_DIR}/curl.routes"
  bot-route '*api.github.com/app' 28 000
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .fix] | @tsv' <<<"$output")" = $'false\tkit bots --check' ]
  [ "$(jq --raw-output .line <<<"$output")" = \
    'check the network (https://api.github.com could not be reached: curl exit 28; GET /app was not made)' ]
  # the call is bounded, so a host that does not answer cannot hold welcome up
  grep --quiet -- '--connect-timeout 10 --max-time 30' "${FAKE_DIR}/curl.calls"
  [ -z "$stderr" ]
}

@test "the bot check holds where the bot's key, installation, and permissions are in order, naming the bot and its jobs" {
  bot-world
  bot-key
  run --separate-stderr check bot
  [ "$(jq --raw-output '[.ok, .line, .fix, .runs] | @tsv' <<<"$output")" = \
    $'true\tkit-bot[bot] acts for you here, for work, review\t\ttrue' ]
  [ -z "$stderr" ]
}
