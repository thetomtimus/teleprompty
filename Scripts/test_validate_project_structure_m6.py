#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 6 evidence-epoch validator."""

from __future__ import annotations

import hashlib
import importlib.util
import inspect
from pathlib import Path
import re
import subprocess
import sys
import unittest
from unittest.mock import patch


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_project_structure", ROOT / "Scripts/validate_project_structure.py"
)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

EXPECTED_PLAN_COMMIT = "3c1aadd9fb50ab6f335580ebd72e6609f2cfa2f0"
EXPECTED_PLAN_PARENT = "1ac13dbbdae1c53eea06033c353d22ab0919e8a5"
EXPECTED_PLAN_PATH = "docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md"
EXPECTED_M5_TREE = "3d90bcd2c1851b36e0adc774c99a2416da7ba5b8"
EXPECTED_M5_MANIFEST_SHA256 = "2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9"

EXPECTED_PROTECTED_PATHS = (
    "HANDOFF.md",
    "IMPLEMENTATION_PLAN.md",
    "PRD.md",
    "design/concept.html",
    "design/teleprompter-concept.png",
    "references/teleprompter-ui-reference.png",
    "docs/plans/2026-07-12-milestone-0-stabilization.md",
    "docs/plans/2026-07-12-milestone-1-core-state-durability.md",
    "docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md",
    "docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md",
    "docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md",
    "docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md",
    EXPECTED_PLAN_PATH,
    "docs/validation/m0-phase-a-causal-decision-2026-07-14.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
    "docs/validation/m2-controller-editor-display-safety-result.md",
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/overlay-proof-result.md",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/performance-result.md",
    "docs/validation/source-artifact-checksums.sha256",
)

EXPECTED_FUTURE_M6_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift",
    "PrivatePresenterAppTests/M6VisualTestSupport.swift",
    "docs/validation/visual-result.md",
    ".omx/handoff/private-presenter-m6/MAC-CONTINUATION.md",
    ".omx/handoff/private-presenter-m6/m6-artifacts.sha256",
    ".omx/handoff/private-presenter-m6/m6-source-files.sha256",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-source.tar",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-wsl.bundle",
)

EXPECTED_M1_REQUIRED_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
    "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift",
)
EXPECTED_M1_NAMED_TESTS = (
    "testReferenceSurfaceUsesExactOpaqueNavyTokens",
    "testRoundedInteriorIsOpaqueOverWhiteAndBlack",
    "testNoTitleBarScrollbarGlowOrCompetingReaderFill",
)
EXPECTED_M1_SOURCE_MARKERS = (
    (
        "named-swiftui-srgb",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "Color(\n                .sRGB,\n                red: Double(red),",
    ),
    (
        "named-appkit-srgb",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)",
    ),
    (
        "opaque-card-top",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 52.0 / 255, green: 70.0 / 255, blue: 111.0 / 255, opacity: 1",
    ),
    (
        "opaque-card-middle",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 44.0 / 255, green: 61.0 / 255, blue: 99.0 / 255, opacity: 1",
    ),
    (
        "opaque-card-bottom",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 32.0 / 255, green: 43.0 / 255, blue: 75.0 / 255, opacity: 1",
    ),
    (
        "reading-text",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 247.0 / 255, green: 248.0 / 255, blue: 252.0 / 255, opacity: 1",
    ),
    (
        "card-radius",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "static let cardRadius: CGFloat = 30",
    ),
    (
        "card-border-width",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "static let cardBorderWidth: CGFloat = 1",
    ),
    (
        "root-gradient",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        "LinearGradient(",
    ),
    (
        "continuous-card",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        "RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)",
    ),
    (
        "inset-card-border",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        ".strokeBorder(",
    ),
    (
        "background-accessibility-id",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        '.accessibilityIdentifier("privatePresenter.readerBackground")',
    ),
    (
        "transparent-appkit-reader",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "backgroundView.layer?.backgroundColor = NSColor.clear.cgColor",
    ),
)

EXPECTED_PENDING_CLAIMS = (
    ("accessibility-status", "docs/validation/m5-accessibility-result.md", "Status: PENDING"),
    ("accessibility-m3", "docs/validation/m5-accessibility-result.md", "M3 native evidence: PENDING"),
    ("accessibility-m4", "docs/validation/m5-accessibility-result.md", "M4 native evidence: PENDING"),
    ("accessibility-voiceover", "docs/validation/m5-accessibility-result.md", "VoiceOver: PENDING"),
    ("lifecycle-status", "docs/validation/m5-display-crash-quit-result.md", "Status: PENDING"),
    ("lifecycle-m3", "docs/validation/m5-display-crash-quit-result.md", "M3 native evidence: PENDING"),
    ("lifecycle-m4", "docs/validation/m5-display-crash-quit-result.md", "M4 native evidence: PENDING"),
    ("lifecycle-appkit", "docs/validation/m5-display-crash-quit-result.md", "AppKit/XCTest: PENDING"),
    ("performance-status", "docs/validation/performance-result.md", "Status: PENDING"),
    ("performance-m3", "docs/validation/performance-result.md", "M3 native evidence: PENDING"),
    ("performance-m4", "docs/validation/performance-result.md", "M4 native evidence: PENDING"),
    ("performance-instruments", "docs/validation/performance-result.md", "Local Instruments trace paths: PENDING"),
)

EXPECTED_M5_HANDOFF_FILES = (
    "MAC-CONTINUATION.md",
    "m5-artifacts.sha256",
    "m5-review-red-source-files.sha256",
    "m5-source-files.sha256",
    "private-presenter-m5-review-red-source.tar",
    "private-presenter-m5-source.tar",
    "private-presenter-m5-wsl.bundle",
)
EXPECTED_M5_MANIFEST_ENTRIES = (
    "MAC-CONTINUATION.md",
    "m5-source-files.sha256",
    "m5-review-red-source-files.sha256",
    "private-presenter-m5-source.tar",
    "private-presenter-m5-review-red-source.tar",
    "private-presenter-m5-wsl.bundle",
)


class Milestone6ValidatorContractTests(unittest.TestCase):
    def assert_m6_constants(self) -> None:
        expected = {
            "M6_PLAN_COMMIT": EXPECTED_PLAN_COMMIT,
            "M6_PLAN_PARENT": EXPECTED_PLAN_PARENT,
            "M6_PLAN_PATH": EXPECTED_PLAN_PATH,
            "M6_M5_SOURCE_TREE": EXPECTED_M5_TREE,
            "M6_M5_HANDOFF_MANIFEST_SHA256": EXPECTED_M5_MANIFEST_SHA256,
            "M6_PROTECTED_PATHS": EXPECTED_PROTECTED_PATHS,
            "M6_PHASE_ZERO_FUTURE_PATHS": EXPECTED_FUTURE_M6_PATHS,
            "M6_PREDECESSOR_PENDING_CLAIMS": EXPECTED_PENDING_CLAIMS,
            "M6_M5_HANDOFF_FILES": EXPECTED_M5_HANDOFF_FILES,
            "M6_M1_REQUIRED_PATHS": EXPECTED_M1_REQUIRED_PATHS,
            "M6_M1_NAMED_TESTS": EXPECTED_M1_NAMED_TESTS,
            "M6_M1_SOURCE_MARKERS": EXPECTED_M1_SOURCE_MARKERS,
        }
        for name, value in expected.items():
            with self.subTest(constant=name):
                self.assertTrue(hasattr(VALIDATOR, name), f"missing {name}")
                actual = getattr(VALIDATOR, name)
                self.assertEqual(tuple(actual) if isinstance(value, tuple) else actual, value)

    def testM5EpochRequiresVerifiedImmutableHandoffBeforeAndAfterCopy(self) -> None:
        handoff = ROOT / ".omx/handoff/private-presenter-m5"
        actual_files = tuple(sorted(path.name for path in handoff.iterdir() if path.is_file()))
        self.assertEqual(actual_files, tuple(sorted(EXPECTED_M5_HANDOFF_FILES)))
        manifest = handoff / "m5-artifacts.sha256"
        self.assertEqual(hashlib.sha256(manifest.read_bytes()).hexdigest(), EXPECTED_M5_MANIFEST_SHA256)
        entries: list[str] = []
        for line in manifest.read_text(encoding="utf-8").splitlines():
            match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n]+)", line)
            self.assertIsNotNone(match, line)
            assert match is not None
            digest, relative = match.groups()
            entries.append(relative)
            self.assertEqual(hashlib.sha256((handoff / relative).read_bytes()).hexdigest(), digest)
        self.assertEqual(tuple(entries), EXPECTED_M5_MANIFEST_ENTRIES)
        bundle = subprocess.run(
            ["git", "bundle", "verify", "private-presenter-m5-wsl.bundle"],
            cwd=handoff,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(bundle.returncode, 0, bundle.stdout + bundle.stderr)

        runner = VALIDATOR.read("Scripts/verify-wsl.sh")
        required = (
            'M5_HANDOFF="$PWD/.omx/handoff/private-presenter-m5"',
            f"M5_MANIFEST_SHA={EXPECTED_M5_MANIFEST_SHA256}",
            'find "$M5_HANDOFF" -maxdepth 1 -type f',
            'sha256sum "$M5_HANDOFF/m5-artifacts.sha256"',
            'cp -a "$M5_HANDOFF" "$M5_ROOT/tree/.omx/handoff/private-presenter-m5"',
            'git worktree add --detach "$M5_ROOT/tree" ' + EXPECTED_PLAN_PARENT,
            EXPECTED_M5_TREE,
            "trap 'git worktree remove --force",
        )
        for marker in required:
            with self.subTest(runner_marker=marker):
                self.assertIn(marker, runner)
        self.assertEqual(runner.count("sha256sum -c m5-artifacts.sha256"), 2)
        self.assertEqual(runner.count("git bundle verify private-presenter-m5-wsl.bundle"), 2)
        start = runner.find('M5_EXPECTED_FILES="$(printf')
        end = runner.find('test "$(find', start)
        self.assertGreaterEqual(start, 0)
        self.assertGreater(end, start)
        for name in EXPECTED_M5_HANDOFF_FILES:
            self.assertEqual(runner[start:end].count(name), 1, name)

    def testVerifyWSLRunsM5OnlyInExactPreparedEpoch(self) -> None:
        runner = VALIDATOR.read("Scripts/verify-wsl.sh")
        m5_test = "python3 -B Scripts/test_validate_project_structure_m5.py"
        m6_test = "python3 -B Scripts/test_validate_project_structure_m6.py"
        epoch_start = runner.find('(cd "$M5_ROOT/tree"')
        epoch_end = runner.find('git worktree remove --force "$M5_ROOT/tree"', epoch_start)
        self.assertEqual(runner.count(m5_test), 1)
        self.assertEqual(runner.count(m6_test), 1)
        self.assertGreaterEqual(epoch_start, 0)
        self.assertGreater(epoch_end, epoch_start)
        self.assertGreater(runner.find(m5_test), epoch_start)
        self.assertLess(runner.find(m5_test), epoch_end)
        self.assertGreater(runner.find(m6_test), epoch_end)
        self.assertEqual(runner.count("python3 Scripts/validate_project_structure.py"), 2)
        for milestone in (2, 3, 4):
            self.assertEqual(runner.count(f"Scripts/test_validate_project_structure_m{milestone}.py"), 1)

        self.assertTrue(hasattr(VALIDATOR, "validate_m6_source"), "missing validate_m6_source() is intended RED")
        self.assertNotIn("validate_m5_source", inspect.getsource(VALIDATOR.validate_m6_source))
        main_source = inspect.getsource(VALIDATOR.main)
        self.assertEqual(main_source.count("validate_m6_source()"), 1)
        self.assertNotIn("validate_m5_source()", main_source)
        self.assertIn("Milestone 6 validation failed", main_source)
        self.assertNotIn("Milestone 5 validation failed", main_source)

    def testPhaseZeroRequiresFutureM6InventoryAbsentAndClaimsPending(self) -> None:
        parent = VALIDATOR.git("rev-parse", f"{EXPECTED_PLAN_COMMIT}^")
        self.assertEqual(parent.returncode, 0, parent.stderr)
        self.assertEqual(parent.stdout.strip(), EXPECTED_PLAN_PARENT)
        paths = VALIDATOR.git("diff-tree", "--no-commit-id", "--name-only", "-r", EXPECTED_PLAN_COMMIT)
        self.assertEqual(paths.returncode, 0, paths.stderr)
        self.assertEqual(paths.stdout.splitlines(), [EXPECTED_PLAN_PATH])
        self.assertEqual(VALIDATOR.git("merge-base", "--is-ancestor", EXPECTED_PLAN_COMMIT, "HEAD").returncode, 0)
        for path in EXPECTED_PROTECTED_PATHS:
            with self.subTest(protected=path):
                committed = subprocess.run(
                    ["git", "show", f"{EXPECTED_PLAN_COMMIT}:{path}"],
                    cwd=ROOT,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
                self.assertEqual(committed.returncode, 0, committed.stderr.decode())
                self.assertEqual(committed.stdout, (ROOT / path).read_bytes())
        for path in EXPECTED_FUTURE_M6_PATHS:
            with self.subTest(future_path=path):
                self.assertFalse((ROOT / path).exists())
        for _, path, marker in EXPECTED_PENDING_CLAIMS:
            with self.subTest(pending_path=path, marker=marker):
                self.assertEqual(VALIDATOR.read(path).splitlines().count(marker), 1)
        self.assert_m6_constants()
        self.assertTrue(hasattr(VALIDATOR, "validate_m6_source"))
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testFinalStageCannotRetainPhaseZeroAbsenceAllowance(self) -> None:
        self.assertTrue(
            hasattr(VALIDATOR, "validate_m6_path_inventory"),
            "phase zero must expose the path-inventory oracle used by final-stage tests",
        )
        final_violations = VALIDATOR.validate_m6_path_inventory(
            required_paths=EXPECTED_FUTURE_M6_PATHS,
            absent_paths=(),
        )
        for path in EXPECTED_FUTURE_M6_PATHS:
            with self.subTest(final_required_path=path):
                self.assertIn(f"missing-path:{path}", final_violations)
        phase_zero = VALIDATOR.validate_m6_path_inventory(
            required_paths=("Scripts/test_validate_project_structure_m6.py",),
            absent_paths=EXPECTED_FUTURE_M6_PATHS,
        )
        self.assertEqual(phase_zero, [])
        source = inspect.getsource(VALIDATOR.validate_m6_path_inventory).lower()
        self.assertNotIn("getenv", source)
        self.assertNotIn("environ", source)
        self.assertNotIn("phase_zero", inspect.signature(VALIDATOR.validate_m6_path_inventory).parameters)

    def testM1OpaqueReferenceSurfaceContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M1_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker in EXPECTED_M1_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), 1, f"{path}:{label}")

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}", 1)
                    return VALIDATOR_READ(candidate)

                VALIDATOR_READ = VALIDATOR.read
                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m1-missing-marker:{label}", violations)

        root = VALIDATOR.read("PrivatePresenterApp/Overlay/OverlayRootView.swift")
        reader = VALIDATOR.read("PrivatePresenterApp/Overlay/ReaderTextView.swift")
        panel = VALIDATOR.read("PrivatePresenterApp/Overlay/TeleprompterPanel.swift")
        self.assertNotIn("Color(red: 0.05, green: 0.06, blue: 0.09)", root)
        self.assertNotIn("red: 0.05,\n            green: 0.06", reader)
        self.assertNotIn(".shadow(", root)
        self.assertIn("hasShadow = true", panel)
        self.assertIn("isOpaque = false", panel)
        self.assertEqual(VALIDATOR.validate_m6_source(), [])


if __name__ == "__main__":
    unittest.main()
