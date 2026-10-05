# CI와 자동배포

## 실행 흐름

- `CI`: `main` 대상 PR, `main` push, 수동 실행에서 배포 경계 검증 테스트와 앱 단위 테스트를 실행하고, arm64 + x86_64 Release 앱을 빌드한다. 테스트 결과는 7일간 Actions artifact로 보관한다. UI 테스트는 실행하지 않는다.
- `Release`: `v1.0`, `v1.1.0` 같은 stable 태그 push 또는 기존 태그 수동 실행으로 시작한다. 태그가 `main`에 포함된 커밋인지 확인한 뒤 테스트 → Developer ID 서명 → Apple notarization → staple → ZIP과 Sparkle feed 생성·검증 → GitHub Release 게시를 진행한다.
- `main`은 PR을 통해 변경한다. `Build and test`가 실제 GitHub runner에서 성공한 후 브랜치 보호의 필수 status check로 지정한다.

GitHub의 무료 표준 `xcode-27` runner와 Xcode 27.0을 사용한다. 이 runner는 현재 public preview다. GitHub 공식 Actions는 검증한 commit SHA로 고정했고, Sparkle 버전은 저장소의 `Package.resolved`로 고정한다.

## 최초 Secrets 등록

[저장소 Actions Secrets](https://github.com/MuchanKim/SnapDMG/settings/secrets/actions)에 아래 6개를 등록한다. 파일이나 키 내용은 저장소, 이슈, PR, 채팅에 붙여 넣지 않는다.

| Secret | 내용 |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | SnapDMG의 Developer ID Application 인증서와 연결된 개인 키를 포함한 `.p12`의 Base64 문자열 |
| `DEVELOPER_ID_P12_PASSWORD` | 해당 `.p12`의 export password |
| `APP_STORE_CONNECT_KEY_P8` | Apple notarization용 App Store Connect **Team API key**의 `.p8` 파일 내용 |
| `APP_STORE_CONNECT_KEY_ID` | 해당 API key의 Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | 해당 Team API key의 Issuer ID |
| `SPARKLE_PRIVATE_KEY` | 기존 `com.moolab.SnapDMG` 계정의 Sparkle Ed25519 개인 키 export 문자열 |

Keychain Access에서 `Developer ID Application: Muchan Kim (F7T7NU8578)` 인증서와 해당 개인 키만 `.p12`로 내보낸다. 다른 키를 함께 export하지 않는다. Apple API key는 App Store Connect의 Users and Access → Integrations에서 준비한다. workflow는 Team API key만 지원한다.

등록은 로그인된 로컬 `gh`에서 파일을 stdin으로 전달할 수 있다. 아래 경로는 실제 로컬 파일 경로로 바꾼다. `.p12` password, Key ID, Issuer ID는 `gh secret set`의 숨김 입력 프롬프트에서 입력한다.

```sh
base64 < /path/to/SnapDMG-Developer-ID.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --repo MuchanKim/SnapDMG
gh secret set DEVELOPER_ID_P12_PASSWORD --repo MuchanKim/SnapDMG
gh secret set APP_STORE_CONNECT_KEY_P8 --repo MuchanKim/SnapDMG < /path/to/AuthKey.p8
gh secret set APP_STORE_CONNECT_KEY_ID --repo MuchanKim/SnapDMG
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo MuchanKim/SnapDMG
```

Sparkle 개인 키는 새로 생성하지 않는다. 기존 키를 제한된 임시 폴더에 export한 뒤 등록한다. export 파일은 등록 완료 후 직접 삭제한다.

```sh
umask 077
sparkle_key_dir=$(mktemp -d)
/path/to/Sparkle/bin/generate_keys --account com.moolab.SnapDMG -x "$sparkle_key_dir/private-key"
gh secret set SPARKLE_PRIVATE_KEY --repo MuchanKim/SnapDMG < "$sparkle_key_dir/private-key"
```

Secrets 등록은 인증서와 개인 키를 GitHub Actions runner에서 사용할 수 있도록 전송하는 작업이다. 배포 시 서명된 앱 ZIP은 Apple notarization 서비스와 공개 GitHub Releases에 전송된다. workflow는 PR 빌드에서 Secrets를 사용하지 않으며, 서명 단계에서만 임시 Keychain과 `.p8`를 만들고 해당 단계가 끝나면 삭제한다.

## 새 버전 배포

1. 작업 브랜치에서 앱의 `MARKETING_VERSION`을 새 버전으로 설정하고 `CURRENT_PROJECT_VERSION`을 이전 배포보다 큰 **양의 정수**로 올린다.
2. PR의 CI 결과를 확인하고 `main`에 merge한다.
3. 해당 커밋에 `v<MARKETING_VERSION>` 태그를 만들고 push한다. 예를 들어 버전 `1.1`, Build `2`는 태그 `v1.1`로 배포한다.

```sh
git switch main
git pull --ff-only
git tag v1.1
git push origin v1.1
```

workflow가 `SnapDMG-1.1.zip`, `appcast.xml`, `SHA256SUMS`를 draft에 업로드한 뒤 게시한다. 기존 draft의 릴리즈 노트가 있으면 그대로 사용하며, 없으면 GitHub에서 릴리즈 노트를 생성한다. 같은 내용은 appcast에 Markdown으로 포함한다.

이미 공개된 같은 버전은 덮어쓰지 않는다. 태그와 앱 버전이 다르거나, 현재 최신 릴리즈보다 Version 또는 Build 번호가 낮거나 같으면 배포를 중단한다. Apple notarization이나 서명 검증 실패 시에도 공개하지 않는다. 실패 후에는 원인을 해결하고 Actions에서 같은 태그를 수동 실행할 수 있다. 소스 수정이 필요하면 새 버전·Build·태그를 사용한다.

최초 `v1.0` draft는 검증된 `main` 커밋에 `v1.0` 태그를 만들고 실행하면 사용할 수 있다. 기존 draft 노트는 유지하고 최종 바이너리와 feed를 workflow가 채운다. Secrets가 없으면 배포되지 않는다.

## 로컬 검증

저장소 루트에서 실행한다. 배포 키나 Apple 계정은 필요하지 않다.

```sh
bash scripts/check.sh /tmp/snapdmg-ci-check
```

CI 성공은 코드 빌드와 단위 테스트 결과다. 최초 실제 배포에서는 Actions의 notarization·서명·게시 결과와 `/Applications`에 설치한 이전 버전의 다운로드·설치·재실행까지 별도로 확인한다.

공식 자료: [GitHub runner 목록](https://github.com/actions/runner-images), [macOS runner 인증서 설정](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [Sparkle 업데이트 게시](https://sparkle-project.org/documentation/publishing/), [Apple notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
