#!/usr/bin/env bash
set -euo pipefail

bash -n Scripts/*.sh
python3 -B -m unittest \
  Scripts/test_validate_project_structure_m2.py \
  Scripts/test_validate_project_structure_m3.py \
  Scripts/test_validate_project_structure_m4.py

M5_HANDOFF="$PWD/.omx/handoff/private-presenter-m5"
M5_MANIFEST_SHA=2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9
M5_EXPECTED_FILES="$(printf '%s\n' MAC-CONTINUATION.md m5-artifacts.sha256 \
  m5-review-red-source-files.sha256 m5-source-files.sha256 \
  private-presenter-m5-review-red-source.tar private-presenter-m5-source.tar \
  private-presenter-m5-wsl.bundle | LC_ALL=C sort)"
test "$(find "$M5_HANDOFF" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)" = \
  "$M5_EXPECTED_FILES"
test "$(sha256sum "$M5_HANDOFF/m5-artifacts.sha256" | awk '{print $1}')" = \
  "$M5_MANIFEST_SHA"
(cd "$M5_HANDOFF" && sha256sum -c m5-artifacts.sha256 && \
  git bundle verify private-presenter-m5-wsl.bundle)

M5_ROOT="$(mktemp -d)"
trap 'git worktree remove --force "$M5_ROOT/tree" 2>/dev/null || true; rm -rf "$M5_ROOT"' EXIT
git worktree add --detach "$M5_ROOT/tree" 1ac13dbbdae1c53eea06033c353d22ab0919e8a5
test "$(git -C "$M5_ROOT/tree" rev-parse HEAD^{tree})" = \
  3d90bcd2c1851b36e0adc774c99a2416da7ba5b8
mkdir -p "$M5_ROOT/tree/.omx/handoff"
cp -a "$M5_HANDOFF" "$M5_ROOT/tree/.omx/handoff/private-presenter-m5"
(cd "$M5_ROOT/tree/.omx/handoff/private-presenter-m5" && \
  test "$(sha256sum m5-artifacts.sha256 | awk '{print $1}')" = "$M5_MANIFEST_SHA" && \
  sha256sum -c m5-artifacts.sha256 && \
  git bundle verify private-presenter-m5-wsl.bundle)
(cd "$M5_ROOT/tree" && test -z "$(git status --porcelain=v1)" && \
  python3 -B Scripts/test_validate_project_structure_m5.py && \
  python3 Scripts/validate_project_structure.py)
git worktree remove --force "$M5_ROOT/tree"
rm -rf "$M5_ROOT"
trap - EXIT

python3 -B Scripts/test_validate_project_structure_m6.py
python3 Scripts/validate_project_structure.py
python3 -B Scripts/generate-m5-fixture.py --self-test
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
echo "Not run here: Swift compilation, Xcode/AppKit/VoiceOver tests, proof build provenance, Instruments, or the physical Keynote/display gate."
git status --short
