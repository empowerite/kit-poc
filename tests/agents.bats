#!/usr/bin/env bats
# agents.bats - the agents/cursor, agents/copilot, and agents/gemini packages deliver each harness's native shapes
# ----------------------------------------------------------------------------------------------------------------------
# Each test gets an empty git repository and runs the kit from this checkout against it. A rule mirror names, in the
# harness's own frontmatter, the paths a rule governs, and its body points at the rule under .kit/rules/, so what is
# proven is that each mirror follows its rule and that the merged settings keep the repository's own entries.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fresh-repo
}

kit() { "${kit_checkout}/bin/kit" "$@"; }

# kinds prints the kind of every rule the kit package delivers.
kinds() {
  local rule
  for rule in "${kit_checkout}"/packages/kit/files/repo/.kit/rules/*.md
  do
    rule=${rule##*/}
    printf '%s\n' "${rule%.md}"
  done
}

# rule-paths <kind> prints the kind's paths: entries, comma-joined, as a harness's glob list.
rule-paths() {
  awk '/^[a-z]+:/ { p = ($0 == "paths:") }
       p && /^  - / { gsub(/^  - "|"$/, ""); printf "%s%s", sep, $0; sep = "," }
       END { printf "\n" }' "${kit_checkout}/packages/kit/files/repo/.kit/kinds/$1.yml"
}

# claude-prefixes prints the command prefixes of the Claude deny list, with one that another covers left out.
claude-prefixes() {
  jq --raw-output '.permissions.deny[] | ltrimstr("Bash(") | rtrimstr(" *)")' \
    "${kit_checkout}/packages/agents/claude/files/repo/.claude/settings.json" \
    | awk '{ all[NR] = $0 } END { for (i in all) { covered = 0; for (j in all) if (i != j && index(all[i], all[j] " ") == 1) covered = 1; if (!covered) print all[i] } }' \
    | sort
}

@test "agents/cursor places one rule mirror per kind, attached by the rule's paths, whose body points at the rule" {
  run kit install agents/cursor
  [ "$status" -eq 0 ]
  local kind globs
  for kind in $(kinds)
  do
    [ -f ".cursor/rules/kit-${kind}.mdc" ]
    [ "$(head -n 1 ".cursor/rules/kit-${kind}.mdc")" = "---" ]
    grep --quiet "^description: ." ".cursor/rules/kit-${kind}.mdc"
    # a kind with no paths, matched by its first line alone, has a globs: line with nothing after it
    globs="globs: $(rule-paths "${kind}")"
    grep --quiet --line-regexp --fixed-strings "${globs% }" ".cursor/rules/kit-${kind}.mdc"
    grep --quiet --line-regexp "alwaysApply: false" ".cursor/rules/kit-${kind}.mdc"
    grep --quiet --fixed-strings "@.kit/rules/${kind}.md" ".cursor/rules/kit-${kind}.mdc"
    grep --quiet --fixed-strings 'run `kit context <path>` and read every file it prints' ".cursor/rules/kit-${kind}.mdc"
    grep --quiet --fixed-strings "  .cursor/rules/kit-${kind}.mdc" .kit/manifest
  done
  [ "$(ls .cursor/rules | wc -l | tr -d ' ')" = "$(kinds | wc -l | tr -d ' ')" ]
  printf 'edited\n' >> .cursor/rules/kit-bash.mdc
  run kit check
  [ "$status" -eq 1 ]
}

@test "agents/copilot places one instruction file per kind, applied to the rule's paths, whose body points at the rule" {
  run kit install agents/copilot
  [ "$status" -eq 0 ]
  local kind
  for kind in $(kinds)
  do
    # a kind with no paths has nothing for applyTo to match, so it has no file
    if [ -z "$(rule-paths "${kind}")" ]
    then
      [ ! -e ".github/instructions/kit-${kind}.instructions.md" ]
      continue
    fi
    [ -f ".github/instructions/kit-${kind}.instructions.md" ]
    [ "$(head -n 1 ".github/instructions/kit-${kind}.instructions.md")" = "---" ]
    grep --quiet --line-regexp --fixed-strings "applyTo: \"$(rule-paths "${kind}")\"" \
      ".github/instructions/kit-${kind}.instructions.md"
    grep --quiet --fixed-strings ".kit/rules/${kind}.md" ".github/instructions/kit-${kind}.instructions.md"
    grep --quiet --fixed-strings 'run `kit context <path>` and read every file it prints' \
      ".github/instructions/kit-${kind}.instructions.md"
    grep --quiet --fixed-strings "  .github/instructions/kit-${kind}.instructions.md" .kit/manifest
  done
  [ "$(ls .github/instructions | wc -l | tr -d ' ')" = "7" ]
}

@test "agents/gemini merges the context file names and the deny list into .gemini/settings.json, keeps the repository's entries, and remove takes the kit's out" {
  mkdir .gemini
  printf '%s\n' '{"context": {"fileName": ["TEAM.md"]}, "tools": {"exclude": ["run_shell_command(rm -rf)"]}, "ui": {"theme": "Dark"}}' \
    > .gemini/settings.json
  run kit install agents/gemini
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '.context.fileName' .gemini/settings.json)" = '["TEAM.md","GEMINI.md","AGENTS.md"]' ]
  [ "$(jq --raw-output '.tools.exclude[0]' .gemini/settings.json)" = 'run_shell_command(rm -rf)' ]
  [ "$(jq --raw-output '.ui.theme' .gemini/settings.json)" = 'Dark' ]
  run kit check
  [ "$status" -eq 0 ]
  run kit packages remove agents/gemini
  [ "$status" -eq 0 ]
  [ "$(jq --compact-output '.context.fileName' .gemini/settings.json)" = '["TEAM.md"]' ]
  [ "$(jq --compact-output '.tools.exclude' .gemini/settings.json)" = '["run_shell_command(rm -rf)"]' ]
  [ "$(jq --raw-output '.ui.theme' .gemini/settings.json)" = 'Dark' ]
}

@test "agents/gemini denies the commands agents/claude denies, as prefixes, which is how Gemini matches a shell command" {
  kit install agents/gemini
  expected=$(claude-prefixes | grep --invert-match '[*]' | sed 's/.*/run_shell_command(&)/')
  [ "$(jq --raw-output '.tools.exclude[]' .gemini/settings.json | sort)" = "${expected}" ]
}

@test "the deny lists refuse a merge on each forge, the git forms that undo or hide work, and git -C before a write" {
  kit install agents/claude agents/gemini
  local denied
  for denied in 'gh pr merge' 'glab mr merge' 'az repos pr update' 'git merge' 'git restore' 'git clean' 'git stash' \
    'git checkout -B' 'git switch -C' 'git switch --create' 'git branch -d' 'git branch --delete'
  do
    jq --exit-status --arg c "Bash(${denied} *)" '.permissions.deny | index($c)' .claude/settings.json >/dev/null
    jq --exit-status --arg c "run_shell_command(${denied})" '.tools.exclude | index($c)' .gemini/settings.json >/dev/null
  done
  for denied in commit push rebase merge 'reset --hard' 'worktree add' 'worktree remove'
  do
    jq --exit-status --arg c "Bash(git -C * ${denied} *)" '.permissions.deny | index($c)' .claude/settings.json >/dev/null
  done
}

@test "the trust is the person's to give: the AGENTS.md region tells an agent to ask them, and the deny lists refuse kit trust" {
  kit install agents/claude agents/gemini
  # the region is in a fresh clone before anything is hydrated, where .kit/1st.md is not; it names no option
  region=$(sed -n '/kit:generate AGENTS.md/,/kit:end AGENTS.md/p' AGENTS.md)
  [[ "${region}" == *'stop and ask the person to run `kit trust`'* ]]
  [[ "${region}" == *'Never run `kit trust` yourself'* ]]
  [[ "${region}" != *--yes* ]]
  grep --quiet --fixed-strings 'An agent never runs `kit trust`' .kit/1st.md
  jq --exit-status '.permissions.deny | index("Bash(kit trust *)")' .claude/settings.json >/dev/null
  jq --exit-status '.tools.exclude | index("run_shell_command(kit trust)")' .gemini/settings.json >/dev/null
}

@test "each agents package merges the kit's MCP server beside the repository's own, tells the person once, and remove takes only the kit's out" {
  printf '{"mcpServers": {"ours": {"command": "ours"}}}\n' > .mcp.json
  run kit install agents/claude
  [ "$status" -eq 0 ]
  [[ "$output" == *".mcp.json: Claude Code asks once, at the start of the next session"* ]]
  jq --exit-status '.mcpServers == {ours: {command: "ours"}, kit: {command: "kit", args: ["serve"]}}' .mcp.json
  run kit check
  [ "$status" -eq 0 ]
  run kit packages add agents/cursor agents/copilot agents/gemini
  [ "$status" -eq 0 ]
  [[ "$output" != *".mcp.json: Claude Code asks"* ]]
  [[ "$output" == *".cursor/mcp.json: Cursor starts the kit server"* ]]
  [[ "$output" == *".vscode/mcp.json: VS Code starts the kit server"* ]]
  [[ "$output" == *".gemini/settings.json: Gemini CLI starts the kit server"* ]]
  jq --exit-status '.mcpServers.kit == {type: "stdio", command: "kit", args: ["serve"]}' .cursor/mcp.json
  jq --exit-status '.servers.kit == {type: "stdio", command: "kit", args: ["serve"]}' .vscode/mcp.json
  jq --exit-status '.mcpServers.kit == {command: "kit", args: ["serve"]}' .gemini/settings.json
  run kit packages remove agents/claude
  [ "$status" -eq 0 ]
  jq --exit-status '.mcpServers == {ours: {command: "ours"}}' .mcp.json
}

# ----------------------------------------------------------------------------------------------------------------------
