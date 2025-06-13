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
            PREFIX="\${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
            INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"
            FONT_SOURCE=${noto-fonts-cjk-sans}/share/fonts

            if [ ! -d "$PREFIX" ]; then
              mkdir -p "$PREFIX"
              WINEPREFIX="$PREFIX" wineboot -u
            fi

            FONT_DIR="$PREFIX/drive_c/windows/Fonts"
            if [ ! -f "$FONT_DIR/NotoSansCJK-Regular.otf" ]; then
              mkdir -p "$FONT_DIR"
              cp "$FONT_SOURCE"/* "$FONT_DIR" 2>/dev/null || true
            fi

            if [ ! -f "$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
              echo "Installing KakaoTalk..."
              WINEPREFIX="$PREFIX" wine "$INSTALLER"
            fi

            WINEPREFIX="$PREFIX" wine "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
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
