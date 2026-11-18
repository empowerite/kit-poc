# backlog.jq - the backlog's issues: those not closed by any open change, with the branch that claims each (jq module)
#
# import "backlog" as backlog; with jq -L "${kit_jq}".
#
# see: modules/bash/backlog.sh

import "forge" as forge;

# unclaimed($changes; $heads; $logins; $except) reads the open issues, as an array of forge.jq's issue documents, and
# gives those no change in $changes closes, each with branch: the first of $heads, the primary's branches, that
# starts with its number and a dash, or null. A change closes an issue when one of its closes has the issue's number
# and is where the issue is, as forge.jq's at says: its source, organization, and repository, so a change that closes
# another repository's issue of the same number leaves this one. With $logins, it keeps the issues assigned to one of
# them, or with $except, those assigned to none of them.
def unclaimed($changes; $heads; $logins; $except):
  ([$changes[] | .closes[]?] | group_by(.number) | map({key: (.[0].number | tostring), value: .}) | from_entries)
    as $closed
  | map(select(. as $issue | any(($closed[.number | tostring] // [])[]; forge::at($issue)) | not)
        | . + {branch: (. as $issue | $heads | map(select(startswith("\($issue.number)-"))) | first)})
  | if ($logins | length) == 0 then .
    else map(select((.assignees | any(. as $a | $logins | index($a))) != $except)) end;
