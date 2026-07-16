# Private Presenter — Milestone 5 Accessibility, Performance, and Lifecycle Hardening Plan

Status: **IMPLEMENTATION-READY SEQUENTIAL ROLE CONSENSUS — IMPLEMENTATION NOT STARTED**

Canonical publication target: `docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md`

Exact planning baseline: clean `main` at
`9eac2f9db3de49a3a925983dcadc1893c7ae3a6d` (`Keep the reviewed M4 path free of dead state`).

## 1. Outcome, authorization, and hard stop

Implement only `IMPLEMENTATION_PLAN.md` Milestone 5 (`IMPLEMENTATION_PLAN.md:577-591`):
accessibility, display/crash/quit lifecycle hardening, and measured exactly-50,000-word
performance. The owner explicitly authorizes immediate **M5 WSL candidate continuation** from
the clean M4 source candidate. That authorization permits WSL-authored candidate test/source
pairs and later controlled-Mac replay. It does **not** convert WSL checks into Swift/AppKit/
TextKit/VoiceOver/Carbon/display/Keynote/Instruments evidence, waive predecessors, or authorize a
completion claim.

Native evidence remains honestly pending:

- M3 controlled-Mac Swift/AppKit/TextKit/display-link/package/physical evidence is pending.
- M4 controlled-Mac Swift/Carbon/AppKit and fresh-user Keynote/TCC/hotkey evidence is pending;
  `docs/validation/hotkey-proof-result.md` does not exist at this baseline.
- M5 runs may exercise M3/M4 behavior but cannot close those milestones without separately
  replaying and accepting their canonical plans.

Stop after the M5 source candidate, available gates, additive M5 evidence, exact-SHA closure, and
independent review. Do not enter M6, apply visual polish, add a dependency or permission, push,
edit `HANDOFF.md`, rewrite M0-M4 plan/result evidence, or call M5 complete while M3/M4 native
evidence remains pending.

## 2. Grounded architecture and protected invariants

- One `@MainActor @Observable AppModel` is command authority
  (`PrivatePresenterApp/App/AppModel.swift:14-72,205-373`).
- `AppRuntime` owns the one model, controller, status item, display service, and panel and wires
  display callbacks (`AppRuntime.swift:80-123,218-250`).
- Startup shields before load, restores before display observation/privacy, then registers
  hotkeys (`AppRuntime.swift:292-371`).
- Display callbacks enter on the main queue (`SystemDisplayService.swift:269-300,406-415`;
  `AppRuntime.swift:374-403`).
- Privacy plans pause, hide, shield, invalidate-show, query/evaluate, confirmation
  (`PrivacyCoordinator.swift:8-40`); scroll retirement synchronously captures semantic position
  (`DependencyContainer.swift:210-230`).
- Restore already produces hidden, paused, confirmation-required runtime state
  (`AppModel.swift:886-935`; `SnapshotMigratorTests.swift:67-82`).
- Quit stages paused snapshot and flushes before teardown (`AppLifecycleCoordinator.swift:52-87`;
  `DependencyContainer.swift:504-535`).
- Editor/reader are separate TextKit 2 stacks. Edits are UTF-16 revisioned
  (`EditorTextSystem.swift:12-137`); reader applies incremental mutations and counts replacements
  (`ReaderTextSystem.swift:11-183`).
- Persistence is an actor with 300 ms debounce and atomic commit
  (`SnapshotStore.swift:91-125,233-304,325-360`); scroll checkpoints are capped at 1 Hz
  (`AppModel.swift:1344-1418`).
- M4 preserves one model/panel/status/scroll owner and Carbon-only input. Current audits reject
  event taps, AX, key monitors, network, telemetry, and generic logging
  (`Scripts/test_validate_project_structure_m4.py:44-78`; `Scripts/verify-no-network.sh:4-28`).

### Protected history/evidence

Execution records preflight hashes. Prior plans, `HANDOFF.md`, historical `m0-*`, `m2-*`, and
`overlay-proof-result.md`, both PNG references, and unrelated source evidence stay unchanged.
Although `IMPLEMENTATION_PLAN.md:582` names the historical overlay result, the owner's no-rewrite
constraint requires additive `docs/validation/m5-display-crash-quit-result.md`, which references
but does not edit the old proof. No schema v1, dependency direction, panel level/style/opacity,
Carbon policy, Focus deadline, shortcut-edit default, or M6 surface changes.

### Non-goals

No M6; new model/panel/editor/reader; schema/dependency/permission; network/telemetry/remote crash
service; AX/event tap/global or local monitor/key polling; Keynote integration; private lecture
content in public UI, logs, signposts, traces, filenames, or committed evidence; or screen-capture
guarantee.

## 3. RALPLAN-DR

### Principles

1. Fail closed: capture/stage position synchronously but never delay hide/shield on I/O/query.
2. Extend existing typed owners; create no shadow state authority.
3. Measure with static names/closed enums and no content-bearing metadata.
4. Accessibility means exact operation and focus, not labels alone.
5. WSL, Mac automation, VoiceOver, physical display, and Instruments claims stay separate.

### Top drivers

1. Audience privacy and recoverable controls through asynchronous display/quit races.
2. Deterministic, testable criteria for every M5 claim and threshold.
3. Useful local measurement without permission, content, telemetry, or overhead regressions.

### Options

**A — harden existing owners with typed seams (chosen).** Central accessibility semantics,
runtime display generations, lifecycle result/order tests, typed `OSSignposter`, fixture, additive
evidence. Pros: real product path, least authority change, no dependency/schema/permission. Cons:
bounded changes span integration files and require Mac replay.

**B — separate M5 coordinator and benchmark target.** Pros: nominal isolation and synthetic input.
Cons: duplicated authority, non-product measurement, new target complexity, order disagreement.
Viable for future diagnostics, rejected because privacy ownership dominates isolation.

**C — manual Inspector/Instruments only.** Smallest diff, but cannot enforce callback order,
non-vacuous accessibility, incremental reader behavior, fixture identity, or repeatability.
Invalid against `IMPLEMENTATION_PLAN.md:579-591`.

### Tradeoff synthesis

- Durability versus privacy: accept captured anchor and enqueue paused snapshot, then hide; never
  wait on disk except normal quit. Only committed data is crash-durable.
- Assistive focus versus Keynote: focus generic safety state only when controller already active;
  never activate app or locked overlay, never announce private content cross-app.
- Detail versus privacy/overhead: static durations and optional closed enums only; Instruments
  Hangs/Time Profiler remains authoritative.

## 4. Acceptance criteria

### 4.1 VoiceOver and full keyboard operation

1. Shield Tab order is exactly `privateDisplayPicker`, `confirmPrivateDisplay`,
   `keepScriptHidden`; Shift-Tab reverses it.
2. Confirmed controller order is exactly `scriptTitle`, `scriptEditor`, `openClose`, `hideShow`,
   `lock`, `clear`, `fontSize`, `alignment`, `activeBand`, `start`, `pause`, `restart`, `back`,
   `forward`, `speed`, `focusMode`, conditional `retryShortcuts`. Hidden/disabled controls skip;
   reverse order has no trap.
3. Space activates focused button/toggle; Return only the default dialog action; Escape cancels
   Clear; arrows adjust native slider/picker steps. No bare Space/arrows become global.
4. Every focused control shows standard macOS focus ring/highlight at normal and Increase Contrast.
5. Every action has stable `privatePresenter.*` identifier, concise localized label, current
   value/state, action-result help/hint, and tooltip for icon/action controls. Labels omit role
   words. Public surfaces omit title/script.
6. Exact values: `Font size`, `{n} points`, 24–96 step 2; `Scroll speed`, `{n} points per second`,
   10–240 step 5; `Text alignment`, Left/Center; band/Focus On/Off; playback/visibility/lock label
   the next action and expose current state separately.
7. Title label is `Script title`; editor `Script editor` with help `Edit the local teleprompter
   script`; reader is read-only `Teleprompter script` only on confirmed private overlay. Band,
   drag/resize zones, backgrounds, and decorative containers are ignored.
8. Safety status is `Display safety: {generic state}`. Unsafe state uses visible text and icon/
   role, never color only. Mirroring keeps exact PRD warning. VoiceOver focus moves once per
   unsafe generation only while controller already active; otherwise no activation/announcement.
9. Status/menu expose only generic controls and five actions, never private/display/path data.
10. Overlay Start/Pause, Show/Hide, Lock/Unlock expected action set is nonempty; each hit frame is
    at least 44 by 44 points per `IMPLEMENTATION_PLAN.md:476`; M6 still owns final icons.
11. Workspace accessibility-options changes update Reduce Motion live: decorative Focus duration
    becomes zero while reading motion continues. Contrast/color settings preserve text and focus.
12. Canonical UI tests pass and cannot pass vacuously:
    `testAllIconButtonsHaveLabelsAndHelp`, `testWarningExposesTextNotColorOnly`,
    `testControllerKeyboardTraversal`, `testFontRangeControlsAreReachable`. Deterministic app-host
    tests cover the complete semantics/traversal manifest without topology substitution. The four
    canonical UI tests are a separate real-display gate: they require the explicit physical-host
    flag and at least two active, extended, non-mirrored displays; select and confirm the real
    private display through the shield; use only the gated temporary store; and fail with an
    actionable prerequisite error rather than silently skipping, faking a display, or touching
    normal user storage.
13. Real Mac passes VoiceOver speech/actions/values/help, Full Keyboard Access both directions,
    Accessibility Inspector, contrast/color, live Reduce Motion. Evidence records generic outcome,
    never reader/editor value.

### 4.2 Disconnect, reconnect, crash, quit

14. Each observation lifetime/topology transaction has monotonic runtime-only generation. Start
    creates it; begin invalidates earlier query/show work; stop/quiescence invalidates lifetime.
    Never persist or signpost it.
15. Disconnect order on main actor: invalidate pending show/generation; stop display link/capture
    anchor and offset; set paused; stage paused snapshot to persistence actor; hide panel; shield
    controller; require confirmation/clear runtime display; stop Focus pointer; query/evaluate.
16. `Persists anchor then hides` means AppModel accepts capture, advances snapshot revision, and
    enqueues save before `orderOut`; never wait for I/O before privacy. Only committed snapshot is
    crash-durable.
17. Failure/missing/ambiguity/mirroring remains paused, hidden, shielded, confirmation-required.
    Stale result cannot move or reveal.
18. Reconnect may preselect/stage hidden candidate and move controller shielded. Never confirm,
    reveal, show, or resume. Confirmation re-evaluates live generation/fingerprint; controller
    reveals after shielded move; Show and Start remain separate.
19. Crash runs no teardown/imaginary flush. Relaunch order: shield; load last atomic snapshot;
    restore document/preferences/anchor paused/hidden, runtime display nil, confirmation required;
    attach reader paused; observe/query; stage candidate hidden; register hotkeys. No auto show.
20. Quit order: reject product mutations; stop/capture; pause; hide; shield; stage paused snapshot;
    drain/flush exact revision; enter quiescence; close Carbon dispatch; stop Focus/pointer; stop
    display observation/invalidate queued generations; tear down scroll/display link; remove status;
    close controller; reply terminate true. Closing Carbon dispatch precedes unregister so every
    already-queued callback is a no-op. Record unregister as a content-neutral typed result. A
    non-`noErr` result proves neither release nor retention of OS hotkey references and preserves
    M4 `cleanupUnknown` truth; after the exact revision is durably flushed, finish process exit and
    attempt recovery only on a later relaunch, never by reopening dispatch during termination.
21. Flush failure tears down nothing; cancellation stays paused/hidden/shielded with controller,
    status, hotkeys, display observation, recovery, generic error; retry allowed, no resume.
22. Overlapping quits share one in-flight attempt; completed teardown idempotent. Post-invalidation
    display/tick/focus/hotkey callbacks are no-op and retain no owner.
23. Canonical tests pass: `testCrashRestoreIsPaused`,
    `testDisconnectDuringTickPersistsAnchorThenHides`, `testReconnectRequiresConfirmation`,
    `testQuitTearsDownCallbacks`, plus hostile tests in section 7.
24. Physical Keynote/extended display proves disconnect privacy, 30-second no-auto reconnect,
    unclean relaunch paused/hidden at last committed synthetic anchor, and clean ordinary quit.

### 4.3 Privacy-safe signposts and exactly 50,000 words

25. Generated fixture tokens `word00000`…`word49999`, single spaces, newline each 20, no final
    newline: exactly 50,000 whitespace words, 499,999 UTF-8 bytes and UTF-16 units, SHA-256
    `d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4`.
26. Swift helper and stdlib Python generator are byte-identical; fail on count/length/endpoints/
    digest drift. Use only synthetic fixture.
27. One injected `PerformanceSignposting` wraps local `OSSignposter`; no logger/telemetry/upload/
    MetricKit transport/crash service/entitlement. Its typed token is app-local, never enters
    `TeleprompterCore`, a snapshot, an effect payload that can persist, or public observation.
28. Static subsystem `com.privatepresenter.teleprompter`; categories `load`, `layout`, `edit`,
    `scroll`, `persistence`; intervals `restore-to-interactive`, `reader-layout`, `edit-to-visible`,
    `scroll-session`, `scroll-tick`, `snapshot-encode`, `snapshot-write`, `snapshot-flush`. Exact
    owners and edges are:
    - `AppRuntime` begins restore immediately before snapshot load and ends only after restore,
      reader attachment, first reader layout, and a queued main-actor sentinel have completed;
    - the reader/text-system boundary brackets actual `ensureLayout` work for reader-layout;
    - `EditorTextSystem` begins edit-to-visible after it has validated and accepted a
      `ScriptTextEdit`; an app-local token keyed by—but never labeled with—the runtime document
      revision crosses the injected runtime probe, and the reader ends it after incremental
      storage application plus viewport `ensureLayout`;
    - the scroll-session owner brackets start through retirement; scroll-tick brackets one real
      frame callback only when the signposter is enabled, with no metadata or per-frame publish;
    - `SnapshotStore` brackets canonical encoding, `atomicCommit`, and terminal drain/flush as
      three separate intervals. Debounce waiting belongs to none of them.
29. A single app-local interval registry retains each token; the designated completion edge above
    consumes and ends it exactly once for success, failure, cancellation, rejected edit, resync,
    supersession, and teardown. Tests inject a recorder and assert no open token remains. No
    interval state crosses into core or persistence.
    No metadata by default. Only closed outcome `success|failure|cancelled` and reason
    `initial|restore|resync|debounced|flush` may be emitted. Forbidden even redacted: text/title/
    selection, display identity, path/URL, revision, count/size, arbitrary strings, object/error
    description, user ID.
30. Validator rejects generic Logger/os_log and allows OS/OSSignposter only in the signposter file;
    mutations inject every forbidden source. No-network/AX/event audit remains.
31. Tick probe never causes SwiftUI publish, text mutation/persistence, or attributed rebuild.
32. Each load trial restores a pristine pre-seeded paused/hidden v1 snapshot containing the
    synthetic fixture, created and flushed once through production `SnapshotStore`; paste/import
    is not the measured load path. Release/Instruments runs use a dedicated disposable macOS test
    account with empty normal Application Support—never the DEBUG UI-test override and never an
    owner's account. Before each Release trial, terminate the prior process, replace only that
    account's app store with the verified pristine snapshot, and launch the same executable.
    Start at `AppRuntime` immediately before `load()`; end after restore, editor/reader attachment,
    first reader viewport layout, one injected synthetic edit accepted/reflected, and the next
    main-actor sentinel. Window appearance alone is insufficient. The controller is interactive
    and the restore interval ends within 2.000 seconds.
33. Run one complete unrecorded warm-up, terminate/reset as above, then three recorded clean load
    trials. Every trial—not their mean—must be at most 2.000 seconds. Record all durations and the
    executable/snapshot identity; a faster non-baseline Mac is provisional.
34. Exactly 300 actions run at 100 ms cadence: 50 identical six-action cycles. With the stable
    fixture length 499,999 UTF-16 units, each cycle inserts ASCII `x` then deletes it at UTF-16
    offset 0; inserts/deletes `x` at offset 250,000, immediately before `word25000`; then inserts
    at current end offset 499,999 and deletes it at that same offset. Recompute/assert each target
    against the unchanged fixture before its pair. The document returns byte-for-byte to the
    exactly-50,000-word fixture after every pair. Each accepted action produces one
    edit-to-visible sample through incremental reader storage plus viewport layout. Sort all 300
    durations ascending; nearest-rank p95 is the one-based sample `ceil(0.95 * 300) = 285` and must
    be strictly below 50.000 ms. Every sample and observed main-thread stall must be at most
    100.000 ms; full-replacement count is unchanged and resync count is zero.
35. Run one continuous six-minute actual display-link session. The first 60 seconds are unmeasured
    warm-up; at its end, mark the Allocations baseline and begin the measured five-minute window.
    Sample live bytes at measured elapsed 60/120/180/240/300 seconds (total session elapsed
    120/180/240/300/360 seconds). Let `x_i = 1...5`, `y_i = liveBytes_i / 1,048,576`, and means be
    `x_bar`, `y_bar`; ordinary least-squares slope is
    `sum((x_i-x_bar)*(y_i-y_bar)) / sum((x_i-x_bar)^2)`. It must be at most 1.0 MiB/min and
    `y_5 - y_1` at most 5.0 MiB. Across the measured five minutes, no main-thread stall may exceed
    100 ms and no tick may mutate/persist/rebuild/publish; any tick/session leak fails.
36. Tests inject 200 ms filesystem delay while typing; AppModel edit never awaits disk; save causes
    no edit interval above 100 ms; final revision flushes. Instruments records real saves.
37. Required automated tests: `testFiftyThousandWordLoad`,
    `testRepeatedEditDoesNotRebuildWholeReader`, `testDebouncedSaveDoesNotBlockMainActor`,
    `testScrollTicksDoNotMutateTextOrPublishPerFrame`,
    `testFixtureIsExactlyFiftyThousandWords`, signpost balance/privacy. Hardware thresholds require
    opt-in baseline command plus Instruments, never WSL/variable CI.
38. Result records source/app SHA, Mac/chip/RAM, OS/Xcode/Swift, scale/refresh, Release flags,
    power/thermal, fixture digest, trials, latency distribution/max, stalls, reader counters, save,
    memory samples/slope/delta, local trace paths. Raw traces/fixture/pasteboard stay untracked.

## 5. Official constraints

- [OSSignposter](https://developer.apple.com/documentation/os/ossignposter): paired intervals and
  retained interval state.
- [XCTOSSignpostMetric](https://developer.apple.com/documentation/xctest/xctossignpostmetric) and
  [performance tests](https://developer.apple.com/documentation/xctest/performance-tests):
  signpost/clock/CPU/memory/storage metrics.
- [Accessibility for AppKit](https://developer.apple.com/documentation/appkit/accessibility-for-appkit)
  and [accessibility labels](https://developer.apple.com/documentation/appkit/nsaccessibility-c.protocol/accessibilitylabel):
  bridged custom semantics, concise labels, separate value/help.
- [Reduce Motion](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion):
  workspace option changes.
- [Responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness):
  Time Profiler/Hangs; project uses stricter 100 ms gate.

Documentation constrains implementation but never replaces Mac evidence.

## 6. Planned file surface

### Create

| Path | Purpose |
|---|---|
| `PrivatePresenterApp/Accessibility/PresenterAccessibility.swift` | Closed identifiers, labels, values, help, safety states, traversal targets; no private storage. |
| `PrivatePresenterApp/Interfaces/PerformanceSignposting.swift` | Typed operation/outcome/reason seam; no arbitrary string API. |
| `PrivatePresenterApp/Services/PerformanceSignposter.swift` | Sole OS/OSSignposter boundary, static names, balanced intervals. |
| `PrivatePresenterAppTests/PresenterAccessibilityTests.swift` | Semantics, privacy, reduce-motion, hit-frame host tests. |
| `PrivatePresenterAppTests/PerformanceSignposterTests.swift` | Balance and metadata allowlist tests. |
| `PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift` | Fixture, load/edit/tick/save invariants and opt-in baseline assertions. |
| `PrivatePresenterUITests/ControllerAccessibilityUITests.swift` | Canonical UI tests and focus/value/action assertions. |
| `PrivatePresenterUITests/M5UITestSupport.swift` | DEBUG/XCTest temporary store/helpers; no privacy bypass. |
| `Scripts/generate-m5-fixture.py` | Stdlib generator with digest self-check. |
| `Scripts/test_validate_project_structure_m5.py` | Mutation-tested path/test/order/metadata/scope policy. |
| `docs/validation/m5-accessibility-result.md` | Additive PENDING manual result. |
| `docs/validation/m5-display-crash-quit-result.md` | Additive PENDING lifecycle result. |
| `docs/validation/performance-result.md` | Additive PENDING exact-50k result. |

### Modify only as required

| Path | Bounded change |
|---|---|
| Controller, shield, and editor views | Manifest semantics, identifiers, focus order, values/help, generic warning focus. |
| Overlay chrome/root and reader view | 44-point actions, reader semantics, ignore decorations/interactions; no restyle. |
| `StatusItemController.swift` | Generic status/menu help and state. |
| `DependencyContainer.swift` | Inject signposter and bracket real edit/layout paths; one model/session. |
| Runtime, command, and model | Runtime generations, stale/quiescent guards, restore interval, typed effects. |
| `SystemDisplayService.swift` | Observation-lifetime generation and queued callback rejection; no polling. |
| Lifecycle coordinator and app delegate | Shared in-flight/idempotent result and exact teardown order. |
| TextKit, scroll, and store files | Measurement hooks/counters only as tests require; no hot-path rebuild. |
| Existing focused tests | Extend without weakening M0-M4. |
| Validator/no-network/WSL scripts | M5 inventory, narrow OS allowlist, metadata/scope gates. |
| `project.yml` | Only if test source wiring is necessary; no target/package/entitlement/deployment change. |

## 7. Test-first slices and exact commands

Every `nA` is test/contract-only and must fail on controlled Mac for the intended missing symbol or
expectation. Every `nB` is minimum GREEN. Preserve both Lore commits. WSL-authored pairs remain
**unobserved candidates** until each A/B checkout is replayed on Mac. Toolchain/configuration
failure is not valid RED.

### M5.0 — ancestry, protected evidence, validator guard (0A/0B)

0A adds `Scripts/test_validate_project_structure_m5.py` for exact paths/tests, M6/dependency/
schema/permission prohibition, logging/signpost metadata mutations, protected prior result bytes,
additive template PENDING status, and ancestry. Expected RED is missing M5 validator. 0B adds
minimum current-source wiring.

```bash
python3 Scripts/test_validate_project_structure_m5.py
python3 Scripts/validate_project_structure.py
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
git diff --check
```

### M5.1 — accessibility and keyboard operation (1A/1B)

1A adds canonical four UI tests plus:

- `testAccessibilityManifestContainsEveryActionExactlyOnce`
- `testEveryDynamicControlExposesLabelValueHelpAndIdentifier`
- `testControllerReverseTraversalHasNoTrap`
- `testOverlayActionTargetsAreAtLeastFortyFourPoints`
- `testReaderBandAndInteractionZonesAreIgnored`
- `testWarningFocusNeverActivatesBackgroundApplication`
- `testPublicAccessibilitySurfacesNeverContainPrivateSentinels`
- `testReduceMotionChangeRemovesFadeButKeepsReadingMotion`

The product honors a UI-test store-root override only when all four gates hold: compilation is
inside `#if DEBUG`; `PRIVATE_PRESENTER_UI_TEST` equals `1`; `XCTestConfigurationFilePath` is
nonempty; and the standardized, symlink-resolved override URL is a strict descendant of the
standardized, symlink-resolved `NSTemporaryDirectory()`. Missing/invalid gates reject the override
and use the normal store.
Tests cover traversal rejection for `..`, symlink escape, prefix-only siblings, Release builds,
and missing XCTest configuration. The override changes only the Application Support root: UI
tests traverse and confirm the real shield/current-display policy, never bypass privacy or
authorization, and never fake confirmation or create a synthetic display. 1B adds the manifest,
gated root, and minimum modifiers/AppKit bridge/focus order/44-point frames; no restyle.

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/PresenterAccessibilityTests

# Separate physical-host gate: the UI helper fails unless a real extended, non-mirrored display
# is active, then creates its unique canonical temporary root and confirms through the real shield.
PRIVATE_PRESENTER_M5_REAL_DISPLAY_UI=1 xcodebuild test \
  -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M5-Physical CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterUITests/ControllerAccessibilityUITests
```

### M5.2 — topology, reconnect, crash restore, quit (2A/2B)

2A adds:

- four canonical lifecycle tests;
- `testStaleTopologyResultCannotMoveRevealOrResume`;
- `testQueuedDisplayCallbackAfterStopIsIgnored`;
- `testReconnectConfirmationMustMatchCurrentGeneration`;
- `testDisconnectEnqueuesCapturedAnchorBeforeOrderOutWithoutAwaitingDisk`;
- `testCrashRestoreClearsRuntimeDisplayAndNeverShowsOrStarts`;
- `testSuccessfulQuitUsesExactLifecycleOrder`;
- `testFlushFailureTearsDownNothingAndLeavesRecoveryAvailable`;
- `testOverlappingQuitRequestsShareOneAttempt`;
- `testRepeatedSuccessfulTeardownIsIdempotent`;
- `testQuiescentTickFocusHotKeyAndDisplayCallbacksAreIgnored`;
- `testCarbonDispatchClosesBeforeUnregisterAndCleanupStatusDoesNotReopenIt`;
- `testRuntimeOwnersDeallocateAfterTeardown`.

Use event recorders and injected display-query, frame-clock, persistence-continuation, Carbon,
pointer, and weak-owner seams, never sleeps. 2B adds generations, guards, capture/enqueue-before-
hide, explicit confirmation, outcome-aware quit. Hide never awaits persistence.

```bash
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppLifecycleCoordinatorTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SystemDisplayServiceTests \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests
```

### M5.3 — typed signposts and privacy guard (3A/3B)

3A tests exact balance on success/failure/cancel/reject/resync/supersede/teardown, no arbitrary
metadata API, static names, private sentinel absence, tick no mutation/publish/persist, restore
completion only after the main-actor sentinel, edit completion only after incremental reader
layout, debounce exclusion, separate encode/write/flush boundaries, and validator mutations. 3B
adds the typed protocol, sole OS wrapper, app-local token ownership, and injection; no generic
logging or persisted/core token.

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/PerformanceSignposterTests
python3 Scripts/test_validate_project_structure_m5.py
./Scripts/verify-no-network.sh
```

### M5.4 — deterministic 50k invariants and measured gate (4A/4B)

4A references missing fixture/probe from criterion 37 and generator digest. Absolute mode requires
`PRIVATE_PRESENTER_M5_BASELINE=1`; heterogeneous hosts skip rather than fabricate baseline. 4B
adds generator, test support, instrumentation, and only trace-proven hot-path fixes.

```bash
python3 Scripts/generate-m5-fixture.py \
  --words 50000 --output "$TMPDIR/private-presenter-m5-50000.txt"
sha256sum "$TMPDIR/private-presenter-m5-50000.txt"
PRIVATE_PRESENTER_M5_BASELINE=1 xcodebuild test \
  -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/FiftyThousandWordPerformanceTests
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
```

4B without baseline Instruments is automated candidate only.

### M5.5 — validator and additive evidence templates (5A/5B)

5A mutations remove each path/test/threshold/order/prohibition or alter prior evidence. 5B adds
current checks and PENDING templates. Change to PASS only after exact source/app-SHA gate.

## 8. Logical Lore RED/GREEN ledger

1. 0A/0B — **Keep M5 claims inside the WSL/native evidence boundary.**
2. 1A/1B — **Make every presenter control operable without sight or pointer.**
3. 2A/2B — **Keep recovery fail-closed through display, crash, and quit races.**
4. 3A/3B — **Measure hot paths without recording lecture identity.**
5. 4A/4B — **Hold 50,000-word lectures to recorded responsiveness limits.**
6. 5A/5B — **Keep M5 evidence reproducible without rewriting prior proof.**
7. Evidence-only — record exact controlled-Mac candidate, generic results only.
8. Review-only repair pairs when required; preserve review RED/minimum fix.

All commits use why-first Lore trailers. WSL trailers say `Not-tested: Swift/XCTest/AppKit/
VoiceOver/display/Keynote/Instruments behavior; WSL unobserved candidate`. Never amend a WSL
commit to imply native replay, squash RED checkpoints, or commit raw traces/fixture.

## 9. Verification and evidence gates

### 9.1 WSL/source-static candidate

```bash
bash -n Scripts/*.sh
python3 -m unittest Scripts/test_validate_project_structure_m2.py \
  Scripts/test_validate_project_structure_m3.py \
  Scripts/test_validate_project_structure_m4.py \
  Scripts/test_validate_project_structure_m5.py
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
python3 Scripts/generate-m5-fixture.py --self-test
git diff --check
git status --short
```

WSL may claim path/test/static order markers, fixture digest, Python/shell, protected bytes,
prohibited-surface absence, and diff hygiene. It cannot claim Swift, actor/AppKit/TextKit,
VoiceOver/focus, callbacks/Carbon, Keynote/display, latency/memory/Instruments, package, or
physical behavior.

### 9.2 Controlled-Mac automated replay/regression

Record `M3_NATIVE_EVIDENCE=PENDING` and `M4_NATIVE_EVIDENCE=PENDING` unless separately accepted.
Continue only as owner-authorized candidate.

```bash
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = 'Version: 2.45.4'
python3 Scripts/validate_project_structure.py
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests/ControllerAccessibilityUITests
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Analyze CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-macos.sh
./Scripts/verify-no-network.sh
git diff --check
```

Replay each A/B checkout and record command, expected/actual RED, GREEN, source SHA, host,
toolchain, and timestamp in a local content-neutral manifest. App-host worker failure is not
source pass; preserve output and repair/retry.

### 9.3 VoiceOver, keyboard, Accessibility Inspector

On exact package/source SHA with synthetic script:

1. Attach a real extended, non-mirrored display, record host/app/display-count identities, and run
   the explicit `PRIVATE_PRESENTER_M5_REAL_DISPLAY_UI=1` command from M5.1. The helper must observe
   at least two active displays, drive real shield selection/confirmation, and fail—not skip—if
   the prerequisite disappears. Confirm its store root resolved under the temporary directory.
   Accessibility/Input Monitoring remain off; no permission prompt.
2. Enable Full Keyboard Access. Traverse shield/controller both directions; activate each action;
   adjust font 24–96–24, speed 10–240–10, alignment, band, Focus, Clear Cancel, conditional Retry.
3. Enable VoiceOver. Verify labels, values, state, help, disabled state, menu/status, reader
   read-only semantics, and no band/drag/resize noise.
4. Trigger mirroring/missing/query failure. Verify text plus icon, generic safety speech, no
   color-only meaning, private content, or background activation.
5. Toggle Increase Contrast, Differentiate Without Color, Reduce Motion live. Focus/text remain,
   fade becomes immediate, reading continues.
6. Run Accessibility Inspector Audit; resolve every actionable M5 issue; confirm overlay actions
   at least 44 by 44 points.
7. Record generic outcomes in `m5-accessibility-result.md`; never transcribe script value.

### 9.4 Release/Instruments exactly-50k gate

Use slowest available supported base Apple-silicon baseline; faster Mac remains provisional. AC
power, Low Power Mode off, nominal thermal state, unrelated apps closed, Release without debugger;
record scale/refresh.

1. Log into a dedicated disposable baseline-test macOS account with empty normal Application
   Support; the Release build must reject/omit the DEBUG UI-test override. Generate/self-check the
   fixture. Through production `SnapshotStore`, create and durably flush one paused/hidden pristine
   v1 snapshot in that account's app store; verify its fixture digest and retain an untracked
   pristine copy outside the live store. Paste/import is prohibited as the measured load path.
2. Add Points of Interest/Signposts, Time Profiler with Hangs threshold 100 ms, and Allocations.
3. For one unrecorded warm-up and each of three recorded load trials: terminate the prior process,
   replace the temporary store with the same pristine snapshot, launch the same Release executable,
   and use criterion 32's load-to-sentinel interval. Every recorded trial is at most 2.000 seconds.
4. Run the criterion-34 sequence—50 cycles of insert/delete at beginning, midpoint token boundary,
   and end, one action every 100 ms—for exactly 300 actions over 30 seconds with saves. Assert the
   fixture is restored after every pair: p95 below 50.000 ms, every interval and main stall at
   most 100.000 ms, zero full replacements/resync.
5. Scroll one continuous six-minute session: discard the first 60 seconds as warm-up, mark the
   Allocations baseline, then measure five minutes. Sample at measured seconds
   60/120/180/240/300 (total session seconds 120/180/240/300/360); use criterion 35's five-point
   OLS formula, end delta at most 5.0 MiB, and require no leak/stall/tick mutation/replacement/
   publish.
6. Pause and flush; final synthetic revision durable without edit stall.
7. Raw trace stays outside repo; record path and content-neutral values in `performance-result.md`.
8. Threshold failure is defect: trace-rooted RED, minimum fix, full rerun. Never relax number or
   disable privacy/persistence.

### 9.5 Physical display, reconnect, crash, quit

On same package/source SHA with Keynote and real extended projector/display, synthetic fixture:

1. Confirm private display and scroll with Keynote frontmost.
2. Disconnect after checkpoint; immediate pause/hide/shield and clean audience display.
3. Reconnect; wait 30 seconds proving no reveal/resume; explicitly confirm, then Show and Start.
4. After successful synthetic save, force `kill -9`; relaunch exact app; verify last committed
   anchor, shield-first paused/hidden restore, no runtime display reuse, explicit confirmation.
5. Ordinary Quit while scrolling; exact order, clean exit, no later callback/signpost, paused/
   hidden relaunch.
6. Flush failure uses injected tests only; never damage user Application Support.
7. Record additive `m5-display-crash-quit-result.md`; do not alter old overlay proof or imply
   M3/M4 closure.

### 9.6 Exact-SHA claim matrix

| Highest evidence | Permitted label |
|---|---|
| WSL/static only | `M5 WSL source candidate; M3/M4 native evidence pending` |
| Mac automated only | `M5 native automated candidate; no VoiceOver/display/Instruments claim; M3/M4 pending` |
| Accessibility manual only | `M5 accessibility candidate`; no lifecycle/performance completion |
| Lifecycle physical only | `M5 display/crash/quit candidate`; no 50k completion |
| Faster-than-baseline performance | `M5 performance provisional`; baseline pending |
| All M5 gates, M3/M4 pending | `M5 physically measured candidate; M3/M4/M5 completion blocked` |
| M3/M4 separately accepted and all M5 gates/reviews | `M5 complete`; M6 may be planned separately |

Authorization alone never promotes rows. Every result names exact source and executable SHA;
source-equivalent/rebuilt-unproven is disclosed, not equated.

## 10. Expanded test strategy

- **Unit:** semantics/ranges, fixture bytes, signpost balance/privacy, paused restore, generations,
  stale rejection, quit outcomes.
- **Integration/app host:** AppModel/effect order, TextKit edit/layout, AppKit accessibility/hit
  frames, display lifetime, actor save, display-link teardown/weak ownership.
- **UI/e2e physical-host:** the four canonical tests require an explicit flag and real extended
  non-mirrored display, confirm through the real shield, and fail on missing topology. App-host
  tests—not a fake display—provide topology-independent deterministic semantics. Neither proves
  VoiceOver speech or Keynote.
- **Physical e2e:** VoiceOver/keyboard/Inspector, disconnect/reconnect, crash/relaunch, quit,
  Keynote audience cleanliness, motion/contrast.
- **Observability/performance:** fixture, Release, signposts, Time Profiler/Hangs, Allocations,
  three loads, 300 edits, five-minute scroll, actor save.
- **Regression/static:** all applicable M0-M4 tests, analyze, Release, format, no-network/
  permission/logging, checksums/protected bytes/diff.

## 11. Deliberate pre-mortem

1. **Stale reconnect reveals content.** Old query arrives after newer disconnect/quit. Detect by
   hostile generations and 30-second wait; prevent by lifetime generation/quiescent rejection;
   recover paused/hidden/shielded with new confirmation.
2. **Instrumentation leaks or distorts.** Arbitrary metadata/per-tick allocation. Detect by
   mutation/sentinel and profile comparison; prevent typed static wrapper; invalidate affected
   trace/evidence and rerun synthetic.
3. **Nominal 50k pass hides stalls/host variance.** Window-only endpoint, averages, fast hardware,
   ignored memory. Detect semantic endpoint, every-trial limit, raw distribution/max, 100 ms
   Hangs, baseline/samples; keep provisional/failed and trace-root repair.
4. **Test isolation escapes into user storage.** A forged environment or symlink selects real
   Application Support. Detect every missing gate, traversal, symlink, and Release mutation;
   require DEBUG plus XCTest proof plus canonical temporary containment; reject rather than fall
   back to the requested path.
5. **Carbon cleanup is overstated.** Unregister returns failure after dispatch closes and a report
   calls refs released or retained. Detect order/result tests and wording audit; record only the
   typed cleanup outcome, finish exit after durable flush, and retry only after relaunch.

## 12. Risks

| Risk | Detection | Mitigation/stop |
|---|---|---|
| Hide waits on save | slow-store disconnect | enqueue then hide; never await |
| Staged called durable | crash wording test | distinguish staged/committed |
| Queued CG callback | injected callback | lifetime generation/quiescence |
| Test root escapes temp | env/path/symlink mutations | four gates plus canonical containment |
| Carbon result overclaims OS state | forced non-`noErr` result | content-neutral outcome; no ref claim |
| Vacuous accessibility | removed manifest mutation | exact nonzero set |
| Physical UI gate silently skipped | missing/removed-display run | explicit flag; prerequisite is failure |
| Release benchmark uses test override/user data | build/env/account audit | disposable account; normal store only |
| Focus steals Keynote | frontmost/key evidence | already-active controller only |
| Reader value in evidence | sentinel audit | boolean assertions/generic record |
| Metadata expands | API/mutation validator | closed enums/sole allowlist |
| Tick probes distort | profile comparison | no metadata/allocation |
| Threshold flakes | host matrix | opt-in baseline |
| Full replacement | counter in edit run | trace RED/minimum fix |
| M3/M4 mislabeled | claim schema | pending until separate evidence |
| M6 creep | path/token audit | focus/hit frame only |

## 13. Independent review and closure

1. Optional `code-simplifier` xhigh on changed M5 files only, then rerun all gates.
2. Independent `code-reviewer` high reviews correctness, privacy, races, signpost content/balance,
   measure validity, and M5-only scope.
3. Independent `verifier` high reconstructs commands, evidence, source/app SHA, traces, protected
   bytes, and claim row.
4. Independent `architect` high approves one authority, immediate-hide synthesis, no retained
   callback, and no M6/dependency/permission expansion.
5. Each finding becomes preserved review RED/minimum GREEN and all applicable gates rerun. No
   self-approval or completion with missing physical/baseline/predecessor evidence.

## 14. ADR-005 — typed hardening on existing product path

**Decision.** Keep AppModel/AppRuntime/TextKit/SnapshotStore as sole owners; add centralized
accessibility manifest, runtime-only topology generations, outcome-aware idempotent quit, static
typed OSSignposter, deterministic fixture, and additive M5 records.

**Drivers.** Fail-closed recovery; exact accessibility/performance evidence; content-neutral local
observability without new authority, permission, dependency, or schema.

**Alternatives considered.** Separate coordinator/benchmark; manual-only evidence; disk flush
before disconnect hide; arbitrary redacted metadata; logger/telemetry/crash service; automatic
reconnect resume.

**Why chosen.** It measures and hardens the actual path that captures anchors, applies reader
edits, and drains persistence. Typed generation/metadata prevent stale-callback/content-leak
classes without shadow state. Manual Mac gates remain necessary.

**Consequences.** Bounded integration hooks/tests. Immediate post-disconnect crash can lose only
not-yet-committed work; privacy never waits for flush. Local signposts carry no content. M5 may be
a measured candidate while M3/M4 remain blocked.

**Follow-ups.** If trace fails, `$performance-goal` may own only isolated evaluator-defined
optimization. M6 needs a separate plan after M0-M5 gates; this plan never starts it.

## 15. Available roles and staffing

Installed roster: `planner`, `architect`, `critic`, `executor`, `team-executor`, `test-engineer`,
`debugger`, `verifier`, `code-reviewer`, `code-simplifier`, `designer`, `researcher`, `writer`,
`git-master`, `explore`, `scholastic`, `vision`.

- `executor`, xhigh: exclusive shared AppModel/AppRuntime/lifecycle/signposter integration.
- `test-engineer`, xhigh: REDs, fixture, validator, evidence, replay manifest.
- `team-executor`, xhigh with disjoint paths only: accessibility views/UITests.
- `debugger`, xhigh after reproduced race/host/trace/retain failure only.
- `git-master`, high bounded: RED/GREEN ancestry and SHA ledger.
- `code-reviewer`, `verifier`, `architect`, high sequential closure.
- `code-simplifier`, xhigh before rerun. No designer; M6 forbidden.

One leader owns shared integration. Do not parallelize M5.2/M5.3 shared files. Accessibility and
fixture/validator lanes may overlap only after REDs and with disjoint ownership.

## 16. Goal-mode, Team, and exact Ralph handoff

### Goal-mode suggestions

- `$ultragoal` is the default durable-ledger alternative, optionally wrapping Team.
- `$performance-goal` only after reproduced threshold failure, not for all M5.
- `$autoresearch-goal` is inappropriate; this is implementation/verification.
- Owner explicitly requests Ralph, so it is the selected persistent fallback, not auto-started.

### Team plus Ultragoal launch hints

```text
$ultragoal Execute only the approved Private Presenter M5 plan. Ledger 0A/0B through 5A/5B,
WSL-to-Mac replay, exact-SHA evidence, review, pending M3/M4, stop before M6.

$team 3 Executor exclusively owns shared model/runtime/lifecycle/signposter integration;
test-engineer owns REDs/fixture/validator/evidence; team-executor owns accessibility view/UITest
paths. Never overlap shared files or call WSL native evidence.
```

Exact attached-tmux CLI equivalent—an inert handoff hint; **do not run during planning**:

```bash
omx team 3 --task 'Execute only the approved Private Presenter M5 plan at docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md from its exact plan commit. Executor exclusively owns shared AppModel/AppRuntime/lifecycle/signposter integration; test-engineer owns REDs, fixture, validator, replay ledger, and evidence; team-executor owns accessibility view and UI-test paths. Preserve M0-M4 history/evidence, keep M3/M4 native evidence pending, execute 0A/0B through 5A/5B test-first, never overlap shared files, never call WSL native evidence, stop before M6, and do not push.'
```

Team returns changed paths, RED SHA/expected/observed failure, GREEN SHA/result, and focused
commands. Leader runs aggregate gates; human Mac/VoiceOver/display/Instruments evidence stays
host-bound; Ultragoal owns final checkpoints and SHA.

### Exact Ralph handoff — do not run during Ralplan

```text
PLAN=docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md
PLAN_COMMIT="$(git log -1 --format=%H -- "$PLAN")"
test -n "$PLAN_COMMIT"
test "$(git rev-parse HEAD)" = "$PLAN_COMMIT"
git status --short

$ralph Implement only Private Presenter Milestone 5 from "$PLAN" at exact plan commit
"$PLAN_COMMIT". Owner authorizes immediate WSL candidate continuation from M4, but M3/M4 native
evidence remains pending and is not waived. Preserve every M0-M4 plan/result/history byte and one
AppModel/panel/TextKit/Carbon authority. Execute Lore pairs 0A/0B through 5A/5B test-first; label
WSL pairs unobserved; replay every exact RED/GREEN pair on controlled Mac; retain SHA ledger.
Implement exact VoiceOver/keyboard semantics, fail-closed disconnect/reconnect/crash/quit order,
typed static privacy-safe OSSignposter metadata, deterministic 50,000-word thresholds. Run full
Mac, VoiceOver/Full Keyboard Access, real Keynote/display/crash/quit, Release Time Profiler and
Allocations, exact-SHA evidence, then independent code-reviewer → verifier → architect. If M3/M4
native evidence remains pending, stop as `M5 physically measured candidate; M3/M4/M5 completion
blocked`. Do not enter M6, add dependencies/permissions/network/telemetry, rewrite prior evidence,
push, or amend WSL commits to imply native proof.
```

## 17. Consensus and publication record

Planner record, iteration 3:

1. Exact clean baseline/evidence inventory was verified before planning writes.
2. Dedicated native Planner `/root/planner` started with full task/context, exceeded the bounded
   240-second wait, produced no artifact, and was interrupted. The active standalone Planner lane
   produced iteration 1 per the Ralplan fallback contract.
3. Dedicated native Architect `/root/architect` then started with the full task, context, and
   iteration-1 draft, exceeded its bounded 240-second wait, produced no artifact, and was
   interrupted. Direct review under the installed Architect role returned **ITERATE**.
4. Planner revision 2 constrained the DEBUG/XCTest temporary-store gate; assigned exact
   signpost owners, completion/cancellation edges, and separate persistence intervals; preserved
   M4 Carbon cleanup truth; defined all 300 edit operations and the five-point OLS memory formula;
   and added unsafe test-root/cleanup-claim pre-mortems.
5. Direct Architect re-review approved iteration 2. Only then, dedicated native Critic
   `/root/critic` reviewed it and returned **ITERATE** on three reproducibility gaps.
6. Planner revision 3 makes the scroll run exactly six total minutes (60-second warm-up plus five
   measured minutes); defines snapshot-based load reset/endpoints, exact UTF-16 edit offsets, and
   nearest-rank p95; and makes confirmed-controller UI traversal a real extended-display,
   fail-on-missing-prerequisite gate while deterministic app-host semantics remain always runnable.
7. Direct Architect iteration-3 review approved revision 3
   (`.omx/drafts/m5-architect-review-iteration3.md`), after explicitly rechecking the timeline,
   snapshot/reset path, edit statistic, physical UI split, alternative, and residual risk.
8. Only after that approval, fresh dedicated native Critic `/root/critic_final` reviewed revision
   3 at SHA-256 `16e59713e3896af5c703820c742296d8ed077760c9635144f3ba9f66695b1e64`
   and returned **APPROVE** (`.omx/drafts/m5-critic-review-iteration3.md`).

Sequential consensus: **PLANNER READY → ARCHITECT APPROVE → CRITIC APPROVE**.

Runtime provenance limit: the native Planner and Architect threads exceeded their 240-second
bounds; the owner-authorized direct installed-role fallback supplied the approving Architect
decisions, and a fresh dedicated Critic approved iteration 3. OMX's tracker-only clean-completion
gate does not accept a direct Architect fallback, so the standard Plan Consensus cancellation
ended the active planning hook after the review artifacts were frozen. This tooling closeout limit
does not erase the sequential reviews, imply native product evidence, or itself authorize M5
implementation; the explicit Ralph/Team/Goal-mode handoff remains separate.

Applied review improvements: all Architect iteration-1 requirements and Critic iteration-2
requirements are incorporated. The inert concrete attached-tmux Team CLI hint is the sole
publication-time insertion allowed after terminal Ralplan state; it is validated but not executed.

Publish exactly the canonical target, commit only that plan with a Lore message, verify no other
tracked path, and stop without implementation or push. This consensus approves planning
readiness only; it supplies no M3, M4, or M5 native evidence.
