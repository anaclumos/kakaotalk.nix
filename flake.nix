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
            bottles
            noto-fonts-cjk-sans
          ];
          
          installPhase = ''
            mkdir -p $out/bin $out/share/icons/hicolor/scalable/apps $out/share/kakaotalk
            cp ${kakaotalk-icon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            # Create launcher script
            cat > $out/bin/kakaotalk << 'EOF'
            #!/bin/sh
            BOTTLE="kakaotalk"
            INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"

            if ! bottles-cli list | grep -q "$BOTTLE"; then
              echo "Creating bottle for KakaoTalk..."
              bottles-cli create -b "$BOTTLE"
              bottles-cli run -b "$BOTTLE" "$INSTALLER"
            fi

            bottles-cli run -b "$BOTTLE" "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
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
