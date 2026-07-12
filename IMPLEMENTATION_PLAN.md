# Private Presenter Teleprompter — Implementation Plan

Status: **GUARDED M1 SOURCE IMPLEMENTED IN WSL; MAC VALIDATION, INDEPENDENT APPROVALS, COMMITS, AND PUSH PENDING**
Original planning baseline: `main` at `2bba07dd75537c6159016afff48b93a3f8d8d86d`; M1 companion-plan baseline: `cca4229be4299eadc0370e8c26fae6f71e621ffc`; guarded implementation parent: `dfaec0b3b933aca46907003530dead19ae01babc`
Delivery boundary: M1.1–M1.4 source/tests and WSL-safe validator/audit changes are present in the uncommitted working tree. The sandbox exposes `.git` read-only, `swift` is absent, and the bootstrap requires macOS, so no Swift/Xcode/AppKit/APFS pass or Lore commit is claimed. `origin` is exactly `https://github.com/thetomtimus/teleprompty.git` for fetch and push; no push is authorized until all Mac gates, independent review, clean-tree, fresh-fetch, and origin/main divergence checks pass.
Toolchain contract: Xcode 16.0 or newer with Swift 6.0; Swift tools version 6.0; XcodeGen 2.45.4 exactly
Product identity: app name `Private Presenter`; target/scheme `PrivatePresenter`; local-only bundle identifier `com.privatepresenter.teleprompter`
Deployment target: macOS 14.0 unless Milestone 0 produces concrete evidence that a required API or reliable behavior needs newer

## 1. Outcome, sources, and non-negotiable boundaries

Build a native Swift/SwiftUI macOS teleprompter whose single AppKit-owned overlay remains visible over Keynote's full-screen Presenter Display on the presenter's selected private screen, while Keynote keeps focus and the audience screen never receives a teleprompter window. The script scrolls smoothly, remains local, survives relaunch, and uses the supplied restrained dark-blue visual language.

The implementation must preserve these source-of-truth artifacts byte-for-byte:

- `PRD.md` — complete product requirements and the 15-item v1 acceptance sequence.
- `references/teleprompter-ui-reference.png` — primary visual reference (896×634).
- `design/concept.html` — visual guidance only; never ship or execute it in the product.
- `design/teleprompter-concept.png` — product-specific visual interpretation (1440×723).

Hard boundaries:

1. Native Swift, SwiftUI, AppKit, and Apple system frameworks only at runtime. No Electron, WebView, browser wrapper, HTML runtime, or JavaScript.
2. No network client/server entitlement, request code, telemetry, analytics, account, cloud, collaboration, updater, or AI feature.
3. Script content and settings stay in the app's local container. Logs and signposts must never include script text.
4. Display privacy fails closed. Mirroring, a missing selection, ambiguous identity, or a topology transition pauses and hides/blocks the overlay before any reassignment. The app warns instead of inferring human intent.
5. The app cannot identify Keynote's audience window without prohibited Keynote integration. It identifies a candidate private display, clearly names it, and requires confirmation whenever built-in-display/default assumptions are insufficient.
6. A real Mac, real Keynote, and an actual second display/projector are mandatory evidence. WSL, mocks, an ordinary desktop window, or a single-display full-screen test cannot satisfy the overlay/privacy gate.
7. The full-screen overlay and private-display safety proof is the first product milestone and a hard stop before editor breadth or visual polish.
8. `PRD.md` out-of-scope items remain deferred. Do not broaden v1 during implementation.

### 2026-07-12 sequencing amendment

`docs/validation/overlay-proof-result.md` truthfully records the physical M0 run as **BLOCKED**, not PASS. Tom explicitly authorized the substantially orthogonal M1 core-state/local-durability slice to proceed under `docs/plans/2026-07-12-milestone-1-core-state-durability.md`. This is not an M0 waiver: the unresolved focus/full-screen interruption, key/main diagnostics, unlock/drag/resize testability, mirroring, opacity, boundary containment, bounded-level comparison, hostile recovery, explicit Space switching, environment record, and physical audience-display checks remain must-fix gates before M2 UI expansion, beta use, or any readiness claim.

## 2. Evidence boundary and primary references

Official/upstream evidence supports the individual design ingredients, not the end-to-end Keynote claim:

- Apple documents `.nonactivatingPanel` as a non-activating panel style, `.canJoinAllSpaces` as Space participation, and `.fullScreenAuxiliary` as sharing a full-screen Space: <https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel>, <https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces>, <https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary>.
- `orderFront(_:)`/`orderFrontRegardless()` do not make a window key or main; `ignoresMouseEvents` makes it transparent to pointer events: <https://developer.apple.com/documentation/appkit/nswindow/orderfront(_:)> and <https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents>.
- AppKit/Core Graphics provide screen enumeration, the `NSScreenNumber` bridge, mirror-set queries, and reconfiguration notification/callbacks, but do not reveal which physical display a person intends as the audience: <https://developer.apple.com/documentation/appkit/nsscreen>, <https://developer.apple.com/documentation/coregraphics/quartz-display-services>.
- macOS 14 added `NSView.displayLink(target:selector:)`; Core Video display links are deprecated in favor of view/window/screen display links: <https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14>, <https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)>.
- XcodeGen 2.45.4 is the pinned upstream project generator: <https://github.com/yonaskolb/XcodeGen/releases/tag/2.45.4>.

Consequently, the plan treats window level, Keynote behavior, Carbon hotkey permission behavior, and physical privacy as empirical compatibility gates. Do not convert a passing unit test into a platform claim.

## 3. RALPLAN-DR decision summary

### Principles

1. **Prove the riskiest platform behavior first.** Full-screen Keynote overlay behavior and audience isolation precede product expansion.
2. **Fail closed on privacy.** Hide and pause before evaluating a changed or ambiguous display topology; never silently select an external display.
3. **Keep policy pure and testable.** Scrolling, display decisions, anchors, persistence schemas, shortcut validation, and geometry belong in a Foundation-only core.
4. **Use the narrowest native mechanism.** Prefer a non-activating panel, the lowest passing window level, Carbon chord registration, and zero runtime dependencies.
5. **Preserve Keynote's input ownership.** A locked overlay is never key/main, ignores mouse events, and does not intercept ordinary Space/arrows.

### Top decision drivers

1. Reliable presence in Keynote's full-screen Presenter Display Space without focus theft.
2. Prevention of accidental audience-display disclosure during normal use and topology changes.
3. Reproducible development and deterministic tests, including responsive behavior at 50,000 words.

### Viable project options

| Option | Advantages | Costs / limits | Decision |
|---|---|---|---|
| A. XcodeGen manifest + generated project + local Swift package | Reviewable targets/settings; reproducible; clear package/test split; avoids hand-edited project state | Requires pinned generator on macOS; generated project must stay in sync | **Chosen** |
| B. Committed hand-maintained `.xcodeproj` + local package | Opens with no generator | Opaque/noisy `.pbxproj`; easy machine-state drift; harder structural review | Viable fallback only if XcodeGen cannot model a proven requirement |
| C. Swift Package executable only | Minimal manifest; excellent pure-core tests | Poor GUI app lifecycle, resources, entitlements, UI-test, and scheme fit | Invalid for the complete product |

Use XcodeGen `2.45.4` exactly. Commit `project.yml`, `.xcodegen-version`, configuration, and source. Generate `PrivatePresenter.xcodeproj`; never hand-edit or commit it. Add `/PrivatePresenter.xcodeproj/` to `.gitignore`. `Scripts/bootstrap-macos.sh` rejects any other XcodeGen version and regenerates the disposable project. If XcodeGen later cannot model a proven requirement, stop and amend this ADR before changing the committed-project policy.

## 4. ADR-001 — Architecture decision

### Decision

- XcodeGen 2.45.4 and `project.yml` are the project source of truth; generated `PrivatePresenter.xcodeproj` is ignored.
- Xcode 16.0+/Swift 6.0, `// swift-tools-version: 6.0`, Swift 6 language mode, strict concurrency checking, warnings as errors in verification, and `MACOSX_DEPLOYMENT_TARGET = 14.0`.
- App identity is fixed for this local-only v1: display name `Private Presenter`, product/target/scheme `PrivatePresenter`, bundle identifier `com.privatepresenter.teleprompter`.
- `Packages/TeleprompterCore` contains Foundation-only domain models, pure policy/state transitions, scrolling math, anchor mapping, persistence codecs, geometry, shortcut validation, and protocols/fakes.
- `PrivatePresenterApp` contains the `@MainActor @Observable AppModel`, SwiftUI controller/menu UI, AppKit/TextKit adapters, Core Graphics display inventory, Carbon hotkeys, local file storage, and notifications.
- AppKit owns the overlay lifetime through one custom `NSPanel`; it hosts SwiftUI chrome and an AppKit/TextKit reader. SwiftUI does not create the overlay as a scene/window.
- `NSView.displayLink(target:selector:)`/`CADisplayLink` drives elapsed-time scroll ticks on macOS 14. No new `CVDisplayLink` code.
- Carbon `RegisterEventHotKey` is wrapped locally for modifier-based global commands. Do not use `NSEvent` global key monitors or `CGEvent` taps as a silent fallback because they can require Accessibility/Input Monitoring.
- App Sandbox is enabled with no network, automation, capture, microphone, camera, contacts, cloud, or account entitlements.

### Drivers

- Explicit AppKit control is necessary for non-activation, window level, Spaces collection behavior, click-through, and selected-screen placement.
- Pure policy makes WSL/static review and deterministic Swift tests possible without pretending to validate AppKit.
- TextKit avoids rebuilding a large SwiftUI `Text` tree every frame and supplies character/layout mapping for reading anchors.

### Alternatives considered

- SwiftUI-only `Window`: rejected because it does not expose the required panel/focus/Space contract precisely enough.
- `.screenSaver` or maximum raw window level: rejected as invasive; select the lowest verified level from a bounded `.floating` → `.statusBar` experiment.
- Third-party hotkey, state-management, snapshot, persistence, or networking packages: rejected as unnecessary runtime surface.
- Accessibility event tap by default: rejected because permission and input interception conflict with the product's focus/safety goals.
- SwiftUI `TextEditor`/`ScrollView` for the long-script hot path: rejected pending evidence; TextKit provides better edit-range and layout control.

### Consequences

- Core logic can be unit-tested with fake clocks/topologies/filesystems.
- AppKit adapters still require macOS `xcodebuild`; Keynote/projector behavior still requires humans and hardware.
- Carbon is a legacy interface with weak current documentation, so compile/runtime/no-permission checks are mandatory.
- The rounded card's corner pixels require a nonopaque window; the complete reading surface inside the rounded mask must still draw at 100% opacity.

### Follow-ups

- Record the lowest passing window level and exact Mac/macOS/Keynote/display configuration in Milestone 0 evidence.
- Keep macOS 14 unless a reproduced failure is tied to an API unavailable there and an ADR amendment documents the new minimum.
- If Carbon fails the gate, stop and evaluate a visible, permission-explained alternative; do not silently change the privacy/permission contract.

## 5. Proposed repository layout

```text
.
├── project.yml
├── .xcodegen-version                       # exactly 2.45.4
├── Makefile                                # generate/build/test/static entry points
├── Config/
│   ├── Shared.xcconfig
│   ├── Debug.xcconfig
│   └── Release.xcconfig
├── Scripts/
│   ├── bootstrap-macos.sh                  # reject wrong XcodeGen; generate project
│   ├── verify-wsl.sh                       # source/policy checks only
│   ├── verify-macos.sh                     # generate, analyze, test, build
│   ├── verify-no-network.sh                # source + entitlement audit
│   └── validate_project_structure.py       # Python stdlib manifest/path/plist checks
├── Packages/TeleprompterCore/
│   ├── Package.swift
│   ├── Sources/TeleprompterCore/
│   │   ├── Models/
│   │   │   ├── ScriptDocument.swift
│   │   │   ├── ReadingAnchor.swift
│   │   │   ├── TeleprompterPreferences.swift
│   │   │   ├── OverlaySession.swift
│   │   │   ├── DisplayDescriptor.swift
│   │   │   ├── DisplayFingerprint.swift
│   │   │   ├── DisplayPrivacyAssessment.swift
│   │   │   └── KeyboardShortcut.swift
│   │   ├── Display/
│   │   │   ├── DisplayTopologyEvaluator.swift
│   │   │   └── PanelFramePolicy.swift
│   │   ├── Scrolling/
│   │   │   ├── ScrollEngine.swift
│   │   │   ├── ScrollCommand.swift
│   │   │   └── ReadingPositionMapper.swift
│   │   ├── Persistence/
│   │   │   ├── PersistedSnapshot.swift
│   │   │   └── SnapshotMigrator.swift
│   │   ├── HotKeys/ShortcutValidator.swift
│   │   ├── Focus/FocusChromeStateMachine.swift
│   │   └── Interfaces/
│   │       ├── ClockProviding.swift
│   │       ├── FrameClock.swift
│   │       ├── DisplayInventoryProviding.swift
│   │       ├── DisplayChangeObserving.swift
│   │       ├── SnapshotPersisting.swift
│   │       └── HotKeyRegistering.swift
│   └── Tests/TeleprompterCoreTests/
│       ├── DisplayTopologyEvaluatorTests.swift
│       ├── PanelFramePolicyTests.swift
│       ├── ScrollEngineTests.swift
│       ├── ReadingPositionMapperTests.swift
│       ├── SnapshotMigratorTests.swift
│       ├── ShortcutValidatorTests.swift
│       └── FocusChromeStateMachineTests.swift
├── PrivatePresenterApp/
│   ├── App/
│   │   ├── PrivatePresenterApp.swift
│   │   ├── AppDelegate.swift
│   │   ├── AppRuntime.swift
│   │   ├── AppModel.swift
│   │   ├── AppCommand.swift
│   │   ├── DependencyContainer.swift
│   │   └── AppLifecycleCoordinator.swift
│   ├── Controller/
│   │   ├── ControllerView.swift
│   │   ├── ScriptEditorTextView.swift
│   │   ├── PlaybackControlsView.swift
│   │   ├── DisplaySelectionView.swift
│   │   ├── PrivacyWarningView.swift
│   │   ├── ControllerPrivacyShieldView.swift
│   │   ├── ControllerWindowController.swift
│   │   ├── ShortcutSettingsView.swift
│   │   └── SettingsView.swift
│   ├── Overlay/
│   │   ├── TeleprompterPanel.swift
│   │   ├── OverlayPanelController.swift
│   │   ├── OverlayRootView.swift
│   │   ├── OverlayHeaderView.swift
│   │   ├── OverlayToolbarView.swift
│   │   ├── ReaderTextView.swift
│   │   ├── ReaderViewportAdapter.swift
│   │   ├── DisplayLinkFrameClock.swift
│   │   ├── ScrollSessionController.swift
│   │   ├── PointerPresenceMonitor.swift
│   │   └── ClampedPanelInteractionController.swift
│   ├── Services/
│   │   ├── SystemDisplayService.swift
│   │   ├── SnapshotStore.swift
│   │   ├── CarbonHotKeyService.swift
│   │   ├── UserNotificationService.swift
│   │   └── WorkspaceFocusProbe.swift        # DEBUG/manual evidence only
│   ├── Interfaces/
│   │   ├── ReaderViewport.swift
│   │   ├── FileSystemProviding.swift
│   │   ├── PointerLocationProviding.swift
│   │   ├── PanelPresenting.swift
│   │   ├── FrontmostApplicationProviding.swift
│   │   └── NotificationPresenting.swift
│   ├── Privacy/
│   │   ├── PrivacyCoordinator.swift
│   │   └── PrivacyEffect.swift
│   ├── Text/
│   │   ├── EditorTextSystem.swift
│   │   ├── ReaderTextSystem.swift
│   │   ├── TextEdit.swift
│   │   └── TextAnchorResolver.swift
│   ├── MenuBar/
│   │   ├── TeleprompterMenu.swift
│   │   └── StatusItemController.swift
│   ├── Resources/Assets.xcassets/
│   ├── Resources/PrivatePresenter.entitlements
│   └── Info.plist
├── PrivatePresenterAppTests/
│   ├── OverlayPanelConfigurationTests.swift
│   ├── OverlayPanelControllerTests.swift
│   ├── ScrollSessionControllerTests.swift
│   ├── SnapshotStoreTests.swift
│   ├── CarbonHotKeyServiceTests.swift
│   ├── FocusModeControllerTests.swift
│   └── AppModelTests.swift
├── PrivatePresenterUITests/
│   ├── ControllerAccessibilityUITests.swift
│   ├── EmptyScriptUITests.swift
│   └── MenuLifecycleUITests.swift
├── Tests/Fixtures/README.md                 # generated fixtures; no real script data
├── docs/validation/
│   ├── source-artifact-checksums.sha256
│   ├── overlay-proof-template.md
│   ├── overlay-proof-result.md
│   ├── hotkey-proof-result.md
│   ├── performance-result.md
│   ├── visual-result.md
│   └── release-acceptance.md
└── HANDOFF.md
```

`docs/validation/source-artifact-checksums.sha256` records the current SHA-256 values and is checked, not used to create derivative runtime assets:

```text
3980ec241d38901ef434b93afa3935ce5b8c3d1a14849ae2417ec6a940138f3d  PRD.md
b3c0e19bbef6285ece0fffa045032a806ccf915b8bb8415184e74f6556af2a2a  design/concept.html
d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e  design/teleprompter-concept.png
352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92  references/teleprompter-ui-reference.png
```

## 6. Module boundaries and state ownership

### 6.1 Dependency direction

```text
SwiftUI controller/menu ─┐
AppKit panel/TextKit ────┼──> @MainActor AppModel ──> TeleprompterCore policies/models
System adapters ─────────┘              │
                                        └──> injected effect protocols
```

`TeleprompterCore` imports Foundation only. It must not import AppKit, SwiftUI, CoreGraphics, Carbon, UserNotifications, or networking frameworks. The app target maps system values into core value types.

### 6.2 Authoritative owner

One `@MainActor @Observable final class AppModel` owns presentation state:

- `document: ScriptDocument`
- `preferences: TeleprompterPreferences`
- `overlaySession: OverlaySession`
- `availableDisplays: [DisplayDescriptor]`
- `privacyAssessment: DisplayPrivacyAssessment`
- `registeredShortcuts: [AppCommand: KeyboardShortcut]`
- transient alert, conflict, and recovery-confirmation state

SwiftUI/AppKit views send typed `AppCommand` values. They never call Carbon, Core Graphics, storage, or panel APIs directly. `AppModel` validates a command through pure policy, changes state, and asks injected adapters to perform effects. `OverlayPanelController` is the only object allowed to create/order/move the panel.

### 6.3 Core data models

| Model | Required fields / invariants |
|---|---|
| `ScriptDocument` | `schemaVersion`, `id`, `title` (default `Lecture Teleprompter`), `text`, monotonically increasing `revision`, `updatedAt`; local-only and Codable |
| `ReadingAnchor` | UTF-16 offset, bounded context before/after, viewport fraction; clamp to document bounds; emoji/surrogate-safe tests |
| `TeleprompterPreferences` | speed 10–240 points/sec (default 60, step 5), font 24–96 (default 42, step 2), Regular/Medium/Semibold weight (Regular default), left/center alignment, active band, Focus Mode, selected fingerprint, normalized frame per fingerprint, lock state, custom shortcut map |
| `OverlaySession` | visibility, playback phase, semantic anchor, pixel offset, selected session display, chrome state, recovery confirmation; playback is never restored as playing |
| `DisplayDescriptor` | Foundation `UInt32` session ID value, best-effort persistent fingerprint, localized name, built-in/main/online flags, bounds/visible frame/scale, mirror membership/source; Core Graphics types never enter the package |
| `DisplayFingerprint` | UUID from `CGDisplayCreateUUIDFromDisplayID` plus vendor/model/meaningful serial, built-in flag, last localized name, and `.strong/.medium/.weak` confidence; raw display ID is session-only and never Codable |
| `DisplayPrivacyAssessment` | `.safeCandidate`, `.blockedMirroring`, `.selectionRequired`, `.confirmationRequired(reason:)`, `.selectedDisplayMissing`, `.ambiguousIdentity`, `.singleDisplayNoAudienceSeparation`, `.systemQueryFailed` |
| `KeyboardShortcut` | virtual key code + normalized Carbon modifiers; disallow bare Space/arrows and duplicates; defaults exactly match the PRD |
| `PersistedSnapshot` | explicit schema version, document, anchor, preferences, frames, shortcuts; deliberately excludes `isPlaying` |

`SystemDisplayService` maps `NSScreen.deviceDescription["NSScreenNumber"]` to an app-layer `RuntimeDisplay` containing the current `CGDirectDisplayID`; its mapper passes only `UInt32(displayID)` into core `DisplayDescriptor`. Persistence receives only `DisplayFingerprint`. Strong means UUID plus agreeing meaningful hardware serial/vendor/model; medium means UUID + vendor/model with no meaningful serial; incomplete/duplicate/name-only evidence is weak. A conflicting UUID/hardware match is ambiguous, weak matches never auto-confirm, and tests inspect encoded JSON to prove no session display ID is serialized.

### 6.4 Reading-position behavior

`ScriptEditorTextView` is an AppKit `NSTextView` wrapped for SwiftUI so edits include range and length delta:

- Edit entirely after anchor: anchor remains unchanged.
- Insert/delete entirely before anchor: shift the UTF-16 offset by the reported delta and refresh context.
- Edit overlapping anchor: clamp to the nearest stable edit boundary, pause, and show a nonblocking “Reading position adjusted” status.
- Font, alignment, or panel geometry change: ask TextKit to restore the semantic anchor at the active-band viewport fraction; never reuse stale pixels.
- Relaunch: restore semantic anchor, always paused.

Avoid a whole-document diff on each keystroke. `ReadingPositionMapper` still supports a pure fallback reconciliation for imported/recovered snapshots and tests prefix/suffix/context matching.

### 6.5 Persistence

`SnapshotStore` is an actor. Its production URL is inside the sandbox container's Application Support directory:

```text
~/Library/Containers/com.privatepresenter.teleprompter/Data/Library/Application Support/Private Presenter/current-snapshot.json
```

Rules:

- debounce edit saves by 300 ms; serialize/write off the edit path;
- write a sibling temporary file, sync/close, then atomically replace;
- flush on controller close, app inactive/termination, and before destructive clear;
- quarantine malformed snapshots locally with a timestamp, surface recovery, and never upload;
- migrations are explicit and idempotent; unknown future schemas fail safely;
- script content is not stored in `UserDefaults`, logs, crash annotations, test snapshots, or notifications;
- restore document/settings/anchor/locked state, then force paused and re-evaluate display safety before showing.

## 7. AppKit ↔ SwiftUI bridge and panel contract

### 7.1 Window construction

`TeleprompterPanel: NSPanel` is created once with:

- style mask `[.borderless, .nonactivatingPanel]`; omit `.resizable` so AppKit cannot start an unconstrained native live-resize session;
- `isFloatingPanel = true`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`;
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` initially;
- initial `level = .floating`;
- `hasShadow = true`, transparent window background, no title/traffic lights/scroller chrome;
- `isOpaque = false` only for clear pixels outside the rounded shape; `OverlayRootView` must fill every pixel inside the rounded reading surface with an opaque gradient.

Do not use `makeKeyAndOrderFront`. Prefer `orderFront(nil)`; test `orderFrontRegardless()` only if showing while Keynote owns activation requires it. Neither code path may call `NSApp.activate` for panel show/hide.

The level is injectable in the DEBUG proof harness. Test `.floating` first. Only if it fails real Keynote, test `.statusBar`. Select the lowest level that passes all focus/Space/privacy cases. `.screenSaver`, arbitrary maximum raw values, and private APIs are prohibited.

Locked contract:

- `ignoresMouseEvents = true`;
- `canBecomeKey == false`, `canBecomeMain == false`;
- cannot drag/resize or invoke overlay buttons;
- panel remains ordered without activating the app;
- controller, menu bar, and global shortcuts remain recovery paths.

Unlocked contract:

- `ignoresMouseEvents = false`;
- do not call `performWindowDrag(with:)` and do not expose native unconstrained move/resize behavior;
- the custom header and eight resize zones route every pointer delta through `ClampedPanelInteractionController`;
- each candidate frame applies minimum/maximum size, clamps size and origin wholly inside the confirmed screen, and only then calls `setFrame`; `constrainFrameRect(_:to:)` is a second defense;
- cursor movement onto an adjacent display never moves even one panel pixel across the selected-screen boundary;
- overlay controls dispatch commands, but text editing remains in the controller;
- opening Settings/Controller may intentionally activate the normal app window.

### 7.2 Hosting boundary

`OverlayPanelController` owns `TeleprompterPanel` and an `NSHostingController<OverlayRootView>`. It subscribes to `AppModel` state and performs only panel effects: show/order, hide, lock, screen frame, and teardown. Panel delegate callbacks send typed frame/visibility events back to `AppModel`; feedback loops are suppressed with transaction IDs.

`OverlayRootView` owns visual chrome only. `ReaderTextView` is `NSViewRepresentable` around a noneditable **TextKit 2** `NSTextView`/`NSScrollView`. `ReaderViewportAdapter` exposes offset/content bounds and semantic anchor mapping to `ScrollSessionController`; SwiftUI state is not published at display refresh rate.

The editor and reader each own a separate main-actor TextKit 2 stack created with `NSTextView(usingTextLayoutManager: true)` (`NSTextContentStorage` → `NSTextLayoutManager` → `NSTextContainer`). `AppModel.document.text` is the persisted authority; layout objects are never shared across windows. A user edit emits ordered `TextEdit(rangeUTF16:replacement:revision:)`: the editor has already applied it locally, `AppModel` validates/applies it and increments revision, and the reader applies the same delta in one `beginEditing`/`endEditing` transaction. Full reader replacement is allowed only for initial load, recovery, or a detected revision gap. Scroll ticks mutate only clip-view offset and perform zero text-storage writes. Capture the semantic anchor before an edit or font/alignment/width change and restore it after affected layout completes.

### 7.3 Selected-screen pinning

- There is exactly one overlay panel and never one window per screen.
- Default frame is 70% selected-screen width × 35% height, top-centered inside `visibleFrame` with a safe top inset.
- Store per-display frames normalized to `visibleFrame`, not global pixels.
- Clamp every intermediate and final frame to the selected display during drag/resize and before any programmatic `setFrame`; never move across a boundary and correct afterward.
- Re-enumerate `NSScreen.screens`; never cache `NSScreen` objects across a display change.
- On topology change: **pause → capture anchor → order out → refresh topology → assess privacy → clamp hidden frame → require confirmation if needed → optionally show; never resume automatically**.
- If the selected display disappears and exactly one built-in display remains, stage the panel there while hidden and require confirmation before showing. With no unique built-in display, remain hidden until explicit selection.

### 7.4 Privacy state machine

| Input | State/action |
|---|---|
| Mirroring detected before open | `.blockedMirroring`; disable Open and show the exact PRD warning |
| Any Core Graphics reconfiguration-begin callback | pause, hide overlay, shield controller, and invalidate pending shows before querying the new topology |
| Mirroring begins while visible | pause, hide, and redact the controller before publishing the warning; no override that shows private content while mirrored |
| Unique built-in + extended topology | select it as a safe candidate and clearly display its name; first-run confirmation remains part of onboarding |
| No built-in or multiple weak fingerprint matches | require explicit display selection and “This is my private display” confirmation |
| Selected display missing/query failure | pause/hide; no fuzzy external fallback |
| Single display | allow general teleprompter use only with a clear “No separate audience display protection” state; do not claim privacy |
| Topology becomes safe again | remain paused/hidden until user confirms/resumes |

Required visible warning, verbatim:

> **Display mirroring is on. Students may see the teleprompter. Use Extended Display mode.**

The controller always shows the selected display and safety state. The UI also states that full-screen capture/conferencing can expose the private screen and is outside v1's physical-display guarantee.

### 7.5 Controller privacy shield and ordered effects

The normal controller is itself script-bearing. It launches shielded, is placed while shielded on a built-in candidate, and reveals script/title/position only after explicit private-display confirmation. `ControllerPrivacyShieldView` replaces all private content with generic guidance; status/menu titles never contain the script title. On reconfiguration begin, mirroring, query failure, ambiguous identity, missing selection, or selected-display loss, `PrivacyCoordinator` produces and executes this exact ordered effect list:

1. `.pauseScrolling`
2. `.hideOverlay`
3. `.shieldController`
4. `.invalidatePendingShow`
5. `.queryTopology`
6. `.evaluatePrivacy`
7. `.moveWindowsWhileShielded` only when a confirmed safe screen exists
8. `.requestConfirmation` or `.publishSafeState`

Never auto-resume/reveal. If the controller's saved frame is on an unconfirmed/external display, ignore it and open a shielded selector on the unique built-in candidate; with no candidate, open only generic shielded guidance on the main screen. Because macOS controls when mirroring pixels change, no app can guarantee zero frames before receiving a system callback; the pre-change callback plus immediate shield is the required best-effort defense and this limitation must be stated in `HANDOFF.md`.

First-run heading and guidance are fixed:

> **Choose your private presenter display**
>
> Select the display only you can see. Private Presenter will keep the script editor hidden and the teleprompter closed until you confirm. Do not select the projector or audience display.

Actions: `Confirm “{displayName}” as Private` and `Keep Script Hidden`.

Unsafe-state copy extends the required PRD warning with `Your script is hidden until display privacy is confirmed again.` Query failure says `Display safety could not be verified. Your script is hidden and the teleprompter is closed.` Ambiguity says `Private Presenter cannot reliably distinguish these displays. Select and confirm the display only you can see.`

## 8. Editor, reader, scrolling, hotkeys, focus, menu, and accessibility

### 8.1 Editor/controller

The SwiftUI controller contains the multiline TextKit 2 editor plus: editable title, Open/Close, Start/Pause, Restart, speed, font size, weight, left/center alignment, active band, Focus Mode, Lock/Unlock, display selector/safety state, Hide/Show, shortcut settings, and confirmed Clear. Empty text disables Start and presents the paste/type instruction. Closing the controller does not terminate the app while the status item or overlay is active.

Fixed v1 defaults remove implementation-time product questions: title `Lecture Teleprompter` (editable, trimmed, nonempty, maximum 120 Unicode scalar values); font 42 points with 24–96 range and 2-point step; Regular weight with Regular/Medium/Semibold choices; left alignment; speed 60 points/second with 10–240 range and 5-point step; active band on; Focus Mode on; paused; first-run unlocked for placement but hidden/shielded until confirmation. Manual forward/back is 15% of viewport height clamped to 80–240 points; if TextKit can provide three full line fragments, prefer exactly three lines.

### 8.2 Smooth scrolling

`DisplayLinkFrameClock` is created from the actual reader `NSView` only after attachment to a window/screen, using `displayLink(target:selector:)`, and is scheduled in common run-loop modes. It starts only when privacy is safe and playback is playing; invalidate it on pause, hide, privacy loss, reader replacement, or teardown, then recreate it after a screen move. A generation token rejects stale callbacks and the clock must not retain torn-down views/controllers. `ScrollEngine` is pure:

- displacement is `speedPointsPerSecond × (currentTimestamp - previousTimestamp)`, never pixels per callback;
- 60/120 Hz and dropped-frame schedules yield the same elapsed-time position within tolerance;
- a long suspension is treated as a pause boundary to avoid a resume jump;
- speed changes affect only later ticks;
- pause retains exact offset; restart sets offset 0 and pauses;
- reaching maximum offset clamps once and pauses;
- forward/back commands move exactly three laid-out lines (fallback: 15% viewport), clamp, and work while playing or paused;
- anchor persistence is throttled and never causes per-frame JSON writes.

The active reading band is a fixed, subtle 2–3-line layer behind text around the configured viewport fraction; it is not text selection. The toolbar gets reserved bottom content inset.

### 8.3 Global shortcuts

Defaults exactly match `PRD.md`: Control-Option-Space, Up, Down, Left, Right, H, and L. `CarbonHotKeyService` wraps `RegisterEventHotKey`, `UnregisterEventHotKey`, and one application event handler behind `HotKeyRegistering`.

- Do not register bare Space/arrows and do not consume Keynote's normal commands.
- Registration failure/collision is an inline error; the controller/menu continue to work.
- Custom recording occurs only while the controller is active, validates modifiers/duplicates, unregisters old chords transactionally, and persists only after all new registrations succeed.
- Never silently fall back to `NSEvent.addGlobalMonitorForEvents`, `CGEvent.tapCreate`, polling keys, or Accessibility permission.
- A fresh-user manual gate must prove all seven shortcuts with Keynote frontmost and confirm no Accessibility/Input Monitoring prompt.

### 8.4 Lock and Focus Mode

`FocusChromeStateMachine` owns `.unlocked`, `.lockedChromeVisible`, `.lockedFocusChromeVisible`, and `.lockedFocusChromeHidden`. Locked states always ignore mouse and return false from `canBecomeKey`; `canBecomeMain` is always false. Unlocked may become key only while `NSApp.isActive`, and unlocking never activates the app or makes the panel key. Focus Mode hides chrome after two seconds without pointer presence and reveals informational chrome on pointer presence or unlock. Because a click-through window cannot receive hover, `PointerPresenceMonitor` samples `NSEvent.mouseLocation` at low frequency and compares it with the panel frame; it does not monitor clicks/keys or install an event tap. Reduce Motion removes decorative fades but does not disable continuous reading motion.

### 8.5 Menu bar/lifecycle

`PrivatePresenterApp.swift` is an explicit `@main` AppKit bootstrap: it creates `NSApplication.shared`, one `AppRuntime`, and one retained `AppDelegate(runtime:)`, sets `.regular` activation policy, assigns the delegate, and calls `run()`. It does not create a SwiftUI `WindowGroup`. `AppRuntime` creates one dependency container and one `@MainActor AppModel`, then strongly owns exactly one `ControllerWindowController`, `OverlayPanelController`, `StatusItemController`, and `AppLifecycleCoordinator`. Both window controllers host SwiftUI through `NSHostingController` with the same model. The status item dispatches `AppCommand` only. The lifecycle coordinator loads the snapshot paused/shielded, begins display observation, assesses privacy, then registers hotkeys. Closing the controller orders it out; `applicationShouldTerminateAfterLastWindowClosed` is false; Show Controller reuses and safely repositions the same instance. Quit pauses, shields/hides, atomically flushes, unregisters hotkeys/callbacks, invalidates the display link, removes the status item, and terminates in that order.

### 8.6 Accessibility

- Full controller keyboard traversal and visible focus.
- VoiceOver label, value/state, help, tooltip, and at least 44×44-point hit target for icon controls.
- Font size 24–96, default 42; high contrast and left alignment default.
- Locked/paused/warning states use text/icon plus color, never color alone.
- Reduce Motion controls decorative transitions; scrolling remains readable.
- The reading band must preserve WCAG-style high text contrast and not expose itself as selected text.

## 9. TDD execution plan and hard gates

Run tasks in order. For each task: add the named failing test(s), observe the targeted command fail for the expected reason, implement the minimum behavior, rerun the targeted test, then run the milestone regression command. Do not delete/weaken tests to pass.

### Milestone 0 — Technical overlay and private-display proof (first milestone)

**Amended hard stop:** the historical physical result remains BLOCKED. Only the guarded, substantially orthogonal M1 slice may proceed under the 2026-07-12 companion plan. No M2/UI expansion, beta use, visual-product work, or readiness claim may proceed until a dedicated M0 stabilization slice fixes and reruns the complete physical matrix. If both bounded panel levels fail the complete rerun, stop as a feasibility blocker.

| Task | RED tests (exact names) | Implementation paths | Target command |
|---|---|---|---|
| M0.1 Reproducible shell | Run `python3 Scripts/validate_project_structure.py` RED before required paths/manifest entries exist, then GREEN after scaffold; it checks targets, deployment, package, scheme, bundle ID, ignored project, and entitlements | `project.yml`, `.xcodegen-version`, `Config/*`, `Makefile`, `Scripts/bootstrap-macos.sh`, validator, package/app/test shells, entitlements | `python3 Scripts/validate_project_structure.py && ./Scripts/bootstrap-macos.sh && xcodebuild -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build` |
| M0.2 Fail-closed topology | `testMirroredSelectionBlocksOpening`, `testMirrorSourceStillBlocksOpening`, `testNoBuiltInRequiresSelection`, `testAmbiguousFingerprintRequiresConfirmation`, `testRemovedSelectionReturnsHiddenPausedRecovery`, `testEvaluatorNeverAutoSelectsExternalDisplay` | core display models + `DisplayTopologyEvaluator.swift` | `swift test --package-path Packages/TeleprompterCore --filter DisplayTopologyEvaluatorTests` |
| M0.3 Frame pinning | `testDefaultFrameIsTopCenteredSeventyByThirtyFivePercent`, `testNormalizedFrameRestoresOnSameFingerprint`, `testEveryIntermediateDragFrameStaysContained`, `testResizeCannotCrossAdjacentScreen`, `testNegativeAndVerticalLayoutsStayContained`, `testResolutionChangeReclamps` | `PanelFramePolicy.swift`, `ClampedPanelInteractionController.swift` | `swift test --package-path Packages/TeleprompterCore --filter PanelFramePolicyTests && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests` |
| M0.4 Panel contract | `testPanelIsBorderlessNonactivatingAndNotNativelyResizable`, `testCustomResizeHandlesApplyOnlyContainedFrames`, `testPanelJoinsAllSpacesAsFullScreenAuxiliary`, `testPanelUsesBoundedLevel`, `testLockedPanelIgnoresMouseAndCannotBecomeKeyOrMain`, `testUnlockedPanelRestoresInteraction`, `testShowDoesNotActivateApplication`, `testReadingSurfaceInteriorIsOpaque` | `TeleprompterPanel.swift`, minimal `OverlayPanelController.swift`, proof `OverlayRootView.swift` | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests` |
| M0.5 Screen/controller privacy | `testControllerCreatesExactlyOnePanel`, `testNoIntermediateSetFrameIsUnsafe`, `testTopologyEffectsPauseHideShieldBeforeQuery`, `testControllerStartsShielded`, `testControllerNeverReopensUnredactedOnExternalScreen`, `testMissingDisplayStagesBuiltInHidden`, `testRecoveryRequiresConfirmationAndNeverAutoResumes` | `SystemDisplayService.swift`, `PrivacyCoordinator.swift`, both window controllers, core-to-system mapping | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests -only-testing:PrivatePresenterAppTests/AppModelTests` |
| M0.6 Diagnostic harness | Unit assertions for immutable configuration snapshot; compile DEBUG focus/display diagnostics | `WorkspaceFocusProbe.swift`, `docs/validation/overlay-proof-template.md`, minimal controller buttons for select/show/lock/hide | `xcodebuild -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` |

#### Mandatory Milestone 0 physical gate

On a Mac running macOS 14 or later, with a current Keynote and a real second display/projector in **extended** mode:

1. Record Mac model, macOS build, Keynote version, display/projector models, topology, separate-Spaces setting, and selected screen.
2. Put Keynote audience slideshow on the external display and Presenter Display full-screen on the Mac.
3. Show the already-created panel after Keynote is full-screen; verify it joins the Presenter Display Space without forcing Keynote out of full screen.
4. Photograph/capture both displays and verify no teleprompter pixel exists on the audience display.
5. Lock it; record frontmost application PID/bundle ID and key window before/after show/lock. Keynote must stay frontmost and the panel must not become key/main.
6. Click through the panel; operate Keynote with mouse, ordinary Space/arrows, and a presentation remote.
7. Hide/show with the diagnostic chord while Keynote stays active.
8. Move Keynote into/out of full screen and switch Spaces; panel remains recoverable on the selected screen.
9. Disconnect the external display: overlay pauses/hides before recovery. Reconnect: it remains hidden/paused until confirmation.
10. Enable mirroring: overlay immediately pauses/hides/blocks and displays the exact warning in the controller.
11. Run `.floating` first; test `.statusBar` only if necessary. Record and keep the lowest configuration that passes every case.
12. Place the panel over bright Presenter Display content and verify the rounded reading surface is fully opaque.
13. Drag and resize toward every edge/corner, including an adjacent display; no intermediate panel pixel may cross the selected-screen boundary.
14. Cold-launch with the saved controller frame on the projector, enable mirroring while a script is visible, and disconnect the private display. Verify the controller becomes generic/shielded before warning or reposition, stays shielded after recovery, and never exposes script/title in its status-menu text.
15. Save evidence in `docs/validation/overlay-proof-result.md` with date/tester, focus/window observations, and paths to local screenshots/photos/video.

If `.floating` and `.statusBar` both fail, do not try `.screenSaver`, private APIs, or a focus-stealing window. Mark the milestone blocked with evidence and reassess feasibility.

### Milestone 1 — Core state and local durability

Execute this milestone only through the approved companion plan: `docs/plans/2026-07-12-milestone-1-core-state-durability.md`. M1 completion does not imply M0 or product readiness; stop after M1 for the dedicated M0 stabilization slice.

Execution record (`2026-07-12`): M1.1–M1.4 production/test sources, exact-origin
verification, M1 validator inventory, Foundation-only core enforcement, and
data-safety audits are present in the working tree. WSL-safe gates pass. Swift is
absent (`command -v swift` exit `1`) and `./Scripts/bootstrap-macos.sh` exits `1`
with `error: bootstrap-macos.sh requires macOS.`, so the named tests have not
been observed behavior-RED/GREEN and the Mac gate remains pending. No commit or
push was made. M0 remains **BLOCKED**; M2, beta use, and readiness remain blocked.

| Task | RED tests (exact names) | Implementation paths | Target command |
|---|---|---|---|
| M1.1 Models/defaults | `testDefaultTitleAndPreferencesMatchPRD`, `testFontRangeClampsTo24Through96`, `testPersistedSnapshotExcludesPlayingState`, `testCodableRoundTripPreservesUnicodeScript` | core models | `swift test --package-path Packages/TeleprompterCore` |
| M1.2 Migration | `testV1MigratesIdempotently`, `testUnknownFutureSchemaFailsWithoutDataLoss`, `testRestoreAlwaysReturnsPaused`, `testMalformedSnapshotIsReported` | `PersistedSnapshot.swift`, `SnapshotMigrator.swift` | `swift test --package-path Packages/TeleprompterCore --filter SnapshotMigratorTests` |
| M1.3 Atomic storage | `testSaveAtomicallyReplacesSnapshot`, `testDebounceCoalescesRapidEdits`, `testFlushPersistsLatestRevision`, `testMalformedFileIsQuarantined`, `testScriptIsNeverWrittenToUserDefaults` | `SnapshotStore.swift` with injected root/filesystem/clock | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -destination 'platform=macOS' -only-testing:PrivatePresenterAppTests/SnapshotStoreTests` |
| M1.4 Authoritative app state | `testCommandsChangeStateBeforeEffects`, `testEmptyScriptCannotStart`, `testRestartPausesAtBeginning`, `testRelaunchReassessesPrivacyBeforeShow`, `testClearRequiresConfirmedCommand` | `AppModel.swift`, `AppCommand.swift`, dependency container | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -destination 'platform=macOS' -only-testing:PrivatePresenterAppTests/AppModelTests` |

### Milestone 2 — Controller/editor and production display safety

| Task | RED tests (exact names) | Implementation paths | Target command |
|---|---|---|---|
| M2.1 Long-script editor | `testEditorReportsEditedRangeAndDelta`, `testIncrementalEditDoesNotReplaceReaderStorage`, `testRevisionGapPerformsOneResync`, `testEmptyInstructionAndDisabledStart`, `testClearPresentsConfirmation` | controller views + `EditorTextSystem.swift` + `ReaderTextSystem.swift` | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/AppModelTests -only-testing:PrivatePresenterUITests/EmptyScriptUITests` |
| M2.2 Display inventory | `testMapsNSScreenNumberToSessionID`, `testBuildsFingerprintFromUUIDAndHardware`, `testDuplicateZeroSerialDisplaysAreAmbiguous`, `testRawDisplayIDIsNotEncoded`, `testQueryFailureIsUnsafe` | `SystemDisplayService.swift` | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests` |
| M2.3 Safety UI/recovery | `testMirroringWarningUsesRequiredText`, `testShieldPrecedesWarningAndReposition`, `testSelectedDisplayNameIsVisible`, `testAmbiguityRequiresExplicitConfirmation`, `testMenuNeverContainsPrivateTitle`, `testRecoveryNeverResumesAutomatically`, `testPerDisplayFramesRemainSeparate` | display selection/warning/shield/controller + privacy/lifecycle coordinator | `swift test --package-path Packages/TeleprompterCore --filter DisplayTopologyEvaluatorTests && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/AppModelTests` |

### Milestone 3 — Smooth time-based reading and edit-stable position

| Task | RED tests (exact names) | Implementation paths | Target command |
|---|---|---|---|
| M3.1 Pure scroll engine | `testElapsedTimeNotFrameCountControlsOffset`, `testSixtyAndOneTwentyHertzMatch`, `testPausePreservesExactOffset`, `testSpeedChangeDoesNotJump`, `testEndClampsAndPauses`, `testRestartReturnsZeroAndPauses`, `testForwardBackwardClamp`, `testSuspensionDoesNotJump` | `ScrollEngine.swift`, `ScrollCommand.swift` | `swift test --package-path Packages/TeleprompterCore --filter ScrollEngineTests` |
| M3.2 Anchor mapping | `testInsertionBeforeAnchorShiftsOffset`, `testDeletionBeforeAnchorShiftsOffset`, `testEditAfterAnchorDoesNotMove`, `testOverlapClampsAndRequestsPause`, `testEmojiOffsetsAreUTF16Safe`, `testLayoutChangeRestoresViewportFraction` | `ReadingPositionMapper.swift` | `swift test --package-path Packages/TeleprompterCore --filter ReadingPositionMapperTests` |
| M3.3 Reader viewport | `testReaderHidesScrollerAndClips`, `testMaximumOffsetAccountsForToolbarInset`, `testBandDoesNotBecomeTextSelection`, `testRestorePlacesAnchorAtBand`, `testScrollTickPerformsNoTextMutation` | reader TextKit 2 bridge + adapter | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests` |
| M3.4 Display-link controller | `testFakeTicksDriveViewport`, `testPauseStopsClock`, `testHiddenPanelStopsClock`, `testStaleGenerationCallbackIsIgnored`, `testTickDoesNotPublishSwiftUIStatePerFrame`, `testEndPublishesOnePausedTransition` | display-link + scroll session controller | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests` |

### Milestone 4 — Global hotkeys, production lock, Focus Mode, and menu

| Task | RED tests (exact names) | Implementation paths | Target command |
|---|---|---|---|
| M4.1 Shortcut policy | `testDefaultsMatchPRD`, `testBareSpaceAndArrowsAreRejected`, `testDuplicateChordIsRejected`, `testCustomChordRoundTrips` | core shortcut model/validator | `swift test --package-path Packages/TeleprompterCore --filter ShortcutValidatorTests` |
| M4.2 Carbon service | `testRegistersEveryActionOnce`, `testReconfigurationUnregistersOldChordTransactionally`, `testPartialRegistrationRollsBack`, `testCollisionSurfacesWithoutFallback`, `testShutdownUnregistersAll`, `testHandlerDispatchesExpectedCommand` | `CarbonHotKeyService.swift` | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/CarbonHotKeyServiceTests` |
| M4.3 Focus chrome | `testEveryFocusTransition`, `testLockedFocusHidesAfterTwoSeconds`, `testPointerPresenceRevealsWithoutDisablingClickThrough`, `testDynamicCanBecomeKeyRequiresUnlockedAndActive`, `testUnlockNeverActivates`, `testReduceMotionRemovesDecorativeFade` | core focus state machine + pointer monitor + overlay views | `swift test --package-path Packages/TeleprompterCore --filter FocusChromeStateMachineTests && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/FocusModeControllerTests` |
| M4.4 Menu/lifecycle | `testSingleModelIsSharedByBothWindowsAndStatusItem`, `testMenuContainsFiveRequiredActions`, `testClosingControllerDoesNotQuit`, `testShowControllerReusesInstance`, `testQuitFlushesPausedStateBeforeUnregisterAndTerminate` | app runtime, menu + lifecycle coordinator | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterUITests/MenuLifecycleUITests -only-testing:PrivatePresenterAppTests/AppModelTests` |

Mandatory hotkey hardware gate with Keynote frontmost:

- exercise all seven default actions;
- confirm ordinary Space/arrows and remote still operate Keynote;
- confirm Keynote remains frontmost/key and overlay does not activate;
- on a fresh user account, record that Private Presenter is disabled/absent in Accessibility and Input Monitoring before launch, no TCC prompt appears, and each `RegisterEventHotKey` return status succeeds; do not reset TCC automatically;
- create a chord collision and confirm the visible conflict/recovery path;
- record macOS/Keynote versions and results in `docs/validation/hotkey-proof-result.md` before enabling shortcut customization by default.

`Scripts/verify-no-network.sh` also fails on `CGEventTap`, `AXIsProcessTrusted`, `addGlobalMonitorForEvents`, Accessibility entitlements, or an Input-Monitoring fallback in product sources; comments documenting the prohibition are explicitly allowlisted.

### Milestone 5 — Accessibility, 50,000-word performance, and lifecycle hardening

| Task | RED tests / measures | Implementation paths | Target command / evidence |
|---|---|---|---|
| M5.1 Accessibility | UI tests `testAllIconButtonsHaveLabelsAndHelp`, `testWarningExposesTextNotColorOnly`, `testControllerKeyboardTraversal`, `testFontRangeControlsAreReachable` | controller/overlay/menu labels, focus, state text | `xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterUITests/ControllerAccessibilityUITests`; manual VoiceOver audit |
| M5.2 Display/crash lifecycle | `testCrashRestoreIsPaused`, `testDisconnectDuringTickPersistsAnchorThenHides`, `testReconnectRequiresConfirmation`, `testQuitTearsDownCallbacks` | lifecycle/display/scroll/store coordination | `swift test --package-path Packages/TeleprompterCore && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO`; then physically disconnect/reconnect and record the ordered behavior in `docs/validation/overlay-proof-result.md` |
| M5.3 50k performance | generated fixture; `testFiftyThousandWordLoad`, `testRepeatedEditDoesNotRebuildWholeReader`, `testDebouncedSaveDoesNotBlockMainActor`; signposts for load/layout/edit/tick/save | TextKit bridges, store, local `OSSignposter` with privacy-safe metadata | `xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO && xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO -only-testing:PrivatePresenterAppTests/AppModelTests`; then launch the Release app under Instruments Time Profiler and Allocations, paste the deterministic generated 50,000-word fixture, type for 30 seconds, scroll for 5 minutes, export both traces, and record thresholds/trace paths in `docs/validation/performance-result.md` |

Performance acceptance on the recorded baseline Mac (minimum target: base Apple-silicon Mac supported by the team):

- controller becomes interactive with generated 50,000-word plain text within 2 seconds;
- ordinary typing has no main-thread stall over 100 ms and p95 edit-to-visible latency below 50 ms over a 30-second sample;
- 5 minutes of scrolling has no stall over 100 ms and no unbounded memory growth; the reader does not rebuild attributed text per frame;
- background/debounced persistence does not block an edit frame;
- record hardware, build configuration, sample length, memory start/end, and Instruments trace location. If thresholds fail, treat as a defect; optionally hand the isolated optimization to `$performance-goal`.

### Milestone 6 — Reference-faithful visual polish (last feature milestone)

Only begin after M0–M5 functional gates pass.

- Add opaque `#34466F` → `#202B4B` navy gradient, approximately 1-point white border at 20–24% opacity, 28–30-point radius, restrained shadow, and no glow.
- Default `#F7F8FC` system text at 42 points, 1.35–1.5 line spacing, 44–52-point padding, constrained readable line width.
- Implement the quiet document/title header, right-side start/lock/settings icons, subtle desaturated 2–3-line active band, and centered bottom pill with A−/A+, alignment, slower, play/pause, faster, and Focus controls. Reserve bottom inset.
- Preserve reference proportions while allowing resize; no title bar, traffic lights, ordinary scrollbar, content bleed, or automatic underlining.
- Add a deterministic app-render baseline test using native Core Graphics image comparison (no snapshot dependency) for gross regressions in bounds/opacity/tokens; do not demand pixel identity to the unrelated wording/reference dimensions.
- Capture representative unlocked, locked, Focus-hidden, bright-background, and active-band screenshots. Run visual-verdict/designer comparison against both supplied PNGs with a target score of at least 90 and no privacy/opacity regression. Store the result in `docs/validation/visual-result.md`.

Preservation command:

```bash
sha256sum -c docs/validation/source-artifact-checksums.sha256
git diff --exit-code 2bba07d -- PRD.md references/teleprompter-ui-reference.png design/concept.html design/teleprompter-concept.png
```

### Milestone 7 — Full acceptance and final `HANDOFF.md`

1. Run every WSL/static command that applies, all core/app/UI tests, static analysis, and a no-sign Release build.
2. Execute all 15 manual v1 acceptance criteria from `PRD.md` on the same real Keynote/projector setup, plus fresh-user hotkeys, VoiceOver/keyboard, performance, no-network, and visual records.
3. Create/update `HANDOFF.md` with:
   - baseline and implementation commit range;
   - last completed task/milestone and all Lore commit hashes;
   - macOS/Xcode/Swift/XcodeGen/Keynote/hardware versions;
   - exact commands, exit codes, and test counts;
   - links/paths to overlay, hotkey, performance, visual, and release evidence;
   - chosen window level/flags and known compatibility constraints;
   - persistence schema and migration state;
   - remaining risks and explicit deferrals;
   - source-artifact checksum confirmation;
   - confirmation of no product network surface plus exact expected `origin` fetch/push URLs and branch/push status;
   - exact first command for the next maintainer.
4. Run prompt-to-acceptance audit, code review, verifier review, and final architect approval. Do not mark complete with a missing physical gate.

## 10. Milestone regression commands

### WSL/source-static checks (possible in the current environment)

The current WSL environment has Python 3 and Git but no Swift, Xcode, XcodeGen, or `xcodebuild`. It can prove source shape/policy only:

```bash
bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py   # stdlib-only checker created in M0
git diff --check
test "$(cat .xcodegen-version)" = "2.45.4"
git check-ignore -q PrivatePresenter.xcodeproj/project.pbxproj
! git ls-files --error-unmatch PrivatePresenter.xcodeproj/project.pbxproj >/dev/null 2>&1
test -f project.yml
test -f Packages/TeleprompterCore/Package.swift
test -f PrivatePresenterApp/Resources/PrivatePresenter.entitlements
sha256sum -c docs/validation/source-artifact-checksums.sha256
Scripts/verify-no-network.sh
test "$(git remote)" = origin
test "$(git remote get-url origin)" = https://github.com/thetomtimus/teleprompty.git
test "$(git remote get-url --push origin)" = https://github.com/thetomtimus/teleprompty.git
git status --short
```

`Scripts/validate_project_structure.py` uses only Python stdlib to check every planned path; macOS 14, Swift 6, `com.privatepresenter.teleprompter`, app/unit/UI targets, local package and shared scheme in `project.yml`; plist syntax; sandbox/no-network entitlements; ignored/untracked generated project; and, on macOS, `xcodebuild -list -json` target/scheme output. `verify-no-network.sh` checks product sources/config for `URLSession`, `WKWebView`, `import Network`, `NWConnection`, analytics/telemetry SDK markers, network entitlements, ATS exceptions, event taps, AX trust calls, and global key monitors; allowlist only policy comments/tests with a documented reason. A green WSL run must not claim Swift compilation, window behavior, hotkeys, smoothness, visual fidelity, or privacy.

### macOS automated verification

```bash
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = "Version: 2.45.4" || xcodegen --version
python3 Scripts/validate_project_structure.py
swift test --package-path Packages/TeleprompterCore
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -destination 'platform=macOS'
xcodebuild analyze \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-macos.sh
```

`bootstrap-macos.sh` must reject a non-2.45.4 XcodeGen, require Xcode 16.0+/Swift 6.0+, give an exact install instruction, generate the ignored project, and never use `latest`. `verify-macos.sh` fails if any generated `.xcodeproj` file is tracked.

### macOS-only physical/manual gates

- M0 full-screen Keynote + real second display/projector, selected-screen pinning, bounded level, click-through, focus/remote, mirroring, disconnect/reconnect, opacity.
- M4 all global hotkeys with Keynote active on a fresh account and no Accessibility/Input Monitoring prompt.
- Crash/quit/relaunch paused restoration and corrupted-snapshot recovery.
- VoiceOver and keyboard traversal.
- 50,000-word Release/Instruments run.
- Full 15-item PRD acceptance sequence.
- Final reference comparison and opaque-card check over bright content.
- Product network inactivity/entitlement audit; do not claim the app prevents third-party screen capture.

## 11. Testing seams and mocks

Inject these protocols; do not sleep or depend on physical screens in unit tests:

- `ClockProviding` and `FrameClock` — deterministic time/ticks.
- `ReaderViewport` — offset, maximum offset, line-step, anchor/restore.
- `DisplayInventoryProviding` and `DisplayChangeObserving` — complete/failed/ambiguous topologies and ordered transitions.
- `FileSystemProviding` and `SnapshotPersisting` — temporary roots, failure injection, atomic operations.
- `HotKeyRegistering` — registration IDs/status/conflicts/dispatch.
- `PointerLocationProviding` — Focus Mode presence without global event monitoring.
- `PanelPresenting` — order/hide/frame/lock transaction recording.
- `FrontmostApplicationProviding` — DEBUG diagnostics only; never a privacy guarantee.
- `NotificationPresenting` — message verification without displaying system UI.

Core unit tests contain value types only. App adapter tests may instantiate AppKit windows, temporary files, and wrapped Carbon calls on macOS. No mock or screenshot can approve the full-screen/private-display gate.

## 12. Edge cases and required response

| Condition | Required behavior |
|---|---|
| Empty script | Disable Start; show paste/type instruction |
| Mirroring before open | Block Open; exact prominent warning |
| Mirroring begins while visible | Pause/hide first; warn; require extended mode + confirmation before show |
| Selected display removed | Capture anchor, pause/hide, stage unique built-in hidden if available, require confirmation |
| Display ID changes/reboot | Conservative fingerprint match; ambiguity requires selection; never fuzzy external choice |
| Display query/API failure | Unsafe/hidden state; preserve script; retry without guessing |
| Controller saved frame on projector | Ignore it; show only a shielded selector on a safe candidate and reveal after confirmation |
| Reconfiguration/mirroring race | Pre-change callback orders pause → hide → shield → invalidate pending show before query/warning |
| No built-in display | Require explicit private-display selection and confirmation |
| Single display | General use allowed only with no-separation warning; never claim audience privacy |
| Keynote absent | Work over ordinary apps; do not special-case failure |
| Keynote enters/exits full screen | Panel remains recoverable in correct Space/display; manual gate |
| Script edited before/at anchor | Range-delta remap; overlap pauses and reports adjustment |
| Font/alignment/panel width changes | Restore semantic anchor at active band through layout |
| App crash/relaunch | Restore local data/settings/anchor, always paused, hidden until privacy reassessment |
| Snapshot malformed/disk full | Preserve/quarantine old data, show local error, keep in-memory text, retry; never discard silently |
| Hotkey collision/failure | Explain affected action; controller/menu work; no permission-requiring fallback |
| Locked panel | Non-key/main, click-through, immovable; hotkey/menu/controller recovery |
| Cursor crosses display during move/resize | Clamp every candidate before `setFrame`; no transient audience pixel |
| Display sleep/wake/long tick | Treat gap as pause boundary; no jump |
| Display-link stale callback | Reject by generation token after hide/invalidate/recreate |
| Reader misses edit revision | Perform one full resync, re-resolve anchor, and remain paused before incremental delivery resumes |
| Duplicate identical monitors/UUID conflict | Treat as ambiguous; shield/hide and require explicit selection/confirmation |
| Bright content behind panel | Interior remains fully opaque; transparent pixels only outside rounded mask |
| 50,000 words | TextKit-backed editor/reader, no per-frame rebuild, debounced local save |
| Full-screen capture/conference | Warn that physical-display protection cannot guarantee capture privacy |

## 13. Minimum viable deferrals

Defer Keynote notes/import/current-slide detection/control, PowerPoint, slide synchronization, multiple saved-script library, rich text/Markdown, cloud/accounts/collaboration/telemetry/networking, AI, audio pacing, eye tracking, recording/capture prevention, iOS/iPadOS/Windows/web, shortcut profiles/import/export, App Store/notarization/updater, and automatic audience-window detection.

Do **not** defer the seven default shortcuts, basic shortcut customization, local autosave/restore, display selector and explicit safety state, mirroring block/warning, selected-screen pinning, click-through lock, Focus Mode, per-display frames, topology recovery, menu-bar commands, accessibility basics, 50,000-word responsiveness, real Keynote gate, or reference-faithful polish.

## 14. Logical commit breakdown

Every implementation commit is local, uses the Lore protocol, and follows passing RED→GREEN tests. Do not commit a “passing” hardware proof until it actually passes.

1. **Make the riskiest macOS behavior reproducible** — M0 scaffold, pure privacy/frame policies, panel contract, diagnostics, proof template.
2. **Prove private full-screen presentation before product expansion** — completed M0 evidence plus only the bounded validated panel-level adjustment.
3. **Keep lecture state durable without exposing script content** — M1 models, migration, atomic store/tests.
4. **Give presenters one authoritative controller for script and session state** — AppModel and M2 editor/controller commands.
5. **Prevent topology changes from exposing the private overlay** — production display adapter, warnings, confirmations, recovery.
6. **Keep reading motion smooth and position stable across edits** — M3 TextKit reader/editor mapping, display link, engine/tests.
7. **Control the teleprompter globally without taking Keynote input** — M4 Carbon registrar/customization and hardware record.
8. **Keep presenter controls recoverable and accessible** — Focus Mode, menu/lifecycle, accessibility.
9. **Keep very long lectures responsive** — performance seams, fixes, measured record.
10. **Match the supplied visual language without weakening privacy** — M6 styling, visual/opacity evidence.
11. **Leave repeatable completion evidence** — full acceptance, policy/static audit, final `HANDOFF.md`.

Representative Lore message:

```text
Prove private full-screen presentation before product expansion

Keynote and macOS Space behavior cannot be inferred from AppKit flags alone, so
the first milestone records the lowest window level that passes on real hardware.

Constraint: Keynote full-screen and projector safety require physical macOS verification
Rejected: Screen-saver window level | invasive and outside the bounded proof
Confidence: high
Scope-risk: moderate
Directive: Do not bypass the M0 manual gate or silently select an external display
Tested: <exact automated commands and docs/validation/overlay-proof-result.md>
Not-tested: <honest remaining OS/display combinations>
```

## 15. Acceptance-criteria traceability

| Acceptance requirement | Implementation boundary | Automated evidence | Mandatory manual evidence |
|---|---|---|---|
| PRD 1: extended second display | display inventory/topology | evaluator fixtures | M0 topology record |
| PRD 2: Keynote audience + Presenter split | user-selected private display; no Keynote control | none can prove | real Keynote/projector |
| PRD 3: overlay on Mac display | frame policy/panel owner | frame/controller tests | both-display evidence |
| PRD 4: above full-screen Presenter Display | panel styles/collection/validated lowest level | configuration tests only | hard M0 gate |
| PRD 5: absent from projector | sole panel + fail-closed pinning | topology/frame tests | audience-display photo/screenshot |
| PRD 6: locked retains Keynote focus | nonactivation/key overrides/click-through | panel assertions | frontmost/key/PID check |
| PRD 7: Space/arrows/remote normal | modifier-only Carbon chords | shortcut validation | Keynote + remote gate |
| PRD 8: seven global actions | Carbon service → AppCommand | registrar/dispatch tests | fresh-user hotkey record |
| PRD 9: smooth exact resume | elapsed-time engine/reader adapter | schedule/pause tests | visible scroll/resume |
| PRD 10: disconnect/reconnect | ordered topology recovery | injected transition tests | hardware disconnect |
| PRD 11: restore paused | atomic snapshot/migrator | store/relaunch tests | quit/reopen/crash |
| PRD 12: mirroring warning | mirror queries + blocked state | exact-string/policy test | toggle mirroring |
| PRD 13: reference consistency | visual tokens/header/band/pill | native gross-regression snapshot | designer/visual verdict ≥90 |
| PRD 14: fully opaque | opaque interior surface | layer/pixel assertion | bright Keynote check |
| PRD 15: Focus chrome | clock/pointer state machine | focus tests | lock/hover/unlock |
| Native/no web wrapper | target/module policy | WSL source audit | app bundle inspection |
| Local-only/no network | sandbox/zero clients | entitlement/source audit | network observation |
| Selected display + ambiguity warning | topology state/confirmation | policy/UI tests | external-only scenario |
| Controller script privacy | shield + ordered privacy effects + contained controller placement | redaction/effect-order/menu-title tests | cold launch, mirror, disconnect |
| No transient move/resize exposure | clamped interaction controller | every-intermediate-frame tests | dual-display edge/corner drag |
| Stable display identity | UUID/hardware confidence; no persisted CGID | churn/duplicate/serialization tests | reboot/reconnect |
| Per-display frame memory | normalized fingerprint map | frame tests | resolution/reconnect |
| Edit-stable position | edit ranges + semantic anchor | mapper tests | live edit before position |
| Menu-bar behavior | status item/lifecycle | menu UI tests | close-controller lecture |
| Accessibility | labels/focus/contrast/motion | UI assertions | VoiceOver/keyboard audit |
| 50,000 words | TextKit/throttled persistence | generated fixture/perf tests | Release/Instruments record |
| Display-link teardown | generation-token clock lifecycle | start/stop/invalidate/stale-callback tests | hide/move/sleep/wake |
| No Accessibility requirement | Carbon-only source/entitlement policy | forbidden-API audit | fresh-user TCC-off record |
| Source artifacts preserved | checksum manifest | `sha256sum -c` | visual reviewer uses originals |
| `HANDOFF.md` final task | M7 evidence summary | file/required-section check | maintainer dry-run |

## 16. Deliberate-mode pre-mortem

1. **Overlay disappears or steals focus in the lecture.** Trigger: flags pass unit tests but Keynote full-screen Space differs by OS/display. Prevention: M0 before product work, lowest-level matrix, frontmost/key evidence, no `makeKeyAndOrderFront`. Recovery: stop at M0; do not raise to screen-saver/private APIs; document compatibility or revise product feasibility.
2. **Controller or panel reaches the audience display.** Trigger: cached `NSScreen`, raw display-ID restore, native cross-screen drag, automatic fallback, or controller restored on the projector. Prevention: launch shield, pre-change ordered effects, one panel, clamped candidate frames, mirror queries, UUID/hardware confidence, explicit confirmation. Recovery: pause/hide/shield, preserve local data, require safe confirmation; record the unavoidable OS-notification timing limitation.
3. **Long scripts stutter or lose position.** Trigger: per-frame SwiftUI publication, whole-document rebuild/diff/write, pixel-only position, or stale display-link callback. Prevention: separate incremental TextKit 2 stacks, revisioned edits, generation-token display link, semantic anchors, throttled anchor/debounced actor save. Recovery: pause, one resync, retain snapshot, measure signposts/Instruments, isolate performance work without weakening privacy.

## 17. Expanded test strategy

- **Unit:** pure display/privacy policy, frame geometry, scrolling schedules, anchors including Unicode, schema/migration, shortcut validation.
- **Integration:** actual `NSPanel` properties/order path, TextKit viewport, atomic files, Carbon adapter, AppModel effect ordering, menu/lifecycle teardown.
- **UI/e2e automated:** empty/clear flow, controls/labels/states, menu/controller lifecycle, deterministic visual harness. These still do not approve Keynote privacy.
- **Physical e2e:** M0 Keynote/projector, M4 hotkeys/remote/fresh-account permission, topology changes, relaunch, VoiceOver, performance, all PRD acceptance.
- **Observability:** local unified logging/signposts for state transitions and timing only; privacy annotations; no script/title/content, telemetry, upload, identifier persistence, or remote crash service. Validation records contain versions/results, not lecture text.

## 18. Available agent types and execution staffing

Available installed roles: `executor`, `test-engineer`, `designer`, `debugger`, `researcher`, `architect`, `critic`, `code-reviewer`, `verifier`, `code-simplifier`, plus `explore`, `planner`, and `writer` for bounded read/document work.

The user explicitly selected a subsequent Ralph run. Use Ralph as the persistent single-owner lane, with bounded role dispatch:

- implementation lane: `executor`, xhigh — AppKit panel, state/adapters, integration;
- evidence/regression lane: `test-engineer`, xhigh — RED tests, scripts, acceptance records;
- display/privacy review: `architect`, xhigh — fail-closed transitions and window boundary;
- debugging lane when a gate fails: `debugger`, xhigh — reproduce before changing level/API;
- visual lane after M0–M5 only: `designer`, high, then visual verdict;
- final gates: `code-reviewer`, high; `verifier`, high; explicit `architect`, xhigh sign-off;
- changed-files cleanup before final re-verification: `code-simplifier`, xhigh, without widening scope.

Do not parallelize work across the M0 hard gate. After M0 passes, core tests, controller UI, and evidence tooling may be parallelized if their file ownership is disjoint.

### Team launch hint (optional after M0)

```text
$team Execute IMPLEMENTATION_PLAN.md from the first incomplete milestone. Keep M0
overlay/privacy as the blocking critical path. Staff executor for AppKit/app integration,
test-engineer for core/regression evidence, designer only after M0–M5 pass, and verifier
for integrated acceptance. Never substitute mocks for Keynote/projector evidence.
```

Team verification before shutdown: core tests → app/UI tests → analyze + Release build → no-network/entitlement/reference audit → required real-hardware records → visual/accessibility/performance records → verifier and architect approval. If Team is used with `$ultragoal`, Team returns checkpoint-ready evidence while the leader-owned Ultragoal ledger records milestone completion.

### Goal-mode follow-up suggestions

- `$ultragoal` is the default durable ledger for general implementation and can wrap `$team` after M0.
- `$performance-goal` is appropriate only if M5 becomes a separate measured optimization effort.
- `$autoresearch-goal` is not appropriate; the product plan is implementation, not an open research deliverable.
- `$ralph` is the user's explicit chosen fallback here: a persistent single owner must enforce the physical gates and verification/fix loop.

## 19. Exact Ralph handoff

Run from a **macOS checkout** at the M1 planning commit:

```text
$ralph Implement docs/plans/2026-07-12-milestone-1-core-state-durability.md
exactly as the next guarded M1-only TDD slice. The 2026-07-12 amendment permits
M1.1–M1.4 while docs/validation/overlay-proof-result.md remains BLOCKED; do not rewrite
that result or claim M0 passed. Preserve the M0 DEBUG proof harness, PRD.md, and visual
artifacts byte-for-byte. Do not begin editor, scrolling, product-hotkey, menu, visual,
or M2 work. Finish with environment-separated verification plus independent
code-reviewer, verifier, and architect approval. Then stop for the dedicated M0
stabilization slice before M2/beta/readiness. Push only through the companion plan's
clean-main, exact-origin, zero-behind, non-force safety gate.
```

If Ralph starts in this WSL environment, it may implement and run source-static checks but must stop before claiming any Swift/AppKit/Keynote success. Resume the same local commit/milestone on macOS; no product question is required. A human/hardware evidence dependency is a gate, not permission to simulate or silently skip acceptance.

## 20. Completion definition

The overall implementation is complete only when every matrix row has real evidence, M0 and final physical gates pass, all tests/analyze/Release build/static audits are green, no source-of-truth checksum changes, no known errors/pending tasks remain, `HANDOFF.md` is current, and verifier + architect approve. Completion of the guarded M1 companion slice is only an intermediate state: it must stop before M2 and cannot support beta/readiness language while M0 remains BLOCKED. Failure of the Keynote overlay or display-safety proof blocks the product rather than permitting UI polish or a weaker privacy claim.

## 21. Consensus-review changelog

- Planner draft established M0-first sequencing, native/core boundaries, RALPLAN-DR options/ADR, TDD milestones, environment-separated verification, traceability, staffing, and exact Ralph handoff.
- Architect iteration 1 required contained move/resize, controller shielding, a fixed XcodeGen/toolchain identity, exact TextKit/lifecycle/default decisions, stronger display fingerprints, and corresponding tests/gates; all were incorporated.
- Architect iteration 2 required removal of command shorthand, removal of native `.resizable`, and a Core Graphics-free package session ID; all were incorporated.
- Architect iteration 3 returned **APPROVE**, finding no architecture or execution-readiness blocker and confirming Ralph can execute without product questions.
- Critic then ran sequentially, returned **APPROVE** with no blocker, and closed the consensus gate.
