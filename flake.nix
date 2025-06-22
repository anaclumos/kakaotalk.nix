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
                INSTALLER="${src}"
                WINE="${wine}/bin/wine"
                WINEBOOT="${wine}/bin/wineboot"
                WINETRICKS="${winetricks}/bin/winetricks"
                
                # Initialize Wine prefix if needed
                if [ ! -d "$PREFIX" ]; then
                  mkdir -p "$PREFIX"
                  WINEPREFIX="$PREFIX" "$WINEBOOT" -u
                  
                  # Configure Wine settings
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Managed" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg delete "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /f 2>/dev/null || true
                  
                  # Configure font rendering
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "ClientSideAntiAliasWithCore" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "ClientSideAntiAliasWithRender" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v "FontSmoothingType" /t REG_DWORD /d 2 /f
                  
                  # Configure window behavior for better Wayland compatibility
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DWM" /v "AllowWindowAnimation" /t REG_DWORD /d 1 /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DWM" /v "AllowWinodwMaximize" /t REG_DWORD /d 1 /f
                  
                  # Configure window manager class hints for KakaoTalk
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" /v "Managed" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f
                  
                  # Enable proper keyboard shortcuts and IME
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "InputStyle" /t REG_SZ /d "root" /f
                  
                  # Fix keyboard shortcuts
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "GrabFullscreen" /t REG_SZ /d "N" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "GrabPointer" /t REG_SZ /d "N" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DirectInput" /v "MouseWarpOverride" /t REG_SZ /d "disable" /f
                  
                  # Configure IME support
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseXIM" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseTakeFocus" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v "UseXKB" /t REG_SZ /d "Y" /f
                  
                  # Enable IME for the application
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" /v "UseXIM" /t REG_SZ /d "Y" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\KakaoTalk.exe\\X11 Driver" /v "InputStyle" /t REG_SZ /d "overthespot" /f
                  
                  # Set locale for proper IME handling
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "Locale" /t REG_SZ /d "00000412" /f
                  WINEPREFIX="$PREFIX" "$WINE" reg add "HKEY_CURRENT_USER\\Control Panel\\International" /v "sLanguage" /t REG_SZ /d "KOR" /f
                  
                  # Install Windows IME components
                  WINEPREFIX="$PREFIX" "$WINETRICKS" -q ime_ko cjkfonts || true
                fi
                
                # Install KakaoTalk if not present
                if [ ! -f "$PREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" ]; then
                  echo "Installing KakaoTalk..."
                  WINEPREFIX="$PREFIX" "$WINE" "$INSTALLER"
                fi
                
                # Set Wayland-specific environment variables
                export WINEDLLOVERRIDES="winemenubuilder.exe=d"
                export WINE_DISABLE_WAYLAND=0
                export WINE_ENABLE_PIPE_SYNC_FOR_APP=1
                
                # Disable Wine's keyboard grabbing to fix shortcuts
                export WINE_ALLOW_XIM=1
                export WINE_X11_NO_MITSHM=1
                
                # Set input method environment variables
                # Detect which input method is available
                if command -v ibus-daemon >/dev/null 2>&1; then
                  export XMODIFIERS="@im=ibus"
                  export GTK_IM_MODULE="ibus"
                  export QT_IM_MODULE="ibus"
                  export SDL_IM_MODULE="ibus"
                  export GLFW_IM_MODULE="ibus"
                elif command -v fcitx5 >/dev/null 2>&1; then
                  export XMODIFIERS="@im=fcitx"
                  export GTK_IM_MODULE="fcitx"
                  export QT_IM_MODULE="fcitx"
                  export SDL_IM_MODULE="fcitx"
                  export GLFW_IM_MODULE="fcitx"
                elif command -v fcitx >/dev/null 2>&1; then
                  export XMODIFIERS="@im=fcitx"
                  export GTK_IM_MODULE="fcitx"
                  export QT_IM_MODULE="fcitx"
                  export SDL_IM_MODULE="fcitx"
                  export GLFW_IM_MODULE="fcitx"
                fi
                
                # Set locale for Wine
                export LANG="ko_KR.UTF-8"
                export LC_ALL="ko_KR.UTF-8"
                
                # Run KakaoTalk with improved window management
                exec env WINEPREFIX="$PREFIX" \
                  WINE_ENABLE_PIPE_SYNC_FOR_APP=1 \
                  WINE_DISABLE_WAYLAND=0 \
                  LANG="ko_KR.UTF-8" \
                  LC_ALL="ko_KR.UTF-8" \
                  "$WINE" "C:\\Program Files (x86)\\Kakao\\KakaoTalk\\KakaoTalk.exe" "$@"
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