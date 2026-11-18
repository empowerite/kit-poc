#!/usr/bin/env bats
# ready.bats - kit ready writes the report as the pull request's body, keeps the lines that close issues, and marks it
# ----------------------------------------------------------------------------------------------------------------------
# The forge is a provider the repository adds on its module path, as in forge-stand-ins.bats, that keeps the pull
# request's body in body.txt: pr-body prints it and pr-set-body writes it, so a test reads the body a forge would then
# hold, and a second command reads what the first wrote. Every call logs its name to calls.log. The last test drives
# GitHub's provider through the fake of gh.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fake-tools gh
  fresh-repo
  git remote add origin https://code.example/team/example.git
  mkdir -p bash/forge
  # the forge links no issue by itself, so the body's closing lines are all that link one
  {
    printf 'forge: plain\nbash_path:\n  - kit:modules/bash/\n  - bash/\n'
    printf 'forge_settings:\n  plain:\n    stand_ins:\n      closing-issues: body\n'
  } > kit.yml
  {
    printf 'forge/plain:contract() { echo 3; }\n'
    printf 'forge/plain:lacks() { echo closing-issues; }\n'
    printf 'log() { printf "%%s\\n" "$1" >> "%s/calls.log"; }\n' "${repo}"
    printf 'forge/plain:require() { :; }\n'
    printf 'forge/plain:noun() { printf "#\\tpull request\\n"; }\n'
    printf 'forge/plain:repo() { echo team/example; }\n'
    printf 'forge/plain:pr-here() { echo 5; }\n'
    printf 'forge/plain:pr-url() { echo "https://code.example/team/example/pull/$1"; }\n'
    printf 'forge/plain:pr-body() { log pr-body; [[ ! -e "%s/unreadable" ]] && cat "%s/body.txt"; }\n' "${repo}" "${repo}"
    printf 'forge/plain:pr-set-body() { log pr-set-body; [[ ! -e "%s/unwritable" ]] && printf "%%s\\n" "$2" > "%s/body.txt"; }\n' \
      "${repo}" "${repo}"
    printf 'forge/plain:pr-ready() { log pr-ready; }\n'
    printf 'forge/plain:issue-state() { echo OPEN; }\n'
  } > bash/forge/plain.sh
  # what kit work and kit commit leave in a draft's body, a line a person added, and prose that closes nothing
  printf 'Closes #7\nfixes AB#4521\r\nA note from before.\nCloses #8, closes #9\nFixes typos\n' > body.txt
}

@test "kit ready --report= writes the report as the body, above each line that only closes issues, and then marks it ready" {
  run "${kit_root}/bin/kit" ready --report=$'What changed: the parser.\n\nWhat was checked: bats tests/parser.bats.\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull request #5's body is the report"* ]]
  [[ "$output" == *"pull request #5 is ready for review"* ]]
  [ "$(cat body.txt)" = "$(printf '%s\n' 'What changed: the parser.' '' 'What was checked: bats tests/parser.bats.' '' \
    'Closes #7' 'fixes AB#4521' 'Closes #8, closes #9')" ]
  [ "$(paste -s -d ' ' calls.log)" = 'pr-body pr-set-body pr-ready' ]
  # the body still links the issue, as kit linked reads it
  run "${kit_root}/bin/kit" linked 5
  [ "$status" -eq 0 ]
}

@test "ready, linked, and settle refuse a missing change, and a word that is no number, in the same words and with the same statuses" {
  printf 'forge/plain:pr-here() { :; }\nforge/plain:settle() { :; }\n' >> bash/forge/plain.sh
  local verb
  for verb in ready linked settle
  do
    run "${kit_root}/bin/kit" "${verb}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no change is named, and this checkout is working on none; run: cd "*" && kit ${verb} <number>"* ]]
    run "${kit_root}/bin/kit" "${verb}" abc
    [ "$status" -eq 2 ]
    [[ "$output" == *"'abc' is not a number; run: cd "*" && kit help ${verb}"* ]]
  done
}

@test "a second report replaces the first and repeats no closing line, and --report-file= is read from where it was typed" {
  "${kit_root}/bin/kit" ready --report='The first report.' >/dev/null 2>&1
  mkdir notes
  printf 'The second report.\n\nCloses #7\n\n' > notes/report.md
  cd notes
  run "${kit_root}/bin/kit" ready 5 --report-file=report.md
  [ "$status" -eq 0 ]
  [ "$(cat ../body.txt)" = "$(printf '%s\n' 'The second report.' '' 'Closes #7' '' 'fixes AB#4521' 'Closes #8, closes #9')" ]
  run "${kit_root}/bin/kit" linked 5
  [ "$status" -eq 0 ]
}

@test "a body that cannot be read or written stays as it was, and the pull request stays a draft" {
  before=$(cat body.txt)
  touch unreadable
  run "${kit_root}/bin/kit" ready --report='The report.'
  [ "$status" -eq 1 ]
  [[ "$output" == *"pull request #5's body could not be written, so it is still a draft; write the report on the forge, https://code.example/team/example/pull/5"* ]]
  [ "$(paste -s -d ' ' calls.log)" = 'pr-body' ]
  rm unreadable calls.log
  touch unwritable
  run "${kit_root}/bin/kit" ready --report='The report.'
  [ "$status" -eq 1 ]
  [ "$(paste -s -d ' ' calls.log)" = 'pr-body pr-set-body' ]
  [ "$(cat body.txt)" = "${before}" ]
}

@test "an empty report, a file that is not there, and both options at once are usage errors, and the forge is not asked" {
  run "${kit_root}/bin/kit" ready --report=$' \n'
  [ "$status" -eq 2 ]
  [[ "$output" == *"the report is empty"* ]]
  : > empty.md
  run "${kit_root}/bin/kit" ready --report-file=empty.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"the report is empty"* ]]
  run "${kit_root}/bin/kit" ready --report-file=none.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"'none.md' is not a file"* ]]
  run "${kit_root}/bin/kit" ready --report=x --report-file=empty.md
  [ "$status" -eq 2 ]
  [ ! -e calls.log ]
}

@test "without a report, kit ready marks the pull request and leaves its body alone" {
  before=$(cat body.txt)
  run "${kit_root}/bin/kit" ready
  [ "$status" -eq 0 ]
  [ "$(cat calls.log)" = 'pr-ready' ]
  [ "$(cat body.txt)" = "${before}" ]
}

@test "on GitHub, the report and the closing line reach gh pr edit as one body, before gh pr ready" {
  git remote set-url origin https://github.com/empowerite/example.git
  rm kit.yml
  fixture user.json <<<'{"login": "ada"}'
  fixture pr.json <<<'{"body": "Closes AB#4521"}'
  route gh 'api user*' user.json
  route gh 'pr view 3 --json body*' pr.json
  route gh 'pr edit 3 --body *' '!0'
  route gh 'pr ready 3' '!0'
  run "${kit_root}/bin/kit" ready 3 --report='What changed: the parser.'
  [ "$status" -eq 0 ]
  [ "$(grep -A2 '^pr edit 3 --body' "${FAKE_DIR}/gh.calls")" \
    = "$(printf '%s\n' 'pr edit 3 --body What changed: the parser.' '' 'Closes AB#4521')" ]
  [ "$(tail -n 1 "${FAKE_DIR}/gh.calls")" = 'pr ready 3' ]
}

# ----------------------------------------------------------------------------------------------------------------------
