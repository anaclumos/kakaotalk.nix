{
  description = "A Nix flake for KakaoTalk (Wine launcher)";
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
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system} = with pkgs; {
        # expose `nix build` (no attr) to mean “build KakaoTalk”
        default = self.packages.${system}.kakaotalk;

        kakaotalk = stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.1"; # ↑ bump because wrapper changed
          src = kakaotalk-exe; # the official installer
          dontUnpack = true;

          nativeBuildInputs = [ makeWrapper wineWowPackages.stable winetricks ];

          installPhase = ''
            mkdir -p $out/bin \
                     $out/share/icons/hicolor/scalable/apps \
                     $out/share/applications \
                     $out/share/kakaotalk

            cp ${kakaotalk-icon} \
               $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe

            # Desktop entry ----------------------------------------------------
            cat > $out/share/applications/KakaoTalk.desktop <<EOF
            [Desktop Entry]
            Name=KakaoTalk
            Comment=A messaging and video‑calling app
            Exec=$out/bin/kakaotalk
            Icon=kakaotalk
            Terminal=false
            Type=Application
            Categories=Network;InstantMessaging;
            StartupWMClass=kakaotalk.exe
            EOF

            # Wrapper ----------------------------------------------------------
            cat > $out/bin/kakaotalk <<'EOF'
            #!/usr/bin/env bash
            set -euo pipefail
            export WINEDLLOVERRIDES="explorer.exe=d"
            export WINEDEBUG="-all"

              PREFIX="\''${XDG_DATA_HOME:-\$HOME/.local/share}/kakaotalk"
            INSTALLER="@out@/share/kakaotalk/KakaoTalk_Setup.exe"
            WINE="@winePath@/wine"
            WINEBOOT="@winePath@/wineboot"

            if [[ ! -d "$PREFIX" ]]; then
              mkdir -p "$PREFIX"
              WINEPREFIX="$PREFIX" $WINEBOOT -u

              # DPI / locale / focus / sound tweaks
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d 96 /f
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKCU\\Software\\Wine\\X11 Driver" /v DPI /t REG_SZ /d 96 /f
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKCU\\Software\\Wine\\X11 Driver" /v Managed /t REG_SZ /d N /f
              WINEPREFIX="$PREFIX" $WINE reg delete \
                "HKCU\\Software\\Wine\\Explorer" /v Desktop /f 2>/dev/null || true
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKCU\\Software\\Wine\\Drivers" /v Audio /t REG_SZ /d "" /f
              # Korean locale (same as original script)
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKCU\\Control Panel\\International" /v Locale /t REG_SZ /d 00000412 /f
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKLM\\System\\CurrentControlSet\\Control\\Nls\\Language" \
                /v Default /t REG_SZ /d 0412 /f
              WINEPREFIX="$PREFIX" $WINE reg add \
                "HKLM\\System\\CurrentControlSet\\Control\\Nls\\Language" \
                /v InstallLanguage /t REG_SZ /d 0412 /f
            fi

            # Corefonts once per prefix
            if [[ ! -f "$PREFIX/.winetricks_done" ]]; then
              WINEPREFIX="$PREFIX" @winetricks@/bin/winetricks -q corefonts
              touch "$PREFIX/.winetricks_done"
            fi

            # Install KakaoTalk only once
            if [[ ! -f "$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]]; then
              echo ">>> Installing KakaoTalk …"
              WINEPREFIX="$PREFIX" $WINE "$INSTALLER"
            fi

            # Run
            exec WINEPREFIX="$PREFIX" $WINE \
              "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
            EOF

            # patch @... placeholders
            substituteInPlace $out/bin/kakaotalk \
              --subst-var-by out $out \
              --subst-var-by winePath ${wineWowPackages.stable}/bin \
              --subst-var-by winetricks ${winetricks}

            chmod +x $out/bin/kakaotalk
          '';

          meta = with lib; {
            description = "KakaoTalk (via Wine) without the Wine tray window";
            homepage =
              "https://www.kakaocorp.com/page/service/service/KakaoTalk";
            license = licenses.unfree;
            platforms = [ system ];
          };
        };
      };

      # `nix run` convenience
      apps.${system}.kakaotalk = {
        type = "app";
        program = "${self.packages.${system}.kakaotalk}/bin/kakaotalk";
      };
      apps.${system}.default = self.apps.${system}.kakaotalk;
    };
}
