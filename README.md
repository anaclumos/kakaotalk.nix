# KakaoTalk Nix Flake

This repository packages the Windows version of **KakaoTalk** for Linux using Wine. The flake provides a wrapper that sets up a Wine prefix, configures fonts and locale for Korean support and then launches KakaoTalk.

## Prerequisites
- **Nix** with flakes enabled

## Installation

To build and run KakaoTalk without installing it system wide:

```bash
nix run github:anaclumos/kakaotalk.nix
```

To permanently install it into your user profile:

```bash
nix profile install .
```

## Using in NixOS

Add this flake to the `inputs` of your `flake.nix` and reference the package in `environment.systemPackages` of your `configuration.nix`:

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

On first launch a new Wine prefix is created at `\$XDG_DATA_HOME/kakaotalk`. The wrapper configures DPI scaling, installs core fonts and sets the locale for proper Korean support before running the KakaoTalk installer automatically.

## Uninstallation

To remove KakaoTalk from your system:

1. Remove the package from your Nix profile:

   ```bash
   nix profile remove kakaotalk
   ```

2. Remove the Wine prefix:

   ```bash
   rm -rf ${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk
   ```

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.
