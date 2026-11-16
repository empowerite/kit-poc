# shellcheck shell=bash
# model.sh - the model of kit's entities: its files, one YAML file each, read into one JSON document (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2154  # kit_root is set by modules/bash/1st.sh
#
# The release's model is modules/model/<domain>/<entity>.yml, one file for each entity and a domain.yml for each
# domain; a repository adds its own under .kit/model/<domain>/. The domain of a file is the name of its directory.
# A file uses the part of YAML that CUE also reads: one document, no anchors, no aliases, no merge keys, so model:load
# refuses one that does, naming the file.
#
#   model:load [<release-dir> [<repo-dir>]]   prints {"files": [{"domain", "origin", "path", "doc"}, …], "strays":
#                                             [<path>, …]}, on one line: the release's files first, then the
#                                             repository's, each group in path order, and every other file it finds
#                                             in either directory, which it does not read. <release-dir> is
#                                             modules/model of the kit, and <repo-dir> is .kit/model of the
#                                             repository, unless named; a directory that does not exist holds no
#                                             files. A path is written as the release is delivered,
#                                             modules/model/<domain>/<file>, or .kit/model/<domain>/<file>. It
#                                             returns 1, naming the file, for a file it refuses or cannot parse.
#   model:findings [<release-dir> [<repo-dir>]]
#                                             prints the findings of the model model:load reads, one a line, then,
#                                             last, how many entities and stubs it holds, as model: 12 entities, 2
#                                             stubs. It returns 1 when there is a finding, when a file cannot be read,
#                                             which model:load names, and when jq fails, whose message stays on
#                                             stderr.
#
# see: docs/model.md, modules/model/model.schema.json

use yaml

# model:refusal <file> prints why the file is refused, or nothing when its form is allowed: a second document, a merge
# key, an alias, or an anchor.
model:refusal() {
  local file=$1 count
  count=$(yaml:yq "${file}" model-documents 'document_index' | wc -l) || return 1
  if (( count > 1 ))
  then
    printf '%s\n' 'holds two documents; a model file holds one'
  elif [[ -n "$(yaml:yq "${file}" model-merge '.. | key | select(tag == "!!merge")')" ]]
  then
    printf '%s\n' 'has a merge key; write the keys out'
  elif [[ -n "$(yaml:yq "${file}" model-alias '.. | select(kind == "alias")')" ]]
  then
    printf '%s\n' 'has an alias; write the value out'
  elif [[ -n "$(yaml:yq "${file}" model-anchor '(.. | select(anchor != "")), (.. | key | select(anchor != ""))')" ]]
  then
    printf '%s\n' 'has an anchor; write the value out'
  fi
}

# yq reads a quoted "<<" key as a merge key, and drops it, unless it is told to follow the YAML spec.
# model:read <origin> <dir> <prefix> prints, one JSON object a line, each <dir>/<domain>/*.yml, in path order, as
# {"domain", "origin", "path", "doc"} with the path written from <prefix>, then {"stray": <path>} for each other file
# under <dir>. It returns 1 for a file it refuses.
model:read() {
  local origin=$1 dir=$2 prefix=$3 file domain path why doc
  local LC_ALL=C
  shopt -s nullglob
  for file in "${dir}"/*/*.yml
  do
    domain=$(basename "$(dirname "${file}")")
    path=${prefix}/${domain}/$(basename "${file}")
    doc=$(yaml:eval "${file}" model-json '.' --output-format=json --indent=0 --yaml-fix-merge-anchor-to-spec=true) || return 1
    why=$(model:refusal "${file}") || return 1
    if [[ -n "${why}" ]]
    then
      error "${path} ${why}"
      return 1
    fi
    jq --null-input --compact-output --arg domain "${domain}" --arg origin "${origin}" --arg path "${path}" \
      --argjson doc "${doc:-null}" '{domain: $domain, origin: $origin, path: $path, doc: $doc}'
  done
  model:strays "${origin}" "${dir}" "${prefix}"
}

# model:strays <origin> <dir> <prefix> prints {"stray": <path>}, one a line in path order, for each file under <dir>
# that model:read does not read: any but <dir>/<domain>/*.yml. It leaves out a file or a directory whose name starts
# with a dot, which an editor or a file manager makes, and the release's two schemas, modules/model/*.schema.json.
model:strays() {
  local origin=$1 dir=$2 prefix=$3 file relative
  local LC_ALL=C
  [[ -d "${dir}" ]] || return 0
  while IFS= read -r file
  do
    relative=${file#"${dir}"/}
    [[ "${relative}" =~ ^[^/]+/[^/]+\.yml$ ]] && continue
    [[ "${origin}" == release && "${relative}" =~ ^(model|domain)\.schema\.json$ ]] && continue
    jq --null-input --compact-output --arg path "${prefix}/${relative}" '{stray: $path}'
  done < <(find -L "${dir}" -mindepth 1 -name '.*' -prune -o -type f -print | sort)
}

# model:load [<release-dir> [<repo-dir>]] prints the model's files as one JSON document, as the header says.
model:load() {
  local release=${1:-${kit_root}/modules/model} repo=${2:-} top lines
  if [[ -z "${repo}" ]]
  then
    top=$(git rev-parse --show-toplevel 2>/dev/null) || top=''
    [[ -z "${top}" ]] || repo=${top}/.kit/model
  fi
  lines=$(model:read release "${release}" modules/model) || return 1
  if [[ -n "${repo}" ]]
  then
    lines+=$'\n'$(model:read repository "${repo}" .kit/model) || return 1
  fi
  jq --slurp --compact-output '{files: map(select(has("doc"))), strays: map(select(has("stray")) | .stray)}' <<<"${lines}"
}

# model:findings [<release-dir> [<repo-dir>]] prints the model's findings and its count, as the header says.
model:findings() {
  local loaded report
  loaded=$(model:load "$@") || return 1
  report=$(jq -L "${kit_root}/modules/jq" --raw-output 'import "model" as model; model::build
    | model::check[], "model: \(.entities | length) entities, \(model::stubs | length) stubs"' <<<"${loaded}") || return 1
  printf '%s\n' "${report}"
  [[ "${report}" != *$'\n'* ]]
}
# ----------------------------------------------------------------------------------------------------------------------
