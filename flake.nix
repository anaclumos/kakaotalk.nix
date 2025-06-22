{
  description = "A Nix flake for KakaoTalk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        kakaotalkSrc = pkgs.fetchurl {
          url = "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe";
          sha256 = "0j853x6ihgqvkzfnijw92q6z22d2m60clbdk5mr1n0qx0s1bm009";
        };
        
        kakaotalkIcon = pkgs.fetchurl {
          url = "https://upload.wikimedia.org/wikipedia/commons/e/e3/KakaoTalk_logo.svg";
          sha256 = "16ad4i7k1zm5drxkhfzplxfpk41js71kp9vr6xadl2jh27y67pfh";
        };

        wine = pkgs.wineWowPackages.stable;
        winetricks = pkgs.winetricks;

        winePrefix = "\${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk";
        
      in {
        packages = {
          default = self.packages.${system}.kakaotalk;
          
          kakaotalk = pkgs.stdenv.mkDerivation rec {
            pname = "kakaotalk";
            version = "0.1.0";
            
            src = kakaotalkSrc;
            dontUnpack = true;

            nativeBuildInputs = with pkgs; [ 
              makeWrapper
              copyDesktopItems
            ];

            desktopItem = pkgs.makeDesktopItem {
              name = "kakaotalk";
              desktopName = "KakaoTalk";
              exec = "kakaotalk";
              icon = "kakaotalk";
              categories = [ "Network" "InstantMessaging" ];
              comment = "KakaoTalk messenger via Wine";
              startupWMClass = "kakaotalk.exe";
            };

            installPhase = ''
              runHook preInstall

              # Create directory structure
              install -Dm644 ${src} $out/share/kakaotalk/KakaoTalk_Setup.exe
              install -Dm644 ${kakaotalkIcon} $out/share/icons/hicolor/scalable/apps/kakaotalk.svg
              
              # Install desktop entry
              install -Dm644 ${desktopItem}/share/applications/*.desktop -t $out/share/applications

              # Create wrapper script
              makeWrapper ${pkgs.writeShellScript "kakaotalk-launcher" ''
                set -e
                
                PREFIX="${winePrefix}"
                INSTALLER="$out/share/kakaotalk/KakaoTalk_Setup.exe"
                WINE="${wine}/bin/wine"
                WINEBOOT="${wine}/bin/wineboot"
                
                # Initialize Wine prefix if needed
                if [ ! -d "$PREFIX" ]; then
                  mkdir -p "$PREFIX"
                  WINEPREFIX="$PREFIX" "$WINEBOOT" -u
                  
                  # Configure Wine settings
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed" /t REG_SZ /d "N" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /f 2>/dev/null || true
                  
                  # Configure font rendering
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "ClientSideAntiAliasWithCore" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "ClientSideAntiAliasWithRender" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingType" /t REG_DWORD /d 2 /f
                fi
                
                # Install KakaoTalk if not present
                if [ ! -f "$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
                  echo "Installing KakaoTalk..."
                  WINEPREFIX="$PREFIX" "$WINE" "$INSTALLER"
                fi
                
                # Run KakaoTalk
                exec env WINEPREFIX="$PREFIX" "$WINE" "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
              ''} $out/bin/kakaotalk \
                --prefix PATH : ${wine}/bin \
                --prefix PATH : ${winetricks}/bin

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "KakaoTalk messenger for Linux via Wine";
              homepage = "https://www.kakaocorp.com/page/service/service/KakaoTalk";
              license = licenses.unfree;
              platforms = [ "x86_64-linux" ];
              mainProgram = "kakaotalk";
            };
          };
        };
        
        apps = {
          default = self.apps.${system}.kakaotalk;
          kakaotalk = {
            type = "app";
            program = "${self.packages.${system}.kakaotalk}/bin/kakaotalk";
          };
        };
      }
    );
}