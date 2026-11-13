# shellcheck shell=bash
# manifest.sh - .kit/manifest and ~/.kit/manifest: the digest of every delivered path, per base (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2154  # kit_root is exported by modules/bash/1st.sh
#
# Each base has a manifest, written beside what kit placed and ignored like it: one line per delivered path, the
# digest of the release's content kit placed there and the path. kit update compares a file against its digest to tell
# whether the repository edited it. A record says kit placed the path, so a path kit did not place keeps the record it
# had, and a path under .kit/ that holds the repository's own file has none. A path the packages no longer deliver,
# as under a release that retired it, keeps its record too while its file is there, until kit update retires it.
# Home's manifest, with no settings file beside it, carries the version and the packages as well, and is shared by
# every repository on the machine.
#
# see: docs/packages.md

use release place materialize settings file trust

# manifest_dropped names each path a verb took out of what the packages deliver, as "<base>" a tab "<path>", so
# manifest:text keeps no record of it. manifest:drop fills it, for kit packages remove; no other verb takes a path
# out and writes with --keep.
declare -gA manifest_dropped=()

# manifest:drop <base> <path> says the caller took <path> out of what the packages deliver under <base>, so the next
# manifest:write --keep keeps no record of it.
manifest:drop() { manifest_dropped[$1$'\t'$2]=1; }

# manifest:path <base> prints the base's manifest: .kit/manifest in the repository, ~/.kit/manifest for home.
manifest:path() { release:dest "$1" .kit/manifest; }

# manifest:write [--keep] <base> <excluded> <package>… writes the base's manifest: a record for every path delivered
# under the base, as manifest:text prints them, and under home, which has no settings file, the version and the active
# packages as well. A caller that placed every path, as kit install and kit update do, records the release's digest
# for each. A caller that did not, as a verb that hydrates and kit packages do, passes --keep, and a path it did not
# place keeps the digest the manifest records, and so does a recorded path the packages no longer deliver, as
# manifest:text says. The repository's manifest is always written. Home's manifest is shared by every repository on
# the machine. It is written when these packages deliver to home. When they do not, it drops the lines whose paths no
# longer exist, and removes the file once no line is left.
manifest:write() {
  local keep=false base excluded manifest path src delivered kept dest
  local -a paths
  if [[ "$1" == --keep ]]
  then
    keep=true
    shift
  fi
  base=$1 excluded=$2
  shift 2
  manifest=$(manifest:path "${base}")
  if [[ "${base}" == repo && -L "${manifest%/*}" ]]
  then
    error "${manifest%/*} is a link, which kit neither writes nor removes through; make it a directory, then run:" \
      "kit hydrate"
    return 1
  fi
  delivered=$(place:delivered "${kit_root}" "${base}" "$@") || return 1
  if [[ "${base}" != repo && -z "${delivered}" ]]
  then
    [[ -f "${manifest}" ]] || return 0
    list:read paths manifest:paths "${base}" || return 1
    # A path that is gone, or that grep does not find, keeps no line.
    kept=$(for path in "${paths[@]}"
      do
        [[ -n "${path}" ]] && release:dest "${base}" "${path}" dest && [[ -e "${dest}" ]] \
          && grep -F "  ${path}" "${manifest}"
      done; true)
    if [[ -z "${kept}" ]]
    then
      rm -f "${manifest}"
    else
      file:replace --read-only "${manifest}" manifest:kept-text "${manifest}" "${kept}"
    fi
    return 0
  fi
  # The manifest has no write bit, as every file kit places under .kit/ has none.
  file:replace --read-only "${manifest}" manifest:text "${keep}" "${base}" "${excluded}" "${delivered}" "$@"
}

# manifest:kept-text <manifest> <kept> prints home's manifest with its header lines and the record lines in <kept>.
manifest:kept-text() {
  awk '!(length($1) == 64 && $0 ~ /^[0-9a-f]+  /)' "$1"
  printf '%s\n' "$2"
}

# manifest:text <keep> <base> <excluded> <delivered> <package>… prints a manifest: its header; under home, the
# version, the packages, and the excludes; and one record per "<path>\t<source>" line of <delivered>, a digest and
# the path. The digest is the source's, which is what kit placed. With <keep> true it is the digest the manifest
# records already, for a path that has one and that kit does not materialize: the caller did not place that path, and
# what is there is still what the record says. A materialized path that holds the repository's own file, as
# materialize:foreign finds it, has no record, in either case, so materialize:all goes on leaving it alone. The
# sources are digested together, by one process.
#
# With <keep> true, a recorded path that is not in <delivered> keeps its record, after the others, while something is
# at the path: the release that runs may have retired it, and the record is what kit update retires it by
# (place:retire). A path in manifest_dropped keeps none: the caller took it out of what the packages deliver.
#
# It returns 1, having printed the header alone, when the manifest or a source cannot be read.
manifest:text() {
  local keep=$1 base=$2 excluded=$3 delivered=$4 path src row i kind root
  local -a rows paths=() digests=() fresh=() srcs=() found owned=() before=()
  local -A recorded=() source=() materialized=() foreign=() kept=()
  shift 4
  printf '# .kit/manifest - written by kit, not by hand\n'
  if [[ "${base}" != repo ]]
  then
    # Home has no settings file, so its manifest carries the version and the packages that wrote it.
    printf 'version %s\n' "$(release:version)"
    if (( $# > 0 ))
    then printf 'packages %s\n' "$*"
    else printf 'packages\n'
    fi
    [[ -z "${excluded}" ]] || printf 'excludes %s\n' "${excluded}"
  fi
  manifest:records recorded "${base}" || return 1
  readarray -t rows <<<"${delivered}"
  for row in "${rows[@]}"
  do
    IFS=$'\t' read -r path src <<<"${row}"
    [[ -n "${path}" ]] || continue
    source[${path}]=${src}
    place:kind "${src}" "${path}" kind
    if [[ "${kind}" == copy ]] && materialize:owned "${base}" "${path}"
    then
      materialized[${path}]=1
      owned+=("${path}")
    fi
  done
  (( ${#owned[@]} == 0 )) || materialize:foreign foreign recorded source "${owned[@]}"
  for row in "${rows[@]}"
  do
    path=${row%%$'\t'*}
    [[ -n "${path}" && -z "${foreign[${path}]+x}" ]] || continue
    if [[ "${keep}" == true && -n "${recorded[${path}]:-}" && -z "${materialized[${path}]+x}" ]]
    then
      # A path recorded twice keeps its first digest.
      digests+=("${recorded[${path}]%%$'\n'*}")
    else
      digests+=('')
      fresh+=("${#paths[@]}")
      srcs+=("${source[${path}]}")
    fi
    paths+=("${path}")
  done
  file:digests found "${srcs[@]}" || return 1
  for i in "${!fresh[@]}"
  do
    digests[fresh[i]]=${found[i]}
  done
  for i in "${!paths[@]}"
  do
    printf '%s  %s\n' "${digests[i]}" "${paths[i]}"
  done
  [[ "${keep}" == true ]] || return 0
  list:read before manifest:paths "${base}" || return 1
  release:dest "${base}" '' root || return 1
  for path in "${before[@]}"
  do
    [[ -n "${path}" && -z "${source[${path}]+x}" && -z "${kept[${path}]+x}" ]] || continue
    [[ -z "${manifest_dropped[${base}$'\t'${path}]+x}" ]] || continue
    [[ -e "${root}${path}" || -L "${root}${path}" ]] || continue
    kept[${path}]=1
    printf '%s  %s\n' "${recorded[${path}]%%$'\n'*}" "${path}"
  done
}

# manifest:write-all [--keep] <excluded> <package>… writes every base's manifest, as manifest:write does, with
# --keep when the caller did not place every path, then the repository's declaration in kit.yml, keeping the clone's
# trust across it, as trust:keeping does. <excluded> is the excluded packages as a space-separated list, empty when
# there are none.
manifest:write-all() {
  local excluded base
  local -a keep=()
  if [[ -z "${trust_keeping:-}" ]]
  then
    trust:keeping manifest:write-all "$@"
    return
  fi
  if [[ "$1" == --keep ]]
  then
    keep=(--keep)
    shift
  fi
  excluded=$1
  shift
  for base in $(release:bases)
  do
    manifest:write "${keep[@]}" "${base}" "${excluded}" "$@"
  done
  settings:declare "$(release:version)" "${excluded}" "$@"
}

# manifest:paths <base> prints every path the base's manifest records. A record line is a 64-character
# hex digest, two spaces, and the path, which can contain spaces. A record whose path climbs out of the base's root,
# by a leading /, or a . or .. segment, is skipped and named: a manifest a clone carries is not kit's to trust, and
# every path read here is one a verb may remove.
manifest:paths() {
  local manifest path
  manifest=$(manifest:path "$1")
  [[ -f "${manifest}" ]] || return 0
  while IFS= read -r path
  do
    if [[ "${path}" == /* || "/${path}/" == */../* || "/${path}/" == */./* ]]
    then
      warn "${manifest}: the record for '${path}' climbs out of its root; skipped"
      continue
    fi
    printf '%s\n' "${path}"
  done < <(awk 'length($1) == 64 && $0 ~ /^[0-9a-f]+  / { print substr($0, 67) }' "${manifest}")
}

# manifest:recorded <base> <path> prints the digest the base's manifest records for <path>, or nothing.
manifest:recorded() {
  local -A records
  manifest:records records "$1" || return 1
  [[ -z "${records[$2]+x}" ]] || printf '%s\n' "${records[$2]}"
}

# manifest:records <map> <base> fills the named associative array with the base's manifest, path to digest, read
# in this shell, so a caller that asks about every path reads the file once and starts no process for each. A record
# line is 64 hex characters, two spaces, and the path, as manifest:paths reads it; a missing manifest records nothing.
# A path recorded twice maps to both digests, a line each, as the manifest has them.
manifest:records() {
  local -n manifest_records_out=$1
  local manifest_records_file manifest_records_line manifest_records_path
  manifest_records_out=()
  manifest_records_file=$(manifest:path "$2")
  [[ -f "${manifest_records_file}" ]] || return 0
  while IFS= read -r manifest_records_line || [[ -n "${manifest_records_line}" ]]
  do
    [[ "${manifest_records_line}" =~ ^[0-9a-f]{64}'  '. ]] || continue
    manifest_records_path=${manifest_records_line:66}
    manifest_records_out["${manifest_records_path}"]+=${manifest_records_out["${manifest_records_path}"]+$'\n'}
    manifest_records_out["${manifest_records_path}"]+=${manifest_records_line:0:64}
  done < "${manifest_records_file}"
}

# ----------------------------------------------------------------------------------------------------------------------
