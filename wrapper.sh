#!@bash@/bin/bash
set -euo pipefail

: "${GTK_IM_MODULE:=fcitx}" "${QT_IM_MODULE:=fcitx}" "${XMODIFIERS:=@im=fcitx}" "${GTK_USE_PORTAL:=}"
export GTK_IM_MODULE QT_IM_MODULE XMODIFIERS GTK_USE_PORTAL

: "${WINEESYNC:=1}" "${WINEFSYNC:=1}" "${WINEDEBUG:=-all}"
export WINEESYNC WINEFSYNC WINEDEBUG

export PATH="@wineBin@:@winetricks@/bin:$PATH"
WINE="@wineBin@/wine"
WINEBOOT="@wineBin@/wineboot"
WINESERVER="@wineBin@/wineserver"
WINETRICKS="@winetricks@/bin/winetricks"
INSTALLER="@out@/share/kakaotalk/KakaoTalk_Setup.exe"

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
export WINEPREFIX="$PREFIX" WINEARCH=win32

LOCKFILE="$PREFIX/.kakaotalk.lock"
KAKAO_EXE="C:\\Program Files\\Kakao\\KakaoTalk\\KakaoTalk.exe"
KAKAO_EXE_UNIX="$PREFIX/drive_c/Program Files/Kakao/KakaoTalk/KakaoTalk.exe"

HAS_XDOTOOL=0; HAS_WMCTRL=0; HAS_XPROP=0
command -v xdotool >/dev/null 2>&1 && HAS_XDOTOOL=1
command -v wmctrl >/dev/null 2>&1 && HAS_WMCTRL=1
command -v xprop >/dev/null 2>&1 && HAS_XPROP=1

BACKEND="${KAKAOTALK_FORCE_BACKEND:-x11}"

log_info() { echo "[kakaotalk] $*" >&2; }
log_warn() { echo "[kakaotalk] WARNING: $*" >&2; }
log_error() { echo "[kakaotalk] ERROR: $*" >&2; }

reg_add() { "$WINE" reg add "$1" /v "$2" /t "$3" /d "$4" /f >/dev/null 2>&1 || true; }
reg_delete() { "$WINE" reg delete "$1" /v "$2" /f >/dev/null 2>&1 || true; }

get_kakaotalk_pids() {
  pgrep -f "KakaoTalk\.exe" 2>/dev/null | while read -r pid; do
    if [ -r "/proc/$pid/environ" ] && tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -q "WINEPREFIX=$PREFIX"; then
      echo "$pid"
    fi
  done
}

is_wineserver_responsive() { timeout 2 "$WINESERVER" -w 2>/dev/null; }

kill_wine_processes() {
  log_info "Terminating Wine processes..."
  "$WINESERVER" -k 2>/dev/null || true
  sleep 1
  if ! timeout 2 "$WINESERVER" -w 2>/dev/null; then
    local pids; pids=$(get_kakaotalk_pids)
    [ -n "$pids" ] && echo "$pids" | xargs -r kill -9 2>/dev/null || true
    pkill -9 -f "wineserver.*$PREFIX" 2>/dev/null || true
  fi
  sleep 1
}

cleanup_orphans() {
  local pids; pids=$(get_kakaotalk_pids)
  [ -z "$pids" ] && return 0
  log_info "Found existing KakaoTalk processes, checking health..."
  if ! is_wineserver_responsive; then
    log_warn "Wineserver unresponsive, cleaning up orphaned processes..."
    kill_wine_processes
    return 0
  fi
  return 1
}

find_kakaotalk_windows() {
  [ "$HAS_XDOTOOL" -eq 1 ] || return 0
  xdotool search --name "카카오톡" 2>/dev/null || true
  xdotool search --name "KakaoTalk" 2>/dev/null || true
  xdotool search --class "kakaotalk.exe" 2>/dev/null || true
}

try_activate_window() {
  local activated=1
  if [ "$HAS_WMCTRL" -eq 1 ]; then
    wmctrl -a "카카오톡" 2>/dev/null && { log_info "Activated via wmctrl"; activated=0; }
    [ $activated -ne 0 ] && wmctrl -a "KakaoTalk" 2>/dev/null && { log_info "Activated via wmctrl"; activated=0; }
  fi
  if [ $activated -ne 0 ] && [ "$HAS_XDOTOOL" -eq 1 ]; then
    local wid
    wid=$(xdotool search --name "카카오톡" 2>/dev/null | head -1)
    [ -z "$wid" ] && wid=$(xdotool search --name "KakaoTalk" 2>/dev/null | head -1)
    [ -z "$wid" ] && wid=$(xdotool search --class "kakaotalk.exe" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then
      xdotool windowmap "$wid" 2>/dev/null || true
      xdotool windowactivate --sync "$wid" 2>/dev/null && { log_info "Activated via xdotool"; activated=0; }
    fi
  fi
  return $activated
}

has_visible_window() {
  if [ "$HAS_XDOTOOL" -eq 1 ]; then
    local wids
    wids=$(xdotool search --name "카카오톡" 2>/dev/null)
    [ -z "$wids" ] && wids=$(xdotool search --name "KakaoTalk" 2>/dev/null)
    [ -z "$wids" ] && wids=$(xdotool search --class "kakaotalk.exe" 2>/dev/null)
    for wid in $wids; do
      if xdotool getwindowgeometry "$wid" >/dev/null 2>&1; then
        local geom; geom=$(xdotool getwindowgeometry "$wid" 2>/dev/null || true)
        echo "$geom" | grep -qE "Geometry: [5-9][0-9]x[5-9][0-9]|Geometry: [0-9]{3,}x[0-9]+" && return 0
      fi
    done
  fi
  [ "$HAS_WMCTRL" -eq 1 ] && wmctrl -l 2>/dev/null | grep -qiE "카카오톡|kakaotalk" && return 0
  return 1
}

hide_phantom_windows_once() {
  [ "$HAS_XDOTOOL" -eq 1 ] || return 0
  local wid wids WIDTH HEIGHT
  wids=$(xdotool search --class "kakaotalk.exe" 2>/dev/null || true)
  for wid in $wids; do
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)" || continue
    if [ "${WIDTH:-9999}" -le 32 ] && [ "${HEIGHT:-9999}" -le 32 ]; then
      local wm_name=""
      if [ "$HAS_XPROP" -eq 1 ]; then
        wm_name=$(xprop -id "$wid" WM_NAME 2>/dev/null | sed -n 's/.*= "\(.*\)".*/\1/p' || true)
        case "$wm_name" in ""|" ") ;; *) continue ;; esac
      fi
      xdotool windowmove "$wid" -10000 -10000 2>/dev/null || true
      if [ "$HAS_WMCTRL" -eq 1 ]; then
        wmctrl -i -r "$(printf '0x%x' "$wid")" -b add,skip_taskbar,skip_pager 2>/dev/null || true
      fi
      log_info "Moved phantom $wid offscreen (${WIDTH}x${HEIGHT})"
    fi
  done
}

monitor_phantom_windows() {
  [ "$HAS_XDOTOOL" -eq 1 ] || return 0
  local interval="${KAKAOTALK_PHANTOM_INTERVAL:-1}"
  declare -A seen_windows
  while [ -n "$(get_kakaotalk_pids)" ]; do
    local wid wids; wids=$(xdotool search --class "kakaotalk.exe" 2>/dev/null || true)
    for wid in $wids; do
      if [ -z "${seen_windows[$wid]:-}" ]; then
        seen_windows["$wid"]=1
        hide_phantom_windows_once
        break
      fi
    done
    sleep "$interval"
  done
}

acquire_lock() {
  mkdir -p "$(dirname "$LOCKFILE")"
  if [ -f "$LOCKFILE" ]; then
    local old_pid; old_pid=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      grep -q "KakaoTalk\|kakaotalk\|wine" "/proc/$old_pid/cmdline" 2>/dev/null && return 1
    fi
    rm -f "$LOCKFILE"
  fi
  echo $$ > "$LOCKFILE"
}

release_lock() { rm -f "$LOCKFILE" 2>/dev/null || true; }

handle_existing_instance() {
  log_info "KakaoTalk is already running"
  try_activate_window && exit 0
  log_warn "Could not activate existing window"
  local pids; pids=$(get_kakaotalk_pids)
  if [ -n "$pids" ]; then
    if ! is_wineserver_responsive; then
      log_warn "Wineserver unresponsive, forcing restart..."
      kill_wine_processes; release_lock; return 0
    fi
    log_warn "KakaoTalk appears stuck"
    [ "${KAKAOTALK_CLEAN_START:-0}" = "1" ] && { kill_wine_processes; release_lock; return 0; }
    exit 1
  fi
  release_lock
}

run_watchdog() {
  local check_interval=30 no_window_count=0 max_no_window=3
  log_info "Watchdog started"
  while true; do
    sleep "$check_interval"
    local pids; pids=$(get_kakaotalk_pids)
    [ -z "$pids" ] && break
    if has_visible_window; then
      no_window_count=0
    else
      no_window_count=$((no_window_count + 1))
      log_warn "No visible window ($no_window_count/$max_no_window)"
      [ $no_window_count -ge $max_no_window ] && try_activate_window && no_window_count=0
    fi
    is_wineserver_responsive || log_error "Wineserver unresponsive"
  done
}

set_wine_graphics_driver() {
  local driver="$1" have_wayland=0
  [ -f "@wineLib@/wine/winewayland.drv.so" ] || [ -f "@wineLib@/wine/x86_64-unix/winewayland.drv.so" ] && have_wayland=1
  case "$driver" in
    wayland) [ "$have_wayland" -eq 1 ] && reg_add "HKCU\\Software\\Wine\\Drivers" "Graphics" REG_SZ "wayland" || reg_add "HKCU\\Software\\Wine\\Drivers" "Graphics" REG_SZ "x11" ;;
    *) reg_add "HKCU\\Software\\Wine\\Drivers" "Graphics" REG_SZ "x11" ;;
  esac
}

detect_scale_factor() {
  local re='^[0-9]+([.][0-9]+)?$' c
  for var in KAKAOTALK_SCALE GDK_SCALE QT_SCALE_FACTOR; do
    c="${!var:-}"; [ -n "$c" ] && printf '%s' "$c" | grep -Eq "$re" && { echo "$c"; return; }
  done
  [ -n "${XCURSOR_SIZE:-}" ] && command -v awk >/dev/null 2>&1 && { c=$(awk -v s="$XCURSOR_SIZE" 'BEGIN{if(s>0)printf"%.2f",s/24}'); [ -n "$c" ] && { echo "$c"; return; }; }
  echo "1"
}

calculate_dpi() {
  local scale="$1"
  command -v awk >/dev/null 2>&1 && { awk -v s="$scale" 'BEGIN{s=s+0;if(s<=0)s=1;d=96*s;if(d<96)d=96;printf"%d",d+0.5}'; return; }
  local i=${scale%.*}; [ -z "$i" ] || [ "$i" -lt 1 ] 2>/dev/null && i=1; echo $((96 * i))
}

apply_dpi_settings() {
  local dpi="$1" scale="$2"
  reg_add "HKCU\\Control Panel\\Desktop" "LogPixels" REG_DWORD "$dpi"
  reg_add "HKCU\\Control Panel\\Desktop" "Win8DpiScaling" REG_DWORD 1
  local shell_icon small_icon
  if command -v awk >/dev/null 2>&1; then
    shell_icon=$(awk -v s="$scale" 'BEGIN{printf"%d",32*s+0.5}')
    small_icon=$(awk -v s="$scale" 'BEGIN{printf"%d",16*s+0.5}')
  else
    local i=${scale%.*}; [ -z "$i" ] || [ "$i" -lt 1 ] 2>/dev/null && i=1
    shell_icon=$((32 * i)); small_icon=$((16 * i))
  fi
  reg_add "HKCU\\Control Panel\\Desktop\\WindowMetrics" "Shell Icon Size" REG_SZ "$shell_icon"
  reg_add "HKCU\\Control Panel\\Desktop\\WindowMetrics" "Shell Small Icon Size" REG_SZ "$small_icon"
  [ "$BACKEND" = "x11" ] && reg_add "HKCU\\Software\\Wine\\X11 Driver" "DPI" REG_SZ "$dpi"
}

initialize_prefix() {
  [ -d "$PREFIX" ] && return
  log_info "Initializing Wine prefix..."
  mkdir -p "$PREFIX"
  "$WINEBOOT" -u
  apply_dpi_settings "$DPI" "$SCALE_FACTOR"
  reg_add "HKCU\\Control Panel\\International" "Locale" REG_SZ "00000412"
  reg_add "HKLM\\System\\CurrentControlSet\\Control\\Nls\\Language" "Default" REG_SZ "0412"
  reg_add "HKLM\\System\\CurrentControlSet\\Control\\Nls\\Language" "InstallLanguage" REG_SZ "0412"
  if [ "$BACKEND" = "x11" ]; then
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "Decorated" REG_SZ "Y"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "Managed" REG_SZ "Y"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "GrabFullscreen" REG_SZ "N"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "UseXIM" REG_SZ "Y"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "UsePrimarySelection" REG_SZ "N"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "GrabClipboard" REG_SZ "Y"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "UseSystemClipboard" REG_SZ "Y"
    reg_add "HKCU\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKCU\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" "GrabFullscreen" REG_SZ "N"
  fi
  reg_add "HKCU\\Control Panel\\Desktop" "ForegroundLockTimeout" REG_DWORD 2147483647
  reg_add "HKCU\\Control Panel\\Desktop" "ForegroundFlashCount" REG_DWORD 0
  reg_delete "HKCU\\Software\\Wine\\Explorer" "Desktop"
  reg_add "HKCU\\Software\\Wine\\Drivers" "Audio" REG_SZ ""
  reg_add "HKCU\\Software\\Wine\\DragAcceptFiles" "Accept" REG_DWORD 1
  reg_add "HKCU\\Software\\Wine\\OleDropTarget" "Enable" REG_DWORD 1
  set_wine_graphics_driver "$BACKEND"
}

ensure_corefonts() {
  [ -f "$PREFIX/.winetricks_done" ] && return
  log_info "Installing core fonts..."
  "$WINETRICKS" -q corefonts
  touch "$PREFIX/.winetricks_done"
}

configure_fonts() {
  [ -f "$PREFIX/.fonts_configured" ] && return
  log_info "Configuring fonts..."
  mkdir -p "$PREFIX/drive_c/windows/Fonts"
  find -L @fontPath@ -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) | while read -r font; do
    ln -sf "$font" "$PREFIX/drive_c/windows/Fonts/$(basename "$font")" 2>/dev/null || true
  done
  local primary="Pretendard"
  for font in @westernFonts@ @koreanFonts@; do
    reg_add "HKCU\\Software\\Wine\\Fonts\\Replacements" "$font" REG_SZ "$primary"
  done
  reg_add "HKCU\\Control Panel\\Desktop" "FontSmoothing" REG_SZ "2"
  reg_add "HKCU\\Control Panel\\Desktop" "FontSmoothingType" REG_DWORD 2
  reg_add "HKCU\\Control Panel\\Desktop" "FontSmoothingGamma" REG_DWORD 1400
  "$WINEBOOT"
  touch "$PREFIX/.fonts_configured"
}

install_kakaotalk() {
  [ -f "$KAKAO_EXE_UNIX" ] && return
  log_info "Installing KakaoTalk..."
  "$WINE" "$INSTALLER"
}

cleanup_shortcuts() {
  rm -f "$HOME/.local/share/applications/wine/Programs/카카오톡.desktop" 2>/dev/null || true
  rm -f "$HOME/.local/share/applications/wine/Programs/KakaoTalk.desktop" 2>/dev/null || true
}

check_tray_support() {
  [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || return 0
  dbus-send --session --dest=org.kde.StatusNotifierWatcher --print-reply /StatusNotifierWatcher \
    org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierWatcher string:IsStatusNotifierHostRegistered \
    >/dev/null 2>&1 || log_warn "No StatusNotifierItem host detected"
}

main() {
  [ "${KAKAOTALK_CLEAN_START:-0}" = "1" ] && { log_info "Clean start"; kill_wine_processes; release_lock; }
  if [ "${KAKAOTALK_NO_SINGLE_INSTANCE:-0}" != "1" ]; then
    acquire_lock || handle_existing_instance
    trap release_lock EXIT
  fi
  SCALE_FACTOR=$(detect_scale_factor)
  DPI=$(calculate_dpi "$SCALE_FACTOR")
  [ "$SCALE_FACTOR" != "1" ] && log_info "Scale $SCALE_FACTOR (~${DPI} DPI)"
  initialize_prefix
  ensure_corefonts
  configure_fonts
  install_kakaotalk
  cleanup_shortcuts
  set_wine_graphics_driver "$BACKEND"
  apply_dpi_settings "$DPI" "$SCALE_FACTOR"
  reg_add "HKCU\\Control Panel\\Desktop" "ForegroundLockTimeout" REG_DWORD 2147483647
  reg_add "HKCU\\Control Panel\\Desktop" "ForegroundFlashCount" REG_DWORD 0
  [ "$BACKEND" = "x11" ] && {
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKCU\\Software\\Wine\\X11 Driver" "GrabFullscreen" REG_SZ "N"
  }
  check_tray_support
  [ "${KAKAOTALK_ENSURE_EXPLORER:-0}" = "1" ] && "$WINE" start /b explorer.exe >/dev/null 2>&1 || true
  local bg_pids=()
  if [ "${KAKAOTALK_HIDE_PHANTOM:-1}" = "1" ] && [ "$HAS_XDOTOOL" -eq 1 ]; then
    ( sleep 2; hide_phantom_windows_once ) &
    bg_pids+=($!)
    monitor_phantom_windows &
    bg_pids+=($!)
  fi
  [ "${KAKAOTALK_WATCHDOG:-0}" = "1" ] && { run_watchdog & bg_pids+=($!); }
  [ ${#bg_pids[@]} -gt 0 ] && trap "release_lock; kill ${bg_pids[*]} 2>/dev/null || true" EXIT
  log_info "Starting KakaoTalk..."
  exec "$WINE" "$KAKAO_EXE" "$@"
}

main "$@"
