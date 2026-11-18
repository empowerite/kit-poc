#!/usr/bin/env bats
# workflow.bats - the workflow package: the workflow, plans as prose, and the worker contract, apart from the entry file
# ----------------------------------------------------------------------------------------------------------------------
# Each test gets an empty git repository under a temporary directory and runs the kit from this checkout against
# it. The kit package delivers the rules every repository takes; the workflow package delivers the taste a repository
# may leave out, and the entry file points to it only as a file that may be there.

bats_require_minimum_version 1.5.0

load helper

setup() {
  fresh-repo
}

@test "install's last line names the file the workflow is in with the package, and says whether an agent is sent to .kit/1st.md" {
  run "${kit_checkout}/bin/kit" install workflow agents/generic
  [ "$status" -eq 0 ]
  [[ "${lines[${#lines[@]} - 1]}" == *"The workflow is in .kit/workflow.md." ]]
  run "${kit_checkout}/bin/kit" uninstall
  # no agents package: nothing sends an agent to the entry file, and the line names the command that adds one
  run "${kit_checkout}/bin/kit" install workflow
  [ "$status" -eq 0 ]
  [[ "${lines[${#lines[@]} - 1]}" == *"The workflow is in .kit/workflow.md. No agent is sent to .kit/1st.md yet; run: kit packages add agents/generic"* ]]
  run "${kit_checkout}/bin/kit" uninstall
  run "${kit_checkout}/bin/kit" install
  [ "$status" -eq 0 ]
  [ ! -e AGENTS.md ]
  [[ "$output" != *"The workflow is in"* ]]
  [[ "$output" != *"Every agent reads"* ]]
  [[ "${lines[${#lines[@]} - 1]}" == *"ignored. No agent is sent to .kit/1st.md yet; run: kit packages add agents/generic"* ]]
  # the command it names makes an agent read the entry file, and the line then says so
  run "${kit_checkout}/bin/kit" packages add agents/generic
  [ "$status" -eq 0 ]
  grep --quiet '\.kit/1st\.md' AGENTS.md
  run "${kit_checkout}/bin/kit" update
  [ "$status" -eq 0 ]
  [[ "$output" != *"No agent is sent"* ]]
  [[ "${lines[${#lines[@]} - 1]}" == *"Every agent reads .kit/1st.md first." ]]
  # without the kit package there is no entry file, and the line names none
  run "${kit_checkout}/bin/kit" packages remove agents/generic kit
  [ "$status" -eq 0 ]
  run "${kit_checkout}/bin/kit" update
  [ "$status" -eq 0 ]
  [[ "${lines[${#lines[@]} - 1]}" == *"what it placed under .kit/ is ignored." ]]
}

@test "kit install alone delivers the entry file without the workflow, the worker contract, or a forge's command" {
  run "${kit_checkout}/bin/kit" install
  [ "$status" -eq 0 ]
  [ -f .kit/1st.md ]
  [ ! -e .kit/workflow.md ]
  grep --quiet '^## Integrity$' .kit/1st.md
  grep --quiet '^## Kit commands instead of git commands$' .kit/1st.md
  run -1 grep --quiet 'The worker contract' .kit/1st.md
  run -1 grep --quiet 'Plans are prose' .kit/1st.md
  run -1 grep --quiet 'gh pr ready' .kit/1st.md
  # the entry file names the file the workflow package delivers, so an agent knows where to look when it is there
  grep --quiet '^## The workflow$' .kit/1st.md
  grep --quiet 'workflow.md' .kit/1st.md
}

@test "kit install workflow delivers .kit/workflow.md: the workflow, plans as prose, and the worker contract, forge-neutral" {
  run "${kit_checkout}/bin/kit" install workflow
  [ "$status" -eq 0 ]
  [ -f .kit/workflow.md ]
  [ "$(head -n 1 .kit/workflow.md)" = '<!-- kit:generated -- the workflow from an issue to a merged pull request, from the workflow package -->' ]
  grep --quiet '^## The worker contract$' .kit/workflow.md
  grep --quiet '^## Plans are prose$' .kit/workflow.md
  grep --quiet 'what was left out, and why' .kit/workflow.md
  # every forge marks a change ready the one way, the draft's stand-in with it
  grep --quiet 'kit ready' .kit/workflow.md
  run -1 grep --quiet 'glab mr update --ready' .kit/workflow.md
  # the report the workflow asks for has a command that writes it, in the workflow's step and in the worker's
  [ "$(grep --count 'kit ready --report-file=<path>' .kit/workflow.md)" -eq 2 ]
  run "${kit_checkout}/bin/kit" packages remove workflow
  [ "$status" -eq 0 ]
  [ ! -e .kit/workflow.md ]
  [ -f .kit/1st.md ]
}

# ----------------------------------------------------------------------------------------------------------------------
