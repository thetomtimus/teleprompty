# Private Presenter — Milestone 3 Smooth Rehearsal Scrolling

Status: **CONSENSUS APPROVED — CANONICAL PUBLICATION PENDING**

Planning baseline: exact clean `main` at
`802953089e88369e2a8e9fb744f4e32b30d9727d` (`origin/main` at intake)  
Canonical publication target:
`docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md`  
Scope authority: `IMPLEMENTATION_PLAN.md:548-555`, M3.1–M3.4 only  
Execution boundary: this Ralplan run writes and commits this plan only; it does not
implement M3 or enter an execution workflow.

## 1. Outcome, authorization, and hard stop

Deliver the shortest safe first usable rehearsal-scrolling alpha:

1. a pure elapsed-time `ScrollEngine` whose result is independent of callback count and
   display refresh rate;
2. a UTF-16/scalar-safe `ReadingPositionMapper` that preserves the reading position over
   incremental edits and layout changes;
3. one transparent, clipped, noneditable/nonselectable TextKit 2 reader viewport over an
   opaque card and fixed active band; and
4. one attached-reader-view display-link session that moves only the clip origin per frame
   and never publishes frame-rate state through `AppModel`, Observation, or SwiftUI.

M3 also makes controller Start, Pause, Restart, speed, Back, and Forward real. Back and
Forward are visible controller commands only; M4 product/global input is not pulled
forward.

Implementation stops at M3 when all named RED→GREEN stages, existing M0–M2 regressions,
controlled-Mac package/app-host gates, the focused physical scrolling smoke, exact-SHA
evidence, and independent review pass. It must not implement M4 hotkeys, Focus Mode,
menu-bar behavior, Accessibility/event taps/global monitors, focus-return hacks, M5
hardening, M6 polish, network, dependencies, schema migration, entitlements, or redesign.

## 2. Baseline truth and protected behavior

The baseline already has the seams M3 must extend, not replace:

- one `@MainActor @Observable AppModel` is the reducer/observable authority
  (`PrivatePresenterApp/App/AppModel.swift:5-55,178-268`);
- one `OverlayPanelController` creates one `TeleprompterPanel`, one reader system, and one
  hosting root (`PrivatePresenterApp/Overlay/OverlayPanelController.swift:45-59,97-135`);
- the selected proof configuration is `.statusBar + frontRegardless`, without activation,
  key, or main status (`OverlayPanelController.swift:158-183,274-312` and
  `TeleprompterPanel.swift:69-103`);
- editor and reader are separate TextKit 2 stacks; the reader is noneditable/nonselectable
  and its incremental transaction plus one latched resync are synchronous on the main
  actor (`ReaderTextSystem.swift:11-23,25-51,53-119,167-172`);
- AppModel owns the persisted document and applies revisioned edits before its one reader
  effect (`AppModel.swift:428-454`); the adapter connects the synchronous reader-resync
  callback directly to the reducer (`DependencyContainer.swift:67-96,98-127`);
- frame feedback alone is intentionally deferred with `Task.yield()`
  (`DependencyContainer.swift:73-83`); M3 must not copy that delay into reader resync;
- `ReadingAnchor` already persists a UTF-16 offset, independent before/after contexts of at
  most 64 UTF-16 units, and a clamped viewport fraction, default `0.5`
  (`ReadingAnchor.swift:3-31,51-88`);
- speed already persists in schema v1 at default 60 pt/s and range 10–240 pt/s
  (`TeleprompterPreferences.swift:14-23,31-57`), while playback remains runtime-only and
  restored paused (`OverlaySession.swift:8-29`; `PersistedSnapshot.swift:29-55`);
- the reader clip is currently deliberately static and the 36-point header is outside it
  (`ReaderTextView.swift:4-16`; `OverlayRootView.swift:34-49`); M3 replaces only the static
  lockout, not the one-panel/opaque-card structure;
- hide and privacy reducers already expose the exact ordering seam that must be strengthened
  with synchronous scroll stop/capture before `.hidePanel`
  (`AppModel.swift:753-783,849-898,930-980`).

Preserve the following throughout implementation:

- one main-actor AppModel and one AppKit-owned panel;
- `.statusBar + frontRegardless`, nonactivation, permanent non-key/non-main behavior,
  selected-display containment, opaque hosted card, and audience isolation;
- separate editor/reader TextKit 2 storage, M2 revision validation, incremental reader edit,
  exactly one authoritative resync for a contiguous gap/application failure, and no task
  yield in that resync path;
- schema v1, paused restore, durability and pre-clear flush, display confirmation/privacy,
  content-neutral diagnostics, local-only storage, and no private content in evidence;
- `PRD.md`, `IMPLEMENTATION_PLAN.md`, design/reference assets, all M0 validation evidence,
  `docs/validation/m2-controller-editor-display-safety-result.md`, and the canonical M0/M2
  plans byte-for-byte.

## 3. Requirements and testable acceptance criteria

1. Equal elapsed uptime produces equal displacement within `1e-9` engine tolerance for
   60 Hz, 120 Hz, dropped-frame, and mixed schedules; callback count alone has no effect.
2. `start(at:)` records the start uptime, so the first later tick advances. A valid delta in
   `0...0.5` seconds advances by old speed × delta. Negative, nonfinite, or `>0.5` deltas
   advance zero, invalidate the baseline, and edge-trigger one paused stop.
3. Pause preserves exact offset. A speed/manual command while playing first settles a
   wholly valid interval at the old speed. Restart sets offset zero and leaves playback
   paused. Reaching maximum clamps and publishes one paused transition only.
4. A bound change is legal only while paused. Back/Forward moves by exactly three complete
   TextKit 2 line fragments when available; otherwise by
   `clamp(0.15 * clipHeight, 80...240)` points. It works while playing or paused.
5. Mapper input includes the pre-edit document, post-edit document, edit range, replacement,
   and prior anchor. The mapper validates signed ranges, addition/subtraction overflow,
   pre/post result equality, and scalar boundaries itself; malformed input clamps and
   requests pause instead of trapping or guessing.
6. Ordered edit mapping is unambiguous: insertion strictly before shifts; insertion exactly
   at the anchor clamps there and pauses; nonempty edit ending at/before shifts; edit
   starting strictly after preserves; every remaining overlap/touch case clamps to the
   post-edit lower scalar boundary and pauses.
7. Context recovery compares before and after context independently at scalar boundaries,
   prefers exact two-sided matches, then greatest semantic match and one unique nearest
   distance. Equal winning ties or no candidate clamp the normalized old offset and pause;
   no arbitrary lower match wins.
8. The hosted reader stack is opaque background → fixed active band → transparent clipped
   reader. The band is exactly 84 points high, centered at the persisted anchor
   `viewportFraction` (default `0.5`), stationary during ticks, non-hit-testing,
   accessibility-ignored, and never a text selection.
9. The document reserves exactly 64 points of bottom padding. Maximum offset is
   `max(0, laidOutTextBottom + 64 - clipHeight)`; the existing 36-point header is outside
   the clip and is not counted again.
10. A tick changes only `NSClipView.bounds.origin.y`; it writes zero text-storage bytes.
    Edit/font/alignment/resize capture semantic position before invalidation, lay out, then
    restore with `clamp(anchorY - clipHeight * viewportFraction, 0...maximumOffset)`.
11. The production clock is created only from the actual attached hosted reader view with
    `view.displayLink(target:selector:)`, consumes `CADisplayLink.timestamp`, is added to
    `.main` in `.common`, and is explicitly invalidated on every stop, hide, end, detach,
    attachment replacement, screen move, privacy loss, reader replacement, and teardown.
12. Clock creation/attachment failure yields `clockUnavailable` and exactly one matching
    AppModel playing→paused transition. Detach/recreation never auto-resumes and clock,
    view, and controller owners deallocate after teardown.
13. AppModel alone issues opaque UUID session generations and is the sole observable
    playback authority. Speed alone does not issue a generation. Ticks never enter
    AppModel. Arbitrary stale callbacks are inert.
14. Semantic checkpoint publication is at most once per uptime second; accepted crash loss
    is at most one second. A separately authorized synchronous terminal capture from the
    retiring generation is accepted once even after replacement generation issuance.
15. Stop/capture/invalidate completes before panel order-out, topology/shield movement,
    privacy loss, clear, reader edit/replacement/resync, restore, attachment replacement,
    or teardown. Resync performs no task yield and remains paused after a gap/failure.
16. Controller Start/Pause/Restart/speed/Back/Forward are visible, functional, and covered
    by presentation/reducer tests; Focus Mode stays visibly disabled and no product/global
    key handling is added.
17. All 25 canonical tests retain their exact names, every added test below passes, the
    entire package/app suites regress cleanly, and the same exact-SHA packaged app passes
    the focused real-Mac/Keynote scrolling smoke.
18. WSL/static results make no Swift, TextKit, AppKit, display-link, package, refresh-rate,
    or physical claim. App-host test materialization failure is a blocking M3 failure; the
    M2 owner waiver does not carry forward.

## 4. RALPLAN-DR decision record

### Principles

1. **Elapsed time, not frames, is policy.** Refresh rate is only a delivery cadence.
2. **Keep the hot path below Observation.** Per-frame work is transient AppKit state.
3. **Capture before invalidation.** Semantic position is captured before edit/layout/privacy
   boundaries and restored only from validated text and current geometry.
4. **One authority, explicit generations.** AppModel owns observable playback and UUID
   capabilities; the session owns only the current engine/clock/viewport mechanics.
5. **Extend proven M2 safety.** Privacy, resync, persistence, focus, containment, and
   evidence boundaries are preserved rather than reimplemented.

### Top decision drivers

1. Refresh-independent smoothness without per-frame SwiftUI/AppModel publication.
2. Exact, deterministic position preservation across Unicode edits and TextKit relayout.
3. No regression in private-display, focus, one-panel, durability, or evidence truth.

### Viable options

#### Option A — pure core plus AppKit viewport/session (**chosen**)

- **Approach:** keep engine/mapper in Foundation-only TeleprompterCore; keep clip geometry,
  TextKit layout, display-link attachment, and hot ticks in one main-actor AppKit session;
  send only bounded semantic/terminal outcomes to AppModel.
- **Pros:** deterministic unit tests; correct AppKit lifecycle ownership; no display-rate
  Observation; fakes for engine/session; shortest path from the current reader bridge.
- **Cons:** needs generation-bearing effects/callbacks and strict stop-result validation.

#### Option B — `@ObservationIgnored` engine inside AppModel

- **Approach:** AppModel owns the engine and hidden hot offset; display link is a timestamp
  source and viewport is a sink.
- **Pros:** simpler nominal authority and fewer cross-object generations.
- **Cons:** entangles reducer state with attachment, TextKit geometry, clip motion, and
  display-link teardown; makes privacy/layout ordering harder to isolate and test.

#### Option C — SwiftUI timer/binding or generic `Timer`/`CVDisplayLink`

- **Approach:** publish offsets through SwiftUI or drive a non-view-bound clock.
- **Pros:** superficially fewer AppKit types.
- **Cons:** violates refresh independence/hot-path isolation or loses view/display lifecycle
  binding; rejected as unsafe for this alpha.

### Tension and synthesis

Checkpointing every frame would minimize crash-position loss but violate hot-path
isolation. Never checkpointing would protect the hot path but can lose the entire session
position. The synthesis is at-most-1-Hz semantic checkpoints in the same uptime domain,
plus a separately authorized synchronous terminal capture. This accepts at most one second
of crash loss while preserving precise deliberate stops.

### ADR-004 — elapsed-time core with one view-bound transient session

**Decision.** Choose Option A. Add pure core policy and one main-actor AppKit session bound
to the hosted reader view. AppModel alone issues UUID generations, owns observable
playback, and accepts bounded results. The session never invents generations or publishes
per-frame model state.

**Drivers.** Refresh independence, deterministic edit/layout restoration, and preservation
of private-display/focus behavior.

**Alternatives considered.** Option B is the strongest antithesis; it simplifies nominal
ownership but puts AppKit lifecycle in the reducer. Option C is smaller only on paper and
breaks the core constraints. Pixel-only persistence, shared editor/reader storage, whole-
document diffing per keystroke, and auto-resume after topology changes are also rejected.

**Why chosen.** It aligns each concern with its lifecycle: Foundation policy in the core,
TextKit/clip/display link below SwiftUI, and user-visible authority in AppModel.

**Consequences.** Effects/callbacks carry UUID generations; explicit stop ordering and
stale-result tests are mandatory. Checkpoints may lose at most one second on crash. Schema
v1 needs no migration because anchor and speed already persist. App-host and physical Mac
evidence remain mandatory.

**Follow-ups.** M4 alone adds product hotkeys/Focus/menu; M5 owns performance/hardening;
M6 owns toolbar/chrome polish. The 64-point document padding reserves space without
constructing the M6 toolbar.

## 5. Binding type and transition contracts

### 5.1 Pure `ScrollCommand` and `ScrollEngine`

Create `Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollCommand.swift`
with these public, `Equatable`, `Sendable` values (case spelling may not drift during
execution):

```swift
public enum ScrollSuspensionReason: Equatable, Sendable {
    case explicitSuspension
    case clockUnavailable
}

public enum ScrollStopReason: Equatable, Sendable {
    case commandPause
    case restart
    case reachedEnd
    case suspensionGap
    case invalidTimestamp
    case explicitSuspension
    case clockUnavailable
}

public enum ScrollCommand: Equatable, Sendable {
    case start(at: TimeInterval)
    case tick(at: TimeInterval)
    case pause
    case setSpeed(pointsPerSecond: Double, at: TimeInterval)
    case moveBy(points: Double, at: TimeInterval)
    case setMaximumOffset(Double)
    case restart
    case suspend(ScrollSuspensionReason)
}

public struct ScrollTransition: Equatable, Sendable {
    public let offset: Double
    public let phase: PlaybackPhase
    public let didChangeOffset: Bool
    public let didChangePhase: Bool
    public let stopReason: ScrollStopReason?
}
```

Create `ScrollEngine.swift` with a stateful pure value exposing current offset, speed,
maximum, phase, last uptime, and `mutating func apply(_:) -> ScrollTransition`.

Binding semantics, in command order:

- All production command times are monotonic uptime seconds. `CACurrentMediaTime()` and
  `CADisplayLink.timestamp` share the production clock domain; tests inject one fake
  domain. Never use `Date`, wall time, or `targetTimestamp` for displacement.
- `start(at:)` requires a finite uptime, records it immediately, changes paused→playing,
  and moves zero. A repeated start while playing settles nothing and is a no-op.
- `tick(at:)` while playing accepts a finite nonnegative delta no greater than 0.5 seconds,
  applies `speed * delta`, and replaces the baseline. While paused it is inert.
- A negative/nonfinite/`>0.5` interval is atomic: no partial displacement, clear baseline,
  pause, and emit exactly one `.invalidTimestamp` or `.suspensionGap`. Later ticks while
  paused emit no repeated stop.
- `pause` preserves the exact offset, clears the baseline, and emits `.commandPause` only
  when it actually retires playing state.
- `setSpeed` while playing first validates the command timestamp and settles the entire
  valid interval at the old speed, then installs the caller-normalized finite 10–240 pt/s
  value. If timing is invalid, it installs no value and performs the single pause above.
  While paused, a finite in-range speed installs without movement or baseline creation.
- `moveBy` while playing likewise settles the valid interval first, then adds finite points,
  clamps to `0...maximumOffset`, and remains playing unless it reaches maximum. If timing
  is invalid, the entire command is atomic: no elapsed or manual motion and one pause.
  While paused it clamps finite manual points without starting playback.
- `setMaximumOffset` accepts only a finite nonnegative value while paused, clamps the
  current offset to the new range, and otherwise rejects with no mutation. The session
  must stop/capture before every layout-bound change.
- `restart` sets offset zero, clears baseline, leaves paused, and emits `.restart` only if
  phase or offset changed. `suspend` advances zero, clears baseline, pauses, and maps its
  explicit reason once. Reaching maximum clamps and emits `.reachedEnd` once.
- `stopReason` is edge-triggered; repeated ticks/commands in the resulting paused state
  cannot republish terminal state.

The engine receives manual distances only. TextKit line measurement belongs to the
viewport adapter: Forward passes a positive distance, Back the negative of that distance.

### 5.2 UTF-16 mapper

Create `ReadingPositionMapper.swift` with a pure result carrying a refreshed
`ReadingAnchor`, `requiresPause`, and a content-neutral reason. The exact edit entry point
is:

```swift
public static func map(
    anchor: ReadingAnchor,
    editedRangeUTF16: NSRange,
    replacement: String,
    preEditDocument: String,
    postEditDocument: String
) -> ReadingPositionMapping
```

The mapper independently validates nonnegative location/length, addition and length-delta
overflow, range containment in `preEditDocument`, scalar boundaries at both range ends,
and that applying `replacement` produces exactly `postEditDocument` and its UTF-16 length.
Invalid input returns the old offset normalized backward to the nearest pre-document
scalar boundary, clamped to the post-document length/scalar boundary, with
`requiresPause == true`.

For valid edits use these ordered half-open rules; first match wins:

1. zero-length insertion where `location < anchor` shifts by replacement UTF-16 length;
2. zero-length insertion where `location == anchor` uses the post-edit insertion start and
   requests pause/adjustment;
3. nonempty edit where `upperBound <= anchor` shifts by replacement length minus removed
   length;
4. any edit where `lowerBound > anchor` preserves the offset;
5. every remaining overlap/touch-at-start case maps to the post-edit lower boundary and
   requests pause/adjustment.

Every output is scalar-safe. Context slices are independent, maximum 64 UTF-16 units, and
never split a surrogate pair. For imported/recovered fallback, enumerate only scalar
boundaries in the post document and score candidate boundaries by: exact before+after;
then both sides over one side; then greatest total matched UTF-16 units; then unique minimum
distance from normalized old offset. A unique winner succeeds. An equal winning tie or no
candidate returns the normalized/clamped old offset and requests pause—never arbitrarily
choose the lower occurrence.

Layout restoration uses the current TextKit anchor Y and current geometry:
`clamp(anchorY - clipHeight * anchor.viewportFraction, 0...maximumOffset)`.

### 5.3 Viewport, clock, generation, and result contracts

Create `PrivatePresenterApp/Interfaces/ReaderViewport.swift` for the main-actor fakeable
viewport operations: attachment view, clip size/origin, maximum offset, capture/restore
anchor, ensure layout, three-complete-line step, and text-mutation counter.

Create `ReaderViewportAdapter.swift` as the sole production implementation over the
existing `ReaderTextSystem` and reader scroll view. It owns TextKit geometry and clip
movement, not document authority. It uses TextKit 2 (`textLayoutManager`,
`ensureLayout(for:)`, layout/line fragments) and never accesses legacy `.layoutManager`.

Create `DisplayLinkFrameClock.swift` with an injected `FrameClock` seam and production
wrapper. Production creation requires `readerView.window != nil` and
`readerView.window?.screen != nil`; otherwise it returns `clockUnavailable`. It calls
`readerView.displayLink(target:selector:)`, whose selector is
`@objc func displayLinkDidFire(_ link: CADisplayLink)`, adds the link to `.main` for
`.common`, and forwards `link.timestamp`. The link target/owner references are weak where
possible; `invalidate()` is idempotent and mandatory before replacement/deinit.

Apple's current contracts support these choices: `NSView.displayLink(target:selector:)`
returns a link synchronized to the display containing the view; `CADisplayLink` is added
to a run loop, exposes `timestamp`, and `invalidate()` removes it from all modes and
disassociates its target:

- <https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)>
- <https://developer.apple.com/documentation/quartzcore/cadisplaylink>
- <https://developer.apple.com/documentation/quartzcore/cadisplaylink/add(to:formode:)>

Create `ScrollSessionController.swift` as one `@MainActor` transient owner of engine,
clock, viewport, last checkpoint uptime, mirrored current generation, and one pending
mutation capture. It never constructs a generation. Frame ticks apply the engine result
and clip origin locally. It emits only:

- at-most-1-Hz semantic checkpoints while playing;
- one terminal event for end/timing suspension/clock unavailable; or
- one synchronous terminal capture requested by an AppModel stop effect.

Define `ScrollSessionGeneration` in `AppModel.swift` with a `fileprivate` UUID initializer
so only that file can issue values. AppModel keeps the current generation and a single-use
pending retirement `(retiring, replacement, reason)`, both `@ObservationIgnored`. Every
session effect/callback carries a generation. Speed effects carry the current generation
but do not replace it.

A stop effect carries retiring and replacement generations. The adapter calls
`stopAndCapture`, which invalidates the clock before returning a
`ScrollTerminalCapture`; it immediately sends the capture back into AppModel. The reducer
accepts it exactly once only when both tokens equal the pending retirement pair. A normal
checkpoint or terminal callback is accepted only for the current generation. Arbitrary
stale values are ignored. No wrapping integer token exists.

AppModel issues a fresh UUID on start and before pause, restart, hide, topology/privacy
loss, clear, restore, reader replacement/resync, edit/font/alignment/resize bounds change,
attachment replacement/screen move, or teardown. The corresponding reducer path first
records paused if needed and emits stop/capture/invalidate; only after that effect returns
may it emit hide/order-out, shield/move, reader mutation/replacement, or teardown. Speed
alone never advances the generation.

For edits, the synchronous sequence is binding:

1. copy pre-edit document and ask the session to capture live anchor, stop, and invalidate;
2. validate/apply the existing `ScriptTextEdit` to AppModel's document;
3. call the mapper with pre document, post document, range, and replacement;
4. apply the existing one reader `beginEditing`/`endEditing` transaction;
5. ensure current layout and restore the mapped anchor/fraction;
6. report one authorized result to AppModel and schedule persistence;
7. resume with a fresh generation only if the session was previously playing, the
   incremental edit/layout/restore succeeded, and mapping did not request adjustment.

If the M2 gap/application check fails, `ReaderTextSystem.latchResync()` synchronously sends
one resync command, AppModel stop/captures then emits one authoritative replacement, and
adapter reconciles/layouts/restores while paused. There is no `Task`, dispatch, await, or
yield between resync request and replacement, and nested handling remains nonrecursive via
AppModel's existing command queue. Restore/clear/privacy/screen move never auto-resumes.

## 6. Exact files and integration ownership

### 6.1 Create

| Path | Ownership and responsibility |
|---|---|
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollCommand.swift` | Exact command/transition/stop enums; pure and Foundation-only. |
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollEngine.swift` | Elapsed-time transition implementation; no AppKit/Observation. |
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ReadingPositionMapper.swift` | Validated pre/post UTF-16 mapping, scalar-safe contexts, deterministic fallback. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ScrollEngineTests.swift` | All canonical M3.1 and added timing/transition tests. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ReadingPositionMapperTests.swift` | All canonical M3.2 and added boundary/context tests. |
| `PrivatePresenterApp/Interfaces/ReaderViewport.swift` | Main-actor viewport seam for the real adapter and fakes. |
| `PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift` | TextKit 2 geometry, semantic capture/restore, line step, clip motion. |
| `PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift` | `FrameClock` seam and attached-view `CADisplayLink` production lifecycle. |
| `PrivatePresenterApp/Overlay/ScrollSessionController.swift` | Transient engine/clock/viewport session; no generation issuance or per-frame model calls. |
| `PrivatePresenterAppTests/ScrollSessionControllerTests.swift` | Canonical M3.3/M3.4 plus viewport/lifecycle/order tests. |
| `Scripts/test_validate_project_structure_m3.py` | Static RED/GREEN contract for required M3 files/tests and prohibited surfaces. |
| `docs/validation/m3-smooth-rehearsal-scrolling-result.md` | Created only after exact-SHA controlled-Mac automated/package/physical evidence; content-neutral. |

The package and Xcode project discover source/test directories recursively, so no manifest
entry is required (`Package.swift:8-17`; `project.yml:28-54`).

### 6.2 Modify

| Path | Exact integration ownership |
|---|---|
| `PrivatePresenterApp/App/AppCommand.swift` | Add speed, Back/Forward, checkpoint, terminal, clock-unavailable, mutation-result, attachment, and teardown commands carrying generations/results. No M4 input. |
| `PrivatePresenterApp/App/AppEffect.swift` | Add start/stop/speed/manual/mutation/attachment/teardown session effects with explicit generations; stop effects precede destructive/presentation effects. |
| `PrivatePresenterApp/App/AppModel.swift` | **Sole shared integration owner:** issue UUID generations, own observable phase, validate results, order stop/capture before mutation/hide/privacy, checkpoint at ≤1 Hz, preserve snapshot/reducer semantics. No other lane edits this file concurrently. |
| `PrivatePresenterApp/App/DependencyContainer.swift` | `AppEffectAdapter` owns one session, synchronously maps effects/results, preserves no-yield resync, and wires the attached reader view. This file shares the AppModel integration owner. |
| `PrivatePresenterApp/App/AppRuntime.swift` | Route termination through AppModel/session stop and adapter teardown before final persistence/application termination. |
| `PrivatePresenterApp/Controller/ControllerPresentation.swift` | Enable M3 controls from script/phase/safety; add Back/Forward; keep Focus M4-disabled. |
| `PrivatePresenterApp/Controller/ControllerView.swift` | Replace disabled M3 placeholders with visible Start/Pause/Restart/Back/Forward and persisted speed binding; keep disabled Focus. |
| `PrivatePresenterApp/Overlay/ReaderTextSystem.swift` | Preserve one transaction/resync latch; expose TextKit 2 layout/attachment data and content-neutral mutation counts needed by adapter/tests. |
| `PrivatePresenterApp/Overlay/ReaderTextView.swift` | Replace static clip lock with explicit container/scroll/clip attachment, exact background-band-reader order, lifecycle callbacks, and adapter ownership. |
| `PrivatePresenterApp/Overlay/OverlayRootView.swift` | Pass adapter/lifecycle seam while retaining opaque card and existing 36-point header outside reader clip. |
| `PrivatePresenterApp/Overlay/OverlayPanelController.swift` | Sole panel owner forwards attached-reader-view lifecycle events to the adapter; it does not own or create a second session/generation. Preserve level/order/containment and invoke it only after the adapter's stop effect. |
| `PrivatePresenterAppTests/AppModelTests.swift` | Observable authority, generation, ordering, checkpoint, resync, restore/clear/privacy tests. |
| `PrivatePresenterAppTests/ControllerPresentationTests.swift` | Enabled M3 and visible Back/Forward command tests; M4 remains disabled. |
| `PrivatePresenterAppTests/ReaderTextSystemTests.swift` | Incremental edit/resync/zero-extra-mutation regressions around adapter integration. |
| `PrivatePresenterAppTests/OverlayPanelControllerTests.swift` | One panel, attachment replacement, hide/order-out, containment/level/non-key/non-main regressions. |
| `Scripts/validate_project_structure.py` | Require all M3 files/exact tests; retain every M0/M2 validation and add no-frame-publication/no-private-surface checks. |

### 6.3 Explicit no-change/protected decisions

- **No change:** `Packages/TeleprompterCore/Package.swift`, `project.yml`, configuration,
  entitlements, Info.plist, resources, persistence schema/model/migrator, editor TextKit
  stack, privacy coordinator/directive planner, panel class/level enum, snapshot store,
  network verifier, and M0 proof scripts.
- **Byte-for-byte protected:** `PRD.md`, `IMPLEMENTATION_PLAN.md`, M0/M1/M2 canonical
  plans, every existing `docs/validation/*` file, design/reference assets, and checksum
  manifest. M3 adds its own result; it does not edit M0/M2 evidence or `HANDOFF.md`.
- If a RED test appears to require a second AppModel/panel, shared text storage, migration,
  new entitlement/dependency, private API, Accessibility/event tap/global monitor, or focus
  hack, stop for Architect review rather than broadening M3.

## 7. Exact TDD plan — test-only RED then minimum GREEN

For every numbered phase, commit `nA` with tests only, run its exact focused command on a
controlled Mac/Swift toolchain, and retain the expected missing-symbol/failed-expectation
RED. Only then author `nB`, rerun the same command GREEN, and rerun all prior phase targets.
An unrelated compile/configuration failure is not valid RED. If WSL prepares `nA/nB`, it
must say “unobserved candidate”; a controlled Mac must later check out `nA`, observe the
specific RED, then check out `nB` before the pair is accepted.

### M3.0 — preflight and regression lock

Before `1A`:

```bash
BASE=802953089e88369e2a8e9fb744f4e32b30d9727d
test "$(git rev-parse HEAD^)" = "$BASE"   # when starting from this plan commit
test "$(git diff --name-only "$BASE"..HEAD)" = \
  'docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md'
test -z "$(git status --porcelain=v1)"
./Scripts/bootstrap-macos.sh
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests
python3 Scripts/test_validate_project_structure_m2.py
./Scripts/verify-macos.sh
```

Any existing failure is a regression/blocker, not feature RED.

### M3.1 — pure engine

`1A` adds these eight canonical names unchanged:

- `testElapsedTimeNotFrameCountControlsOffset`
- `testSixtyAndOneTwentyHertzMatch`
- `testPausePreservesExactOffset`
- `testSpeedChangeDoesNotJump`
- `testEndClampsAndPauses`
- `testRestartReturnsZeroAndPauses`
- `testForwardBackwardClamp`
- `testSuspensionDoesNotJump`

Add:

- `testStartTimestampMakesFirstTickAdvance`
- `testSpeedChangeSettlesOldSpeedBeforeInstallingNewSpeed`
- `testInvalidTimestampPausesOnceWithoutMovement`
- `testSuspensionGapPausesOnceWithoutCatchUp`
- `testUptimeClockDomainIsUsedConsistently`
- `testMaximumOffsetChangeRequiresPause`
- `testManualMoveSettlesElapsedTimeBeforeClamping`
- `testTerminalStopReasonIsEdgeTriggered`

Focused command:

```bash
swift test --package-path Packages/TeleprompterCore --filter ScrollEngineTests
```

Expected RED is missing command/engine symbols. `1B` implements only section 5.1; GREEN
proves exact offsets/phases/reasons without AppKit.

### M3.2 — reading position mapper

`2A` adds these six canonical names unchanged:

- `testInsertionBeforeAnchorShiftsOffset`
- `testDeletionBeforeAnchorShiftsOffset`
- `testEditAfterAnchorDoesNotMove`
- `testOverlapClampsAndRequestsPause`
- `testEmojiOffsetsAreUTF16Safe`
- `testLayoutChangeRestoresViewportFraction`

Add:

- `testInsertionExactlyAtAnchorClampsAndRequestsPause`
- `testInvalidRangeOverflowClampsAndRequestsPause`
- `testSplitSurrogateRangeClampsAndRequestsPause`
- `testResultDocumentMismatchClampsAndRequestsPause`
- `testAnchorNormalizesBackwardToScalarBoundary`
- `testExactIndependentContextsSelectUniqueCandidate`
- `testAbsentContextClampsAndRequestsPause`
- `testAmbiguousEqualContextTieClampsAndRequestsPause`

Focused command:

```bash
swift test --package-path Packages/TeleprompterCore --filter ReadingPositionMapperTests
```

Expected RED is missing mapper/result symbols. `2B` implements section 5.2. GREEN plus the
full package suite proves ordered mapping, malformed-input containment, independent
contexts, deterministic ties, and no split surrogate output.

### M3.3 — clipped TextKit 2 reader viewport

`3A` adds these five canonical names unchanged to
`PrivatePresenterAppTests/ScrollSessionControllerTests.swift`:

- `testReaderHidesScrollerAndClips`
- `testMaximumOffsetAccountsForToolbarInset`
- `testBandDoesNotBecomeTextSelection`
- `testRestorePlacesAnchorAtBand`
- `testScrollTickPerformsNoTextMutation`

Add:

- `testReaderLayerOrderIsBackgroundBandThenTransparentClip`
- `testBottomDocumentPaddingIsExactlySixtyFourPoints`
- `testExistingHeaderIsNotDoubleCountedInMaximumOffset`
- `testBandUsesPersistedViewportFractionAndFixedHeight`
- `testBandIsNonHitTestingAndAccessibilityIgnored`
- `testIncrementalEditRestoresMappedAnchor`
- `testInsertionAtAnchorPausesAndRestoresBoundary`
- `testRevisionGapResyncIsSynchronousAndSingle`
- `testResizeRestoresAnchorAtBand`
- `testFontChangeRestoresAnchorAtBand`
- `testAlignmentChangeRestoresAnchorAtBand`
- `testThreeCompleteLinesPreferredForManualStep`
- `testManualStepFallsBackToClampedViewportFraction`

Focused command:

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests
```

Expected RED is missing viewport/adapter symbols and static clip behavior. `3B` builds the
layering/geometry/anchor adapter and preserves one M2 edit transaction/resync. Rerun M3.1,
M3.2, `ReaderTextSystemTests`, `OverlayPanelControllerTests`, then full package tests.

### M3.4 — display-link session, AppModel, and controller integration

`4A` adds these six canonical names unchanged:

- `testFakeTicksDriveViewport`
- `testPauseStopsClock`
- `testHiddenPanelStopsClock`
- `testStaleGenerationCallbackIsIgnored`
- `testTickDoesNotPublishSwiftUIStatePerFrame`
- `testEndPublishesOnePausedTransition`

Add:

- `testClockRequiresAttachedReaderView`
- `testDisplayLinkUsesCommonModeAndTimestamp`
- `testDetachInvalidatesClockBeforeReplacement`
- `testScreenMoveInvalidatesAndRecreatesWithoutAutoResume`
- `testTeardownInvalidatesClockAndReleasesOwners`
- `testAppModelIsSoleSessionGenerationIssuer`
- `testSpeedChangeDoesNotAdvanceGeneration`
- `testPauseInvalidatesGenerationBeforeStopEffect`
- `testHideStopsAndCapturesBeforeOrderOut`
- `testPrivacyLossStopsBeforeShieldMove`
- `testClockUnavailablePublishesExactlyOnePausedTransition`
- `testOnlyAuthorizedRetiringGenerationTerminalCaptureIsAccepted`
- `testArbitraryStaleTerminalCaptureIsRejected`
- `testSemanticCheckpointsAreAtMostOncePerSecond`
- `testReaderResyncHasNoTaskYieldOrRecursiveEffectHandling`
- `testEndInvalidatesClockBeforeOnePausedTransition`
- `testControllerExposesBackAndForwardWithoutM4GlobalInput`

Focused and full commands:

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests

xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests
```

Expected RED is missing session/generation effects and disabled controller controls. `4B`
integrates under the sole AppModel/effect-adapter owner. GREEN must prove fake ticks,
actual controlled-Mac attachment/common-mode lifecycle, exact stop ordering, bounded
publication, stale rejection, controller behavior, and all M0–M2 app regressions.

### M3.5 — validator and scope lock

`5A` adds `Scripts/test_validate_project_structure_m3.py` expectations for all M3 paths,
all 25 canonical names, added lifecycle names, one AppModel/panel, TextKit 2 only, schema
v1, `.statusBar + frontRegardless`, non-key/non-main, and prohibited M4/network/private-
API/dependency surfaces. Observe its focused static RED. `5B` extends only
`validate_project_structure.py` and reaches GREEN without weakening M0/M2 validation.

```bash
python3 Scripts/test_validate_project_structure_m2.py
python3 Scripts/test_validate_project_structure_m3.py
python3 Scripts/validate_project_structure.py
./Scripts/verify-wsl.sh
```

## 8. Logical Lore commit breakdown, including Ralph fallback

Every commit uses why-first Lore format with honest `Tested:` and `Not-tested:` trailers.
Keep test-only RED checkpoints; do not squash them away before controlled-Mac replay.

1. **Make scroll distance depend only on elapsed uptime** — `1A` engine tests only; `1B`
   operational command/transition engine.
2. **Keep semantic position stable across Unicode edits** — `2A` mapper tests only; `2B`
   validated ordered mapper/context fallback.
3. **Move the reader without mutating its document** — `3A` viewport/TextKit tests only;
   `3B` reader seam, exact band/padding/layering, semantic capture/restore.
4. **Retire scrolling before privacy or lifecycle boundaries** — `4A` session/AppModel/UI
   tests only; `4B` clock/session/generation/stop ordering and M3 controller controls.
5. **Keep M3 verifiable without widening app access** — `5A` validator contract only;
   `5B` validator implementation and static scope lock.
6. **Record the exact scrolling alpha that passed on the controlled Mac** — create only
   `docs/validation/m3-smooth-rehearsal-scrolling-result.md` after source/package/physical
   evidence. No M0/M2/HANDOFF/source/test mutation.

This is also the logical commit sequence for an explicitly selected `$ralph` fallback.
Ralph may persist through the pairs sequentially, but it is not the default durable-goal
follow-up and may not skip Mac replay/evidence.

## 9. Verification and evidence boundaries

### 9.1 WSL/Linux/static candidate gate

WSL may prepare source/tests/RED-GREEN commits and run:

```bash
BASE=802953089e88369e2a8e9fb744f4e32b30d9727d
test "$(git cat-file -t "$BASE")" = commit
bash -n Scripts/*.sh
python3 Scripts/test_validate_project_structure_m2.py
python3 Scripts/test_validate_project_structure_m3.py
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
git diff --check
git diff --exit-code "$BASE" -- \
  docs/plans/2026-07-12-milestone-0-stabilization.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md \
  docs/validation
git status --short
```

WSL may claim source shape, shell/Python behavior, validator inventory, prohibited-surface
absence, protected bytes, origin/provenance, and diff hygiene only. It cannot claim Swift
compilation, actor isolation, TextKit 2 layout/scalar behavior, `NSView.displayLink`,
common run-loop scheduling, app-host materialization, packaging, 60/120 behavior, Keynote
focus, panel visibility, audience isolation, or physical scrolling.

If implementation crosses hosts, preserve every `nA/nB` SHA and exact command in a
checksummed `.omx/tmp/m3-red-green-manifest.tsv`, plus a git bundle/patch and copies of the
canonical plan/PRD/test spec. The controlled Mac verifies the archive and replays every
RED before accepting its paired GREEN.

### 9.2 Controlled-Mac automated and package gate

Run from clean `SOURCE_SHA` on an Apple-silicon Mac with the repository-pinned XcodeGen
and current controlled Xcode/Swift. Record Mac model/chip, macOS build, Xcode, Swift,
XcodeGen, and exact command exits/test counts; retain content-neutral raw logs in
`.omx/tmp/m3-mac-evidence/` only.

```bash
set -euo pipefail
SOURCE_SHA=$(git rev-parse HEAD)
test -z "$(git status --porcelain=v1)"
./Scripts/bootstrap-macos.sh

swift test --package-path Packages/TeleprompterCore \
  --filter ScrollEngineTests
swift test --package-path Packages/TeleprompterCore \
  --filter ReadingPositionMapperTests
swift test --package-path Packages/TeleprompterCore

xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests

# App-host test materialization/execution must succeed; an infrastructure-style failure
# is blocking and is not waived by M2.
./Scripts/verify-macos.sh
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-no-network.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256

APP='.build/DerivedData-Release/Build/Products/Release/Private Presenter.app'
EXE="$APP/Contents/MacOS/Private Presenter"
test -d "$APP" && test -x "$EXE"
test ! -e "${EXE}.debug.dylib"
mkdir -p .omx/tmp/m3-package
rm -f .omx/tmp/m3-package/Private-Presenter-M3.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" \
  .omx/tmp/m3-package/Private-Presenter-M3.zip
shasum -a 256 "$EXE" \
  .omx/tmp/m3-package/Private-Presenter-M3.zip \
  > .omx/tmp/m3-package/SHA256SUMS
printf '%s\n' "$SOURCE_SHA" > .omx/tmp/m3-package/SOURCE_SHA
test -z "$(git status --porcelain=v1)"
```

The result records `SOURCE_SHA`, exact build command, app path, executable SHA-256,
package SHA-256, app-host result/test count, package/core/full test counts, analyze/Release/
format/no-network/checksum exits, and environment. Never record script text/title,
screenshots, snapshot contents, display serials, or private paths.

### 9.3 Focused physical scrolling smoke

Use synthetic nonprivate text in the exact packaged app whose executable/package hashes
match section 9.2. Use real Keynote Presenter Display with one confirmed private display
and one audience display. Record pass/fail/not-exercised, environment, duration, and only
content-neutral facts.

1. Open a long synthetic script; confirm the overlay is on the private display only,
   `.statusBar + frontRegardless`, opaque, contained, permanently non-key/non-main, and
   Keynote remains frontmost with ordinary slide input.
2. Start at default 60 pt/s and run continuously for two minutes; observe smooth forward
   movement without text mutation or audience leakage.
3. Pause and verify immediate exact stop; wait, resume, and verify no catch-up jump.
4. Change speed while playing and verify no discontinuity at the change; use controller
   Back/Forward and verify three-line movement where layout permits; Restart returns to
   top paused.
5. While positioned mid-script, make synthetic edits strictly before, strictly after,
   exactly at, and overlapping the anchor, including emoji. Verify deterministic restore;
   at/overlap pauses with generic content-neutral adjustment status.
6. Change font, alignment, and panel size; verify the semantic anchor returns to the fixed
   band and the band remains stationary/noninteractive.
7. Hide while playing; verify stop precedes order-out, reopening is paused, and no stale
   callback moves the reader. Repeat for display topology/privacy loss and screen move;
   never auto-resume.
8. Suspend/wake or otherwise create a `>0.5s` gap; verify one paused transition and no
   catch-up. Detach/reattach or move screens and verify link recreation only after
   attachment and no owner leak/crash.
9. Confirm final focus/non-key/non-main, private/audience isolation, containment, opacity,
   locked click-through, and content-neutral diagnostics.
10. Claim a physical 60/120 comparison only if the same display and OS expose both modes;
    otherwise record that row not exercised and rely on deterministic engine schedules,
    never imply a physical pass.

Any focus, privacy, order, stale-movement, resync, package, or app-host failure blocks M3.

### 9.4 Exact-SHA evidence closure and independent review

After the smoke, create evidence-only commit 6 from the observed content-neutral result.
Prove `SOURCE_SHA..FINAL_SHA` changes only that result, the product source tree is
byte-identical, and rerun the nonphysical automated/static gates on clean `FINAL_SHA`.
Then run independent `code-reviewer → verifier → architect` on that exact clean SHA:

- code-reviewer: scope, pure-core transitions, mapper determinism, Swift 6 isolation,
  TextKit 2/no mutation, generation/stale/ordering, privacy/data/prohibited surfaces;
- verifier: replay exact commands, hashes, protected bytes, app-host result, physical rows,
  and source/evidence SHA relationship;
- architect: confirm one authority/panel, lifecycle split, M3 boundary, no M4–M6 creep,
  and no known architectural error.

Any critical/high finding or failed gate requires a fix commit, affected RED/GREEN replay,
full automated/package/physical rerun when product bytes change, and restart of reviews.

## 10. Risk register and deliberate pre-mortem

| Failure | Early signal | Prevention/test | Recovery |
|---|---|---|---|
| Clock domains differ or suspension catches up | first tick/speed change jumps; 60/120 schedules diverge | injected uptime tests, 0.5s boundary, actual link timestamp test | pause without movement, fix engine/domain, replay M3.1–M3.4 |
| Unicode edit picks wrong repeated context | emoji split, repeated paragraph jumps, arbitrary lower tie | pre/post validation, scalar enumeration, independent contexts, tie tests | clamp normalized old offset, pause, never guess |
| Hot ticks leak into Observation/persistence | publication count tracks frame count | fake tick/publication counters; ≤1-Hz checkpoint test | move callback below model; rerun package/app tests |
| Stale terminal capture resurrects motion/state | hide/screen move followed by offset change | UUID pair authorization, stop-before-order tests, stale hostile tests | invalidate, remain paused/hidden, reject result, rerun privacy smoke |
| Reader resync becomes async or recursive | later edit outruns replacement; handle depth > 1 | no-yield resync and maximum-depth tests | restore M2 queue/synchronous callback; remain paused |
| Active band/padding double-count header | end cannot reach band or overscrolls by 36 pt | exact 84/64/header/max tests | correct reader-local geometry only; no toolbar redesign |
| App-host failure is mislabeled infrastructure | package created without executing hosted tests | explicit blocking app-host command/result | stop M3; repair host/toolchain; no waiver |
| WSL candidate is called Mac-proven | no xcodebuild/TextKit/link/package record | claim matrix and RED manifest | transfer/replay on controlled Mac before approval |
| Evidence captures private content | title/script/screenshot appears in logs/result | synthetic text, fixed diagnostics, review sentinel | delete unsafe artifact, rotate local copy, rerun evidence |

Expanded test layers:

- **Unit:** pure engine/mapper exhaustive boundaries, fake viewport/clock, generation token
  acceptance and publication counts.
- **Integration:** real TextKit 2 layout/clip/edit/resync, AppModel-effect ordering,
  controller commands, actual attached-view display-link lifecycle on controlled Mac.
- **End-to-end:** exact packaged app with Keynote/private+audience displays, two-minute
  scrolling, edits/layout/hide/suspension/focus/privacy.
- **Observability/evidence:** content-neutral command exits/test counts, source/app/package
  hashes, publication/transition counters in tests only, clean status and protected-byte
  proofs. No script/title content, telemetry, or production diagnostics expansion.

## 11. Available agents and follow-up staffing

Relevant installed roles are `explore`, `analyst`, `planner`, `architect`, `debugger`,
`executor`, `team-executor`, `test-engineer`, `code-reviewer`, `verifier`, `critic`,
`dependency-expert`, `researcher`, `writer`, `git-master`, `code-simplifier`, `designer`,
`vision`, `scholastic`, and the installed Prometheus Strict roles. Do not use `worker`
outside active Team runtime. M3 needs no dependency, researcher, designer, or vision lane
unless a new blocker changes scope.

Suggested ownership/reasoning:

- **executor, xhigh:** sole shared integration owner for AppModel/AppCommand/AppEffect/
  DependencyContainer/AppRuntime; integrates all lanes;
- **test-engineer, xhigh:** RED checkpoints, fake clocks/viewports, hostile Unicode/
  lifecycle tests; no concurrent AppModel edits;
- **executor or team-executor, high:** pure core lane (`Scrolling/*` and core tests);
- **executor or team-executor, xhigh:** AppKit viewport/session lane excluding shared
  reducer files until integration handoff;
- **code-reviewer, high; verifier, high; architect, high:** independent final gates;
- **git-master, high bounded:** RED/GREEN ancestry, Lore trailers, exact-SHA/package/evidence
  closure; no behavior edits;
- **writer, high bounded:** content-neutral M3 result after evidence only.

### Goal-Mode Follow-up Suggestions

- `$ultragoal` is the default durable implementation follow-up: it owns the sequential
  ledger, RED/GREEN checkpoints, WSL→Mac handoff, exact-SHA evidence, and stop gate.
- For parallelizable delivery, use `$ultragoal + $team`: Team may own disjoint pure-core,
  AppKit viewport/session, and test lanes; Ultragoal/leader retains shared AppModel
  integration and checkpoints Team evidence.
- `$team` alone is appropriate only with one declared integration owner and the verification
  path below. `$ralph` is an explicit persistent single-owner fallback, not the default.
- `$autoresearch-goal` is inappropriate because this is an implementation deliverable.
  `$performance-goal` is deferred to M5; M3's 60/120 equivalence is correctness, not an
  optimization project.

### Team/Ultragoal launch hints (do not run in this Ralplan)

```text
$ultragoal Execute only the approved Private Presenter M3 canonical plan. Own the
durable RED/GREEN ledger, exact baseline/plan ancestry, shared AppModel integration,
controlled-Mac replay, package hashes, physical smoke, and final evidence SHA.

$team 3 Execute disjoint M3 lanes under the Ultragoal leader: executor owns the pure
Scrolling core/tests; team-executor owns ReaderViewport/DisplayLink/ScrollSession and
app-host tests without editing AppModel; test-engineer owns hostile boundary/lifecycle
RED evidence. The leader alone integrates AppModel/AppEffect/DependencyContainer.

omx team 3 --task 'Execute only the approved Private Presenter M3 plan under a
leader-owned Ultragoal ledger; preserve disjoint ownership, RED/GREEN ancestry,
controlled-Mac/package/physical gates, and stop before M4.'
```

### Team verification path

1. Each lane returns exact changed paths, RED SHA/observed failure, GREEN SHA/result, and
   focused command; no two lanes edit shared reducer/effect files.
2. Leader integrates and reruns all M3.1–M3.4 focused tests, full package/app suites,
   validator/M0–M2 regressions, protected bytes, no-network, format/analyze/Release.
3. Team stops after handing checkpoint-ready evidence to Ultragoal. The controlled Mac
   owner replays unobserved WSL pairs, builds/hashes the package, and performs the physical
   smoke on exact `SOURCE_SHA`.
4. Ultragoal records source/evidence SHA closure and independent reviews. Team shuts down
   only after the durable ledger contains the evidence; no lane enters M4 or pushes private
   artifacts.

### Explicit Ralph fallback

Only if the user later selects it:

```text
$ralph Implement only Private Presenter M3 from
docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md. Follow logical
commit pairs 1A/1B through 5A/5B sequentially, preserve the one AppModel integration
owner and every M0/M2 invariant, replay every RED/GREEN pair on a controlled Mac,
block on app-host failure, package/hash and physically smoke the exact SOURCE_SHA,
create only the M3 evidence result, complete independent reviews, and stop before M4.
```

## 12. Consensus record and publication gate

Sequential recovery record:

1. Planner draft READY — `2026-07-15T11:50:09.292Z`.
2. Architect ITERATE — `2026-07-15T11:50:24.471Z`; required timing, transition, mapper,
   layering, resync, authority, ordering, lifecycle, evidence, and publication repairs.
3. Planner repaired READY — `2026-07-15T11:56:40.823Z`.
4. Architect APPROVE — `2026-07-15T11:56:52.263Z`; final mapper/pre-post, Back/Forward,
   tie, clock-unavailable, and sole-authority corrections became binding.
5. Critic ITERATE — direct bounded fallback after a stale dedicated subagent; required the
   exact test/file/stage/commit/evidence/consensus expansion now present in this revision.
6. Planner revised — this artifact; renewed Architect then Critic review remain required.
7. Architect APPROVE — direct bounded fallback after the renewed Architect subagent also
   remained stale; representative engine, edit/resync, and hide/privacy flows are
   decision-complete. The final wording makes `AppEffectAdapter` the sole transient
   session owner and the panel controller only the attached-view lifecycle source.
8. Critic APPROVE — direct bounded fallback after the final dedicated Critic attempt
   remained stale. The reviewed plan contains all 25 exact canonical tests, named added
   boundary/suspension/lifecycle tests, operational contracts, explicit file/shared
   ownership, staged RED→GREEN/Lore commits, protected-byte and WSL/Mac claim boundaries,
   blocking app-host/package evidence, physical smoke, ADR/risks, and execution staffing.

The Planner → Architect APPROVE → Critic APPROVE consensus gate is now complete in the
required order. Copy the approved bytes to the canonical
target and make exactly one plan-only Lore commit:

```text
Constrain M3 to the shortest safe rehearsal-scrolling alpha

The first usable rehearsal path needs time-based motion and edit-stable position
without moving display-rate state into SwiftUI or weakening M2 privacy/lifecycle
ordering, so the plan binds a pure core to one view-attached transient session.

Constraint: Planning only from exact clean baseline 802953089e88369e2a8e9fb744f4e32b30d9727d
Rejected: Implement M3 during Ralplan | violates the planning/execution boundary
Confidence: high
Scope-risk: narrow
Directive: Preserve every named RED/GREEN, Mac/package/physical gate, and stop before M4
Tested: Baseline/static provenance, protected-byte checks, Planner/Architect/Critic consensus
Not-tested: Swift/AppKit/TextKit/display-link/package/physical behavior; this commit is a plan only
```

Publication proof:

```bash
BASE=802953089e88369e2a8e9fb744f4e32b30d9727d
PLAN=docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md
test -f "$PLAN"
test "$(git rev-parse HEAD^)" = "$BASE"
test "$(git diff --name-only "$BASE"..HEAD)" = "$PLAN"
test "$(git show --pretty='' --name-only HEAD)" = "$PLAN"
git diff --exit-code "$BASE" -- \
  docs/plans/2026-07-12-milestone-0-stabilization.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md \
  docs/validation
test -z "$(git status --porcelain=v1)"
```

Only after these proofs may Ralplan persist the durable Planner → Architect APPROVE →
Critic APPROVE handoff, mark consensus complete, and become terminal/inactive. No M3
implementation begins in this run.

## 13. Planner revision changelog

- Replaced the unsupported premature Critic approval with the truthful sequential record.
- Expanded all 25 canonical names plus exact boundary/suspension/lifecycle tests.
- Bound operational command/transition, mapper, clock, generation, stop-result, layering,
  resync, and controller contracts.
- Added create/modify/no-change ownership, RED→GREEN phases, Ralph logical commits,
  WSL/Mac claim boundaries, blocking app-host/package output, physical smoke, risks,
  deliberate test layers, agent roster, Team/Ultragoal/Ralph guidance, and publication
  proof.
- Recorded the final sequential Architect and Critic approvals after bounded stale-agent
  fallbacks; no implementation or execution handoff occurred.
