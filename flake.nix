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
      inherit (nixpkgs.lib) concatMapStringsSep genAttrs;

      systems = [ "x86_64-linux" ];

      westernFonts = [
        "Arial"
        "Times New Roman"
        "Courier New"
        "Verdana"
        "Tahoma"
        "Georgia"
        "Trebuchet MS"
        "Comic Sans MS"
        "Impact"
        "Lucida Console"
        "Lucida Sans Unicode"
        "Palatino Linotype"
        "Segoe UI"
        "Segoe Print"
        "Segoe Script"
        "Calibri"
        "Cambria"
        "Candara"
        "Consolas"
        "Constantia"
        "Corbel"
      ];

      koreanFonts = [ "Gulim" "Dotum" "Batang" "Gungsuh" "Malgun Gothic" ];

      quoteList = list:
        concatMapStringsSep " " (font: ''"'' + font + ''"'') list;

      mkPackage = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          fontPackages = with pkgs; [ noto-fonts-emoji baekmuk-ttf ];
          fontPath = pkgs.symlinkJoin {
            name = "kakaotalk-fonts";
            paths = fontPackages;
          };

          desktopItem = pkgs.makeDesktopItem {
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
        in pkgs.stdenv.mkDerivation rec {
          pname = "kakaotalk";
          version = "0.1.0";
          src = kakaotalk-exe;
          dontUnpack = true;

          nativeBuildInputs = [ pkgs.wineWowPackages.stable pkgs.winetricks ];

          installPhase = ''
            runHook preInstall

            install -Dm644 ${kakaotalk-icon} \
              $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            install -Dm644 ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
            install -Dm755 ${./wrapper.sh} $out/bin/kakaotalk

            substituteInPlace $out/bin/kakaotalk \
              --replace-fail "@bash@" "${pkgs.bash}" \
              --replace-fail "@wineBin@" "${pkgs.wineWowPackages.stable}/bin" \
              --replace-fail "@wineLib@" "${pkgs.wineWowPackages.stable}/lib" \
              --replace-fail "@winetricks@" "${pkgs.winetricks}" \
              --replace-fail "@out@" "$out" \
              --replace-fail "@westernFonts@" '${quoteList westernFonts}' \
              --replace-fail "@koreanFonts@" '${quoteList koreanFonts}' \
              --replace-fail "@fontPath@" "${fontPath}/share/fonts"

            install -Dm644 ${desktopItem}/share/applications/kakaotalk.desktop \
              $out/share/applications/kakaotalk.desktop

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "A messaging and video calling app.";
            homepage =
              "https://www.kakaocorp.com/page/service/service/KakaoTalk";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
          };
        };
    in {
      packages = genAttrs systems (system: rec {
        kakaotalk = mkPackage system;
        default = kakaotalk;
      });

      apps = genAttrs systems (system:
        let pkg = self.packages.${system}.kakaotalk; in rec {
          kakaotalk = {
            type = "app";
            program = "${pkg}/bin/kakaotalk";
          };
          default = kakaotalk;
        });
    };
}
