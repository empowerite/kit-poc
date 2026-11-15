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
#   model:load [<release-dir> [<repo-dir>]]   prints {"files": [{"domain", "origin", "path", "doc"}, …]}, on one line:
#                                             the release's files first, then the repository's, each group in path
#                                             order. <release-dir> is modules/model of the kit, and <repo-dir> is
#                                             .kit/model of the repository, unless named; a directory that does not
#                                             exist holds no files. A path is written as the release is delivered,
#                                             modules/model/<domain>/<file>, or .kit/model/<domain>/<file>.
#                                             It returns 1, naming the file, for a file it refuses or cannot parse.
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
  elif [[ -n "$(yaml:yq "${file}" model-merge '.. | select(kind == "map") | keys | .[] | select(. == "<<")')" ]]
  then
    printf '%s\n' 'has a merge key; write the keys out'
  elif [[ -n "$(yaml:yq "${file}" model-alias '.. | select(kind == "alias")')" ]]
  then
    printf '%s\n' 'has an alias; write the value out'
  elif [[ -n "$(yaml:yq "${file}" model-anchor '.. | select(anchor != "")')" ]]
  then
    printf '%s\n' 'has an anchor; write the value out'
  fi
}

# model:read <origin> <dir> <prefix> prints, one JSON object a line, each <dir>/<domain>/*.yml, in path order, as
# {"domain", "origin", "path", "doc"} with the path written from <prefix>. It returns 1 for a file it refuses.
model:read() {
  local origin=$1 dir=$2 prefix=$3 file domain path why doc
  local LC_ALL=C
  shopt -s nullglob
  for file in "${dir}"/*/*.yml
  do
    domain=$(basename "$(dirname "${file}")")
    path=${prefix}/${domain}/$(basename "${file}")
    doc=$(yaml:json "${file}") || return 1
    why=$(model:refusal "${file}") || return 1
    if [[ -n "${why}" ]]
    then
      error "${path} ${why}"
      return 1
    fi
    jq --null-input --compact-output --arg domain "${domain}" --arg origin "${origin}" --arg path "${path}" \
      --argjson doc "${doc:-null}" '{domain: $domain, origin: $origin, path: $path, doc: $doc}'
  done
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
  lines+=$'\n'$(model:read repository "${repo:-/nonexistent}" .kit/model) || return 1
  jq --slurp --compact-output '{files: .}' <<<"${lines}"
}
# ----------------------------------------------------------------------------------------------------------------------
