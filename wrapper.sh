#!@bash@/bin/bash

set -euo pipefail

: "${GTK_IM_MODULE:=fcitx}"
: "${QT_IM_MODULE:=fcitx}"
: "${XMODIFIERS:=@im=fcitx}"
: "${GTK_USE_PORTAL:=}"
export GTK_IM_MODULE QT_IM_MODULE XMODIFIERS GTK_USE_PORTAL

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

BACKEND="${KAKAOTALK_FORCE_BACKEND:-}"
if [ -z "$BACKEND" ]; then
  BACKEND="x11"
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo "Wayland session detected; defaulting to X11 for tray stability. Set KAKAOTALK_FORCE_BACKEND=wayland to try the Wayland driver." >&2
  fi
fi

if [ "${KAKAOTALK_CLEAN_START:-0}" = "1" ]; then
  "$WINESERVER" -k 2>/dev/null || true
fi

reg_add() {
  "$WINE" reg add "$1" /v "$2" /t "$3" /d "$4" /f >/dev/null 2>&1 || true
}

reg_delete() {
  "$WINE" reg delete "$1" /v "$2" /f >/dev/null 2>&1 || true
}

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

initialize_prefix() {
  if [ -d "$PREFIX" ]; then
    return
  fi

  mkdir -p "$PREFIX"
  "$WINEBOOT" -u

  apply_dpi_settings "$DPI" "$SCALE_FACTOR"
  reg_add "HKEY_CURRENT_USER\\Control Panel\\International" "Locale" REG_SZ "00000412"
  reg_add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" "Default" REG_SZ "0412"
  reg_add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" "InstallLanguage" REG_SZ "0412"

  if [ "$BACKEND" = "x11" ]; then
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "Decorated" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "Managed" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseTakeFocus" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseXIM" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UsePrimarySelection" REG_SZ "N"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "GrabClipboard" REG_SZ "Y"
    reg_add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" "UseSystemClipboard" REG_SZ "Y"
  fi

  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "ForegroundLockTimeout" REG_DWORD 200000
  reg_delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" "Desktop"
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" "Audio" REG_SZ ""
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\DragAcceptFiles" "Accept" REG_DWORD 1
  reg_add "HKEY_CURRENT_USER\\Software\\Wine\\OleDropTarget" "Enable" REG_DWORD 1

  set_wine_graphics_driver "$BACKEND"
}

ensure_corefonts() {
  if [ ! -f "$PREFIX/.winetricks_done" ]; then
    "$WINETRICKS" -q corefonts
    touch "$PREFIX/.winetricks_done"
  fi
}

configure_fonts() {
  if [ -f "$PREFIX/.fonts_configured" ]; then
    return
  fi

  echo "Configuring font replacements..." >&2

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

  local primary_font="Baekmuk Gulim"
  local serif_font="Baekmuk Batang"
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

  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothing" REG_SZ "2"
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothingType" REG_DWORD 2
  reg_add "HKEY_CURRENT_USER\\Control Panel\\Desktop" "FontSmoothingGamma" REG_DWORD 1400

  "$WINEBOOT"
  touch "$PREFIX/.fonts_configured"
}

install_kakaotalk() {
  if [ ! -f "$PREFIX/drive_c/Program Files/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
    echo "Installing KakaoTalk..."
    "$WINE" "$INSTALLER"
  fi
}

cleanup_shortcuts() {
  rm -f "$HOME/.local/share/applications/wine/Programs/카카오톡.desktop" 2>/dev/null
  rm -f "$HOME/.local/share/applications/wine/Programs/KakaoTalk.desktop" 2>/dev/null
}

SCALE_FACTOR=$(detect_scale_factor)
DPI=$(calculate_dpi "$SCALE_FACTOR")

if [ "$SCALE_FACTOR" != "1" ]; then
  echo "Applying scale factor $SCALE_FACTOR (~${DPI} DPI) for Wine." >&2
fi

initialize_prefix
ensure_corefonts
configure_fonts
install_kakaotalk
cleanup_shortcuts

set_wine_graphics_driver "$BACKEND"
apply_dpi_settings "$DPI" "$SCALE_FACTOR"

"$WINE" "C:\\Program Files\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
