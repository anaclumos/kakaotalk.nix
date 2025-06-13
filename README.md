# KakaoTalk Nix Flake

This repository packages the Windows version of **KakaoTalk** for Linux using Wine. The flake provides a wrapper that sets up a Wine prefix, configures fonts and locale for Korean support and then launches KakaoTalk.

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

Installation: Select 2nd option (First Tofu); and install with guesswork, once installed you can set local Korean font to display the Korean Font.

If you're interested in how it actually works in NixOS, see: https://github.com/anaclumos/nixos

## Uninstalling

- Remove the Flakes Input.
- Delete `~/.local/share/kakaotalk`
- Delete `~/.local/share/applications/wine/Programs/카카오톡.desktop` or `~/.local/share/applications/wine/Programs/kakaotalk.desktop`

## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.
