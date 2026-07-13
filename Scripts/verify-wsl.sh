#!/usr/bin/env bash
set -euo pipefail

bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
git diff --check
test "$(<.xcodegen-version)" = "2.45.4"
git check-ignore -q PrivatePresenter.xcodeproj/project.pbxproj
! git ls-files --error-unmatch PrivatePresenter.xcodeproj/project.pbxproj >/dev/null 2>&1
test -f project.yml
test -f Packages/TeleprompterCore/Package.swift
test -f PrivatePresenterApp/Resources/PrivatePresenter.entitlements
sha256sum -c docs/validation/source-artifact-checksums.sha256
./Scripts/verify-no-network.sh
expected_origin='https://github.com/thetomtimus/teleprompty.git'
test "$(git remote)" = 'origin'
test "$(git remote get-url origin)" = "$expected_origin"
test "$(git remote get-url --push origin)" = "$expected_origin"

echo "WSL-safe source/static verification passed."
echo "The Phase A runner inventory contains exactly 24 unique cells. No cell ran here."
echo "Not run here: Swift compilation, Xcode/AppKit tests, proof build provenance, or the physical Keynote/display gate."
git status --short
