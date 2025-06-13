{
  description = "A Nix flake for KakaoTalk";

  inputs = {
    erosanix.url = "github:emmanuelrosa/erosanix";
    kakaotalk-exe = {
      url = "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe";
      flake = false;
    };
    kakaotalk-icon = {
      url = "https://upload.wikimedia.org/wikipedia/commons/e/e3/KakaoTalk_logo.svg";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, erosanix, kakaotalk-exe, kakaotalk-icon }: {
    packages.x86_64-linux =
      let
        pkgs = import "${nixpkgs}" {
          system = "x86_64-linux";
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
          nativeBuildInputs = [ nanum ];
          winAppInstall = ''
            ln -s "${nanum}/share/fonts/NanumBarunGothic.ttf" "$WINEPREFIX/drive_c/windows/Fonts/NanumBarunGothic.ttf"
            wine ${src}
            echo "CustomFontFaceName=NanumBarunGothic" >> "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Kakao/KakaoTalk/pref.ini"
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