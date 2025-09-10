

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

> IMPORTANT! On first launch, you must run `kakaotalk` in terminal to install & create desktop item.

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

If you're interested in how it actually works in NixOS, see: https://github.com/anaclumos/nixos

## Best Practices (GNOME Wayland, Bottles, Notifications)

- Wayland vs X11 backend:
  - The launcher now prefers the Wine Wayland driver when `WAYLAND_DISPLAY` exists and falls back to X11/XWayland otherwise. Force it explicitly with:
    - Wayland: `KAKAOTALK_FORCE_BACKEND=wayland kakaotalk`
    - X11: `KAKAOTALK_FORCE_BACKEND=x11 kakaotalk`
  - Why Wayland: prevents focus‑stealing and generally plays nicer with GNOME window management. If your Wine build lacks the Wayland driver, the wrapper will harmlessly fall back to X11.

- Focus behavior on GNOME:
  - Prefer Wayland backend (above). On X11, the wrapper sets Wine’s `UseTakeFocus=N` to reduce focus stealing, but some apps may still raise themselves.
  - System‑wide option to be stricter: `gsettings set org.gnome.mutter focus-new-windows 'strict'` (keeps new/urgent windows from stealing focus).

- GNOME notifications:
  - KakaoTalk on Wine does not emit native GNOME notifications; it shows in‑app toasts. There is no reliable Wine bridge to GNOME’s `org.freedesktop.Notifications` yet.
  - To avoid the app popping to front on message alerts, keep KakaoTalk’s notifications on but disable any “bring to front on alert”/“focus on new message” options in the app settings.
  - Tray restoration requires the GNOME extension “AppIndicator and KStatusNotifierItem Support”. Without it, use `wineserver -k` to quit fully.

- Bottles (optional integration):
  - If you prefer managing the prefix with Bottles (Flatpak or system), create a new Bottle (type: Application), enable esync/fsync, DXVK, and Wayland support if offered by your Bottles runner.
  - Install KakaoTalk into that Bottle (use the same Windows installer URL). Then run via `bottles-cli run -b "KakaoTalk" -- "KakaoTalk"`.
  - Bottles doesn’t magically provide native GNOME notifications for Windows apps, but it often ships newer Wine(-GE/staging) with the Wayland driver which improves focus behavior.

- DPI/Scaling:
  - The launcher avoids forcing DPI inside Wine; aim for integer display scales (100%/200%) on Wayland for crisp text, and use KakaoTalk’s in‑app scaling if needed.
  - If fractional scaling artifacts occur, try the X11 fallback: `KAKAOTALK_FORCE_BACKEND=x11 kakaotalk`.

- Rendering & performance:
  - Esync/fsync are enabled by default via env. Set `WINEESYNC=0 WINEFSYNC=0` to troubleshoot if you hit instability.
  - Ensure 32‑bit graphics are enabled on NixOS so Wine can run 32‑bit GUI apps:
    - `hardware.graphics.enable = true;`
    - `hardware.graphics.enable32Bit = true;`

- Input method:
  - The launcher exports `GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS=fcitx`. Enable and configure fcitx5 on NixOS for proper IME.

## Uninstalling

- Remove the Flakes Input.
- Delete `~/.local/share/kakaotalk`
- Delete
  - `~/.local/share/applications/wine/Programs/카카오톡.desktop`
  - `~/.local/share/applications/wine/Programs/KakaoTalk.desktop`
  - `~/.local/share/applications/wine-protocol-kakaotalk.desktop`
  - `~/.local/share/applications/wine-protocol-kakaoopen.desktop`


```
rm -rf ~/.local/share/kakaotalk ~/.local/share/applications/wine/Programs/카카오톡.desktop ~/.local/share/applications/wine/Programs/KakaoTalk.desktop ~/.local/share/applications/wine-protocol-kakaotalk.desktop ~/.local/share/applications/wine-protocol-kakaoopen.desktop
```

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.

## Building

```
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```
