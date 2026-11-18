# shellcheck shell=bash
# uv.sh - the uv dependency provider: pyproject.toml names the packages, uv.lock pins them (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# uv is usable where uv is on PATH, and pyproject.toml and uv.lock are at the repository root. It pins what its
# install, uv sync --frozen, would have in .venv: the lock's packages but the project itself, less those this platform
# or the default groups leave out. The lock is TOML, read with yq; what is installed is read with uv pip list, from
# .venv; what uv would install is read from a dry run of the install.
#
# A package's name is compared in its normal form, lowercase with dashes: the lock has pyyaml, and pip lists PyYAML.

dependencies/uv:file() { printf 'pyproject.toml\n'; }

dependencies/uv:install() { uv sync --frozen; }

dependencies/uv:lock() { printf 'uv.lock\n'; }

# dependencies/uv:outdated asks the index which installed packages are behind, each by its normal name.
dependencies/uv:outdated() {
  local doc
  if ! doc=$(uv pip list --outdated --format json --python .venv/bin/python 2>/dev/null)
  then
    error "uv pip list --outdated could not ask the index; run kit tools install first"
    return 1
  fi
  jq --raw-output 'def normal: ascii_downcase | gsub("[-_.]+"; "-");
    .[] | [(.name | normal), .version, .latest_version] | @tsv' <<<"${doc}"
}

dependencies/uv:path() { printf '%s/.venv/bin\n' "${PWD}"; }

# dependencies/uv:pins never reaches the network. With no .venv, nothing is installed. jq reads the lock and the
# installed list on stdin: a lock names every wheel of every package, so it is soon larger than a command line, or one
# argument of it, may be.
#
# A lock is written for every platform, every extra, and every group, so it holds packages uv sync --frozen never
# installs here: one a marker such as sys_platform == 'win32' leaves out, one only an extra names, and the other
# version of a package locked at two. An entry is pinned here when .venv holds it at its version, or when uv would
# install it, which a dry run of the install says, offline, changing nothing. Where uv gives no plan kit can read, as
# with no Python yet to judge a marker by, every entry is pinned.
dependencies/uv:pins() {
  local lock plan installed='[]'
  lock=$(yq --input-format toml --output-format json uv.lock) || return 1
  [[ ! -x .venv/bin/python ]] \
    || installed=$(uv pip list --format json --python .venv/bin/python 2>/dev/null) || installed='[]'
  if ! plan=$(uv sync --frozen --dry-run --offline --output-format json 2>/dev/null) \
    || ! jq --exit-status 'type == "object"' <<<"${plan}" >/dev/null 2>&1
  then
    plan=null
  fi
  jq --slurp --raw-output '
    def normal: ascii_downcase | gsub("[-_.]+"; "-");
    . as [$lock, $installed, $plan]
    | ($installed | map({key: (.name | normal), value: .version}) | from_entries) as $have
    # what uv would install, each as name==version; null where the plan is not in the form read here
    | (try ($plan.sync.changes | if type != "array" then null
        else map(select(.action != "uninstalled") | "\(.name | normal)==\(.version)") end) catch null) as $due
    | $lock.package[] | select(.source.virtual == null and .source.editable == null)
    | (.name | normal) as $name | "\($name)==\(.version)" as $entry
    | select($due == null or $have[$name] == .version or ($due | index($entry)) != null)
    | [$name, .version, ($have[$name] // "")] | @tsv' <<<"${lock}"$'\n'"${installed}"$'\n'"${plan}"
}

# dependencies/uv:update moves every package to the latest pyproject.toml allows, then installs it.
dependencies/uv:update() { uv lock --upgrade && uv sync --frozen; }

dependencies/uv:usable() {
  command -v uv >/dev/null 2>&1 && [[ -f pyproject.toml && -f uv.lock ]]
}

# The seam's calls end here; what follows is this provider's own.

# ----------------------------------------------------------------------------------------------------------------------
