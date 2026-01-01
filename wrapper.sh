#!@bash@/bin/bash

set -euo pipefail

# =============================================================================
# KakaoTalk Wine Wrapper with Reliability Improvements
# =============================================================================
# Features:
#   - Single-instance enforcement with recovery
#   - Orphan process cleanup
#   - Wineserver health monitoring
#   - Window activation helper
#   - Optional watchdog mode
#   - Phantom window hiding
# =============================================================================

# -----------------------------------------------------------------------------
# Input Method Configuration
# -----------------------------------------------------------------------------
: "${GTK_IM_MODULE:=fcitx}"
: "${QT_IM_MODULE:=fcitx}"
: "${XMODIFIERS:=@im=fcitx}"
: "${GTK_USE_PORTAL:=}"
export GTK_IM_MODULE QT_IM_MODULE XMODIFIERS GTK_USE_PORTAL

# -----------------------------------------------------------------------------
# Wine Configuration
# -----------------------------------------------------------------------------
: "${WINEESYNC:=1}"
: "${WINEFSYNC:=1}"
: "${WINEDEBUG:=-all}"
export WINEESYNC WINEFSYNC WINEDEBUG

export PATH="@wineBin@:@winetricks@/bin:$PATH"
WINE="@wineBin@/wine"
WINEBOOT="@wineBin@/wineboot"
WINESERVER="@wineBin@/wineserver"
WINETRICKS="@winetricks@/bin/winetricks"
INSTALLER="@out@/share/kakaotalk/KakaoTalk_Setup.exe"

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
export WINEPREFIX="$PREFIX"
export WINEARCH=win32

LOCKFILE="$PREFIX/.kakaotalk.lock"
KAKAO_EXE="C:\\Program Files\\Kakao\\KakaoTalk\\KakaoTalk.exe"
KAKAO_EXE_UNIX="$PREFIX/drive_c/Program Files/Kakao/KakaoTalk/KakaoTalk.exe"

# -----------------------------------------------------------------------------
# Optional Tools Detection
# -----------------------------------------------------------------------------
HAS_XDOTOOL=0
HAS_WMCTRL=0
command -v xdotool >/dev/null 2>&1 && HAS_XDOTOOL=1
command -v wmctrl >/dev/null 2>&1 && HAS_WMCTRL=1

# -----------------------------------------------------------------------------
# Configuration Options
# -----------------------------------------------------------------------------
# KAKAOTALK_FORCE_BACKEND: Force x11 or wayland graphics driver
# KAKAOTALK_CLEAN_START: Set to 1 to kill existing processes before start
# KAKAOTALK_WATCHDOG: Set to 1 to enable watchdog mode (monitors for stuck state)
# KAKAOTALK_NO_SINGLE_INSTANCE: Set to 1 to disable single-instance enforcement
# KAKAOTALK_HIDE_PHANTOM: Set to 1 to hide phantom windows (requires xdotool)

BACKEND="${KAKAOTALK_FORCE_BACKEND:-}"
if [ -z "$BACKEND" ]; then
  BACKEND="x11"
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo "Wayland detected; using X11 backend for tray stability." >&2
    echo "Set KAKAOTALK_FORCE_BACKEND=wayland to try native Wayland." >&2
  fi
fi

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log_info() {
  echo "[kakaotalk] $*" >&2
}

log_warn() {
  echo "[kakaotalk] WARNING: $*" >&2
}

log_error() {
  echo "[kakaotalk] ERROR: $*" >&2
}

reg_add() {
  "$WINE" reg add "$1" /v "$2" /t "$3" /d "$4" /f >/dev/null 2>&1 || true
}

reg_delete() {
  "$WINE" reg delete "$1" /v "$2" /f >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# Process Management Functions
# -----------------------------------------------------------------------------

# Get PIDs of KakaoTalk.exe processes in our prefix
get_kakaotalk_pids() {
  pgrep -f "KakaoTalk\.exe" 2>/dev/null | while read -r pid; do
    # Verify it's using our prefix by checking /proc/pid/environ
    if [ -r "/proc/$pid/environ" ]; then
      if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -q "WINEPREFIX=$PREFIX"; then
        echo "$pid"
      fi
    fi
  done
}

# Check if wineserver for our prefix is responsive
is_wineserver_responsive() {
  timeout 2 "$WINESERVER" -w 2>/dev/null
  return $?
}

# Kill wineserver and all associated processes
kill_wine_processes() {
  log_info "Terminating Wine processes..."
  "$WINESERVER" -k 2>/dev/null || true
  sleep 1

  # Force kill if still running
  if ! timeout 2 "$WINESERVER" -w 2>/dev/null; then
    # Kill any remaining KakaoTalk processes
    local pids
    pids=$(get_kakaotalk_pids)
    if [ -n "$pids" ]; then
      echo "$pids" | xargs -r kill -9 2>/dev/null || true
    fi

    # Force kill wineserver
    pkill -9 -f "wineserver.*$PREFIX" 2>/dev/null || true
  fi

  sleep 1
}

# Cleanup orphaned processes before launch
cleanup_orphans() {
  local pids
  pids=$(get_kakaotalk_pids)

  if [ -z "$pids" ]; then
    return 0
  fi

  log_info "Found existing KakaoTalk processes, checking health..."

  # Check if wineserver is responsive
  if ! is_wineserver_responsive; then
    log_warn "Wineserver unresponsive, cleaning up orphaned processes..."
    kill_wine_processes
    return 0
  fi

  return 1  # Processes exist and are healthy
}

# -----------------------------------------------------------------------------
# Window Management Functions
# -----------------------------------------------------------------------------

# Try to find KakaoTalk window IDs
find_kakaotalk_windows() {
  if [ "$HAS_XDOTOOL" -eq 1 ]; then
    xdotool search --name "KakaoTalk" 2>/dev/null || true
    xdotool search --class "kakaotalk.exe" 2>/dev/null || true
  fi
}

# Try to activate (bring to foreground) an existing KakaoTalk window
try_activate_window() {
  local activated=1

  if [ "$HAS_WMCTRL" -eq 1 ]; then
    if wmctrl -a "KakaoTalk" 2>/dev/null; then
      log_info "Activated existing KakaoTalk window via wmctrl"
      activated=0
    fi
  fi

  if [ $activated -ne 0 ] && [ "$HAS_XDOTOOL" -eq 1 ]; then
    local wid
    wid=$(xdotool search --name "KakaoTalk" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then
      if xdotool windowactivate --sync "$wid" 2>/dev/null; then
        log_info "Activated existing KakaoTalk window via xdotool"
        activated=0
      fi
    fi
  fi

  return $activated
}

# Check if there's a visible KakaoTalk window
has_visible_window() {
  if [ "$HAS_XDOTOOL" -eq 1 ]; then
    local wids
    wids=$(xdotool search --name "KakaoTalk" 2>/dev/null)
    if [ -n "$wids" ]; then
      for wid in $wids; do
        # Check if window is mapped (visible)
        if xdotool getwindowgeometry "$wid" >/dev/null 2>&1; then
          local geom
          geom=$(xdotool getwindowgeometry "$wid" 2>/dev/null || true)
          # Filter out tiny phantom windows (less than 50x50)
          if echo "$geom" | grep -qE "Geometry: [5-9][0-9]+x[5-9][0-9]+|Geometry: [0-9]{3,}x[0-9]+"; then
            return 0
          fi
        fi
      done
    fi
  fi

  if [ "$HAS_WMCTRL" -eq 1 ]; then
    if wmctrl -l 2>/dev/null | grep -qi "kakaotalk"; then
      return 0
    fi
  fi

  return 1
}

# Hide phantom windows (small invisible windows used by KakaoTalk)
hide_phantom_windows() {
  if [ "$HAS_XDOTOOL" -ne 1 ]; then
    return
  fi

  sleep 3  # Wait for windows to spawn

  local wids
  wids=$(xdotool search --class "kakaotalk.exe" 2>/dev/null || true)

  for wid in $wids; do
    local geom
    geom=$(xdotool getwindowgeometry "$wid" 2>/dev/null || true)
    if [ -z "$geom" ]; then
      continue
    fi

    # Check for very small windows (phantom windows are typically 1x1 to 32x32)
    if echo "$geom" | grep -qE "Geometry: [0-3]?[0-9]x[0-3]?[0-9]$"; then
      log_info "Hiding phantom window $wid"
      xdotool windowminimize "$wid" 2>/dev/null || true
    fi
  done
}

# -----------------------------------------------------------------------------
# Single Instance Management
# -----------------------------------------------------------------------------

acquire_lock() {
  mkdir -p "$(dirname "$LOCKFILE")"

  if [ -f "$LOCKFILE" ]; then
    local old_pid
    old_pid=$(cat "$LOCKFILE" 2>/dev/null || true)

    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      # Process exists, check if it's actually KakaoTalk
      if grep -q "KakaoTalk\|kakaotalk\|wine" "/proc/$old_pid/cmdline" 2>/dev/null; then
        return 1  # Lock held by valid process
      fi
    fi

    # Stale lock, remove it
    rm -f "$LOCKFILE"
  fi

  echo $$ > "$LOCKFILE"
  return 0
}

release_lock() {
  rm -f "$LOCKFILE" 2>/dev/null || true
}

handle_existing_instance() {
  log_info "KakaoTalk is already running"

  # Try to bring existing window to foreground
  if try_activate_window; then
    log_info "Brought existing window to foreground"
    exit 0
  fi

  # Window activation failed, check if stuck
  log_warn "Could not activate existing window"

  local pids
  pids=$(get_kakaotalk_pids)

  if [ -n "$pids" ]; then
    # Check wineserver health
    if ! is_wineserver_responsive; then
      log_warn "Wineserver unresponsive, forcing restart..."
      kill_wine_processes
      release_lock
      return 0  # Proceed with new launch
    fi

    # Wineserver responsive but window not activating - likely stuck
    log_warn "KakaoTalk appears stuck (process running but no activatable window)"
    log_info "Use KAKAOTALK_CLEAN_START=1 to force restart, or manually kill processes"

    if [ "${KAKAOTALK_CLEAN_START:-0}" = "1" ]; then
      log_info "Clean start requested, terminating existing processes..."
      kill_wine_processes
      release_lock
      return 0
    fi

    exit 1
  fi

  # No processes found, stale lock
  release_lock
  return 0
}

# -----------------------------------------------------------------------------
# Watchdog Functions
# -----------------------------------------------------------------------------

run_watchdog() {
  local check_interval=30
  local no_window_count=0
  local max_no_window=3

  log_info "Watchdog started (checking every ${check_interval}s)"

  while true; do
    sleep "$check_interval"

    # Check if KakaoTalk process still exists
    local pids
    pids=$(get_kakaotalk_pids)

    if [ -z "$pids" ]; then
      log_info "KakaoTalk process ended, watchdog exiting"
      break
    fi

    # Check for visible window
    if has_visible_window; then
      no_window_count=0
    else
      no_window_count=$((no_window_count + 1))
      log_warn "No visible window detected ($no_window_count/$max_no_window)"

      if [ $no_window_count -ge $max_no_window ]; then
        log_error "KakaoTalk appears stuck (no visible window for $((check_interval * max_no_window))s)"
        log_info "Consider running: KAKAOTALK_CLEAN_START=1 kakaotalk"

        # Try to activate window one more time
        if try_activate_window; then
          no_window_count=0
          log_info "Successfully recovered window"
        fi
      fi
    fi

    # Check wineserver health
    if ! is_wineserver_responsive; then
      log_error "Wineserver became unresponsive"
      log_info "Run 'KAKAOTALK_CLEAN_START=1 kakaotalk' to restart"
    fi
  done
}

# -----------------------------------------------------------------------------
# Graphics Driver Configuration
# -----------------------------------------------------------------------------

set_wine_graphics_driver() {
  local driver="$1"
  local have_wayland=0

  if [ -f "@wineLib@/wine/winewayland.drv.so" ] || [ -f "@wineLib@/wine/x86_64-unix/winewayland.drv.so" ]; then
    have_wayland=1
  fi

  case "$driver" in
    wayland)
      if [ "$have_wayland" -eq 1 ]; then
        reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" "Graphics" REG_SZ "wayland"
      else
        reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" "Graphics" REG_SZ "x11"
      fi
      ;;
    x11|*)
      reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" "Graphics" REG_SZ "x11"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# DPI/Scaling Configuration
# -----------------------------------------------------------------------------

detect_scale_factor() {
  local number_re='^[0-9]+([.][0-9]+)?$'
  local candidate

  for var in KAKAOTALK_SCALE GDK_SCALE QT_SCALE_FACTOR; do
    candidate="${!var:-}"
    if [ -n "$candidate" ] && printf '%s' "$candidate" | grep -Eq "$number_re"; then
      echo "$candidate"
      return
    fi
  done

  if [ -n "${XCURSOR_SIZE:-}" ] && command -v awk >/dev/null 2>&1; then
    candidate=$(awk -v size="$XCURSOR_SIZE" 'BEGIN { if (size > 0) printf "%.2f", size/24; }')
    if [ -n "$candidate" ]; then
      echo "$candidate"
      return
    fi
  fi

  echo "1"
}

calculate_dpi() {
  local scale="$1"

  if command -v awk >/dev/null 2>&1; then
    awk -v s="$scale" 'BEGIN {
      if (s !~ /^[0-9]+(\.[0-9]+)?$/ || s <= 0) s = 1;
      dpi = 96 * s;
      if (dpi < 96) dpi = 96;
      printf "%d", (dpi + 0.5);
    }'
  else
    local int_scale=${scale%.*}
    if [ -z "$int_scale" ] || [ "$int_scale" -lt 1 ] 2>/dev/null; then
      int_scale=1
    fi
    echo $((96 * int_scale))
  fi
}

apply_dpi_settings() {
  local dpi="$1"
  local scale="$2"

  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "LogPixels" REG_DWORD "$dpi"
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "Win8DpiScaling" REG_DWORD 1

  local shell_icon_size
  local small_icon_size
  if command -v awk >/dev/null 2>&1; then
    shell_icon_size=$(awk -v s="$scale" 'BEGIN { printf "%d", 32 * s + 0.5 }')
    small_icon_size=$(awk -v s="$scale" 'BEGIN { printf "%d", 16 * s + 0.5 }')
  else
    local int_scale=${scale%.*}
    if [ -z "$int_scale" ] || [ "$int_scale" -lt 1 ] 2>/dev/null; then
      int_scale=1
    fi
    shell_icon_size=$((32 * int_scale))
    small_icon_size=$((16 * int_scale))
  fi

  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics" "Shell Icon Size" REG_SZ "$shell_icon_size"
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics" "Shell Small Icon Size" REG_SZ "$small_icon_size"

  if [ "$BACKEND" = "x11" ]; then
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "DPI" REG_SZ "$dpi"
  fi
}

# -----------------------------------------------------------------------------
# Wine Prefix Initialization
# -----------------------------------------------------------------------------

initialize_prefix() {
  if [ -d "$PREFIX" ]; then
    return
  fi

  log_info "Initializing Wine prefix..."
  mkdir -p "$PREFIX"
  "$WINEBOOT" -u

  apply_dpi_settings "$DPI" "$SCALE_FACTOR"

  # Korean locale settings
  reg_add "HKEY_CURRENT_USER\\Control Panel\\International" "Locale" REG_SZ "00000412"
  reg_add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" "Default" REG_SZ "0412"
  reg_add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" "InstallLanguage" REG_SZ "0412"

  # X11 driver settings for better window management
  if [ "$BACKEND" = "x11" ]; then
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "Decorated" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "Managed" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "GrabFullscreen" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseXIM" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UsePrimarySelection" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "GrabClipboard" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseSystemClipboard" REG_SZ "Y"
  fi

  # Prevent focus stealing - max timeout = never steal focus
  # 0x7FFFFFFF = max signed 32-bit int, effectively infinite
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "ForegroundLockTimeout" REG_DWORD 2147483647
  # FlashCount 0 = flash infinitely in taskbar instead of stealing focus
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "ForegroundFlashCount" REG_DWORD 0

  # Disable virtual desktop (can cause window issues)
  reg_delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" "Desktop"

  # Audio (disabled - KakaoTalk uses notification sounds which can conflict)
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" "Audio" REG_SZ ""

  # Drag and drop support
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\DragAcceptFiles" "Accept" REG_DWORD 1
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\OleDropTarget" "Enable" REG_DWORD 1

  set_wine_graphics_driver "$BACKEND"
}

ensure_corefonts() {
  if [ ! -f "$PREFIX/.winetricks_done" ]; then
    log_info "Installing core fonts via winetricks..."
    "$WINETRICKS" -q corefonts
    touch "$PREFIX/.winetricks_done"
  fi
}

configure_fonts() {
  if [ -f "$PREFIX/.fonts_configured" ]; then
    return
  fi

  log_info "Configuring font replacements..."

  mkdir -p "$PREFIX/drive_c/windows/Fonts"
  find -L @fontPath@ -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) | while read -r font; do
    ln -sf "$font" "$PREFIX/drive_c/windows/Fonts/$(basename "$font")" 2>/dev/null || true
  done

  local emoji_file="NotoColorEmoji.ttf"
  local detected
  detected=$(find "$PREFIX/drive_c/windows/Fonts" -maxdepth 1 \( -iname "NotoColorEmoji.ttf" -o -iname "NotoColorEmoji.otf" \) -print -quit)
  if [ -n "$detected" ]; then
    emoji_file=$(basename "$detected")
  fi

  local primary_font="Pretendard"
  local serif_font="Pretendard"
  local emoji_font="Noto Color Emoji"
  local font_link_value="$emoji_file,$emoji_font"

  for font in @westernFonts@ @koreanFonts@; do
    local replacement="$primary_font"
    case "$font" in
      "Batang"|"Gungsuh")
        replacement="$serif_font"
        ;;
    esac
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" "$font" REG_SZ "$replacement"
  done

  for font in "Segoe UI Emoji" "Segoe UI Symbol" "Apple Color Emoji" "Symbola"; do
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" "$font" REG_SZ "$emoji_font"
  done

  local link_targets=("Tahoma" "Segoe UI" "Malgun Gothic" "Microsoft Sans Serif" "Gulim" "Batang" "$primary_font" "$serif_font")
  for font in "${link_targets[@]}"; do
    reg_add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" "$font" REG_MULTI_SZ "$font_link_value"
  done

  # Font smoothing
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothing" REG_SZ "2"
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothingType" REG_DWORD 2
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothingGamma" REG_DWORD 1400

  "$WINEBOOT"
  touch "$PREFIX/.fonts_configured"
}

install_kakaotalk() {
  if [ ! -f "$KAKAO_EXE_UNIX" ]; then
    log_info "Installing KakaoTalk..."
    "$WINE" "$INSTALLER"
  fi
}

cleanup_shortcuts() {
  rm -f "$HOME/.local/share/applications/wine/Programs/카카오톡.desktop" 2>/dev/null || true
  rm -f "$HOME/.local/share/applications/wine/Programs/KakaoTalk.desktop" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Tray Support Check
# -----------------------------------------------------------------------------

check_tray_support() {
  # Check if we're on Wayland without proper tray support
  if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    # Check for SNI-capable tray
    if ! dbus-send --session --dest=org.kde.StatusNotifierWatcher \
         --print-reply /StatusNotifierWatcher \
         org.freedesktop.DBus.Properties.Get \
         string:org.kde.StatusNotifierWatcher string:IsStatusNotifierHostRegistered \
         >/dev/null 2>&1; then
      log_warn "No StatusNotifierItem host detected. Tray icons may not work properly."
      log_info "Consider installing a tray extension for your desktop environment."
    fi
  fi
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------

main() {
  # Handle clean start request
  if [ "${KAKAOTALK_CLEAN_START:-0}" = "1" ]; then
    log_info "Clean start requested"
    kill_wine_processes
    release_lock
  fi

  # Single instance enforcement
  if [ "${KAKAOTALK_NO_SINGLE_INSTANCE:-0}" != "1" ]; then
    if ! acquire_lock; then
      handle_existing_instance
    fi
    trap release_lock EXIT
  fi

  # Calculate DPI settings
  SCALE_FACTOR=$(detect_scale_factor)
  DPI=$(calculate_dpi "$SCALE_FACTOR")

  if [ "$SCALE_FACTOR" != "1" ]; then
    log_info "Applying scale factor $SCALE_FACTOR (~${DPI} DPI)"
  fi

  # Initialize Wine environment
  initialize_prefix
  ensure_corefonts
  configure_fonts
  install_kakaotalk
  cleanup_shortcuts

  # Apply runtime settings
  set_wine_graphics_driver "$BACKEND"
  apply_dpi_settings "$DPI" "$SCALE_FACTOR"

  # Apply focus-stealing prevention (runtime, not just init)
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "ForegroundLockTimeout" REG_DWORD 2147483647
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "ForegroundFlashCount" REG_DWORD 0
  if [ "$BACKEND" = "x11" ]; then
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "GrabFullscreen" REG_SZ "N"
  fi

  # Check tray support
  check_tray_support

  # Hide phantom windows in background if requested
  if [ "${KAKAOTALK_HIDE_PHANTOM:-0}" = "1" ] && [ "$HAS_XDOTOOL" -eq 1 ]; then
    hide_phantom_windows &
  fi

  # Start watchdog if requested
  if [ "${KAKAOTALK_WATCHDOG:-0}" = "1" ]; then
    run_watchdog &
    WATCHDOG_PID=$!
    trap "release_lock; kill $WATCHDOG_PID 2>/dev/null || true" EXIT
  fi

  # Launch KakaoTalk
  log_info "Starting KakaoTalk..."
  exec "$WINE" "$KAKAO_EXE" "$@"
}

main "$@"
