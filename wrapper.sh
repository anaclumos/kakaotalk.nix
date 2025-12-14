#!@bash@/bin/bash

# Environment variables
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export GTK_USE_PORTAL=
: "
  Respect host portals for dialogs where possible. While Wine apps
  do not directly use portals, this helps when helpers are spawned.
"

# Performance toggles
[ -z "$WINEESYNC" ] && export WINEESYNC=1
[ -z "$WINEFSYNC" ] && export WINEFSYNC=1
[ -z "$WINEDEBUG" ] && export WINEDEBUG=-all

# Paths
export PATH="@wineBin@:@winetricks@/bin:$PATH"
WINE="@wineBin@/wine"
WINEBOOT="@wineBin@/wineboot"
WINESERVER="@wineBin@/wineserver"
WINETRICKS="@winetricks@/bin/winetricks"
INSTALLER="@out@/share/kakaotalk/KakaoTalk_Setup.exe"

# Data directory
PREFIX="$XDG_DATA_HOME"
if [ -z "$PREFIX" ]; then
  PREFIX="$HOME/.local/share"
fi
PREFIX="$PREFIX/kakaotalk"
export WINEPREFIX="$PREFIX"

# Backend detection
# Default to X11 (Xwayland) for stable tray behavior; allow override to try
# Wine's Wayland driver.
if [ -n "$KAKAOTALK_FORCE_BACKEND" ]; then
  BACKEND="$KAKAOTALK_FORCE_BACKEND"
else
  BACKEND=x11
  if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Wayland session detected; defaulting to X11 for tray stability. Set KAKAOTALK_FORCE_BACKEND=wayland to try the Wayland driver." >&2
  fi
fi

# Optional clean start to recover from a stuck tray/session
if [ "$KAKAOTALK_CLEAN_START" = "1" ]; then
  "$WINESERVER" -k 2>/dev/null || true
fi

# Helper function to set Wine graphics driver
set_wine_graphics_driver() {
  local driver="$1"
  local have_wayland=0
  
  # Check if wayland driver exists
  if [ -f "@wineLib@/wine/winewayland.drv.so" ] || [ -f "@wineLib@/wine/x86_64-unix/winewayland.drv.so" ]; then
    have_wayland=1
  fi

  case "$driver" in
    wayland)
      if [ "$have_wayland" -eq 1 ]; then
        "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Graphics" /t REG_SZ /d "wayland" /f >/dev/null 2>&1 || true
      else
        "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Graphics" /t REG_SZ /d "x11" /f >/dev/null 2>&1 || true
      fi
      ;;
    x11|*)
      "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Graphics" /t REG_SZ /d "x11" /f >/dev/null 2>&1 || true
      ;;
  esac
}

# Detect host scale factor (default 1) to keep Wine UI/tray sizes aligned
detect_scale_factor() {
  local number_re='^[0-9]+([.][0-9]+)?$'

  if [ -n "$KAKAOTALK_SCALE" ] && printf '%s' "$KAKAOTALK_SCALE" | grep -Eq "$number_re"; then
    echo "$KAKAOTALK_SCALE"
    return
  fi

  if [ -n "$GDK_SCALE" ] && printf '%s' "$GDK_SCALE" | grep -Eq "$number_re"; then
    echo "$GDK_SCALE"
    return
  fi

  if [ -n "$QT_SCALE_FACTOR" ] && printf '%s' "$QT_SCALE_FACTOR" | grep -Eq "$number_re"; then
    echo "$QT_SCALE_FACTOR"
    return
  fi

  if [ -n "$XCURSOR_SIZE" ] && command -v awk >/dev/null 2>&1; then
    local approx
    approx=$(awk -v size="$XCURSOR_SIZE" 'BEGIN { if (size > 0) printf "%.2f", size/24; }')
    if [ -n "$approx" ]; then
      echo "$approx"
      return
    fi
  fi

  echo "1"
}

calculate_dpi() {
  if command -v awk >/dev/null 2>&1; then
    awk -v s="$1" 'BEGIN {
      if (s !~ /^[0-9]+(\.[0-9]+)?$/ || s <= 0) s = 1;
      dpi = 96 * s;
      if (dpi < 96) dpi = 96;
      printf "%d", (dpi + 0.5);
    }'
  else
    local int_scale=${1%.*}
    case "$int_scale" in
      ''|0) int_scale=1 ;;
    esac
    if [ "$int_scale" -lt 1 ] 2>/dev/null; then
      int_scale=1
    fi
    echo $((96 * int_scale))
  fi
}

apply_dpi_settings() {
  local dpi="$1"
  local scale="$2"

  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "LogPixels" /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "Win8DpiScaling" /t REG_DWORD /d 1 /f >/dev/null 2>&1 || true

  # Scale shell/tray icon sizes (default: 32 for large, 16 for small)
  # WindowMetrics uses negative twips: -15 * size (for 96 DPI baseline)
  # But "Shell Icon Size" is in pixels, not twips
  local shell_icon_size
  local small_icon_size
  if command -v awk >/dev/null 2>&1; then
    shell_icon_size=$(awk -v s="$scale" 'BEGIN { printf "%d", 32 * s + 0.5 }')
    small_icon_size=$(awk -v s="$scale" 'BEGIN { printf "%d", 16 * s + 0.5 }')
  else
    local int_scale=${scale%.*}
    [ -z "$int_scale" ] || [ "$int_scale" -lt 1 ] 2>/dev/null && int_scale=1
    shell_icon_size=$((32 * int_scale))
    small_icon_size=$((16 * int_scale))
  fi
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics" /v "Shell Icon Size" /t REG_SZ /d "$shell_icon_size" /f >/dev/null 2>&1 || true
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics" /v "Shell Small Icon Size" /t REG_SZ /d "$small_icon_size" /f >/dev/null 2>&1 || true

  if [ "$BACKEND" = x11 ]; then
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "DPI" /t REG_SZ /d "$dpi" /f >/dev/null 2>&1 || true
  fi
}

SCALE_FACTOR=$(detect_scale_factor)
DPI=$(calculate_dpi "$SCALE_FACTOR")

if [ "$SCALE_FACTOR" != "1" ]; then
  echo "Applying scale factor $SCALE_FACTOR (~${DPI} DPI) for Wine." >&2
fi

# Initial setup
if [ ! -d "$PREFIX" ]; then
  mkdir -p "$PREFIX"
  "$WINEBOOT" -u
  
  # Base settings
  apply_dpi_settings "$DPI" "$SCALE_FACTOR"
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "Default" /t REG_SZ /d "0412" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "InstallLanguage" /t REG_SZ /d "0412" /f
  
  # X11 specific settings
  if [ "$BACKEND" = x11 ]; then
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseTakeFocus" /t REG_SZ /d "N" /f
    
    # Clipboard
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseXIM" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UsePrimarySelection" /t REG_SZ /d "N" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "GrabClipboard" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseSystemClipboard" /t REG_SZ /d "Y" /f
  fi

  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "ForegroundLockTimeout" /t REG_DWORD /d 200000 /f

  # Explorer and behaviors
  "$WINE" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /f 2>/dev/null || true
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Audio" /t REG_SZ /d "" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DragAcceptFiles" /v "Accept" /t REG_DWORD /d 1 /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\OleDropTarget" /v "Enable" /t REG_DWORD /d 1 /f
  
  set_wine_graphics_driver "$BACKEND"
fi

# Winetricks
if [ ! -f "$PREFIX/.winetricks_done" ]; then
  "$WINETRICKS" corefonts -q
  touch "$PREFIX/.winetricks_done"
fi

# Font configuration
if [ ! -f "$PREFIX/.fonts_configured" ]; then
  echo "Configuring font replacements..."
  
  # Western fonts to Pretendard
  for font in @westernFonts@; do
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "$font" /t REG_SZ /d "Pretendard" /f
  done
  
  # Korean fonts to Pretendard
  for font in @koreanFonts@; do
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "$font" /t REG_SZ /d "Pretendard" /f
  done
  
  # Emoji mapping
  # Note: Wine requires proper key names. "Noto Color Emoji" must match the internal font name.
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Emoji" /t REG_SZ /d "Noto Color Emoji" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Symbol" /t REG_SZ /d "Noto Color Emoji" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Apple Color Emoji" /t REG_SZ /d "Noto Color Emoji" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Color Emoji" /t REG_SZ /d "Noto Color Emoji" /f

  # Font linking
  # Critical for fallback. Noto Color Emoji often fails if not explicitly linked.
  # We link both Noto Color Emoji and CJK fonts to Pretendard/system fallback.
  # Note: For TTC files, we point to the file. Wine usually auto-detects the face or uses the first one (Sans CJK usually includes KR in the first few/merged).
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Pretendard" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Noto Sans CJK KR,NotoSansCJK-VF.otf.ttc\0Noto Serif CJK KR,NotoSerifCJK-VF.otf.ttc" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Tahoma" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Pretendard,Pretendard-Regular.otf" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Segoe UI" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Pretendard,Pretendard-Regular.otf" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Malgun Gothic" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Pretendard,Pretendard-Regular.otf" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Microsoft Sans Serif" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Pretendard,Pretendard-Regular.otf" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Gulim" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf\0Pretendard,Pretendard-Regular.otf" /f
  
  # Font smoothing
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingType" /t REG_DWORD /d 2 /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingGamma" /t REG_DWORD /d 1400 /f
  
  # Link system fonts
  mkdir -p "$PREFIX/drive_c/windows/Fonts"
  
  # Link provided fonts
  # Using find with -exec ln is safer but loop is fine here.
  # Ensure we follow symlinks if fontPath is a symlink forest (it is).
  find -H @fontPath@ -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) | while read -r font; do
    name=$(basename "$font")
    ln -sf "$font" "$PREFIX/drive_c/windows/Fonts/$name" 2>/dev/null || true
  done
  
  touch "$PREFIX/.fonts_configured"
fi

# Install if needed
if [ ! -f "$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
  echo "Installing KakaoTalk..."
  "$WINE" "$INSTALLER"
fi

# Cleanup shortcuts
rm -f "$HOME/.local/share/applications/wine/Programs/카카오톡.desktop" 2>/dev/null
rm -f "$HOME/.local/share/applications/wine/Programs/KakaoTalk.desktop" 2>/dev/null

# Ensure driver preference
set_wine_graphics_driver "$BACKEND"

# Keep DPI in sync with the host scale even on existing prefixes
apply_dpi_settings "$DPI" "$SCALE_FACTOR"

# Launch
"$WINE" "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
