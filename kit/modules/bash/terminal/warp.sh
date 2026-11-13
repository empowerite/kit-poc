# shellcheck shell=bash
# warp.sh - Warp's reader: its Meta keys and mouse reporting, read from its settings file (sourced module)
# ----------------------------------------------------------------------------------------------------------------------
# Warp keeps its settings in settings.toml: ~/.warp on macOS, warp-terminal under XDG_CONFIG_HOME or ~/.config
# elsewhere. Warp's source is closed, and its docs do not say whether the file holds every setting or only the changed
# ones, so a key that is not there is Warp's default. The file is read as TOML, so a table, a dotted key, and an inline
# table are one setting. View → Toggle Mouse Reporting changes reporting for the session without the file, which no
# reader sees.
#
#   left_meta     [terminal.input] extra_meta_keys' left_alt, false
#   right_meta    its right_alt, false
#   mouse         [terminal] mouse_reporting_enabled, true
#
# see: modules/bash/terminal.sh, https://docs.warp.dev/terminal/settings/all-settings/

# terminal/warp:settings prints Warp's Meta keys and mouse reporting.
terminal/warp:settings() {
  local file
  if [[ "${OSTYPE:-}" == darwin* ]]
  then
    file=${HOME}/.warp/settings.toml
  else
    file=${XDG_CONFIG_HOME:-${HOME}/.config}/warp-terminal/settings.toml
  fi
  [[ -r "${file}" ]] || file=/dev/null
  if ! yq --input-format=toml --output-format=json --indent=0 '{
      "left_meta": (.terminal.input.extra_meta_keys.left_alt == true),
      "right_meta": (.terminal.input.extra_meta_keys.right_alt == true),
      "mouse": (.terminal.mouse_reporting_enabled != false)}' "${file}" 2>/dev/null
  then
    printf "kit cannot read Warp's settings.toml as TOML\n"
    return 1
  fi
}

# ----------------------------------------------------------------------------------------------------------------------
