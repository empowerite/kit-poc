# shellcheck shell=bash
# tui.sh - finds kittui, the binary kit tui runs, and hands the terminal to it (tui:exec); a verb never does it itself
# ----------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2154  # kit_root is exported by modules/bash/1st.sh
#
# A release carries kittui for each platform it supports in libexec/, built by bin/release pack, so whatever installs
# the kit installs kittui at the same version. A checkout of the kit has projects/tui/ instead, and kittui is built from
# it, once per change to its sources or to go, into the cache; a kittui on PATH is the last resort.

use file terminal

# tui:platform prints this machine's platform as Go names it: linux-amd64, darwin-arm64. It returns 1 on an
# operating system or architecture no release builds for.
tui:platform() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "${arch}" in
    (x86_64 | amd64) arch=amd64 ;;
    (aarch64 | arm64) arch=arm64 ;;
    (*) return 1
  esac
  case "${os}" in
    (linux | darwin) ;;
    (*) return 1
  esac
  printf '%s-%s\n' "${os}" "${arch}"
}

# tui:checkout prints the projects/tui/ directory of a checkout of the kit, and fails for a release, which has a version
# file and no projects/tui/.
tui:checkout() {
  [[ ! -f "${kit_root}/version" && -f "${kit_root}/../projects/tui/go.mod" ]] || return 1
  (cd "${kit_root}/../projects/tui" && pwd)
}

# tui:cached <tui> prints where the build of the sources under <tui>, with the go on PATH, lives in the cache: named by
# a digest of every file under <tui> that the build can read, the Go sources and the JSON that is embedded among them,
# and of go version, so a change to any of them is a new build. Tests, their testdata, and the README are no part of the
# build. It fails when the files cannot be read.
tui:cached() {
  local digest
  digest=$(set -o pipefail
    { find "$1" -type f ! -path '*/testdata/*' ! -name '*_test.go' ! -name README.md -print0 \
        | LC_ALL=C sort -z | xargs -0 cat
      go version; } | file:digest) || return 1
  printf '%s\n' "${XDG_CACHE_HOME:-${HOME}/.cache}/kit/kittui-${digest:0:16}"
}

# tui:prune <build> removes the builds in <build>'s directory that are older than two weeks, so each change to a source
# does not leave a binary behind for good. A build another checkout made a day ago stays.
tui:prune() {
  find "$(dirname "$1")" -maxdepth 1 -type f -name 'kittui-*' -mtime +14 -delete
}

# tui:binary [--probe] prints the path of the kittui to run. In a checkout with go, it is the build of projects/tui/'s
# sources, built first when they or go changed, under a temporary name and then renamed into place, so two first runs
# never run a half-written file. Otherwise it is the release's own for this platform, else kittui on PATH. With --probe
# it is the hand-off's question, whether a kittui can be had: it builds as a run would, so a build that fails is known
# before the hand-off, says so, and returns 1, and it says nothing of a kittui that is not to be had, which a verb that
# prints text does not need. Without it, a kittui that is not to be had is said, with the remedy, and returns 1.
tui:binary() {
  local probe=false platform tui out tmp
  [[ "${1:-}" == --probe ]] && probe=true
  if tui=$(tui:checkout) && command -v go >/dev/null 2>&1
  then
    out=$(tui:cached "${tui}") || { error "the sources of kittui under ${tui} could not be read"; return 1; }
    if [[ ! -x "${out}" ]]
    then
      step "building kittui from projects/tui/, once for these sources and this go"
      tmp="${out}.tmp.$$"
      mkdir -p "$(dirname "${out}")"
      if ! (cd "${tui}" && CGO_ENABLED=0 go build -o "${tmp}" ./cmd/kittui)
      then
        rm -f "${tmp}"
        error "kittui could not be built from ${tui}; see above"
        return 1
      fi
      mv -f "${tmp}" "${out}"
      tui:prune "${out}"
    fi
    printf '%s\n' "${out}"
    return 0
  fi
  # A platform kit builds no kittui for has none in libexec; a kittui on PATH is looked for next.
  platform=$(tui:platform || true)
  if [[ -n "${platform}" && -x "${kit_root}/libexec/kittui-${platform}" ]]
  then
    printf '%s\n' "${kit_root}/libexec/kittui-${platform}"
    return 0
  fi
  if command -v kittui >/dev/null 2>&1
  then
    command -v kittui
    return 0
  fi
  [[ "${probe}" == false ]] || return 1
  if tui:checkout >/dev/null
  then
    guard:require tool:go
  elif [[ -f "${kit_root}/version" ]]
  then
    error "this release of kit carries no kittui for ${platform:-$(uname -sm)}; run: kit help tui"
  else
    error "this copy of kit carries no kittui, and none is on PATH; run: kit help tui"
  fi
  return 1
}

# tui:exec <argument>… puts kittui in this process's place, with the arguments. It finds kittui as tui:binary does and
# ends the verb with the remedy where none can be had, though the caller's tui:binary --probe has judged that already.
# It asks the terminal first, as terminal:export-probes does, so kittui never reads the terminal it holds, and names this
# kit to kittui in KIT, so what kittui runs is this kit. The arguments are the caller's: the app, and the workspace kit
# --workspace= named, which kittui reads on each call.
tui:exec() {
  local binary
  binary=$(tui:binary) || exit 1
  terminal:export-probes
  export KIT="${kit_root}/bin/kit"
  exec "${binary}" "$@"
}

# ----------------------------------------------------------------------------------------------------------------------
