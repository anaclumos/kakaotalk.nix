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

## Installation

Once you rebuild the flakes, you will see:

![Image](https://github.com/user-attachments/assets/74e76194-5f1e-4a00-93d6-dce340587f25)

If you want to use KakaoTalk in Korean, select the second one.

![Image](https://github.com/user-attachments/assets/c5057455-619f-4c23-8414-7871513b1781)

If you chose the second option, you'll the GNOME menu bar showing Korean "카카오톡 설치"

![Image](https://github.com/user-attachments/assets/367dc85f-b849-4983-81b6-4b9e90c37456)

Proceed to install. Untick the two options (optional). Those are "Launch KakaoTalk (카카오톡 실행)" and "Add Desktop Shortcut (바탕화면에 바로가기 만들기)" respectively. 

![Image](https://github.com/user-attachments/assets/f780d8f6-35ba-4e67-b0e0-809a8b0ccf41)

Click on the top settings icon. Click on the first option.

![Image](https://github.com/user-attachments/assets/c7556716-36b9-4c05-8549-f2ce3036a3bb)

Click on the first option on the left, and set the scale to 200% and Choose a Korean font. 

![Image](https://github.com/user-attachments/assets/ae1edd23-bcaf-4307-962a-2ee0a951bc7d)

Click on left button to confirm.

![Image](https://github.com/user-attachments/assets/45594ecc-3c06-461b-9ccc-1c4025825c20)

FYI, I used Pretendard.

![Image](https://github.com/user-attachments/assets/247eb319-dfbd-40e8-8448-88501ea04d5f)

If you're interested in how it actually works in NixOS, see: https://github.com/anaclumos/nixos

## Uninstalling

- Remove the Flakes Input.
- Delete `~/.local/share/kakaotalk`
- Delete
  - `~/.local/share/applications/wine/Programs/카카오톡.desktop`
  - `~/.local/share/applications/wine/Programs/kakaotalk.desktop`
  - `~/.local/share/applications/wine-protocol-kakaotalk.desktop`
  - `~/.local/share/applications/wine-protocol-kakaoopen.desktop`


## License

KakaoTalk is proprietary software owned by Kakao Corp. This flake is merely a packaging script and does not provide the software itself.
