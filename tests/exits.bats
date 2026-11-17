#!/usr/bin/env bats
# exits.bats - every verb's header ends its description with one Exits line, stating its codes as docs/modules.md has them
# ----------------------------------------------------------------------------------------------------------------------

load helper

# one-exits-line <shard> <shards> checks, for every <shards>th verb from the <shard>th, that its header has exactly one
# Exits line, and that kit help prints it. The verbs are split into shards, tests of their own, as bats --jobs runs
# them side by side.
one-exits-line() {
  local verb count
  for verb in $(verb-shard "$1" "$2")
  do
    count=$(awk 'NR > 1 && !/^#/ { exit } /^# Exits / { n++ } END { print n + 0 }' "${kit_root}/bin/kit-${verb}")
    [ "${count}" -eq 1 ] || { echo "${verb}: ${count} Exits line(s) in its header"; return 1; }
    run "${kit_root}/bin/kit" help "${verb}"
    [[ "$output" == *$'\n\nExit status\n  Exits '* ]] || { echo "${verb}: kit help prints no Exits line"; return 1; }
  done
}

@test "every verb's header has exactly one line that starts with Exits, and kit help prints it under Exit status: shard 1 of 4" {
  one-exits-line 1 4
}

@test "every verb's header has exactly one line that starts with Exits, and kit help prints it under Exit status: shard 2 of 4" {
  one-exits-line 2 4
}

@test "every verb's header has exactly one line that starts with Exits, and kit help prints it under Exit status: shard 3 of 4" {
  one-exits-line 3 4
}

@test "every verb's header has exactly one line that starts with Exits, and kit help prints it under Exit status: shard 4 of 4" {
  one-exits-line 4 4
}

@test "an Exits line names 2, the guard's status for a usage error, and every status its verb's own file exits with" {
  local verb name exits status
  for verb in "${kit_root}"/bin/kit-*
  do
    [[ -x "${verb}" ]] || continue
    name=${verb##*/kit-}
    # the header's paragraph from its Exits line to the next line of a lone #, on one line
    exits=$(awk '/^# Exits / { on = 1 } on && /^#$/ { exit } on { sub(/^# ?/, ""); print }' "${verb}" | paste -s -d ' ' -)
    for status in 2 $(grep --only-matching --extended-regexp '\bexit [0-9]+' "${verb}" | cut -d ' ' -f 2 | sort -u)
    do
      [[ "${exits}" =~ (Exits|,|;|and|or)\ ${status}[\ ,.] ]] \
        || { echo "kit ${name}: its Exits line does not name ${status}"; return 1; }
    done
  done
}

# ----------------------------------------------------------------------------------------------------------------------
