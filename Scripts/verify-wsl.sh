#!/usr/bin/env bash
set -euo pipefail

bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py
git diff --check
test "$(<.xcodegen-version)" = "2.45.4"
git check-ignore -q PrivatePresenter.xcodeproj/project.pbxproj
! git ls-files --error-unmatch PrivatePresenter.xcodeproj/project.pbxproj >/dev/null 2>&1
test -f project.yml
test -f Packages/TeleprompterCore/Package.swift
test -f PrivatePresenterApp/Resources/PrivatePresenter.entitlements
sha256sum -c docs/validation/source-artifact-checksums.sha256
git diff --exit-code a58afbd -- PRD.md references/teleprompter-ui-reference.png design/concept.html design/teleprompter-concept.png
./Scripts/verify-no-network.sh
test -z "$(git remote)"

echo "WSL-safe source/static verification passed."
echo "Not run here: Swift compilation, Xcode/AppKit tests, or the physical Keynote/display gate."
git status --short
