{
  description = "A Nix flake for KakaoTalk";

  inputs = {
    kakaotalk-exe = {
      url = "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe";
      flake = false;
    };
    kakaotalk-icon = {
      url = "https://upload.wikimedia.org/wikipedia/commons/e/e3/KakaoTalk_logo.svg";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, kakaotalk-exe, kakaotalk-icon }: {
    packages.x86_64-linux =
      let
        pkgs = import "${nixpkgs}" {
          system = "x86_64-linux";
        };

      in
      with pkgs; {
        default = self.packages.x86_64-linux.kakaotalk;
        kakaotalk = stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.0";
          src = kakaotalk-exe;
          dontUnpack = true;
          
          nativeBuildInputs = [
            makeWrapper
            wineWowPackages.stable
            winetricks
            noto-fonts-cjk-sans
          ];
          
          installPhase = ''
            mkdir -p $out/bin $out/share/icons/hicolor/scalable/apps $out/share/kakaotalk
            cp ${kakaotalk-icon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            # Create launcher script
            cat > $out/bin/kakaotalk <<EOF
            #!/usr/bin/env bash
            PREFIX="\''${XDG_DATA_HOME:-\$HOME/.local/share}/kakaotalk"
            INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"
            FONT_SOURCE=${noto-fonts-cjk-sans}/share/fonts
            WINE_PATH=${wineWowPackages.stable}/bin

            if [ ! -d "\$PREFIX" ]; then
              mkdir -p "\$PREFIX"
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wineboot" -u
              
              # Configure DPI scaling for high resolution displays
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "LogPixels" /t REG_DWORD /d 192 /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "DPI" /t REG_SZ /d "192" /f
              # Restart to apply DPI changes
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wineboot" -u
              
              # Configure Wine locale for Korean support
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "Default" /t REG_SZ /d "0412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "InstallLanguage" /t REG_SZ /d "0412" /f
            fi

            FONT_DIR="\$PREFIX/drive_c/windows/Fonts"
            if [ ! -f "\$FONT_DIR/NotoSansCJK-Regular.otf" ]; then
              mkdir -p "\$FONT_DIR"
              cp "\$FONT_SOURCE"/* "\$FONT_DIR" 2>/dev/null || true
              
              # Register Korean fonts in Wine registry
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Malgun Gothic" /t REG_SZ /d "Noto Sans CJK KR" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "맑은 고딕" /t REG_SZ /d "Noto Sans CJK KR" /f  
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Gulim" /t REG_SZ /d "Noto Sans CJK KR" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "굴림" /t REG_SZ /d "Noto Sans CJK KR" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Dotum" /t REG_SZ /d "Noto Sans CJK KR" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "돋움" /t REG_SZ /d "Noto Sans CJK KR" /f
              # Restart to pick up new fonts
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wineboot" -u
            fi

            # Install core Windows fonts for Korean support
            if [ ! -f "\$PREFIX/.winetricks_done" ]; then
              WINEPREFIX="\$PREFIX" ${winetricks}/bin/winetricks corefonts -q
              touch "\$PREFIX/.winetricks_done"
            fi

            if [ ! -f "\$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
              echo "Installing KakaoTalk..."
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" "\$INSTALLER"
            fi

            GDK_SCALE="${GDK_SCALE:-2}" GDK_DPI_SCALE="${GDK_DPI_SCALE:-2}" \
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" \
              "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "\$@"
            EOF

            chmod +x $out/bin/kakaotalk
          '';
          meta = with lib; {
            description = "A messaging and video calling app.";
            homepage = "https://www.kakaocorp.com/page/service/service/KakaoTalk";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
          };
        };
      };
    apps.x86_64-linux.kakaotalk = {
      type = "app";
      program = "${self.packages.x86_64-linux.kakaotalk}/bin/kakaotalk";
    };
    apps.x86_64-linux.default = self.apps.x86_64-linux.kakaotalk;
  };
}
