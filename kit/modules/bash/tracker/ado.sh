# shellcheck shell=bash
# ado.sh - the Azure DevOps tracker provider: work items, through az boards (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# modules/bash/tracker.sh loads this provider for a prefix whose record sets `provider: ado`. The record gives the
# organization's URL, the project that new work items are created in, and optionally the work item type (default:
# Task):
#
#   trackers:
#     - prefix: "AB#"
#       provider: ado
#       organization: https://dev.azure.com/example
#       project: Claims
#       type: Task
#
# The provider needs the az CLI with its azure-devops extension. No other part of the kit needs az.
#
# A work item is CLOSED in the states Closed, Done, and Removed (the closing states of Azure DevOps' process
# templates) and OPEN in every other state. Closing a work item sets the record's closed_state, or, when it is not
# planned or a duplicate, its removed_state (default: Removed); a duplicate also gets a comment naming the original,
# as Azure DevOps has no duplicate reason. Without a closed_state it closes to Closed, and to Done where its type has
# no Closed: the Agile and CMMI processes close a work item to Closed, and the Basic process, which a new
# organization gets, and the Scrum process to Done. A state Azure Boards refuses fails the close with one line: the
# field of the record that names the state, and then the states tried and what az said last. The caller (me) is the
# identity az is signed in as, which can differ from the login on the forge (GitHub or GitLab).

tracker/ado:assign() {
  local org
  org=$(tracker/ado:organization) || return 1
  az boards work-item update --id "$1" --assigned-to "$2" --org "${org}" --output none 2>/dev/null
}

tracker/ado:assignees() { tracker/ado:read "$1" '.fields["System.AssignedTo"].uniqueName // ""'; }

# tracker/ado:body prints the work item's description, which Azure Boards keeps as HTML, as forge.jq's ado_text reads
# it, and nothing for an empty one.
tracker/ado:body() {
  # shellcheck disable=SC2154  # kit_jq is exported by modules/bash/1st.sh
  tracker/ado:read "$1" -L "${kit_jq}" 'import "forge" as forge;
    .fields["System.Description"] // "" | strings | forge::ado_text | select(. != "")'
}

tracker/ado:close() {
  local org setting=removed_state state said='' tried
  local -a states=(Removed)
  org=$(tracker/ado:organization) || return 1
  if [[ "$2" == completed ]]
  then
    setting=closed_state
    states=(Closed Done)
  fi
  state=$(tracker:field "${TRACKER_PREFIX}" "${setting}")
  [[ -z "${state}" ]] || states=("${state}")
  [[ "$2" != duplicate ]] || tracker/ado:comment "$1" "Duplicate of ${TRACKER_PREFIX}$3" || return 1
  for state in "${states[@]}"
  do
    said=$(az boards work-item update --id "$1" --state "${state}" --org "${org}" --output none 2>&1 >/dev/null) \
      && return 0
  done
  said=${said##*$'\n'}
  tried=${states[0]}${states[1]:+ or ${states[1]}}
  error "set ${setting} in the ${TRACKER_PREFIX} tracker's record in kit.yml to a state of the work item's type, if" \
    "Azure Boards refuses this one (${TRACKER_PREFIX}$1 could not be set to ${tried}${said:+: ${said}})"
  return 1
}

tracker/ado:comment() {
  local org
  org=$(tracker/ado:organization) || return 1
  az boards work-item update --id "$1" --discussion "$2" --org "${org}" --output none 2>/dev/null
}

tracker/ado:create() {
  local org project type item
  org=$(tracker/ado:organization) || return 1
  project=$(tracker:field "${TRACKER_PREFIX}" project)
  type=$(tracker:field "${TRACKER_PREFIX}" type)
  if [[ -z "${project}" ]]
  then
    error "add project: <name> to the ${TRACKER_PREFIX} tracker in kit.yml"
    return 1
  fi
  item=$(az boards work-item create --title "$1" --type "${type:-Task}" --project "${project}" --org "${org}" \
    --output json 2>/dev/null) || { error "run: az login (the work item could not be created)"; return 1; }
  jq --raw-output '.id' <<<"${item}"
}

tracker/ado:me() {
  guard:require tool:az || return 1
  az account show --query user.name --output tsv 2>/dev/null \
    || { error "run: az login (the Azure CLI is not signed in)"; return 1; }
}

tracker/ado:new-url() {
  local org project type
  org=$(tracker/ado:organization) || return 1
  project=$(tracker:field "${TRACKER_PREFIX}" project)
  type=$(tracker:field "${TRACKER_PREFIX}" type)
  type=${type:-Task}
  tracker:query "${org}/${project// /%20}/_workitems/create/${type// /%20}" '[System.Title]' "${1:-}"
}

# tracker/ado:open-issues prints one document per open work item of the record's project, oldest first, as the seam's
# header says: those an Azure Boards query finds in no closing state, each its reference under the record's prefix, its
# page, and the project as its organization, as an Azure DevOps forge's work items have it. az boards query answers
# the first 1000 work items a query finds and says nothing of the rest, and prints nothing when it finds none. So the
# query is read a page at a time, by id, as modules/bash/forge/ado.sh reads it: a read that answers 1000 is followed
# by the next, and a list that reaches forge_list_limit fails.
tracker/ado:open-issues() {
  local org project page pages='' seen
  local -i after=0 count=0 total=0
  org=$(tracker/ado:organization) || return 1
  project=$(tracker:field "${TRACKER_PREFIX}" project)
  if [[ -z "${project}" ]]
  then
    error "add project: <name> to the ${TRACKER_PREFIX} tracker in kit.yml"
    return 1
  fi
  guard:require tool:az || return 1
  while :
  do
    # shellcheck disable=SC2154  # kit_jq is exported by modules/bash/1st.sh
    if ! page=$(az boards query --project "${project}" --org "${org}" --output json --wiql \
      "SELECT [System.Id], [System.Title], [System.AssignedTo], [System.Tags], [System.CreatedDate],
              [System.IterationPath] FROM WorkItems
       WHERE [System.TeamProject] = @project AND [System.State] NOT IN ('Closed', 'Done', 'Removed')
         AND [System.Id] > ${after}
       ORDER BY [System.Id] ASC" 2>/dev/null) || ! seen=$(jq --raw-output -L "${kit_jq}" --argjson after "${after}" \
      'import "forge" as forge; forge::ado_page($after)' <<<"${page:-[]}" 2>/dev/null)
    then
      error "run: az login (the work items of ${project} could not be read from ${org})"
      return 1
    fi
    IFS=$'\t' read -r count after <<<"${seen}"
    total+=count
    forge:whole "the work items of ${project}" "${total}" || return 1
    pages+=${page:-[]}$'\n'
    (( count >= 1000 )) || break
  done
  jq --slurp --compact-output -L "${kit_jq}" --argjson now "$(date +%s)" --arg prefix "${TRACKER_PREFIX}" \
    --arg path "${project}/" --arg page "${org}/${project// /%20}/_workitems/edit/" '
    import "forge" as forge;
    add | forge::ado_issues($now; $path) | .ref = "\($prefix)\(.number)" | .repository = null
    | .url = "\($page)\(.number)"' <<<"${pages}"
}

tracker/ado:state() {
  tracker/ado:read "$1" 'if (.fields["System.State"] | IN("Closed", "Done", "Removed")) then "CLOSED" else "OPEN" end'
}

tracker/ado:title() { tracker/ado:read "$1" '.fields["System.Title"]'; }

# tracker/ado:unassign clears the work item's one assignee, when it is the login named.
tracker/ado:unassign() {
  local org
  org=$(tracker/ado:organization) || return 1
  [[ "$(tracker/ado:assignees "$1")" == "$2" ]] || return 0
  az boards work-item update --id "$1" --assigned-to "" --org "${org}" --output none 2>/dev/null
}

tracker/ado:url() {
  local org project
  org=$(tracker/ado:organization) || return 1
  project=$(tracker:field "${TRACKER_PREFIX}" project)
  printf '%s/%s/_workitems/edit/%s\n' "${org}" "${project// /%20}" "$1"
}

# The seam's calls end here; what follows is this provider's own.

# shellcheck disable=SC2154  # TRACKER_PREFIX is set by tracker:of and tracker:at for the call
tracker/ado:organization() {
  local org
  org=$(tracker:field "${TRACKER_PREFIX}" organization)
  if [[ -z "${org}" ]]
  then
    error "add organization: <https://dev.azure.com/name> to the ${TRACKER_PREFIX} tracker in kit.yml"
    return 1
  fi
  printf '%s\n' "${org%/}"
}

# tracker/ado:show <id> prints the work item as az shows it.
tracker/ado:show() {
  local org
  org=$(tracker/ado:organization) || return 1
  guard:require tool:az || return 1
  az boards work-item show --id "$1" --org "${org}" --output json 2>/dev/null \
    || { error "run: az login (work item ${TRACKER_PREFIX}$1 could not be read from ${org})"; return 1; }
}

# tracker/ado:read <id> <jq argument>… applies jq, with the arguments, to the work item. It fails when az cannot show
# the item.
tracker/ado:read() {
  local item
  item=$(tracker/ado:show "$1") || return 1
  shift
  jq --raw-output "$@" <<<"${item}"
}

# ----------------------------------------------------------------------------------------------------------------------
