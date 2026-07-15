#!/usr/bin/env python3
"""Validate the committed Milestone 0 stabilization source without third-party modules."""

from __future__ import annotations

import json
import os
from pathlib import Path
import plistlib
import platform
import re
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
    "Scripts/verify-m0-proof-provenance.sh",
    "Scripts/test-verify-m0-proof-provenance.sh",
    "Scripts/run-m0-phase-a-diagnosis.sh",
    "Packages/TeleprompterCore/Package.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ReadingAnchor.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/TeleprompterPreferences.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/OverlaySession.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/KeyboardShortcut.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/SnapshotMigrator.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/SnapshotMigratorTests.swift",
    "PrivatePresenterApp/Info.plist",
    "PrivatePresenterApp/App/AppCommand.swift",
    "PrivatePresenterApp/App/AppEffect.swift",
    "PrivatePresenterApp/App/AppModel.swift",
    "PrivatePresenterApp/App/DependencyContainer.swift",
    "PrivatePresenterApp/Interfaces/SnapshotFileSystem.swift",
    "PrivatePresenterApp/Interfaces/SnapshotScheduling.swift",
    "PrivatePresenterApp/Services/SnapshotStore.swift",
    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
    "PrivatePresenterApp/Services/DiagnosticHotKeyService.swift",
    "PrivatePresenterApp/Services/DiagnosticEvidenceRecorder.swift",
    "PrivatePresenterApp/Services/DiagnosticObserverSet.swift",
    "PrivatePresenterApp/Services/SystemDisplayService.swift",
    "PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift",
    "PrivatePresenterAppTests/OverlayPanelControllerTests.swift",
    "PrivatePresenterAppTests/AppModelTests.swift",
    "PrivatePresenterAppTests/SnapshotStoreTests.swift",
    "PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests.swift",
    "PrivatePresenterAppTests/DiagnosticHotKeyServiceTests.swift",
    "PrivatePresenterAppTests/DiagnosticObserverLifecycleTests.swift",
    "PrivatePresenterAppTests/SystemDisplayServiceTests.swift",
    "PrivatePresenterUITests/PrivatePresenterUITestShell.swift",
    "docs/validation/source-artifact-checksums.sha256",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
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
    "Control-Option-L",
    "CGGetOnlineDisplayList",
    "isDrawableDestination",
    "constrainFrameRect",
    "case top, bottom, left, right",
    "case topLeft, topRight, bottomLeft, bottomRight",
    "WorkspaceFocusProbe.capture",
    "PRIVATE_PRESENTER_ORDERING",
    "PRIVATE_PRESENTER_CONTROLLER_COHORT",
    "PRIVATE_PRESENTER_REPETITION",
    "PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256",
    "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256",
    "PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST",
    "configurationBound",
    "sessionCompletion",
    "EVIDENCE_QUEUE_OVERFLOW",
    "HOT_KEY_REGISTRATION_FAILED",
    "applyContainedFrame",
    "selectedFullFrame",
    "selectedVisibleFrame",
    "containmentFrame",
    "appliedFrame",
    "OverlayPanelOrderingMode",
    "NSApplication.willBecomeActiveNotification",
    "NSWorkspace.didActivateApplicationNotification",
)

PHASE_A_NAMED_TESTS = (
    "testStabilizationRetainsV1CanonicalSnapshotAfterDiagnosticLockChange",
    "testStabilizationRestoreRemainsHiddenPausedUntilPrivacyConfirmation",
    "testStabilizationStartupRestoresBeforeTopologyAndRegistersControlsLast",
    "testStabilizationRuntimeStillConstructsExactlyOneAppModel",
    "testStabilizationServicesShareTheRuntimeModelIdentity",
    "testDiagnosticStateNeverEntersPersistedSnapshot",
    "testEvidenceEnvelopeCarriesSessionCorrelationSourceTimeSequenceAndFixedKind",
    "testCarbonReceiptIsStampedBeforeMainDispatchForSameCorrelation",
    "testCorrelatedEventsRetainStrictRecorderOrderAcrossDelayedSamples",
    "testEvidenceUsesLocalApplicationSupportValidationDirectory",
    "testEvidenceAppendDoesNotEraseEarlierEvents",
    "testEvidenceWriterNeverPerformsFileIOOnHotKeyOrMainCriticalPath",
    "testEvidenceAndFixedErrorsNeverContainScriptTitleContextOrRawEnvironment",
    "testRecorderFailureDoesNotBlockPrivacyOrHotKeyDispatch",
    "testRecorderFailurePermanentlyInvalidatesCellWhileActionsContinue",
    "testSessionCompletionRequiresResolvedPathExistingFileAndSuccessfulFlush",
    "testEvidenceHeaderBindsFullCommitLevelAndOrdering",
    "testQueueSaturationAtomicallyInvalidatesCellWithoutDelayingHotKeyOrPrivacy",
    "testQueueOverflowEmitsFixedFaultWhenCapacityReturns",
    "testQueueOverflowCannotBecomeValidAfterSuccessfulFlush",
    "testBoundedIngressRejectsNewestEnvelopeAtCapacityWithoutWaiting",
    "testQueueOverflowInvalidationDoesNotRequireFaultEnvelopeCapacity",
    "testOverflowFaultIsEmittedOnceAfterWriterCapacityReturns",
    "testHotKeyDispatchContinuesWhileEvidenceQueueIsSaturated",
    "testPrivacyDirectivesContinueInOrderWhileEvidenceQueueIsSaturated",
    "testOverflowAndLaterSinkFailurePreserveFirstPermanentInvalidation",
    "testConfigurationBoundIncludesControllerCohortAndRepetition",
    "testOnlyRepetitionsOneThroughThreeAreAccepted",
    "testInvalidRepetitionUsesFixedCodeWithoutEchoingInput",
    "testConfigurationBoundIncludesExecutableSHA256AndBuildLogPathAndHash",
    "testExecutableHashRequiresSixtyFourLowercaseHexCharacters",
    "testInvalidExecutableHashUsesFixedCodeWithoutEchoingInput",
    "testInvalidBuildLogHashUsesFixedCodeWithoutEchoingInput",
    "testEvidenceWritesOnlyToSiblingPendingPathBeforeCompletion",
    "testSessionCompletionIsLastSerializedEventBeforeSynchronization",
    "testSynchronizationAndClosePrecedeAtomicFinalRename",
    "testFinalPathAppearsOnlyAfterAtomicRename",
    "testSynchronizationFailureNeverPublishesFinalEvidenceFile",
    "testCloseFailureNeverPublishesFinalEvidenceFile",
    "testAtomicRenameFailureNeverPublishesAcceptedFinalFile",
    "testPendingFileIsNeverAcceptedAsProof",
    "testFinalizationFailurePermanentlyInvalidatesCell",
    "testControlOptionHRetainsVisibilityAction",
    "testObserversInstallBeforeVisibilityHotKeyAndTearDownAfterUnregistration",
    "testNoEventsAreAcceptedAfterObserverTeardown",
    "testApplicationObserversCaptureWillAndDidBecomeActive",
    "testApplicationObserversCaptureWillAndDidResignActive",
    "testWorkspaceObserverCapturesDidActivateApplication",
    "testWindowObserversRetainTransientKeyMainOrderAndOcclusionNotifications",
    "testFocusSnapshotsUseImmediateNextRunLoop100msAnd500msSchedule",
    "testDelayedSamplesAreCancelledAfterSessionTeardown",
    "testControllerPlacementRecordsEntryAndExitWithoutPresentation",
    "testStartupPresentationRecordsFrameShowWindowAndPresentationCount",
    "testPhaseAControllerObserverRecordsVisibilityOrderKeyMainAndOcclusion",
    "testPhaseAInstrumentationDoesNotChangeControllerFrameVisibilityOrShowCount",
    "testColdShowTraceSupportsControllerVisibleAndOrderedOutStates",
    "testEvidenceDistinguishesVisibleDesktopSpaceAndOrderedOutCohorts",
    "testObservedVisibleControllerMatchesVisibleDesktopSpaceCohort",
    "testObservedOrderedOutControllerMatchesOrderedOutCohort",
    "testMissingControllerWindowCausesCohortMismatch",
    "testControllerCohortMismatchPermanentlyInvalidatesCellBeforeFirstHotKey",
    "testObservedCohortValidationNeverPresentsOrOrdersController",
    "testConfigurationBoundPrecedesCorrelatedCarbonReceipt",
    "testNormalQuitWaitsForAllCorrelatedSamplesBeforeCompletion",
    "testPostCorrelationQuitActivationIsTaggedAndExcludedFromFocusVerdict",
    "testUncorrelatedActivationWithoutTerminationStillFailsFocusVerdict",
    "testOrderedOutCohortQuitDoesNotPresentOrOrderController",
    "testOrderingModesAreExactlyFrontAndFrontRegardless",
    "testBothOrderingModesAvoidKeyMainAndExplicitActivation",
    "testDefaultProofLevelUsesLowestPhysicallyPassingStatusBarEvidence",
    "testDefaultOrderingRetainsFrontRegardlessAfterPhysicalEvidence",
    "testOrderingSelectionChoosesOnlyPassingMode",
    "testOrderingSelectionRetainsCurrentSourceDefaultWhenBothModesAreEquivalent",
    "testOrderingSelectionUsesSafetyVectorBeforeDefaultTieBreak",
    "testOrderingSelectionRejectsLevelWhenNeitherModePasses",
    "testLevelSelectionPrefersFloatingOnlyAfterCompletePassingOrdering",
    "testConfigurationSnapshotExportsCommitOrderingAndLevel",
    "testActivationPolicyIsSetOnlyAtBootstrap",
    "testForbiddenWindowLevelsAndFocusWorkaroundsAreAbsent",
)

PHASE_B_NAMED_TESTS = (
    "testControlOptionLDispatchesDistinctLockAction",
    "testCarbonIdentifiersDecodeToDistinctActions",
    "testRegistrationFailureCleansUpBothHotKeys",
    "testSuccessfulTerminationUnregistersBothDiagnosticChords",
    "testBothRegistrationFailuresInvalidatePhysicalPrecondition",
    "testBothHotKeyActionsPropagateCorrelationID",
    "testEvidenceExportsSelectedAndAppliedFramesSeparately",
    "testPrivacyDirectiveEffectAndApplicationOrderShareCorrelation",
    "testRuntimeInventoryRequiresDrawableDestinationsAndTopology",
    "testCGOnlyTopologyMemberHasNoVisibleFrameScaleOrDestinationEligibility",
    "testOnlineMirroredSinkMissingFromDrawableScreensStillBlocks",
    "testOnlineDisplayQueryFailureFailsClosed",
    "testOnlineDisplayCountRaceFailsClosed",
    "testVerifiedMirroringRequiresHardwareMirrorFacts",
    "testCGOnlyDisplayCannotBecomeSelectedDestination",
    "testPanelConstrainFrameIsASecondContainmentDefense",
    "testWiredDragAndResizeUpdatesRemainContained",
    "testEveryAppliedFrameIsRecordedExactlyOnce",
    "testRecordedFrameIncludesSeparateSelectedFullVisibleAndContainmentFrames",
    "testLockRestoresClickThroughWithoutChangingFrame",
    "testSecondContainmentDefenseRejectsCrossDisplayFrame",
    "testDragAndResizeNeverPresentNormalController",
    "testPlacementPreservesVisibleControllerState",
    "testPlacementPreservesOrderedOutControllerState",
    "testMirroringWhileVisibleHidesAndShieldsBeforeRecovery",
    "testSelectedPrivateDisplayDisconnectHidesBeforeRecovery",
    "testControllerRemainsShieldedAfterReconnectUntilConfirmation",
    "testPendingShowCannotSurviveTopologyChange",
    "testNonDrawableOnlineMirrorStillUsesExactWarningAndCannotBeBypassed",
    "testTopologyPlacementNeverPresentsNormalController",
    "testHLockTopologyDragAndResizeNeverOrderControllerOnScreen",
    "testDefaultProofLevelUsesLowestPhysicallyPassingStatusBarEvidence",
    "testLevelSelectionRetainsFloatingBeforeComparingStatusBarSafety",
)

PROVENANCE_FIXTURE_TESTS = (
    "testProvenanceVerifierAcceptsMatchingCleanManifest",
    "testProvenanceVerifierRejectsExecutableHashMismatch",
    "testProvenanceVerifierRejectsBuildLogHashMismatch",
    "testProvenanceVerifierRejectsCommitMismatch",
    "testProvenanceVerifierRejectsMissingBuildLog",
    "testProvenanceVerifierRejectsDirtyTree",
    "testProvenanceVerifierRejectsDebugDylibIndirection",
    "testSameExecutableHashIsRequiredAcrossSmokeAndPhysicalEvidence",
    "testProvenanceVerifierRejectsWrongBuildLogCommit",
    "testProvenanceVerifierRejectsMissingOrDuplicateBuildLogCleanStatus",
    "testProvenanceVerifierRejectsIncompleteCorrelation",
    "testProvenanceVerifierRejectsDuplicateCorrelationEvent",
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
    "testUnlockedPanelRestoresInteractionWithoutAcceptingKey",
    "testShowDoesNotActivateApplication",
    "testReadingSurfaceInteriorIsOpaque",
    "testControllerCreatesExactlyOnePanel",
    "testNoIntermediateSetFrameIsUnsafe",
    "testTopologyEffectsPauseHideShieldBeforeQuery",
    "testControllerStartsShielded",
    "testControllerNeverReopensUnredactedOnExternalScreen",
    "testMissingDisplayStagesBuiltInHidden",
    "testRecoveryRequiresConfirmationAndNeverAutoResumes",
    "testDefaultTitleAndPreferencesMatchPRD",
    "testFontRangeClampsTo24Through96",
    "testSpeedRangeClampsTo10Through240",
    "testDefaultShortcutMapMatchesPRD",
    "testReadingAnchorClampsWithoutSplittingUnicode",
    "testCodableRoundTripPreservesUnicodeScript",
    "testPersistedSnapshotExcludesPlayingState",
    "testPersistedSnapshotExcludesRuntimeDisplayID",
    "testCanonicalEncodingIsByteEqualForPermutedInput",
    "testDuplicateFrameAndShortcutEntriesAreRejected",
    "testUnknownShortcutModifierIsMalformed",
    "testSnapshotAndDocumentSchemaMustAgree",
    "testCoreProductionSourcesImportFoundationOnly",
    "testV1MigratesIdempotently",
    "testV1MigrationPreservesUnicodeAndRevision",
    "testUnknownFutureSchemaFailsWithoutDataLoss",
    "testUnsupportedLegacySchemaDoesNotGuess",
    "testRestoreAlwaysReturnsPaused",
    "testRestoreRequiresFreshPrivacyAssessmentBeforeShow",
    "testMalformedSnapshotIsReported",
    "testMigrationErrorsNeverContainScriptContent",
    "testProductionURLUsesSandboxApplicationSupportSubdirectory",
    "testSaveAtomicallyReplacesSnapshot",
    "testFailedReplacePreservesLastKnownGoodSnapshot",
    "testDebounceCoalescesRapidEdits",
    "testStaleRevisionCannotOverwriteNewerPendingSnapshot",
    "testEqualRevisionWithDifferentPayloadIsConflict",
    "testFlushPersistsLatestRevision",
    "testFlushCancelsPendingDebounceWithoutDuplicateWrite",
    "testSaveArrivingAroundFlushCannotLetStaleWriteWin",
    "testMalformedFileIsQuarantined",
    "testQuarantineFailurePreservesSourceAndBlocksWrites",
    "testFutureSchemaIsPreservedInPlace",
    "testFutureSchemaBlocksSubsequentSaveAndFlushWithoutChangingBytes",
    "testQuarantineCollisionDoesNotDeleteEvidence",
    "testFailedWriteRetainsPendingSnapshotAndPersistedRevision",
    "testScriptIsNeverWrittenToUserDefaults",
    "testDiagnosticsAndErrorsDoNotContainScriptContent",
    "testCommandsChangeStateBeforeEffects",
    "testEmptyScriptCannotStart",
    "testWhitespaceOnlyScriptCannotStart",
    "testRestartPausesAtBeginning",
    "testRelaunchReassessesPrivacyBeforeShow",
    "testAppRuntimeRestoreAndPrivacyOrderingBlocksEarlyShow",
    "testRestoreClearsCurrentSessionDisplayIdentity",
    "testClearRequiresConfirmedCommand",
    "testClearWaitsForSuccessfulPreClearFlush",
    "testFailedPreClearFlushPreservesScript",
    "testInterveningEditInvalidatesPendingClear",
    "testStaleClearCompletionCannotEraseScript",
    "testPostClearSnapshotPersistsImmediatelyWithoutDebounce",
    "testConfirmedClearIncrementsRevisionsAndPersistsEmptySnapshot",
    "testRuntimeAndControllerShareOneAuthoritativeModel",
    "testAppRuntimeConstructsExactlyOneAppModel",
)

DATA_SAFETY_PATTERNS = (
    r"\bUserDefaults\b",
    r"\bprint\s*\(",
    r"\bLogger\s*\(",
    r"\bos_log\s*\(",
    r"\bUNUserNotificationCenter\b",
    r"\bNSUserNotification\b",
)

M2_REQUIRED_PATHS = (
    "PrivatePresenterApp/Text/ScriptTextEdit.swift",
    "PrivatePresenterApp/Controller/EditorTextSystem.swift",
    "PrivatePresenterApp/Controller/ScriptEditorTextView.swift",
    "PrivatePresenterApp/Controller/ControllerPresentation.swift",
    "PrivatePresenterApp/Controller/DebugDiagnosticsView.swift",
    "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    "PrivatePresenterApp/Overlay/ReaderTextView.swift",
    "PrivatePresenterAppTests/EditorTextSystemTests.swift",
    "PrivatePresenterAppTests/ReaderTextSystemTests.swift",
    "PrivatePresenterAppTests/ControllerPresentationTests.swift",
)

M2_NAMED_TESTS = (
    "testEditorReportsEditedRangeAndDelta",
    "testScriptTextEditValidatesBaseAndResultRevision",
    "testScriptTextEditIsSendableAcrossActorBoundary",
    "testUTF16EmojiEditBoundaries",
    "testCombiningCharacterEditUsesUTF16DeltaWithoutCorruption",
    "testProgrammaticEditorSyncDoesNotEmitUserEdit",
    "testEditorCallbackIsMainActorIsolated",
    "testEditorUsesTextKit2WithoutLegacyLayoutManager",
    "testStaleOrOutOfOrderEditCannotOverwriteAuthority",
    "testAcceptedEditMutatesStateBeforeReaderAndSnapshotEffects",
    "testIncrementalEditDoesNotReplaceReaderStorage",
    "testRevisionGapPerformsOneResync",
    "testMultipleUpdatesDuringGapRequestOnlyOneResync",
    "testDuplicateAndStaleReaderUpdatesAreIgnored",
    "testContiguousInvalidRangePerformsOneAuthoritativeResync",
    "testStorageLengthDivergencePerformsOneAuthoritativeResync",
    "testResyncToLatestRevisionRestoresIncrementalDelivery",
    "testInitialRestoreClearAndLatchedGapOrApplicationFailureAreOnlyFullReplacementReasons",
    "testReaderResyncCallbackIsMainActorIsolated",
    "testReaderUsesTextKit2WithoutLegacyLayoutManager",
    "testFontAndAlignmentUpdatesDoNotMutateReaderText",
    "testActiveBandToggleDoesNotMutateReaderText",
    "testEmptyInstructionAndDisabledStart",
    "testClearPresentsConfirmation",
    "testWhitespaceOnlyScriptUsesEmptyInstruction",
    "testNonemptyM2ScriptStillExplainsScrollingIsM3",
    "testM2StartPauseRestartDoNotDispatchPlaybackCommands",
    "testM2FocusModeExplainsM4AndDoesNotChangeChrome",
    "testProductControllerExposesOpenCloseAndHideShowThroughOnePanelState",
    "testTitleTrimsDefaultsAndCapsWithoutSplittingCharacter",
    "testFontSizeAlignmentAndActiveBandPersistThroughV1Snapshot",
    "testAcceptedEditSchedulesAutosaveAfterAuthoritativeMutation",
    "testRapidEditsDebounceToLatestSnapshot",
    "testAutosaveDoesNotBlockMainActorEffectDispatch",
    "testAutosaveDiagnosticsExcludeScriptTitleAndReplacementText",
    "testMapsNSScreenNumberToSessionID",
    "testBuildsFingerprintFromUUIDAndHardware",
    "testDuplicateZeroSerialDisplaysAreAmbiguous",
    "testRawDisplayIDIsNotEncoded",
    "testQueryFailureIsUnsafe",
    "testMissingOrWrongTypedNSScreenNumberFailsClosed",
    "testDuplicateDrawableSessionIDsFailClosed",
    "testDuplicateOnlineSessionIDsFailClosed",
    "testZeroSessionIDFailsClosed",
    "testZeroVendorModelAndSerialAreNotStrongIdentity",
    "testLocalizedNameDoesNotOverrideHardwareConflict",
    "testAmbiguousFingerprintCannotRestoreAcrossSessionWithoutConfirmation",
    "testExplicitCurrentSessionChoiceDoesNotEnterEncodedSnapshot",
    "testMirroringWarningUsesRequiredText",
    "testShieldPrecedesWarningAndReposition",
    "testSelectedDisplayNameIsVisible",
    "testAmbiguityRequiresExplicitConfirmation",
    "testMenuNeverContainsPrivateTitle",
    "testRecoveryNeverResumesAutomatically",
    "testPerDisplayFramesRemainSeparate",
    "testExactMirroringWarningIsSeparateFromRecoveryGuidance",
    "testSelectedNameIsHiddenUntilCurrentSessionConfirmation",
    "testTopologyStatusDistinguishesExtendedMirroredSingleMissingAmbiguousAndQueryFailure",
    "testAmbiguousWeakDisplayFrameIsNotAutoRestoredOrPersisted",
    "testRestoredNormalizedFrameReclampsToCurrentContainment",
    "testFrameCallbackPersistsOnlyCurrentConfirmedDisplayFingerprint",
    "testDisplayLossPausesHidesShieldsBeforeFallbackPlacement",
    "testReconnectRemainsHiddenPausedUntilExplicitConfirmation",
    "testPendingShowCannotSurviveTopologyChange",
    "testWindowMenuDiagnosticAndAccessibilityLabelsExcludeSentinelPrivateContent",
    "testM2PreservesOnePanelAndOneAppModel",
    "testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain",
    "testM2PreservesDiagnosticHAndLDirectDispatchWithoutControllerRaise",
    "testM2PreservesEveryDragAndResizeFrameWithinSelectedDisplay",
    "testM2PreservesOpaqueRoundedReaderSurface",
)

M2_PROHIBITED_PATTERNS = (
    "NSStatusItem",
    "MenuBarExtra",
    "addGlobalMonitorForEvents",
    "CGEventTap",
    "AXIsProcessTrusted",
    "WKWebView",
    "URLSession",
    ".screenSaver",
    ".layoutManager",
)


M3_REQUIRED_PATHS = (
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollCommand.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollEngine.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ReadingPositionMapper.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ScrollEngineTests.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ReadingPositionMapperTests.swift",
    "PrivatePresenterApp/Interfaces/ReaderViewport.swift",
    "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift",
    "PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift",
    "PrivatePresenterApp/Overlay/ScrollSessionController.swift",
    "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
    "PrivatePresenterApp/App/AppCommand.swift",
    "PrivatePresenterApp/App/AppEffect.swift",
    "PrivatePresenterApp/App/AppModel.swift",
    "PrivatePresenterApp/App/DependencyContainer.swift",
    "PrivatePresenterApp/App/AppRuntime.swift",
    "PrivatePresenterApp/Controller/ControllerPresentation.swift",
    "PrivatePresenterApp/Controller/ControllerView.swift",
    "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    "PrivatePresenterApp/Overlay/ReaderTextView.swift",
    "PrivatePresenterApp/Overlay/OverlayRootView.swift",
    "PrivatePresenterApp/Overlay/OverlayPanelController.swift",
    "PrivatePresenterAppTests/AppModelTests.swift",
    "PrivatePresenterAppTests/ControllerPresentationTests.swift",
    "PrivatePresenterAppTests/ReaderTextSystemTests.swift",
    "PrivatePresenterAppTests/OverlayPanelControllerTests.swift",
    "Scripts/test_validate_project_structure_m3.py",
    "Scripts/validate_project_structure.py",
)

M3_CANONICAL_NAMED_TESTS = (
    "testElapsedTimeNotFrameCountControlsOffset",
    "testSixtyAndOneTwentyHertzMatch",
    "testPausePreservesExactOffset",
    "testSpeedChangeDoesNotJump",
    "testEndClampsAndPauses",
    "testRestartReturnsZeroAndPauses",
    "testForwardBackwardClamp",
    "testSuspensionDoesNotJump",
    "testInsertionBeforeAnchorShiftsOffset",
    "testDeletionBeforeAnchorShiftsOffset",
    "testEditAfterAnchorDoesNotMove",
    "testOverlapClampsAndRequestsPause",
    "testEmojiOffsetsAreUTF16Safe",
    "testLayoutChangeRestoresViewportFraction",
    "testReaderHidesScrollerAndClips",
    "testMaximumOffsetAccountsForToolbarInset",
    "testBandDoesNotBecomeTextSelection",
    "testRestorePlacesAnchorAtBand",
    "testScrollTickPerformsNoTextMutation",
    "testFakeTicksDriveViewport",
    "testPauseStopsClock",
    "testHiddenPanelStopsClock",
    "testStaleGenerationCallbackIsIgnored",
    "testTickDoesNotPublishSwiftUIStatePerFrame",
    "testEndPublishesOnePausedTransition",
)

M3_ADDED_NAMED_TESTS = (
    "testStartTimestampMakesFirstTickAdvance",
    "testSpeedChangeSettlesOldSpeedBeforeInstallingNewSpeed",
    "testInvalidTimestampPausesOnceWithoutMovement",
    "testSuspensionGapPausesOnceWithoutCatchUp",
    "testUptimeClockDomainIsUsedConsistently",
    "testMaximumOffsetChangeRequiresPause",
    "testManualMoveSettlesElapsedTimeBeforeClamping",
    "testTerminalStopReasonIsEdgeTriggered",
    "testInsertionExactlyAtAnchorClampsAndRequestsPause",
    "testInvalidRangeOverflowClampsAndRequestsPause",
    "testSplitSurrogateRangeClampsAndRequestsPause",
    "testResultDocumentMismatchClampsAndRequestsPause",
    "testAnchorNormalizesBackwardToScalarBoundary",
    "testExactIndependentContextsSelectUniqueCandidate",
    "testAbsentContextClampsAndRequestsPause",
    "testAmbiguousEqualContextTieClampsAndRequestsPause",
    "testReaderLayerOrderIsBackgroundBandThenTransparentClip",
    "testBottomDocumentPaddingIsExactlySixtyFourPoints",
    "testExistingHeaderIsNotDoubleCountedInMaximumOffset",
    "testBandUsesPersistedViewportFractionAndFixedHeight",
    "testBandIsNonHitTestingAndAccessibilityIgnored",
    "testIncrementalEditRestoresMappedAnchor",
    "testInsertionAtAnchorPausesAndRestoresBoundary",
    "testRevisionGapResyncIsSynchronousAndSingle",
    "testResizeRestoresAnchorAtBand",
    "testFontChangeRestoresAnchorAtBand",
    "testAlignmentChangeRestoresAnchorAtBand",
    "testThreeCompleteLinesPreferredForManualStep",
    "testManualStepFallsBackToClampedViewportFraction",
    "testClockRequiresAttachedReaderView",
    "testDisplayLinkUsesCommonModeAndTimestamp",
    "testDetachInvalidatesClockBeforeReplacement",
    "testScreenMoveInvalidatesAndRecreatesWithoutAutoResume",
    "testTeardownInvalidatesClockAndReleasesOwners",
    "testAppModelIsSoleSessionGenerationIssuer",
    "testSpeedChangeDoesNotAdvanceGeneration",
    "testPauseInvalidatesGenerationBeforeStopEffect",
    "testHideStopsAndCapturesBeforeOrderOut",
    "testPrivacyLossStopsBeforeShieldMove",
    "testClockUnavailablePublishesExactlyOnePausedTransition",
    "testOnlyAuthorizedRetiringGenerationTerminalCaptureIsAccepted",
    "testArbitraryStaleTerminalCaptureIsRejected",
    "testSemanticCheckpointsAreAtMostOncePerSecond",
    "testReaderResyncHasNoTaskYieldOrRecursiveEffectHandling",
    "testEndInvalidatesClockBeforeOnePausedTransition",
    "testControllerExposesBackAndForwardWithoutM4GlobalInput",
)

M3_PROHIBITED_PATTERNS = (
    "NSStatusItem",
    "MenuBarExtra",
    "addGlobalMonitorForEvents",
    "addLocalMonitorForEvents",
    "CGEventTap",
    "CGEvent.tapCreate",
    "AXIsProcessTrusted",
    "AXUIElement",
    "AXObserver",
    "WKWebView",
    "URLSession",
    "URLRequest",
    "NSURLConnection",
    "NWConnection",
    "import Network",
    "import ApplicationServices",
    ".layoutManager",
    "NSLayoutManager",
    "NSClassFromString",
    "dlsym(",
)

M3_ALLOWED_PACKAGE_DEPENDENCIES = ("TeleprompterCore", "Carbon.framework")
M3_BASELINE = "802953089e88369e2a8e9fb744f4e32b30d9727d"


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


def validate_data_safety() -> None:
    violations: list[str] = []
    sensitive_name = re.compile(r"\b(document|title|text|contextBefore|contextAfter)\b")
    for path in (ROOT / "PrivatePresenterApp").rglob("*.swift"):
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            code = raw_line.split("//", 1)[0]
            if any(re.search(pattern, code) for pattern in DATA_SAFETY_PATTERNS):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
            if "\\(" in code and sensitive_name.search(code):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
            if "appendingPathComponent" in code and sensitive_name.search(code):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
    if violations:
        fail("unsafe local-data exposure marker in product source: " + ", ".join(violations))


def validate_historical_result_prefix() -> None:
    baseline = git(
        "show",
        "940e1821f36c4125b0f81f623a6d24a015c22dcc:"
        "docs/validation/overlay-proof-result.md",
    )
    if baseline.returncode != 0:
        fail("historical overlay result baseline is unavailable")
    baseline_bytes = baseline.stdout.encode("utf-8")
    current = (ROOT / "docs/validation/overlay-proof-result.md").read_bytes()
    import hashlib

    if len(baseline_bytes) != 14_486:
        fail("historical overlay result baseline length changed")
    if hashlib.sha256(baseline_bytes).hexdigest() != (
        "e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da"
    ):
        fail("historical overlay result baseline hash changed")
    if not current.startswith(baseline_bytes):
        fail("overlay result no longer begins with the immutable historical prefix")


def validate_m0_prohibited_surfaces() -> None:
    violations: list[str] = []
    prohibited = (
        r"\bNSApp\.activate\s*\(",
        r"\bNSRunningApplication\b[^\n]*\.activate\s*\(",
        r"\bmakeKeyAndOrderFront\s*\(",
        r"\.screenSaver\b",
        r"\bCGWindowLevelForKey\s*\(",
        r"\bGetEventDispatcherTarget\s*\(",
        r"\bperformWindowDrag\s*\(",
        r"\bNSWindow\.Level\s*\(\s*rawValue",
        r"\bstyleMask[^\n]*(?:insert|formUnion)[^\n]*\.resizable",
        r"\bstyleMask\s*[:=][^\n]*\.resizable",
        r"\b(?:AXUIElement|AXObserver|AXIsProcessTrusted)\b",
        r"\bimport\s+ApplicationServices\b",
    )
    for path in (ROOT / "PrivatePresenterApp").rglob("*.swift"):
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            code = raw_line.split("//", 1)[0]
            if any(re.search(pattern, code) for pattern in prohibited):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
    hot_key_source = read("PrivatePresenterApp/Services/DiagnosticHotKeyService.swift")
    if "GetApplicationEventTarget()" not in hot_key_source:
        violations.append("DiagnosticHotKeyService.swift:application-target-missing")
    for marker in ("kVK_ANSI_H", "kVK_ANSI_L", "Control-Option-H", "Control-Option-L"):
        if marker not in hot_key_source:
            violations.append(f"DiagnosticHotKeyService.swift:missing-{marker}")
    panel_source = read("PrivatePresenterApp/Overlay/TeleprompterPanel.swift")
    level_cases = re.findall(r"^\s*case\s+(\w+)\s*$", panel_source, re.MULTILINE)
    allowed_level_cases = {"floating", "statusBar", "front", "frontRegardless"}
    unexpected_level_cases = set(level_cases).difference(allowed_level_cases)
    if unexpected_level_cases:
        violations.append("TeleprompterPanel.swift:unexpected-bounded-enum-case")
    if violations:
        fail("prohibited M0 behavior marker in product source: " + ", ".join(violations))


def validate_m2_source() -> list[str]:
    violations: list[str] = []
    missing_paths = [path for path in M2_REQUIRED_PATHS if not (ROOT / path).is_file()]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    test_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for root in (
            ROOT / "Packages/TeleprompterCore/Tests",
            ROOT / "PrivatePresenterAppTests",
        )
        for path in root.rglob("*.swift")
    )
    violations.extend(
        f"missing-test:{name}" for name in M2_NAMED_TESTS if name not in test_sources
    )

    production_files = list((ROOT / "PrivatePresenterApp").rglob("*.swift"))
    for path in production_files:
        source = path.read_text(encoding="utf-8")
        for pattern in M2_PROHIBITED_PATTERNS:
            if pattern in source:
                violations.append(f"prohibited:{pattern}:{path.relative_to(ROOT)}")

    app_model = read("PrivatePresenterApp/App/AppModel.swift")
    if app_model.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")

    app_sources = "\n".join(path.read_text(encoding="utf-8") for path in production_files)
    if app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")

    editor_source = read("PrivatePresenterApp/Controller/EditorTextSystem.swift")
    reader_source = read("PrivatePresenterApp/Overlay/ReaderTextSystem.swift")
    if "NSTextView(usingTextLayoutManager: true)" not in editor_source:
        violations.append("textkit:editor-not-textkit2")
    if "NSTextView(usingTextLayoutManager: true)" not in reader_source:
        violations.append("textkit:reader-not-textkit2")
    if "private(set) var isAwaitingResync" not in reader_source:
        violations.append("reader:resync-latch-missing")
    if "incrementalMutationCount" not in reader_source or "fullReplacementCount" not in reader_source:
        violations.append("reader:mutation-instrumentation-missing")

    controller_source = read("PrivatePresenterApp/Controller/ControllerView.swift")
    m3_source_present = all(
        (ROOT / path).is_file()
        for path in (
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollEngine.swift",
            "PrivatePresenterApp/Overlay/ScrollSessionController.swift",
            "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
        )
    )
    if m3_source_present:
        control_markers = (
            'Button("Start") { dispatch(.start) }',
            'Button("Pause") { dispatch(.pause) }',
            'Button("Restart") { dispatch(.restart) }',
            'Button("Back") { dispatch(.back) }',
            'Button("Forward") { dispatch(.forward) }',
            'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
        )
        for marker in control_markers:
            if marker not in controller_source:
                violations.append(f"controller:missing-m3-marker:{marker}")
    else:
        for marker in (
            'Button("Start") {}.disabled(true)',
            'Button("Pause") {}.disabled(true)',
            'Button("Restart") {}.disabled(true)',
            'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
        ):
            if marker not in controller_source:
                violations.append(f"controller:missing-disabled-marker:{marker}")
    for prohibited_dispatch in (
        "model.send(.start)",
        "model.send(.togglePlayback)",
        "model.send(.restart)",
    ):
        if prohibited_dispatch in controller_source:
            violations.append(f"controller:future-dispatch:{prohibited_dispatch}")

    if "static let currentSchemaVersion = 1" not in read(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
    ):
        violations.append("schema:persisted-snapshot-version")
    if "static let currentSchemaVersion = 1" not in read(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
    ):
        violations.append("schema:script-document-version")

    snapshot_store_baseline = git(
        "show",
        "d17e74a95f8e4b29dd691b911eb1f775421e2b30:"
        "PrivatePresenterApp/Services/SnapshotStore.swift",
    )
    if snapshot_store_baseline.returncode != 0:
        violations.append("snapshot-store:planning-baseline-unavailable")
    elif snapshot_store_baseline.stdout != read("PrivatePresenterApp/Services/SnapshotStore.swift"):
        violations.append("snapshot-store:production-source-changed")

    return violations


def validate_m3_source() -> list[str]:
    violations: list[str] = []
    # Keep this inventory explicit: M3 may add its validator contract, but its
    # controlled-Mac result is forbidden until native/package/physical evidence exists.
    missing_paths = [path for path in M3_REQUIRED_PATHS if not (ROOT / path).is_file()]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    swift_test_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Tests", ROOT / "PrivatePresenterAppTests")
        for path in root.rglob("*.swift")
    ]
    test_sources = "\n".join(read(path) for path in swift_test_paths)
    violations.extend(
        f"missing-test:{name}"
        for name in (*M3_CANONICAL_NAMED_TESTS, *M3_ADDED_NAMED_TESTS)
        if name not in test_sources
    )

    production_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Sources", ROOT / "PrivatePresenterApp")
        for path in root.rglob("*.swift")
    ]
    production_sources = {path: read(path) for path in production_paths}
    for path, text in production_sources.items():
        for pattern in M3_PROHIBITED_PATTERNS:
            if pattern in text:
                violations.append(f"prohibited:{pattern}:{path}")

    app_sources = {
        path: text
        for path, text in production_sources.items()
        if path.startswith("PrivatePresenterApp/")
    }
    joined_app_sources = "\n".join(app_sources.values())
    if joined_app_sources.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if joined_app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")
    if joined_app_sources.count("ScrollSessionController(") != 1:
        violations.append("authority:scroll-session-construction-count")

    app_model_path = "PrivatePresenterApp/App/AppModel.swift"
    app_model = app_sources[app_model_path]
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")
    if "struct ScrollSessionGeneration" not in app_model or "fileprivate init" not in app_model:
        violations.append("authority:generation-issuer")
    for path, text in app_sources.items():
        if path != app_model_path and "ScrollSessionGeneration()" in text:
            violations.append(f"authority:generation-issued-outside-AppModel:{path}")

    editor = app_sources["PrivatePresenterApp/Controller/EditorTextSystem.swift"]
    reader = app_sources["PrivatePresenterApp/Overlay/ReaderTextSystem.swift"]
    adapter = app_sources["PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift"]
    if "NSTextView(usingTextLayoutManager: true)" not in editor:
        violations.append("textkit:editor-not-textkit2")
    if "NSTextView(usingTextLayoutManager: true)" not in reader:
        violations.append("textkit:reader-not-textkit2")
    for marker in ("textLayoutManager", "ensureLayout(for:", "enumerateTextLayoutFragments"):
        if marker not in adapter:
            violations.append(f"textkit:adapter-missing:{marker}")

    snapshot = production_sources[
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
    ]
    document = production_sources[
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
    ]
    if "static let currentSchemaVersion = 1" not in snapshot:
        violations.append("schema:persisted-snapshot-version")
    if "static let currentSchemaVersion = 1" not in document:
        violations.append("schema:script-document-version")

    runtime = app_sources["PrivatePresenterApp/App/AppRuntime.swift"]
    dependency_container = app_sources["PrivatePresenterApp/App/DependencyContainer.swift"]
    panel = app_sources["PrivatePresenterApp/Overlay/TeleprompterPanel.swift"]
    if "proofLevel: OverlayPanelLevel = .statusBar" not in runtime:
        violations.append("panel:status-bar-default")
    if "orderingMode: OverlayPanelOrderingMode = .frontRegardless" not in dependency_container:
        violations.append("panel:front-regardless-default")
    if "override var canBecomeKey: Bool { false }" not in panel:
        violations.append("panel:permanent-non-key")
    if "override var canBecomeMain: Bool { false }" not in panel:
        violations.append("panel:permanent-non-main")

    clock = app_sources["PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift"]
    clock_markers = (
        "readerView.window != nil",
        "readerView.window?.screen != nil",
        "readerView.displayLink(",
        "link.timestamp",
        "RunLoop.main",
        "forMode: .common",
        "link.invalidate()",
    )
    for marker in clock_markers:
        if marker not in clock:
            label = {
                "link.timestamp": "clock:timestamp",
                "forMode: .common": "clock:common-run-loop",
            }.get(marker, f"clock:missing:{marker}")
            violations.append(label)
    if "targetTimestamp" in clock:
        violations.append("clock:target-timestamp")
    if "Date(" in clock or "Date." in clock:
        violations.append("clock:wall-time")

    session = app_sources["PrivatePresenterApp/Overlay/ScrollSessionController.swift"]
    for marker in ("model.send(", "@Observable", "withObservationTracking"):
        if marker in session:
            violations.append("hot-path:model-publication")
            break
    if "Task {" in session or "DispatchQueue" in session:
        violations.append("hot-path:asynchronous-session")

    controller = app_sources["PrivatePresenterApp/Controller/ControllerView.swift"]
    for marker in (
        'Button("Start") { dispatch(.start) }',
        'Button("Pause") { dispatch(.pause) }',
        'Button("Restart") { dispatch(.restart) }',
        'Button("Back") { dispatch(.back) }',
        'Button("Forward") { dispatch(.forward) }',
        'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
    ):
        if marker not in controller:
            violations.append(f"controller:missing-m3-marker:{marker}")

    project_baseline = git("show", f"{M3_BASELINE}:project.yml")
    if project_baseline.returncode != 0:
        violations.append("dependency:project-baseline-unavailable")
    elif project_baseline.stdout != read("project.yml"):
        violations.append("dependency:project-yml-changed")
    package_path = "Packages/TeleprompterCore/Package.swift"
    package_baseline = git("show", f"{M3_BASELINE}:{package_path}")
    if package_baseline.returncode != 0:
        violations.append("dependency:package-baseline-unavailable")
    elif package_baseline.stdout != read(package_path):
        violations.append("dependency:package-swift-changed")

    project = read("project.yml")
    for dependency in M3_ALLOWED_PACKAGE_DEPENDENCIES:
        if dependency not in project:
            violations.append(f"dependency:missing-allowed:{dependency}")

    return violations


def main() -> None:
    missing = [path for path in REQUIRED_PATHS if not (ROOT / path).is_file()]
    if missing:
        fail("missing required paths: " + ", ".join(missing))
    if read(".xcodegen-version").strip() != "2.45.4":
        fail(".xcodegen-version must contain exactly 2.45.4")
    if "ENABLE_DEBUG_DYLIB = NO" not in read("Config/Debug.xcconfig"):
        fail("Debug proof builds must disable unbound debug-dylib indirection")
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
    phase_a_inventory = swift_sources + "\n" + read(
        "Scripts/test-verify-m0-proof-provenance.sh"
    )
    missing_phase_a_tests = [
        name
        for name in (*PHASE_A_NAMED_TESTS, *PROVENANCE_FIXTURE_TESTS)
        if name not in phase_a_inventory
    ]
    if missing_phase_a_tests:
        fail("missing required Phase A named tests: " + ", ".join(missing_phase_a_tests))
    missing_phase_b_tests = [
        name for name in PHASE_B_NAMED_TESTS if name not in phase_a_inventory
    ]
    if missing_phase_b_tests:
        fail("missing required Phase B named tests: " + ", ".join(missing_phase_b_tests))
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
    validate_data_safety()
    validate_historical_result_prefix()
    validate_m0_prohibited_surfaces()
    m2_violations = validate_m2_source()
    if m2_violations:
        fail("Milestone 2 source validation failed: " + ", ".join(m2_violations))
    m3_violations = validate_m3_source()
    if m3_violations:
        fail("Milestone 3 source validation failed: " + ", ".join(m3_violations))
    validate_xcode_listing()
    print(
        "Project structure validation passed "
        "(Milestone 0 Phase B + Milestone 2 + Milestone 3 source)."
    )


if __name__ == "__main__":
    main()
