{
  description = "A Nix flake for KakaoTalk";

  inputs = {
    erosanix.url = "github:emmanuelrosa/erosanix";

    pretendard-regular = {
      url = "https://raw.githubusercontent.com/orioncactus/pretendard/main/packages/pretendard/dist/public/static/alternative/Pretendard-Regular.ttf";
      flake = false;
    };
    pretendard-bold = {
      url = "https://raw.githubusercontent.com/orioncactus/pretendard/main/packages/pretendard/dist/public/static/alternative/Pretendard-Bold.ttf";
      flake = false;
    };
    kakaotalk-exe = {
      url = "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe";
      flake = false;
    };
    kakaotalk-icon = {
      url = "https://upload.wikimedia.org/wikipedia/commons/e/e3/KakaoTalk_logo.svg";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, erosanix, pretendard-regular, pretendard-bold, kakaotalk-exe, kakaotalk-icon }: {
    packages.x86_64-linux =
      let
        pkgs = import "${nixpkgs}" {
          system = "x86_64-linux";
        };

        pretendardPkg = pkgs.stdenvNoCC.mkDerivation {
          pname = "pretendard";
          version = "1.3.9";
          srcs = [ pretendard-regular pretendard-bold ];
          dontUnpack = true;
          installPhase = ''
            install -Dm644 ${pretendard-regular} $out/share/fonts/truetype/Pretendard-Regular.ttf
            install -Dm644 ${pretendard-bold}   $out/share/fonts/truetype/Pretendard-Bold.ttf
          '';
        };
      in
      with (pkgs // erosanix.packages.x86_64-linux // erosanix.lib.x86_64-linux); {
        default = self.packages.x86_64-linux.kakaotalk;
        kakaotalk = mkWindowsApp rec {
          wine = wineWowPackages.full;
          pname = "kakaotalk";
          version = "3.7.0";
          src = kakaotalk-exe;
          dontUnpack = true;
          wineArch = "win64";
          enableInstallNotification = true;
          fileMapDuringAppInstall = false;
          persistRegistry = false;
          persistRuntimeLayer = false;
          inputHashMethod = "store-path";
          nativeBuildInputs = [ pretendardPkg ];
          winAppInstall = ''
            # copy the fonts so Wine enumerates them
            install -m644 "${pretendardPkg}/share/fonts/truetype/Pretendard-Regular.ttf" \
                 "$WINEPREFIX/drive_c/windows/Fonts/Pretendard-Regular.ttf"
            install -m644 "${pretendardPkg}/share/fonts/truetype/Pretendard-Bold.ttf" \
                 "$WINEPREFIX/drive_c/windows/Fonts/Pretendard-Bold.ttf"

            # map Windows' default Korean UI font to Pretendard
            reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" \
                /v "Malgun Gothic" /t REG_SZ /d "Pretendard" /f
            reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" \
                /v "맑은 고딕"    /t REG_SZ /d "Pretendard" /f

            # KakaoTalk's own override
            mkdir -p "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Kakao/KakaoTalk"
            echo "CustomFontFaceName=Pretendard" >> \
                "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Kakao/KakaoTalk/pref.ini"

            wine ${src} /S
          '';
          winAppRun = ''
            wine "$WINEPREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" "$ARGS"
          '';
          enabledWineSymlinks = {
            desktop = false;
          };
          desktopItems = [
            (makeDesktopItem {
              name = "KakaoTalk";
              exec = "kakaotalk";
              icon = "kakaotalk";
              desktopName = "KakaoTalk";
              genericName = "Messenger";
              categories = [ "Network" "InstantMessaging" ];
            })
          ];
          desktopIcon = makeDesktopIcon {
            name = "kakaotalk";
            src = kakaotalk-icon;
          };
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
      program = "${self.packages.x86_64-linux.kakaotalk}/bin/.launcher";
    };
    apps.x86_64-linux.default = self.apps.x86_64-linux.kakaotalk;
  };
}