

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

On first launch, you must run `kakaotalk` in terminal to install, then reboot.

If you're interested in how it actually works in NixOS, see: https://github.com/anaclumos/nixos

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