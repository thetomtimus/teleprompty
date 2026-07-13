# Private Presenter — Milestone 0 Stabilization Before Milestone 2

Status: **RALPLAN CONSENSUS APPROVED — PLANNING ONLY; IMPLEMENTATION REQUIRES AN EXPLICIT HANDOFF**
Planning date: 2026-07-13 (requested artifact date retained in the filename)
Repository: `/home/thomas/teleprompty-review`
GitHub/origin: `https://github.com/thetomtimus/teleprompty.git`
Branch and baseline: clean `main` at `940e1821f36c4125b0f81f623a6d24a015c22dcc`; `origin/main` matches
Predecessor: accepted Milestone 1 in `docs/plans/2026-07-12-milestone-1-core-state-durability.md`
Historical physical result: `docs/validation/overlay-proof-result.md` is **BLOCKED**
Delivery boundary: dedicated M0 stabilization and a practical physical rerun; stop before every M2/editor surface

## 1. Outcome and hard stop

Deliver the smallest native DEBUG-oriented stabilization slice that makes the
2026-07-12 physical failure causally diagnosable and the remaining M0 matrix
practical to execute. The slice must:

1. diagnose and remove the causal path by which the initial Control-Option-H
   show coincided with Private Presenter becoming foreground and Keynote
   leaving its full-screen Presenter Display;
2. preserve Control-Option-H and add the intended Control-Option-L as a global,
   recoverable DEBUG lock/unlock path that never raises the normal controller;
3. export ordered, content-neutral local evidence spanning the Carbon callback,
   AppRuntime, the one AppModel, privacy directives/effects, controller/panel
   lifecycle, application activation, topology, and every applied interaction
   frame;
4. distinguish drawable AppKit screens from all-online Core Graphics display
   topology so hardware mirroring is verified rather than inferred from a
   checkpoint label;
5. keep the window experiment bounded to `.floating` and `.statusBar`, default
   to the currently proven `.statusBar`, and retain the lowest level that passes
   the complete physical matrix;
6. make header drag, all eight custom resize zones, bright-background opacity,
   explicit macOS Space switching, and hostile recovery executable while
   Keynote remains the foreground application; and
7. preserve the M1 snapshot schema/store, paused/hidden restore, startup order,
   and exactly one AppModel.

The implementation lane stops after source changes, Mac automated verification,
a focused real-Keynote/second-display smoke, and independent
**code-reviewer → verifier → architect** approval. It must not begin M2. The
historical result remains BLOCKED until Tom completes the full physical rerun;
code, unit tests, source review, screenshots, or the focused smoke cannot mark
M0 PASS.

## 2. Grounded baseline and evidence boundary

### Repository facts at `940e182`

- M1 is implemented. Tom reported the complete Mac verification and DEBUG
  harness smoke passed; WSL/static checks passed independently. Raw Mac logs are
  not committed, so the platform evidence remains explicitly user-reported.
- `PersistedSnapshot.currentSchemaVersion == 1`. `PersistedSnapshot`,
  `SnapshotMigrator`, `SnapshotStore`, canonical encoding, generation-safe
  persistence, hidden/paused restore, and one `@MainActor @Observable AppModel`
  are protected behavior.
- The only global DEBUG chord is Control-Option-H. Its current route is:

  ```text
  Carbon application-target callback
    → DispatchQueue.main.async
    → AppModel.toggleOverlayFromDiagnosticHotKey
    → AppCommand.showOverlay / hideOverlay
    → AppEffect.showPanel / hidePanel
    → AppEffectAdapter
    → OverlayPanelController.show / hide
    → TeleprompterPanel.orderFrontRegardless / orderOut
  ```

- Current operation-recorder tests prove that this path contains no explicit
  `NSApp.activate`, `showWindow`, `makeKey`, or `makeMain` call. They do not
  prove actual activation-notification order, full-screen behavior, controller
  visibility, or Keynote focus on the target Mac.
- `PrivatePresenterApplication` sets `.regular` activation policy once at
  bootstrap. `ControllerWindowController.showShielded(on:)` both moves the
  normal titled controller and calls `showWindow(nil)`. Runtime startup invokes
  it, and the `.moveControllerWhileShielded` effect invokes it after safe
  display confirmation. H/show itself does not intentionally emit that effect.
- `TeleprompterPanel` is borderless and `.nonactivatingPanel`, joins all Spaces
  as full-screen auxiliary, is not natively `.resizable`, and supports only
  `.floating` and `.statusBar`. Locked mode ignores mouse events; main is always
  false; key eligibility is false while Keynote owns activation.
- `OverlayRootView` already has a custom drag header and eight custom
  edge/corner zones. Candidates pass through `PanelFramePolicy` before
  `setFrame`, and `constrainFrameRect` is a second defense. Applied frames are
  only held in memory and can be double-recorded by current controller paths.
- `WorkspaceFocusProbe` currently captures frontmost PID/bundle plus panel
  key/main. The controller shows only the last eight snapshots and a truncated
  configuration line. No durable validation text is exported.
- `SystemDisplayService.currentDisplays()` maps only `NSScreen.screens`.
  Mirrored hardware may have an online non-drawable sink that is absent from
  that list, so the existing inventory is not sufficient evidence that
  mirroring is off or on.

### Historical physical facts

The 2026-07-12 result contains positive evidence for extended Keynote placement,
later overlay visibility, clean captured audience frames, click-through,
ordinary Keynote input/remote operation, repeated H toggles after the initial
failure, and fail-closed disconnect/reconnect. It records these unresolved gates:

1. initial H made Private Presenter foreground and coincided with Keynote no
   longer being full-screen;
2. PID/bundle and panel/controller/app key/main/activation ordering was not
   exported;
3. the locked panel had no usable full-screen unlock path, so header/eight-zone
   interaction was not completed;
4. the “mirroring” checkpoint still showed two distinct desktops and was not
   actual mirrored topology;
5. `.floating` versus `.statusBar`, bright-pixel opacity, explicit macOS Space
   switching, hostile stale-frame recovery, and physical audience-display
   observation/photo were incomplete.

### Upstream facts versus empirical claims

- Apple documents `orderFrontRegardless()` as ordering an inactive app's window
  without changing key or main, but says it is rarely needed. That API contract
  does not prove the target Keynote/Spaces behavior:
  <https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless()>.
- Apple documents that mirrored configurations expose the largest drawable
  display through AppKit, while `CGGetOnlineDisplayList` includes displays that
  are active, mirrored, or sleeping:
  <https://developer.apple.com/documentation/appkit/nsscreen/screens> and
  <https://developer.apple.com/documentation/coregraphics/cggetonlinedisplaylist(_:_:_:)>.
- `NSScreen.screensHaveSeparateSpaces` directly reflects the Mission Control
  setting and belongs in the evidence export:
  <https://developer.apple.com/documentation/appkit/nsscreen/screenshaveseparatespaces>.

These sources justify the diagnostic seams, not a Keynote compatibility claim.
Only the real Mac/Keynote/display matrix can select the retained configuration.

## 3. Scope and non-negotiable boundaries

### In scope

- DEBUG H/L Carbon registration and direct one-AppModel dispatch.
- DEBUG content-neutral automatic local diagnostics and copyable sanitized text.
- Application/workspace activation, controller/panel, ordering, and delayed
  before/after probes.
- Separate drawable-screen and all-online display topology queries.
- Existing fail-closed mirroring/disconnect/recovery behavior and exact warning.
- Only the instrumentation/control and minimal fixes proven necessary by the
  trace.
- Explicit DEBUG selection of two bounded window levels and, for root-cause
  isolation, two public AppKit ordering methods.
- Existing custom drag/eight-zone containment and an automated opacity render
  check plus practical bright-pixel placement.
- Additive M1 persistence/startup/one-model regressions.
- Updated append/supersede physical procedure.
- Clean-build executable/log hashing and manifest checks as DEBUG-only local
  proof provenance—not signing, attestation, or production authority.

### Out of scope

- M2 long-script editor, script-entry UI, TextKit editing, reader, scrolling,
  display link, active band, production header/toolbar/Focus visual polish.
- Product hotkey customization or the complete M4 Carbon service. H/L here are
  a bounded DEBUG proof control only.
- Menu/status item, accounts, cloud, network, upload, telemetry, remote logging,
  updater, signing, notarization, distribution, or beta/readiness claims.
- Keynote control/automation, Accessibility permission, Accessibility event
  taps, `CGEventTap`, global `NSEvent` monitor fallback, input polling, focus
  return, reactivation of Keynote, or deactivation as a symptom mask.
- `.screenSaver`, private window APIs, arbitrary raw maximum levels, native
  `.resizable`, `performWindowDrag(with:)`, or any unconstrained move/resize.
- Electron, WebView, JavaScript runtime, non-native UI, or any new dependency.
- Production diagnostics/provenance UI, security attestation, signing claims, or
  treating the recorder/manifest as runtime state authority.

### Byte-for-byte protected artifacts

- `PRD.md`
- `design/concept.html`
- `design/teleprompter-concept.png`
- `references/teleprompter-ui-reference.png`

The source checksum manifest remains authoritative. Do not add the historical
result to that immutable manifest; the result is intentionally appendable only
during an actual physical rerun.

## 4. RALPLAN-DR deliberate decision record

### Principles

1. **Fail closed; never focus-correct after the fact.** Remove the causal
   activation path or keep M0 blocked. Never add focus-return behavior.
2. **Measure the real path before selecting a fix.** First add only the causal
   evidence spine, run the cold-show matrix on a Mac, and then implement the
   regression-backed correction plus the remaining proof controls. Instrument
   Carbon receipt, main dispatch, model state/effects, controller/panel
   operations, and explicit immediate/next-turn/delayed activation samples.
3. **Keep the proof bounded.** One runtime, one AppModel, one panel, two chords,
   two levels, two public ordering methods, local-only evidence.
4. **Preserve historical and durable truth.** M1 schema/store/startup behavior
   stays intact and the 2026-07-12 BLOCKED observations are never erased.
5. **Let hardware evidence decide.** Automated tests constrain allowable
   behavior; they cannot approve Keynote, Spaces, mirroring, opacity, or the
   physical audience display.

### Top decision drivers

1. Prevent Keynote/full-screen interruption and any normal-controller raise
   during H/L and custom interaction.
2. Produce sufficient content-neutral evidence to distinguish app behavior from
   an operator or checkpoint-label error.
3. Preserve M1 and avoid building M2 architecture under a proof-harness label.

### Viable options

| Option | Advantages | Costs / risks | Decision |
| --- | --- | --- | --- |
| A. Instrument the existing DEBUG runtime and run a bounded order/level matrix | Measures the path that matters; preserves one model/runtime; permits an evidence-driven minimal fix; reusable local artifact | Several DEBUG integration seams; careful redaction required; still needs hardware | **Chosen** |
| B. Build a separate tiny diagnostic helper executable | Strong isolation of panel/hotkey behavior; fast experiment | A helper can pass while the app fails; duplicates wiring; evidence cannot approve the actual runtime; threatens one-model proof | Viable only as an external debugging experiment after this plan fails, not part of this slice |
| C. Unconditionally replace `orderFrontRegardless` or change activation policy | Small apparent diff; might hide the symptom | No causal evidence; may make inactive panel invisible; changes controller lifecycle; can invalidate the proof | Rejected until Option A trace isolates and tests a specific change |
| D. Reactivate Keynote/deactivate Private Presenter after show | May cosmetically restore focus | Full-screen interruption already happened; races; focus-stealing workaround; prohibited by product intent | Invalid |

Option A is deliberately **two phase**, accepting the Architect's strongest
antithesis rather than attempting every stabilization change before observing
the failure:

1. **Phase A — minimal diagnosis:** add the content-neutral in-memory event
   envelope, lifecycle observers, nonblocking local writer, bounded order/level
   selectors, and tests. Run the four cold-show cells on a Mac in both historical
   controller states. Do not add L, topology changes, interaction changes, or a
   causal fix before this checkpoint.
2. **Phase B — evidence-selected stabilization:** preserve the Phase A record,
   add a failing regression for the identified branch, apply only the permitted
   correction, and then add L, verified topology, interaction/opacity evidence,
   and hostile-recovery coverage. If Phase A does not isolate a permitted cause,
   M0/M2 remain blocked rather than broadening the solution.

Phase A specifically leaves `ControllerWindowController.showShielded(on:)` and
the existing combined move-plus-`showWindow(nil)` behavior unchanged. It observes
that lifecycle without splitting, redirecting, or suppressing it because a
pre-trace split could mask hypothesis 4.

### Deliberate pre-mortem

1. **Diagnostics alter timing or leak content.** Trigger: heavy asynchronous
   formatting, arbitrary strings, or persistence reuse. Prevention: short typed
   events, monotonic sequence, injected sink, no snapshot payloads, sentinel
   tests, static scan. Recovery: diagnostics fail nonfatally and content-neutrally;
   privacy actions/H/L still execute.
2. **Hardware mirror is falsely classified extended.** Trigger: a mirror sink is
   absent from `NSScreen.screens`. Prevention: all-online Core Graphics query,
   drawable/topology separation, fail closed on either query/mapping error,
   exported source/sink facts. Recovery: remain hidden/paused and require an
   interpretable topology; never fall back to drawable-only “safe.”
3. **Repeated H passes but the first cold show or Space transition fails.**
   Trigger: state/Space timing differs after first order. Prevention: three cold
   repetitions per bounded micro-matrix cell, then the complete matrix for the
   lowest candidate. Recovery: retain traces, keep M0 blocked, do not escalate
   level/API privilege.
4. **A recorder changes the hot-key timing or produces an incomplete file.**
   Trigger: formatting/file I/O on the Carbon or main-actor path, missing flush,
   or observer installation after hot-key registration. Prevention: synchronous
   envelope stamping into a bounded in-memory queue, serial off-main writing,
   observers installed first, and an explicit completion barrier. Recovery: H
   and privacy continue, but the cell is invalid evidence and must be rerun.
5. **A level appears to pass on a diagnostic commit but the final default commit
   differs.** Trigger: treating the four-cell trace as final evidence or changing
   level/order after review. Prevention: bind every evidence file to a full SHA,
   configuration, and session, and restart automation/smoke/reviews/full matrix
   after any default or causal commit. Recovery: mark earlier files diagnostic,
   never final.
6. **High-frequency resize saturates the nonblocking evidence ingress.** Trigger:
   every intermediate frame is required but the bounded queue fills. Prevention:
   atomically latch permanent cell invalidity outside the queue, never block the
   gesture/privacy/H/L path, and enqueue a fixed overflow fault when capacity
   returns. Recovery: discard the cell for proof and rerun; never treat partial
   frame evidence as acceptable.

## 5. Root-cause hypotheses and decision table

These are ranked hypotheses, not conclusions.

| Rank | Hypothesis | Current evidence | Initial confidence |
| --- | --- | --- | --- |
| 1 | The normal controller was already visible in its desktop Space and was exposed when the app activated or the Space changed; H may not have explicitly raised it. | Capture showed controller/desktop and Private Presenter foreground; current H operation test records no controller show. | medium-high |
| 2 | The `orderFrontRegardless` + full-screen-auxiliary + level/Space combination triggered or coincided with activation/full-screen exit on macOS 26.5.2/Keynote 14.5. | Failure followed first H; the physical-run commit introduced `orderFrontRegardless`. | medium |
| 3 | Activation began before panel ordering through Carbon application-target delivery or another application lifecycle event. | Existing evidence lacks callback/activation/order chronology. | medium |
| 4 | A delayed startup/display callback ran `moveControllerWhileShielded → showShielded → showWindow` near first H. | Those paths exist independently of H; no ordered trace was exported. | medium-low |
| 5 | `.regular` policy permits an implicit activation. | Policy is set once and permits UI activation, but permission is not causation. | low-medium |
| 6 | H/L explicitly raises/activates the controller. | Source and operation-recorder tests argue against H; actual window/activation observations are missing. | low |
| 7 | M1 caused the original failure. | The failure occurred at pre-M1 `31dff6f`; M1 may affect present timing only. | low |
| 8 | Drag/resize geometry is broken. | Pure/AppKit tests clamp; the physical run never established unlock. | low |
| 9 | Drag/resize was blocked primarily by unrecoverable locked click-through state. | Only the normal controller could unlock. | high |
| 10 | The mirror checkpoint was mislabeled, and the app also lacks sufficient topology visibility. | Captures remained distinct; current inventory is `NSScreen`-only. | high |

Interpret the new timeline as follows:

- **Activation precedes panel-order event:** investigate Carbon receipt,
  application notifications, delayed startup/display callback, and controller
  operations before changing level/order.
- **Activation begins only after `frontRegardless`, while `front` stays visible
  and inactive:** retain `orderFront(nil)` only after a new RED regression and
  complete matrix.
- **`front` stays inactive but cannot display, while `frontRegardless` activates:**
  try the other allowed level. If no allowed pair passes, keep M0 blocked; do not
  add a focus workaround.
- **Controller `showWindow` appears in H/L timeline:** split placement from
  presentation, remove the causal coupling, and lock the operation graph with a
  failing test before the fix.
- **Controller does not receive a show operation but becomes visible after app
  activation:** fix the actual activation cause; do not merely close/re-hide the
  controller and call the problem solved.
- **Activation policy changes after bootstrap:** defect. Only bootstrap may set
  `.regular`; no command/effect may mutate policy.
- **Activation precedes panel ordering and is isolated to Carbon's
  application-target delivery or bootstrap `.regular` policy:** first add a
  RED regression reproducing the isolated public-API behavior. A separate
  code-reviewer + architect decision must approve any public Carbon target or
  activation-policy change and prove controller/startup behavior remains valid.
  No accessory-agent conversion, reactivation, private API, or focus correction
  is implied. If no allowed public-API correction exists, stop with M0/M2
  BLOCKED.
- **Failure does not reproduce:** run at least three cold first shows per cell,
  retain all timelines, and continue the full physical gate. Source tests alone
  do not establish a fix.

## 6. ADR-002 — Evidence-first M0 stabilization

### Decision

In Phase A, add a DEBUG-only, content-neutral diagnostic evidence spine to the
existing runtime and run the cold-show diagnosis. In Phase B, add
Control-Option-L routed directly to the one AppModel; separate
drawable destinations from all-online topology; expose exactly
`.floating`/`.statusBar` and `front`/`frontRegardless` as bounded DEBUG
dimensions. Preserve the current `.statusBar` + `frontRegardless` defaults until
Mac evidence supports a conditional minimal change.

The lifecycle is binding:

```text
instrumented clean commit
  → 24-cell/two-controller-state diagnosis
  → regression-backed repair/default-candidate clean commit
  → Mac automation → focused smoke
  → code-reviewer → verifier → architect
  → Tom's complete matrix on that exact source-default configuration
```

Any later implementation, default, Carbon target, activation-policy, level, or
ordering change creates a new Lore commit and restarts every downstream arrow.
Evidence from an older commit may explain cause but cannot approve the new one.

### Drivers

- The physical failure has no causal chronology.
- Locked click-through mode needs recovery without the controller.
- Hardware mirroring must be proven from hardware topology.
- M1 state ownership and persistence may not change.

### Alternatives considered

- Immediate ordering replacement.
- `.accessory` activation-policy change.
- Separate helper executable.
- Native `.resizable`, focus return, `.screenSaver`, event taps, private APIs,
  global key monitors, or remote logging.

### Why chosen

The chosen design measures the actual failing path and supports every incomplete
physical checkpoint without duplicating state, broadening the product, or
assuming a platform root cause.

### Consequences

- Several existing boundaries receive injected DEBUG recorders/operation probes.
- Phase A stops for the Mac causal trace before L/topology/interaction work.
- The local diagnostic text becomes authoritative for sequence/state claims but
  never substitutes for physical observation.
- Display inventory explicitly distinguishes screens that can host windows from
  online hardware that determines privacy.
- The retained ordering method remains evidence-dependent.
- Recorder, provenance, cohort, and order/level controls remain DEBUG-only,
  local, non-authoritative validation instrumentation rather than signing or
  security attestation.
- Diagnostic write failure is nonfatal and cannot suppress a privacy action or
  H/L action, but it permanently invalidates that physical proof cell; a fresh
  rerun needs successful transactional final publication at the resolved path.

### Follow-ups

- Reduce/remove M0-only diagnostics only under a later approved plan after M0
  passes.
- Do not convert H/L into the product M4 shortcut service here.
- Never persist diagnostics or current topology in `PersistedSnapshot`.
- Retain the Phase A causal note and local evidence with exact instrumented SHA,
  configuration, controller cohort, and repetition.

## 7. Acceptance contract

### 7.1 Activation, focus, and the normal controller

For every H show/hide and L lock/unlock while Keynote is active:

- frontmost PID and bundle ID are identical before, immediately after, on the
  explicitly scheduled next main-run-loop turn, and at bounded `+100 ms` and
  `+500 ms` samples;
- Keynote remains in full-screen Presenter Display;
- `NSApp.isActive` stays false for Private Presenter;
- activation policy remains `.regular`;
- the panel never becomes main or key;
- normal-controller visible/key/main state and presentation count do not
  increase;
- no controller `showWindow`, `makeKeyAndOrderFront`, panel `makeKey`, app
  activation, policy mutation, or focus-return operation occurs; and
- the panel order/hide/lock operation is the only relevant window change.

Run Phase A in both controller lifecycle states: (a) the normal controller is
visible in its ordinary desktop Space, and (b) it has been explicitly closed or
ordered out. Phase A records the existing combined controller lifecycle without
changing it; any `showShielded`, `showWindow`, presentation-count, or order-on
event is causal evidence rather than behavior Phase A attempts to suppress.

After the Phase A trace, Phase B separates startup presentation from placement
as a mandatory final lifecycle invariant. In the Phase B/final configuration,
H/L, topology, drag, and resize must not increment controller presentation count
or generate an order-on-screen transition in either cohort.

The same focus condition applies while an unlocked custom drag/resize gesture is
performed. A test process cannot prove cross-application focus; these assertions
are mandatory physical evidence.

### 7.2 Global DEBUG controls

- Control-Option-H remains the visibility chord and changes only visibility.
- Control-Option-L changes only lock state through a typed command on the same
  AppModel.
- L works when the normal controller is closed/ordered out and Keynote remains
  frontmost.
- Unlock sets `ignoresMouseEvents = false` and enables only custom interactions;
  lock restores click-through.
- Both registrations expose individual OSStatus and unregister cleanly.
- No Accessibility/Input Monitoring permission, event tap, global `NSEvent`
  monitor, or silent fallback exists.

### 7.3 Content-neutral evidence

Every Debug run automatically creates an append-only local text record by
resolving `.applicationSupportDirectory` and appending:

```text
Private Presenter/Validation/<session-id>/overlay-diagnostics.txt
```

The record is UTF-8 JSON Lines with one fixed-schema typed event per line; this
keeps it copyable and permits exact local validation without accepting arbitrary
strings. It is not snapshot JSON and never reuses snapshot persistence.

The controller may show the resolved local path and a **Copy Diagnostics** action
over the already-sanitized report, but full-screen evidence never depends on
raising the controller. The recorder first accepts a fixed typed envelope into
a fixed-capacity **4,096-envelope** nonblocking queue; tests inject smaller
capacities to force saturation. The queue never grows, waits for writer
capacity, or performs file I/O on producer paths. Formatting and append I/O
execute on a serial off-main writer and may not delay Carbon dispatch, H/L, or
privacy effects.

Every event envelope contains exactly:

- one random local `sessionID` (not a device/account identifier);
- a new `correlationID` for each H or L callback, propagated through runtime,
  AppModel, effect adapter, and panel/controller observations;
- a source monotonic timestamp stamped at the observation point;
- a recorder-assigned strictly increasing sequence;
- a fixed `DiagnosticEventKind`; and
- a typed, allowlisted content-neutral payload.

The Carbon handler stamps `carbon.received` synchronously before it schedules
main-actor delivery. Observers are installed before either chord is registered
and removed deterministically after both are unregistered. Observe
`NSApplication.willBecomeActiveNotification`,
`NSApplication.didBecomeActiveNotification`,
`NSApplication.willResignActiveNotification`, and
`NSApplication.didResignActiveNotification`, plus
`NSWorkspace.didActivateApplicationNotification`; also observe panel/controller
did-become/did-resign key/main, order-on/off-screen, and relevant occlusion-state
transitions. Record
focus/window snapshots at command receipt, immediately after application, the
next main-run-loop turn, `+100 ms`, and `+500 ms`; do not use an ambiguous count
of `Task.yield()` calls as a clock.

The first serialized event is `configurationBound`; it includes session ID and
declared cohort and serves as the durable session start. The closed event-kind
vocabulary includes `configurationBound`, `controllerCohortObserved`,
`carbonReceived`, `mainDispatchBegan`, `commandBefore`,
`commandAfter`, `directiveBefore`, `directiveAfter`, `effectEmitted`,
`effectApplyBefore`, `effectApplyAfter`, `panelOperation`,
`controllerOperation`, `applicationLifecycle`, `workspaceActivation`,
`windowLifecycle`, `focusImmediate`, `focusNextMainRunLoop`,
`focusDelayed100Milliseconds`, `focusDelayed500Milliseconds`,
`correlationWindowClosed`, `recorderFault`, `sessionEnded`, and
`sessionCompletion`. Do not accept arbitrary event names.
The typed `applicationLifecycle` payload cases are `willBecomeActive`,
`didBecomeActive`, `willResignActive`, and `didResignActive`; the only
`workspaceActivation` payload case is `didActivateApplication`.
Lifecycle events also carry a closed `observationPhase` of `correlatedAction`
or `postCorrelationQuit`. The latter is permitted only after all active
correlation windows recorded `correlationWindowClosed` **and** the ensuing
normal termination request confirms the documented quit sequence. Other
uncorrelated activation remains ordinary evidence and fails the focus verdict;
it is never retroactively excused. The tag does not change the underlying
lifecycle case or erase the physical observation requirement.

Allowed fields only:

- session/correlation IDs, monotonic source time, sequence, event kind, and
  configuration identifier;
- full 40-character implementation commit, level, and ordering method for the
  session (the commit is supplied by the validated DEBUG launch environment);
- declared and observed controller cohort, repetition `1|2|3`, proof executable
  SHA-256, proof build-log local path/SHA-256, proof-manifest path, panel count,
  and style/collection flags;
- app activation policy/isActive; application will/did become active and
  will/did resign active; workspace did-activate notification;
- frontmost PID/bundle ID;
- panel visible/key/main/locked/ignoresMouseEvents/frame/order/occlusion state;
- controller visible/key/main/shielded/presentation count/order/occlusion state;
- selected-screen full frame, visible frame, containment frame, and
  `NSScreen.screensHaveSeparateSpaces`, kept as separately labelled fields;
- drawable and online display counts/IDs, mirror source/sink facts, and
  `verifiedMirroring`;
- every applied frame with source (`stage`, `show`, `drag`, or one of eight
  resize zones) and the selected-screen frame;
- sanitized command name, privacy directive, emitted/applied effect, and
  panel/controller operation;
- content-neutral diagnostic error code and resolved evidence path.

Forbidden fields include script text, document title, reading context/anchor
context, arbitrary UI/window title, snapshot JSON, clipboard input, screenshot
pixels, telemetry identifier, network address, or upload. Associated snapshot or
script command payloads are recorded only as fixed enum names, never interpolated.

Unknown configuration values, malformed commit values, path resolution, append,
and flush failures export fixed enum codes only—never raw environment values,
paths on failure, exception text, or arbitrary localized descriptions. Recorder
failure is deliberately **nonfatal to privacy and H/L but fatal to evidence**:
the run/cell is unacceptable unless the expected file exists at the exported
resolved final path, ends with `sessionCompletion`, has no pending sibling, and
was published only after synchronize/close/atomic-rename success. The operator reruns an invalid cell after the
fixed-code condition is corrected; implementation must not convert recorder
failure into a show failure or skip a privacy directive.

The fixed failure vocabulary is `EVIDENCE_OPEN_FAILED`,
`EVIDENCE_APPEND_FAILED`, `EVIDENCE_FLUSH_FAILED`,
`EVIDENCE_PATH_UNRESOLVED`, `EVIDENCE_QUEUE_OVERFLOW`,
`EVIDENCE_CLOSE_FAILED`, `EVIDENCE_FINALIZE_FAILED`, `CONFIG_COMMIT_INVALID`,
`CONFIG_LEVEL_INVALID`, `CONFIG_ORDERING_INVALID`,
`CONFIG_CONTROLLER_COHORT_INVALID`, `CONFIG_REPETITION_INVALID`,
`CONTROLLER_COHORT_MISMATCH`, `CONFIG_EXECUTABLE_HASH_INVALID`,
`CONFIG_BUILD_LOG_PATH_INVALID`, `CONFIG_BUILD_LOG_HASH_INVALID`,
`CONFIG_BUILD_MANIFEST_PATH_INVALID`, `PROVENANCE_EXECUTABLE_HASH_MISMATCH`,
`PROVENANCE_BUILD_LOG_HASH_MISMATCH`, and `PROVENANCE_HEAD_MISMATCH`. Proof status is `pending`, `valid`, or
`invalid(<fixed-code>)`; the first error permanently invalidates that cell.

When full, ingress drops the **newest** envelope, atomically latches permanent
`invalid(EVIDENCE_QUEUE_OVERFLOW)` outside the queue, increments only a
saturating content-neutral dropped-event count, and returns immediately so the
gesture/H/L/privacy path continues. When writer capacity returns, it serializes
exactly one fixed `recorderFault(EVIDENCE_QUEUE_OVERFLOW)` before later ordinary
events. The validity latch is authoritative even if no fault envelope initially
fits. Drain, later fault emission, successful flush, or another recorder error
can never restore validity or erase the first permanent invalidation; incomplete
frame records cannot support the matrix.

`configurationBound` contains the exact commit, level, ordering, declared
controller cohort, ASCII repetition (`1`, `2`, or `3` only), executable SHA-256,
build-log local path/SHA-256, and manifest path. Immediately before the first
correlated H show, inspect the existing controller without ordering, presenting,
or activating it: an existing visible window matches `visibleDesktopSpace`; an
existing nonvisible window matches `orderedOut`; a missing/ambiguous state or a
different state emits `CONTROLLER_COHORT_MISMATCH` and permanently invalidates
the cell. A mismatched first show remains blocked/hidden as an invalid proof
precondition, while hide, lock, and privacy handling remain available. The check
never manufactures the requested cohort.

Evidence publication is transactional:

1. exclusively create a unique same-directory `<cell>.txt.pending`;
2. append the ordered session only to that pending file;
3. after each action's `+100 ms`/`+500 ms` samples and related observer callbacks
   drain, append `correlationWindowClosed` for that correlation;
4. during the existing `.terminateLater` orderly shutdown, append `sessionEnded`
   and terminal `sessionCompletion`;
5. synchronize the pending file, close its handle, and only then atomically
   rename it to `<cell>.txt` in the same directory.

The final path is the commit point. A `.pending` file is never acceptable proof;
synchronization, close, or atomic-rename failure leaves no accepted final file
and permanently invalidates the cell. A valid final file exists only after the
rename, has no pending sibling, and ends with `sessionCompletion`. Thus the
serialized marker cannot claim acceptance on its own.

### 7.4 Verified mirroring and hostile recovery

When the all-online topology establishes a mirror set:

1. current session pauses;
2. panel hides;
3. controller state shields;
4. pending show generation invalidates;
5. topology query/evaluation occurs;
6. the exact warning is published:

   > **Display mirroring is on. Students may see the teleprompter. Use Extended Display mode.**

7. show remains blocked; and
8. returning to extended mode does not auto-reveal or auto-resume and requires
   explicit confirmation.

The result procedure rejects a “mirroring” checkpoint unless the exported
record says `verifiedMirroring=true`, reports at least two online displays, and
contains an interpretable source/sink or mirror-set relationship. A label or
one drawable screen is insufficient.

For stale projector controller coordinates, mirroring while visible, selected
private-display disconnect, and reconnect, the record must prove
shield-before-warning/reposition and no automatic reveal/resume. The existing
macOS callback-timing limitation remains documented: the app supplies the
earliest callback-driven best effort and does not claim control over pixels
before macOS delivers the callback.

### 7.5 Window configuration, interaction, and opacity

- Allowed levels are exactly `.floating` and `.statusBar`.
- Default level remains `.statusBar` until the complete matrix establishes a
  lower passing level.
- Diagnostic ordering modes are exactly `front` (`orderFront(nil)`) and
  `frontRegardless` (`orderFrontRegardless()`).
- Ordering selection is deterministic per level: reject invalid/failing modes;
  select the sole complete passer; if both pass, minimize in order activation
  transitions, controller presentation/order operations, panel key/main
  transitions, and missed required visibility samples. If that safety vector is
  equal, retain the exact candidate commit's source default (currently
  `frontRegardless`). Timing alone never overrides an otherwise equivalent
  source default.
- `.screenSaver`, raw maximum level, private APIs, native `.resizable`, and
  focus workarounds are forbidden.
- The custom drag header and all eight edge/corner zones work after L unlock.
- Every candidate is clamped before the sole `setFrame`, and every applied
  intermediate frame is contained by the current selected private-screen frame.
- `constrainFrameRect` stays as a second defense.
- A native render test composites the rounded view over white and checkerboard
  fixtures and samples the reading-surface interior to prove alpha/content is
  background-independent; the physical run still positions it over genuinely
  bright Presenter Display pixels and captures the rounded interior.
- No proof-only visual redesign is allowed. A minimal DEBUG interaction-zone
  guide is permitted only if the Mac smoke shows the invisible zones themselves
  remain a testability blocker; it must not ship in Release.

### 7.6 M1 invariants

- Snapshot and document schemas remain v1; no migration is added.
- Canonical bytes for fixed v1 fixtures remain unchanged.
- L-driven lock changes schedule the correct v1 snapshot.
- Restore stays hidden/paused/shielded until topology reassessment and
  current-session confirmation.
- Startup order remains controller shield/presentation → load → restore → begin
  display observation/query → evaluate privacy → register DEBUG H/L last.
- `SnapshotStoreTests` and `SnapshotMigratorTests` remain fully green.
- Runtime constructs one AppModel. Controller, adapter, H, L, and diagnostics
  reference that model or observe its typed output; no second authority exists.
- Diagnostic events and current-session topology never enter snapshot bytes.

## 8. Planned architecture and exact file boundaries

### 8.1 DEBUG evidence recorder

Create:

- `PrivatePresenterApp/Services/DiagnosticEvidenceRecorder.swift`
- `PrivatePresenterApp/Services/DiagnosticObserverSet.swift`
- `PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests.swift`
- `PrivatePresenterAppTests/DiagnosticObserverLifecycleTests.swift`

The recorder owns a typed `DiagnosticEventEnvelope` (`sessionID`, optional H/L
`correlationID`, source monotonic time, recorder sequence, fixed kind, typed
payload), a fixed-capacity 4,096-envelope nonblocking ingress with an independent
atomic permanent-invalidity latch, an injected sink/root/clock/capacity for
tests, a serial off-main append writer, sanitized report text, current evidence
URL, and content-neutral write/flush status. Use the system Application Support
URL; do
not reuse `SnapshotStore`, its actor, snapshot path, schema, or diagnostics. A
recorder failure emits only a fixed code, never blocks H/L or privacy handling,
and permanently marks that session/cell `evidenceInvalid`. The bounded ingress
has an atomic overflow-invalid latch independent of queue capacity; overflow
never blocks a producer, and one fixed overflow event is appended later when
capacity returns.

Ingress saturation drops newest, never oldest. Invalidation does not depend on
enqueueing a fault. The writer later observes the out-of-band overflow latch and
emits exactly one fixed-code event when capacity is available.

The sink writes exclusively to a unique sibling `.pending` path. Its injected
finalizer exposes synchronize, close, and atomic same-directory rename seams so
tests can fail each step. Only rename publishes the final `.txt`; no failure path
creates/replaces the final name. Extend the existing `AppDelegate` terminate-
later/`AppRuntime.stopAndFlush()` path to await this finalizer after H/L teardown
and correlation drain without putting file I/O on H/L/privacy paths.

Expand:

- `PrivatePresenterApp/Services/WorkspaceFocusProbe.swift`
- `PrivatePresenterApp/App/AppRuntime.swift`
- `PrivatePresenterApp/App/PrivatePresenterApp.swift`
- `PrivatePresenterApp/Controller/ControllerWindowController.swift`
- `PrivatePresenterApp/Overlay/OverlayPanelController.swift`

Install lifecycle observers before hot-key registration and tear them down after
hot-key unregistration. Record synchronous Carbon receipt/action decode before
main dispatch; main-dispatch begin; before/after model command; before/immediate/
next-run-loop/`+100 ms`/`+500 ms` panel operation; application will/did become
active and will/did resign active, plus workspace did-activate;
panel/controller key/main/order/occlusion notifications; and the existing
controller lifecycle. Preserve one correlation ID end-to-end.
Focus snapshots contain no window titles. The critical Carbon/main paths enqueue
typed envelopes only and never wait for file I/O.

`DiagnosticObserverSet` owns all notification tokens. Install
`NSApplication.willBecomeActiveNotification`,
`NSApplication.didBecomeActiveNotification`,
`NSApplication.willResignActiveNotification`,
`NSApplication.didResignActiveNotification`,
`NSWorkspace.didActivateApplicationNotification`, and each panel/controller
window's did-become/did-resign key/main, did-order-on/off-screen, and
did-change-occlusion observers. Delayed samples are session/generation guarded
and ignored after teardown. Teardown order is H/L unregister → drain/close active
correlation windows → observer removal → enqueue `sessionEnded` and
`sessionCompletion` → synchronize → close → atomic final rename → continue
normal service teardown. A finalization failure replies to the existing
termination coordinator only after invalidation and leaves no accepted final
file.

**Phase A does not split controller behavior.** It instruments the current
`moveControllerWhileShielded → showShielded → showWindow` path and records the
actual placement/presentation/order-on events in both cohorts, preserving
hypothesis 4 for causal diagnosis.

In **Phase B**, after the 24-cell trace is retained, split controller semantics
as a mandatory lifecycle invariant (and as the causal repair if the trace
selects that branch):

- a placement method moves/clamps an already shielded controller without
  ordering or activation;
- a presentation method calls the placement method then `showWindow(nil)` only
  for startup or an explicit normal-controller action.

Then `.moveControllerWhileShielded` uses placement without increasing a
presentation count or raising the controller, and H/L cannot emit either
controller operation.

#### 8.1.1 Historical controller-state cohorts

The two cohorts are fixed configuration values:

1. `visibleDesktopSpace`: after shielded startup/confirmation, the controller
   stays visible in its desktop Space while Keynote enters a separate full-screen
   Presenter Display Space.
2. `orderedOut`: after confirmation, the controller is explicitly closed/ordered
   out before Keynote enters full-screen.

During Phase A, both cohorts use the existing controller implementation.
Evidence records existing `showShielded` entry/exit, frame changes,
`showWindow` calls, show count, order-on notifications, and visible/key/main/
occlusion state. No new placement or presentation API exists in Phase A.

During Phase B, after the causal trace is preserved, introduce:

- `placeControllerWhileShielded` clamps/moves without ordering;
- `presentShieldedControllerAtStartup` performs placement plus the one implicit
  startup presentation; and
- only a later explicit normal-controller user action may present again.

Phase B placement preserves the cohort: a visible controller may move while
remaining visible, while an ordered-out controller remains ordered out. Evidence
records placement count, presentation count, order-on notification count, and visible/
key/main/occlusion state. H/L, topology, show/hide, lock/unlock, drag, and resize
may increment neither presentation nor order-on count.

### 8.2 Two DEBUG Carbon actions

Modify:

- `PrivatePresenterApp/Services/DiagnosticHotKeyService.swift`
- `PrivatePresenterApp/App/AppCommand.swift`
- `PrivatePresenterApp/App/AppModel.swift`
- `PrivatePresenterApp/App/AppRuntime.swift`
- `PrivatePresenterApp/Controller/ControllerView.swift`

Add a fixed `DiagnosticHotKeyAction`:

| Action | Chord | Carbon virtual key | AppModel command |
| --- | --- | --- | --- |
| visibility | Control-Option-H | `kVK_ANSI_H` | existing typed show/hide toggle |
| lock | Control-Option-L | `kVK_ANSI_L` | new typed `.toggleLock` |

Decode `EventHotKeyID` in the handler; keep separate registration references and
statuses; unregister both deterministically. If L registration fails, expose the
failure and treat the physical precondition as failed—do not fall back. Both
closures capture only the one AppModel, never the controller.

### 8.3 Bounded order/level configuration

Modify:

- `PrivatePresenterApp/Overlay/TeleprompterPanel.swift`
- `PrivatePresenterApp/Overlay/OverlayPanelController.swift`
- `PrivatePresenterApp/App/AppRuntime.swift`
- `PrivatePresenterApp/App/DependencyContainer.swift`
- `PrivatePresenterApp/App/PrivatePresenterApp.swift`

Add `OverlayPanelOrderingMode` with exactly `front` and `frontRegardless`.
Support in Debug only:

```text
PRIVATE_PRESENTER_PROOF_LEVEL=floating|statusBar
PRIVATE_PRESENTER_ORDERING=front|frontRegardless
PRIVATE_PRESENTER_EVIDENCE_COMMIT=<40 lowercase hex>
PRIVATE_PRESENTER_CONTROLLER_COHORT=visibleDesktopSpace|orderedOut
PRIVATE_PRESENTER_REPETITION=1|2|3
PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256=<64 lowercase hex>
PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG=<resolved local path>
PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256=<64 lowercase hex>
PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST=<resolved local path>
```

Unknown level/order values use explicit source defaults but still invalidate the
proof cell; malformed commit/cohort/repetition/provenance values invalidate the
cell and are exported only as fixed errors without echoing input. Accept
repetition only as ASCII `1|2|3`; do not accept a numeric window level.
The cohort/repetition values label and validate an operator-created state; they
must never present/order the controller to manufacture that state. Release
remains bounded and unchanged during stabilization. Any later default change is
a conditional Lore commit supported by the Mac trace and rerun.

### 8.4 Verified topology with drawable placement

Modify:

- `PrivatePresenterApp/Services/SystemDisplayService.swift`
- `PrivatePresenterApp/App/AppModel.swift` only for the additive inventory shape
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/DisplayDescriptor.swift`
- `Packages/TeleprompterCore/Sources/TeleprompterCore/Display/DisplayTopologyEvaluator.swift`
- `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/DisplayTopologyEvaluatorTests.swift`

Create:

- `PrivatePresenterAppTests/SystemDisplayServiceTests.swift`

Define one unambiguous value:

```swift
struct RuntimeDisplayInventory {
    let drawableDestinations: [RuntimeDisplay]
    let topology: DisplayTopologySnapshot
}
```

The only production initializer is
`RuntimeDisplayInventory(drawableDestinations:topology:)`; remove or confine any
legacy `init(displays:)` compatibility helper to test code so
`SystemDisplayService.currentInventory()` cannot accidentally evaluate only
drawable screens. Maintain two distinct collections:

1. **Drawable destinations:** `NSScreen.screens`, valid `NSScreenNumber`, frame,
   visible frame, scale, and identity; only these may host a panel/controller.
2. **All-online topology:** two-stage `CGGetOnlineDisplayList`, followed by
   `CGDisplayMirrorsDisplay`, `CGDisplayIsInMirrorSet`, bounds, built-in/main/
   online state, UUID/vendor/model/serial; all entries become transient topology
   members for privacy evaluation.

Introduce a transient `OnlineDisplayTopologyRecord` containing only current
session ID, fingerprint, built-in/main/online/active facts, Core Graphics
topology bounds, mirror source ID, and mirrored IDs. It deliberately has **no**
placement visible frame, backing scale, containment frame, or selection API.
Keep `DisplayDescriptor`/`RuntimeDisplay` as the NSScreen-backed drawable type.
`DisplayTopologySnapshot` carries topology records; change the evaluator seam to
accept that snapshot plus explicit drawable descriptors and selection. It checks
all online records for mirroring first, then resolves any returned candidate by
session ID from the drawable list. Thus a CG-only sink blocks privacy but cannot
be returned or selected. Count/query races, missing candidate-to-drawable join,
or Core Graphics errors produce `querySucceeded=false` and fail closed.
`currentInventory()` must exercise this production path in a test where a
mirrored sink is absent from `NSScreen`. Do not persist raw display IDs or
topology.

The core seam is explicit rather than overload-compatible:

```swift
func evaluate(
    snapshot: DisplayTopologySnapshot,
    drawableDestinations: [DisplayDescriptor],
    selection: DisplaySelection?
) -> DisplayTopologyEvaluation
```

Delete the former production `evaluate(snapshot:selection:)` path so callers
cannot omit drawable eligibility or synthesize topology from NSScreen values.

The accepted conservative policy is that an interpretable mirror set among any
online members blocks show, even if a sleeping/virtual member later proves
operationally irrelevant. Exported topology permits diagnosis, but this M0 slice
adds no privacy override; an uncertain or unexpectedly mirrored inventory stays
hidden/paused/shielded.

### 8.5 Ordered directives/effects

Modify narrowly:

- `PrivatePresenterApp/App/AppModel.swift`
- `PrivatePresenterApp/App/AppEffect.swift`
- `PrivatePresenterApp/App/DependencyContainer.swift`

Observe without creating a second reducer:

- sanitized command received;
- each `PrivacyDirective` before/after authoritative state mutation;
- each `AppEffect` emitted;
- each adapter effect immediately before/after application;
- panel/controller operation.

Do not add a second privacy coordinator or let the recorder mutate AppModel.
The order remains:

```text
pause → hide → shield → invalidate pending show → query → evaluate
  → move while shielded + publish safe OR request confirmation
```

### 8.6 Custom frame and opacity evidence

Modify:

- `PrivatePresenterApp/Overlay/ClampedPanelInteractionController.swift`
- `PrivatePresenterApp/Overlay/OverlayPanelController.swift`
- `PrivatePresenterApp/Overlay/OverlayRootView.swift` only as needed to expose
  testable zone identity/opaque rendering
- `PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift`
- `PrivatePresenterAppTests/OverlayPanelControllerTests.swift`
- `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/PanelFramePolicyTests.swift`

Make `ResizeEdge` enumerable. Centralize actual frame application so one typed
record is emitted once, after clamp and adjacent to the sole `setFrame`. Remove
duplicate appends. Record source/candidate/applied/selected frame; apply only the
contained frame. Use native AppKit/Core Graphics bitmap rendering for opacity
tests—no snapshot dependency.

### 8.7 Validation and audits

Modify during implementation:

- `docs/validation/overlay-proof-template.md`
- `Scripts/validate_project_structure.py`
- `Scripts/verify-no-network.sh` only for narrowly scoped prohibited runtime
  markers not already covered
- `HANDOFF.md` only after real implementation/Mac evidence exists

Create:

- `Scripts/verify-m0-proof-provenance.sh` — compare clean HEAD, executable/log
  hashes, and manifest/header values without modifying artifacts;
- `Scripts/test-verify-m0-proof-provenance.sh` — temporary-fixture success plus
  commit/executable/log/missing-file/dirty-tree mismatch cases.

The verifier is an independent local proof check, not app/runtime authority. It
must be run before and after every proof-app launch and by the verifier role.

Do not modify `docs/validation/overlay-proof-result.md` during code-only
implementation. Tom's actual rerun owns the append described in section 11.

No `project.yml` or `Package.swift` source-membership change is expected because
their source paths are recursive. Add no dependency, target, entitlement,
resource, or build phase.

## 9. TDD execution order and exact commands

For every stage: add the named test first, run the exact targeted command on a
Mac, capture the expected missing-behavior RED, implement the minimum, rerun
GREEN, then run all prior stabilization suites. A compile error caused by a test
referencing a not-yet-created type is acceptable initial RED only when it is the
smallest honest expression of missing behavior. Do not weaken/delete a test.

WSL cannot observe Swift/AppKit RED or GREEN. Missing `swift`, `xcodebuild`, or
macOS is environment evidence only.

### M0S.0 — Preflight and freeze M1 behavior

Before implementation edits:

```bash
test "$(git rev-parse 940e182^{commit})" = \
  "940e1821f36c4125b0f81f623a6d24a015c22dcc"
git merge-base --is-ancestor \
  940e1821f36c4125b0f81f623a6d24a015c22dcc HEAD
test "$(git branch --show-current)" = "main"
test -z "$(git status --porcelain)"
test "$(git remote get-url origin)" = "https://github.com/thetomtimus/teleprompty.git"
git diff --exit-code 940e1821f36c4125b0f81f623a6d24a015c22dcc -- \
  PRD.md IMPLEMENTATION_PLAN.md HANDOFF.md Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests Scripts design references \
  docs/validation project.yml
sha256sum -c docs/validation/source-artifact-checksums.sha256
./Scripts/bootstrap-macos.sh
```

Add to `CoreStateModelTests.swift` and `AppModelTests.swift`:

- `testStabilizationRetainsV1CanonicalSnapshotAfterDiagnosticLockChange`
- `testStabilizationRestoreRemainsHiddenPausedUntilPrivacyConfirmation`
- `testStabilizationStartupRestoresBeforeTopologyAndRegistersControlsLast`
- `testStabilizationRuntimeStillConstructsExactlyOneAppModel`
- `testStabilizationServicesShareTheRuntimeModelIdentity`
- `testDiagnosticStateNeverEntersPersistedSnapshot`

Run:

```bash
swift test --package-path Packages/TeleprompterCore --filter CoreStateModelTests
swift test --package-path Packages/TeleprompterCore --filter SnapshotMigratorTests
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests
```

These are regression locks. Baseline failures are defects to resolve before
stabilization; they are not expected feature REDs.

### M0S.1 — Phase A causal evidence spine

Add `DiagnosticEvidenceRecorderTests.swift` before changing the hot-key path:

- `testEvidenceEnvelopeCarriesSessionCorrelationSourceTimeSequenceAndFixedKind`
- `testCarbonReceiptIsStampedBeforeMainDispatchForSameCorrelation`
- `testCorrelatedEventsRetainStrictRecorderOrderAcrossDelayedSamples`
- `testEvidenceUsesLocalApplicationSupportValidationDirectory`
- `testEvidenceAppendDoesNotEraseEarlierEvents`
- `testEvidenceWriterNeverPerformsFileIOOnHotKeyOrMainCriticalPath`
- `testEvidenceAndFixedErrorsNeverContainScriptTitleContextOrRawEnvironment`
- `testRecorderFailureDoesNotBlockPrivacyOrHotKeyDispatch`
- `testRecorderFailurePermanentlyInvalidatesCellWhileActionsContinue`
- `testSessionCompletionRequiresResolvedPathExistingFileAndSuccessfulFlush`
- `testEvidenceHeaderBindsFullCommitLevelAndOrdering`
- `testQueueSaturationAtomicallyInvalidatesCellWithoutDelayingHotKeyOrPrivacy`
- `testQueueOverflowEmitsFixedFaultWhenCapacityReturns`
- `testQueueOverflowCannotBecomeValidAfterSuccessfulFlush`
- `testBoundedIngressRejectsNewestEnvelopeAtCapacityWithoutWaiting`
- `testQueueOverflowInvalidationDoesNotRequireFaultEnvelopeCapacity`
- `testOverflowFaultIsEmittedOnceAfterWriterCapacityReturns`
- `testHotKeyDispatchContinuesWhileEvidenceQueueIsSaturated`
- `testPrivacyDirectivesContinueInOrderWhileEvidenceQueueIsSaturated`
- `testOverflowAndLaterSinkFailurePreserveFirstPermanentInvalidation`
- `testConfigurationBoundIncludesControllerCohortAndRepetition`
- `testOnlyRepetitionsOneThroughThreeAreAccepted`
- `testInvalidRepetitionUsesFixedCodeWithoutEchoingInput`
- `testConfigurationBoundIncludesExecutableSHA256AndBuildLogPathAndHash`
- `testExecutableHashRequiresSixtyFourLowercaseHexCharacters`
- `testInvalidExecutableHashUsesFixedCodeWithoutEchoingInput`
- `testInvalidBuildLogHashUsesFixedCodeWithoutEchoingInput`
- `testEvidenceWritesOnlyToSiblingPendingPathBeforeCompletion`
- `testSessionCompletionIsLastSerializedEventBeforeSynchronization`
- `testSynchronizationAndClosePrecedeAtomicFinalRename`
- `testFinalPathAppearsOnlyAfterAtomicRename`
- `testSynchronizationFailureNeverPublishesFinalEvidenceFile`
- `testCloseFailureNeverPublishesFinalEvidenceFile`
- `testAtomicRenameFailureNeverPublishesAcceptedFinalFile`
- `testPendingFileIsNeverAcceptedAsProof`
- `testFinalizationFailurePermanentlyInvalidatesCell`

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests
```

### M0S.2 — Phase A cold-H lifecycle and bounded configuration

Create `DiagnosticHotKeyServiceTests.swift`; extend panel/controller tests. Do
not add L or any causal fix yet:

- `testControlOptionHRetainsVisibilityAction`
- `testObserversInstallBeforeVisibilityHotKeyAndTearDownAfterUnregistration`
- `testNoEventsAreAcceptedAfterObserverTeardown`
- `testApplicationObserversCaptureWillAndDidBecomeActive`
- `testApplicationObserversCaptureWillAndDidResignActive`
- `testWorkspaceObserverCapturesDidActivateApplication`
- `testWindowObserversRetainTransientKeyMainOrderAndOcclusionNotifications`
- `testFocusSnapshotsUseImmediateNextRunLoop100msAnd500msSchedule`
- `testDelayedSamplesAreCancelledAfterSessionTeardown`
- `testPhaseAControllerObserverRecordsExistingShowShieldedEntryAndExit`
- `testPhaseAControllerObserverRecordsFrameShowWindowAndShowCount`
- `testPhaseAControllerObserverRecordsVisibilityOrderKeyMainAndOcclusion`
- `testPhaseAInstrumentationDoesNotChangeControllerFrameVisibilityOrShowCount`
- `testColdShowTraceSupportsControllerVisibleAndOrderedOutStates`
- `testEvidenceDistinguishesVisibleDesktopSpaceAndOrderedOutCohorts`
- `testObservedVisibleControllerMatchesVisibleDesktopSpaceCohort`
- `testObservedOrderedOutControllerMatchesOrderedOutCohort`
- `testMissingControllerWindowCausesCohortMismatch`
- `testControllerCohortMismatchPermanentlyInvalidatesCellBeforeFirstHotKey`
- `testObservedCohortValidationNeverPresentsOrOrdersController`
- `testConfigurationBoundPrecedesCorrelatedCarbonReceipt`
- `testNormalQuitWaitsForAllCorrelatedSamplesBeforeCompletion`
- `testPostCorrelationQuitActivationIsTaggedAndExcludedFromFocusVerdict`
- `testUncorrelatedActivationWithoutTerminationStillFailsFocusVerdict`
- `testOrderedOutCohortQuitDoesNotPresentOrOrderController`
- `testOrderingModesAreExactlyFrontAndFrontRegardless`
- `testBothOrderingModesAvoidKeyMainAndExplicitActivation`
- `testDefaultProofLevelRemainsStatusBarUntilPhysicalMatrix`
- `testDefaultOrderingRemainsFrontRegardlessUntilPhysicalEvidence`
- `testOrderingSelectionChoosesOnlyPassingMode`
- `testOrderingSelectionRetainsCurrentSourceDefaultWhenBothModesAreEquivalent`
- `testOrderingSelectionUsesSafetyVectorBeforeDefaultTieBreak`
- `testOrderingSelectionRejectsLevelWhenNeitherModePasses`
- `testLevelSelectionPrefersFloatingOnlyAfterCompletePassingOrdering`
- `testConfigurationSnapshotExportsCommitOrderingAndLevel`
- `testActivationPolicyIsSetOnlyAtBootstrap`
- `testForbiddenWindowLevelsAndFocusWorkaroundsAreAbsent`

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticHotKeyServiceTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticObserverLifecycleTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
python3 Scripts/validate_project_structure.py
./Scripts/verify-no-network.sh
```

The validator rejects product calls/values for `NSApp.activate`,
`NSRunningApplication.activate`, `makeKeyAndOrderFront`, `.screenSaver`, raw
maximum levels, event taps, and global key monitors while excluding test names
and policy prose narrowly.

### M0S.3 — Mandatory Phase A Mac diagnosis gate

Commit the instrumented Phase A slice with a Lore message, run section 10's four
cells in both controller states, and archive each transactionally finalized
record. The implementation agent writes a short causal decision note mapping
the observed sequence to section 5. **No Phase B production change may begin
until this Mac trace exists.** WSL work stops and hands off a bundle here.

The diagnosis is exactly 24 cold cells:

```text
2 levels × 2 ordering modes × 2 controller cohorts × 3 repetitions
```

After a clean Phase A build, each launch sets all bound dimensions:

```bash
test -z "$(git status --porcelain)"
INSTRUMENTED_COMMIT="$(git rev-parse HEAD)"
PRIVATE_PRESENTER_EVIDENCE_COMMIT="$INSTRUMENTED_COMMIT" \
PRIVATE_PRESENTER_PROOF_LEVEL='<floating|statusBar>' \
PRIVATE_PRESENTER_ORDERING='<front|frontRegardless>' \
PRIVATE_PRESENTER_CONTROLLER_COHORT='<visibleDesktopSpace|orderedOut>' \
PRIVATE_PRESENTER_REPETITION='<1|2|3>' \
"$APP"
```

Ensure no prior Private Presenter process remains before launch. After every
correlated delayed sample drains, require `correlationWindowClosed`; do not kill
the process. The cell is usable only when its SHA/config/cohort/repetition match,
the final path exists with no pending sibling and terminal `sessionCompletion`,
and the proof-validity latch never
records `EVIDENCE_QUEUE_OVERFLOW` or another permanent invalidation.
The causal note must state whether activation preceded/followed panel ordering
and whether any controller presentation/order-on event occurred.

If activation is isolated to Carbon application-target delivery or `.regular`,
preserve the exact failure, consult current official Apple documentation for
`RegisterEventHotKey` targets and `NSApplication.ActivationPolicy`, and write an
ADR addendum naming the public candidate, lifecycle consequences, and rejected
alternatives. Obtain a separate architect approval, then add and observe a
failing regression over an injected target/policy seam before implementation.
Tests include `testCarbonRegistrationTargetIsExplicitAndRecorded`,
`testCarbonReceiptCorrelationPrecedesAnyRecordedActivationEvent`,
`testHotKeyDispatchNeverMutatesActivationPolicy`,
`testDefaultAndReleaseActivationPolicyRemainRegularUntilApprovedChange`, and
`testUnsupportedCarbonTargetOrActivationPolicyFailsClosed`, plus branch-specific
controller/one-model tests. Do not assume that an event-dispatcher target or
`.accessory` is acceptable merely because public API exists. If no documented
non-focus-stealing correction preserves global H/L, shielded startup, controller
operability, and one AppModel, terminate with M0/M2 BLOCKED. Otherwise implement
only the selected cause, create a dedicated Lore commit, rerun M0S.1–2 and all
affected cold cells, and restart downstream validation.

### M0S.4 — Phase B controller lifecycle, global H/L recovery, and ordered effects

Only after M0S.3, perform the behavior-changing placement/presentation split,
add L, and complete the correlated path:

- `testControllerOperationRecorderDistinguishesPlacementFromPresentation`
- `testStartupPresentationIsTheOnlyImplicitControllerOrderOn`
- `testPlacementMovesVisibleControllerWithoutPresenting`
- `testPlacementKeepsOrderedOutControllerOrderedOut`
- `testTopologyNeverIncrementsControllerPresentationOrOrderOnCount`
- `testHotKeysAndPanelInteractionsNeverIncrementControllerPresentation`
- `testHotKeyShowNeverRaisesOrPresentsNormalControllerInEitherState`
- `testControlOptionLDispatchesLockAction`
- `testControlOptionLDispatchesOnlyToggleLock`
- `testControlOptionLWorksWithControllerOrderedOut`
- `testHotKeyIDsDecodeToDistinctActions`
- `testRegistrationFailureCleansUpBothHotKeys`
- `testBothRegistrationFailuresInvalidatePhysicalPrecondition`
- `testBothHotKeyActionsPropagateCorrelationID`
- `testDiagnosticHotKeysDispatchThroughOneAppModel`
- `testShowHideLockUnlockNeverRaiseNormalControllerInEitherState`
- `testShowHideLockUnlockNeverExplicitlyActivateApplication`
- `testDiagnosticUnlockSchedulesV1LockSnapshot`
- `testTerminationUnregistersBothDiagnosticChords`
- `testPrivacyDirectiveEffectAndApplicationOrderShareCorrelation`
- `testEvidenceExportsOrderedPrivacyDirectivesAndEffects`

These tests become RED only after the Phase A trace is preserved. Implement the
placement/presentation split in Phase B even if it is not the primary activation
cause because it is a required final lifecycle invariant. If the trace selects
the combined lifecycle as causal, record that evidence in the causal-fix Lore
commit; otherwise record the split as a bounded stabilization invariant.

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/DiagnosticHotKeyServiceTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

### M0S.5 — All-online mirroring with drawable-only placement

Add `SystemDisplayServiceTests.swift` and core/app-model tests:

- `testRuntimeInventoryRequiresDrawableDestinationsAndTopology`
- `testProductionCurrentInventoryIncludesNonDrawableOnlineMirrorSink`
- `testCGOnlyTopologyMemberHasNoVisibleFrameScaleOrDestinationEligibility`
- `testDrawableDestinationsRemainNSScreenBacked`
- `testOnlineMirroredSinkMissingFromDrawableScreensStillBlocks`
- `testAllOnlineMirrorSourceAndSinkAreExported`
- `testOnlineDisplayQueryFailureFailsClosed`
- `testOnlineDisplayCountRaceFailsClosed`
- `testMissingCandidateDrawableMappingFailsClosed`
- `testSelectedScreenExportsFullVisibleAndContainmentFramesSeparately`
- `testVerifiedMirroringRequiresHardwareMirrorFacts`
- `testDistinctExtendedDisplaysAreNotMislabelledMirrored`
- `testVerifiedMirroringWhileVisiblePausesHidesShieldsAndInvalidates`
- `testVerifiedMirroringUsesExactWarning`
- `testMirroringRecoveryNeverAutoRevealsOrResumes`
- `testNonMirroredSelectionCannotBypassAnotherMirroredPair`

RED/GREEN:

```bash
swift test --package-path Packages/TeleprompterCore --filter DisplayTopologyEvaluatorTests
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/SystemDisplayServiceTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

### M0S.6 — Header, eight zones, frame export, and opacity

Extend core/overlay tests:

- `testResizeZonesContainExactlyEightEdgesAndCorners`
- `testEveryResizeZoneAppliesOnlyContainedIntermediateFrames`
- `testDragHeaderAppliesOnlyContainedIntermediateFrames`
- `testEveryAppliedFrameIsRecordedExactlyOnce`
- `testRecordedFrameIncludesSeparateSelectedFullVisibleAndContainmentFrames`
- `testDiagnosticUnlockRestoresInteractionWithoutNativeResizable`
- `testLockRestoresClickThroughWithoutChangingFrame`
- `testSecondContainmentDefenseRejectsCrossDisplayFrame`
- `testDragAndResizeNeverPresentNormalController`
- `testRenderedRoundedInteriorIsOpaqueOverBrightAndCheckerboardBackdrops`

Use negative-X, positive-X, vertically arranged, resolution-change, and adjacent
display layouts.

RED/GREEN:

```bash
swift test --package-path Packages/TeleprompterCore --filter PanelFramePolicyTests
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
```

### M0S.7 — Hostile recovery and startup order

Extend `AppModelTests.swift`/overlay tests:

- `testStaleProjectorControllerFrameIsClampedWhileShieldedBeforePresentation`
- `testMirroringWhileVisibleRecordsShieldBeforeWarningAndReposition`
- `testSelectedPrivateDisplayDisconnectHidesBeforeRecovery`
- `testHostileRecoveryNeverAutoResumesOrReveals`
- `testControllerRemainsShieldedAfterReconnectUntilConfirmation`
- `testPendingShowCannotSurviveTopologyChange`
- `testDiagnosticsDoNotChangeStartupRestoreOrdering`
- `testTopologyPlacementNeverPresentsNormalController`
- `testHLockTopologyDragAndResizeNeverOrderControllerOnScreen`

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
```

### M0S.8 — Procedure/static gate

Update the template and validator after behavior is green. Require every new
source/test/path/marker, both chords, bounded configurations, content-neutral
fields, checksum preservation, immutable historical block, and append-only
current-decision procedure.

The provenance script fixture covers:

- `testProvenanceVerifierAcceptsMatchingCleanManifest`
- `testProvenanceVerifierRejectsExecutableHashMismatch`
- `testProvenanceVerifierRejectsBuildLogHashMismatch`
- `testProvenanceVerifierRejectsCommitMismatch`
- `testProvenanceVerifierRejectsMissingBuildLog`
- `testProvenanceVerifierRejectsDirtyTree`
- `testSameExecutableHashIsRequiredAcrossSmokeAndPhysicalEvidence`

Run:

```bash
bash -n Scripts/bootstrap-macos.sh Scripts/verify-macos.sh \
  Scripts/verify-no-network.sh Scripts/verify-wsl.sh \
  Scripts/verify-m0-proof-provenance.sh \
  Scripts/test-verify-m0-proof-provenance.sh
./Scripts/test-verify-m0-proof-provenance.sh
python3 Scripts/validate_project_structure.py
git diff --check
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
./Scripts/verify-no-network.sh
```

### M0S.9 — Full Mac automated regression

```bash
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = "Version: 2.45.4"
python3 Scripts/validate_project_structure.py
swift test --package-path Packages/TeleprompterCore
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests
xcodebuild analyze \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release \
  CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive \
  Packages PrivatePresenterApp PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-no-network.sh
./Scripts/test-verify-m0-proof-provenance.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
./Scripts/verify-macos.sh
git diff --check
```

Record commands, exits, counts, Mac model/chip, macOS build, Xcode, Swift,
XcodeGen, and implementation commit. The UI-test shell remains a skipped future
surface; it is not the physical gate.

## 10. Focused Mac diagnosis and pre-push smoke

### 10.1 Environment record

Before launch, require a clean tree and bind the run to the exact commit:

```bash
test -z "$(git status --porcelain)"
IMPLEMENTATION_COMMIT="$(git rev-parse HEAD)"
test "${#IMPLEMENTATION_COMMIT}" = 40
```

Record:

- clean implementation commit;
- Mac model/chip, macOS version/build, Xcode, Swift, XcodeGen, Keynote;
- built-in/private and external display/projector name/model;
- cable/dock/adapter;
- exact arrangement and origins;
- `NSScreen.screensHaveSeparateSpaces` and visible Mission Control setting;
- initial extended topology and selected private screen;
- local evidence root.
- proof executable/build-log/manifest local paths and executable/log SHA-256.

Run this fresh clean-HEAD proof-build recipe twice when applicable: once for the
Phase A instrumented commit before its 24 diagnostic cells, and once after
Phase B M0S.9 automated verification before focused smoke. Phase A evidence is
diagnostic only. Reviews inspect the Phase B smoke/evidence, and Tom uses that
same copied Phase B binary for the physical matrix; do not rebuild between those
gates:

```bash
test -z "$(git status --porcelain)"
IMPLEMENTATION_COMMIT="$(git rev-parse HEAD)"
PROOF_ROOT="$HOME/Library/Application Support/Private Presenter/Validation/Builds/$IMPLEMENTATION_COMMIT"
BUILD_LOG="$PROOF_ROOT/proof-build.log"
DERIVED="$PWD/.build/M0ProofDerivedData"

rm -rf "$DERIVED" "$PROOF_ROOT"
mkdir -p "$PROOF_ROOT"
set -o pipefail
{
  printf 'commit=%s\n' "$IMPLEMENTATION_COMMIT"
  printf 'status_porcelain=%s\n' "$(git status --porcelain)"
  xcodebuild -version
  swift --version
  xcodebuild clean build \
    -project PrivatePresenter.xcodeproj \
    -scheme PrivatePresenter \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO
} 2>&1 | tee "$BUILD_LOG"

SOURCE_APP="$DERIVED/Build/Products/Debug/Private Presenter.app"
PROOF_APP="$PROOF_ROOT/Private Presenter.app"
test -d "$SOURCE_APP"
ditto "$SOURCE_APP" "$PROOF_APP"
PROOF_EXE="$PROOF_APP/Contents/MacOS/Private Presenter"
test -x "$PROOF_EXE"
EXE_SHA256="$(shasum -a 256 "$PROOF_EXE" | awk '{print $1}')"
LOG_SHA256="$(shasum -a 256 "$BUILD_LOG" | awk '{print $1}')"
MANIFEST="$PROOF_ROOT/proof-build-manifest.txt"
{
  printf 'commit=%s\n' "$IMPLEMENTATION_COMMIT"
  printf 'clean_head=true\n'
  printf 'executable_path=%s\n' "$PROOF_EXE"
  printf 'executable_sha256=%s\n' "$EXE_SHA256"
  printf 'build_log_path=%s\n' "$BUILD_LOG"
  printf 'build_log_sha256=%s\n' "$LOG_SHA256"
} > "$MANIFEST"

./Scripts/verify-m0-proof-provenance.sh "$MANIFEST"
APP="$PROOF_EXE"
```

This chain is local provenance, not signing/security attestation. The verifier
independently checks clean HEAD and rehashes the executable/log; caller-supplied
environment values alone never establish validity. Any HEAD, executable, log,
manifest, or source-default change invalidates downstream evidence and requires
a fresh proof build after the required automation/review restart.

### 10.2 Four-cell bounded first-show micro-matrix

Run the Phase A instrumented commit from a cold app launch and freshly entered
Keynote Presenter Display. Every launch supplies the exact validated commit:

```bash
./Scripts/verify-m0-proof-provenance.sh "$MANIFEST"
export PRIVATE_PRESENTER_EVIDENCE_COMMIT="$IMPLEMENTATION_COMMIT"
export PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256="$EXE_SHA256"
export PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG="$BUILD_LOG"
export PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256="$LOG_SHA256"
export PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST="$MANIFEST"

PRIVATE_PRESENTER_PROOF_LEVEL=floating \
PRIVATE_PRESENTER_ORDERING=front \
"$APP"

PRIVATE_PRESENTER_PROOF_LEVEL=floating \
PRIVATE_PRESENTER_ORDERING=frontRegardless \
"$APP"

PRIVATE_PRESENTER_PROOF_LEVEL=statusBar \
PRIVATE_PRESENTER_ORDERING=front \
"$APP"

PRIVATE_PRESENTER_PROOF_LEVEL=statusBar \
PRIVATE_PRESENTER_ORDERING=frontRegardless \
"$APP"
```

For each command, also set the matching
`PRIVATE_PRESENTER_CONTROLLER_COHORT` and
`PRIVATE_PRESENTER_REPETITION`; the diagnostic header must match the actual
operator-prepared window state and repetition.
Run `verify-m0-proof-provenance.sh` immediately before and after every launch;
all smoke and full-matrix files must report the same executable/log hashes.

For each cell, perform three cold repetitions in each of two separately labelled
normal-controller states: **visible in its desktop Space** and **explicitly
closed/ordered out**:

1. extended mode; select/confirm the private screen; record diagnostics path;
2. enter Keynote audience slideshow externally and full-screen Presenter Display
   privately;
3. record pre-H PID/bundle, app policy/active, panel and normal-controller state;
4. press H for the first cold show;
5. capture immediate, next-main-run-loop, `+100 ms`, and `+500 ms` state and
   prove Keynote remains frontmost/full-screen;
6. repeat H hide/show and confirm no normal-controller presentation;
7. explicitly switch to another **macOS Space** using the recorded Mission
   Control gesture or Control-Left/Right, then return; distinguish this from the
   ordinary Space key used to advance Keynote;
8. wait until the pending evidence records `correlationWindowClosed` for the last
   H/L action, then exit Keynote Presenter Display/full-screen;
9. only after that boundary, select Private Presenter via Cmd-Tab or its Dock
   icon solely to issue Cmd-Q. Record the activation as uncorrelated
   `postCorrelationQuit`; exclude it from the H/L focus verdict. In the
   `orderedOut` cohort this quit path must not present/order the controller;
10. wait for process exit and require a final file, no `.pending` sibling,
    terminal `sessionCompletion`, matching commit/config/cohort/repetition and
    executable/log hashes, then save local captures/video.

Per-cell publication check:

```bash
test -f "$FINAL_EVIDENCE"
test ! -e "$FINAL_EVIDENCE.pending"
tail -n 1 "$FINAL_EVIDENCE" | grep -q '"kind":"sessionCompletion"'
./Scripts/verify-m0-proof-provenance.sh "$MANIFEST"
```

L/drag/resize are intentionally absent from this Phase A trace. After the causal
branch is fixed and Phase B is green, repeat the chosen/default cells with L
unlock, header drag, all eight resize zones, and L lock as the focused smoke.

A diagnostic cell is invalid (and must be rerun) if commit/configuration does not
match, the recorder reports a fixed error, transactional publication is
incomplete, a pending sibling remains, or its path cannot be resolved.
`EVIDENCE_QUEUE_OVERFLOW` invalidates the cell even if later drain/final
publication succeeds. A valid cell fails behaviorally if the required panel is
invisible, Private Presenter becomes frontmost/active, Keynote exits full screen,
the controller raises, or the panel is key/main. In the later Phase B focused
smoke, unavailable L or any unsafe applied frame is also a failure. Apply section
5's decision table before changing any default. Any root-cause fix starts with a
new failing regression and reruns all affected cells.

### 10.3 Exact-commit retained-level rule and focused smoke

The micro-matrix isolates the order path; it does not by itself select the final
level. Use this objective rule, not a causal guess:

1. At `.floating`, discard invalid/failed cold-show orderings. Try the candidate
   commit's source-default ordering first (currently `frontRegardless`) when it
   qualifies; otherwise try the sole qualifying alternate. Run the complete
   matrix. If it fails, run the other cold-qualified ordering.
2. Select the first complete passer. If historical/current evidence means both
   were completely run and pass, compare the fixed safety vector: fewer
   activation transitions → fewer controller presentation/order operations →
   fewer panel key/main transitions → fewer missed required visibility samples;
   retain the source default if equal. Timing alone never breaks a tie.
3. If neither `.floating` ordering completes, apply the identical deterministic
   rule at `.statusBar`. Never waive a failed row.
4. The lowest level with a deterministically selected complete ordering is the
   proposed pair. If neither level has one, stop M0/feasibility; never try a
   higher, private, or raw level.
5. If the proposed pair differs
   from source defaults, create a new Lore commit changing only the bounded
   default and restart Mac automation, focused smoke, code-reviewer → verifier →
   architect, and Tom's **entire** physical matrix on that clean exact commit.

The procedure records every attempted per-level ordering outcome vector,
selection/tie-break reason, source default at that SHA, and `resolved-default match`. An
environment override whose pair differs from source cannot be final PASS.

The evidence sequence is therefore strict:

```text
Phase A instrumented commit + bound four-cell diagnosis
  → regression-backed causal-fix/default-candidate commit
  → Mac automation + focused smoke
  → code-reviewer → verifier → architect
  → Tom complete matrix on that exact clean commit/configuration
```

Any causal, ordering, or level/default commit after any arrow invalidates all
downstream approvals and final physical evidence; rerun from Mac automation (and
repeat affected diagnostic cells). Earlier files remain labelled diagnostic and
must never be relabelled as final evidence.

Before any push consideration, the current default candidate must demonstrate:

- first cold H and repeated H without activation/full-screen/controller change;
- L unlock/lock globally while Keynote stays active;
- header and all eight resize zones operable and contained;
- automatic content-neutral local diagnostics;
- actual mirroring recognized/blocked with the exact warning;
- disconnect/reconnect remains hidden/paused/shielded;
- no auto-reveal/resume and no normal-controller raise.

This focused smoke supports review/push consideration only. It does not mark M0
PASS or unlock M2.

## 11. Updated complete physical rerun and immutable result history

Implementation updates `docs/validation/overlay-proof-template.md` so the next
run retains all existing 15 steps and adds exact fields/checks from this plan.

Mandatory additions:

- before/immediate/delayed frontmost PID/bundle, app policy/active, panel
  visible/key/main/locked, controller visible/key/main/shielded/presentation;
- H/L registration OSStatus and direct command evidence;
- all four micro-matrix cells, both controller states, and three cold first-show
  repetitions per state;
- complete matrix at the lowest candidate and, if it fails, `.statusBar`;
- automatic diagnostic path/configuration identifier;
- declared/observed controller cohort, repetition, no mismatch, correlation
  closure, final `sessionCompletion`, and no pending evidence sibling;
- exact arrangement/origins, separate-Spaces, cable/dock/adapter;
- physical observation/photo of the actual audience display as well as screen
  captures;
- ordinary Keynote Space/arrows/remote and separately labeled macOS Space
  switching;
- `verifiedMirroring=true`, online/drawable counts, mirror relationship, exact
  warning, blocked show, hidden/paused/shielded order, no auto recovery;
- genuinely bright Presenter Display pixels behind the rounded interior;
- header plus top/right/bottom/left and all four corners, adjacent-display
  attempt, every applied frame path, no unsafe intermediate;
- stale projector-coordinate controller launch, mirroring while visible,
  selected-private-display disconnect, shield-before-warning/reposition, and
  no script/title in any diagnostic/controller/status surface;
- every local diagnostics/photo/screenshot/video path and path-resolution check.
- proof executable/build-log/manifest local paths and hashes, independent
  before/after launch checks, and smoke-to-physical executable equality.

The complete baseline `docs/validation/overlay-proof-result.md` content is an
**immutable historical prefix**: 14,486 bytes at SHA-256
`e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da`.
Its title, BLOCKED decision, observations, limitations, and checksum section
remain byte-for-byte unchanged. Do not edit, move, summarize, rehead, or delete
anything in that prefix. Code-only implementation does not modify this file.
Tom appends a separate current-decision ledger only during an actual run:

```markdown
---

# Current Milestone 0 Decision Ledger

## Decision entry — <date/time>

- Current decision: PASS / FAIL / BLOCKED
- Historical decision changed: NO
- Supersedes the prior current-decision entry: YES / NO
- Tester:
- Exact clean implementation commit (40 hex):
- Resolved default proof level:
- Resolved default ordering:
- Configuration matches source defaults: YES / NO
- Clean HEAD at proof build: YES / NO
- Proof executable local path and SHA-256:
- Proof build-log local path and SHA-256:
- Proof manifest local path:
- Focused-smoke executable SHA-256:
- Physical-matrix executable SHA-256:
- Smoke/physical executable equality: YES / NO
- Evidence validity: VALID / INVALID
- Complete matrix result:
- Diagnostics and local media roots:
...
```

If any row fails or lacks mandatory evidence, append that truthful result and
record FAIL/BLOCKED; never edit an incomplete or invalid entry away. If no ledger
exists, the historical BLOCKED decision is current. Only a complete PASS on the
reviewed exact clean commit, with `Configuration matches source defaults: YES`,
transactionally published valid evidence, identical verified proof binary, the
full physical matrix, and required reviews may
supersede the prior current entry. It never supersedes or changes the historical
BLOCKED evidence.

`Scripts/validate_project_structure.py` must verify that the result begins with
the exact baseline bytes/hash; extra bytes are permitted only after the prefix:

```bash
python3 - <<'PY'
import hashlib
import pathlib
import subprocess

path = pathlib.Path("docs/validation/overlay-proof-result.md")
baseline = subprocess.check_output([
    "git", "show",
    "940e1821f36c4125b0f81f623a6d24a015c22dcc:"
    "docs/validation/overlay-proof-result.md",
])
current = path.read_bytes()
assert len(baseline) == 14486
assert hashlib.sha256(baseline).hexdigest() == \
    "e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da"
assert current.startswith(baseline)
PY
```

Local captures containing unrelated/private screen content are not published or
committed; only content-neutral result text and local paths are committed.

## 12. Mac-versus-WSL evidence and push safety

### WSL may prove

- source/static structure and named-test inventory;
- shell syntax and Python validator behavior;
- protected checksums;
- prohibited API/network/entitlement absence;
- diff/patch hygiene and Git/origin configuration.

Run:

```bash
./Scripts/verify-wsl.sh
git diff --check
sha256sum -c docs/validation/source-artifact-checksums.sha256
```

### WSL may not prove

- Swift compilation/concurrency or Xcode/AppKit tests;
- Carbon registration/callback order;
- application/workspace activation;
- window level/order, Keynote, full-screen, or Spaces;
- mirroring/disconnect, opacity, custom gestures, or audience isolation;
- APFS semantics beyond source review.
- clean macOS proof-app build provenance or smoke/physical binary equality.

WSL-authored source-only work is committed locally and handed to a Mac; it is
not pushed to `main`. Create uncommitted handoff artifacts if needed:

```bash
mkdir -p .omx/tmp
git bundle create \
  .omx/tmp/2026-07-12-milestone-0-stabilization.bundle \
  940e1821f36c4125b0f81f623a6d24a015c22dcc..HEAD
git format-patch \
  --stdout 940e1821f36c4125b0f81f623a6d24a015c22dcc..HEAD \
  > .omx/tmp/2026-07-12-milestone-0-stabilization.patch
```

Neither `.omx` artifact is committed. A normal push is eligible only after Mac
compile/tests/analyze/build/format/static gates, focused smoke, and sequential
approval. Then, from a clean `main`:

```bash
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = "main"
test "$(git remote get-url origin)" = "https://github.com/thetomtimus/teleprompty.git"
test "$(git remote get-url --push origin)" = "https://github.com/thetomtimus/teleprompty.git"
git fetch --prune origin
read behind ahead <<EOF_COUNTS
$(git rev-list --left-right --count origin/main...HEAD)
EOF_COUNTS
test "$behind" = "0"
test "$ahead" -gt "0"
git push --porcelain origin HEAD:main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Never force-push or publish private physical media.

## 13. Logical Lore commits

The planning artifact is one documentation commit. Implementation follows these
reviewable RED→GREEN boundaries; every message includes honest `Tested` and
`Not-tested` trailers.

1. **Keep M1 durability invariant while stabilizing the physical proof** — v1
   canonical/store/startup/one-model regression locks.
2. **Make full-screen activation failures observable without exposing lecture
   content** — Phase A transactional recorder/observers, controller cohorts,
   bounded ordering, sentinel tests; run the Mac causal gate after this commit.
3. **Bind physical evidence to one clean proof executable** — local build/log
   manifest, independent hash verifier/mismatch tests, no rebuild through the
   physical matrix.
4. **Remove only the activation path proven by the Mac trace** — conditional;
   separate public-API ADR approval, failing regression, causal correction, and
   dedicated Lore commit only if the trace requires it.
5. **Keep proof controls recoverable without raising the normal controller** —
   Phase B controller placement/presentation split, H/L direct routing, and
   correlated ordered effects.
6. **Block hardware mirroring that drawable-screen inventory can omit** —
   all-online topology, fail-closed mapping, export, tests.
7. **Prove every custom interaction frame stays on the private display** —
   eight zones/header, exact-once frame records, native opacity test.
8. **Make the physical rerun append-only, explicit, and reproducible** —
   template, validators/audits, handoff based on actual evidence.
9. **Retain the lowest fully passing bounded configuration** — conditional
   default-only Lore commit followed by the complete validation restart.
10. **Append the current M0 decision without changing the failed historical
   proof** — separate documentation commit only after Tom's real rerun.

Representative implementation message:

```text
Keep proof controls recoverable without raising the normal controller

The blocked hardware run could not unlock the click-through panel, so the DEBUG
Carbon path now routes both bounded proof actions directly to the one AppModel.

Constraint: Keynote must remain frontmost and M1 schema v1 must remain unchanged
Rejected: Global NSEvent monitor | permission behavior and prohibited fallback
Confidence: high
Scope-risk: moderate
Directive: Do not turn this DEBUG registrar into the M4 product shortcut system
Tested: <exact targeted and full Mac commands plus focused smoke paths>
Not-tested: <remaining physical matrix or OS/display combinations>
```

## 14. Rollback and failure handling

- Revert stabilization commits in reverse order. No M1 data migration or
  snapshot rollback is required because schema v1 is unchanged.
- Unset `PRIVATE_PRESENTER_ORDERING`, `PRIVATE_PRESENTER_PROOF_LEVEL`,
  `PRIVATE_PRESENTER_EVIDENCE_COMMIT`, `PRIVATE_PRESENTER_CONTROLLER_COHORT`,
  `PRIVATE_PRESENTER_REPETITION`,
  `PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256`,
  `PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG`,
  `PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256`,
  `PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST`, and
  `PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME` to restore recorded defaults.
- Local validation files are independent of the snapshot and can be archived or
  deleted without touching user state.
- If a conditional ordering/default fix fails, revert only that commit and
  retain safe diagnostics/tests.
- If all allowed order/level pairs fail, append evidence, retain the current
  safest code/default, and keep M0/M2 blocked for feasibility reassessment.
- If all-online topology is uncertain, remain hidden/paused/shielded; never
  weaken it to drawable-only “safe.”
- Never recover with `.screenSaver`, raw levels, private APIs, activation/focus
  return, native `.resizable`, Accessibility, event taps, global key monitors,
  upload, or telemetry.

## 15. Implementation review, roles, and execution lanes

### Required approval order

After implementation and Mac evidence:

1. **code-reviewer — APPROVE:** scope, activation/privacy graph, content-neutral
   export, all-online topology, M1 preservation, prohibited-surface audit.
2. **verifier — PASS:** independently rerun exact targeted/full commands, inspect
   sentinel/checksum evidence, and match focused-smoke claims to local paths.
3. **architect — APPROVE:** confirm root cause/configuration is evidence-backed,
   controller/privacy architecture is fail-closed, and no second owner,
   workaround, or M2 surface exists.

Any critical/high finding is fixed and restarts affected tests and the approval
sequence. A role may not approve only from another role's summary.

### Available agent types

Installed roles include `explore`, `analyst`, `planner`, `architect`, `debugger`,
`executor`, `team-executor`, `test-engineer`, `code-reviewer`, `verifier`,
`critic`, `dependency-expert`, `researcher`, `writer`, `git-master`,
`code-simplifier`, `designer`, `vision`, `scholastic`, and the installed
Prometheus Strict roles.

Recommended staffing/reasoning:

- executor, debugger, test-engineer: xhigh;
- architect, code-reviewer, verifier, critic: high;
- explore/writer/git-master: bounded low-to-high support;
- designer/vision: not staffed; opacity is proof, not visual polish.

### Goal-Mode Follow-up Suggestions and Team guidance

- `$ultragoal` is the recommended durable implementation follow-up because the
  work crosses WSL source, Mac gates, physical smoke, reviews, and later Tom
  evidence.
- `$ultragoal` + `$team` is appropriate only with disjoint ownership:
  diagnostics/hotkeys/panel; tests/procedure; read-only Mac trace/debugging.
  Shared `AppModel`, `AppRuntime`, and validator integration stays leader-owned.
- `$ralph` is the explicit single-owner fallback in section 16.
- `$autoresearch-goal` and `$performance-goal` are not appropriate.

Optional Team launch hint:

```text
$team Execute the approved M0 stabilization plan under a leader-owned Ultragoal
ledger. Executor owns DEBUG diagnostics/hotkeys/panel configuration; test-engineer
owns new tests/procedure; debugger owns read-only Mac trace synthesis. Integrate
AppModel/AppRuntime through one owner. Stop before M2 and never mark the physical
gate passed from code.
```

Team verification path:

```text
Phase A RED/GREEN → 24-cell Mac causal diagnosis → Phase B RED/GREEN →
full core/app suite → analyze/Release/format/static/checksum → clean proof build
+ manifest/hash verification → exact-binary focused smoke → code-reviewer →
independent verifier → architect → same-binary physical matrix
```

## 16. Exact Ralph handoff

```text
$ralph Implement docs/plans/2026-07-12-milestone-0-stabilization.md exactly as
the dedicated Private Presenter M0 stabilization slice from baseline 940e182.
Use TDD and do not begin M2/editor/scrolling/product UI. Preserve
PersistedSnapshot schema v1, SnapshotStore/SnapshotMigrator, hidden-paused
restore/startup ordering, and exactly one AppModel. Preserve PRD.md and all
visual source artifacts byte-for-byte.

Execute in two phases. Phase A adds only the M1 regression locks, causal event
envelope, deterministic application will/did-become and will/did-resign,
workspace did-activate, and panel/controller window lifecycle observers;
fixed-capacity nonblocking local evidence whose overflow atomically and
permanently invalidates proof without delaying H/L/privacy;
observation of the existing controller lifecycle, and bounded
.floating/.statusBar plus orderFront/orderFrontRegardless diagnosis. It must not
split controller behavior or apply a causal fix. Keep Control-Option-H. Stop and
run the 24-cell Mac diagnosis across both historical controller states before
Phase B. Bind and validate each file's exact clean commit/config, declared and
observed cohort, repetition, executable SHA-256, build-log path/SHA-256, and
manifest. Reject a cohort mismatch before the first show and reject
any cell without a transactionally published final path ending in
sessionCompletion, no pending sibling, and zero queue overflow. Reject
`EVIDENCE_QUEUE_OVERFLOW` even when later finalization succeeds.

For each Phase A/final candidate, create the plan's fresh clean-HEAD proof build,
verify executable/log hashes independently before and after every launch, and
never treat caller environment values as provenance. After the last correlated
sample closes, exit Keynote and activate Private Presenter only to quit; tag that
activation post-correlation and prove the ordered-out controller stays out. Use
the same Phase B proof binary for focused smoke and Tom's matrix; any mismatch or
rebuild restarts downstream evidence.

Phase B begins only from the trace-selected cause. Any Carbon target or
activation-policy change requires current official public-API evidence, a RED
regression, a separately architect-approved ADR addendum, and a complete
downstream restart; if no permitted correction exists, stop M0/M2 BLOCKED. Then
split controller placement from presentation as the mandatory lifecycle
invariant, and add only DEBUG Control-Option-L, explicit NSScreen drawable/all-
online Core Graphics topology, ordered effects, contained drag/eight-zone
resize, opacity, and hostile recovery.

Never use .screenSaver, raw/private levels, native .resizable, focus return,
Accessibility, CGEventTap, or a global NSEvent monitor. Keep the baseline result
prefix byte-for-byte immutable; Tom appends current-decision ledger entries.
Any code/default/config change invalidates older approval evidence and restarts
Mac automation, both-controller-state smoke, code-reviewer -> verifier ->
architect, and the complete physical matrix.
If working under WSL, create logical local Lore commits and bundle/patch for Mac
validation but do not push. Tom's valid appended full physical rerun on the exact
source-default commit remains the only M0 PASS and M2-unlock authority.
```

## 17. Objective criterion that unlocks M2

M2 may begin only when **all** conditions are true:

1. At the exact implementation commit, all core/app tests, analyze, Debug/Release
   builds, formatting, no-network/prohibited-surface audit, structure validator,
   and protected checksums pass on a Mac.
2. Code reviewer approves, verifier independently passes, and architect approves
   in that order.
3. Tom runs the updated procedure on a real Mac, current Keynote, and a real
   second display/projector.
4. The appended rerun records PASS for every mandatory row, including:
   - valid correlated envelopes with every correlation window closed and a
     transactionally published final file ending in `sessionCompletion`, all headed with the
     exact clean final commit, source-default level/order, controller cohort, and
     repetition;
   - independently verified executable/build-log hashes match every header and
     ledger entry, and the focused smoke and physical matrix used the same proof
     binary without rebuild;
   - no accepted cell recorded `EVIDENCE_QUEUE_OVERFLOW` or another permanent
     proof-invalidity code;
   - three initial cold H samples in both `visibleDesktopSpace` and `orderedOut`
     cohorts without focus/full-screen/controller change;
   - repeated H and global L unlock/lock;
   - mouse, ordinary Keynote Space/arrows, and remote;
   - physical audience-display observation/photo with no teleprompter pixel;
   - explicit, separately labeled macOS Space switching;
   - actual exported mirroring, exact warning, blocked show, ordered
     hidden/paused/shielded recovery, no auto reveal/resume;
   - bounded order/level evidence and the lowest complete passing level retained;
   - bright-pixel rounded-interior opacity;
   - header/eight-zone/adjacent-display containment with every applied frame;
   - no H/L/topology/drag/resize event increments controller presentation or
     order-on count;
   - selected private destination is NSScreen-backed while CG-only topology
     members remain nonselectable;
   - stale projector frame, mirroring while visible, private-display disconnect,
     shield-before-warning/reposition;
   - complete environment and resolved local evidence paths.
5. The immutable 14,486-byte historical prefix passes its recorded SHA-256, and
   the final appended current-decision ledger entry is PASS without claiming to
   change the historical decision.
6. If the causal branch changed the Carbon target or activation policy, its
   public-API ADR addendum and separate architect approval exist.
7. No code/default/configuration changed after the evidence and approval SHA; any
   such change caused the complete downstream sequence to restart.
8. No unresolved critical/high defect, privacy failure, or unknown required
   checkpoint remains.

If either `.floating` or `.statusBar` has a failed matrix, that failure remains
recorded; M2 is unlocked only by the lowest **passing** bounded configuration.
If neither passes, M0 stays blocked and the product's feasibility is reassessed.

Focused smoke, source tests, reviews, or a pushed commit without Tom's complete
PASS cannot unlock M2.

## 18. Consensus record

- Planner iteration 4: **READY FOR ARCHITECT RE-REVIEW**. Integrated the
  two-phase causal gate, controller-cohort/config validation, transactional
  evidence publication, deterministic ordering, executable provenance, M1
  regression locks, and physical-only M2 gate.
- Architect iteration 4: **APPROVE**. Confirmed the causal/display/controller
  architecture, exact-commit/provenance restart rules, DEBUG-only boundary, and
  implementation readiness. Durable review:
  `.omx/context/milestone-0-stabilization-architect-iteration4.md`.
- Critic iteration 2, run only after Architect approval: **APPROVE**. Confirmed
  principle/option consistency, alternatives, pre-mortem, tests/commands,
  transactional proof integrity, practical procedure, Ralph handoff, and M2
  criterion. Durable review:
  `.omx/context/milestone-0-stabilization-critic-iteration2.md`.
- Consensus gate: **COMPLETE** in required Planner → Architect → Critic order.
