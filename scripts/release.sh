#!/bin/bash
set -euo pipefail
umask 077

check_dir=${1:?Usage: release.sh <check-directory> <release-directory>}
release_dir=${2:?Usage: release.sh <check-directory> <release-directory>}
for secret_name in DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD \
  APP_STORE_CONNECT_KEY_P8 APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID SPARKLE_PRIVATE_KEY; do
  if [[ -z "${!secret_name:-}" ]]; then
    echo "::error::Missing GitHub Actions secret: $secret_name" >&2
    exit 1
  fi
done

signing_dir=$(mktemp -d "$RUNNER_TEMP/snapdmg-signing.XXXXXX")
keychain_path="$signing_dir/signing.keychain-db"
cleanup() {
  if [[ -f "$keychain_path" ]]; then security delete-keychain "$keychain_path"; fi
  rm -rf "$signing_dir"
}
trap cleanup EXIT
keychain_password=$(openssl rand -hex 32)
printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 --decode > "$signing_dir/certificate.p12"
printf '%s' "$APP_STORE_CONNECT_KEY_P8" > "$signing_dir/notary.p8"
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$signing_dir/certificate.p12" -k "$keychain_path" \
  -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$keychain_password" "$keychain_path" > /dev/null
security list-keychains -d user -s "$keychain_path"

team_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["team"])' "$release_dir/metadata.json")
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$release_dir/metadata.json")
security find-identity -v -p codesigning "$keychain_path" | grep -F "Developer ID Application:" | grep -F "($team_id)"

xcodebuild -project SnapDMG/SnapDMG.xcodeproj -scheme SnapDMG \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$signing_dir/SnapDMG.xcarchive" -derivedDataPath "$check_dir/derived" \
  -clonedSourcePackagesDirPath "$check_dir/packages" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  archive CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application' \
  DEVELOPMENT_TEAM="$team_id" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  OTHER_CODE_SIGN_FLAGS="--keychain $keychain_path"

python3 - "$team_id" "$signing_dir/ExportOptions.plist" <<'PY'
import plistlib, sys
with open(sys.argv[2], "wb") as file:
    plistlib.dump({"method": "developer-id", "destination": "export", "signingStyle": "manual",
                  "signingCertificate": "Developer ID Application", "teamID": sys.argv[1]}, file)
PY
xcodebuild -exportArchive -archivePath "$signing_dir/SnapDMG.xcarchive" \
  -exportPath "$signing_dir/export" -exportOptionsPlist "$signing_dir/ExportOptions.plist"
app="$signing_dir/export/SnapDMG.app"
codesign --verify --deep --strict --verbose=2 "$app"
lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/SnapDMG"

ditto -c -k --sequesterRsrc --keepParent "$app" "$signing_dir/notarization.zip"
if ! xcrun notarytool submit "$signing_dir/notarization.zip" \
  --key "$signing_dir/notary.p8" --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" --wait --timeout 20m \
  --output-format json > "$signing_dir/notarization.json"; then
  cat "$signing_dir/notarization.json" >&2
  exit 1
fi
python3 - "$signing_dir/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result["status"] != "Accepted":
    raise SystemExit(f"Notarization failed: {result['status']} (submission {result['id']})")
print(f"Notarization accepted: {result['id']}")
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"

mkdir -p "$release_dir/assets"
zip_path="$release_dir/assets/SnapDMG-$version.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip_path"
cp "$release_dir/release-notes.md" "$release_dir/assets/SnapDMG-$version.md"
download_prefix="https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG/"
printf '%s' "$SPARKLE_PRIVATE_KEY" | \
  "$check_dir/packages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --ed-key-file - --maximum-deltas 0 --maximum-versions 1 --embed-release-notes \
    --download-url-prefix "$download_prefix" "$release_dir/assets"
python3 scripts/release_metadata.py verify "$RELEASE_TAG" "$release_dir" "$app/Contents/Info.plist"
(cd "$release_dir/assets" && shasum -a 256 "SnapDMG-$version.zip" > SHA256SUMS)
