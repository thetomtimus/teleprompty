#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 2 structure validator."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_project_structure",
    ROOT / "Scripts/validate_project_structure.py",
)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class Milestone2ValidatorContractTests(unittest.TestCase):
    def test_m2_required_paths_are_enforced(self) -> None:
        required = set(VALIDATOR.M2_REQUIRED_PATHS)
        self.assertIn("PrivatePresenterApp/Text/ScriptTextEdit.swift", required)
        self.assertIn("PrivatePresenterApp/Controller/EditorTextSystem.swift", required)
        self.assertIn("PrivatePresenterApp/Overlay/ReaderTextSystem.swift", required)
        self.assertIn("PrivatePresenterAppTests/ControllerPresentationTests.swift", required)

    def test_m2_named_tests_are_enforced(self) -> None:
        names = set(VALIDATOR.M2_NAMED_TESTS)
        for name in (
            "testEditorReportsEditedRangeAndDelta",
            "testRevisionGapPerformsOneResync",
            "testMapsNSScreenNumberToSessionID",
            "testMirroringWarningUsesRequiredText",
            "testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain",
        ):
            self.assertIn(name, names)

    def test_m2_prohibited_surfaces_are_enforced(self) -> None:
        patterns = set(VALIDATOR.M2_PROHIBITED_PATTERNS)
        for pattern in (
            "NSStatusItem",
            "MenuBarExtra",
            "addGlobalMonitorForEvents",
            "AXIsProcessTrusted",
            ".screenSaver",
            ".layoutManager",
        ):
            self.assertIn(pattern, patterns)

    def test_editor_delegate_uses_sdk_declared_edit_actions_type(self) -> None:
        source = (
            ROOT / "PrivatePresenterApp/Controller/EditorTextSystem.swift"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "didProcessEditing editedMask: NSTextStorageEditActions",
            source,
        )
        self.assertNotIn("NSTextStorage.EditActions", source)
        self.assertIn("@preconcurrency NSTextStorageDelegate", source)

    def test_display_topology_mapping_gives_nil_an_optional_context(self) -> None:
        source = (
            ROOT / "PrivatePresenterApp/Services/SystemDisplayService.swift"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "onlineIDs.compactMap { id -> DisplayDescriptor? in",
            source,
        )

    def test_current_m2_source_satisfies_validator(self) -> None:
        self.assertEqual(VALIDATOR.validate_m2_source(), [])


if __name__ == "__main__":
    unittest.main()
