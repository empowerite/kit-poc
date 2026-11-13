# shellcheck shell=bash
# trust.sh - the clones you trust: what one asks kit to run, and the file that records your answer (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# kit runs nothing in a clone until you trust it, nor in a folder outside a clone that holds a kit.yml, which is
# trusted as a clone is, by its own path. modules/bash/1st.sh holds the check, kit:trust-here, which every verb's
# kit:enter makes before anything else, and bin/kit, the loader, makes the same check in POSIX sh before it runs a
# release the clone names. This module holds what kit trust adds: what a clone asks kit to run, and the records it
# writes.
#
# A record is one line of the trust file, kit:trust-file. For a clone, which trusts it and every worktree of it, it is
# the sha256 of what the clone asks kit to run, kit:trust-digest's, two spaces, and the clone's absolute path, as
# sha256sum prints a file's: the trust holds while the clone asks the same, and a clone whose kit.yml, rules, or
# styles come to ask something new is asked about again. A clone may have a line for each thing it asked that you
# trusted, as two worktrees on different branches do. For a folder it is the folder's absolute path alone, ending in
# /, which trusts every clone under it, whatever it asks. A line that starts with # is a comment, and ~/ at the start
# of a path is the home directory. kit trust writes physical paths, with no link in them, as the check compares them.
#
# see: bin/kit-trust, modules/bash/1st.sh, bin/kit

use yaml file

# trust:settings <clone> prints the settings file kit reads at <clone>: its kit.yml, or where there is none, the
# .kit/settings.yml that kit:move-settings moves there, which kit:trust-digest digests in its place. It prints
# nothing where there is neither.
trust:settings() {
  if [[ -f "$1/kit.yml" ]]
  then printf '%s\n' "$1/kit.yml"
  elif [[ ! -e "$1/kit.yml" && -f "$1/.kit/settings.yml" ]]
  then printf '%s\n' "$1/.kit/settings.yml"
  fi
}

# trust:version-line <value> <file> puts in the variable <value> the release bin/kit, the loader, reads from the
# settings file <file>, by the loader's own sed program: its first line that starts with version:, without quotes and
# without a comment beside it. It is the one place in bash that holds that program, for trust:pinned, which shows the
# release, and for modules/bash/settings.sh's settings:version, which holds yq's reading to it.
trust:version-line() {
  printf -v "$1" '%s' "$(sed -n -e '/^version:/{' -e 's/^version:[[:space:]]*//' -e 's/^#.*$//' \
    -e 's/[[:space:]]\{1,\}#.*$//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/" \
    -e p -e q -e '}' "$2")"
}

# trust:pinned <value> <from> <clone> puts in the variable <value> the release the clone at <clone> pins, read as
# bin/kit, the loader, reads it, by the same two sed programs: the version line of its settings, trust:settings', as
# trust:version-line reads it, and where that gives nothing, the version .kit/manifest records. It puts in <from>
# the words that name where the release was read, for the line kit trust shows. yq is not asked: a version it finds
# and the loader does not, as under a key in quotes, is not the release that runs.
trust:pinned() {
  local pinned='' pinned_from='version:' pinned_settings
  pinned_settings=$(trust:settings "$3")
  [[ -z "${pinned_settings}" ]] || trust:version-line pinned "${pinned_settings}"
  if [[ -z "${pinned}" && -f "$3/.kit/manifest" ]]
  then
    pinned=$(sed -n 's/^version //p' "$3/.kit/manifest")
    pinned_from='version in .kit/manifest:'
  fi
  printf -v "$1" '%s' "${pinned}"
  printf -v "$2" '%s' "${pinned_from}"
}

# trust:ask <format> <value>… prints one line of what a clone asks: printf's <format>, a newline, with each value
# whole on that line. A newline in a value is printed as \n, and any other control character as ?, so a value the
# clone wrote starts no line of its own and moves nothing on the screen.
trust:ask() {
  local format=$1 value
  local -a values=()
  shift
  for value in "$@"
  do
    value=${value//$'\n'/\\n}
    values+=("${value//[[:cntrl:]]/?}")
  done
  # shellcheck disable=SC2059  # the format is this module's own text, and the values are its arguments
  printf "${format}\n" "${values[@]}"
}

# trust:asks <clone> prints what the clone at <clone> asks kit to run, one line each, as trust:ask prints one: the
# release it pins, trust:pinned's, and whether that is the clone's own kit/, which unreleased names whether or not
# the clone holds one yet; each bash_path entry that loads bash from outside the release; its gate; each source it
# brings packages from, or fetches tools from, by its kind and url; the tools it has kit download and run; and each
# lint: command a rule or a style names, of the kit's packages or the clone's own, once each. It prints nothing for
# a clone that asks for none of them. A folder outside a clone pins no release: the loader chooses one in a clone
# alone, and runs the kit you installed elsewhere. It reads the rest of the settings, trust:settings', so a
# .kit/settings.yml kit has yet to move is shown as the kit.yml it becomes, and the frontmatter, with yq, and runs
# nothing the clone names.
trust:asks() {
  local clone=$1 version='' from='' entry gate file lint name kind url settings
  local -a entries=() sources=() tools=() files=()
  local -A said=()
  [[ ! -e "${clone}/.git" ]] || trust:pinned version from "${clone}"
  if [[ "${version}" == unreleased && -x "${clone}/kit/bin/kit" && -f "${clone}/kit/modules/bash/1st.sh" ]]
  then
    trust:ask 'run its own kit, kit/ in the clone, for every kit command there (%s %s)' "${from}" "${version}"
  elif [[ "${version}" == unreleased ]]
  then
    trust:ask 'run its own kit, kit/ in the clone, for every kit command there, once the clone holds one (%s %s)' \
      "${from}" "${version}"
  elif [[ -n "${version}" ]]
  then
    trust:ask 'run kit %s, downloaded from its release and checked against its digest (%s %s)' \
      "${version}" "${from}" "${version}"
  fi
  settings=$(trust:settings "${clone}")
  if [[ -n "${settings}" ]]
  then
    list:read entries yaml:list "${settings}" bash_path || return 1
    for entry in "${entries[@]}"
    do
      [[ "${entry}" == kit:* ]] || trust:ask 'load bash into every kit command from %s (bash_path)' "${entry}"
    done
    gate=$(yaml:value "${settings}" gate) || return 1
    [[ -z "${gate}" ]] || trust:ask 'run %s for kit gate (gate)' "${gate}"
    list:read sources yaml:records "${settings}" sources name kind url || return 1
    for entry in "${sources[@]}"
    do
      IFS=$'\x1f' read -r name kind url <<<"${entry}"
      case "${kind}" in
        ('' | kit-packages) trust:ask 'bring packages from the source %s (sources)' "${name}" ;;
        (*) trust:ask 'fetch its tools from the %s source %s, at %s (sources)' "${kind}" "${name}" "${url}"
      esac
    done
    list:read tools yaml:eval "${settings}" tool-names '(.tools // {}) | keys | .[]' || return 1
    if (( ${#tools[@]} ))
    then
      trust:ask 'download and run the tools it pins, from the URLs it names: %s (tools)' "$(trust:joined "${tools[@]}")"
    fi
  fi
  for file in "${clone}"/.kit/{rules,styles}/*.md "${clone}"/.kit/packages/{,*/}*/files/repo/.kit/{rules,styles}/*.md
  do
    [[ ! -f "${file}" ]] || files+=("${file}")
  done
  for file in "${files[@]}"
  do
    lint=$(yaml:value "${file}" lint) || return 1
    [[ -n "${lint}" && -z "${said[${lint}]+x}" ]] || continue
    said[${lint}]=1
    trust:ask 'run %s for kit lint (lint: in %s)' "${lint}" "${file#"${clone}"/}"
  done
}

# trust:joined <word>… prints the words joined by a comma and a space.
trust:joined() {
  local IFS=,
  local joined="$*"
  printf '%s\n' "${joined//,/, }"
}

# trust:line <record> [<digest>] prints the line that records <record>: <digest>, two spaces, and <record> for a
# clone, and <record> alone for a folder.
trust:line() {
  if [[ -n "${2:-}" ]]
  then printf '%s  %s\n' "$2" "$1"
  else printf '%s\n' "$1"
  fi
}

# trust:names <name> <line> puts in the variable <name> the path a line of the trust file names, without the digest
# a clone's line starts with.
trust:names() {
  if [[ "$2" =~ ^[0-9a-f]{64}\ \ (.*)$ ]]
  then printf -v "$1" '%s' "${BASH_REMATCH[1]}"
  else printf -v "$1" '%s' "$2"
  fi
}

# trust:recorded <record> [<digest>] succeeds when the trust file holds trust:line's line for them, as a line of its
# own.
trust:recorded() {
  local file
  file=$(kit:trust-file)
  [[ -f "${file}" ]] && grep --quiet --fixed-strings --line-regexp -- "$(trust:line "$@")" "${file}"
}

# trust:record <record> [<digest>] adds trust:line's line to the trust file, once, writing the file whole or not at
# all. A line of the clone's path alone, which kit trust wrote before it kept the digest, goes.
trust:record() {
  local file
  file=$(kit:trust-file)
  trust:recorded "$@" && return 0
  file:replace "${file}" trust:with "${file}" "$1" "$(trust:line "$@")"
}

# trust:revoke <record> takes every line for <record> out of the trust file, writing the file whole or not at all. It
# fails when the file holds none.
trust:revoke() {
  local file line name found=false
  file=$(kit:trust-file)
  [[ -f "${file}" ]] || return 1
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    trust:names name "${line}"
    [[ "${name}" != "$1" ]] || found=true
  done < "${file}"
  [[ "${found}" == true ]] || return 1
  file:replace "${file}" trust:without "${file}" "$1"
}

# trust:with <file> <record> <line> prints <file>'s lines, if it is there, but a line of <record> alone, then <line>.
trust:with() {
  local line
  if [[ -f "$1" ]]
  then
    while IFS= read -r line || [[ -n "${line}" ]]
    do
      [[ "${line}" == "$2" && "$2" != */ ]] || printf '%s\n' "${line}"
    done < "$1"
  fi
  printf '%s\n' "$3"
}

# trust:without <file> <record> prints <file>'s lines but those for <record>.
trust:without() {
  local line name
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    trust:names name "${line}"
    [[ "${name}" == "$2" ]] || printf '%s\n' "${line}"
  done < "$1"
}

# trust:list prints the clones and folders the records name, one per line, once each, comments and blank lines left
# out.
trust:list() {
  local file line name
  local -A listed=()
  file=$(kit:trust-file)
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    [[ -n "${line//[[:space:]]/}" && "${line}" != '#'* ]] || continue
    trust:names name "${line}"
    [[ -z "${listed[${name}]+x}" ]] || continue
    listed[${name}]=1
    printf '%s\n' "${name}"
  done < "${file}"
}

# trust:keeping <command>… runs a command that writes what kit itself keeps, its declaration in kit.yml, .kit/manifest,
# and what it places under .kit/, and keeps the clone's trust across it: where a line of the trust file trusts the
# clone as it asks just before, it records the digest of what it asks after, so a fresh clone that kit hydrates, or
# an update that moves its version, is not asked about what kit wrote. A folder outside a clone that holds a kit.yml
# is kept the same way. A clone a folder trusts, or none, it leaves as it is. The command runs in this shell, with
# trust_keeping set, so one it calls in turn is not kept twice. It returns what the command returns.
trust:keeping() {
  # shellcheck disable=SC2034  # read by the command it runs, through bash's dynamic scope
  local trust_keeping=1
  local root name before after status=0
  if ! root=$(kit:trust-root .)
  then
    "$@"
    return
  fi
  name=$(kit:trust-name "${root}")
  before=$(kit:trust-digest "${root}") && trust:recorded "${name}" "${before}" || before=''
  "$@" || status=$?
  if [[ -n "${before}" ]] && after=$(kit:trust-digest "${root}") && [[ "${after}" != "${before}" ]]
  then
    trust:record "${name}" "${after}" || status=1
  fi
  return "${status}"
}

# ----------------------------------------------------------------------------------------------------------------------
