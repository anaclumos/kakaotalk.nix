

# KakaoTalk Nix Flake

This repository packages the Windows version of **KakaoTalk** for NixOS.

```nix
{
  inputs.kakaotalk.url = "github:anaclumos/kakaotalk.nix";

  outputs = { self, nixpkgs, kakaotalk, ... }: {
    nixosConfigurations."my-host".configuration = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        kakaotalk.packages.${pkgs.system}.kakaotalk
      ];
    };
  };
}
```


## Installation

> [!IMPORTANT]
> On first launch, you must run `kakaotalk` in terminal to install & create desktop item.

| Step | Description | Screenshot |
|------|-------------|------------|
| 1 | Rebuild the flakes and launch the installer. | ![Image](https://github.com/user-attachments/assets/74e76194-5f1e-4a00-93d6-dce340587f25) |
| 2 | Select the second option if you want to use KakaoTalk in Korean. | ![Image](https://github.com/user-attachments/assets/c5057455-619f-4c23-8414-7871513b1781) |
| 3 | The installer window displays Korean text in the GNOME menu bar. | ![Image](https://github.com/user-attachments/assets/367dc85f-b849-4983-81b6-4b9e90c37456) |
| 4 | Proceed with the install. Untick "Launch KakaoTalk" and "Add Desktop Shortcut" if desired. | ![Image](https://github.com/user-attachments/assets/f780d8f6-35ba-4e67-b0e0-809a8b0ccf41) |
| 5 | Korean fonts are automatically installed. You can optionally adjust settings by clicking the top settings icon. | ![Image](https://github.com/user-attachments/assets/c7556716-36b9-4c05-8549-f2ce3036a3bb) |
| 6 | (Optional) On the left, select the first option, set the scale to 200% if needed. | ![Image](https://github.com/user-attachments/assets/ae1edd23-bcaf-4307-962a-2ee0a951bc7d) |
| 7 | Confirm by clicking the left button. | ![Image](https://github.com/user-attachments/assets/45594ecc-3c06-461b-9ccc-1c4025825c20) |
| 8 | Korean text should display correctly without manual font selection. | ![Image](https://github.com/user-attachments/assets/247eb319-dfbd-40e8-8448-88501ea04d5f) |

If you're interested in how it actually works in NixOS, see: https://github.com/anaclumos/nix

## Wayland users

- Default backend is Xwayland for tray stability (Wine's Wayland driver still has tray issues). To try native Wayland, launch with `KAKAOTALK_FORCE_BACKEND=wayland kakaotalk`.
- If the app gets stuck in the tray, you can do a clean start:  
  `KAKAOTALK_CLEAN_START=1 kakaotalk`  
  (equivalent to `WINEPREFIX=${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk wineserver -k` before launch)

## Uninstalling

1. Remove the flake input from your configuration and rebuild.
2. Delete the Wine prefix and leftover desktop files:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
rm -f ~/.local/share/applications/wine/Programs/카카오톡.desktop
rm -f ~/.local/share/applications/wine/Programs/KakaoTalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaotalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaoopen.desktop
```

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.

## Building

```
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```
