#!/usr/bin/env bats
# context.bats - kit context classifies a file into its kinds, names the rules by kind and by what a kind embeds, logs the ask, and answers Claude's hook
# ----------------------------------------------------------------------------------------------------------------------

bats_require_minimum_version 1.5.0

load helper

setup_file() {
  world-repo installed
}

setup() {
  world-copy-repo installed
}

@test "a file is governed by its path, by its first line, or by nothing" {
  # a real file the rule's glob would expand to, were the glob ever word-split
  mkdir docs && printf '# x\n' > docs/x.md
  run "${kit_checkout}/bin/kit" context README.md
  [ "$output" = ".kit/rules/markdown.md" ]
  run "${kit_checkout}/bin/kit" context justfile
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = ".kit/rules/just.md" ]
  [ "${lines[1]}" = ".kit/rules/bash.md" ]
  [ "${#lines[@]}" -eq 2 ]
  mkdir bin && printf '#!/usr/bin/env bash\necho\n' > bin/tool
  run "${kit_checkout}/bin/kit" context bin/tool
  [ "$output" = ".kit/rules/bash.md" ]
  run "${kit_checkout}/bin/kit" context bin/other
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "${kit_checkout}/bin/kit" context docs/a.md "${PWD}/.github/workflows/x.yml" lib/x.md
  [ "${lines[0]}" = ".kit/rules/markdown.md" ]
  [ "${lines[1]}" = ".kit/rules/workflows.md" ]
  [ "${lines[2]}" = ".kit/rules/bash.md" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "the prose style governs every text file, the kind made of the kit's kinds, after the rule and the style for its kind" {
  "${kit_checkout}/bin/kit" packages add style/bash style/prose >/dev/null 2>&1
  mkdir bin && printf '#!/usr/bin/env bash\necho\n' > bin/tool
  run "${kit_checkout}/bin/kit" context bin/tool
  [ "${lines[0]}" = ".kit/rules/bash.md" ]
  [ "${lines[1]}" = ".kit/styles/bash.md" ]
  [ "${lines[2]}" = ".kit/styles/prose.md" ]
  [ "${#lines[@]}" -eq 3 ]
  run "${kit_checkout}/bin/kit" context notes.txt
  [ "$output" = ".kit/styles/prose.md" ]
  run "${kit_checkout}/bin/kit" context bin/other image.png
  [ -z "$output" ]
  run "${kit_checkout}/bin/kit" context --json bin/tool
  [ "$(jq -c .kinds <<<"$output")" = '["any","bash","text"]' ]
  grep --quiet 'indicative' .kit/styles/prose.md
}

# compressed <page> prints, in the form <line>: <sentence>, each sentence of the page's paragraphs and list items that
# runs past 30 words or holds a second colon or semicolon. A code span and a quoted example each count as one word,
# so the fault that an example shows is not counted against the page.
compressed() {
  awk '
    function flush(   count, i, held, parts) {
      gsub(/`[^`]*`/, "code", text); gsub(/\."/, "\".", text); gsub(/"[^"]*"/, "quote", text)
      count = split(text, parts, /[.?!]( |$)/); text = ""
      for (i = 1; i <= count; i++)
        if (split(parts[i], held, " ") > 30 || gsub(/[:;]/, "&", parts[i]) > 1) print at ": " parts[i]
    }
    FNR == 1 && $0 == "---" { front = 1; next }
    front { front = ($0 != "---"); next }
    /^[[:space:]]*$/ || /^#/ { flush(); next }
    /^[[:space:]]*([0-9]+\.|-) / { flush() }
    {
      line = $0; sub(/^[[:space:]]*(([0-9]+\.|-) )?/, "", line)
      if (text == "") at = FNR
      text = (text == "" ? "" : text " ") line
    }
    END { flush() }
  ' "$1"
}

@test "the prose style names compressed prose in six rules, and its own sentences keep the two rules a count can judge" {
  local rule style="${kit_root}/packages/style/prose/files/repo/.kit/styles/prose.md" text
  text=$(tr '\n' ' ' < "${style}" | tr -s ' ')
  for rule in 'make who or what acts the subject' 'Give each sentence one idea' 'Repeat the noun' \
    '"such as" before an example and "because" before a cause' "Define a term of the project's own" \
    "Do not repeat another file's text"
  do
    [[ "${text}" == *"${rule}"* ]] || { echo "the prose style does not say: ${rule}"; return 1; }
  done
  # the two rules that led writers to compressed prose are reworded
  [[ "${text}" != *'thing under discussion'* && "${text}" != *'Do not restate'* ]]
  # the counter finds a second mark and a thirty-first word, and passes over a quoted example and a code span
  {
    printf -- '---\nkind: a; b; c\n---\n# A page: one; two\n\nOne idea here. A case: the first; the second.\n\n'
    printf '1. Short, not "a; b: c." Short again: `a; b; c`.\n2. %sone.\n' "$(printf 'word %.0s' {1..30})"
    printf '   %s\n' "$(printf 'word %.0s' {1..29})one."
  } > page.md
  run compressed page.md
  [ "${lines[0]}" = '6: A case: the first; the second' ]
  [ "${lines[1]}" = "9: $(printf 'word %.0s' {1..30})one" ]
  [ "${#lines[@]}" -eq 2 ]
  run compressed "${style}"
  [ -z "$output" ] || { printf '%s\n' "${output}"; return 1; }
}

@test "a relative path is taken from the directory the command was typed in" {
  mkdir docs && cd docs
  run "${kit_checkout}/bin/kit" context x.md
  [ "$output" = ".kit/rules/markdown.md" ]
  [ "$(cut -f 2 ../.git/kit/context.log)" = "docs/x.md" ]
}

@test "the json answer is one object per path with its kinds and its rules, and every ask is logged" {
  run "${kit_checkout}/bin/kit" context --json justfile README.md
  [ "$status" -eq 0 ]
  [ "$(jq -c .kinds <<<"${lines[0]}")" = '["any","just","text"]' ]
  [ "$(jq -c .rules <<<"${lines[0]}")" = '[".kit/rules/just.md",".kit/rules/bash.md"]' ]
  [ "$(jq -r .path <<<"${lines[1]}")" = "README.md" ]
  [ "$(jq -c .kinds <<<"${lines[1]}")" = '["any","markdown","text"]' ]
  [ "$(cut -f 2 .git/kit/context.log | paste -s -d ' ' -)" = "justfile README.md" ]
}

@test "a kind is defined once under .kit/kinds/, and the rule and the style of a kind name it, so neither carries a glob" {
  "${kit_checkout}/bin/kit" packages add style/bash >/dev/null 2>&1
  [ -f .kit/kinds/bash.yml ]
  grep --quiet --line-regexp '  - "\*\*/\*.sh"' .kit/kinds/bash.yml
  for file in .kit/rules/*.md .kit/styles/*.md
  do
    run -1 grep --quiet --line-regexp 'paths:' "${file}"
    run -1 grep --quiet --line-regexp 'content:' "${file}"
    grep --quiet --line-regexp 'kind:' "${file}"
  done
  grep --quiet --line-regexp '  - bash' .kit/kinds/just.yml
  grep --quiet --line-regexp 'embeds:' .kit/kinds/workflows.yml
  mkdir -p .github/workflows && printf 'on: push\n' > .github/workflows/w.yml
  run "${kit_checkout}/bin/kit" context --json .github/workflows/w.yml
  [ "$(jq -c .kinds <<<"$output")" = '["any","text","workflows","yaml"]' ]
  [ "$(jq -c .rules <<<"$output")" = '[".kit/rules/workflows.md",".kit/rules/bash.md"]' ]
}

@test "a repository package adds a kind with its rule, and replaces a delivered kind to widen it" {
  mkdir -p .kit/packages/toml/files/repo/.kit/kinds .kit/packages/toml/files/repo/.kit/rules
  printf 'description: "The TOML kind and its rule"\ndepends:\n  - kit\n' > .kit/packages/toml/package.yml
  printf '# The TOML kind\nname: toml\npaths:\n  - "**/*.toml"\n' > .kit/packages/toml/files/repo/.kit/kinds/toml.yml
  printf -- '---\nkind:\n  - toml\n---\n# TOML\n\nQuote every key.\n' > .kit/packages/toml/files/repo/.kit/rules/toml.md
  run "${kit_checkout}/bin/kit" packages add toml
  [ "$status" -eq 0 ]
  run "${kit_checkout}/bin/kit" context Cargo.toml
  [ "$output" = ".kit/rules/toml.md" ]
  mkdir -p .kit/packages/mdx/files/repo/.kit/kinds
  printf 'description: "Markdown with components counts as markdown"\ndepends:\n  - kit\n' > .kit/packages/mdx/package.yml
  printf '# The markdown kind, with .mdx\nname: markdown\npaths:\n  - "**/*.md"\n  - "**/*.mdx"\n' > .kit/packages/mdx/files/repo/.kit/kinds/markdown.yml
  run "${kit_checkout}/bin/kit" packages add mdx
  [ "$status" -eq 0 ]
  run "${kit_checkout}/bin/kit" context docs/page.mdx
  [ "$output" = ".kit/rules/markdown.md" ]
  run "${kit_checkout}/bin/kit" check
  [ "$status" -eq 0 ]
}

@test "a kind is named by its name:, never by its file, one file may define several, a kind may be made of others, and a nameless or doubled kind is refused" {
  mkdir -p .kit/packages/conf/files/repo/.kit/kinds .kit/packages/conf/files/repo/.kit/rules
  printf 'description: "Two configuration kinds in one file"\ndepends:\n  - kit\n' > .kit/packages/conf/package.yml
  printf '# configuration\nname: toml\npaths:\n  - "**/*.toml"\n---\nname: ini\npaths:\n  - "**/*.ini"\n' \
    > .kit/packages/conf/files/repo/.kit/kinds/config.yml
  printf -- '---\nkind:\n  - toml\n---\n# TOML\n' > .kit/packages/conf/files/repo/.kit/rules/toml.md
  printf -- '---\nkind:\n  - ini\n---\n# INI\n' > .kit/packages/conf/files/repo/.kit/rules/ini.md
  run "${kit_checkout}/bin/kit" packages add conf
  [ "$status" -eq 0 ]
  run "${kit_checkout}/bin/kit" context --json Cargo.toml setup.ini
  [ "$(jq -sc 'map(.kinds)' <<<"$output")" = '[["any","toml"],["any","ini"]]' ]
  [ "$(jq -sc 'map(.rules)' <<<"$output")" = '[[".kit/rules/toml.md"],[".kit/rules/ini.md"]]' ]
  printf -- '---\nname: config\nkinds:\n  - toml\n  - ini\n' >> .kit/packages/conf/files/repo/.kit/kinds/config.yml
  run "${kit_checkout}/bin/kit" context --json setup.ini
  [ "$(jq -c .kinds <<<"$output")" = '["any","config","ini"]' ]
  printf '# configuration\nname: toml\npaths:\n  - "**/*.toml"\n---\npaths:\n  - "**/*.ini"\n' \
    > .kit/packages/conf/files/repo/.kit/kinds/config.yml
  run "${kit_checkout}/bin/kit" context Cargo.toml
  [ "$status" -eq 1 ]
  [[ "$output" == *".kit/kinds/config.yml: a kind has no name:"* ]]
  printf 'name: toml\npaths:\n  - "**/*.toml"\n---\nname: toml\npaths:\n  - "**/*.tml"\n' \
    > .kit/packages/conf/files/repo/.kit/kinds/config.yml
  run "${kit_checkout}/bin/kit" context Cargo.toml
  [ "$status" -eq 1 ]
  [[ "$output" == *".kit/kinds/config.yml: the kind toml is defined twice"* ]]
}

@test "a style the repository takes is printed after the rule, and the hook asks for each to be read" {
  "${kit_checkout}/bin/kit" packages add style/bash >/dev/null 2>&1
  run "${kit_checkout}/bin/kit" context lib/run.sh
  [ "${lines[0]}" = ".kit/rules/bash.md" ]
  [ "${lines[1]}" = ".kit/styles/bash.md" ]
  [ "${#lines[@]}" -eq 2 ]
  input=$(printf '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"%s/lib/run.sh"}}' "${PWD}")
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" \
    = "kit: lib/run.sh is governed by .kit/rules/bash.md .kit/styles/bash.md; read each before this change." ]
}

@test "the claude hook names the rules of the file about to be written, and nothing for a file none governs" {
  input=$(printf '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"%s/lib/run.sh"}}' "${PWD}")
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = "PreToolUse" ]
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" \
    = "kit: lib/run.sh is governed by .kit/rules/bash.md; read it before this change." ]
  [ "$(cut -f 2 .git/kit/context.log)" = "lib/run.sh" ]
  input='{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"x.bin"}}'
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the claude hook names a set of rules once for a session, and again for a new session or another set" {
  hook() { printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s/%s"}}' "$1" "${PWD}" "$2" \
    | "${kit_checkout}/bin/kit" context --claude; }
  [[ "$(hook s1 lib/run.sh)" == *"lib/run.sh is governed by .kit/rules/bash.md"* ]]
  [ -z "$(hook s1 lib/other.sh)" ]
  [[ "$(hook s2 lib/other.sh)" == *"lib/other.sh is governed by .kit/rules/bash.md"* ]]
  "${kit_checkout}/bin/kit" packages add style/bash >/dev/null 2>&1
  [[ "$(hook s1 lib/run.sh)" == *".kit/rules/bash.md .kit/styles/bash.md"* ]]
}

@test "a file in another checkout of the repository is governed by that checkout's rules, each named so it opens from where it was asked" {
  git add --all && git commit --quiet --message=init
  git worktree add --quiet -b 7-fix-the-thing worktrees/7-fix-the-thing
  desk=$(pwd -P)
  wt=worktrees/7-fix-the-thing
  # the branch adds a kind and its rule, which the desk does not have
  mkdir -p "${wt}/.kit/packages/toml/files/repo/.kit/kinds" "${wt}/.kit/packages/toml/files/repo/.kit/rules"
  printf 'description: "The TOML kind and its rule"\ndepends:\n  - kit\n' > "${wt}/.kit/packages/toml/package.yml"
  printf '# The TOML kind\nname: toml\npaths:\n  - "**/*.toml"\n' > "${wt}/.kit/packages/toml/files/repo/.kit/kinds/toml.yml"
  printf -- '---\nkind:\n  - toml\n---\n# TOML\n' > "${wt}/.kit/packages/toml/files/repo/.kit/rules/toml.md"
  (cd "${wt}" && "${kit_checkout}/bin/kit" packages add toml) >/dev/null 2>&1
  # a workflow's glob is anchored at its checkout's root, and the worktree's own kind is no kind at the desk
  run "${kit_checkout}/bin/kit" context "${wt}/.github/workflows/w.yml" "${wt}/Cargo.toml" Cargo.toml README.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "${wt}/.kit/rules/workflows.md" ]
  [ "${lines[1]}" = "${wt}/.kit/rules/bash.md" ]
  [ "${lines[2]}" = "${wt}/.kit/rules/toml.md" ]
  [ "${lines[3]}" = ".kit/rules/markdown.md" ]
  [ "${#lines[@]}" -eq 4 ]
  # each ask is logged once, by the checkout that answered it
  [ "$(cut -f 2 .git/kit/context.log | paste -s -d ' ' -)" = ".github/workflows/w.yml Cargo.toml Cargo.toml README.md" ]
  run "${kit_checkout}/bin/kit" context --json "${wt}/.github/workflows/w.yml" README.md
  [ "$status" -eq 0 ]
  [ "$(jq -r .path <<<"${lines[0]}")" = "${wt}/.github/workflows/w.yml" ]
  [ "$(jq -c .kinds <<<"${lines[0]}")" = '["any","text","workflows","yaml"]' ]
  [ "$(jq -c .rules <<<"${lines[0]}")" = "[\"${wt}/.kit/rules/workflows.md\",\"${wt}/.kit/rules/bash.md\"]" ]
  [ "$(jq -c .rules <<<"${lines[1]}")" = '[".kit/rules/markdown.md"]' ]
  # the harness runs the hook at the desk, and names the file by its absolute path
  input=$(printf '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"%s/%s/.github/workflows/w.yml"}}' \
    "${desk}" "${wt}")
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" \
    = "kit: ${wt}/.github/workflows/w.yml is governed by ${wt}/.kit/rules/workflows.md ${wt}/.kit/rules/bash.md; read each before this change." ]
  # from the worktree, a file at the desk is the desk's, and neither path is under the worktree
  cd "${wt}"
  run "${kit_checkout}/bin/kit" context ../../README.md ../../Cargo.toml Cargo.toml
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "${desk}/.kit/rules/markdown.md" ]
  [ "${lines[1]}" = ".kit/rules/toml.md" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "kit kinds, kit lint, and kit new file give a file in another checkout the answer that checkout gives" {
  git add --all && git commit --quiet --message=init
  git worktree add --quiet -b 7-fix-the-thing worktrees/7-fix-the-thing
  desk=$(pwd -P)
  wt=worktrees/7-fix-the-thing
  # the branch adds a kind, its rule, and a template, which the desk does not have
  mkdir -p "${wt}/.kit/packages/toml/files/repo/.kit/kinds" "${wt}/.kit/packages/toml/files/repo/.kit/rules"
  printf 'description: "The TOML kind and its rule"\ndepends:\n  - kit\n' > "${wt}/.kit/packages/toml/package.yml"
  printf '# The TOML kind\nname: toml\npaths:\n  - "**/*.toml"\n' > "${wt}/.kit/packages/toml/files/repo/.kit/kinds/toml.yml"
  printf -- '---\nkind:\n  - toml\n---\n# TOML\n' > "${wt}/.kit/packages/toml/files/repo/.kit/rules/toml.md"
  (cd "${wt}" && "${kit_checkout}/bin/kit" packages add toml \
    && "${kit_checkout}/bin/kit" new template toml file --package=toml) >/dev/null 2>&1
  # kinds: a workflow's glob is anchored at its checkout's root, and the worktree's own kind is no kind at the desk
  run "${kit_checkout}/bin/kit" kinds "${wt}/.github/workflows/w.yml"
  [ "$status" -eq 0 ]
  [ "$output" = $'any\ntext\nworkflows\nyaml' ]
  run "${kit_checkout}/bin/kit" kinds "${wt}/Cargo.toml" Cargo.toml
  [ "$output" = "${wt}/Cargo.toml"$'\tany toml\nCargo.toml\tany' ]
  run "${kit_checkout}/bin/kit" kinds --json "${wt}/Cargo.toml" Cargo.toml
  [ "$output" = "{\"path\":\"${wt}/Cargo.toml\",\"kinds\":[\"any\",\"toml\"]}"$'\n{"path":"Cargo.toml","kinds":["any"]}' ]
  # lint: the worktree's workflows rule refuses what the desk has no rule for, a file or the directory above it
  mkdir -p "${wt}/.github/workflows"
  printf 'name: w\non: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n' \
    > "${wt}/.github/workflows/w.yml"
  git -C "${wt}" add .github  # a directory stands for the tracked files under it
  for named in "${wt}/.github/workflows/w.yml" "${wt}/.github" "${wt}"
  do
    run "${kit_checkout}/bin/kit" lint "${named}"
    [ "$status" -eq 1 ] || { echo "${named}: ${output}"; false; }
    [[ "$output" == *"${wt}: kit lint runs in that checkout"* ]]
    [[ "$output" == *".github/workflows/w.yml:7: uses: actions/checkout@v4 is not pinned to a commit SHA"* ]]
  done
  # paths of both checkouts are linted, each by its own, and one refusal fails the call
  printf '#!/usr/bin/env bash\necho ok\n' > clean.sh
  run "${kit_checkout}/bin/kit" lint clean.sh "${wt}/.github/workflows/w.yml"
  [ "$status" -eq 1 ]
  [[ "$output" == *".kit/rules/bash.md: shellcheck"*"over 1 path(s)"* ]]
  [[ "$output" == *"uses: actions/checkout@v4 is not pinned"* ]]
  git -C "${wt}" rm --quiet --force .github/workflows/w.yml
  run "${kit_checkout}/bin/kit" lint clean.sh "${wt}/.kit/packages/toml/package.yml"
  [ "$status" -eq 0 ] || { echo "${output}"; false; }
  # new file: the worktree's template makes the file there, and its rules are named so they open from the desk
  run --separate-stderr "${kit_checkout}/bin/kit" new file "${wt}/Cargo.toml" --body='[package]'
  [ "$status" -eq 0 ] || { echo "${stderr}"; false; }
  [ "$output" = "${wt}/.kit/rules/toml.md" ]
  [[ "$stderr" == *"${wt}: kit new file runs in that checkout"* ]]
  [[ "$stderr" == *"made Cargo.toml from .kit/templates/toml/file"* ]]
  [ "$(cat "${wt}/Cargo.toml")" = '[package]' ]
  # from the worktree, a file at the desk is the desk's: its kinds, and its templates, which have none for TOML
  cd "${wt}"
  run "${kit_checkout}/bin/kit" kinds ../../Cargo.toml Cargo.toml
  [ "$output" = "${desk}/Cargo.toml"$'\tany\nCargo.toml\tany toml' ]
  run "${kit_checkout}/bin/kit" new file "${desk}/notes.toml" --body=x
  [ "$status" -eq 2 ]
  [[ "$output" == *"no template governs notes.toml"* ]]
  [ ! -e "${desk}/notes.toml" ]
}

@test "a file in a clone that is no checkout of the repository is governed from where it was asked, and a checkout that cannot answer is named" {
  git add --all && git commit --quiet --message=init
  git init --quiet vendor/lib
  run "${kit_checkout}/bin/kit" context vendor/lib/run.sh vendor/lib/.github/workflows/w.yml
  [ "$status" -eq 0 ]
  [ "$output" = ".kit/rules/bash.md" ]
  # a worktree whose kinds cannot be read fails the ask, and the refusal says which checkout it was
  git worktree add --quiet -b 7-fix-the-thing worktrees/7-fix-the-thing
  wt=worktrees/7-fix-the-thing
  mkdir -p "${wt}/.kit/packages/toml/files/repo/.kit/kinds"
  printf 'description: "The TOML kind"\ndepends:\n  - kit\n' > "${wt}/.kit/packages/toml/package.yml"
  printf 'name: toml\npaths:\n  - "**/*.toml"\n' > "${wt}/.kit/packages/toml/files/repo/.kit/kinds/toml.yml"
  (cd "${wt}" && "${kit_checkout}/bin/kit" packages add toml) >/dev/null 2>&1
  printf 'paths:\n  - "**/*.toml"\n' > "${wt}/.kit/packages/toml/files/repo/.kit/kinds/toml.yml"
  run "${kit_checkout}/bin/kit" context "${wt}/Cargo.toml"
  [ "$status" -eq 1 ]
  [[ "$output" == *".kit/kinds/toml.yml: a kind has no name:"* ]]
  [[ "$output" == *"${wt}, the checkout ${wt}/Cargo.toml is in, could not answer"* ]]
  run "${kit_checkout}/bin/kit" context --json "${wt}/Cargo.toml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"${wt}, the checkout ${wt}/Cargo.toml is in, could not answer"* ]]
  input=$(printf '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"%s/%s/Cargo.toml"}}' "${PWD}" "${wt}")
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$status" -eq 1 ]
  [[ "$output" != *hookSpecificOutput* ]]
}

@test "a kinds file is YAML: CRLF endings, a flow list, a quoted name, a comment after an item, and a leading --- all read" {
  mkdir -p .kit/packages/conf/files/repo/.kit/kinds .kit/packages/conf/files/repo/.kit/rules
  printf 'description: "Two configuration kinds in one file"\ndepends:\n  - kit\n' > .kit/packages/conf/package.yml
  printf -- '---\r\n# configuration\r\nname: "toml"\r\npaths: ["**/*.toml", "**/*.tml"] # both spellings\r\n---\r\nname: ini\r\npaths:\r\n  - "**/*.ini" # windows\r\n---\r\n' \
    > .kit/packages/conf/files/repo/.kit/kinds/config.yml
  printf -- '---\r\nkind: [toml, ini]\r\n---\r\n# Configuration\r\n' > .kit/packages/conf/files/repo/.kit/rules/config.md
  run "${kit_checkout}/bin/kit" packages add conf
  [ "$status" -eq 0 ]
  run "${kit_checkout}/bin/kit" context --json Cargo.toml build.tml setup.ini
  [ "$status" -eq 0 ]
  [ "$(jq -sc 'map(.kinds)' <<<"$output")" = '[["any","toml"],["any","toml"],["any","ini"]]' ]
  [ "$(jq -sc 'map(.rules)' <<<"$output")" = '[[".kit/rules/config.md"],[".kit/rules/config.md"],[".kit/rules/config.md"]]' ]
  run "${kit_checkout}/bin/kit" kinds --json toml ini
  [ "$status" -eq 0 ]
  [ "$(jq -sc 'map([.name, .paths])' <<<"$output")" = '[["ini",["**/*.ini"]],["toml",["**/*.toml","**/*.tml"]]]' ]
}

@test "a repository with no kinds at all governs nothing: kit context prints nothing and exits 0, as does the hook" {
  fresh-repo bare >/dev/null
  run "${kit_checkout}/bin/kit" context foo.sh
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "${kit_checkout}/bin/kit" context --json foo.sh
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.kinds, .rules]' <<<"$output")" = '[[],[]]' ]
  input='{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"foo.sh"}}'
  run "${kit_checkout}/bin/kit" context --claude <<<"${input}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "two lookups that compile changed kinds at once both succeed and say nothing, though both prune the old matcher" {
  # kit context --json asks for a path's kinds twice at once; after the kinds change, both compile them and both
  # prune the old matcher, so the one that finds it gone already must say nothing, or its words land in the JSON
  "${kit_checkout}/bin/kit" hydrate >/dev/null 2>&1
  kit_bash_modules=context run kit-bash '
    dir="$(git rev-parse --path-format=absolute --git-common-dir)/kit"
    mkdir -p "${dir}"
    for round in $(seq 40)
    do
      : > "${dir}/kinds-0.awk"
      rm -f "${dir}"/kinds-[1-9]*.awk
      context:matcher >/dev/null & context:matcher >/dev/null & wait
    done'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # the matcher of other kinds is younger than a day, so another worktree may be using it
  [ -f "$(git rev-parse --path-format=absolute --git-common-dir)/kit/kinds-0.awk" ]
}

@test "a compile prunes a matcher of other kinds older than a day, and only that one" {
  local dir
  dir="$(git rev-parse --path-format=absolute --git-common-dir)/kit"
  mkdir -p "${dir}"
  rm -f "${dir}"/kinds-*.awk
  : > "${dir}/kinds-1.awk"
  : > "${dir}/kinds-2.awk"
  touch -t 202001010000 "${dir}/kinds-1.awk"
  run "${kit_checkout}/bin/kit" context README.md
  [ "$status" -eq 0 ]
  [ "$output" = ".kit/rules/markdown.md" ]
  [ ! -e "${dir}/kinds-1.awk" ]
  [ -f "${dir}/kinds-2.awk" ]
}

@test "a lookup touches the matcher it uses, so its age is the time since its last use" {
  local dir file
  "${kit_checkout}/bin/kit" context README.md >/dev/null
  dir="$(git rev-parse --path-format=absolute --git-common-dir)/kit"
  for file in "${dir}"/kinds-*.awk
  do
    touch -t 202001010000 "${file}"
  done
  run --separate-stderr "${kit_checkout}/bin/kit" context README.md
  [ "$status" -eq 0 ]
  [ "$output" = ".kit/rules/markdown.md" ]
  [ -n "$(find "${dir}" -name 'kinds-*.awk' -mmin -1440)" ]
}

@test "a matcher of no kinds that a repository with no kit compiled is never taken where a kit is declared" {
  rm -f .kit/kinds/*.yml
  mv kit.yml kit.yml.off
  mv .kit/manifest manifest.off
  kit_bash_modules=context run kit-bash 'printf "README.md\n" | context:classify'
  [ "$status" -eq 0 ]
  [ "$output" = "README.md"$'\t' ]
  mv kit.yml.off kit.yml
  mv manifest.off .kit/manifest
  kit_bash_modules=context run kit-bash 'printf "README.md\n" | context:classify'
  [ "$status" -eq 1 ]
  [[ "$output" == *"no kind is defined under .kit/kinds; run: cd "*" && kit hydrate"* ]]
  [[ "$output" != *"README.md"$'\t'* ]]
}

@test "a matcher another compile prunes between its lookup and its read is compiled again, never read as no kinds" {
  # the first lookup's matcher is taken away before classify reads it, as another worktree's prune would
  kit_bash_modules=context run kit-bash '
    eval "$(declare -f context:matcher | sed "1s/^context:matcher /context:matcher-real /")"
    context:matcher() {
      local file
      file=$(context:matcher-real) || return 1
      if [[ ! -e "${file}.taken" ]]
      then
        : > "${file}.taken"
        rm -f "${file}"
      fi
      printf "%s\n" "${file}"
    }
    printf "README.md\n" | context:classify'
  [ "$status" -eq 0 ]
  [[ "$output" == "README.md"$'\t'*"markdown"* ]]
}

@test "a compiled matcher awk cannot run fails the lookup, and is never read as no kinds" {
  local dir file
  "${kit_checkout}/bin/kit" context README.md >/dev/null
  dir="$(git rev-parse --path-format=absolute --git-common-dir)/kit"
  for file in "${dir}"/kinds-*.awk
  do
    printf 'BEGIN {\n' > "${file}"
  done
  run "${kit_checkout}/bin/kit" context README.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"awk cannot run the compiled kinds"* ]]
  [[ "$output" != *".kit/rules/"* ]]
}

@test "a rule whose frontmatter cannot be read fails kit context, and never reads as a rule that governs nothing" {
  printf -- '---\nkind: [one\n---\n# x\n' > .kit/rules/broken.md
  run --separate-stderr "${kit_checkout}/bin/kit" context README.md
  [ "$status" -eq 1 ]
  [[ "$stderr" == *".kit/rules/broken.md"* ]]
  [ -z "$output" ]
}

@test "a glob with a bracket that never closes matches the bracket itself, and ends" {
  # a watchdog ends the test if the glob never ends, as it did
  kit_bash_modules=context run kit-bash '(sleep 10; kill $$) & context:glob-ere "docs/[draft*.md"; kill $!'
  [ "$status" -eq 0 ]
  [ "$output" = '^docs/\[draft.*\.md$' ]
}

@test "a repository that declares a kit version and has no kind says so, and names kit hydrate" {
  # a verb hydrates first and puts the kinds back, so the lookup runs alone, as a hook's would under kit serve
  rm -f .kit/kinds/*.yml
  kit_bash_modules=context run kit-bash 'context:load'
  [ "$status" -eq 1 ]
  [[ "$output" == *"no kind is defined under .kit/kinds; run: cd "*" && kit hydrate"* ]]
  kit_bash_modules=context run kit-bash 'printf "README.md\n" | context:classify'
  [ "$status" -eq 1 ]
  [[ "$output" != *"README.md"$'\t'* ]]
  # a verb puts the kinds back, and finds them
  run --separate-stderr "${kit_checkout}/bin/kit" context README.md
  [ "$status" -eq 0 ]
  [ "$output" = ".kit/rules/markdown.md" ]
  [ -f .kit/kinds/markdown.yml ]
}

# ----------------------------------------------------------------------------------------------------------------------
