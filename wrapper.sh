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
BACKEND="$KAKAOTALK_FORCE_BACKEND"
if [ -z "$BACKEND" ]; then
  if [ -n "$WAYLAND_DISPLAY" ]; then
    BACKEND=wayland
  else
    BACKEND=x11
  fi
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

# Initial setup
if [ ! -d "$PREFIX" ]; then
  mkdir -p "$PREFIX"
  "$WINEBOOT" -u
  
  # Base settings
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "LogPixels" /t REG_DWORD /d 96 /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "Default" /t REG_SZ /d "0412" /f
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "InstallLanguage" /t REG_SZ /d "0412" /f
  
  # X11 specific settings
  if [ "$BACKEND" = x11 ]; then
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "DPI" /t REG_SZ /d "96" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseTakeFocus" /t REG_SZ /d "N" /f
    
    # Clipboard
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseXIM" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UsePrimarySelection" /t REG_SZ /d "N" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "GrabClipboard" /t REG_SZ /d "Y" /f
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseSystemClipboard" /t REG_SZ /d "Y" /f
  fi

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
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Emoji" /t REG_SZ /d "Noto Color Emoji" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Symbol" /t REG_SZ /d "Noto Color Emoji" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Apple Color Emoji" /t REG_SZ /d "Noto Color Emoji" /f
  
  # Font linking
  "$WINE" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Pretendard" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf" /f
  
  # Font smoothing
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingType" /t REG_DWORD /d 2 /f
  "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingGamma" /t REG_DWORD /d 1400 /f
  
  # Link system fonts
  mkdir -p "$PREFIX/drive_c/windows/Fonts"
  
  # Link provided fonts
  find @fontPath@ -name "*.ttf" -o -name "*.otf" | while read -r font; do
    ln -sf "$font" "$PREFIX/drive_c/windows/Fonts/" 2>/dev/null || true
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

# Launch
"$WINE" "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
