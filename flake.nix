{
  description = "KakaoTalk for NixOS via Wine";

  outputs =
    { self, nixpkgs }:
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

      koreanFonts = [
        "Gulim"
        "Dotum"
        "Batang"
        "Gungsuh"
        "Malgun Gothic"
      ];
      quoteList = l: concatMapStringsSep " " (f: ''"${f}"'') l;

      mkPackage =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          sources = pkgs.callPackage ./_sources/generated.nix { };
          fontPath = pkgs.symlinkJoin {
            name = "kakaotalk-fonts";
            paths = with pkgs; [
              noto-fonts-color-emoji
              pretendard
            ];
          };
          desktopItem = pkgs.makeDesktopItem {
            name = "kakaotalk";
            exec = "kakaotalk %U";
            icon = "kakaotalk";
            desktopName = "KakaoTalk";
            genericName = "Instant Messenger";
            comment = "Messaging and video calling";
            categories = [
              "Network"
              "InstantMessaging"
            ];
            mimeTypes = [ "x-scheme-handler/kakaotalk" ];
            startupWMClass = "kakaotalk.exe";
          };
        in
        pkgs.stdenv.mkDerivation {
          pname = "kakaotalk";
          version = "0.2.0";
          src = sources.kakaotalk-exe.src;
          dontUnpack = true;
          nativeBuildInputs = [
            pkgs.wineWowPackages.stable
            pkgs.winetricks
          ];
          propagatedBuildInputs = [
            pkgs.xdotool
            pkgs.wmctrl
          ];
          installPhase = ''
            runHook preInstall
            install -Dm644 ${sources.kakaotalk-icon.src} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
            install -Dm644 $src $out/share/kakaotalk/KakaoTalk_Setup.exe
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
            install -Dm644 ${desktopItem}/share/applications/kakaotalk.desktop $out/share/applications/kakaotalk.desktop
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "KakaoTalk messenger";
            homepage = "https://www.kakaocorp.com/page/service/service/KakaoTalk";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
          };
        };
    in
    {
      packages = genAttrs systems (s: {
        kakaotalk = mkPackage s;
        default = mkPackage s;
      });
      apps = genAttrs systems (
        s:
        let
          p = mkPackage s;
        in
        {
          kakaotalk = {
            type = "app";
            program = "${p}/bin/kakaotalk";
          };
          default = {
            type = "app";
            program = "${p}/bin/kakaotalk";
          };
        }
      );
    };
}
