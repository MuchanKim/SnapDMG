# SnapDMG 업데이트 배포

SnapDMG는 무료 오픈소스 Sparkle 2.10.0을 사용한다. 앱 메뉴의 `Check for Updates…`와 자동 업데이트 확인을 제공하며, 자동 확인 동의·다운로드·설치 UI는 Sparkle이 처리한다. 라이선스는 앱에 `Sparkle-LICENSE.txt` 리소스로 포함한다.

SnapDMG 전용 Ed25519 키는 macOS Keychain의 `com.moolab.SnapDMG` account에 생성했고, 공개 키를 설정했다. 개인 키는 저장소에 포함하지 않는다. Feed 주소는 공개 소스 저장소 `MuchanKim/SnapDMG`의 최신 release asset을 사용한다.

```text
https://github.com/MuchanKim/SnapDMG/releases/latest/download/appcast.xml
```

처음 release를 게시하면 이 주소에서 feed를 받을 수 있다. 배포 전에는 앱의 Developer ID 서명과 Apple notarization, ZIP의 Ed25519 서명을 완료해야 한다.

둘 중 하나라도 설정 값이 없으면 자동 확인을 시작하지 않고 메뉴를 비활성화하며, Console의 `com.moolab.SnapDMG` / `Updates` 로그에 원인을 남긴다.

## 최초 설정

1. 소스 저장소 `MuchanKim/SnapDMG`의 GitHub Releases에 `appcast.xml`과 DMG/ZIP을 게시한다. Feed는 `/releases/latest/download/appcast.xml`, 각 버전의 ZIP은 `/releases/download/v1.0/SnapDMG-1.0.zip`처럼 고정된 태그 주소를 사용한다.
2. Xcode에서 Sparkle 패키지를 resolve한다. 패키지 checkout의 형제 경로 `artifacts/sparkle/Sparkle/bin/`에 `generate_keys`와 `generate_appcast`가 있다.
3. 최초 키 생성은 이미 완료했다. 새 Mac에서 새 키를 다시 만드는 대신 기존 키를 이전한다. 공개 키만 확인할 때는 `generate_keys --account com.moolab.SnapDMG -p`를 사용한다. 개인 키는 macOS Keychain에 저장되며, **공개 키만** 프로젝트에 넣는다. 개인 키와 Keychain은 백업하고 저장소에 개인 키를 넣지 않는다.
4. `SnapDMG/Config/Updates.xcconfig`의 두 값을 채운다. 이 파일은 Debug와 Release 앱 타겟에 공통으로 적용된다.

```xcconfig
SPARKLE_FEED_URL = https:/$()/github.com/MuchanKim/SnapDMG/releases/latest/download/appcast.xml
SPARKLE_PUBLIC_ED_KEY = S5jZKZIiAFGL6TI4k37qPq868d46A+xPLCe7Y5FmGEw=
```

xcconfig는 `//`를 주석으로 해석하므로 `https:/$()/`를 사용한다. 빌드 후에는 `https://`로 확장된다. 설정 값은 앱의 `SUFeedURL`과 `SUPublicEDKey`에 들어간다.

Sparkle 사용료는 없다. 정식 웹 배포의 Developer ID 서명·notarization에는 별도의 Apple Developer Program 멤버십이 필요하다. 기존 회원은 Sparkle 도입으로 추가 멤버십 비용이 발생하지 않는다.

## 새 버전 배포

1. Xcode 앱 타겟의 `Version`(`MARKETING_VERSION`)을 바꾸고 `Build`(`CURRENT_PROJECT_VERSION`)를 증가시킨다. Sparkle의 새 버전 판단은 `CFBundleVersion`인 Build 번호를 기준으로 한다.
2. Xcode의 `Product > Archive > Distribute App > Developer ID`로 앱과 내장 Sparkle helper를 서명하고 notarize한다.
3. 내보낸 앱을 DMG 또는 ZIP으로 포장한다. ZIP은 symlink와 권한을 보존하는 `ditto`를 사용한다.

```sh
ditto -c -k --sequesterRsrc --keepParent /path/to/SnapDMG.app /path/to/updates/SnapDMG-1.1.zip
```

4. `generate_appcast`로 업데이트 파일의 Ed25519 서명과 feed를 생성한다. `--account`는 최초 키 생성 때와 같아야 한다. `--download-url-prefix`의 태그는 이번 release 태그로 바꾼다.

```sh
/path/to/Sparkle/bin/generate_appcast \
  --account com.moolab.SnapDMG \
  --download-url-prefix https://github.com/MuchanKim/SnapDMG/releases/download/v1.1/ \
  /path/to/updates
```

5. notarization과 검증을 완료한 ZIP과 `appcast.xml`을 같은 draft release에 올린 뒤 게시한다. 최신 release의 `appcast.xml`이 모든 앱에서 읽는 feed가 된다. 이전 버전에서 참조하는 파일 주소도 유지한다. Keychain이나 개인 키는 업로드하지 않는다. notarization 후 ticket을 staple하면 ZIP 바이트가 바뀌므로 ZIP과 appcast 서명을 다시 생성한다.

## 검증

- 내보낸 앱 번들의 `Info.plist`에 실제 `SUFeedURL`과 `SUPublicEDKey`가 들어 있는지 확인한다.
- `/Applications`에 설치한 이전 버전에서 `Check for Updates…`로 새 버전 안내·다운로드·설치·재실행을 확인한다. DMG 안에서 실행한 앱은 읽기 전용이므로 업데이트 검증에 사용하지 않는다.
- 새 버전에서 프로젝트 열기·저장이 정상인지 확인한다.
- 자동 확인은 Sparkle의 사용자 동의와 확인 주기를 따른다. 수동 확인과 별도로 검증한다.

CI/CD는 아직 구성하지 않았다. 앱 연동 빌드 성공만으로 서명된 버전 간 실제 업데이트가 검증된 것은 아니다.

공식 자료: [Sparkle 설정](https://sparkle-project.org/documentation/), [SwiftUI 연동](https://sparkle-project.org/documentation/programmatic-setup/), [업데이트 게시](https://sparkle-project.org/documentation/publishing/), [라이선스](https://github.com/sparkle-project/Sparkle/blob/2.10.0/LICENSE), [Apple 멤버십](https://developer.apple.com/support/compare-memberships/).
