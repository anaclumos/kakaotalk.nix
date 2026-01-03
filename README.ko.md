# KakaoTalk Nix Flake

Wine을 사용하여 NixOS에서 Windows 버전의 **카카오톡**을 실행할 수 있도록 패키징한 저장소입니다.

## 기능

- 단일 인스턴스 관리 및 자동 창 활성화
- 앱 멈춤 감지 및 복구
- 워치독 모드 (선택적)
- 팬텀 윈도우 숨김 (흰색 사각형 문제 해결)
- HiDPI 스케일링 지원
- 한글 폰트 설정 (Pretendard + Noto Color Emoji)
- Wayland/X11 백엔드 선택

## 설치

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
> 처음 실행 시 터미널에서 `kakaotalk` 명령어를 실행하여 설치 및 데스크톱 항목을 생성하세요.

| 단계 | 설명 | 스크린샷 |
|------|------|----------|
| 1 | Flake를 빌드하고 설치 프로그램을 실행합니다. | ![Image](https://github.com/user-attachments/assets/74e76194-5f1e-4a00-93d6-dce340587f25) |
| 2 | 한국어로 사용하려면 두 번째 옵션을 선택합니다. | ![Image](https://github.com/user-attachments/assets/c5057455-619f-4c23-8414-7871513b1781) |
| 3 | GNOME 메뉴 바에 한글이 표시됩니다. | ![Image](https://github.com/user-attachments/assets/367dc85f-b849-4983-81b6-4b9e90c37456) |
| 4 | 설치를 진행합니다. 필요에 따라 "카카오톡 실행" 및 "바탕화면 바로가기 추가"를 해제하세요. | ![Image](https://github.com/user-attachments/assets/f780d8f6-35ba-4e67-b0e0-809a8b0ccf41) |
| 5 | 한글 폰트가 자동으로 설치됩니다. 상단 설정 아이콘을 클릭하여 설정을 조정할 수 있습니다. | ![Image](https://github.com/user-attachments/assets/c7556716-36b9-4c05-8549-f2ce3036a3bb) |
| 6 | (선택) 왼쪽에서 첫 번째 옵션을 선택하고 필요 시 스케일을 200%로 설정합니다. | ![Image](https://github.com/user-attachments/assets/ae1edd23-bcaf-4307-962a-2ee0a951bc7d) |
| 7 | 왼쪽 버튼을 클릭하여 확인합니다. | ![Image](https://github.com/user-attachments/assets/45594ecc-3c06-461b-9ccc-1c4025825c20) |
| 8 | 별도의 폰트 설정 없이 한글이 정상적으로 표시됩니다. | ![Image](https://github.com/user-attachments/assets/247eb319-dfbd-40e8-8448-88501ea04d5f) |

NixOS에서 실제로 어떻게 동작하는지 확인하려면: https://github.com/anaclumos/nix

## 환경 변수

| 변수 | 설명 |
|------|------|
| `KAKAOTALK_CLEAN_START=1` | 기존 프로세스를 종료하고 새로 시작 |
| `KAKAOTALK_WATCHDOG=1` | 멈춤 감지를 위한 워치독 모드 활성화 |
| `KAKAOTALK_HIDE_PHANTOM=0` | 팬텀 윈도우 숨김 비활성화 (기본값: 활성화) |
| `KAKAOTALK_PREVENT_FOCUS_STEAL=0` | 포커스 가로채기 방지 비활성화 (기본값: 활성화) |
| `KAKAOTALK_ENSURE_EXPLORER=0` | 트레이용 explorer.exe 시작 건너뛰기 (기본값: 활성화) |
| `KAKAOTALK_FORCE_BACKEND=wayland` | X11 대신 네이티브 Wayland 사용 |
| `KAKAOTALK_NO_SINGLE_INSTANCE=1` | 단일 인스턴스 강제 비활성화 |
| `KAKAOTALK_SCALE=2` | HiDPI용 스케일 팩터 강제 지정 |
| `KAKAOTALK_PHANTOM_INTERVAL=1` | 팬텀 모니터 체크 간격 (초) |
| `KAKAOTALK_FOCUS_GUARD_INTERVAL=0.3` | 포커스 가드 체크 간격 (초) |
| `KAKAOTALK_FOCUS_GUARD_GRACE=5` | 포커스 가드 활성화 전 유예 시간 (초) |

## 안정성 기능

### 단일 인스턴스 관리

- **자동 창 활성화**: 이미 실행 중일 때 `kakaotalk`을 실행하면 기존 창을 전면으로 가져옴
- **잠금 파일 메커니즘**: 여러 인스턴스로 인한 Wine 상태 손상 방지
- **오래된 잠금 감지**: 고아 잠금 파일 자동 정리

### 멈춤 앱 복구

카카오톡이 응답하지 않는 경우 (실행 중이지만 창이 없거나 트레이 아이콘이 작동하지 않음):

```bash
KAKAOTALK_CLEAN_START=1 kakaotalk
```

### 워치독 모드

앱을 모니터링하고 멈춤 상태로 보일 때 경고합니다:

```bash
KAKAOTALK_WATCHDOG=1 kakaotalk
```

워치독은 30초마다 다음을 확인합니다:
- 표시된 창 존재 여부
- Wineserver 응답성
- 프로세스 상태

### 팬텀 윈도우 처리

카카오톡은 Windows 메시지 처리를 위한 작은 숨겨진 창을 생성합니다. 래퍼가 자동으로 이를 모니터링하고 화면 밖으로 이동시켜 숨깁니다 (기본값: 활성화). 비활성화하려면:

```bash
KAKAOTALK_HIDE_PHANTOM=0 kakaotalk
```

### 포커스 가로채기 방지

래퍼에는 새 메시지가 도착했을 때 카카오톡이 포커스를 가로채는 것을 방지하는 포커스 가드가 포함되어 있습니다 (X11에서 기본값: 활성화). 비활성화하려면:

```bash
KAKAOTALK_PREVENT_FOCUS_STEAL=0 kakaotalk
```

가드는 초기 포커스를 허용하기 위해 실행 후 유예 시간 (기본값 5초)이 있습니다.

## Wayland

- 트레이 안정성을 위해 기본 백엔드는 X11/Xwayland입니다
- 네이티브 Wayland 시도: `KAKAOTALK_FORCE_BACKEND=wayland kakaotalk`
- 래퍼가 자동으로 Wayland를 감지하고 XWayland를 사용합니다

## 문제 해결

### 앱이 멈춤 (실행 중이지만 창 없음, 트레이 응답 없음)

```bash
KAKAOTALK_CLEAN_START=1 kakaotalk
```

### 화면 가장자리에 작은 흰색 사각형이 나타남

카카오톡의 숨겨진 메시지 펌프 윈도우입니다. 래퍼가 자동으로 처리합니다 (기본값: 활성화). 여전히 문제가 있으면 모니터 간격을 조정해 보세요:

```bash
KAKAOTALK_PHANTOM_INTERVAL=0.5 kakaotalk
```

### 트레이 아이콘이 표시되지 않거나 클릭되지 않음

1. **GNOME**: [AppIndicator 확장](https://extensions.gnome.org/extension/615/appindicator-support/) 설치
2. **미니멀 WM**: XEmbed-to-SNI 브릿징을 위해 [snixembed](https://git.sr.ht/~steef/snixembed) 실행
3. **Wayland**: X11 백엔드 시도: `KAKAOTALK_FORCE_BACKEND=x11 kakaotalk`

### 창이 전면으로 나오지 않음

래퍼는 창 활성화를 위해 `xdotool`과 `wmctrl`을 사용합니다 (의존성으로 포함됨):

```bash
# 수동 활성화
wmctrl -a "KakaoTalk"
# 또는
xdotool search --name "KakaoTalk" windowactivate
```

### 로그인 문제

계속 로그인을 시도하세요 - 한 번 성공하면 이후 계속 작동합니다. 첫 로그인 후 서버 오류가 표시되면 완전히 종료하고 다시 시도하세요.

## 제거

1. 설정에서 flake 입력을 제거하고 다시 빌드합니다.
2. Wine 프리픽스와 남은 파일을 삭제합니다:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/kakaotalk"
rm -f ~/.local/share/applications/wine/Programs/카카오톡.desktop
rm -f ~/.local/share/applications/wine/Programs/KakaoTalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaotalk.desktop
rm -f ~/.local/share/applications/wine-protocol-kakaoopen.desktop
```

## 빌드

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```

## 라이선스

카카오톡은 Kakao Corp.가 소유한 독점 소프트웨어입니다. 이 flake는 단순히 패키징 스크립트이며 소프트웨어 자체를 제공하지 않습니다.
