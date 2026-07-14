#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: verify-macos.sh requires macOS." >&2
  exit 1
fi

./Scripts/bootstrap-macos.sh
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
swift test --package-path Packages/TeleprompterCore
# The UI-test shell is intentionally a skipped placeholder for the separate
# physical Keynote/display gate. Running its unsigned runner cannot bootstrap.
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -skip-testing:PrivatePresenterUITests
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-no-network.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
if git ls-files 'PrivatePresenter.xcodeproj/*' | grep -q .; then
  echo "error: generated Xcode project files must not be tracked." >&2
  exit 1
fi

echo "macOS automated verification passed. The exact-binary Phase B Keynote/display smoke and complete physical gate are still separate and mandatory."
