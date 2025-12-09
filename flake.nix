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

      westernFonts = [
        "Arial" "Times New Roman" "Courier New" "Verdana" "Tahoma"
        "Georgia" "Trebuchet MS" "Comic Sans MS" "Impact"
        "Lucida Console" "Lucida Sans Unicode" "Palatino Linotype"
        "Segoe UI" "Segoe Print" "Segoe Script"
        "Calibri" "Cambria" "Candara" "Consolas" "Constantia" "Corbel"
      ];
      
      koreanFonts = [
        "Gulim" "Dotum" "Batang" "Gungsuh" "Malgun Gothic"
      ];

      # Helper to quote list elements for shell usage
      quoteList = list: pkgs.lib.concatMapStringsSep " " (x: "\"" + x + "\"") list;

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
          
          # Combine all fonts we want to link
          fontPackages = [
            pretendard
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];
          
          # Create a symlink join of all fonts to make them easily accessible in one path
          fontPath = symlinkJoin {
            name = "kakaotalk-fonts";
            paths = fontPackages;
          };

        in stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.0";
          src = kakaotalk-exe;
          dontUnpack = true;

          nativeBuildInputs = [ makeWrapper wineWowPackages.stable winetricks copyDesktopItems ];

          # Pass variables to substituteAll
          # We manually invoke substituteAll in installPhase for flexibility or use stdenv's hook if we made it a separate derivation, 
          # but here we can just substitute the script directly.
          
          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin $out/share/icons/hicolor/scalable/apps $out/share/kakaotalk
            
            # Install resources
            cp ${kakaotalk-icon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            cp ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            
            # Process and install wrapper
            cp ${./wrapper.sh} $out/bin/kakaotalk
            chmod +x $out/bin/kakaotalk
            
            # Substitute variables in the wrapper
            substituteInPlace $out/bin/kakaotalk \
              --replace-fail "@bash@" "${bash}" \
              --replace-fail "@wineBin@" "${wineWowPackages.stable}/bin" \
              --replace-fail "@wineLib@" "${wineWowPackages.stable}/lib" \
              --replace-fail "@winetricks@" "${winetricks}" \
              --replace-fail "@out@" "$out" \
              --replace-fail "@westernFonts@" '${quoteList westernFonts}' \
              --replace-fail "@koreanFonts@" '${quoteList koreanFonts}' \
              --replace-fail "@fontPath@" "${fontPath}/share/fonts"

            # Install desktop item
            cp -r ${desktopItem}/share/applications $out/share/

            runHook postInstall
          '';

          meta = with lib; {
            description = "A messaging and video calling app.";
            homepage = "https://www.kakaocorp.com/page/service/service/KakaoTalk";
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
