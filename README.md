# SnapDMG

macOS용 DMG 레이아웃 편집 도구입니다. 앱과 배경 이미지를 선택하고 아이콘 배치를 조정해 DMG 설치 파일을 만들 수 있습니다.

## 실행

macOS 26 이상이 필요합니다. 배포 앱은 Apple silicon과 Intel Mac을 지원합니다.

[GitHub Releases](https://github.com/MuchanKim/SnapDMG/releases)에서 ZIP을 다운로드하고, 압축을 푼 `SnapDMG.app`을 Applications 폴더로 옮겨 실행합니다. 앱 메뉴의 `Check for Updates…`로 새 버전을 확인할 수 있습니다.

## 개발

`SnapDMG/SnapDMG.xcodeproj`를 Xcode에서 열고 `SnapDMG` scheme을 빌드합니다. Sparkle 의존성은 Swift Package Manager로 가져옵니다.

```sh
xcodebuild -project SnapDMG/SnapDMG.xcodeproj \
  -scheme SnapDMG -destination 'platform=macOS' \
  -only-testing:SnapDMGTests test
```

업데이트 서명과 배포 과정은 [업데이트 배포 안내](docs/updates.md)를 참고하세요. 현재 준비한 1.0 배포 파일은 아직 Releases에 게시하지 않았습니다.

## 라이선스

[MIT License](LICENSE). Sparkle의 라이선스 고지는 앱에 포함된 [Sparkle-LICENSE.txt](SnapDMG/SnapDMG/Sparkle-LICENSE.txt)에 있습니다.
