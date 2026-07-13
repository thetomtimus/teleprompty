# Private Presenter — Milestone 1 Core State and Local Durability

Status: **M1 IMPLEMENTED; MAC VALIDATION USER-REPORTED PASS; M0 STABILIZATION NEXT**
Planning date: 2026-07-12
Repository: `/home/thomas/teleprompty-review`
Planning baseline: `cca4229be4299eadc0370e8c26fae6f71e621ffc` on `main`
Implementation parent: `dfaec0b3b933aca46907003530dead19ae01babc` on `main`
Mac implementation exercised physically: `31dff6fdfa56a0987e0b76622c81939419096dbd`
Source plan: `IMPLEMENTATION_PLAN.md`, Milestone 1 (M1.1–M1.4)

## 1. Outcome and stop condition

Implement the smallest guarded foundation that gives Private Presenter typed script/session state, schema-aware local snapshots, crash-safe atomic storage, and one `@MainActor @Observable` command owner without expanding into the editor, scrolling engine, product hotkeys, menu bar, or final overlay UI.

This slice is complete only when:

1. every named M1 test is observed RED for the intended missing behavior, then GREEN;
2. all pre-existing M0 automated tests remain GREEN and the DEBUG proof harness remains launchable and operable;
3. core, app tests, analyze, Debug/Release builds, Swift format lint, structure, checksum, local-data, and no-network audits pass on macOS;
4. WSL/static checks pass without making Swift/AppKit claims;
5. `PRD.md` and the three visual source artifacts remain byte-for-byte unchanged;
6. code-reviewer, verifier, and architect approve independently;
7. the M0 physical record remains `BLOCKED`, with every unresolved M0 item still a gate before M2, beta use, or any readiness claim.

No app code was implemented in the original planning commit. Ralph subsequently
implemented the guarded slice, Hermes created the six logical commits from
`dfaec0b`, and Tom reported that the complete Mac verification plus proof-harness
smoke test passed. Raw Mac command logs were not attached to the repository, so
the Mac result remains explicitly user-reported rather than independently
reproduced from WSL. Source-level code-reviewer and architect reviews approved;
WSL/static verification passed independently. M1 is accepted for integration,
while M0 remains BLOCKED and stabilization remains mandatory before M2.

## 2. Sequencing amendment and M0 guardrails

Tom approved this narrow exception to the original M0 hard stop:

- **M1 may proceed now** because script state, schema migration, and local durability are substantially orthogonal to the observed overlay lifecycle defects.
- **M0 remains BLOCKED.** Do not edit `docs/validation/overlay-proof-result.md` to say PASS or reinterpret partial positive evidence as a completed gate.
- **M2 remains blocked.** After M1, run a dedicated M0 stabilization slice before controller/editor UI expansion. M2, beta use, release/readiness language, and the full acceptance sequence cannot start until a new physical run resolves and records every item below.

Must-fix/retest M0 gates:

1. reproduce and fix the initial Control-Option-H focus activation/full-screen interruption, exporting frontmost PID/bundle plus key/main-window state before and after show/lock;
2. make unlock, drag, and all eight resize directions operable during the full-screen proof, then record every intermediate frame at edges/corners and the adjacent-display boundary;
3. verify actual mirroring topology, exact warning text, pause/hide/block order, and no automatic reveal/resume;
4. compare `.floating` with `.statusBar` and retain only the lowest configuration passing the entire matrix;
5. place the overlay above genuinely bright Presenter Display pixels and prove opaque interior/rounded-mask behavior;
6. exercise explicit Space switching and full-screen exit/re-entry;
7. execute hostile stale-controller-frame, mirroring-while-visible, and private-display-disconnect recovery with shield-before-warning/reposition evidence;
8. physically observe/photograph the audience display and confirm no teleprompter pixel appears;
9. record exact topology/arrangement, separate-Spaces setting, cable/adapter, diagnostic export, and resolved local evidence paths.

M1.4 necessarily reroutes show/lock/privacy commands. Add call-recording seams proving it does not activate/raise the app or create key/main transitions, and keep unlock interaction plus direct diagnostic-hotkey dispatch operable. Fix any regression caused by this changed routing before M1 completes. A directly exposed, bounded root cause may be corrected, but do not expand M1 into the complete physical matrix or change the `BLOCKED` result; the dedicated stabilization slice remains mandatory immediately after M1.

## 3. Evidence boundary

Repository evidence establishes:

- `docs/validation/overlay-proof-result.md` is honestly `BLOCKED` for the 2026-07-12 physical run.
- Positive physical observations were limited to extended Keynote presentation placement, later overlay visibility, click-through/ordinary Keynote input/remote behavior, repeated toggles after the initial failure, and fail-closed disconnect/reconnect.
- The user identifies `31dff6f` as the tested Mac implementation. The repository does not contain raw automated logs or authoritative test counts, so this plan records the macOS automated run as **user-reported**, not independently reproduced by this WSL/Linux planning environment.
- At planning time WSL verification stopped at the obsolete no-remote assertion.
  The guarded implementation replaced it with exact expected fetch/push URL
  checks; the current WSL/source-static gate passes with `origin` intentionally
  set to `https://github.com/thetomtimus/teleprompty.git`.

No WSL command, mock, unit test, code review, or screenshot can convert the physical M0 result into PASS.

## 4. Scope

### In scope

- M1.1: `ScriptDocument`, `ReadingAnchor`, `TeleprompterPreferences`, `OverlaySession`, `KeyboardShortcut`, default shortcut map, and `PersistedSnapshot`.
- M1.2: explicit current schema, deterministic/idempotent v1 decode/migration, future-schema refusal, malformed-data reporting, and paused/hidden restore policy.
- M1.3: actor-isolated sandbox Application Support `SnapshotStore`, injected root/filesystem/clock/sleeper, 300 ms debounce, sibling temporary write + synchronization + atomic replace, latest-revision flush, malformed quarantine, and privacy-safe errors.
- M1.4: one authoritative `@MainActor @Observable AppModel`, typed `AppCommand`, state-before-effect ordering, playback/clear/relaunch guards, additive M0 harness compatibility.
- Static housekeeping: replace the obsolete no-remote assertion with an exact single-origin fetch/push URL assertion.
- Planning/hand-off truth: record the M1 sequencing exception without weakening the M0 gate.

### Out of scope

- Script editor or controller product UI; TextKit edit bridging.
- Scrolling engine, display link, reader viewport, active-band behavior, or position remapping after edits.
- Final overlay appearance, toolbar/header/Focus Mode polish, production lock UX, or M0 lifecycle redesign unless directly touched.
- Full shortcut customization or Carbon product registration; only core values/default map are modeled.
- Menu bar, status item, notifications, telemetry, logs containing user data, accounts, cloud, network, WebView/Electron/JavaScript, signing, notarization, distribution, M2+ behavior.

## 5. RALPLAN-DR decision record

### Principles

1. **Persist only durable intent.** Never persist playing state, runtime display IDs, current-session confirmation, transient alerts, or effect state.
2. **Do not lose the last known-good file.** A failed save cannot remove or truncate the current snapshot; unsupported future data is preserved in place.
3. **Keep core pure.** Codable models and migration live in Foundation-only `TeleprompterCore`; sandbox paths and file I/O stay in the app target.
4. **One command owner, effects second.** `AppModel` validates and mutates state before emitting typed effects; UI/adapters do not mutate independent product state.
5. **Preserve proofability.** M1 integration must retain the M0 DEBUG harness and its current automated tests while adding state foundations.

### Top decision drivers

1. Crash-safe local script durability without script disclosure.
2. Deterministic tests under Swift 6 strict concurrency.
3. Minimal integration risk while M0 remains physically blocked.

### Options

| Option | Benefits | Costs/risks | Decision |
| --- | --- | --- | --- |
| A. Foundation core schema/migrator + app actor store + AppModel; adapt the existing diagnostic model into a compatibility surface | Clean dependency direction; deterministic core tests; sandbox-aware app storage; one authority; preserves M0 call sites | Requires careful compatibility refactor and regression lock | **Chosen** |
| B. Put models and FileManager persistence entirely in the app target | Fewer directories initially | Couples schema to AppKit app; weaker WSL/core tests; violates approved boundary | Rejected |
| C. Keep `DiagnosticHarnessModel` and add an independent product `AppModel` beside it | Lowest immediate M0 diff | Creates two authorities for lock/pause/display state and invites divergence | Rejected |
| D. Replace the entire M0 harness/controller with M1 product architecture | Removes temporary naming quickly | Broadly touches the failing lifecycle and drifts into M2 | Rejected |
| E. Store the script in `UserDefaults` or use non-atomic direct JSON writes | Very small implementation | Privacy, size, corruption, and crash-safety violations | Invalid |

### ADR

**Decision.** Add the durable domain and migrator to `TeleprompterCore`; add an actor store and mechanically expand/rename the current M0 model into the single `AppModel`. Preserve the M0 methods and call patterns while updating their type references; do not retain a second model or compatibility facade. Use a JSON schema envelope at current version 1, an explicit migration switch, and a store-owned restore result that always constructs a hidden, paused runtime session.

**Consequences.** New files are discovered by existing recursive package/XcodeGen source paths. `project.yml` and `Package.swift` need no target/source/resource changes. The structure validator must learn the new required paths/tests. AppModel integration is the only M1 work with meaningful overlap with the M0 harness and therefore carries mandatory M0 regression tests.

**Follow-up.** The dedicated M0 stabilization slice immediately follows M1 and precedes M2. Later milestones may extend commands/schema only through explicit migrations and tests.

## 6. Exact model and schema contract (M1.1)

All types below are `public`, `Equatable`, `Sendable`, and `Codable` only when explicitly durable. All core source files import `Foundation` and nothing else.

### Paths

Create:

- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ReadingAnchor.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/TeleprompterPreferences.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/OverlaySession.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/KeyboardShortcut.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift`
- `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift`

### Values and defaults

- `ScriptDocument`: `schemaVersion: Int`, `id: UUID`, `title`, `text`, monotonically increasing `revision: UInt64`, `updatedAt: Date`. Factory/default schema is 1, title is exactly `Lecture Teleprompter`, text is empty, and revision is 0; inject the initial UUID/date in tests. Title normalization belongs to a later editor command, not the decoder.
- `ReadingAnchor`: `utf16Offset: Int`, bounded `contextBefore`/`contextAfter`, and `viewportFraction: Double`. Default is offset 0, empty context, and viewport fraction 0.5. Clamp offset to the document's UTF-16 bounds, retain at most 64 UTF-16 code units of context without splitting a surrogate pair, and clamp non-finite/out-of-range fractions to `0...1`; M3 owns edit reconciliation.
- `TeleprompterPreferences`: speed 60 points/s (range 10...240; step 5), font 42 pt (range 24...96; step 2), `.regular` weight from `.regular/.medium/.semibold`, `.left` alignment from `.left/.center`, active band on, Focus Mode on, unlocked, and an optional persisted `DisplayFingerprint`. Clamp range violations deterministically on construction/restore; do not silently quantize a valid non-step value.
- `ShortcutAction`: stable string cases `togglePlayback`, `increaseSpeed`, `decreaseSpeed`, `moveBackward`, `moveForward`, `toggleVisibility`, `toggleLock`.
- `ShortcutModifier`: stable string enum cases Control, Option, Shift, and Command. Persist a `Set<ShortcutModifier>` sorted by raw value when encoded; an unknown modifier string is malformed rather than silently ignored.
- `KeyboardShortcut`: `virtualKeyCode: UInt16` plus the semantic modifier set. The default map uses Control+Option with macOS virtual codes Space 49, Up 126, Down 125, Left 123, Right 124, H 4, and L 37, exactly matching the PRD actions. Carbon translation/registration remains M4.
- `OverlaySession` is transient and **not Codable**. It contains visibility, playback phase, `ReadingAnchor`, pixel offset, optional current-session display ID, chrome state, and recovery-confirmation state. Default/restore is hidden, paused, offset 0 unless a persisted anchor is supplied, no current-session display ID, and confirmation required.
- `PersistedPanelFrame`: one `DisplayFingerprint` plus one `NormalizedPanelFrame`. Persist a canonically sorted array rather than a dictionary keyed by a complex Codable value.
- `ShortcutBinding`: one stable `ShortcutAction` plus one shortcut. Persist a canonically sorted array rather than a dictionary whose ordering is undefined.
- `PersistedSnapshot`: `schemaVersion`, top-level monotonically increasing `revision`, `document`, `readingAnchor`, `preferences`, `[PersistedPanelFrame]`, and `[ShortcutBinding]`. The snapshot revision increments for every persistable change, including preferences/anchor/frames, independently of `document.revision`. It contains no `OverlaySession`, `isPlaying`, playback phase, raw/session display ID, current-session confirmation, warning, alert, or pending-effect value. Use one canonical JSON key per field and sorted-key encoding in tests.

Avoid duplicating frame/shortcut storage inside `TeleprompterPreferences`: keep user reading preferences there and persist display frames/shortcut bindings once at `PersistedSnapshot` top level. The AppModel projects these durable values into runtime state.

### Canonical v1 wire format

- `JSONEncoder`: `.sortedKeys` output formatting, `.millisecondsSince1970` dates, and default UTF-8/string escaping; `JSONDecoder` uses `.millisecondsSince1970`.
- Sort shortcut bindings by `ShortcutAction.rawValue`; sort each shortcut's modifiers by `ShortcutModifier.rawValue` through a private v1 DTO rather than relying on `Set` encoding order.
- Sort panel frames by the tuple `(uuid presence/value lowercased, vendor presence/value, model presence/value, serial presence/value, isBuiltIn, lastLocalizedName, confidence.rawValue)`. This is a comparator only; do not derive a filename or disclose it in diagnostics.
- Reject duplicate shortcut actions and duplicate canonical display-fingerprint identities as typed malformed v1 data. Do not pick a winner.
- Require `PersistedSnapshot.schemaVersion == PersistedSnapshot.currentSchemaVersion` and `document.schemaVersion == ScriptDocument.currentSchemaVersion`; version disagreement is malformed.
- Recursive exclusion tests parse the JSON object/arrays and inspect keys. Do not use raw substring tests because lecture text can legitimately contain words such as “playing” or “sessionID.”

### RED tests

In `CoreStateModelTests.swift`, add and first observe failure for:

- `testDefaultTitleAndPreferencesMatchPRD`
- `testFontRangeClampsTo24Through96`
- `testSpeedRangeClampsTo10Through240`
- `testDefaultShortcutMapMatchesPRD`
- `testReadingAnchorClampsWithoutSplittingUnicode`
- `testCodableRoundTripPreservesUnicodeScript`
- `testPersistedSnapshotExcludesPlayingState`
- `testPersistedSnapshotExcludesRuntimeDisplayID`
- `testCanonicalEncodingIsByteEqualForPermutedInput`
- `testDuplicateFrameAndShortcutEntriesAreRejected`
- `testUnknownShortcutModifierIsMalformed`
- `testSnapshotAndDocumentSchemaMustAgree`
- `testCoreProductionSourcesImportFoundationOnly` (static validator remains the primary source audit)

The Unicode fixture must include composed/decomposed accents, Korean, emoji with a skin-tone modifier, and a family ZWJ sequence. Inspect encoded JSON keys as well as round-tripping; a passing decoder alone does not prove excluded fields are absent.

## 7. Explicit migration contract (M1.2)

### Paths

Create:

- `Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/SnapshotMigrator.swift`
- `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/SnapshotMigratorTests.swift`

### Contract

- `PersistedSnapshot.currentSchemaVersion == 1` is the only current schema constant.
- `SnapshotMigrator` first decodes a minimal envelope containing only `schemaVersion`, then switches explicitly.
- Version 1 decodes through a private `V1Snapshot` wire DTO and maps to the current domain snapshot. Re-running migration on the canonical encoded result must produce an equal snapshot: no new UUID/date and no implicit revision change. Canonicalize optional v1 collections to sorted arrays.
- A schema greater than 1 throws typed `SnapshotMigrationError.unsupportedFutureSchema(found:supported:)`. The store leaves that file byte-for-byte in place; it is not quarantined or overwritten.
- Missing/non-integer schema, syntactically invalid JSON, invalid dates/UUIDs/enums, or invalid required fields report `SnapshotMigrationError.malformed` with privacy-safe metadata only. Never include raw JSON, title, context, or script in an error description.
- Schema 0/negative is `unsupportedLegacySchema`, reported without guessing. There is no undocumented pre-v1 production format to infer.
- `RestoredState(snapshot:)` (or an equivalent pure factory) always returns an `OverlaySession` that is hidden and paused, clears current-session display identity/confirmation, retains the semantic anchor, and marks privacy reassessment required.

### RED tests

- `testV1MigratesIdempotently`
- `testV1MigrationPreservesUnicodeAndRevision`
- `testUnknownFutureSchemaFailsWithoutDataLoss`
- `testUnsupportedLegacySchemaDoesNotGuess`
- `testRestoreAlwaysReturnsPaused`
- `testRestoreRequiresFreshPrivacyAssessmentBeforeShow`
- `testMalformedSnapshotIsReported`
- `testMigrationErrorsNeverContainScriptContent`

Use inline/generated JSON in tests; do not add resource fixtures, so `Package.swift` remains unchanged.

## 8. Atomic local storage contract (M1.3)

### Paths

Create:

- `PrivatePresenterApp/Interfaces/SnapshotFileSystem.swift`
- `PrivatePresenterApp/Interfaces/SnapshotScheduling.swift`
- `PrivatePresenterApp/Services/SnapshotStore.swift`
- `PrivatePresenterAppTests/SnapshotStoreTests.swift`

The interfaces are app-layer, Foundation-only protocols with `Sendable` test doubles. The production adapter wraps `FileManager`/`FileHandle`. Inject an explicit root URL in tests and a clock/sleeper that can be advanced without wall-clock sleeps.

### Production location

Resolve `.applicationSupportDirectory` in `.userDomainMask` inside the sandbox, then use:

`Private Presenter/current-snapshot.json`

Create the directory with user-only permissions where supported. Tests use a unique temporary root and never touch the developer's Application Support or `UserDefaults`.

### Actor API and invariants

`actor SnapshotStore` exposes the equivalent of:

- `load() async -> SnapshotLoadResult`
- `scheduleSave(_ snapshot: PersistedSnapshot) async`
- `flush() async throws`
- `discardPendingSave() async` only for controlled shutdown/tests; it must not delete the current snapshot
- observable privacy-safe diagnostics (codes/URLs/revisions, never content)

Rules:

1. Track `pendingSnapshot`, `persistedRevision`, canonical bytes/digest for the accepted equal revision, `debounceGeneration`, and a write-block latch.
2. Debounce scheduled saves for exactly 300 ms. Each accepted higher-revision snapshot increments the generation, replaces the pending value, and cancels/supersedes the prior sleeper. Do not use detached tasks.
3. A sleeper captures its generation and revision, then calls back into the actor after suspension. Immediately before writing, the actor rechecks the generation, pending revision, and write-block latch. A stale/canceled callback is a no-op.
4. A lower revision is rejected. Equal revision with byte-equal canonical payload is idempotent; equal revision with a different payload is a typed conflict and cannot write.
5. `flush()` increments the generation, cancels the sleeper, and commits the latest accepted pending snapshot exactly once before returning. A save arriving around flush cannot let an older callback win.
6. A failed write retains the pending snapshot for retry and does not advance `persistedRevision`. Successful load initializes both persisted revision and canonical payload identity.
7. No non-Sendable `FileHandle` or filesystem object crosses an `await`; all create/write/sync/close/rename work is one synchronous filesystem-adapter operation invoked after the actor's generation checks.
8. Encode off the main actor with the canonical v1 settings. No script-derived value enters a filename, log, notification, error text, or defaults key.
9. For each commit, exclusively create a user-only unique sibling temp. Fully write, synchronize, and close it. If the destination is absent, atomically rename/move the sibling; if present, atomically replace it. Where the platform adapter supports it, synchronize the parent directory before reporting success. Advance `persistedRevision` only after commit success.
10. Any pre-commit failure removes only the temp best-effort and preserves the prior destination.
11. Loading a valid v1 snapshot returns it through `SnapshotMigrator`, initializes store revision state, clears the write-block latch, and supplies a paused/hidden restore state.
12. Loading malformed data moves it to a deterministic injected-clock name such as `current-snapshot.malformed-20260712T180100000Z.json`, returns a recovery report, and leaves no raw content in the report. If quarantine fails, leave the source untouched, latch writes blocked, and return a typed recovery error.
13. Loading an unknown future schema leaves `current-snapshot.json` unchanged, latches writes blocked, and returns an unsupported-version result. While latched, `scheduleSave` rejects and `flush` throws a privacy-safe typed error; only a later successful supported load or explicit recovery API can clear the latch.
14. Quarantine collisions use a non-content suffix. Never delete existing quarantine files automatically.
15. Disk-full, permission, encode, synchronize, or replace failure keeps in-memory state available and the last known-good destination intact.

### RED tests

- `testProductionURLUsesSandboxApplicationSupportSubdirectory`
- `testSaveAtomicallyReplacesSnapshot`
- `testFailedReplacePreservesLastKnownGoodSnapshot`
- `testDebounceCoalescesRapidEdits`
- `testStaleRevisionCannotOverwriteNewerPendingSnapshot`
- `testEqualRevisionWithDifferentPayloadIsConflict`
- `testFlushPersistsLatestRevision`
- `testFlushCancelsPendingDebounceWithoutDuplicateWrite`
- `testSaveArrivingAroundFlushCannotLetStaleWriteWin`
- `testMalformedFileIsQuarantined`
- `testQuarantineFailurePreservesSourceAndBlocksWrites`
- `testFutureSchemaIsPreservedInPlace`
- `testFutureSchemaBlocksSubsequentSaveAndFlushWithoutChangingBytes`
- `testQuarantineCollisionDoesNotDeleteEvidence`
- `testFailedWriteRetainsPendingSnapshotAndPersistedRevision`
- `testScriptIsNeverWrittenToUserDefaults`
- `testDiagnosticsAndErrorsDoNotContainScriptContent`

Run tests against a filesystem spy that records create/write/sync/close/replace-or-move/parent-sync ordering and supports injected failure at each step. Real-temporary-directory integration tests on macOS cover both first save and replacement. APFS atomicity is a Mac verification claim; WSL may inspect only source and fake ordering.

## 9. One authoritative app state (M1.4)

### Paths

Create:

- `PrivatePresenterApp/App/AppCommand.swift`
- `PrivatePresenterApp/App/AppEffect.swift`
- `PrivatePresenterApp/App/DependencyContainer.swift`

Move/rename as required:

- `PrivatePresenterApp/App/DiagnosticHarnessModel.swift` → `PrivatePresenterApp/App/AppModel.swift`

Modify only as required:

- `PrivatePresenterApp/App/AppRuntime.swift`
- `PrivatePresenterApp/Controller/ControllerView.swift`
- `PrivatePresenterApp/Controller/ControllerWindowController.swift`
- `PrivatePresenterApp/Privacy/PrivacyCoordinator.swift`
- `PrivatePresenterApp/Privacy/PrivacyEffect.swift` (rename to a pure directive type or delete after folding it into the coordinator)
- `PrivatePresenterAppTests/AppModelTests.swift`

### Ownership and compatibility

- `AppModel` is `@MainActor @Observable final` and owns document, reading preferences, overlay session, persisted frames/shortcuts, display inventory/privacy assessment, and transient confirmation/error state.
- Mechanically move/rename the current `DiagnosticHarnessModel` implementation to `AppModel` and update its call sites/tests. Do not create a second model, wrapper, facade, or compatibility object with stored product state.
- `AppRuntime`, controller, overlay, DEBUG focus probe, diagnostic chord, and existing M0 tests must all resolve to the same AppModel instance. Preserve the current M0 properties/methods while routing them through typed commands incrementally.
- Do not replace the proof controller with editor UI. Existing select/show/lock/hide/shield/focus-diagnostic controls remain.

### Typed commands and effects

The bounded command set is:

- document: `.replaceScript(text:)`, `.requestClear`, `.confirmClear(token:)`, `.cancelClear`, `.completePreClearFlush(token:persistedRevision:succeeded:)`
- playback: `.start`, `.pause`, `.togglePlayback`, `.restart`
- overlay proof compatibility: `.showOverlay`, `.hideOverlay`, `.setLocked(Bool)`
- lifecycle: `.restore(PersistedSnapshot?)`, `.flushPersistence`
- privacy/display events needed by existing M0 harness remain typed rather than direct independent mutations

Use an unforgeable transient clear token created by `.requestClear`; `.confirmClear` is ignored if the token does not match the pending request. Never persist the token.

Each accepted command follows: validate against current state → mutate all authoritative state → build immutable effect payload(s) from the new state → invoke the injected effect handler. Effects include schedule/flush snapshot, show/hide/lock panel, and reassess privacy. Effect handlers never reach back to mutate AppModel synchronously.

Convert `PrivacyCoordinator` from a synchronous callback executor into a pure directive planner. Topology/display events enter `AppModel` as commands; the coordinator returns ordered `PrivacyDirective` values but invokes no handler. `AppModel` applies all pause/hidden/shielded/invalidation/confirmation state first, then maps external work into the single `AppEffect` stream (panel hide/order/lock, topology query, shielded window placement, persistence). Async effect completions return later through typed `AppCommand` cases and never synchronously re-enter the reducer. Retire or rename `PrivacyEffect` so it is not a second competing external-effect system; existing effect-order tests assert committed model state before the first adapter call.

### AppRuntime startup order

1. `DependencyContainer` creates one SnapshotStore and one external-effect adapter.
2. `AppRuntime` creates exactly one AppModel and injects that adapter.
3. The controller is created/shown shielded; overlay show is disabled.
4. Load the snapshot. AppModel restores only durable values, remains hidden/paused/shielded, and clears current-session display identity.
5. Start display observation, query/evaluate current topology, and require fresh current-session confirmation.
6. Register the diagnostic hotkey last. Its direct dispatch cannot reveal until both restore completion and current privacy prerequisites are satisfied.

On load error, remain shielded/paused and expose only content-neutral recovery state. Add a call-order integration test covering shield → load/restore → observe/query/evaluate → hotkey registration and proving no show effect can occur early.

Required invariants:

- empty/whitespace-only script cannot enter playing state;
- restart sets anchor/offset to zero and playback to paused before emitting persistence/viewport effects;
- restore applies durable data but forces hidden + paused, clears current-session display confirmation/ID, and emits privacy reassessment before any later show can be accepted;
- show is rejected until the current topology has a confirmed safe candidate;
- clear cannot occur through a direct unconfirmed command. `.requestClear` captures token plus document and snapshot revisions. Matching `.confirmClear` changes transient state to awaiting-pre-clear-flush and emits a flush effect while the script remains intact. Any intervening durable edit invalidates the request. Only `.completePreClearFlush(token:persistedRevision:succeeded:)` matching the token and both captured revisions empties text, increments document and snapshot revisions once, updates time via the injected clock, resets anchor, pauses, and emits an immediate non-debounced atomic save. Failed/stale completion preserves the script and reports only a content-neutral local error;
- emitted snapshot data never contains playing/runtime display state.

### RED and regression tests

Add the required M1 tests to `PrivatePresenterAppTests/AppModelTests.swift`:

- `testCommandsChangeStateBeforeEffects`
- `testEmptyScriptCannotStart`
- `testWhitespaceOnlyScriptCannotStart`
- `testRestartPausesAtBeginning`
- `testRelaunchReassessesPrivacyBeforeShow`
- `testAppRuntimeRestoreAndPrivacyOrderingBlocksEarlyShow`
- `testRestoreClearsCurrentSessionDisplayIdentity`
- `testClearRequiresConfirmedCommand`
- `testClearWaitsForSuccessfulPreClearFlush`
- `testFailedPreClearFlushPreservesScript`
- `testInterveningEditInvalidatesPendingClear`
- `testStaleClearCompletionCannotEraseScript`
- `testPostClearSnapshotPersistsImmediatelyWithoutDebounce`
- `testConfirmedClearIncrementsRevisionsAndPersistsEmptySnapshot`
- `testRuntimeAndControllerShareOneAuthoritativeModel`
- `testAppRuntimeConstructsExactlyOneAppModel`

Keep every existing M0 test in `AppModelTests.swift`, `OverlayPanelConfigurationTests.swift`, and `OverlayPanelControllerTests.swift`. Add focused regressions for the physical failure where automatable:

- showing a nonactivating panel does not call `NSApp.activate`, `showWindow`, or make key/main;
- locking/unlocking never activates the application;
- the diagnostic global chord dispatches directly to the command owner without opening/raising the controller;
- overlay interaction is disabled only while locked and restored when unlocked.

These regressions do not close the physical M0 gate.

## 10. Project, package, target, and script determination

### `project.yml`

**No target/source changes are required.** The app and test targets already recursively include `PrivatePresenterApp` and `PrivatePresenterAppTests`; the new app/interface/store/test files are discovered automatically. The package remains a local dependency of both targets. Do not add a target, dependency, entitlement, build phase, or resource.

After generation, prove membership rather than editing the manifest speculatively:

```bash
./Scripts/bootstrap-macos.sh
xcodebuild -list -json -project PrivatePresenter.xcodeproj
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

### `Package.swift`

**No change is required.** SwiftPM discovers the new source/test files recursively. Inline migration fixtures avoid a resources declaration. `TeleprompterCore` continues to import Foundation only.

### `Scripts/validate_project_structure.py`

Update required paths and named-test inventory for M1, retain every M0 marker/test, update its success label to “Milestone 0–1 source,” and keep the Foundation-only import audit. Do not make static marker presence a substitute for Swift tests.

### `Scripts/verify-wsl.sh`

Replace `test -z "$(git remote)"` with exact checks:

```bash
expected_origin='https://github.com/thetomtimus/teleprompty.git'
test "$(git remote)" = 'origin'
test "$(git remote get-url origin)" = "$expected_origin"
test "$(git remote get-url --push origin)" = "$expected_origin"
```

Keep checksum/no-network checks and update the preservation baseline from obsolete `a58afbd` to the planning/implementation parent or use `sha256sum -c` as the canonical byte-preservation check. Do not fetch or mutate remote state in WSL static verification.

### Privacy/static audit

Extend source validation (or a small stdlib/shell audit, no dependency) to reject product use of `UserDefaults`, raw `print`/logger/interpolation of document/title/text/anchor context, and user notification payloads derived from script state. Allow test spies and explicit prohibition comments narrowly. Static scanning supplements, not replaces, runtime store tests and review.

## 11. TDD execution order and exact commands

Use one smell/behavior slice at a time. For each numbered task: add only its named tests, run the targeted command and capture the intended RED, implement the minimum, rerun targeted GREEN, then run all prior M1 tests plus M0 regression tests.

### M1.0 Guard/preflight

```bash
git status --short --branch
planning_commit="$(git log -1 --format=%H -- docs/plans/2026-07-12-milestone-1-core-state-durability.md)"
test "$(git rev-parse HEAD)" = "$planning_commit"
test "$(git branch --show-current)" = 'main'
test "$(git remote)" = 'origin'
test "$(git remote get-url origin)" = 'https://github.com/thetomtimus/teleprompty.git'
sha256sum -c docs/validation/source-artifact-checksums.sha256
! ./Scripts/verify-wsl.sh  # known RED only at the obsolete no-remote assertion
# First implementation edit: apply the exact-origin housekeeping change in section 10.
./Scripts/verify-wsl.sh    # must then be GREEN before M1.1
```

Record that `docs/validation/overlay-proof-result.md` begins and ends M1 as `BLOCKED` unless a separate, complete physical rerun actually changes it.

### M1.1 Models/defaults

```bash
swift test --package-path Packages/TeleprompterCore --filter CoreStateModelTests
swift test --package-path Packages/TeleprompterCore
```

### M1.2 Migration/restore

```bash
swift test --package-path Packages/TeleprompterCore --filter SnapshotMigratorTests
swift test --package-path Packages/TeleprompterCore
```

### M1.3 Atomic store

```bash
./Scripts/bootstrap-macos.sh
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests
```

### M1.4 AppModel + M0 compatibility

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
```

### Full macOS automated gate

```bash
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = 'Version: 2.45.4'
python3 Scripts/validate_project_structure.py
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-macos.sh
```

The skipped placeholder UI shell and the complete physical M0 gate remain separate. Launch the DEBUG harness on the Mac for a smoke check of select/confirm/show/hide/lock/unlock and diagnostic focus capture; call it a harness smoke check, not a physical gate pass.

### WSL/source-static gate

```bash
bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py
git diff --check
test "$(cat .xcodegen-version)" = '2.45.4'
git check-ignore -q PrivatePresenter.xcodeproj/project.pbxproj
! git ls-files --error-unmatch PrivatePresenter.xcodeproj/project.pbxproj >/dev/null 2>&1
sha256sum -c docs/validation/source-artifact-checksums.sha256
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
```

WSL may prove only file shape, policy scans, Git configuration, checksums, and shell/Python behavior. It cannot claim Swift compilation, actor behavior, atomic filesystem semantics on APFS, AppKit behavior, or physical privacy.

## 12. Logical Lore commits

Keep commits reviewable and do not combine the still-unresolved M0 physical fix with unrelated state work.

1. **Keep repository verification aligned with the intentional GitHub origin** — replace only the obsolete no-remote assertion and observe WSL RED→GREEN.
2. **Make durable state explicit without persisting runtime playback** — core models/default shortcut map + RED/GREEN model tests.
3. **Refuse unsafe snapshots without guessing at user data** — v1 migrator/restore policy + RED/GREEN migration tests.
4. **Preserve the last good local script across interrupted saves** — actor store, filesystem/scheduler seams, quarantine + RED/GREEN store tests.
5. **Route script and session commands through one state owner** — AppModel/command/effect integration, diagnostic compatibility, M0 regression lock.
6. **Make M1 source and privacy invariants auditable** — update validator inventory/data-safety checks and rerun every static/Mac gate.

Each commit message follows the repository Lore trailers and names exact tested/not-tested boundaries. Never write “M0 passed.”

## 13. Data safety, rollback, and recovery

- Before changing schema/store code, copy a synthetic v1 snapshot in tests; never use real lecture content.
- The implementation must read before it writes on startup. Unknown future schema blocks writing and stays in place.
- A failed migration/save/replace must leave the last known-good file or quarantine evidence intact and keep the in-memory document available.
- Roll back code commits normally, but do not downgrade or overwrite a snapshot whose schema exceeds the rolled-back app's supported version.
- If a post-merge defect is found, revert AppModel wiring separately from the core schema/store commits where possible. The DEBUG M0 harness must remain available at every commit boundary.
- Never print snapshot JSON or include it in test failure messages, crash annotations, notifications, Git fixtures, or committed validation media.
- Destructive clear is user-confirmed, revisioned, and atomically persisted; no silent file deletion is a substitute.

## 14. Deliberate pre-mortem

1. **Debounce/flush race loses the newest script.** Trigger: a canceled sleep writes after flush or a stale revision wins. Prevention: actor serialization, generation/revision checks, deterministic manual scheduler tests. Recovery: preserve current destination, keep in-memory text, retry explicit flush, never delete the prior file.
2. **Migration destroys a snapshot from a newer app.** Trigger: generic decode failure is treated as corruption and quarantined/overwritten. Prevention: decode schema envelope first; preserve future version in place; block save. Recovery: surface supported/found versions without content and require a compatible app.
3. **AppModel refactor breaks the already-fragile M0 harness.** Trigger: two models diverge or controller show/lock paths activate the app. Prevention: mechanically move/rename the existing authority, keep one instance, run all existing M0 tests plus activation/unlock regressions, then perform a DEBUG Mac smoke check. Recovery: revert only the wiring commit and retain independently tested core/store commits.

## 15. Review, staffing, and execution gates

Available roles: `executor`, `test-engineer`, `debugger`, `architect`, `critic`, `code-reviewer`, `verifier`, `code-simplifier`, `explore`, `planner`, and `writer`.

Recommended Ralph staffing:

- `test-engineer` (xhigh): own RED tests, deterministic actor/filesystem seams, and evidence matrix;
- `executor` (xhigh): implement one M1 task/commit at a time;
- `debugger` (xhigh): only when Swift concurrency, APFS replacement, or M0 regression evidence fails;
- `code-reviewer` (high): privacy, lost-update, schema compatibility, and scope review after implementation;
- `verifier` (high): rerun exact targeted/full commands independently on macOS and inspect artifacts;
- `architect` (xhigh): final authority on single-owner state, core/app boundary, data safety, and preserved M0 gates;
- `code-simplifier` (high): optional changed-files-only pass after green tests, followed by complete re-verification.

Required approval order before completion/push: code-reviewer APPROVE → verifier PASS with command evidence → architect APPROVE. A role may not approve based solely on another role's summary.

### Execution-lane guidance

- **Explicit Ralph fallback (selected for this handoff):** one persistent owner executes M1.1 → M1.4 sequentially, dispatching the bounded roles above and stopping before M2.
- **`$ultragoal` alternative:** appropriate if the maintainer wants a durable goal ledger; create one goal per M1 task and keep M1.4 dependent on M1.1–M1.3.
- **`$team` alternative:** use only after the model/schema contract is fixed. Safe parallel lanes are core models/migration and store test-seam preparation; AppModel integration stays single-owner after both land.
- **`$ultragoal` + `$team`:** Ultragoal owns the milestone ledger; Team returns checkpoint-ready test/commit evidence. Do not parallelize two writers in `AppModelTests.swift` or app runtime files.
- `$autoresearch-goal` is not appropriate because this is implementation, not open-ended research. `$performance-goal` is deferred to the later measured 50,000-word slice.

Optional Team launch hint:

```text
$team Execute only M1.1–M1.4 from docs/plans/2026-07-12-milestone-1-core-state-durability.md.
Assign test-engineer to RED tests/evidence, executor to bounded implementation, and
verifier to the integrated Mac gate. Keep AppModel integration single-owner, preserve
the BLOCKED M0 record, and stop before M2.
```

Team verification path: targeted core tests → full core tests → SnapshotStore app tests → AppModel plus all M0 app tests → analyze/Release build/format → static/privacy/checksum audits → DEBUG harness smoke → code-reviewer → independent verifier → architect.

## 16. Push safety

Push is authorized only after the independent approvals and all macOS/WSL gates above pass. From a clean `main` checkout:

```bash
test "$(git branch --show-current)" = 'main'
test -z "$(git status --porcelain)"
test "$(git remote)" = 'origin'
test "$(git remote get-url origin)" = 'https://github.com/thetomtimus/teleprompty.git'
test "$(git remote get-url --push origin)" = 'https://github.com/thetomtimus/teleprompty.git'
git fetch --prune origin
read behind ahead <<EOF_COUNTS
$(git rev-list --left-right --count origin/main...HEAD)
EOF_COUNTS
test "$behind" = '0'
test "$ahead" -gt '0'
git push --porcelain origin HEAD:main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Do not force-push, push from a dirty tree, push if behind/diverged, or push any physical evidence containing unrelated/private screen content.

## 17. Exact Ralph handoff

```text
$ralph Implement docs/plans/2026-07-12-milestone-1-core-state-durability.md
exactly as a guarded M1-only TDD slice from its planning commit. The explicit
2026-07-12 sequencing amendment permits M1.1–M1.4 even though
`docs/validation/overlay-proof-result.md` remains BLOCKED; do not rewrite that
result or claim M0 passed. Preserve the existing DEBUG proof harness through one
authoritative AppModel and keep every M0 automated regression green. Do not
start editor/scrolling/product-hotkey/menu/visual/M2 work. After M1, stop before
M2 and hand off to a dedicated M0 stabilization slice covering focus/full-screen,
unlock/drag/resize, mirroring, opacity, boundary, level comparison, hostile
recovery, Space switching, and physical audience evidence. Use the exact paths,
RED→GREEN tests, commands, Lore commits, data-safety/rollback rules, Mac-vs-WSL
claims, and origin checks in the companion plan. Preserve PRD.md and all visual
source artifacts byte-for-byte. Completion requires independent code-reviewer
APPROVE, verifier PASS, and architect APPROVE; then push is authorized only if
main is clean, origin URLs are exact, fetch shows zero behind, and a normal
non-force push succeeds.
```

## 18. Consensus record

Completed sequential review:

- Planner: **READY FOR ARCHITECT REVIEW**. Chose Foundation models/migrator → actor store → mechanical expansion of the existing M0 model, confirmed no project/package target changes, and required the M0 stabilization gate before M2.
- Architect iteration 1: **ITERATE**. Required one model/effect system, explicit startup ordering, write-blocked future/quarantine failure states, generation-safe debounce/flush, exact atomic paths and canonical v1 wire rules, revision-bound clear, and a bounded M0 overlap rule.
- Architect iteration 2 (after revisions): **APPROVE**. Found the plan architecturally sound, data-safe, bounded, and executable without product questions; retained the macOS filesystem adapter as a verification risk rather than a planning blocker.
- Critic (after Architect approval): **APPROVE**. Confirmed principle/option consistency, bounded scope, explicit data-safety/race handling, executable tests/commands, correct no-project-change determination, honest environment/evidence boundaries, complete M0 guardrails, and actionable rollback/push/Ralph gates.

Consensus completed in the required Planner → Architect → Critic order. At the
time, planning approval authorized only the Ralph handoff above; the subsequent
guarded execution is recorded below and does not retroactively change that
planning-run boundary.

## 19. Guarded execution record — 2026-07-12

### Source inventory and scope stop

The uncommitted working tree contains only the approved M1 slice plus the
bounded M0 compatibility wiring it directly touches:

- **M1.1:** durable model/default/shortcut sources, `PersistedSnapshot`,
  canonical v1 coding, and `CoreStateModelTests.swift`;
- **M1.2:** explicit v1 migrator, future/legacy refusal, malformed handling,
  paused/hidden privacy-reassessment restore, and `SnapshotMigratorTests.swift`;
- **M1.3:** actor-isolated `SnapshotStore`, injected Foundation-only filesystem
  and scheduler seams, debounce/flush/revision ordering, quarantine and
  write-block safety, privacy-safe diagnostics, and `SnapshotStoreTests.swift`;
- **M1.4:** one `@MainActor @Observable AppModel`, typed commands/effects,
  dependency container, pure privacy directives, startup/test seams, mechanical
  M0 harness compatibility, and additive `AppModelTests.swift` /
  `OverlayPanelControllerTests.swift` regressions;
- **audits:** M1 path/named-test inventory, retained Foundation-only core audit,
  product data-safety scanning, and exact expected `origin` fetch/push URL checks.

No M2/editor/scrolling/display-link/product-hotkey/menu/status-item/accounts/
cloud/network/WebView/Electron/JavaScript/telemetry/signing/notarization/
distribution work was added. `project.yml`, `Package.swift`, `PRD.md`, the three
visual source artifacts, and `docs/validation/overlay-proof-result.md` were not
modified by this slice.

### RED/GREEN and WSL evidence boundary

The exact environment-limited RED evidence is:

```text
$ command -v swift
[exit 1]

$ ./Scripts/bootstrap-macos.sh
error: bootstrap-macos.sh requires macOS.
[exit 1]
```

Therefore this WSL run did **not** observe the named Swift tests behavior-RED or
GREEN and did not run Xcode, AppKit, Swift concurrency, APFS atomic-replacement,
analyze, Release-build, or swift-format validation. The named test sources and
corresponding implementation are present for the prescribed Mac RED→GREEN
sequence; the environment failures above must not be represented as application
test failures or passes.

Fresh WSL-safe results from the repository root:

```text
bash -n Scripts/bootstrap-macos.sh Scripts/verify-macos.sh \
  Scripts/verify-no-network.sh Scripts/verify-wsl.sh                 exit 0
python3 Scripts/validate_project_structure.py                        exit 0
  Project structure validation passed (Milestone 0–1 source).
git diff --check                                                     exit 0
XcodeGen pin and generated-project ignore/untracked checks           exit 0
sha256sum -c docs/validation/source-artifact-checksums.sha256        exit 0
./Scripts/verify-no-network.sh                                       exit 0
./Scripts/verify-wsl.sh                                              exit 0
exact origin name/fetch/push URL checks                              exit 0
```

Protected SHA-256 values at closeout:

```text
3980ec241d38901ef434b93afa3935ce5b8c3d1a14849ae2417ec6a940138f3d  PRD.md
b3c0e19bbef6285ece0fffa045032a806ccf915b8bb8415184e74f6556af2a2a  design/concept.html
d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e  design/teleprompter-concept.png
352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92  references/teleprompter-ui-reference.png
e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da  docs/validation/overlay-proof-result.md
```

### Mac verification and review follow-up

Tom reported that the complete Mac verification commands and the existing DEBUG
proof-harness smoke test passed for the six-commit M1 stack ending at
`88d28cb950c4b2628075aaa408b8e7716864ae31`. Raw Mac command logs were not
attached to the repository, so this is recorded as a user-reported platform pass,
not an independently reproduced WSL result. Source-level code-reviewer and
architect reviews approved, and Hermes independently reran the WSL/static gates.

### Git/push and next-slice state

- Branch is `main`; fetch and push URLs both exactly equal
  `https://github.com/thetomtimus/teleprompty.git`.
- Hermes created the six logical commits from `dfaec0b`; the implementation stack
  ends at `88d28cb950c4b2628075aaa408b8e7716864ae31`.
- A fresh fetch showed the local stack six commits ahead and zero behind
  `origin/main`; the working tree was clean before this documentation closeout.
- A normal non-force push is authorized after this closeout commit and one final
  WSL/static/origin safety check.

M0 remains **BLOCKED** and
`docs/validation/overlay-proof-result.md` remains byte-for-byte unchanged. M2,
beta use, and readiness remain blocked. The next implementation slice is the
dedicated M0 stabilization and focused physical rerun described in section 2;
stop before every M2 or product-polish surface.
