#!/bin/bash
# JumpServer → Warp / Warp-cn.
# Writes a temp launch/tab config, then opens warp:// or warposs://.
# Env comes from connect.json. JMS_WARP_METHOD=keystroke|type keeps the old AppleScript fallback.
set -euo pipefail

LOG_DIR="${HOME}/Library/Logs/jumpserver-client-launchers"
HELPER="${JMS_HELPER:-}"
PROTOCOL="${JMS_PROTOCOL:-ssh}"
USERNAME="${JMS_USERNAME:-}"
HOST="${JMS_HOST:-}"
PORT="${JMS_PORT:-22}"
VALUE="${JMS_VALUE:-}"
TITLE="${JMS_ASSET_NAME:-JMS}"
WARP_APP="${JMS_WARP_APP:-/Applications/Warp.app}"
WARP_SCHEME="${JMS_WARP_SCHEME:-warp}"
METHOD="${JMS_WARP_METHOD:-launch}"
DRY_RUN="${JMS_WARP_DRY_RUN:-}"

warp_home() {
  if [[ -n "${JMS_WARP_HOME:-}" ]]; then
    printf '%s' "${JMS_WARP_HOME}"
    return
  fi
  case "${WARP_SCHEME}" in
    warposs) printf '%s' "${HOME}/.warp-oss" ;;
    *) printf '%s' "${HOME}/.warp" ;;
  esac
}

warp_tab_config_dir() { printf '%s/tab_configs' "$(warp_home)"; }
# ponytail: Warp launch YAML lives in launch_configurations; the old jms-open-warp.sh
# called warp_launch_config_dirs without defining it. Upgrade: read Warp's configured path.
warp_launch_config_dir() { printf '%s/launch_configurations' "$(warp_home)"; }

yaml_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "${s}"
}

toml_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "${s}"
}

notify() {
  [[ -n "${DRY_RUN}" ]] && return 0
  osascript -e "display notification \"$1\" with title \"JumpServer → Warp\"" 2>/dev/null || true
}

log() {
  [[ -n "${DRY_RUN}" ]] && return 0
  mkdir -p "${LOG_DIR}"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"${LOG_DIR}/warp.log"
}

quote_cmd() {
  local out="" part
  for part in "$@"; do
    out+="$(printf '%q' "${part}") "
  done
  printf '%s' "${out% }"
}

open_uri() {
  local uri=$1
  log "open URI: ${uri}"
  [[ -n "${DRY_RUN}" ]] && return 0
  if open "${uri}" 2>>"${LOG_DIR}/warp.log"; then
    return 0
  fi
  open -a "${WARP_APP}" "${uri}" 2>>"${LOG_DIR}/warp.log" || open -a "${WARP_APP}" 2>>"${LOG_DIR}/warp.log" || true
}

# Check if Warp is up via the local control port (9277). Port beats pgrep across subshells.
warp_is_running_with_windows() {
  lsof -iTCP:9277 -sTCP:LISTEN >/dev/null 2>&1
}

launch_in_existing_window() {
  local stamp name dir cfg_path safe_title safe_cmd
  stamp="$(date +%s)-$$"
  name="jms-${stamp}"
  dir="$(warp_tab_config_dir)"
  mkdir -p "${dir}"
  safe_title="$(toml_escape "JMS ${TITLE}")"
  safe_cmd="$(toml_escape "${FULL_CMD}")"
  cfg_path="${dir}/${name}.toml"
  cat >"${cfg_path}" <<EOF
name = "JumpServer ${TITLE}"
title = "${safe_title}"

[[panes]]
id = "main"
type = "terminal"
directory = "$(toml_escape "${HOME}")"
commands = ["${safe_cmd}"]
EOF
  log "wrote tab config: ${cfg_path}"
  open_uri "${WARP_SCHEME}://tab_config/${name}"
  (
    sleep 30
    rm -f "${cfg_path}" 2>/dev/null || true
  ) &
  disown 2>/dev/null || true
}

launch_via_config() {
  local stamp name dir cfg_path
  stamp="$(date +%s)-$$"
  name="jms-${stamp}"
  dir="$(warp_launch_config_dir)"
  mkdir -p "${dir}"
  cfg_path="${dir}/${name}.yaml"
  cat >"${cfg_path}" <<EOF
---
name: ${name}
windows:
  - tabs:
      - title: $(yaml_escape "JMS ${TITLE}")
        layout:
          cwd: $(yaml_escape "${HOME}")
          commands:
            - exec: $(yaml_escape "${FULL_CMD}")
EOF
  log "wrote launch config: ${cfg_path}"
  open_uri "${WARP_SCHEME}://launch/${name}"
  (
    sleep 12
    rm -f "${cfg_path}" 2>/dev/null || true
  ) &
  disown 2>/dev/null || true
}

applescript_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "${s}"
}

warp_bundle_name() {
  defaults read "${WARP_APP}/Contents/Info.plist" CFBundleName 2>/dev/null \
    || defaults read "${WARP_APP}/Contents/Info.plist" CFBundleDisplayName 2>/dev/null \
    || basename "${WARP_APP}" .app
}

launch_via_keystroke() {
  local press_return=${1:-1}
  local esc name
  esc="$(applescript_escape "${FULL_CMD}")"
  name="$(warp_bundle_name)"
  [[ -n "${DRY_RUN}" ]] && return 0
  open -a "${WARP_APP}" || true
  open "${WARP_SCHEME}://action/new_tab" 2>>"${LOG_DIR}/warp.log" || true
  if [[ "${press_return}" == "1" ]]; then
    osascript <<EOF
tell application "${name}" to activate
delay 1.0
tell application "System Events"
  if not (exists process "${name}") then error "Warp process not found: ${name}"
  keystroke "${esc}"
  key code 36
end tell
EOF
  else
    osascript <<EOF
tell application "${name}" to activate
delay 1.0
tell application "System Events"
  if not (exists process "${name}") then error "Warp process not found: ${name}"
  keystroke "${esc}"
end tell
EOF
  fi
}

self_check() {
  local tmp yaml toml
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/jms-warp-check.XXXXXX")"
  export HOME="${tmp}"
  export JMS_WARP_DRY_RUN=1
  export JMS_WARP_HOME="${tmp}/.warp"
  DRY_RUN=1
  WARP_SCHEME=warp
  TITLE='db "prod"'
  FULL_CMD='/tmp/client ssh JMS-id@host -p 2222 -P tok'
  launch_via_config
  launch_in_existing_window
  yaml="$(echo "${tmp}"/.warp/launch_configurations/jms-*.yaml)"
  toml="$(echo "${tmp}"/.warp/tab_configs/jms-*.toml)"
  grep -q 'exec: "/tmp/client ssh JMS-id@host -p 2222 -P tok"' "${yaml}"
  grep -q 'title: "JMS db \\"prod\\""' "${yaml}"
  grep -q 'commands = \["/tmp/client ssh JMS-id@host -p 2222 -P tok"\]' "${toml}"
  rm -rf "${tmp}"
  echo "warp launcher self-check ok"
}

main() {
  if [[ -z "${HELPER}" || -z "${USERNAME}" || -z "${HOST}" ]]; then
    log "ERROR: missing helper/username/host"
    notify "缺少 JumpServer 连接参数"
    exit 1
  fi
  if [[ -z "${DRY_RUN}" && ! -d "${WARP_APP}" ]]; then
    log "ERROR: app not found: ${WARP_APP}"
    notify "未找到 $(basename "${WARP_APP}")"
    exit 1
  fi
  FULL_CMD="$(quote_cmd "${HELPER}" "${PROTOCOL}" "${USERNAME}@${HOST}" -p "${PORT}" -P "${VALUE}")"
  log "method=${METHOD} app=${WARP_APP} scheme=${WARP_SCHEME} cmd=${FULL_CMD}"
  case "${METHOD}" in
    type) launch_via_keystroke 0 ;;
    keystroke) launch_via_keystroke 1 ;;
    launch|*)
      if [[ -z "${DRY_RUN}" ]] && warp_is_running_with_windows; then
        log "Warp is running — opening a tab in the existing window"
        launch_in_existing_window
      else
        log "Warp is not running — creating a window via launch config"
        launch_via_config
      fi
      ;;
  esac
}

if [[ "${1:-}" == "--self-check" ]]; then
  self_check
else
  main
fi
