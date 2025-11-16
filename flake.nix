{
  description = "A Nix flake for KakaoTalk";
  inputs = {
    kakaotalk-exe = {
      url = "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe";
      flake = false;
    };
    kakaotalk-icon = {
      url =
        "https://upload.wikimedia.org/wikipedia/commons/e/e3/KakaoTalk_logo.svg";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, kakaotalk-exe, kakaotalk-icon }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system} = with pkgs; {
        default = self.packages.${system}.kakaotalk;
        kakaotalk = let
          desktopItem = makeDesktopItem {
            name = "kakaotalk";
            exec = "kakaotalk %U";
            icon = "kakaotalk";
            desktopName = "KakaoTalk";
            genericName = "Instant Messenger";
            comment = "A messaging and video calling app";
            categories = [ "Network" "InstantMessaging" ];
            mimeTypes = [ "x-scheme-handler/kakaotalk" ];
            startupWMClass = "kakaotalk.exe";
          };
        in stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.0";
          src = kakaotalk-exe;
          dontUnpack = true;

          nativeBuildInputs = [ makeWrapper wineWowPackages.stable winetricks ];

          buildInputs = [
            pretendard
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];

          installPhase = ''
            mkdir -p $out/bin $out/share/icons/hicolor/scalable/apps $out/share/applications $out/share/kakaotalk
            cp ${kakaotalk-icon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            cat > $out/bin/kakaotalk <<EOF
            #!/usr/bin/env bash

            export GTK_IM_MODULE=fcitx
            export QT_IM_MODULE=fcitx
            export XMODIFIERS=@im=fcitx
            export GTK_USE_PORTAL=
            : "
              Respect host portals for dialogs where possible. While Wine apps
              do not directly use portals, this helps when helpers are spawned.
            "

            # Performance toggles (can be overridden by environment)
            [ -z "\$WINEESYNC" ] && export WINEESYNC=1
            [ -z "\$WINEFSYNC" ] && export WINEFSYNC=1
            [ -z "\$WINEDEBUG" ] && export WINEDEBUG=-all

            # Choose data dir without brace parameter expansion to avoid Nix interpolation
            PREFIX="\$XDG_DATA_HOME"
            if [ -z "\$PREFIX" ]; then
              PREFIX="\$HOME/.local/share"
            fi
            PREFIX="\$PREFIX/kakaotalk"

            INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"

            WINE_BIN="${wineWowPackages.stable}/bin/wine"
            WINEBOOT_BIN="${wineWowPackages.stable}/bin/wineboot"

            # Decide backend: wayland when forced or available, else x11
            BACKEND="\$KAKAOTALK_FORCE_BACKEND"
            if [ -z "\$BACKEND" ]; then
              if [ -n "\$WAYLAND_DISPLAY" ]; then
                BACKEND=wayland
              else
                BACKEND=x11
              fi
            fi

            # Helper to set Wine graphics driver
            set_wine_graphics_driver() {
              local driver="\$1"
              # Detect if wayland driver exists in this Wine build
              local wb="\$WINE_BIN"
              local wine_root
              wine_root="\$(cd "\$(dirname "\$wb")/.." 2>/dev/null && pwd)"
              local have_wayland=1
              if [ -n "\$wine_root" ]; then
                have_wayland=0
                for d in "\$wine_root/lib/wine" "\$wine_root/lib64/wine"; do
                  if [ -e "\$d/winewayland.drv.so" ] || ls "\$d"/winewayland.drv* >/dev/null 2>&1; then
                    have_wayland=1
                    break
                  fi
                done
              fi
              case "\$driver" in
                wayland)
                  if [ "\$have_wayland" -eq 1 ]; then
                    WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add \
                      "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" \
                      /v "Graphics" /t REG_SZ /d "wayland" /f >/dev/null 2>&1 || true
                  else
                    WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add \
                      "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" \
                      /v "Graphics" /t REG_SZ /d "x11" /f >/dev/null 2>&1 || true
                  fi
                  ;;
                x11|*)
                  WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add \
                    "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" \
                    /v "Graphics" /t REG_SZ /d "x11" /f >/dev/null 2>&1 || true
                  ;;
              esac
            }
            if [ ! -d "\$PREFIX" ]; then
              mkdir -p "\$PREFIX"
              WINEPREFIX="\$PREFIX" "\$WINEBOOT_BIN" -u
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "LogPixels" /t REG_DWORD /d 96 /f
              # X11-specific DPI is set only when using X11 backend
              if [ "\$BACKEND" = x11 ]; then
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "DPI" /t REG_SZ /d "96" /f
              fi
              WINEPREFIX="\$PREFIX" "\$WINEBOOT_BIN" -u
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "Default" /t REG_SZ /d "0412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "InstallLanguage" /t REG_SZ /d "0412" /f
              if [ "\$BACKEND" = x11 ]; then
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed"   /t REG_SZ /d "Y" /f
                # Reduce focus stealing on X11/XWayland
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseTakeFocus" /t REG_SZ /d "N" /f
              fi
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /f 2>/dev/null || true
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Audio" /t REG_SZ /d "" /f
              # Enable clipboard integration
              if [ "\$BACKEND" = x11 ]; then
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseXIM" /t REG_SZ /d "Y" /f
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UsePrimarySelection" /t REG_SZ /d "N" /f
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "GrabClipboard" /t REG_SZ /d "Y" /f
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseSystemClipboard" /t REG_SZ /d "Y" /f
              fi
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DragAcceptFiles" /v "Accept" /t REG_DWORD /d 1 /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\OleDropTarget" /v "Enable" /t REG_DWORD /d 1 /f
              set_wine_graphics_driver "\$BACKEND"
            fi
            if [ ! -f "\$PREFIX/.winetricks_done" ]; then
              WINEPREFIX="\$PREFIX" ${winetricks}/bin/winetricks corefonts -q
              touch "\$PREFIX/.winetricks_done"
            fi
            # Configure font substitutions for emoji support
            if [ ! -f "\$PREFIX/.fonts_configured" ]; then
              echo "Configuring font replacements..."
              
              # Replace only specific Western fonts with Pretendard
              # This preserves Korean fonts while updating UI fonts
              for font in "Arial" "Times New Roman" "Courier New" "Verdana" "Tahoma" \
                         "Georgia" "Trebuchet MS" "Comic Sans MS" "Impact" \
                         "Lucida Console" "Lucida Sans Unicode" "Palatino Linotype" \
                         "Segoe UI" "Segoe Print" "Segoe Script" \
                         "Calibri" "Cambria" "Candara" "Consolas" "Constantia" "Corbel"; do
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "\$font" /t REG_SZ /d "Pretendard" /f
              done
              
              # Ensure Korean fonts use Pretendard which has excellent Korean support
              for font in "Gulim" "Dotum" "Batang" "Gungsuh" "Malgun Gothic"; do
                WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "\$font" /t REG_SZ /d "Pretendard" /f
              done
              
              # Map emoji/symbol fonts to Noto Color Emoji
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Emoji" /t REG_SZ /d "Noto Color Emoji" /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Segoe UI Symbol" /t REG_SZ /d "Noto Color Emoji" /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements" /v "Apple Color Emoji" /t REG_SZ /d "Noto Color Emoji" /f
              
              # Set up font linking for emoji support - Pretendard cascades to Noto Color Emoji
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink" /v "Pretendard" /t REG_MULTI_SZ /d "Noto Color Emoji,NotoColorEmoji.ttf" /f
              
              # Enable font smoothing
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingType" /t REG_DWORD /d 2 /f
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingGamma" /t REG_DWORD /d 1400 /f
              
              # Link system fonts to Wine prefix
              mkdir -p "\$PREFIX/drive_c/windows/Fonts"
              # Link Pretendard fonts first
              for font in ${pretendard}/share/fonts/opentype/*.otf ${pretendard}/share/fonts/truetype/*.ttf; do
                if [ -f "\$font" ]; then
                  ln -sf "\$font" "\$PREFIX/drive_c/windows/Fonts/" 2>/dev/null || true
                fi
              done
              # Then link Noto fonts for emoji support
              for font in ${noto-fonts}/share/fonts/truetype/*.ttf ${noto-fonts-cjk-sans}/share/fonts/opentype/*/*.otf ${noto-fonts-color-emoji}/share/fonts/truetype/*.ttf; do
                if [ -f "\$font" ]; then
                  ln -sf "\$font" "\$PREFIX/drive_c/windows/Fonts/" 2>/dev/null || true
                fi
              done
              
              touch "\$PREFIX/.fonts_configured"
            fi
            if [ ! -f "\$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
              echo "Installing KakaoTalk..."
              WINEPREFIX="\$PREFIX" "\$WINE_BIN" "\$INSTALLER"
            fi

            # Remove the installer-created desktop entries to avoid duplicates
            rm -f "\$HOME/.local/share/applications/wine/Programs/카카오톡.desktop" 2>/dev/null
            rm -f "\$HOME/.local/share/applications/wine/Programs/KakaoTalk.desktop" 2>/dev/null
            # Ensure graphics driver preference is set at every launch
            set_wine_graphics_driver "\$BACKEND"

            # Launch
            WINEPREFIX="\$PREFIX" "\$WINE_BIN" \
              "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "\$@"
            EOF
            chmod +x $out/bin/kakaotalk

            # Copy the desktop entry from makeDesktopItem
            cp -r ${desktopItem}/share/applications $out/share/
          '';
          meta = with lib; {
            description = "A messaging and video calling app.";
            homepage =
              "https://www.kakaocorp.com/page/service/service/KakaoTalk";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
          };
        };
      };
      apps.${system}.kakaotalk = {
        type = "app";
        program = "${self.packages.${system}.kakaotalk}/bin/kakaotalk";
      };
      apps.${system}.default = self.apps.${system}.kakaotalk;
    };
}
