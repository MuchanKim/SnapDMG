#!/bin/bash
set -euo pipefail

check_dir=${1:?Usage: check.sh <temporary-build-directory>}
project=SnapDMG/SnapDMG.xcodeproj
mkdir -p "$check_dir"

xcodebuild -version
xcrun swift --version
for script in scripts/*.sh; do bash -n "$script"; done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests

xcodebuild -resolvePackageDependencies -project "$project" -scheme SnapDMG \
  -clonedSourcePackagesDirPath "$check_dir/packages" \
  -onlyUsePackageVersionsFromResolvedFile

xcodebuild -project "$project" -scheme SnapDMG -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$check_dir/derived" \
  -clonedSourcePackagesDirPath "$check_dir/packages" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  -only-testing:SnapDMGTests test CODE_SIGNING_ALLOWED=NO

xcodebuild -project "$project" -scheme SnapDMG -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$check_dir/derived" \
  -clonedSourcePackagesDirPath "$check_dir/packages" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  build CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO
