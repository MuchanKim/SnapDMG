# snapDMG — Design Spec

macOS 네이티브 GUI 앱으로, 인디 개발자가 예쁜 DMG 인스톨러를 손쉽게 만들 수 있는 유틸리티.

## Overview

- **앱 이름:** snapDMG
- **플랫폼:** macOS 14 (Sonoma)+
- **배포 방식:** 웹 배포 (직접 dmg/zip, 노터라이제이션)
- **타겟 사용자:** 인디 개발자 / 1인 개발자
- **핵심 가치:** .app을 드롭하고, 배경/아이콘 위치를 잡고, Build 누르면 예쁜 DMG가 나온다

## Scope

### In Scope
- DMG 창 크기 설정
- 배경 이미지 첨부 (권장 크기 안내, 이미지 제작은 앱 외부)
- 앱 아이콘 & Applications 링크 위치 조정 (드래그 앤 드롭 프리뷰)
- 레이아웃 프리셋 (Classic, Centered, Top-Bottom)
- 프로젝트 파일 저장/불러오기 (재사용)

### Out of Scope
- 배경 이미지 편집/제작 (화살표, 텍스트 등)
- CI/CD CLI 모드 (추후 확장 가능)
- 라이선스 동의 창
- 코드사인/노터라이제이션 (사용자가 별도로 처리)
- 커스텀 볼륨 아이콘

## Architecture

```
┌─────────────────────────────────┐
│         UI Layer (SwiftUI)       │
│  - 프로젝트 편집 화면             │
│  - 드래그 가능한 프리뷰 캔버스     │
│  - 프리셋 선택기                  │
│  - 설정 패널 (창 크기, 배경)      │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│       Core Layer (Swift)         │
│  - DSStoreWriter: .DS_Store 생성 │
│  - DMGBuilder: hdiutil 호출      │
│  - ProjectModel: 설정 저장/로드   │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│      System Layer (macOS)        │
│  - hdiutil (DMG 생성/변환)       │
│  - cp, ln -s (파일 복사, 심링크)  │
└─────────────────────────────────┘
```

## Technical Approach: .DS_Store Direct Generation

AppleScript + Finder 방식 대신 **.DS_Store 바이너리를 직접 생성**하는 접근.

### 근거
- dmgbuild(Python), node-appdmg(Node)에서 수년간 프로덕션 검증됨
- Finder 버그 워크어라운드 불필요 (DropDMG는 20년간 매 macOS 버전마다 대응)
- 빠르고 결정적(deterministic)
- snapDMG가 필요한 레코드가 제한적이라 최소한의 writer로 충분

### .DS_Store Records

| 레코드 | 타입 | 역할 |
|---|---|---|
| `vSrn` | long | 버전 식별자 (항상 1) |
| `bwsp` | binary plist | 창 위치/크기 |
| `icvp` | binary plist | 아이콘 뷰 옵션 (아이콘 크기, 배경 이미지 경로, 텍스트 크기) |
| `Iloc` | 16-byte blob | 각 파일의 아이콘 x, y 좌표 |

### .DS_Store File Structure
- Buddy Allocator + B-tree
- 레코드는 (파일명 + 구조ID)로 정렬
- Python `ds_store` 라이브러리를 참고하여 Swift로 최소한의 writer 구현 (읽기 불필요, 쓰기만)

## UI Design

### Layout: Single Window

- **왼쪽 사이드바 (220pt)**
  - .app 파일 드롭 영역
  - 창 크기 입력 (W × H)
  - 배경 이미지 드롭 + 권장 크기 안내 (창 크기에 맞춰 동적 표시)
  - 프리셋 선택 버튼 (Classic / Centered / Top-Bottom)
  - Build DMG 버튼

- **중앙 프리뷰 캔버스**
  - 실제 DMG 모습을 실시간 프리뷰
  - 앱 아이콘, Applications 아이콘을 드래그하여 위치 조정
  - 배경 이미지 반영
  - 창 크기에 맞춰 캔버스 비율 조정

### Presets

| 프리셋 | 설명 | 참고 |
|---|---|---|
| **Classic** | 좌-우 배치 | Figma, 대부분의 메이저 앱 |
| **Centered** | 중앙 나란히 | 여백 많은 배경에 적합 |
| **Top-Bottom** | 상-하 배치 | Raycast 스타일 |

프리셋 선택 시 아이콘 좌표가 자동 세팅되고, 이후 드래그로 미세 조정.

## Data Model

```swift
struct SnapDMGProject: Codable {
    var appName: String              // "MyApp"
    var windowSize: CGSize           // (540, 380)
    var backgroundImagePath: String? // 배경 이미지 경로 참조
    var iconPositions: IconPositions
}

struct IconPositions: Codable {
    var app: CGPoint         // 앱 아이콘 위치
    var applications: CGPoint // Applications 링크 위치
}
```

- **파일 확장자:** `.snapdmg` — 더블클릭으로 snapDMG에서 열림
- **포맷:** JSON (Codable) — 사람이 읽을 수 있고 버전 관리 가능
- **배경 이미지:** 경로 참조 (파일에 내장하지 않음)

## DMG Build Pipeline

사용자가 "Build DMG" 클릭 시 내부에서 실행되는 흐름:

1. `hdiutil create` — .app 크기 기반으로 적절한 용량의 읽기/쓰기 임시 DMG 생성
2. `hdiutil attach` — 임시 DMG를 마운트
3. 파일 배치 — .app 복사, `/Applications` 심볼릭 링크 생성, `.background/`에 배경 이미지 복사
4. `DSStoreWriter` — .DS_Store 바이너리 직접 생성하여 마운트 경로에 쓰기
5. `hdiutil detach` — 언마운트
6. `hdiutil convert -format UDZO` — 읽기 전용 압축 DMG로 변환
7. 임시 파일 정리

### Error Handling
- 각 단계 실패 시 이전 단계 정리 (마운트된 볼륨 detach, 임시 파일 삭제)
- 빌드 진행 상황을 UI에 프로그레스 바로 표시

### DMG Sizing
- .app 크기를 미리 계산하여 적절한 `-size` 값 자동 산출 (앱 크기 + 배경 이미지 크기 + 여유분)

## Tech Stack

- **UI:** SwiftUI (드래그 프리뷰 캔버스 등 정밀한 부분은 필요 시 AppKit 혼합)
- **Core:** Swift
- **System:** hdiutil (macOS 기본 제공)
- **최소 지원:** macOS 14 Sonoma
