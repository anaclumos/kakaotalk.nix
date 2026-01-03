# KakaoTalk Nix Flake

This repository packages the Windows version of **KakaoTalk** for NixOS using Wine.

## Features

- Single-instance management with automatic window activation
- Stuck app detection and recovery
- Optional watchdog mode for monitoring
- Phantom window hiding (fixes white rectangle issue)
- HiDPI scaling support
- Korean font configuration (Pretendard + Noto Color Emoji)
- Wayland/X11 backend selection

## Installation

```nix
{
  inputs.kakaotalk.url = "github:anaclumos/kakaotalk.nix";

  outputs = { self, nixpkgs, kakaotalk, ... }: {
    nixosConfigurations."my-host".configuration = { pkgs, ... }: {
      environment.systemPackages = [
        kakaotalk.packages.${pkgs.system}.kakaotalk
      ];
    };
  };
}
```

> [!IMPORTANT]
> On first launch, run `kakaotalk` in terminal to install and create the desktop entry.

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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `KAKAOTALK_CLEAN_START=1` | Kill existing processes and start fresh |
| `KAKAOTALK_WATCHDOG=1` | Enable watchdog mode for stuck detection |
| `KAKAOTALK_HIDE_PHANTOM=0` | Disable phantom window hiding (enabled by default) |
| `KAKAOTALK_ENSURE_EXPLORER=1` | Start explorer.exe for tray (disabled by default, usually not needed) |
| `KAKAOTALK_FORCE_BACKEND=wayland` | Use native Wayland instead of X11 |
| `KAKAOTALK_NO_SINGLE_INSTANCE=1` | Disable single-instance enforcement |
| `KAKAOTALK_SCALE=2` | Force specific scale factor for HiDPI |
| `KAKAOTALK_PHANTOM_INTERVAL=1` | Phantom monitor check interval in seconds |

## Reliability Features

### Single Instance Management

- **Automatic window activation**: Launching `kakaotalk` when already running brings the existing window to foreground
- **Lock file mechanism**: Prevents multiple instances from corrupting Wine state
- **Stale lock detection**: Automatically cleans up orphaned lock files

### Stuck App Recovery

If KakaoTalk becomes unresponsive (running but no visible window, tray icon not working):

```bash
KAKAOTALK_CLEAN_START=1 kakaotalk
```

### Watchdog Mode

Monitors the app and warns when it appears stuck:

```bash
KAKAOTALK_WATCHDOG=1 kakaotalk
```

The watchdog checks every 30 seconds for:
- Visible window presence
- Wineserver responsiveness
- Process health

### Phantom Window Handling

KakaoTalk creates small hidden windows for Windows message handling. The wrapper now automatically monitors and hides these by moving them offscreen (enabled by default). To disable:

```bash
KAKAOTALK_HIDE_PHANTOM=0 kakaotalk
```

### Focus Steal Prevention

Focus stealing is prevented via Wine registry settings that are applied automatically:

- `ForegroundLockTimeout` set to maximum (Windows-side prevention)
- `UseTakeFocus` disabled for KakaoTalk (X11-side prevention)
- `ForegroundFlashCount` set to 0 (flash in taskbar instead of stealing focus)

These settings are applied during prefix initialization and at runtime.

## Wayland

- Default backend is X11/Xwayland for tray stability
- To try native Wayland: `KAKAOTALK_FORCE_BACKEND=wayland kakaotalk`
- The wrapper automatically detects Wayland and uses XWayland

## Troubleshooting

### App is stuck (running but no window, unresponsive tray)

```bash
KAKAOTALK_CLEAN_START=1 kakaotalk
```

### Small white rectangle appears at screen edge

This is KakaoTalk's hidden message pump window. The wrapper now automatically handles this (enabled by default). If you still see issues, try adjusting the monitor interval:

```bash
KAKAOTALK_PHANTOM_INTERVAL=0.5 kakaotalk
```

### Tray icon not showing or not clickable

1. **GNOME**: Install the [AppIndicator extension](https://extensions.gnome.org/extension/615/appindicator-support/)
2. **Minimal WMs**: Run [snixembed](https://git.sr.ht/~steef/snixembed) for XEmbed-to-SNI bridging
3. **Wayland**: Try X11 backend: `KAKAOTALK_FORCE_BACKEND=x11 kakaotalk`

### Window won't come to foreground

The wrapper uses `xdotool` and `wmctrl` for window activation (included as dependencies):

```bash
# Manually activate
wmctrl -a "KakaoTalk"
# or
xdotool search --name "KakaoTalk" windowactivate
```

### Login issues

Keep trying to login - once it succeeds, it continues to work. If you see a server error after first login, exit completely and try again.

## Uninstalling

1. Remove the flake input from your configuration and rebuild.
2. Delete the Wine prefix and leftover files:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
rm -f ~/.local/share/applications/wine/Programs/카카오톡.desktop
rm -f ~/.local/share/applications/wine/Programs/KakaoTalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaotalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaoopen.desktop
```

## Building

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.
