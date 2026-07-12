#!/usr/bin/env bash
set -euo pipefail

readonly REQUIRED_XCODEGEN="$(<.xcodegen-version)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: bootstrap-macos.sh requires macOS." >&2
  exit 1
fi

for tool in xcodebuild swift xcodegen; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    if [[ "$tool" == "xcodegen" ]]; then
      echo "error: XcodeGen ${REQUIRED_XCODEGEN} is required." >&2
      echo "Install the ${REQUIRED_XCODEGEN} binary from https://github.com/yonaskolb/XcodeGen/releases/tag/${REQUIRED_XCODEGEN}, then rerun." >&2
    else
      echo "error: ${tool} is required; install Xcode 16.0 or newer and select it with xcode-select." >&2
    fi
    exit 1
  fi
done

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
swift_version="$(swift --version | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1)"
xcodegen_version="$(xcodegen --version | sed -nE 's/^(Version: )?([0-9]+\.[0-9]+\.[0-9]+).*$/\2/p')"

if [[ "${xcode_version%%.*}" -lt 16 ]]; then
  echo "error: Xcode 16.0 or newer is required; found ${xcode_version}." >&2
  exit 1
fi
if [[ "${swift_version%%.*}" -lt 6 ]]; then
  echo "error: Swift 6.0 or newer is required; found ${swift_version:-unknown}." >&2
  exit 1
fi
if [[ "$xcodegen_version" != "$REQUIRED_XCODEGEN" ]]; then
  echo "error: XcodeGen ${REQUIRED_XCODEGEN} is required; found ${xcodegen_version:-unknown}." >&2
  echo "Install the pinned release from https://github.com/yonaskolb/XcodeGen/releases/tag/${REQUIRED_XCODEGEN}." >&2
  exit 1
fi

xcodegen generate --spec project.yml
echo "Generated ignored PrivatePresenter.xcodeproj with XcodeGen ${REQUIRED_XCODEGEN}."
