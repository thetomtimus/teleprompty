# Private Presenter — Milestone 4 Global Hotkeys, Focus Chrome, Menu, and Lifecycle

Status: **CONSENSUS APPROVED — M4 PLANNING ONLY**

Canonical publication target:
`docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md`

Implementation baseline: exact clean commit
`6aba2060c4308ea90d8973b2f606e5646e85d596` (`Keep the M3 boundary enforceable
on every host`). The eventual plan commit must have that commit as its sole parent and
must contain only the canonical plan file.

## 1. Outcome, authorization boundary, and stop rule

This plan delivers only `IMPLEMENTATION_PLAN.md` Milestone 4:

1. validated seven-action shortcut policy and existing schema-v1 round-trip;
2. a production all-or-nothing Carbon global-hotkey service;
3. production lock/click-through plus deterministic Focus Mode chrome;
4. one privacy-safe five-action status menu; and
5. controller reuse and ordered startup/termination lifecycle.

The owner explicitly authorizes immediate **M4 WSL candidate continuation** on the clean
M3 candidate even though M3 controlled-Mac Swift/AppKit/TextKit/display-link/package and
physical evidence remains pending. That authorization permits test/source RED/GREEN
candidate commits on WSL; it does **not** waive M3 evidence, convert WSL checks into native
evidence, or permit an M3/M4 completion claim. M4 Mac and physical work must record the M3
native evidence state honestly. An M4 hotkey run may exercise M3 commands, but it cannot
substitute for the separate M3 evidence contract.

Stop after the M4 source candidate, controlled-Mac replay when available, exact-SHA M4
hotkey proof when available, and independent M4 review. Do not implement M5 accessibility,
performance, or crash/display hardening; do not begin M6 polish; do not edit historical
M0-M3 evidence; do not push.

Grounding:

- canonical M4 rows and physical gate: `IMPLEMENTATION_PLAN.md:557-575`;
- seven shortcuts: `PRD.md:172-190`;
- five menu actions and close behavior: `PRD.md:218-228`;
- Keynote/hotkey/Focus acceptance: `PRD.md:250-268`;
- one authoritative model and panel boundary: `IMPLEMENTATION_PLAN.md:275-287` and
  `IMPLEMENTATION_PLAN.md:370-385`;
- production hotkey, Focus, and lifecycle design: `IMPLEMENTATION_PLAN.md:455-471`;
- test seams: `IMPLEMENTATION_PLAN.md:695-709`.

## 2. Requirements summary and non-goals

### 2.1 Binding requirements

- Defaults remain exactly Control-Option-Space, Up, Down, Left, Right, H, and L. Existing
  virtual-key defaults already encode those seven actions
  (`KeyboardShortcut.swift:3-44`).
- Product shortcuts use only public Carbon `RegisterEventHotKey`,
  `UnregisterEventHotKey`, and one application event handler. `Carbon.framework` is already
  linked (`project.yml:47-50`); add no package, target, or dependency.
- Registration, reconfiguration, rollback, dispatch, shutdown, and error states are
  deterministic and injectable. A collision is visible and never triggers another input
  mechanism.
- Never add or request Accessibility or Input Monitoring, TCC reset, `CGEventTap`,
  `CGEvent.tapCreate`, `AXIsProcessTrusted`, `AXUIElement`, `NSEvent` global/local key
  monitors, key-state polling, Apple Events, or application-focus restoration. The existing
  prohibited-surface audit already rejects the principal event-tap/AX/global-monitor paths
  (`Scripts/verify-no-network.sh:4-28`) and M4 strengthens it.
- One `@MainActor @Observable AppModel` remains the only product state/command authority
  (`AppModel.swift:14-16`). One `OverlayPanelController` remains the only creator/owner of
  one `TeleprompterPanel` (`OverlayPanelController.swift:45-49,101-124`).
- Hotkeys, menu items, controller controls, overlay controls, and lifecycle callbacks send
  typed `AppCommand`; none mutate panel, Carbon, scroll-session, or persistence state
  directly.
- Locked means `ignoresMouseEvents == true`; unlocked means false. `canBecomeMain` is always
  false. M4 deliberately evolves M3's permanent non-key rule
  (`TeleprompterPanel.swift:97-122`) to `canBecomeKey == !isOverlayLocked && NSApp.isActive`.
  Unlocking, showing, Focus reveal, and global/menu commands never call activation or make
  the panel key. With Keynote frontmost, `NSApp.isActive` is false and the panel remains
  non-key even when unlocked.
- Locked Focus Mode hides header and minimal functional quick chrome after exactly two
  seconds without pointer presence. Pointer presence reveals chrome while the panel remains
  click-through. Reduce Motion removes only decorative fade.
- The menu owns exactly five action items: Show Controller, Start/Pause, Show/Hide
  Teleprompter, Lock/Unlock, Quit. Titles and status-item metadata never contain script text
  or title.
- Closing the controller orders it out without quitting. Show Controller reuses the same
  instance. Quit saves a paused state and tears down in the order defined in section 5.5.
- Custom shortcut models and the reconfiguration seam round-trip under existing snapshot
  schema v1 (`PersistedSnapshot.swift:29-55`), but the customization affordance stays off by
  default until the physical proof in section 9 passes. Defaults remain usable.

### 2.2 Explicit non-goals

- No M5 VoiceOver audit, general keyboard traversal expansion, 50,000-word benchmark,
  crash/display hardening, or schema migration.
- No M6 reference-faithful styling, new gradient/tokens, visual score, or screenshot baseline.
  M4 may add only minimal functional header/quick chrome needed to prove Focus behavior.
- No Keynote automation, slide detection, remote interception, focus repair, private API,
  network surface, analytics, new entitlement, or new dependency.
- No change to the selected `.statusBar + frontRegardless` production overlay behavior,
  display privacy state machine, TextKit 2 stacks, M3 scroll engine/session authority, or
  per-frame publication rules.
- No automatic TCC reset and no claim that the app can prevent third-party capture.

## 3. RALPLAN-DR decision summary

### 3.1 Principles

1. **One typed authority:** every input converges on AppModel commands and existing safety
   guards; adapters own effects, never product policy.
2. **All-or-nothing global input:** a complete committed seven-chord set or a visible,
   recoverable unregistered state; never a silent partial/fallback state.
3. **Nonactivation before convenience:** no hotkey, lock, show, pointer, or Focus transition
   may displace Keynote.
4. **Permission-minimal and local:** Carbon plus location sampling only; no monitored input,
   TCC permission, network, private content in evidence, or dependency expansion.
5. **Evidence says exactly what ran:** WSL, controlled-Mac automation, and fresh-user Keynote
   proof are separate claims bound to exact SHAs.

### 3.2 Top decision drivers

1. Preserve ordinary Keynote Space/arrows/remote and its frontmost/key status while all seven
   teleprompter actions remain available.
2. Prevent a collision or failed reconfiguration from persisting an unusable or partially
   registered shortcut map.
3. Add menu/Focus/lifecycle without creating a second model/panel or weakening M0-M3
   privacy, scroll, persistence, and evidence contracts.

### 3.3 Viable options

#### Option A — dedicated production Carbon service; retained diagnostic proof service

- **Approach:** add `CarbonHotKeyService` for all seven product actions and keep the existing
  DEBUG-only `DiagnosticHotKeyService` intact for historical proof tests. A startup mode
  guarantees that exactly one registrar runs.
- **Pros:** clean production transaction/result model; no M0 proof instrumentation enters
  product behavior; easiest exact shutdown and collision tests; preserves diagnostic history.
- **Cons:** repeats a small amount of public Carbon callback plumbing; DEBUG routing must
  prove the two services never register H/L together.

#### Option B — promote the diagnostic registrar into one configurable service

- **Approach:** rename/generalize the diagnostic service, make proof hooks optional, and use
  the same object for product and historical proof modes.
- **Pros:** one Carbon implementation and inherently one handler/registrar.
- **Cons:** rewrites the source surface on which M0 proof tests and evidence depend; couples
  production semantics to correlation/evidence lifecycle; makes seven-action rollback and
  proof-only H/L behavior harder to review independently.

### 3.4 Choice

Choose **Option A**. Duplicate only the minimal callback shape; share the existing core
`ShortcutAction`/`KeyboardShortcut` values and a new injected `HotKeyRegistering` seam, not
diagnostic evidence machinery. In normal DEBUG and Release startup, only the product service
runs. A bounded DEBUG legacy-proof mode may run the diagnostic registrar only, with the
product registrar disabled. A test must reject simultaneous modes.

The invalid alternatives are `NSEvent` global/local monitoring, event taps/AX permission,
and key polling. They are not viable options because they contradict explicit policy and the
fresh-user no-TCC acceptance gate (`IMPLEMENTATION_PLAN.md:566-575`).

## 4. Acceptance criteria

All criteria are blocking unless marked as a WSL-only claim boundary.

1. The exact four M4.1, six M4.2, six M4.3, and five M4.4 canonical test names exist
   unchanged and pass on a controlled Mac.
2. The shortcut validator returns one canonical binding for every `ShortcutAction`, matches
   all seven PRD defaults, rejects missing/duplicate actions, duplicate chords, empty
   modifiers, and especially bare Space/arrows.
3. A custom valid seven-binding map encodes/decodes through existing `PersistedSnapshot`
   schema 1 without a schema bump. Invalid restored maps fall back to defaults with a visible
   generic local error; document/preferences/anchor recovery still succeeds paused.
4. Initial registration installs one handler, registers each action exactly once in stable
   ID order, and commits only after all seven return `noErr`.
5. Any initial failure attempts to unregister every staged reference in reverse order and
   remove the handler, reports action/chord/numeric `OSStatus` plus every cleanup status, and
   does not try another input API. It claims zero active hotkeys only when every cleanup call
   returns `noErr`; otherwise it enters cleanup-unknown and requires relaunch.
6. Reconfiguration retains unchanged references; unregisters all changed old references
   before staging changed proposed chords; suppresses staged callbacks until commit; and
   persists the proposed map only after the complete service transaction commits.
7. On proposed failure/collision, all proposed references are unregistered and every changed
   old chord is re-registered. Complete rollback restores the exact old active map and leaves
   the persisted old bindings unchanged while showing the conflict.
8. If old-map rollback itself fails, the service attempts to unregister rollback and
   unchanged references and remove the handler. When all cleanup calls return `noErr`, it
   enters `degradedClean` and truthfully reports **no global shortcuts are active**;
   controller Retry may attempt a clean zero-to-seven register. If any cleanup or handler
   removal fails, it enters `cleanupUnknown`, closes dispatch, retains the old persisted
   preferences as recovery input, never claims zero active OS registrations, and requires
   process quit/relaunch before another registration attempt.
9. A failure while unregistering changed old references aborts before any proposed
   registration. The service best-effort cleans up, closes dispatch, enters cleanup-unknown,
   and retains the old desired map; it does not guess whether the failed Carbon reference is
   still registered.
10. Unknown Carbon signature/ID returns `eventNotHandledErr`; known events dispatch exactly
   one typed command on the main actor and never activate the application.
11. Shutdown attempts every unregister before handler removal, returns all statuses, and is
    idempotent. A cleanup failure is never reported as success; after a successful flush the
    real termination path may still complete because process exit is the final OS cleanup
    boundary. Product and diagnostic registrars are never active together.
12. Hotkey commands use existing AppModel guards: empty text cannot start; privacy-unsafe
    states cannot show/start; speed remains clamped; hide/topology/quit retire M3 scrolling
    before panel/lifecycle effects (`AppModel.swift:197-210,279-302`).
13. Focus state is exactly `.unlocked`, `.lockedChromeVisible`,
    `.lockedFocusChromeVisible`, or `.lockedFocusChromeHidden`; every transition is covered.
14. Unlocked or Focus-off states show chrome with no hide timer. Locked+Focus+pointer-absent
    arms one injected two-second deadline; stale deadlines are ignored. Pointer entry reveals
    immediately and pointer exit receives a fresh full two seconds.
15. Pointer sampling uses only `NSEvent.mouseLocation` and panel-frame containment at a
    bounded 100 ms interval while visible+locked+Focus is enabled. It installs no event
    monitor, receives no click/key event, and stops when hidden/unlocked/Focus-off/teardown.
16. Pointer reveal never changes `ignoresMouseEvents == true`. Locked click-through remains
    true whether chrome is shown or hidden.
17. `TeleprompterPanel.canBecomeKey` is true only when unlocked and `NSApp.isActive` at query
    time; `canBecomeMain` is always false. Set-lock, unlock, show, Focus, pointer, and hotkey
    operations record no `NSApp.activate`, running-app activation, `makeKey`, or
    `makeKeyAndOrderFront` for the overlay.
18. Reduce Motion sets decorative chrome transition duration to zero but does not change
    state deadlines or time-based reading motion.
19. Minimal M4 header/quick chrome observes the same AppModel and dispatches commands. It
    does not introduce a second observable product store, mutate reader text, change the
    existing 64-point reader bottom inset, or perform M6 styling.
20. AppRuntime exposes identical model identity to controller window, overlay window, status
    item, hotkey dispatcher, and lifecycle coordinator. Exactly one model, panel, controller,
    status item, and scroll-session owner exist.
21. The menu has exactly five actionable items with the required dynamic labels. Separators
    do not count as actions; no item/button/help text contains script title/text.
22. Every menu action sends a typed AppCommand. Show Controller reuses the retained
    controller; if privacy is unsafe it shows only the shield. Closing the controller neither
    quits nor tears down overlay, status item, hotkeys, or model.
23. Startup completes snapshot restore paused/shielded, display observation/query, and
    privacy assessment before product hotkey registration. A startup collision is visible in
    the controller; menu/controller remain usable.
24. Quit order is: reject new mutating commands; pause and synchronously stop/capture the M3
    session; hide overlay and shield controller; flush the paused snapshot; unregister
    hotkeys; stop pointer/focus/display callbacks and idempotently tear down display link;
    remove status item; then reply terminate. Tests observe this exact order.
25. Flush failure cancels termination, exits the temporary termination-attempt state, leaves
    the app paused/hidden/shielded, preserves hotkeys/menu/controller recovery, reports a
    generic local error, and permits Retry Quit. No unregister/status removal/termination
    occurs before a successful flush.
26. Current-source M4 validation permits only the explicitly planned status item, product
    Carbon service, Focus objects, and dynamic key eligibility while carrying forward all
    applicable M0-M3 invariants. Historical M2/M3 contract files and evidence are unchanged.
27. `verify-no-network` finds no network/permission/event-tap/global-or-local-monitor/AX/key-
    polling/focus-workaround surface and entitlements remain sandbox-only.
28. WSL proof is limited to Python/shell/static inventory, prohibited-surface absence,
    history/protected bytes, and diff hygiene. It makes no Swift, Carbon, AppKit, timer,
    click-through, Focus, menu, Keynote, TCC, or physical claim.
29. On a fresh controlled-Mac account, all seven default registrations return `noErr` with
    Private Presenter absent/disabled in Accessibility and Input Monitoring before launch and
    with no TCC prompt during the run; TCC is not reset automatically.
30. With Keynote Presenter Display frontmost, all seven actions work; ordinary Space/arrows
    and a presentation remote still control Keynote; Keynote remains frontmost/key; overlay
    never becomes key/main; locked clicks pass through; locked pointer presence reveals
    informational chrome without accepting the click.
31. A real Carbon collision produces the visible clean-zero conflict, menu/controller
    recovery works, releasing the collision plus Retry registers all seven, and the exact
    content-neutral result is recorded at `docs/validation/hotkey-proof-result.md`.
32. Any unknown-cleanup result blocks the physical gate; fixed UI says `Global shortcuts
    could not be cleaned up safely. Quit and reopen Private Presenter before retrying.` No
    Retry registration occurs in that process, though menu/controller Quit remains usable.
33. Shortcut customization remains disabled by default in the WSL candidate and in any build
    lacking the accepted exact-SHA physical result. No evidence-free default-enable commit is
    allowed.
34. Independent code-reviewer, verifier, then architect approve the exact clean final SHA;
    no critical/high finding or failed automated/physical gate remains.

## 5. Architecture and operational contracts

### 5.1 Shortcut policy and persistence

Keep `ShortcutAction`, `ShortcutModifier`, `KeyboardShortcut`, and the exact default map in
`KeyboardShortcut.swift`. Add pure Foundation-only `ShortcutValidator` returning either a
sorted `[ShortcutBinding]` or typed violations:

```text
missingAction(action)
duplicateAction(action)
duplicateChord(actions, shortcut)
modifierRequired(action)
bareReservedKey(action, keyCode)
unknownActionCoverage
```

Validation requires exactly seven actions, one chord per action, at least one normalized
modifier for every product global shortcut, and no repeated `(virtualKeyCode, modifiers)`.
Key codes 49/123/124/125/126 are explicitly recognized as Space/arrows for error quality;
bare keys are rejected generally so ordinary application input is never captured.

`AppModel` owns committed `shortcutBindings` (already present at
`AppModel.swift:26-31,140-145`). On restore it validates schema-v1 bindings before using
them. Valid custom bindings remain desired/committed data; invalid bindings select the exact
defaults and publish a content-neutral `invalidShortcutConfiguration` error without failing
the rest of the snapshot. A reconfiguration request does not mutate or schedule persistence.
Only `.hotKeyReconfigurationCompleted(.committed(...))` updates bindings, increments the
snapshot revision, and schedules save. Failure leaves persisted bindings unchanged.

`ShortcutCustomizationAvailability.default` is false. The controller may show defaults,
registration status, collision, and Retry; editable recording is disabled with fixed generic
copy until an owner-approved exact-SHA physical proof enables a later separately reviewed
change. The underlying validator/reconfiguration/persistence seams are complete and tested.

### 5.2 Product Carbon service and exact transaction

Create an app-layer `HotKeyRegistering` seam for:

```text
installHandler(callback) -> Result<HandlerToken, OSStatus>
register(keyCode, carbonModifiers, EventHotKeyID) -> Result<HotKeyToken, OSStatus>
unregister(HotKeyToken) -> OSStatus
removeHandler(HandlerToken) -> OSStatus
```

The production adapter is `@MainActor CarbonHotKeyService`. A single noncapturing Carbon
callback decodes the parameter, validates a fixed product signature and explicit stable IDs
1...7, then enqueues the associated `ShortcutAction` onto the main actor. Stable IDs never
depend on dictionary order or Swift hash values:

```text
1 togglePlayback     2 increaseSpeed     3 decreaseSpeed
4 moveBackward       5 moveForward       6 toggleVisibility
7 toggleLock
```

Service state is `.unregistered`, `.registering`, `.registered(committedMap)`,
`.reconfiguring(oldMap)`, `.rollingBack(oldMap)`, `.degradedClean(failure)`, or
`.cleanupUnknown(failure)`. Only references in the committed active table dispatch; staged
references are ignored until atomic service commit. `degradedClean` is reachable only when
every reference cleanup and handler removal returns `noErr`. `cleanupUnknown` disables
dispatch and all in-process registration/retry because the service cannot know whether a
failed Carbon cleanup still owns a chord.

**Initial registration:** validate first; install one handler; register seven actions in
stable ID order into a staged table. On complete success publish the active table/map. On the
first failure, attempt to unregister staged references in reverse registration order and
remove the handler, then return the failed action/chord/numeric OSStatus plus every cleanup
status. All cleanup `noErr` returns `.unregistered` with zero active registrations and allows
Retry. Any cleanup/remove failure returns `.cleanupUnknown`, closes the dispatch gate, and
requires process quit/relaunch; it never asserts an OS reference was released.

**Reconfiguration:** validate proposed bindings before Carbon calls. Partition actions into
unchanged and changed. Keep unchanged references committed. Snapshot the exact old changed
bindings; remove changed references from dispatch and unregister all of them before staging
proposed changed bindings. This makes swaps among changed actions possible. If **any** old
unregister returns non-`noErr`, do not stage any proposed chord: close dispatch, best-effort
clean every known reference/handler, return `.cleanupUnknown` with the full status ledger, and
retain the old desired persisted map without claiming which OS registrations remain. When
all old unregisters succeed, stage proposed changed actions in stable order. On complete
success atomically merge unchanged+staged, publish committed proposed map, and return success
to AppModel for persistence.

**Proposed registration failure/collision:** remove all staged proposed references in reverse
order. Re-register every old changed binding in stable order while unchanged references
remain. If all old bindings return `noErr`, atomically restore the exact old active table and
return a visible `proposalRejectedOldMapRestored` result. AppModel keeps old persisted data.

**Rollback failure:** attempt to unregister every partially restored reference and every
retained unchanged reference, then remove the handler and clear the committed dispatch table.
If every cleanup returns `noErr`, return `.degradedClean(rollbackFailedNoHotKeysActive)`;
desired persisted old bindings remain and Retry may perform a clean zero-to-seven register.
If any cleanup/remove returns non-`noErr`, return `.cleanupUnknown` with the complete proposal,
rollback, cleanup, and handler status ledger. Fixed UI instructs Quit and reopen; in-process
Retry is disabled. Never claim partial recovery/zero OS registrations and never install
defaults or another API.

**Collision:** classify `eventHotKeyExistsErr` as collision but retain the numeric OSStatus;
all other non-`noErr` statuses use the same cleanup. Display fixed action/chord/status only,
never document/title/environment. Controller/menu commands remain available.

All `unregister` and `removeHandler` calls are status-bearing operations, not best-effort
`Void`. The fixed cleanup-unknown message contains no script/title/environment:
`Global shortcuts could not be cleaned up safely. Quit and reopen Private Presenter before retrying.`

**Dispatch/shutdown:** map actions to `.togglePlayback`, speed `current ± speedStep`,
`.moveBackward`, `.moveForward`, current visibility toggle, and current lock toggle. AppModel
does the current-state decision and safety checks; the callback does not read product state.
Shutdown marks dispatch closed, attempts all ref unregistrations in reverse stable order,
removes the handler last, clears closures, returns the complete status ledger, and is
idempotent. A non-`noErr` shutdown status is recorded as cleanup-unknown, never success. After
a successful paused flush the irreversible real quit may still reply true because process exit
is the final OS boundary for process-owned hotkeys; a cancelled/in-process shutdown may not
claim cleanup and may not re-register.

### 5.3 Diagnostic coexistence

`DiagnosticHotKeyService.swift` remains DEBUG-only and its historical tests/evidence stay
unchanged. Add a runtime `HotKeyStartupMode`:

- `.product` in normal DEBUG/Release execution: register the seven-action product service;
- `.legacyDiagnosticProof` only under the explicit existing proof harness: product service
  disabled, diagnostic H/L service enabled;
- simultaneous selection is a construction error covered by tests.

The fresh-user M4 proof always uses `.product`. It cannot pass using the diagnostic chords.
Do not merge diagnostic correlation/evidence state into product AppModel or the production
service.

### 5.4 Focus chrome, pointer sampling, and panel eligibility

Add Foundation-only `FocusChromeStateMachine` with the four states in criterion 13 and pure
inputs for lock, Focus enabled, pointer present, hide deadline token, and teardown. It returns
chrome visibility plus `armHide(token, 2.0)`/`cancelHide` effects. Every new arm creates a
generation token; stale deadlines do nothing.

Rules:

| Inputs | State / timer / interaction |
|---|---|
| unlocked | `.unlocked`; chrome shown; no timer; mouse accepted |
| locked, Focus off | `.lockedChromeVisible`; shown; no timer; click-through |
| locked, Focus on, pointer in | `.lockedFocusChromeVisible`; shown; no timer; click-through |
| locked, Focus on, pointer out | visible then arm exact 2.0 s; on current deadline hidden |
| hidden + pointer enters | visible immediately; cancel deadline; still click-through |
| pointer exits again | visible and new full 2.0 s; old token stale |
| unlock or Focus off | shown immediately; cancel timer |
| hide/teardown | cancel timer and pointer sampling |

`FocusModeController` owns an injected one-shot scheduler and transition-style provider.
`PointerPresenceMonitor` owns an injected repeating scheduler and
`PointerLocationProviding`. Production samples only `NSEvent.mouseLocation` every 100 ms,
compares it with the current panel frame, and sends presence changes only. Sampling runs only
while panel visible+locked+Focus; it never installs a global/local monitor, inspects events,
or changes mouse behavior.

`TeleprompterPanel` keeps `canBecomeMain == false` and changes only:

```swift
override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }
```

`setLocked` updates `isOverlayLocked` and `ignoresMouseEvents`; locking resigns an already-key
panel, but unlocking never orders, activates, or makes key. Existing `orderFrontRegardless`
show behavior remains (`OverlayPanelController.swift:174-205`). Tests record prohibited
operations, and physical proof samples Keynote after each action.

`OverlayPanelController` constructs its one panel, reader text system, and interaction owner
before AppModel exists but deliberately defers `NSHostingController` creation.
`connect(model:)` is called exactly once after the one model exists and installs the sole
hosting root bound to that model. Repeating connect with the same model is an idempotent no-op;
a different identity is a construction failure. No placeholder/replacement host and no second
observable store are introduced.
Minimal M4 `OverlayChromeView` supplies the existing header plus simple functional quick
controls using the same model. Both chrome regions share state-machine visibility/hit-testing.
When locked, shown chrome is informational because the panel remains click-through. Preserve
reader TextKit 2, active band, layer order, and existing bottom inset; defer visual treatment
to M6.

Reduce Motion is an injected/read-only system preference: fade duration `0` when true and a
single bounded decorative duration when false. The two-second deadline and M3 continuous
reading motion do not change.

### 5.5 Menu, startup, controller reuse, and quit lifecycle

`StatusItemController` creates one `NSStatusItem` and one `NSMenu` with exactly five action
items. It retains the one model only as a typed command dispatcher/model identity. Menu
presentation is derived from generic model phase/visibility/lock state:

1. `Show Controller` -> `.showController`
2. `Start` or `Pause` -> `.togglePlayback`
3. `Show Teleprompter` or `Hide Teleprompter` -> `.toggleVisibility`
4. `Lock` or `Unlock` -> `.toggleLock`
5. `Quit` -> `.requestQuit`

No script title/text is used for item, status button, accessibility help, tooltip, or error
copy. Collision status remains inline in the controller; Show Controller is the menu recovery
path and reuses the one window. Unsafe display state presents the existing shield, not
private content. `applicationShouldTerminateAfterLastWindowClosed` remains false
(`PrivatePresenterApp.swift:44-46`).

`AppLifecycleCoordinator` records startup/termination stages; `AppRuntime` still owns all
singletons (`AppRuntime.swift:73-89,133-201`). Startup order:

```text
construct one runtime/container/model/panel/controller/status/lifecycle
-> shield and present controller startup shell
-> load and restore snapshot forced paused
-> start display observation and query
-> evaluate privacy and apply shield/panel state
-> register the selected product-or-legacy hotkey service
-> start Focus/pointer machinery only if state requires it
-> mark menu actions ready
```

On `.showController`, safely place while shielded if needed and call a new idempotent
`showExistingController()` on the retained controller; never allocate another controller or
model. Normal close only orders out.

On `.requestQuit`, call the normal application termination request; the app delegate uses one
in-flight task. Exact `stopAndFlush` transaction:

```text
enter reversible terminationAttempting; reject new mutating commands
-> AppModel pause and synchronous stop/capture current M3 generation
-> hide overlay, shield controller, cancel pending show
-> flush an exact paused snapshot atomically
-> IF flush fails: leave paused/hidden/shielded, clear terminationAttempting,
   retain hotkeys/status/controller/display observation for recovery, reply false
-> IF flush succeeds: enter irreversible quiescence
-> unregister product or diagnostic hotkeys
-> stop Focus deadline, pointer sampling, display callbacks/observation, diagnostics;
   teardown scroll/display link idempotently
-> close controller and remove the one status item
-> reply true so NSApplication terminates
```

The first stop/capture invalidates the display link before persistence; the post-flush
teardown proves no callback remains. No unregister, status removal, or terminate reply true
may precede flush success. Repeated quit/stop calls are idempotent.

## 6. File ownership and protected surfaces

### 6.1 Create

| Path | Exact responsibility |
|---|---|
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Shortcuts/ShortcutValidator.swift` | Complete seven-action pure validation and typed errors. |
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Focus/FocusChromeStateMachine.swift` | Four-state pure transition/effect contract. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ShortcutValidatorTests.swift` | M4.1 canonical plus hostile policy/restore tests. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/FocusChromeStateMachineTests.swift` | M4.3 pure state/deadline/token tests. |
| `PrivatePresenterApp/Interfaces/HotKeyRegistering.swift` | Injected Carbon registration tokens/status operations. |
| `PrivatePresenterApp/Services/CarbonHotKeyService.swift` | One handler, stable IDs, staged commit/rollback/degraded teardown, main-actor dispatch. |
| `PrivatePresenterApp/Overlay/FocusModeController.swift` | Injected deadline scheduler and state-machine effect adapter. |
| `PrivatePresenterApp/Overlay/PointerPresenceMonitor.swift` | 100 ms location-only containment sampler. |
| `PrivatePresenterApp/Overlay/OverlayChromeView.swift` | Minimal functional M4 header/quick chrome; no M6 styling. |
| `PrivatePresenterApp/Menu/StatusItemController.swift` | One privacy-safe five-action status menu, typed commands only. |
| `PrivatePresenterApp/App/AppLifecycleCoordinator.swift` | Observable startup/quit ordering and flush-failure rollback. |
| `PrivatePresenterAppTests/CarbonHotKeyServiceTests.swift` | M4.2 canonical plus transaction/dispatch/shutdown hostility. |
| `PrivatePresenterAppTests/FocusModeControllerTests.swift` | M4.3 app/panel/timer/pointer/nonactivation tests. |
| `PrivatePresenterUITests/MenuLifecycleUITests.swift` | M4.4 canonical UI lifecycle/menu surface. |
| `Scripts/test_validate_project_structure_m4.py` | Static RED/GREEN M4 scope and carried-invariant contract. |
| `Scripts/run-m4-hotkey-collision-holder.swift` | Public-Carbon, content-neutral manual collision holder; no product target/dependency. |
| `docs/validation/hotkey-proof-result.md` | Created only after exact-SHA fresh-user controlled-Mac proof. |

Recursive source/test discovery means `Package.swift` and `project.yml` need no source-list
change (`project.yml:26-27,55-56,70-71`). Carbon is already linked.

### 6.2 Modify

| Path | Exact integration ownership |
|---|---|
| `KeyboardShortcut.swift` / `PersistedSnapshot.swift` | Only validation/canonical helpers needed for schema-v1 round-trip; no wire/schema change. |
| `AppCommand.swift` | Focus, shortcut request/result/retry, generic visibility/lock toggles, Show Controller, Quit commands. |
| `AppEffect.swift` | Reconfigure/retry hotkeys, apply Focus/panel state, show retained controller, request termination. |
| `AppModel.swift` | **Sole shared integration owner:** current-state command mapping, safety guards, committed shortcut/focus/menu state, persist only on service commit. |
| `DependencyContainer.swift` | Construct exactly one product service, Focus controller, pointer monitor, lifecycle/status dependencies; route effects/results. |
| `AppRuntime.swift` | Connect one model to both windows/status item; startup mode; exact startup/quit ordering. |
| `PrivatePresenterApp.swift` | Delegate termination remains normal; retain one runtime/delegate and reply from coordinator. |
| `ControllerPresentation.swift` / `ControllerView.swift` | Enable Focus toggle, show default shortcut/registration conflict/Retry, keep customization editing gated off. |
| `ControllerWindowController.swift` | Idempotently show/reposition the retained instance; unsafe state remains shielded. |
| `TeleprompterPanel.swift` | Dynamic unlocked+active key eligibility; main false; no activation. |
| `OverlayPanelController.swift` / `OverlayRootView.swift` | Bind same model once, drive Focus chrome, preserve one panel/reader/containment/order. |
| `AppModelTests.swift`, `ControllerPresentationTests.swift`, `OverlayPanelConfigurationTests.swift`, `OverlayPanelControllerTests.swift`, `ScrollSessionControllerTests.swift` | One-authority, safety, dynamic-key, no activation, M3 stop/reader regressions. |
| `Scripts/validate_project_structure.py` | Add current-source M4 validator/entrypoint carrying applicable M0-M3 invariants and replacing only milestone-only M3 prohibitions. |
| `Scripts/verify-no-network.sh` | Also reject local event monitors and key polling; preserve all existing checks. |

No parallel lane other than the declared integration owner may edit AppCommand/AppEffect/
AppModel/DependencyContainer/AppRuntime or lifecycle wiring.

### 6.3 No-change/protected decisions

- No change to `project.yml`, package manifest, Info.plist, entitlements, configs, persistence
  schema version/migrator, display models/evaluator/service, privacy coordinator/directives,
  M3 engine/mapper/clock/session/viewport/TextKit stacks, snapshot store, M0 proof scripts, or
  design/reference assets unless a named RED proves an integration defect and Architect
  explicitly approves a bounded plan revision.
- Byte-for-byte protect `PRD.md`, `IMPLEMENTATION_PLAN.md`, `HANDOFF.md`, all existing
  `docs/plans/*` through M3, and every validation artifact present at baseline. M4 may add only
  its new result; it never rewrites M0/M2 evidence or invents M3 evidence.
- Leave `Scripts/test_validate_project_structure_m2.py` and
  `Scripts/test_validate_project_structure_m3.py` unchanged as historical milestone contract
  tests. They are run from their milestone SHAs, not misrepresented as current M4-source
  validators.
- Preserve `.statusBar + frontRegardless`, one panel/model/session owner, sandbox-only
  entitlement, schema v1, local-only persistence, TextKit 2, and no per-frame AppModel calls.

### 6.4 Milestone-aware validator rule

The M3 current-source validator deliberately rejects `NSStatusItem`, Focus/product input, and
dynamic key eligibility (`test_validate_project_structure_m3.py:151-160,205-239`). Do not
weaken or rewrite that historical contract. Add `validate_m4_source()` and make the current
validator entrypoint call it. M4 copies forward every still-applicable M0-M3 invariant and
explicitly allows only:

- one `StatusItemController`/`NSStatusItem` construction;
- one `CarbonHotKeyService` production construction and one product handler in `.product`
  mode, plus runtime-mode mutual exclusion from the retained diagnostic implementation;
- the named Focus state/controller/pointer files;
- dynamic `canBecomeKey` with the exact unlocked+`NSApp.isActive` expression.

It continues to reject a second model/panel/scroll owner/status item/**product** handler,
other window levels/order modes, schema bump, dependencies/entitlements, TextKit 1,
global/local event monitors, event taps, AX, key polling, focus activation, networking, and
M5/M6 surfaces. Because the retained DEBUG diagnostic file necessarily contains its own
legacy `InstallEventHandler`, validation must inspect product construction and exclusive
startup mode rather than naively count that token across all source. Historical validation is
proven by checking out or reading baseline Git objects; current M4 source is never falsely
labeled M3-source conforming.

## 7. Exact TDD plan — test-only RED then minimum GREEN

For each numbered phase, commit `nA` with tests/validator contract only, observe the focused
failure for the intended missing symbol/behavior on a controlled Mac, then commit `nB` with
minimum product code and rerun the focused test plus every earlier phase. Do not squash RED
commits. WSL-authored pairs are explicitly **unobserved candidates** until a controlled Mac
checks out each `nA`, records the expected RED, and then checks out `nB` for GREEN.

### M4.0 — plan ancestry, M3 boundary, and preflight

At implementation handoff:

```bash
M3_BASE=6aba2060c4308ea90d8973b2f606e5646e85d596
PLAN=docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md
test "$(git rev-parse HEAD^)" = "$M3_BASE"
test "$(git show --pretty='' --name-only HEAD)" = "$PLAN"
test -z "$(git status --porcelain=v1)"
./Scripts/verify-wsl.sh
```

On a controlled Mac also run current M0-M3 package/app regressions, analyze, Release, format,
and no-network before observing M4 RED. If the separate M3 native evidence remains pending,
record `M3_NATIVE_EVIDENCE=PENDING` and continue only as the owner-authorized M4 candidate;
do not relabel that missing evidence as a regression waiver or M3 pass.

### M4.1 — shortcut policy and schema-v1 round-trip

`1A` creates `ShortcutValidatorTests.swift` with these canonical names unchanged:

- `testDefaultsMatchPRD`
- `testBareSpaceAndArrowsAreRejected`
- `testDuplicateChordIsRejected`
- `testCustomChordRoundTrips`

Add:

- `testEveryProductShortcutRequiresModifier`
- `testMissingAndDuplicateActionsAreRejected`
- `testCanonicalBindingsUseStableActionOrder`
- `testInvalidRestoredBindingsUseDefaultsWithoutDiscardingDocument`
- `testShortcutRoundTripKeepsPersistedSnapshotSchemaOne`
- `testCustomizationIsDisabledByDefaultUntilPhysicalProof`

```bash
swift test --package-path Packages/TeleprompterCore --filter ShortcutValidatorTests
```

Expected RED is missing validator/violation symbols and invalid-map restore policy. `1B` adds
only pure validation/canonical helpers and schema-v1 integration. GREEN plus the full package
suite proves exact defaults, no normal bare input, duplicates/coverage, stable encoding, and
no schema migration.

### M4.2 — production Carbon service and atomic reconfiguration

`2A` creates `CarbonHotKeyServiceTests.swift` with canonical names unchanged:

- `testRegistersEveryActionOnce`
- `testReconfigurationUnregistersOldChordTransactionally`
- `testPartialRegistrationRollsBack`
- `testCollisionSurfacesWithoutFallback`
- `testShutdownUnregistersAll`
- `testHandlerDispatchesExpectedCommand`

Add:

- `testInitialFailureLeavesNoActiveHotKeysOrHandler`
- `testStableCarbonIDsMapAllSevenActionsExactlyOnce`
- `testUnknownSignatureOrIdentifierIsNotHandled`
- `testReconfigurationKeepsUnchangedReferencesRegistered`
- `testChangedOldReferencesUnregisterBeforeProposedRegistration`
- `testOldUnregistrationFailureDoesNotStageProposalAndReportsUnknownState`
- `testStagedCallbacksDoNotDispatchBeforeCommit`
- `testFailedProposalRestoresCompleteOldMap`
- `testRollbackFailureTearsDownAllRegistrationsAndReportsNoActiveHotKeys`
- `testCleanupFailureNeverClaimsZeroActiveRegistrations`
- `testUnknownCleanupDisablesRetryUntilRelaunch`
- `testCleanupUnknownMessageIsFixedAndContentNeutral`
- `testProposedBindingsPersistOnlyAfterRegistrationCommit`
- `testFailedProposalKeepsPersistedOldBindings`
- `testRetryFromDegradedStateRegistersCleanSevenActionSet`
- `testDispatchRunsOnMainActorWithoutActivatingApplication`
- `testHotKeyCommandsCannotBypassEmptyScriptOrPrivacyGuards`
- `testProductAndDiagnosticRegistrarsNeverRunTogether`
- `testShutdownRemovesHandlerAfterReferencesAndIsIdempotent`
- `testShutdownReportsUnregistrationAndHandlerRemovalFailures`

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/CarbonHotKeyServiceTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

Expected RED is missing production service/seam/result/commands. `2B` implements section 5.2,
product startup mode, AppModel commit-on-success, Retry, and fixed conflict UI. Rerun M4.1,
full package tests, AppModel tests, diagnostic service/lifecycle tests, and no-network.

### M4.3 — lock, Focus state, pointer sampling, and chrome

`3A` adds these canonical names unchanged across core/app tests:

- `testEveryFocusTransition`
- `testLockedFocusHidesAfterTwoSeconds`
- `testPointerPresenceRevealsWithoutDisablingClickThrough`
- `testDynamicCanBecomeKeyRequiresUnlockedAndActive`
- `testUnlockNeverActivates`
- `testReduceMotionRemovesDecorativeFade`

Add:

- `testUnlockedAndFocusOffStatesNeverArmHideDeadline`
- `testLockedFocusArmsExactlyTwoSecondDeadline`
- `testStaleHideDeadlineIsIgnored`
- `testPointerExitRearmsFullDeadline`
- `testHideAndTeardownCancelDeadlineAndSampling`
- `testPointerSamplerRunsOnlyWhileVisibleLockedAndFocused`
- `testPointerSamplerUsesLocationOnlyAtOneHundredMillisecondInterval`
- `testLockedPointerRevealKeepsIgnoresMouseEventsTrue`
- `testInactiveApplicationCannotYieldKeyPanelEvenWhenUnlocked`
- `testShowHideLockFocusAndPointerPathsNeverActivateOrMakeKey`
- `testCanBecomeMainRemainsFalseInEveryState`
- `testFocusChromeUsesSameAppModelIdentityAsReaderWindow`
- `testOverlayHostingControllerIsCreatedOnceOnConnect`
- `testConnectModelIsIdempotentAndRejectsDifferentModel`
- `testFocusChromeDoesNotMutateTextOrChangeReaderInset`
- `testFocusPreferenceRoundTripsSchemaOne`

```bash
swift test --package-path Packages/TeleprompterCore --filter FocusChromeStateMachineTests
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/FocusModeControllerTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests
```

Expected RED is missing state/controller/pointer/chrome paths and M3 permanent-key assertion.
`3B` implements section 5.4 and updates the **current M4** test expectations without changing
historical result files. GREEN proves timing/token behavior, click-through, dynamic eligibility,
one model/panel, zero activation calls, and M3 reader/session regressions.

### M4.4 — five-action menu and lifecycle

`4A` creates `MenuLifecycleUITests.swift` and adds the canonical names unchanged:

- `testSingleModelIsSharedByBothWindowsAndStatusItem`
- `testMenuContainsFiveRequiredActions`
- `testClosingControllerDoesNotQuit`
- `testShowControllerReusesInstance`
- `testQuitFlushesPausedStateBeforeUnregisterAndTerminate`

Add:

- `testStatusItemOwnsExactlyFiveActionItems`
- `testMenuAndStatusTitlesNeverContainScriptTitle`
- `testEveryMenuActionDispatchesTypedAppCommand`
- `testQuitRequestReachesLifecycleAsTypedAppCommand`
- `testClosingControllerLeavesOverlayStatusAndHotKeysAlive`
- `testShowControllerWhileUnsafeRemainsShielded`
- `testStartupRegistersProductHotKeysAfterRestoreAndPrivacyAssessment`
- `testStartupCollisionLeavesMenuAndControllerRecoveryAvailable`
- `testQuitStopsAndCapturesBeforePausedSnapshotFlush`
- `testFlushFailureKeepsRecoveryServicesAndCancelsTermination`
- `testSuccessfulQuitStopsCallbacksBeforeStatusItemRemovalAndTerminateReply`
- `testRepeatedQuitAndShutdownAreIdempotent`
- `testRuntimeConstructsNoSecondModelPanelControllerStatusItemOrScrollOwner`

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterUITests/MenuLifecycleUITests \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticObserverLifecycleTests
```

Expected RED is missing status/lifecycle commands/controllers and reuse/ordered teardown.
`4B` implements section 5.5 under the sole shared integration owner. GREEN must observe model
identities, exact five actions, privacy-safe titles, controller reuse, startup order, flush-
failure rollback, and successful quit order.

### M4.5 — current milestone validator and prohibited-surface lock

`5A` creates `test_validate_project_structure_m4.py` requiring all M4 paths, all 21 canonical
test names, added hostile names including the fixed content-neutral cleanup-unknown error, one
model/panel/status item/product handler/session owner, stable seven IDs, exact dynamic-key
expression, schema v1, `.statusBar + frontRegardless`, five menu commands, two-second/100 ms
constants, and quit-order markers. Mutation tests inject each forbidden permission/monitor/
tap/AX/polling/activation/dependency/entitlement/M5/M6 surface, unsafe dynamic error content,
and duplicate authority. Observe focused static RED.

`5B` adds `validate_m4_source()`, switches only the current entrypoint, and strengthens
`verify-no-network.sh`. It does not weaken or edit the historical M2/M3 contract tests.

```bash
python3 Scripts/test_validate_project_structure_m4.py
python3 Scripts/validate_project_structure.py
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
```

## 8. Logical Lore commit pairs and candidate discipline

Every commit uses why-first Lore trailers with exact `Tested:` and honest `Not-tested:`.
Preserve test-only RED commits until controlled-Mac replay.

1. **Keep every product shortcut explicit and nonintrusive** — `1A` shortcut tests only;
   `1B` pure validator/schema-v1 restore policy.
2. **Keep global input complete through collisions and reconfiguration** — `2A` Carbon/
   AppModel tests only; `2B` production service, staged commit/rollback/degraded recovery.
3. **Reveal Focus chrome without taking Keynote input** — `3A` state/panel/pointer tests
   only; `3B` state machine, location sampler, dynamic key/click-through, minimal chrome.
4. **Keep menu and shutdown behind one retained model** — `4A` menu/lifecycle tests only;
   `4B` status item, controller reuse, lifecycle startup/flush/teardown.
5. **Keep M4 verifiable without widening permissions** — `5A` M4 validator contract only;
   `5B` current validator and prohibited-surface audit.
6. **Record the exact fresh-user hotkey candidate that passed** — evidence-only
   `docs/validation/hotkey-proof-result.md` after section 9. No historical evidence/source
   mutation and no default customization enablement.

For WSL `nA/nB` commits, use `Not-tested: Swift/Carbon/AppKit/Keynote/TCC behavior; WSL
unobserved candidate`. On transfer, retain every SHA in a content-neutral manifest and replay
the exact parent/child pair on the controlled Mac. Do not amend a WSL commit to imply native
observation.

## 9. Verification, physical proof, and evidence boundaries

### 9.1 WSL/static candidate gate

```bash
set -euo pipefail
BASE=6aba2060c4308ea90d8973b2f606e5646e85d596
bash -n Scripts/*.sh
python3 Scripts/test_validate_project_structure_m4.py
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
git diff --check
test "$(git diff --name-only "$BASE" -- PRD.md IMPLEMENTATION_PLAN.md HANDOFF.md \
  docs/plans/2026-07-12-milestone-0-stabilization.md \
  docs/plans/2026-07-12-milestone-1-core-state-durability.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md \
  docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md)" = ""
git diff --exit-code "$BASE" -- $(git ls-tree -r --name-only "$BASE" docs/validation)
git status --short
```

WSL may claim only source/path/test-name inventory, Python/shell behavior, prohibited-surface
absence, one-authority static counts, schema/config/entitlement text, protected baseline bytes,
origin/provenance, and diff hygiene. It cannot claim Swift compilation/concurrency, Carbon
registration/rollback, AppKit menu/timer/panel behavior, click-through, Focus timing, Keynote
focus, TCC absence, Accessibility/Input Monitoring state, packaging, or physical success.

### 9.2 Controlled-Mac automated and package gate

From each clean replay SHA use the pinned XcodeGen and current controlled Xcode/Swift. Record
Mac model/chip, macOS build, Xcode, Swift, XcodeGen, exact commands/exits/test counts, and
`M3_NATIVE_EVIDENCE=PASS|PENDING` without changing M3 evidence.

```bash
set -euo pipefail
SOURCE_SHA=$(git rev-parse HEAD)
test -z "$(git status --porcelain=v1)"
./Scripts/bootstrap-macos.sh
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests
python3 Scripts/test_validate_project_structure_m4.py
./Scripts/verify-no-network.sh
./Scripts/verify-macos.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
test -z "$(git status --porcelain=v1)"
```

Build/hash/package the exact Release app as in the M3 plan, recording only source, executable,
and archive SHA-256 plus environment/command results. App-host materialization failure is a
blocking automated failure, not infrastructure success. M4 automation may proceed while M3
physical evidence is pending, but M4 completion remains blocked and the result must say so.

### 9.3 Fresh-user Carbon/Keynote physical gate

Use the exact packaged `SOURCE_SHA`, synthetic public text, a fresh local macOS account, real
Keynote Presenter Display, and a real second display/projector. Do not run `tccutil reset`.

1. Before first launch, manually inspect Privacy & Security and record Private Presenter as
   absent or disabled in both Accessibility and Input Monitoring. Record Mac/macOS/Keynote/
   display versions without display serials or private paths.
2. Launch the exact Release app in `.product` hotkey mode. Confirm no TCC prompt appears and
   the controller reports `noErr` for all seven stable action IDs. Custom editing remains
   disabled.
3. Confirm extended-display privacy, select the private display, use a long synthetic script,
   show and lock the overlay, then make Keynote Presenter Display frontmost/full-screen.
4. Record Keynote frontmost application/key window and overlay visible/key/main/locked state
   before and after **each** action: Control-Option-Space start/pause, Up increase, Down
   decrease, Left back, Right forward, H hide/show, and L lock/unlock. Each action must occur
   once in each relevant phase and dispatch once.
5. Between teleprompter actions, use ordinary bare Space, all four ordinary arrows, mouse,
   and a presentation remote. Only Keynote advances/navigates; no bare command changes the
   teleprompter.
6. While locked, click through the overlay and confirm Keynote receives the click. Move the
   pointer into the panel: hidden chrome reveals within the 100 ms sampling tolerance while
   `ignoresMouseEvents` remains true and the click still passes through. Move out and confirm
   hide at two seconds; with Reduce Motion, reveal/hide has no decorative fade.
7. Use the committed public-Carbon collision holder to own one default chord, then start or
   Retry product registration. The helper's stable CLI accepts only
   `--action toggleVisibility --ready-file PATH`, registers Control-Option-H, writes exactly
   `READY action=toggleVisibility status=0` after successful ownership, installs no input
   observer, and unregisters on SIGTERM/SIGINT before exit. Run:

   ```bash
   set -euo pipefail
   mkdir -p .omx/tmp/m4-collision
   xcrun swiftc Scripts/run-m4-hotkey-collision-holder.swift \
     -framework Carbon -o .omx/tmp/m4-collision/holder
   READY=.omx/tmp/m4-collision/ready.txt
   rm -f "$READY"
   .omx/tmp/m4-collision/holder --action toggleVisibility \
     --ready-file "$READY" &
   HOLDER_PID=$!
   trap 'kill -TERM "$HOLDER_PID" 2>/dev/null || true; wait "$HOLDER_PID" 2>/dev/null || true' EXIT
   for _ in 1 2 3 4 5; do
     test -f "$READY" && break
     sleep 1
   done
   grep -qx 'READY action=toggleVisibility status=0' "$READY"
   # Launch/Retry the exact app now and record its visible collision/cleanup result.
   kill -TERM "$HOLDER_PID"
   wait "$HOLDER_PID"
   trap - EXIT
   ```

   Confirm visible action/chord/OSStatus conflict, zero product hotkeys active, no fallback/
   TCC prompt, and menu/controller operation. After holder exit, press controller Retry and
   confirm all seven register and work. The helper never captures keys or content; it only
   owns the known H chord. A holder cleanup failure blocks the run.
8. Close the controller; verify status/hotkeys/overlay remain. Show Controller from the menu
   and confirm the same instance, shielded if privacy became unsafe. Exercise the other four
   required menu actions and confirm generic titles.
9. Quit while playing. Confirm pause/stop/hide and paused snapshot flush precede hotkey/
   callback/status teardown; relaunch restores paused. Run an injected/manual disk-failure
   test only in controlled test configuration, not by risking the user's real script.
10. Recheck Accessibility/Input Monitoring and record that no enablement or prompt occurred.
    Confirm Keynote remained frontmost/key throughout hotkey/overlay steps; only intentional
    Show Controller/menu interaction may bring the normal controller forward and is recorded
    separately.

Any missing action, collision cleanup error, ordinary Keynote input interception, application
activation, panel key/main transition over Keynote, click-through failure, TCC prompt,
permission enablement, partial registration, privacy leak, or source/package mismatch blocks
M4. Write `docs/validation/hotkey-proof-result.md` only after the run; use content-neutral
PASS/FAIL/NOT-EXERCISED rows and hashes, never script/title/screenshot content or TCC resets.

### 9.4 Claim matrix and exact-SHA closure

| Evidence present | Permitted claim |
|---|---|
| WSL/static only | `M4 WSL source candidate`; M3 native remains pending |
| Controlled-Mac automated, no physical | `M4 native automated candidate`; no Keynote/TCC claim |
| M4 physical passes but M3 native evidence pending | `M4 hotkey physical candidate; M3/M4 completion blocked` |
| M3 evidence complete + M4 automated/physical exact-SHA pass + reviews | `M4 complete` |

After physical proof, commit only the new result. Prove the source tree is byte-identical from
`SOURCE_SHA` to evidence `FINAL_SHA`, prior validation files are unchanged, and package hashes
match. Any product fix creates a new `SOURCE_SHA` and requires affected RED/GREEN, automated,
package, and physical replay.

## 10. Independent review gate

On the exact clean final SHA run sequential independent roles:

1. **code-reviewer:** transaction cleanup/rollback/degraded state, Carbon callback isolation,
   Swift 6 actor safety, AppModel authority, panel nonactivation/click-through, focus timers,
   privacy-safe menu/errors, quit ordering, prohibited surfaces, and M4-only scope;
2. **verifier:** replay exact commands/test counts, inspect all seven registrations and
   physical rows, compare source/app/package/result hashes, protected prior bytes, M3 evidence
   status, and claim language;
3. **architect:** confirm one model/panel/handler/status/session owner, diagnostic separation,
   lifecycle boundaries, schema/dependency/permission invariants, and no M5/M6 creep.

Any critical/high finding or failed gate requires a fix pair and relevant complete replay.
Reviewers must not be the implementation author. Record verdict, role, exact reviewed SHA,
and bounded artifact; do not invent approvals after a stalled reviewer.

## 11. Risk register, pre-mortem, and expanded tests

| Failure | Early signal | Prevention/test | Recovery |
|---|---|---|---|
| Proposed chord collides after old refs removed | one non-`noErr`; missing action | staged table, old snapshot, complete rollback tests | restore exact old map or tear all down visibly |
| Rollback itself collides | old re-register fails | injected double failure plus cleanup ledger | clean cleanup -> degraded clean/Retry; any cleanup failure -> unknown/relaunch |
| Carbon unregister/remove fails | non-`noErr` cleanup status | inject old/staged/rollback/shutdown cleanup failures | close dispatch; never claim zero; block retry; quit/relaunch |
| DEBUG proof and product own H/L | `eventHotKeyExistsErr` on normal Debug launch | exclusive startup-mode construction test | stop both, choose one mode, retry clean |
| Staged Carbon event dispatches ghost command | action fires before map commit | committed-table lookup/generation test | ignore staged ID, fix, replay transaction suite |
| Unlock/Focus makes panel key over Keynote | activation/key transition sample | dynamic active predicate and operation recorder | immediately pause/hide; revert; rerun full physical gate |
| Pointer reveal breaks click-through | chrome appears and consumes click | independent visibility vs `ignoresMouseEvents` tests | keep informational while locked; no event monitor |
| Timer hides after pointer re-entry | stale token fires | generation-token deadline tests | ignore stale; re-arm full deadline |
| Quit unregisters before durable paused save | flush failure loses recovery controls | exact lifecycle event recorder and failure test | abort termination; keep services; Retry Quit |
| Status/menu leaks title | dynamic menu includes model document | fixed presentation model and sentinel tests | remove unsafe artifact, fix, rerun evidence |
| M4 validator weakens M3 history | old test/evidence edited or current called M3-pass | protected Git-object checks and milestone-aware entrypoint | restore bytes; add M4-specific allowance only |
| WSL candidate is called native/physical | no xcodebuild/package/fresh-account record | claim matrix and exact SHA | correct language; run missing gate |

Pre-mortem scenarios:

1. **Lecture starts with no usable shortcuts after one classroom utility owns H.** The service
   had partially registered six actions and persisted the new map. Prevention is all-seven
   staged commit, status-checked reverse cleanup, visible clean-zero state, and physical
   collision/retry; unknown cleanup instead requires relaunch and blocks the proof.
2. **Control-Option-L unlocks and steals Keynote focus.** The panel became key on unlocked
   state instead of checking application activity. Prevention is dynamic query-time
   eligibility, no activation/make-key calls, per-action frontmost/key sampling, and ordinary
   input checks.
3. **Quit reports success before the paused anchor reaches disk.** Hotkeys/status disappear,
   then flush fails. Prevention is reversible termination attempt, pause/stop/hide, blocking
   flush before irreversible teardown, failure rollback, and relaunch-paused proof.

Expanded layers:

- **Unit:** shortcut coverage/duplicates/encoding; Focus transition/token table; menu
  presentation; Carbon fake registrar operation order/status hostility.
- **Integration:** AppModel request/effect/result commit, real Carbon wrapper on controlled
  Mac, AppKit dynamic key/click-through, location sampler/timers, same-model hosting, status
  commands, startup/quit recorder, M3 stop/reader regressions.
- **End-to-end:** exact packaged app, fresh account, real Keynote/private+audience displays,
  seven actions, ordinary input/remote, Focus hover/click-through, collision/retry,
  controller close/reuse, quit/relaunch paused.
- **Observability/evidence:** numeric registration/cleanup results, fixed action IDs, ordered
  lifecycle events and identity counters in tests; content-neutral environment/command/test/
  hash/result record only. No production telemetry, script/title, raw environment, display
  serial, or private path.

## 12. Available agents and execution staffing

Available installed roles relevant to follow-up are `explore`, `analyst`, `planner`,
`architect`, `debugger`, `executor`, `team-executor`, `test-engineer`, `code-reviewer`,
`verifier`, `critic`, `dependency-expert`, `researcher`, `writer`, `git-master`,
`code-simplifier`, `designer`, `vision`, `scholastic`, and the Prometheus Strict roles.
Do not use `worker` outside active Team runtime. M4 needs no dependency/research/designer/
vision lane unless a new approved blocker changes scope.

Suggested staffing/reasoning:

- **executor, xhigh:** sole shared AppCommand/AppEffect/AppModel/DependencyContainer/
  AppRuntime/lifecycle integration owner;
- **test-engineer, xhigh:** RED checkpoints, fake Carbon/timer/pointer/failure order and UI
  lifecycle tests; never concurrently edits shared integration files;
- **executor or team-executor, high:** pure core shortcut+Focus state and tests;
- **executor or team-executor, xhigh:** Carbon service plus panel/Focus/status adapters on
  disjoint files, handing typed integration to the owner;
- **git-master, high bounded:** test-only ancestry, Lore trailers, WSL-to-Mac manifest,
  exact-SHA source/evidence closure; no behavior edit;
- **writer, high bounded:** content-neutral hotkey result only after physical evidence;
- **code-reviewer, verifier, architect, high:** independent final gates in that order.

### Goal-mode and Team follow-up

- `$ultragoal` is the default durable implementation ledger for RED/GREEN pairs, host replay,
  evidence SHA, and stop conditions.
- For parallel delivery use `$ultragoal + $team`: Team owns disjoint core, Carbon/Focus, and
  tests; the leader alone integrates shared model/runtime files and checkpoints evidence.
- `$autoresearch-goal` is inappropriate; this is implementation, not research.
- `$performance-goal` remains M5-only; M4 timing is correctness, not optimization.
- `$ralph` is included below as the owner's requested explicit persistent single-owner
  handoff, not a permission to begin in this Ralplan.

Launch hints (do not run during planning):

```text
$ultragoal Execute only the approved Private Presenter M4 canonical plan. Own exact
baseline/plan ancestry, RED/GREEN ledger, one shared integration owner, WSL-to-Mac replay,
fresh-user Keynote/hotkey evidence, exact-SHA closure, and stop before M5.

$team 3 Execute disjoint M4 lanes under the Ultragoal leader: executor owns pure shortcut/
Focus core and tests; team-executor owns Carbon/Focus/pointer/status adapters without shared
model edits; test-engineer owns transaction/timer/menu/lifecycle RED evidence. Leader alone
edits AppModel/effects/runtime/lifecycle integration.

omx team 3 --task 'Execute only the approved Private Presenter M4 plan under a leader-owned
Ultragoal ledger; preserve disjoint ownership, transactional Carbon semantics, one model/
panel, WSL/Mac/Keynote evidence boundaries, and stop before M5.'
```

Team verification path:

1. Each lane returns changed paths, RED SHA/expected observed failure, GREEN SHA/result, and
   focused command; no shared integration edit collision.
2. Leader integrates in phase order and runs all focused suites, full package/app/UI,
   M0-M3 applicable regressions, validator/no-network, format/analyze/Release, protected bytes.
3. Team stops with checkpoint-ready evidence. Controlled Mac replays every unobserved WSL
   pair and produces package/physical evidence; Team does not self-certify physical results.
4. Ultragoal owns source/result SHA closure and independent reviews before terminal status.

### Explicit Ralph handoff

Only on a later explicit execution invocation:

```text
$ralph Implement only Private Presenter M4 from
docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md on the exact plan commit.
Follow logical test-only RED/minimum-GREEN pairs 1A/1B through 5A/5B sequentially; preserve
one AppModel/panel and all M0-M3 history/evidence; use only Carbon with exact rollback/
collision/degraded semantics; add no Accessibility/Input Monitoring/event tap/global or
local monitor/focus workaround; label WSL work candidate-only; replay every pair on a
controlled Mac; run the fresh-user Keynote gate; create only the M4 hotkey result; complete
independent code-reviewer -> verifier -> architect review; stop before M5 and do not push.
```

## 13. ADR

**Decision.** Add a distinct production seven-action Carbon service with staged
all-or-nothing transactions; pure shortcut and Focus state; location-only pointer sampling;
one model-bound minimal chrome and five-action status item; and a reversible flush-first
lifecycle coordinator.

**Drivers.** Keynote nonactivation and ordinary-input preservation; complete/recoverable
hotkey state through collision; one-authority integration with honest WSL/Mac evidence.

**Alternatives considered.** Promote the DEBUG diagnostic registrar; use `NSEvent` monitors;
use event taps/Accessibility/Input Monitoring; keep the panel permanently non-key; use hover
events on the locked click-through panel; create a SwiftUI `MenuBarExtra`/second model; tear
down before flush.

**Why chosen.** A separate production Carbon service isolates proof instrumentation while
using the only authorized permission-free global input path. Dynamic unlocked+active key
eligibility supports intentional normal-app interaction without allowing a background
hotkey/unlock to take Keynote. Location sampling is the only way to reveal informational
chrome through a click-through window without monitoring input. One model/status/lifecycle
path preserves safety and deterministic teardown.

**Consequences.** Reconfiguration cannot be OS-atomically reserved; it has a short explicit
unregister/stage/rollback window. A rollback failure yields a truthful zero-active degraded
state only if every cleanup succeeds; otherwise cleanup state is unknown, dispatch/retry is
closed, and relaunch is required.
M3's current-source permanent-non-key validator becomes historical at its SHA while M4 carries
forward its behavioral intent through stronger nonactivation tests. Custom editing remains
off pending physical proof. M4 completion cannot be claimed while required M3 evidence is
still pending.

**Follow-ups.** A later owner-approved, separately tested change may enable shortcut editing
by default only after accepted exact-SHA hotkey proof. M5 owns accessibility/performance/
lifecycle hardening beyond this bounded quit path; M6 owns visual polish. No follow-up may
rewrite earlier evidence.

## 14. Consensus and publication gate

Planner record:

1. Dedicated native Planner was attempted twice and exceeded bounded waits without an
   artifact; it was interrupted.
2. The active standalone Planner lane produced this grounded draft from the clean baseline,
   repository context snapshot, M4 source requirements, and current M3 architecture.
3. The dedicated native Architect exceeded a bounded 240-second wait and was interrupted.
   A durable direct installed-role review at
   `.omx/drafts/m4-architect-review-iteration1.md` returned **ITERATE** against draft SHA-256
   `7fb7cbd339d52d210399858581586521902671c8f4b665f38b9571359d23b0dc`.
4. Planner revision 2 now distinguishes clean-zero from unknown Carbon cleanup, handles old
   unregister/shutdown status, blocks retry until relaunch when cleanup is unknown, defers
   overlay host creation until one model connection, validates product-vs-diagnostic handler
   coexistence correctly, adds hostile tests, and fixes checksum verification.
5. Renewed direct Architect review at
   `.omx/drafts/m4-architect-review-iteration2.md` returned **APPROVE** against substantive
   Planner revision SHA-256
   `38326a5ab8104b856e2a0b79cccda35422831fe33ac6f9a08706fdcad5bf6417`.
   It approved transaction truthfulness, authority, dynamic nonactivation, Focus sampling,
   lifecycle recovery, validator coexistence, and host/evidence boundaries.
6. Only after Architect approval, the dedicated native Critic was started. It exceeded a
   bounded 240-second wait and was interrupted. The durable direct installed-role fallback at
   `.omx/drafts/m4-critic-review-iteration2.md` returned **APPROVE WITH MINOR PUBLICATION
   IMPROVEMENTS** against plan SHA-256
   `05aca077ea1e69e8bc6171dc6f5236a6048f301665ae049d9f52d934110892f6`.
7. Planner applied all Critic improvements without architectural change: corrected the Focus
   criterion reference, added the fixed content-neutral cleanup message test/validator, and
   made the collision holder's controlled-Mac CLI/compile/run/cleanup sequence exact.
8. Final verdict: **PLANNER READY -> ARCHITECT APPROVE -> CRITIC APPROVE** in the required
   sequence. The exact final approved planning-artifact SHA-256 is verified during
   publication and reported with the commit evidence rather than embedded self-referentially
   in these bytes.

The requested deliverable consensus is complete through the owner-authorized direct-role
fallback. The OMX tracker-only clean-state gate is not asserted: the available collaboration
reviewers were not tracker-backed native lanes, so standard mode cancellation closed the
runtime after the durable verdicts rather than fabricating provenance. This runtime
provenance limit is not an implementation approval or an M3 evidence waiver. The remaining
publication sequence is planning closure, not implementation: copy only these approved bytes
to the canonical docs target, make the single plan-only Lore commit, run the publication
proof, and stop. No execution mode is entered.

Planned Lore commit:

```text
Make M4 global control safe to continue from the WSL candidate

Private Presenter needs permission-free global control, click-through Focus chrome,
and recoverable lifecycle behavior without treating pending M3 Mac evidence as complete,
so the plan binds Carbon transactions and every UI surface to one model and exact host gates.

Constraint: Planning only from exact clean M3 WSL candidate 6aba2060c4308ea90d8973b2f606e5646e85d596
Rejected: Wait for M3 native evidence before planning M4 | owner explicitly authorized honest WSL candidate continuation
Rejected: Use event monitors, event taps, or Accessibility/Input Monitoring | violates permission and Keynote-input constraints
Confidence: high
Scope-risk: moderate
Directive: Preserve transactional rollback, Keynote nonactivation, one model/panel, host claim boundaries, and stop before M5
Tested: Clean baseline/provenance inspection and sequential Planner/Architect/Critic consensus
Not-tested: M4 Swift/Carbon/AppKit/Keynote/TCC behavior; this commit is a plan only
```

Publication proof after commit:

```bash
BASE=6aba2060c4308ea90d8973b2f606e5646e85d596
PLAN=docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md
test -f "$PLAN"
test "$(git rev-parse HEAD^)" = "$BASE"
test "$(git diff --name-only "$BASE"..HEAD)" = "$PLAN"
test "$(git show --pretty='' --name-only HEAD)" = "$PLAN"
git diff --exit-code "$BASE" -- PRD.md IMPLEMENTATION_PLAN.md HANDOFF.md \
  docs/plans/2026-07-12-milestone-0-stabilization.md \
  docs/plans/2026-07-12-milestone-1-core-state-durability.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md \
  docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md \
  $(git ls-tree -r --name-only "$BASE" docs/validation)
test -z "$(git status --porcelain=v1)"
```

No implementation, execution handoff, M5 work, push, or evidence rewrite occurs in this
Ralplan run.

## 15. Planner revision changelog

- Grounded the M4 boundary in the exact clean M3 WSL candidate and made pending native M3
  evidence explicit rather than a blocker or a waiver.
- Defined complete initial/reconfiguration/rollback/rollback-failure Carbon semantics,
  stable IDs, callback commit gating, diagnostic coexistence, and persistence timing.
- Defined Focus states, exact two-second tokenized deadline, 100 ms location-only sampling,
  dynamic key eligibility, click-through, same-model chrome, and Reduce Motion behavior.
- Defined exactly five privacy-safe menu actions, controller reuse, reversible flush-failure
  lifecycle, and successful teardown order.
- Added path ownership, all 21 canonical names plus hostile tests, RED/GREEN pairs, M4-aware
  validator policy, WSL/Mac/fresh-user gates, claim matrix, logical commits, independent
  review, staffing/Team/Ultragoal guidance, and the requested Ralph handoff.
- Applied Architect iteration-1 repairs: status-bearing unregister/remove behavior,
  clean-zero versus cleanup-unknown recovery, relaunch-only retry after unknown cleanup,
  one deferred overlay host, product-mode handler validation, typed Quit test, and corrected
  checksum check.
- Applied Critic approval improvements: corrected the acceptance cross-reference, locked the
  cleanup-unknown copy into tests/static validation, and added a reproducible public-Carbon
  collision-holder build/run/teardown contract. Consensus is complete; no implementation or
  execution handoff occurred.
