# shellcheck shell=bash
# builds.sh - the forge's runs not owned by any pull request, drawn as kit flow draws them (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2154  # flow_gap is set by modules/bash/flow.sh
#
# The builds stage of kit flow sits between changes and releases. It lists the recent runs that no pull request
# owns, as forge:runs keeps them:
#
#   - pushes to the default branch
#   - pushes to a tag
#   - scheduled and manually started runs, on any branch
#
# A run for a pull request stays under changes, so no run shows twice.
#
# see: kit/bin/kit-flow, modules/bash/flow.sh, modules/bash/forge.sh, modules/jq/forge.jq

use forge flow workspaces

# builds:documents prints the forge's runs, newest first, as one JSON array: id, number, attempt, workflow, branch,
# tag, event, sha, title, state, age, took, url, and jobs, each.
builds:documents() {
  forge:require || return 1
  # A forge without runs has none to list.
  forge:runs || { (( $? == 3 )) && printf '[]\n'; }
}

# Each helper of a run's cell sets a variable, as the cells of modules/bash/flow.sh do, so a row starts no process.

# builds:glyph-to <name> <state> sets the variable <name> to a run's state glyph: the check glyphs the changes stage
# draws, and 🛑 for cancelled.
builds:glyph-to() {
  case "$2" in
    (running) printf -v "$1" '%s' "${flow_glyphs[Running]}" ;;
    (passed) printf -v "$1" '%s' "${flow_glyphs[Passed]}" ;;
    (failed) printf -v "$1" '%s' "${flow_glyphs[Failed]}" ;;
    (*) printf -v "$1" '%s' "${flow_glyphs[Cancelled]}" ;;
  esac
}

# builds:took-to <name> <seconds> sets the variable <name> to how long a run took: 42s, 3m 36s, 1h 05m; and to … for
# none, while it runs.
builds:took-to() {
  local builds_to_secs=$2
  if [[ -z "${builds_to_secs}" || "${builds_to_secs}" == null ]]
  then printf -v "$1" '…'
  elif (( builds_to_secs < 60 ))
  then printf -v "$1" '%ds' "${builds_to_secs}"
  elif (( builds_to_secs < 3600 ))
  then printf -v "$1" '%dm %02ds' $(( builds_to_secs / 60 )) $(( builds_to_secs % 60 ))
  else printf -v "$1" '%dh %02dm' $(( builds_to_secs / 3600 )) $(( builds_to_secs % 3600 / 60 ))
  fi
}

# builds:event-to <name> <event> <tag> sets the variable <name> to how a run began, in a word: tag for a push to a
# tag, push, schedule, or manual.
builds:event-to() {
  if [[ "$3" == true ]]
  then
    printf -v "$1" 'tag'
  else
    case "$2" in
      (workflow_dispatch) printf -v "$1" 'manual' ;;
      (*) printf -v "$1" '%s' "$2" ;;
    esac
  fi
}

# builds:draw <runs-json> prints the runs, one row each: the state glyph, the workflow, the run's number, how it
# began, the branch or tag, the commit's short hash, the run's title, the age, and how long the run took. The
# number, how it began, and the hash are dim; the age and the time taken are numbers, so they are right-aligned and
# dim. A title that only repeats the workflow is left out, and so is a column no run fills. The title gives way first
# to what the terminal's width leaves, then the branch, then the workflow, none below 10, each clipped with an
# ellipsis. With none it says so in one dim line. One jq reads every run's fields, so the table starts the same
# processes whatever its length.
builds:draw() {
  local doc=$1 row state workflow number event tag branch sha title age took room excess name floor give line cell
  local workflow_w=0 number_w=0 event_w=0 branch_w=0 sha_w=0 title_w=0 age_w=0 took_w=0
  local -a rows=()
  if [[ "$(jq 'length' <<<"${doc}")" == 0 ]]
  then
    flow:none 'no build since the last 20 runs'
    return 0
  fi
  readarray -t rows < <(jq --raw-output '.[] | [.state, .workflow, (if .number then "#\(.number)" else "" end),
    .event, .tag, .branch, .sha, (if .title == .workflow then "" else .title end), .age, .took]
    | map(. // "" | tostring) | join("\u001f")' <<<"${doc}")
  for row in "${rows[@]}"
  do
    IFS=$'\x1f' read -r state workflow number event tag branch sha title age took <<<"${row}"
    builds:event-to event "${event}" "${tag}"
    flow:age-to age "${age}"
    builds:took-to took "${took}"
    (( ${#workflow} > workflow_w )) && workflow_w=${#workflow}
    (( ${#number} > number_w )) && number_w=${#number}
    (( ${#event} > event_w )) && event_w=${#event}
    (( ${#branch} > branch_w )) && branch_w=${#branch}
    (( ${#sha} > sha_w )) && sha_w=${#sha}
    (( ${#title} > title_w )) && title_w=${#title}
    (( ${#age} > age_w )) && age_w=${#age}
    (( ${#took} > took_w )) && took_w=${#took}
  done
  # The glyph and its gap, and the dim and numeric columns with their gaps, are fixed; the workflow, the branch, and
  # the title share the rest.
  room=$(( $(flow:width) - 4 - (2 + event_w) - (2 + age_w) - (2 + took_w) - 2 ))
  (( number_w > 0 )) && room=$(( room - 2 - number_w ))
  (( sha_w > 0 )) && room=$(( room - 2 - sha_w ))
  (( title_w > 0 )) && room=$(( room - 2 ))
  excess=$(( workflow_w + branch_w + title_w - room ))
  for name in title_w branch_w workflow_w
  do
    (( excess > 0 )) || break
    floor=$(( ${!name} < 10 ? ${!name} : 10 ))
    give=$(( ${!name} - floor < excess ? ${!name} - floor : excess ))
    printf -v "${name}" '%d' $(( ${!name} - give ))
    excess=$(( excess - give ))
  done
  for row in "${rows[@]}"
  do
    IFS=$'\x1f' read -r state workflow number event tag branch sha title age took <<<"${row}"
    builds:glyph-to line "${state}"
    flow:cell-to cell "${workflow}" "${workflow_w}"
    line+="  ${cell}"
    if (( number_w > 0 ))
    then
      flow:cell-to cell "${number}" "${number_w}" right 90
      line+="${flow_gap}${cell}"
    fi
    builds:event-to cell "${event}" "${tag}"
    flow:cell-to cell "${cell}" "${event_w}" left 90
    line+="${flow_gap}${cell}"
    flow:cell-to cell "${branch}" "${branch_w}"
    line+="${flow_gap}${cell}"
    if (( sha_w > 0 ))
    then
      flow:cell-to cell "${sha}" "${sha_w}" left 90
      line+="${flow_gap}${cell}"
    fi
    if (( title_w > 0 ))
    then
      flow:cell-to cell "${title}" "${title_w}"
      line+="${flow_gap}${cell}"
    fi
    flow:age-to cell "${age}"
    flow:cell-to cell "${cell}" "${age_w}" right 90
    line+="${flow_gap}${cell}"
    builds:took-to cell "${took}"
    flow:cell-to cell "${cell}" "${took_w}" right 90
    line+="${flow_gap}${cell}"
    printf '%s\n' "${line}"
  done
}

# builds:render [--json] prints the runs as builds:draw does, or with --json as builds:documents does, to stdout, each
# saying where it is from, the forge, as workspaces:placed says.
builds:render() {
  local doc
  doc=$(builds:documents) || return 1
  if [[ " $* " == *" --json "* ]]
  then
    workspaces:placed forge "${doc}"
    return
  fi
  builds:draw "${doc}"
}

# ----------------------------------------------------------------------------------------------------------------------
