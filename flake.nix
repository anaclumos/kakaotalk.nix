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
  outputs = { self, nixpkgs, kakaotalk-exe, kakaotalk-icon }: {
    packages.x86_64-linux =
      let pkgs = import "${nixpkgs}" { system = "x86_64-linux"; };
      in with pkgs; {
        default = self.packages.x86_64-linux.kakaotalk;
        kakaotalk = let
          desktopItem = makeDesktopItem {
            name = "KakaoTalk";
            exec = "kakaotalk";
            icon = "kakaotalk";
            comment = "A messaging and video calling app";
            desktopName = "KakaoTalk";
            terminal = false;
            type = "Application";
            categories = [ "Network" "InstantMessaging" ];
            startupWMClass = "kakaotalk.exe";
          };
        in stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.0";
          src = kakaotalk-exe;
          dontUnpack = true;

          nativeBuildInputs = [ makeWrapper wineWowPackages.stable winetricks ];

          installPhase = ''
            mkdir -p $out/bin $out/share/icons/hicolor/scalable/apps $out/share/kakaotalk
            cp ${kakaotalk-icon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            cp -r ${desktopItem}/share/applications $out/share/
            cat > $out/bin/kakaotalk <<EOF
            #!/usr/bin/env bash
            PREFIX="\''${XDG_DATA_HOME:-\$HOME/.local/share}/kakaotalk"
            INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"
            WINE_PATH=${wineWowPackages.stable}/bin
            if [ ! -d "\$PREFIX" ]; then
              mkdir -p "\$PREFIX"
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wineboot" -u
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "LogPixels" /t REG_DWORD /d 96 /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "DPI" /t REG_SZ /d "96" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wineboot" -u
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "Default" /t REG_SZ /d "0412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Nls\\Language" /v "InstallLanguage" /t REG_SZ /d "0412" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed" /f 2>/dev/null || true
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /f 2>/dev/null || true
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseTakeFocus" /t REG_SZ /d "N" /f
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" /v "Audio" /t REG_SZ /d "" /f
            fi
            if [ ! -f "\$PREFIX/.winetricks_done" ]; then
              WINEPREFIX="\$PREFIX" ${winetricks}/bin/winetricks corefonts -q
              touch "\$PREFIX/.winetricks_done"
            fi
            if [ ! -f "\$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
              echo "Installing KakaoTalk..."
              WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" "\$INSTALLER"
            fi
            export WINEDLLOVERRIDES="explorer.exe=d"
            WINEPREFIX="\$PREFIX" "\$WINE_PATH/wine" \
              "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "\$@"
            EOF
            chmod +x $out/bin/kakaotalk
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
    apps.x86_64-linux.kakaotalk = {
      type = "app";
      program = "${self.packages.x86_64-linux.kakaotalk}/bin/kakaotalk";
    };
    apps.x86_64-linux.default = self.apps.x86_64-linux.kakaotalk;
  };
}
