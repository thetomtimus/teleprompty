#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 5 current-source validator."""

from __future__ import annotations

import importlib.util
import inspect
from pathlib import Path
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

EXPECTED_BASELINE = "d7e79ba1623d76a5df07d2b482bae9ea795ea3cb"

EXPECTED_PLANNED_PATHS = (
    "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
    "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
    "PrivatePresenterApp/Services/PerformanceSignposter.swift",
    "PrivatePresenterAppTests/PresenterAccessibilityTests.swift",
    "PrivatePresenterAppTests/PerformanceSignposterTests.swift",
    "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
    "PrivatePresenterUITests/ControllerAccessibilityUITests.swift",
    "PrivatePresenterUITests/M5UITestSupport.swift",
    "Scripts/generate-m5-fixture.py",
    "Scripts/test_validate_project_structure_m5.py",
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/performance-result.md",
)

EXPECTED_ACCESSIBILITY_TESTS = (
    "testAllIconButtonsHaveLabelsAndHelp",
    "testWarningExposesTextNotColorOnly",
    "testControllerKeyboardTraversal",
    "testFontRangeControlsAreReachable",
    "testAccessibilityManifestContainsEveryActionExactlyOnce",
    "testEveryDynamicControlExposesLabelValueHelpAndIdentifier",
    "testControllerReverseTraversalHasNoTrap",
    "testOverlayActionTargetsAreAtLeastFortyFourPoints",
    "testReaderBandAndInteractionZonesAreIgnored",
    "testWarningFocusNeverActivatesBackgroundApplication",
    "testPublicAccessibilitySurfacesNeverContainPrivateSentinels",
    "testReduceMotionChangeRemovesFadeButKeepsReadingMotion",
    "testUITestStoreOverrideRequiresDebugFlagXCTestAndTemporaryDescendant",
    "testUITestStoreOverrideRejectsDotDotTraversal",
    "testUITestStoreOverrideRejectsSymlinkEscape",
    "testUITestStoreOverrideRejectsPrefixOnlySibling",
    "testUITestStoreOverrideRejectsReleaseBuild",
    "testUITestStoreOverrideRejectsMissingXCTestConfiguration",
)

EXPECTED_LIFECYCLE_TESTS = (
    "testCrashRestoreIsPaused",
    "testDisconnectDuringTickPersistsAnchorThenHides",
    "testReconnectRequiresConfirmation",
    "testQuitTearsDownCallbacks",
    "testStaleTopologyResultCannotMoveRevealOrResume",
    "testQueuedDisplayCallbackAfterStopIsIgnored",
    "testReconnectConfirmationMustMatchCurrentGeneration",
    "testDisconnectEnqueuesCapturedAnchorBeforeOrderOutWithoutAwaitingDisk",
    "testCrashRestoreClearsRuntimeDisplayAndNeverShowsOrStarts",
    "testSuccessfulQuitUsesExactLifecycleOrder",
    "testFlushFailureTearsDownNothingAndLeavesRecoveryAvailable",
    "testOverlappingQuitRequestsShareOneAttempt",
    "testRepeatedSuccessfulTeardownIsIdempotent",
    "testQuiescentTickFocusHotKeyAndDisplayCallbacksAreIgnored",
    "testCarbonDispatchClosesBeforeUnregisterAndCleanupStatusDoesNotReopenIt",
    "testRuntimeOwnersDeallocateAfterTeardown",
)

EXPECTED_SIGNPOST_TESTS = (
    "testSignpostIntervalsBalanceForEveryTerminalPath",
    "testSignpostAPIHasNoArbitraryMetadataSurface",
    "testSignpostNamesAndClosedMetadataAreExact",
    "testSignpostPayloadsNeverContainPrivateSentinels",
    "testRestoreIntervalEndsAfterReaderLayoutAndMainActorSentinel",
    "testEditIntervalEndsAfterIncrementalReaderLayout",
    "testDebounceWaitIsOutsidePersistenceIntervals",
    "testSnapshotEncodeWriteAndFlushAreSeparateIntervals",
    "testSignpostRegistryIsEmptyAfterTeardown",
)

EXPECTED_PERFORMANCE_TESTS = (
    "testFiftyThousandWordLoad",
    "testRepeatedEditDoesNotRebuildWholeReader",
    "testDebouncedSaveDoesNotBlockMainActor",
    "testScrollTicksDoNotMutateTextOrPublishPerFrame",
    "testFixtureIsExactlyFiftyThousandWords",
    "testSwiftFixtureMatchesGeneratedBytesAndDigest",
    "testLoadMeasurementEndpointRequiresEditAndMainActorSentinel",
    "testThreeHundredEditSequenceRestoresFixtureAfterEveryPair",
    "testNearestRankP95UsesSampleTwoHundredEightyFive",
    "testEveryEditAndMainThreadStallUsesOneHundredMillisecondCeiling",
    "testScrollMemoryUsesFivePointOrdinaryLeastSquares",
    "testAbsoluteThresholdsRequireExplicitBaselineOptIn",
    "testDelayedFilesystemDoesNotBlockEditAndFinalRevisionFlushes",
)

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
    "docs/validation/m0-phase-a-causal-decision-2026-07-14.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
    "docs/validation/m2-controller-editor-display-safety-result.md",
    "docs/validation/overlay-proof-result.md",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/source-artifact-checksums.sha256",
)

EXPECTED_PENDING_EVIDENCE = (
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/performance-result.md",
)

EXPECTED_PROHIBITED_PATTERNS = (
    "addGlobalMonitorForEvents",
    "addLocalMonitorForEvents",
    "CGEventTap",
    "CGEvent.tapCreate",
    "AXIsProcessTrusted",
    "AXUIElement",
    "NSEvent.pressedMouseButtons",
    "CGEventSource.keyState",
    "NSApp.activate(",
    "makeKeyAndOrderFront(",
    "URLSession",
    "WKWebView",
    "MenuBarExtra",
    "Logger(",
    "os_log(",
    "MetricKit",
    "Sentry",
    "telemetry",
    "analytics",
    "LinearGradient(",
    "#34466F",
    "#202B4B",
    "#F7F8FC",
)


class Milestone5ValidatorContractTests(unittest.TestCase):
    def violations_with(self, replacements: dict[str, str]) -> list[str]:
        original_read = VALIDATOR.read

        def replaced_read(path: str) -> str:
            return replacements[path] if path in replacements else original_read(path)

        with patch.object(VALIDATOR, "read", side_effect=replaced_read):
            return VALIDATOR.validate_m5_source()

    def test_m5_plan_baseline_is_exact(self) -> None:
        self.assertEqual(VALIDATOR.M5_BASELINE, EXPECTED_BASELINE)

    def test_m5_full_planned_path_inventory_is_exact_without_phase_zero_placeholders(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_PLANNED_REQUIRED_PATHS), EXPECTED_PLANNED_PATHS
        )

    def test_m5_accessibility_test_inventory_is_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_ACCESSIBILITY_NAMED_TESTS),
            EXPECTED_ACCESSIBILITY_TESTS,
        )

    def test_m5_lifecycle_test_inventory_is_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_LIFECYCLE_NAMED_TESTS), EXPECTED_LIFECYCLE_TESTS
        )

    def test_m5_signpost_and_performance_test_inventories_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_NAMED_TESTS), EXPECTED_SIGNPOST_TESTS
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_PERFORMANCE_NAMED_TESTS), EXPECTED_PERFORMANCE_TESTS
        )

    def test_m5_protected_and_pending_evidence_inventories_are_exact(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M5_PROTECTED_PATHS), EXPECTED_PROTECTED_PATHS)
        self.assertEqual(
            tuple(VALIDATOR.M5_PENDING_EVIDENCE_PATHS), EXPECTED_PENDING_EVIDENCE
        )

    def test_m5_prohibited_permission_logging_network_and_m6_surfaces_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_PROHIBITED_PATTERNS), EXPECTED_PROHIBITED_PATTERNS
        )

    def test_phase_zero_validator_rejects_scope_privacy_and_metadata_mutations(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        mutation = VALIDATOR.read(path) + """
// LinearGradient( #34466F #202B4B #F7F8FC
// Logger( os_log( URLSession AXIsProcessTrusted CGEventTap
// OSSignposter is restricted to the sole performance signposter boundary.
// performanceSignposter.begin(.readerLayout, metadata: \"SENTINEL_PRIVATE_SCRIPT\")
"""
        violations = self.violations_with({path: mutation})
        for label in (
            "scope:m6-visual-polish",
            "prohibited:Logger(",
            "prohibited:os_log(",
            "prohibited:URLSession",
            "prohibited:AXIsProcessTrusted",
            "prohibited:CGEventTap",
            "signpost:OS-boundary",
            "signpost:arbitrary-metadata",
            "signpost:private-sentinel",
        ):
            self.assertTrue(any(item.startswith(label) for item in violations), label)

    def test_phase_zero_validator_rejects_protected_dependency_schema_and_entitlement_mutations(
        self,
    ) -> None:
        snapshot = (
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
            "PersistedSnapshot.swift"
        )
        replacements = {
            "HANDOFF.md": VALIDATOR.read("HANDOFF.md") + "\nmutation\n",
            "project.yml": VALIDATOR.read("project.yml") + "\n# package: FutureDependency\n",
            snapshot: VALIDATOR.read(snapshot).replace(
                "currentSchemaVersion = 1", "currentSchemaVersion = 2"
            ),
            "PrivatePresenterApp/Resources/PrivatePresenter.entitlements": (
                VALIDATOR.read(
                    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
                )
                + "\ncom.apple.security.network.client\n"
            ),
        }
        violations = self.violations_with(replacements)
        for expected in (
            "protected-byte:HANDOFF.md",
            "dependency:project-yml-changed",
            "schema:persisted-snapshot-version",
            "entitlement:changed",
            "entitlement:non-sandbox-surface",
        ):
            self.assertIn(expected, violations)

    def test_phase_zero_current_source_is_green_and_main_invokes_m5_validator(self) -> None:
        self.assertEqual(VALIDATOR.validate_m5_source(), [])
        self.assertIn("validate_m5_source()", inspect.getsource(VALIDATOR.main))


if __name__ == "__main__":
    unittest.main()
