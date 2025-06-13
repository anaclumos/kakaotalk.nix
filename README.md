# KakaoTalk Nix Flake

This repository packages the Windows version of **KakaoTalk** for Linux using [Bottles](https://usebottles.com/).

## Prerequisites
- **Nix** with flakes enabled
- **Bottles** installed on your system (`bottles-cli` should be in your `PATH`)

## Installation

To build and run KakaoTalk without installing it system wide:

```bash
nix run .
```

To permanently install it into your user profile:

```bash
nix profile install .
```

## Using in NixOS

Add this flake to the `inputs` of your `flake.nix` and reference the package in `environment.systemPackages` of your `configuration.nix`:

```nix
{
  inputs.kakaotalk.url = "github:USER/kakaotalk.nix"; # replace with the repo location

  outputs = { self, nixpkgs, kakaotalk, ... }: {
    nixosConfigurations."my-host".configuration = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        kakaotalk.packages.${pkgs.system}.kakaotalk
      ];
    };
  };
}
```

The first launch creates a new Bottles bottle named `kakaotalk` and runs the KakaoTalk installer automatically.

## Uninstallation

To remove KakaoTalk from your system:

1. Remove the package from your Nix profile:

   ```bash
   nix profile remove kakaotalk
   ```

2. Delete the created bottle (if present):

   ```bash
   bottles-cli remove -b kakaotalk
   ```

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.
