#!/usr/bin/env python3
"""Validate the committed Milestone 0 project source without third-party modules."""

from __future__ import annotations

import json
import os
from pathlib import Path
import plistlib
import platform
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_PATHS = (
    ".xcodegen-version",
    "project.yml",
    "Config/Shared.xcconfig",
    "Config/Debug.xcconfig",
    "Config/Release.xcconfig",
    "Scripts/bootstrap-macos.sh",
    "Scripts/verify-wsl.sh",
    "Scripts/verify-macos.sh",
    "Scripts/verify-no-network.sh",
    "Packages/TeleprompterCore/Package.swift",
    "PrivatePresenterApp/Info.plist",
    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
    "PrivatePresenterApp/Services/DiagnosticHotKeyService.swift",
    "PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift",
    "PrivatePresenterAppTests/OverlayPanelControllerTests.swift",
    "PrivatePresenterAppTests/AppModelTests.swift",
    "PrivatePresenterUITests/PrivatePresenterUITestShell.swift",
    "docs/validation/source-artifact-checksums.sha256",
    "docs/validation/overlay-proof-template.md",
)

PROJECT_MARKERS = (
    "minimumXcodeGenVersion: 2.45.4",
    'macOS: "14.0"',
    'SWIFT_VERSION: "6.0"',
    "PrivatePresenter:",
    "PrivatePresenterAppTests:",
    "PrivatePresenterUITests:",
    "com.privatepresenter.teleprompter",
    "PRODUCT_MODULE_NAME: PrivatePresenter",
    "Carbon.framework",
    "Packages/TeleprompterCore",
    "TeleprompterCore:",
    "shared: true",
)

APP_SOURCE_MARKERS = (
    "PRIVATE_PRESENTER_PROOF_LEVEL",
    "PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME",
    "DisplayTopologyEvaluator()",
    "refreshDisplayInventory",
    "RegisterEventHotKey",
    "Control-Option-H",
    "constrainFrameRect",
    "case top, bottom, left, right",
    "case topLeft, topRight, bottomLeft, bottomRight",
    "WorkspaceFocusProbe.capture",
)

NAMED_TESTS = (
    "testMirroredSelectionBlocksOpening",
    "testMirrorSourceStillBlocksOpening",
    "testNoBuiltInRequiresSelection",
    "testAmbiguousFingerprintRequiresConfirmation",
    "testRemovedSelectionReturnsHiddenPausedRecovery",
    "testEvaluatorNeverAutoSelectsExternalDisplay",
    "testDefaultFrameIsTopCenteredSeventyByThirtyFivePercent",
    "testNormalizedFrameRestoresOnSameFingerprint",
    "testEveryIntermediateDragFrameStaysContained",
    "testResizeCannotCrossAdjacentScreen",
    "testNegativeAndVerticalLayoutsStayContained",
    "testResolutionChangeReclamps",
    "testPanelIsBorderlessNonactivatingAndNotNativelyResizable",
    "testCustomResizeHandlesApplyOnlyContainedFrames",
    "testPanelJoinsAllSpacesAsFullScreenAuxiliary",
    "testPanelUsesBoundedLevel",
    "testLockedPanelIgnoresMouseAndCannotBecomeKeyOrMain",
    "testUnlockedPanelRestoresInteraction",
    "testShowDoesNotActivateApplication",
    "testReadingSurfaceInteriorIsOpaque",
    "testControllerCreatesExactlyOnePanel",
    "testNoIntermediateSetFrameIsUnsafe",
    "testTopologyEffectsPauseHideShieldBeforeQuery",
    "testControllerStartsShielded",
    "testControllerNeverReopensUnredactedOnExternalScreen",
    "testMissingDisplayStagesBuiltInHidden",
    "testRecoveryRequiresConfirmationAndNeverAutoResumes",
)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=ROOT, check=False, text=True, capture_output=True
    )


def validate_plists() -> None:
    info_path = ROOT / "PrivatePresenterApp/Info.plist"
    entitlement_path = ROOT / "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    with entitlement_path.open("rb") as stream:
        entitlements = plistlib.load(stream)
    if info.get("CFBundleDisplayName") != "Private Presenter":
        fail("Info.plist must set CFBundleDisplayName to Private Presenter")
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        fail("App Sandbox must be enabled")
    prohibited = {
        "com.apple.security.network.client",
        "com.apple.security.network.server",
        "com.apple.security.automation.apple-events",
    }
    present = prohibited.intersection(entitlements)
    if present:
        fail(f"prohibited entitlements present: {sorted(present)}")


def validate_xcode_listing() -> None:
    if platform.system() != "Darwin" or not (ROOT / "PrivatePresenter.xcodeproj").exists():
        return
    result = subprocess.run(
        [
            "xcodebuild",
            "-list",
            "-json",
            "-project",
            "PrivatePresenter.xcodeproj",
        ],
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        fail(f"xcodebuild -list failed: {result.stderr.strip()}")
    listing = json.loads(result.stdout).get("project", {})
    expected_targets = {"PrivatePresenter", "PrivatePresenterAppTests", "PrivatePresenterUITests"}
    if not expected_targets.issubset(set(listing.get("targets", []))):
        fail("generated project is missing required targets")
    if "PrivatePresenter" not in listing.get("schemes", []):
        fail("generated project is missing shared PrivatePresenter scheme")


def main() -> None:
    missing = [path for path in REQUIRED_PATHS if not (ROOT / path).is_file()]
    if missing:
        fail("missing required paths: " + ", ".join(missing))
    if read(".xcodegen-version").strip() != "2.45.4":
        fail(".xcodegen-version must contain exactly 2.45.4")
    project = read("project.yml")
    absent_markers = [marker for marker in PROJECT_MARKERS if marker not in project]
    if absent_markers:
        fail("project.yml is missing markers: " + ", ".join(absent_markers))
    if "/PrivatePresenter.xcodeproj/" not in read(".gitignore"):
        fail("generated PrivatePresenter.xcodeproj must be ignored")
    ignored = git("check-ignore", "-q", "PrivatePresenter.xcodeproj/project.pbxproj")
    if ignored.returncode != 0:
        fail("generated project path is not ignored by Git")
    tracked = git("ls-files", "PrivatePresenter.xcodeproj")
    if tracked.stdout.strip():
        fail("generated project files must not be tracked")
    validate_plists()
    swift_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for root in (ROOT / "Packages", ROOT / "PrivatePresenterAppTests")
        for path in root.rglob("*.swift")
    )
    missing_tests = [name for name in NAMED_TESTS if name not in swift_sources]
    if missing_tests:
        fail("missing required named tests: " + ", ".join(missing_tests))
    core_imports = [
        line.strip()
        for path in (ROOT / "Packages/TeleprompterCore/Sources").rglob("*.swift")
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith("import ") and line.strip() != "import Foundation"
    ]
    if core_imports:
        fail("TeleprompterCore must import Foundation only: " + ", ".join(sorted(set(core_imports))))
    app_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "PrivatePresenterApp").rglob("*.swift")
    )
    missing_app_markers = [marker for marker in APP_SOURCE_MARKERS if marker not in app_sources]
    if missing_app_markers:
        fail("M0 proof harness is missing markers: " + ", ".join(missing_app_markers))
    validate_xcode_listing()
    print("Project structure validation passed (Milestone 0 source).")


if __name__ == "__main__":
    main()
