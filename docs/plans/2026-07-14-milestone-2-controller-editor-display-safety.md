# Private Presenter — Milestone 2 Controller/Editor and Production Display Safety

Status: **COMPLETED — OWNER-APPROVED REAL-MAC SMOKE PASS; M3 AUTHORIZED**
Planning date: 2026-07-14
Repository: `/home/thomas/teleprompty-m2`
GitHub/origin: `https://github.com/thetomtimus/teleprompty.git`
Branch/baseline: clean `main` at `3526b4fa22f94c63c0237d55071f0d464a126e3a`
Proof source authorized by owner: `06d7d5f`
Scope: M2.1–M2.3 only; stop before M3–M6

Closeout date: 2026-07-15. The owner-reported physical result is preserved at
`docs/validation/m2-controller-editor-display-safety-result.md`. The rebuilt app passed
the package-level Keynote/private-display smoke on an M4 Pro with macOS 26.5.2 and Xcode
26.6. The supplied source SHA is the pre-M2 baseline, so exact rebuilt-source provenance
remains a release-evidence follow-up; the owner explicitly accepted the physical result
as M2 completion and authorized M3. Historical M0 evidence remains unchanged.

## 1. Outcome, authorization, and hard stop

Implement the smallest native first-usable **editor/display-safety alpha**:

1. replace the DEBUG proof controller with a real SwiftUI controller and long-script plain-text editor;
2. keep editor and reader on separate TextKit 2 stacks and propagate edits incrementally by UTF-16 range/delta and monotonic revision;
3. turn the current display inventory into a production, fail-closed NSScreen/Core Graphics mapping and persistent-fingerprint boundary;
4. expose selected display/topology/confirmation/recovery state clearly without ever placing private script/title data in menus or status surfaces; and
5. preserve the proven one-model, nonactivation, window-level/order, containment, opacity, H/L, durability, and privacy-order behavior.

**Milestone boundary:** M2 is usable for entering, autosaving, statically displaying, positioning, locking, hiding, and safely recovering a script. It does not scroll. M3 supplies smooth time-based scrolling and edit-stable viewport position. M4 supplies lecture-ready product hotkeys, Focus Mode/chrome fading, and menu-bar control. M5/M6 remain hardening/polish.

Implementation stops when all M2 RED→GREEN tests, existing M0/M1 regressions, Mac automated gates, practical Mac acceptance, independent review, and local Lore commits are complete. It must not implement a scroll clock, viewport motion, global product shortcuts, Focus Mode behavior, menu bar, accessibility hardening, performance hardening, or visual polish.

## 2. Evidence and sequencing truth

- `docs/validation/overlay-proof-result.md` lines 1–307 remain the immutable historical 2026-07-12 **BLOCKED** result. Do not rewrite or relabel it.
- The owner-approved transition appended on 2026-07-14 authorizes M2 from proof commit `06d7d5f`; that record is committed at the requested baseline `3526b4f`.
- The transition accepts the physically selected `.statusBar` + `frontRegardless` configuration, Keynote nonactivation/focus behavior, H/L recovery, containment, opacity, and tested recovery paths. It explicitly defers ordered-out repetitions and human-only remote/photo breadth. Those are not passed; keep them as later hardening/release evidence.
- `HANDOFF.md` predates the owner transition. Its historical evidence remains useful, but its statement that M2 is blocked is superseded only by the appended owner record. Update HANDOFF only after M2 implementation/evidence; never rewrite the historical result.
- M1 schema/store/startup/one-AppModel behavior and M0 Phase B display/focus/privacy behavior are protected regressions.
- Preserve `PRD.md`, `design/concept.html`, `design/teleprompter-concept.png`, and `references/teleprompter-ui-reference.png` byte-for-byte and keep `docs/validation/source-artifact-checksums.sha256` passing.

## 3. Scope contract

### 3.1 In scope — M2.1 long-script controller/editor

- Product SwiftUI controller with editable title and multiline plain-text editor.
- Default title and normalization already specified by the implementation contract: trim, substitute `Lecture Teleprompter` if empty, and cap at 120 Unicode scalars at a `Character` boundary so a grapheme is never split.
- Empty/whitespace instruction and disabled Start.
- Existing token/revision/pre-clear-flush safe Clear flow with a product confirmation dialog.
- Separate TextKit 2 editor and reader systems; range/delta/revision incremental propagation; exactly one latched authoritative full reader resync per detected revision gap or contiguous application/storage-divergence failure.
- Existing SnapshotStore actor/debounce/atomic save path for title, script, preferences, and safe normalized frames.
- Product controls represented honestly:
  - **enabled and wired in M2:** title/editor, Open/Close Teleprompter, Hide/Show Panel, lock/unlock, display selection/confirmation, clear, font size, left/center alignment, active-band toggle, and static reader rendering;
  - **represented but disabled with visible milestone explanation:** Start/Pause/Restart and speed (“Smooth scrolling is available in M3”), Focus Mode (“Focus Mode and product shortcuts are available in M4”). Empty/whitespace retains the stronger paste/type instruction.
- `Open/Close` and `Hide/Show` use the same existing single panel and typed state/effects; they must not create a second window or state owner. Open/Close is the primary session wording; Hide/Show is the explicit visibility control. Both converge on existing safe show/hide eligibility and remain paused.
- DEBUG H/L, proof configuration, evidence copy/path, and focus facts remain available only inside a bounded `#if DEBUG` diagnostics disclosure; none becomes production product control.

### 3.2 In scope — M2.2 production display inventory

- Convert `NSScreen.deviceDescription["NSScreenNumber"]` to the current `CGDirectDisplayID`; reject absent, wrong-typed, duplicate, zero/sentinel, or topology-unjoined IDs.
- Continue a two-source inventory: NSScreen-backed drawable destinations and all-online Core Graphics topology members.
- Normalize persistent UUID plus vendor/model/serial/built-in facts. Treat serial `0` as absent; never promote names, array order, or a raw runtime ID to persistent identity.
- Duplicate or otherwise indistinguishable fingerprints are ambiguous. A user may explicitly select a specific current-session ID and confirm it for that session, but that ID is never encoded.
- Any count race, hardware-fact failure, duplicate drawable/online ID, missing drawable-to-topology join, invalid screen number, or query error produces `querySucceeded=false`/unsafe handling; never use a partial inventory as safe.

### 3.3 In scope — M2.3 safety UI and recovery

- Always show a generic topology state; after safe current-session confirmation show the selected private display's localized name. Never show script/title while shielded.
- Render this exact sentence as its own UI/accessibility string:

  > Display mirroring is on. Students may see the teleprompter. Use Extended Display mode.

  Put any recovery guidance in a separate string so the warning itself remains exact.
- Preserve the order `pause → hide → shield → invalidate pending show → query → evaluate → move while shielded → publish warning/safe confirmation`.
- Ambiguity, missing selection, query failure, mirror state, and display loss never guess or auto-confirm.
- Persist one normalized frame per stable, unambiguous persistent fingerprint; clamp restoration to the current full/visible containment frame. Ambiguous weak identity remains session-only and starts from a safe default rather than restoring/overwriting another display's frame.
- Recovery remains hidden, paused, and shielded until explicit confirmation. It never auto-resumes or auto-reveals.
- Test the existing macOS application menu/window/status/diagnostic surfaces with sentinel private title/text and prove neither appears. Do not add the M4 menu bar.

### 3.4 Explicitly out of scope

- M3 display link, time-based scrolling, manual movement, reader viewport motion, reading-position edit mapping, and end-of-script behavior.
- M4 production Carbon shortcuts, user shortcut editing, Focus Mode fade/hover behavior, menu-bar status item, or product replacement of DEBUG H/L.
- M5 performance/accessibility hardening or claims beyond M2 acceptance, despite designing the bridge for 50,000-word scripts.
- M6 visual polish or redesign of protected references.
- Network, telemetry, accounts/cloud, updater, WebView/Electron/JavaScript, new dependencies, Accessibility permission, event taps, global NSEvent monitors, private APIs, native focus-return/reactivation hacks, `.screenSaver`, raw/unbounded window levels, or a second AppModel/panel.

## 4. RALPLAN-DR decision record

### Principles

1. **One authority, adapters at the edge.** `AppModel` owns document/preferences/session/revisions; TextKit systems report/apply values and never become competing models.
2. **Fail closed before showing detail.** Display uncertainty first commits paused/hidden/shielded state, then performs external window/query work.
3. **Incremental by default, full replacement by named exception.** Reader storage is fully set only for initial bind, restore, confirmed clear, or one latched gap/application-failure resync—not on an ordinary successfully applicable edit.
4. **State only shipped behavior.** Controls that depend on M3/M4 are visible but disabled/explained, never simulated by toggling state with no visible behavior.
5. **Persistent identity is not session routing.** Runtime IDs route only in memory. UUID/hardware facts support persistence; ambiguity requires a new explicit session confirmation.
6. **Reuse before adding.** Keep SnapshotStore, schema v1, privacy directives, one panel, frame policy, H/L proof service, and current window configuration.
7. **Evidence has platform boundaries.** WSL proves source/static properties only; Swift/AppKit/TextKit/Keynote/display claims require the named Mac gates.

### Top decision drivers

1. Privacy impact of choosing/restoring the wrong display or revealing during recovery.
2. Long-script responsiveness and correctness under rapid, Unicode, duplicate, stale, and missing edit events.
3. Preservation of M0/M1 behavior and smallest reversible native change.
4. Honest usable product surface without pulling M3/M4 into M2.

### Options

| Option | Benefits | Costs/risks | Decision |
|---|---|---|---|
| A. Revisioned `ScriptTextEdit` plus separate editor/reader TextKit 2 adapters, one AppModel reducer, normalized hardware identity, capability-gated controller | Range/delta tests; no ordinary full rebuild; gap recovery explicit; independently laid-out editor/reader; no new dependency; safe ambiguity | Requires small command/effect/bridge seams and strict callback suppression | **Chosen** |
| B. SwiftUI `TextEditor` whole-string binding and replace reader text after every change | Small initial diff | Cannot prove range/delta or TextKit 2 continuity; O(document) reader replacement per keystroke; echo/race risk | Rejected |
| C. Share a single `NSTextStorage` between controller and overlay | Automatic content sharing | Couples two layout/lifecycle contexts; makes authority and recovery opaque; threatens M3 viewport work | Rejected |
| D. Persist runtime display ID or use localized name/order to break ties | Easy direct restoration | IDs/names/order are unstable; can restore onto the audience display; violates explicit requirement | Invalid |
| E. Add a new editor/display framework | May provide ready-made widgets | New dependency/security/build surface with no necessity; native APIs already provide required seams | Rejected |

### ADR-003 — Native revisioned editor and fail-closed production display safety

**Decision.** Choose Option A.

**Drivers.** Privacy must fail closed under display uncertainty; ordinary long-script edits must remain incremental and revision-safe; M0/M1 behavior must remain protected; and M2 must expose only real M2 capabilities without pulling scrolling, production shortcuts, Focus Mode, or polish forward.

**Alternatives considered.** Option B's whole-string SwiftUI binding is simpler but cannot meet the incremental bridge contract. Option C's shared text storage removes delivery gaps but couples editor and reader lifecycle/layout ownership. Option D's runtime-ID/name/order persistence is privacy-unsafe. Option E adds an unnecessary dependency and build/security surface.

**Why chosen.** Option A is the smallest native path that preserves one authoritative model, separates editor and reader layout, makes edit loss/recovery testable, and makes persistent display ambiguity explicit rather than guessed.

`ScriptTextEdit` is an immutable `Sendable` app-domain value containing a small integer-only `UTF16TextRange` (location/length), replacement text, `changeInLength`, `baseRevision`, and `revision`. AppKit `NSRange` is converted at the editor boundary instead of becoming the cross-boundary contract. The editor's TextKit 2 delegate computes the original range from the processed edited range/delta, suppresses programmatic synchronization callbacks, and submits on the main actor. `AppModel` validates UTF-16 boundaries, `baseRevision == document.revision`, `revision == base + 1`, and replacement/delta consistency before atomically mutating text/revision/time and emitting snapshot plus reader effects.

The reader owns a distinct TextKit 2 text content/storage/layout/view stack. A valid contiguous edit uses `beginEditing`/`replaceCharacters`/`endEditing`; duplicate/stale updates are ignored. A forward gap or contiguous application/storage-divergence failure enters one `awaitingResync` state and emits one typed `.readerResyncRequested` command. While waiting, further increments do not emit more requests. AppModel replies with the latest authoritative text/revision; the reader performs exactly one full replacement, clears the latch, and resumes incremental edits. Initial bind, restore, and confirmed clear may explicitly full-replace. No ordinary successfully applicable edit ships the full script to the reader effect.

Display service maps each NSScreen number to one online Core Graphics session ID, normalizes UUID/hardware values, and produces a separate drawable/topology inventory. The core relationship policy distinguishes match/no-match/conflict and treats duplicate weak/zero-serial identities as ambiguous. Explicit current-session ID resolves only a user-confirmed current choice; persistence continues to encode only the fingerprint. Stable frame lookup uses the same identity policy. Unsafe/ambiguous identity has no automatic frame restore.

**Consequences.** Schema stays v1; no migration or user-content rewrite. M3 can add viewport/clock behavior atop the reader without replacing its storage contract. M4 alone enables product hotkeys/Focus Mode/menu. The M2 UI has intentionally disabled future controls. TextKit/AppKit correctness remains a Mac claim.

**Official API basis.** Apple documents `NSScreenNumber` as the number identifying the screen's Core Graphics display, TextKit edit processing with edited range and length delta, TextKit edit batching, and TextKit 2 access through `textLayoutManager`. It also documents display serial zero as absence of an encoded serial. Implementation must re-check current official documentation on the Mac toolchain before coding and must never access legacy `layoutManager`, which can switch compatibility mode:

- <https://developer.apple.com/documentation/appkit/nsscreen/devicedescription>
- <https://developer.apple.com/documentation/appkit/nstextstoragedelegate>
- <https://developer.apple.com/documentation/appkit/nstextstorage>
- <https://developer.apple.com/documentation/appkit/nstextview>
- <https://developer.apple.com/documentation/coregraphics/cgdisplayserialnumber(_:)>
- <https://developer.apple.com/documentation/coregraphics/quartz-display-services>

**Follow-ups.** M3 attaches time-based scrolling and viewport preservation to this reader contract. M4 alone enables production shortcuts, Focus Mode, and menu-bar behavior. M5/M6 retain hardening, accessibility/performance certification, and polish; none is an M2 completion condition.

## 5. Architecture and exact file plan

### 5.1 Create

| Path | Responsibility |
|---|---|
| `PrivatePresenterApp/Text/ScriptTextEdit.swift` | Foundation-only immutable `Sendable` integer `UTF16TextRange` + edit value, UTF-16 validation, revision transition. App-domain rather than core persistence schema. |
| `PrivatePresenterApp/Controller/EditorTextSystem.swift` | `@MainActor` TextKit 2 editor stack/delegate, range+delta extraction, callback suppression, programmatic initial/restore/clear sync. |
| `PrivatePresenterApp/Controller/ScriptEditorTextView.swift` | `NSViewRepresentable` wrapper with multiline plain-text configuration, scroll view, accessibility identifiers, and revision-based updates. |
| `PrivatePresenterApp/Controller/ControllerPresentation.swift` | Pure presentation/capability derivation for empty instruction, enabled/disabled controls, selected name, topology label, and future-milestone explanations; no second state owner. |
| `PrivatePresenterApp/Controller/DebugDiagnosticsView.swift` | Bounded `#if DEBUG` disclosure containing existing proof diagnostics/H/L facts without script/title. |
| `PrivatePresenterApp/Overlay/ReaderTextSystem.swift` | `@MainActor` separate TextKit 2 reader stack, incremental mutation counter, gap latch/resync contract, static attributes. |
| `PrivatePresenterApp/Overlay/ReaderTextView.swift` | Static noneditable, nonselectable, no-scroller TextKit 2 reader wrapper; font/alignment/active-band rendering only. |
| `PrivatePresenterAppTests/EditorTextSystemTests.swift` | Edited-range/delta, Unicode, callback suppression, main-actor/TextKit 2 tests. |
| `PrivatePresenterAppTests/ReaderTextSystemTests.swift` | Incremental storage, gap/duplicate/stale/resync, attribute-only update tests. |
| `PrivatePresenterAppTests/ControllerPresentationTests.swift` | Empty/future-control/display/warning/menu-safe presentation tests without inventing a privacy-bypass UI-test mode. |
| `docs/validation/m2-controller-editor-display-safety-result.md` | Created only at verified M2 closeout; content-neutral Mac environment/commands/manual results and remaining deferred breadth, never script/title/media. |

Do **not** create `PrivatePresenterUITests/EmptyScriptUITests.swift` merely to mirror the stale target path in `IMPLEMENTATION_PLAN.md`. The present UI-test target is only a shell, and launching the private editor under automation would otherwise require a test-only bypass of current-session display confirmation. Place the exact required test name in `ControllerPresentationTests` and cover the visible product flow manually on Mac. A later dedicated UI harness needs its own privacy-reviewed plan.

### 5.2 Modify

| Path | Minimum change |
|---|---|
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Models/DisplayFingerprint.swift` | Centralize normalized hardware identity/relationship and persistence eligibility; zero serial absent; name is display metadata/weak hint, not strong tie-break. Keep Codable keys/schema compatible. |
| `Packages/TeleprompterCore/Sources/TeleprompterCore/Display/DisplayTopologyEvaluator.swift` | Reuse fingerprint relationship; duplicate/conflicting matches require current-session explicit selection/confirmation; never auto-select external. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/DisplayTopologyEvaluatorTests.swift` | Duplicate/weak/current-session confirmation and query-failure regressions. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift` | Raw runtime-ID absence, v1 canonical compatibility, per-display normalized-frame separation. |
| `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/PanelFramePolicyTests.swift` | Same-fingerprint restore, changed geometry clamp, cross-display separation, unsafe ambiguous fallback. |
| `PrivatePresenterApp/App/AppCommand.swift` | Add typed title/edit/font/alignment/active-band/frame/resync commands. Keep existing clear, privacy, H/L-compatible commands; add no M3/M4 command. |
| `PrivatePresenterApp/App/AppEffect.swift` | Add incremental reader edit, explicit reader replace/resync, and static reader-attribute effects; immutable payloads only. Do not put AppKit objects in effects. |
| `PrivatePresenterApp/App/AppModel.swift` | Validate/apply edits and title, update preferences, derive snapshot once, request one resync, keep future playback commands unavailable from product UI, save safe frames, expose content-neutral topology presentation. Preserve reducer-before-effect order. |
| `PrivatePresenterApp/App/DependencyContainer.swift` | Construct one editor/reader integration/effect adapter as needed; do not construct state authority. |
| `PrivatePresenterApp/App/AppRuntime.swift` | Wire the one AppModel to editor/reader/panel callbacks and teardown/flush ordering; keep display observation before H/L registration and one model identity. |
| `PrivatePresenterApp/Controller/ControllerView.swift` | Replace proof layout with product title/editor/safety/control sections; shield branch still owns unsafe state; add DEBUG diagnostics disclosure. |
| `PrivatePresenterApp/Controller/ControllerPrivacyShieldView.swift` | Exact mirroring string as one node, separate recovery guidance, generic shield content only. |
| `PrivatePresenterApp/Controller/ControllerWindowController.swift` | Product window sizing/title/accessibility and existing shielded placement; never add private title to NSWindow title or raise during H/L/topology. |
| `PrivatePresenterApp/Overlay/OverlayRootView.swift` | Replace proof text with static reader and M2-safe header/control representation; active band works, M3/M4 actions remain unavailable. Preserve opaque container and interaction zones. |
| `PrivatePresenterApp/Overlay/OverlayPanelController.swift` | Own/wire ReaderTextSystem view, report normalized applied frame adjacent to the sole contained `setFrame`, restore only after safe display resolution; preserve exact-one panel/nonactivation/order behavior. |
| `PrivatePresenterApp/Services/SystemDisplayService.swift` | Injectable NSScreen-number mapping, duplicate/sentinel validation, normalized UUID/hardware builder, all-online fail-closed join. |
| `PrivatePresenterAppTests/AppModelTests.swift` | Edit authority, title/preferences/autosave, clear, safety ordering, frame persistence, future controls, one-model tests. |
| `PrivatePresenterAppTests/SystemDisplayServiceTests.swift` | M2 mapping/fingerprint/duplicate/query tests while retaining M0 all-online mirror tests. |
| `PrivatePresenterAppTests/OverlayPanelControllerTests.swift` | Reader wiring, frame save/restore/clamp, H/L/nonactivation/containment regressions. |
| `PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift` | Static reader remains opaque/non-key/non-main at `.statusBar` + `frontRegardless`; no legacy TextKit compatibility path. |
| `PrivatePresenterAppTests/SnapshotStoreTests.swift` | Rapid title/edit autosave coalescing and content-neutral diagnostics using existing source unchanged. |
| `Scripts/validate_project_structure.py` | Require new paths/named tests and M2 prohibited-surface/static markers; retain every M0/M1 check and historical-prefix validation. |
| `HANDOFF.md` | Only after M2 Mac verification: record exact commit/commands/environment/manual results, M3/M4 boundary, and deferred breadth. Do not alter historical proof. |

### 5.3 Explicit no-change decisions

| Path/surface | Decision and reason |
|---|---|
| `project.yml` | **No change.** App/app-test/UI-test paths are recursive; no target/build setting is needed. Regenerate project on Mac with existing bootstrap. |
| `Packages/TeleprompterCore/Package.swift` | **No change.** Existing Foundation-only target and recursive sources/tests suffice; app TextKit code stays outside core. |
| `PrivatePresenterApp/Resources/PrivatePresenter.entitlements` | **No change.** No permission/capability is required. |
| `PrivatePresenterApp/Resources/Assets.xcassets/**` | **No change.** M2 uses system-native controls; M6 owns polish/assets. |
| `PrivatePresenterApp/Info.plist` | **No change.** No URL scheme, service, background mode, permission string, or status item. |
| `.xcodegen-version`, `Configs/**`, `Makefile` | **No change.** Existing build contract and commands suffice. |
| `Packages/.../PersistedSnapshot.swift`, `SnapshotMigrator.swift`, `ScriptDocument.swift`, `TeleprompterPreferences.swift` | **No schema change.** Existing v1 contains all M2 durable fields. Preserve canonical fixtures/bytes. |
| `PrivatePresenterApp/Services/SnapshotStore.swift` | **No production change expected.** Reuse its actor-isolated 300 ms debounce, generations, atomic save/flush/quarantine; extend tests only. |
| `PrivatePresenterApp/Privacy/PrivacyCoordinator.swift`, `PrivacyDirective.swift` | **No change expected.** Existing ordered fail-closed directive planner already expresses M2 recovery. If a RED test proves a missing directive, stop for Architect review rather than adding a second safety system. |
| `PrivatePresenterApp/Overlay/TeleprompterPanel.swift`, `ClampedPanelInteractionController.swift` | **No change expected.** Preserve one nonactivating panel, bounded `.statusBar`, `frontRegardless`, lock/click-through, and contained interactions. |
| `PrivatePresenterApp/Services/DiagnosticHotKeyService.swift`, `DiagnosticEvidenceRecorder.swift`, `DiagnosticObserverSet.swift`, `WorkspaceFocusProbe.swift` | **No behavior change.** Retain H/L and content-neutral proof; only move presentation into DEBUG disclosure. |
| `PrivatePresenterApp/App/PrivatePresenterApp.swift` | **No change expected.** Existing bootstrap/termination remains. |
| `PrivatePresenterUITests/PrivatePresenterUITestShell.swift` | **No change.** It remains a skipped future shell and is not evidence for M2. |
| `Scripts/bootstrap-macos.sh`, `verify-macos.sh`, `verify-wsl.sh`, `verify-no-network.sh`, proof provenance scripts | **No change expected.** Use them as gates. `verify-macos.sh` remains honest about still-deferred physical breadth; M2 acceptance is recorded separately. |
| `PRD.md`, `IMPLEMENTATION_PLAN.md`, `docs/validation/overlay-proof-result.md`, `docs/validation/m0-phase-*.md`, M0/M1 plans, design/reference assets/checksum manifest | **Byte-for-byte no change.** They are source/history, not implementation scratch space. |

## 6. Detailed state and effect contract

### 6.1 Commands

Add these bounded cases (exact spelling may follow local Swift style, semantics are binding):

- `.setScriptTitle(String)`
- `.applyScriptEdit(ScriptTextEdit)`
- `.readerResyncRequested(appliedRevision: UInt64)`
- `.setFontSize(Double)`
- `.setTextAlignment(TeleprompterTextAlignment)`
- `.setActiveBandEnabled(Bool)`
- `.panelFrameChanged(displayID: UInt32, frame: CGRect)` as an app-boundary event; AppModel resolves ID to the confirmed fingerprint and core normalized frame before persistence

Reuse `.showOverlay`, `.hideOverlay`, `.setLocked`, `.selectDisplay`, `.confirmSelectedDisplay`, and safe clear cases. Product UI must not dispatch `.start`, `.togglePlayback`, `.restart`, or a new speed/Focus/chrome mutation in M2. Existing playback commands/preferences remain for M1 regression and later milestones, but M2 presentation reports them unavailable. `Hide/Show Panel` means overlay visibility, not the M4 automatic chrome fade.

### 6.2 Mutation/effect order

For an accepted edit/title/preference/frame event:

1. validate input/revision/current confirmed display as applicable;
2. mutate the authoritative AppModel value and revision;
3. invalidate a pending clear when durable document state changed;
4. construct one immutable v1 snapshot;
5. emit the reader change/attribute effect if applicable; then
6. schedule that snapshot through existing SnapshotStore.

No effect handler synchronously reaches back into AppModel. Reader gap/application-failure callbacks return as a later typed command. An invalid authoritative edit/revision/frame is ignored or produces only a content-neutral local error; reader application failure uses the one resync contract and never overwrites authoritative text or saves a raw ID.

### 6.3 Autosave and lifecycle

- Every accepted document/title/preference/safe-frame change increments the existing snapshot revision exactly once and calls existing debounce scheduling off the UI path.
- Confirmed clear retains the current two-save safety protocol: successful pre-clear flush while content remains, then empty document/revision update and immediate atomic save. Do not route Clear through a plain text replacement.
- App termination continues to await `flushPersistence`; reader/editor objects do not own persistence.
- Restore sets editor/reader text by a named full-sync path but forces paused/hidden/shielded, clears current session display ID/confirmation, then queries/evaluates topology before any show.
- Never log, diagnose, name a file/default/menu/window, or formulate an error with script/title/replacement content.

### 6.4 Frame identity and restoration

1. OverlayPanelController clamps every candidate to the confirmed display and applies it at the existing sole `setFrame` boundary.
2. It reports the final applied frame plus transient display ID.
3. AppModel verifies that ID is the current confirmed safe candidate, resolves a persistence-eligible unique fingerprint, normalizes with `PanelFramePolicy`, replaces only that fingerprint's entry, and schedules v1 save.
4. On later current-session confirmation, AppModel searches saved frames by stable relationship. Exactly one match may restore, followed by clamp to current containment.
5. Zero matches use a safe default. Multiple/conflicting/weak ambiguous matches use a safe default and require confirmation; never restore by array position/name/session ID.

### 6.5 Binding fingerprint relationship truth table

Normalize UUID strings to lowercase canonical form and empty UUIDs to nil. Normalize vendor/model/serial zero to nil. `isBuiltIn` is always identity-relevant. `lastLocalizedName` is presentation metadata and a weak diagnostic hint only; it never overrides or completes persistent identity.

| Saved/current facts | Relationship | Automatic persistent use |
|---|---|---|
| Both UUIDs present and equal; built-in agrees; every hardware value present on both sides agrees | match | eligible only if that UUID occurs once in the current online/drawable inventory |
| Both UUIDs present and equal but built-in or any jointly present vendor/model/serial disagrees | conflict/unsafe | never |
| Both UUIDs present and different | no match, regardless of matching name or incomplete hardware | each may be eligible independently if its UUID is unique |
| UUID absent on one or both; built-in agrees; vendor, model, and meaningful nonzero serial are present on both and all equal | match | eligible only if the complete hardware tuple occurs once currently |
| UUID absent on one or both; complete hardware tuple differs | no match | never for that pair |
| UUID absent on one or both and vendor/model/meaningful serial is incomplete, including zero serial | ambiguous—not a persistent match even if names agree | never; explicit current-session selection/confirmation only |
| Built-in disagrees when any otherwise matching identity facts exist | conflict/unsafe | never |
| More than one current display resolves to the same UUID or complete hardware key | ambiguous duplicate | explicit runtime-ID selection may route the current session, but no instance becomes persistence-eligible |

Distinct nonnil UUIDs keep two otherwise identical zero-serial monitors distinct. The required duplicate-zero-serial test uses absent/nonunique UUID facts and must evaluate ambiguous. A raw current-session ID can disambiguate only after explicit user selection and confirmation; it never enters `DisplayFingerprint`, `PersistedSnapshot`, frame keys, logs, or menu text.

Define one canonical persistent key used by selection matching, duplicate detection, frame lookup/replacement, validation, and sorting: unique normalized UUID first; otherwise unique complete `(isBuiltIn, vendorID, modelID, meaningfulSerial)`; otherwise nil. When a persisted display name/confidence changes but the canonical key is the same, replace that frame/selection entry with the latest fingerprint metadata rather than append a duplicate. Keep wire keys/schema v1 unchanged and lock old canonical fixtures; the name is still encoded as metadata but does not form the stable key. Ambiguous/nil-key displays may have transient per-session geometry only and must not overwrite a persisted frame.

### 6.6 Binding edit arithmetic and resync ordering

`ScriptTextEdit` additionally carries checked `baseUTF16Length` and `resultUTF16Length`. For every edit:

```text
originalLength = processedEditedRange.length - changeInLength
originalRange = (processedEditedRange.location, originalLength)
replacement = post-edit text substring in processedEditedRange
changeInLength = replacement.utf16.count - originalRange.length
resultUTF16Length = baseUTF16Length + changeInLength
revision = baseRevision + 1
```

Every subtraction/addition uses checked nonnegative integer arithmetic. Reject overflow, negative original length, a range outside `baseUTF16Length`, a result inconsistent with the post-edit storage length, or a range that splits a UTF-16 surrogate pair. Ordinary script editing is scalar/UTF-16 safe; it does **not** prohibit a legitimate TextKit operation that removes a combining scalar inside an extended grapheme. Title truncation separately remains Character-boundary safe. Rename the composed-text test to `testCombiningCharacterEditUsesUTF16DeltaWithoutCorruption` so it tests preservation/correct offsets rather than a false grapheme-boundary rule.

The reader accepts an incremental edit only when all are true: it is not awaiting resync; `baseRevision == appliedRevision`; `revision == appliedRevision + 1`; storage UTF-16 length equals `baseUTF16Length`; range/delta arithmetic validates; the range is applicable; and post-apply length equals `resultUTF16Length`. A forward revision gap **or any contiguous-application failure** latches the same one pending resync, emits exactly one request, and completes with exactly one authoritative full replacement. Add `testContiguousInvalidRangePerformsOneAuthoritativeResync` and `testStorageLengthDivergencePerformsOneAuthoritativeResync`; both assert one request **and** one full replacement at the returned revision.

The resync command is handled and its full-reader replacement effect applied synchronously on the main actor without `await` before a later editor command can be reduced. It carries the authoritative full text and its exact current document revision. Reader sets storage and `appliedRevision` atomically, clears the latch, and then accepts later contiguous edits. Duplicate/stale full responses are ignored. Incremental effects observed while latched are ignored and cannot emit another request; the synchronous response contract prevents a later accepted edit from being omitted by the replacement. If that immediate effect cannot be applied, remain latched/hidden-safe and surface only a content-neutral error; do not loop or fabricate a revision.

## 7. TDD execution plan — named RED → GREEN

For every stage, commit the named test before its production change. On a Mac-authored stage, run the exact targeted command, capture the honest missing-symbol/failed-expectation RED, implement only that behavior, capture GREEN, then rerun all prior M2 targets. A compile failure is an acceptable first RED only when the not-yet-created type is the smallest honest expression. Never weaken/delete M0/M1 tests.

WSL cannot observe Swift/AppKit RED or GREEN. If WSL prepares implementation, each logical stage is two consecutive local commits: `nA` is a **test-only RED checkpoint** and `nB` is its minimum GREEN implementation. Record both full SHAs and the targeted command in the checksummed transfer manifest. Before accepting the candidate implementation, the Mac continuation checks out `nA`, runs that command and records the expected failure, then checks out `nB`, records GREEN, and reruns prior targets. If `nA` passes or fails for an unrelated reason, reject/rework the pair; a later GREEN alone is not TDD evidence. WSL reports only “RED checkpoint prepared, unobserved” and “implementation candidate prepared, unverified,” never a Swift result.

### M2.0 — Preflight and protected regression lock

Before implementation edits:

```bash
BASE=3526b4fa22f94c63c0237d55071f0d464a126e3a
test "$(git rev-parse "$BASE^{commit}")" = "$BASE"
git merge-base --is-ancestor "$BASE" HEAD
test "$(git branch --show-current)" = main
test "$(git remote get-url origin)" = 'https://github.com/thetomtimus/teleprompty.git'
test "$(git remote get-url --push origin)" = 'https://github.com/thetomtimus/teleprompty.git'
test -z "$(git status --porcelain)"
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
git diff --exit-code "$BASE" -- \
  PRD.md IMPLEMENTATION_PLAN.md design references \
  docs/validation/overlay-proof-result.md \
  docs/validation/m0-phase-a-causal-decision-2026-07-14.md \
  docs/validation/m0-phase-b-physical-selection-2026-07-14.md
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = 'Version: 2.45.4'
```

Run existing M0/M1 suites first. Any failure is a regression/blocker, not an expected feature RED:

```bash
swift test --package-path Packages/TeleprompterCore
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests \
  -only-testing:PrivatePresenterAppTests/SystemDisplayServiceTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticHotKeyServiceTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticObserverLifecycleTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests
```

### M2.1a — Edit value and editor TextKit 2 bridge

Required names from `IMPLEMENTATION_PLAN.md` plus missing correctness/concurrency tests:

- `testEditorReportsEditedRangeAndDelta`
- `testScriptTextEditValidatesBaseAndResultRevision`
- `testScriptTextEditIsSendableAcrossActorBoundary`
- `testUTF16EmojiEditBoundaries`
- `testCombiningCharacterEditUsesUTF16DeltaWithoutCorruption`
- `testProgrammaticEditorSyncDoesNotEmitUserEdit`
- `testEditorCallbackIsMainActorIsolated`
- `testEditorUsesTextKit2WithoutLegacyLayoutManager`
- `testStaleOrOutOfOrderEditCannotOverwriteAuthority`
- `testAcceptedEditMutatesStateBeforeReaderAndSnapshotEffects`

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/EditorTextSystemTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

### M2.1b — Incremental reader and one latched gap/application-failure resync

- `testIncrementalEditDoesNotReplaceReaderStorage`
- `testRevisionGapPerformsOneResync`
- `testMultipleUpdatesDuringGapRequestOnlyOneResync`
- `testDuplicateAndStaleReaderUpdatesAreIgnored`
- `testContiguousInvalidRangePerformsOneAuthoritativeResync`
- `testStorageLengthDivergencePerformsOneAuthoritativeResync`
- `testResyncToLatestRevisionRestoresIncrementalDelivery`
- `testInitialRestoreClearAndLatchedGapOrApplicationFailureAreOnlyFullReplacementReasons`
- `testReaderResyncCallbackIsMainActorIsolated`
- `testReaderUsesTextKit2WithoutLegacyLayoutManager`
- `testFontAndAlignmentUpdatesDoNotMutateReaderText`
- `testActiveBandToggleDoesNotMutateReaderText`

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ReaderTextSystemTests \
  -only-testing:PrivatePresenterAppTests/EditorTextSystemTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests
```

### M2.1c — Product controller, honest controls, clear, and autosave

- `testEmptyInstructionAndDisabledStart`
- `testClearPresentsConfirmation`
- `testWhitespaceOnlyScriptUsesEmptyInstruction`
- `testNonemptyM2ScriptStillExplainsScrollingIsM3`
- `testM2StartPauseRestartDoNotDispatchPlaybackCommands`
- `testM2FocusModeExplainsM4AndDoesNotChangeChrome`
- `testProductControllerExposesOpenCloseAndHideShowThroughOnePanelState`
- `testTitleTrimsDefaultsAndCapsWithoutSplittingCharacter`
- `testFontSizeAlignmentAndActiveBandPersistThroughV1Snapshot`
- `testAcceptedEditSchedulesAutosaveAfterAuthoritativeMutation`
- `testRapidEditsDebounceToLatestSnapshot`
- `testAutosaveDoesNotBlockMainActorEffectDispatch`
- `testAutosaveDiagnosticsExcludeScriptTitleAndReplacementText`
- retain all safe-clear tests: confirmed token, successful pre-clear flush, failure preserves script, intervening edit invalidates, stale completion cannot erase, post-clear immediate save

RED/GREEN:

```bash
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ControllerPresentationTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests
```

The exact implementation-plan UI behavior names run in the app unit-test target. Do not count the skipped `PrivatePresenterUITestShell` as proof.

### M2.2 — Production display inventory and identity

Required names:

- `testMapsNSScreenNumberToSessionID`
- `testBuildsFingerprintFromUUIDAndHardware`
- `testDuplicateZeroSerialDisplaysAreAmbiguous`
- `testRawDisplayIDIsNotEncoded`
- `testQueryFailureIsUnsafe`

Additional safety tests:

- `testMissingOrWrongTypedNSScreenNumberFailsClosed`
- `testDuplicateDrawableSessionIDsFailClosed`
- `testDuplicateOnlineSessionIDsFailClosed`
- `testZeroSessionIDFailsClosed`
- `testZeroVendorModelAndSerialAreNotStrongIdentity`
- `testLocalizedNameDoesNotOverrideHardwareConflict`
- `testAmbiguousFingerprintCannotRestoreAcrossSessionWithoutConfirmation`
- `testExplicitCurrentSessionChoiceDoesNotEnterEncodedSnapshot`
- retain `testProductionCurrentInventoryIncludesNonDrawableOnlineMirrorSink`, count-race, missing-hardware, missing-join, CG-only-nonselectable, and verified-mirror regressions

RED/GREEN:

```bash
swift test \
  --package-path Packages/TeleprompterCore \
  --filter DisplayTopologyEvaluatorTests
swift test \
  --package-path Packages/TeleprompterCore \
  --filter CoreStateModelTests
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

### M2.3 — Safety presentation, frames, recovery, and M0 protection

Required names:

- `testMirroringWarningUsesRequiredText`
- `testShieldPrecedesWarningAndReposition`
- `testSelectedDisplayNameIsVisible`
- `testAmbiguityRequiresExplicitConfirmation`
- `testMenuNeverContainsPrivateTitle`
- `testRecoveryNeverResumesAutomatically`
- `testPerDisplayFramesRemainSeparate`

Additional tests:

- `testExactMirroringWarningIsSeparateFromRecoveryGuidance`
- `testSelectedNameIsHiddenUntilCurrentSessionConfirmation`
- `testTopologyStatusDistinguishesExtendedMirroredSingleMissingAmbiguousAndQueryFailure`
- `testAmbiguousWeakDisplayFrameIsNotAutoRestoredOrPersisted`
- `testRestoredNormalizedFrameReclampsToCurrentContainment`
- `testFrameCallbackPersistsOnlyCurrentConfirmedDisplayFingerprint`
- `testDisplayLossPausesHidesShieldsBeforeFallbackPlacement`
- `testReconnectRemainsHiddenPausedUntilExplicitConfirmation`
- `testPendingShowCannotSurviveTopologyChange`
- `testWindowMenuDiagnosticAndAccessibilityLabelsExcludeSentinelPrivateContent`
- `testM2PreservesOnePanelAndOneAppModel`
- `testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain`
- `testM2PreservesDiagnosticHAndLDirectDispatchWithoutControllerRaise`
- `testM2PreservesEveryDragAndResizeFrameWithinSelectedDisplay`
- `testM2PreservesOpaqueRoundedReaderSurface`

RED/GREEN:

```bash
swift test \
  --package-path Packages/TeleprompterCore \
  --filter DisplayTopologyEvaluatorTests
swift test \
  --package-path Packages/TeleprompterCore \
  --filter PanelFramePolicyTests
xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ControllerPresentationTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SystemDisplayServiceTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticHotKeyServiceTests
```

## 8. Exact full verification commands and claim boundaries

### 8.1 Full Mac automated gate

Run from a clean commit after every implementation/review fix:

```bash
set -euo pipefail
BASE=3526b4fa22f94c63c0237d55071f0d464a126e3a
test -z "$(git status --porcelain)"
GATE_SHA="$(git rev-parse HEAD)"
test "${#GATE_SHA}" = 40
git merge-base --is-ancestor "$BASE" HEAD
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = 'Version: 2.45.4'
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
bash -n Scripts/*.sh
./Scripts/verify-no-network.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
git diff --exit-code "$BASE" -- \
  PRD.md IMPLEMENTATION_PLAN.md design references \
  docs/validation/overlay-proof-result.md \
  docs/validation/m0-phase-a-causal-decision-2026-07-14.md \
  docs/validation/m0-phase-b-physical-selection-2026-07-14.md
./Scripts/verify-macos.sh
git diff --check
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$GATE_SHA"
```

Record exact commit, command exits/test counts, Mac model/chip, macOS build, Xcode, Swift, XcodeGen, and Keynote version in the M2 result. The skipped UI-test shell is not a pass claim.

### 8.2 Exact WSL/static gate

```bash
set -euo pipefail
BASE=3526b4fa22f94c63c0237d55071f0d464a126e3a
test -z "$(git status --porcelain)"
GATE_SHA="$(git rev-parse HEAD)"
test "$(git rev-parse "$BASE^{commit}")" = "$BASE"
git merge-base --is-ancestor "$BASE" HEAD
test "$(git branch --show-current)" = main
test "$(git remote get-url origin)" = 'https://github.com/thetomtimus/teleprompty.git'
test "$(git remote get-url --push origin)" = 'https://github.com/thetomtimus/teleprompty.git'
bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
sha256sum -c docs/validation/source-artifact-checksums.sha256
git diff --exit-code "$BASE" -- \
  PRD.md IMPLEMENTATION_PLAN.md design references \
  docs/validation/overlay-proof-result.md \
  docs/validation/m0-phase-a-causal-decision-2026-07-14.md \
  docs/validation/m0-phase-b-physical-selection-2026-07-14.md
git diff --check
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$GATE_SHA"
```

WSL may prove file/test inventory, shell/Python behavior, source-level dependency/network/private-API/entitlement bans, protected bytes, Git hygiene, and reviewable diffs. It **cannot** prove Swift 6 compilation, actor isolation at runtime, TextKit 2 selection/edit behavior, AppKit window/menu contents, SnapshotStore APFS semantics, NSScreen/Core Graphics mapping on hardware, Keynote focus/full-screen/Spaces, physical display privacy, opacity, or interaction. Missing `swift`, `xcodebuild`, macOS, Keynote, or a second display is environment evidence—not a failed/passed Swift gate.

### 8.3 Exact-SHA evidence closure

The implementation/evidence sequence is binding:

1. Finish source stages `1A`–`5B`, including validator changes, with a clean tree. If they were WSL-prepared, first run every transferred `nA` RED checkpoint and paired `nB` GREEN commit on Mac in manifest order. Capture `SOURCE_SHA`; run all targeted/full Mac automated gates and section 9 manual acceptance on the product built from that SHA. Record raw content-neutral results locally under `.omx/tmp/`; do not change product source during the run.
2. Write `docs/validation/m2-controller-editor-display-safety-result.md` and update `HANDOFF.md` from those observed results. Those committed documents record `SOURCE_SHA`, environment, observations, and that their own commit will be evidence-only; they do **not** attempt to embed their future commit SHA. Commit only those two Markdown files as logical stage 6, then capture `FINAL_SHA`.
3. Prove the evidence-only commit changed no build/project/source/test/script/protected file and rerun the entire non-manual Mac gate on clean `FINAL_SHA`. Record `SOURCE_SHA` and `FINAL_SHA` in content-neutral `.omx/state/` execution state and in each later independent review artifact, not by editing commit 6. Manual evidence remains applicable only because the product source tree is byte-identical; otherwise rerun it.
4. Run code-reviewer → verifier → architect on exact clean `FINAL_SHA`. A review fix to code/tests/config/validator invalidates the prior manual and evidence record: make a new logical commit, rerun automated/manual gates, supersede the M2 result truthfully, and restart all reviews. A docs-only correction reruns automated/static gates and review but may retain manual evidence only after the source-equality assertion passes.

Exact closure commands:

```bash
test -z "$(git status --porcelain)"
SOURCE_SHA="$(git rev-parse HEAD)"
test "${#SOURCE_SHA}" = 40
# Run sections 7, 8.1, and 9; retain content-neutral local evidence.

git add HANDOFF.md docs/validation/m2-controller-editor-display-safety-result.md
git diff --cached --name-only | sort | diff -u \
  <(printf '%s\n' HANDOFF.md docs/validation/m2-controller-editor-display-safety-result.md) -
git commit  # Lore message for evidence/handoff only
FINAL_SHA="$(git rev-parse HEAD)"
test -z "$(git status --porcelain)"
git diff --quiet "$SOURCE_SHA" "$FINAL_SHA" -- \
  Packages PrivatePresenterApp PrivatePresenterAppTests PrivatePresenterUITests \
  Scripts Config project.yml Makefile PRD.md IMPLEMENTATION_PLAN.md design \
  references docs/validation/overlay-proof-result.md
mkdir -p .omx/state/m2
printf '{"source_sha":"%s","final_sha":"%s"}\n' "$SOURCE_SHA" "$FINAL_SHA" \
  > .omx/state/m2/source-evidence-shas.json
# Rerun section 8.1 on FINAL_SHA, then require every review artifact to name FINAL_SHA.
```

## 9. Practical manual Mac acceptance for M2

Use synthetic nonprivate text only. Do not commit screenshots, videos, scripts, titles, snapshot files, or diagnostics containing private content.

1. Record clean implementation SHA, hardware/OS/tool versions, two displays/cable/dock, arrangement/origins, separate-Spaces setting, Keynote version, and selected `.statusBar + frontRegardless` defaults.
2. Start extended mode. Confirm the controller starts generic/shielded and cannot reveal title/editor before current-session display confirmation.
3. Confirm the display selector lists drawable screens by localized name, topology says extended, the chosen private display name is clear, and no display is guessed.
4. Enter a synthetic 50,000-word plain-text script, type/undo/paste/delete at beginning/middle/end including emoji and composed characters, and observe responsive editor plus static reader updates. This is a practical smoke, not M5 performance certification.
5. Change the title, font size, left/center alignment, and active band. Verify static reader changes without text loss or motion. Verify speed, Start/Pause/Restart, and Focus Mode are visibly unavailable with M3/M4 explanations.
6. Hide/show and open/close the same single panel. Confirm it remains paused and nonactivating. Lock/unlock and verify click-through/recovered interaction.
7. Quit normally during rapid edits, relaunch, and verify the latest committed title/script/preferences restore but panel remains hidden/paused/shielded until a fresh confirmation.
8. Empty/whitespace: instruction is visible and Start disabled. Clear: cancel preserves content; confirm follows safe protocol and restores an empty document only after successful flush. Simulated failure coverage remains automated—do not induce disk corruption on user data.
9. Move/resize on display A, then B, then return to A. Confirm distinct normalized frames restore/clamp only after safe confirmation and every intermediate stays within the selected display.
10. With Keynote in full-screen Presenter Display, run existing DEBUG H/L and ordinary panel controls. Keynote remains frontmost/full-screen; Private Presenter/panel/controller never become key/main or raise; header/eight zones remain contained when unlocked; surface remains opaque over bright pixels.
11. Enable actual hardware mirroring. Confirm the panel pauses/hides and controller shields before it displays the exact warning; show remains blocked. Return to extended mode: nothing auto-reveals/resumes and explicit selection/confirmation is required.
12. Disconnect the selected display while visible and reconnect. Confirm pause/hide/shield/invalidation precedes recovery placement/warning, generic safe fallback only, and no auto-resume/reveal.
13. Where duplicate/zero-serial hardware is available, confirm ambiguity instead of automatic selection/restore. Otherwise record this row **not physically exercised** and rely only on injected tests—never call it physically passed.
14. Inspect the application menu, Window menu, NSWindow title, diagnostics disclosure/copy text, warnings, accessibility labels exposed by Accessibility Inspector, and any existing status text using a sentinel title/script. Neither sentinel appears outside the private confirmed editor/reader.
15. Capture content-neutral result rows. Reconfirm that ordered-out repetitions and remote/photo breadth deferred by the owner transition remain unclaimed release/hardening work.

**Acceptance boundary:** Passing these rows makes M2 the first usable editor/display-safety alpha. It does not make scrolling usable (M3), lecture controls ready (M4), or the product performance/accessibility/polish complete (M5/M6).

## 10. Data safety, migration compatibility, rollback

- `PersistedSnapshot.currentSchemaVersion` and `ScriptDocument.currentSchemaVersion` remain 1. No new keys, migration, destructive rewrite, or default-store reset is required.
- Before manual destructive-clear/rollback checks, quit the app and copy the sandboxed `current-snapshot.json` from the app's Application Support container to a timestamped local private backup outside the repository. Treat it as private lecture content; never commit, attach, log, or upload it.
- Existing canonical v1 fixture tests must remain byte-identical. New M2 values already occupy existing title/text/preferences/frame fields. Current session ID/playback/chrome/resync state remains non-Codable.
- SnapshotStore failures preserve in-memory content and last-known-good bytes; unsupported future/malformed handling and write-block latch remain unchanged.
- Roll back by `git revert` of logical M2 commits in reverse order. Because storage remains valid v1, no data down-migration is needed. Preserve the snapshot backup until the reverted app loads and saves successfully.
- If display mapping/identity is uncertain after rollback, stay hidden/paused/shielded and discard only transient selection; never delete a snapshot to make a privacy test pass.

## 11. Deliberate pre-mortem

| Failure | Early signal | Prevention / RED test | Recovery |
|---|---|---|---|
| Editor echo or range math corrupts Unicode | duplicate callbacks, revision conflict, emoji split | programmatic-suppression, UTF-16/delta validation, grapheme/title tests | reject edit content-neutrally; authoritative text stays; explicit one-time sync |
| Reader silently rebuilds 50k words each keystroke | full-replacement counter rises on normal edits | separate storage and `testIncrementalEditDoesNotReplaceReaderStorage` | stop, restore incremental effect; do not call it M2 green |
| Missing/out-of-order update causes repeated resync storm | multiple callbacks for one gap | one awaiting-resync latch and duplicate/gap tests | one latest authoritative replace; resume only at returned revision |
| Duplicate/zero-serial display restores onto audience screen | multiple fingerprint matches or weak facts | normalized relationship, no persisted runtime ID, ambiguity/frame tests | pause/hide/shield; safe default; explicit current-session confirmation |
| Warning/update reveals content before shield | private view visible during mirror/disconnect | state-before-effects/order tests and manual actual mirror/disconnect | keep hidden, revert offending slice, rerun all privacy/M0 gates |
| Autosave/clear loses last good script | stale debounce wins or clear bypasses flush | existing generation/conflict/clear tests plus rapid edit autosave tests | retain in-memory/last-good file; content-neutral error; retry/rollback |
| Future controls imply non-existent scrolling/Focus behavior | Start changes `playing` without motion | capability presentation and no-dispatch tests | disable/explain; defer implementation to M3/M4 |
| Product controller leaks title into app surfaces/DEBUG evidence | sentinel appears in menu/window/diagnostics | menu/status/accessibility/diagnostic sentinel tests | generic fixed labels only; reject evidence file; rerun privacy audit |
| WSL green is mistaken for Mac proof | no xcodebuild/TextKit/hardware evidence | explicit environment boundary and Mac gate | local commits/bundle only; no push/claim until Mac verification |
| Canonical plan is handed off uncommitted or drifts from reviewed bytes | `$ralph` path missing/dirty/different from `.omx` source | exact-status, stage-set, Lore-commit, clean-tree, `PLAN_SHA`, and post-commit `cmp` checks | do not terminalize RALPLAN; repair publication and rerun checks |
| Evidence commit contaminates the manually tested product or tries to embed its own hash | stage 6 includes source/test/script/config changes or dirties itself after `FINAL_SHA` capture | exact two-path cached assertion, `SOURCE_SHA..FINAL_SHA` source-equality check, and external final-SHA state/reviews | discard evidence commit, rerun source/manual gates, recreate truthful evidence; never self-embed `FINAL_SHA` |
| Cross-host continuation loses TDD or binding planning gates | only GREEN head/bundle arrives, or `.omx` PRD/test/manifest is missing | preserve `nA`/`nB` ancestry and transfer a checksummed planning-gates tar beside bundle/patch | stop before Mac acceptance; reacquire and verify archive, then replay every RED/GREEN pair |

## 12. Logical Lore commits

Each commit follows the repository Lore format, includes why-first intent plus honest `Tested:`/`Not-tested:` trailers, and is kept local until Mac gates permit publication.

For each source stage below, `nA` is a test-only RED checkpoint and `nB` is the GREEN implementation. A Mac-created pair observes RED before authoring `nB`; a WSL-created pair remains an unverified candidate until Mac replays `nA` then `nB` as section 7 requires. Preserve both commits—do not squash away the RED checkpoint before Mac evidence.

1. **Refuse unstable display identity before product selection** — `1A` adds fingerprint/mapping/ambiguity/query RED tests only; `1B` implements normalized fail-closed identity. No UI/editor changes.
2. **Keep long-script edits incremental under one authority** — `2A` adds edit/resync/Swift 6/Unicode RED tests only; `2B` implements ScriptTextEdit, separate TextKit 2 systems, and typed AppModel commands/effects.
3. **Expose only behavior that the M2 alpha can perform** — `3A` adds controller/static-reader/clear/autosave/capability RED tests only; `3B` implements the product controller, reader, and DEBUG disclosure.
4. **Restore each confirmed display without exposing recovery** — `4A` adds frames/shield/warning/menu/M0-regression RED tests only; `4B` implements normalized-frame callbacks and M2 safety/recovery presentation.
5. **Make M2 verification reproducible without widening platform access** — `5A` adds the validator's missing-path/test/prohibited-surface expectations and captures its expected static failure; `5B` updates the validator and passes static/protected gates. No evidence claims yet.
6. **Record the M2 boundary without changing the verified product** — result/HANDOFF only after real Mac evidence; include `SOURCE_SHA` but never the commit's own future hash, assert source identity, record `FINAL_SHA` externally, rerun non-manual gates, then review that exact SHA.

Representative message:

```text
Keep long-script edits incremental under one authority

The first usable editor must update a 50,000-word reader without replacing its
entire storage or letting TextKit become a second document owner, so edits carry
validated UTF-16 ranges and revisions through AppModel.

Constraint: Swift 6 complete concurrency and TextKit 2 on macOS 14+
Rejected: Share one text storage | couples controller and overlay layout/lifecycle
Confidence: high
Scope-risk: moderate
Directive: Full replacement is limited to initial/restore/clear or one latched gap/application-failure resync
Tested: <exact targeted and full Mac commands with counts>
Not-tested: <unrun hardware/Keynote/manual rows>
```

## 13. Implementation review and stop gates

After implementation and Mac evidence, run independent roles sequentially:

1. **code-reviewer — APPROVE:** scope-only diff, TextKit edit/resync correctness, one authority, display privacy/identity, menu/data leakage, no prohibited surfaces/dependencies.
2. **verifier — PASS:** independently rerun exact targeted/full Mac and WSL-safe/static gates, inspect protected bytes and manual evidence paths, and separate observed facts from deferred rows.
3. **architect — APPROVE:** confirm M2/M3/M4 boundary, safe display/frame semantics, no second model/panel, and schema/rollback compatibility.

Any critical/high finding or failed command is fixed in a new/reworked logical commit and restarts affected tests plus the full review sequence. Reviews may not approve from summaries alone. No Swift/AppKit commit is pushed until the Mac automated gate, applicable manual M2 acceptance, and all three approvals are complete on the exact clean SHA. Never force-push or publish private content/media.

## 13.1 Available agents and execution-lane guidance

### Available-agent-types roster

Installed roles relevant to follow-up are `explore`, `analyst`, `planner`, `architect`, `debugger`, `executor`, `team-executor`, `test-engineer`, `code-reviewer`, `verifier`, `critic`, `dependency-expert`, `researcher`, `writer`, `git-master`, `code-simplifier`, `designer`, `vision`, `scholastic`, and the installed Prometheus Strict roles. Do not use `worker` outside active Team runtime. M2 needs no dependency-expert/researcher after the official API checks already cited, and no designer/vision lane because M6 polish is excluded.

Suggested effort and ownership:

- **executor, xhigh:** primary implementation; sole owner of shared `AppModel`, `AppRuntime`, `AppCommand`, `AppEffect`, and final integration;
- **test-engineer, xhigh:** RED→GREEN evidence and hostile revision/identity/privacy cases, with test-file ownership but no parallel edits to AppModel;
- **architect, high:** read-only boundary/privacy review and Mac evidence sign-off;
- **code-reviewer, high:** independent scope/concurrency/privacy/data review after integration;
- **verifier, high:** independently rerun exact commands and reconcile claims to clean SHA;
- **git-master, high (bounded):** Lore commit/path-set/source-vs-evidence closure only;
- **explore/writer, low-to-high (bounded):** read-only lookup and content-neutral result/HANDOFF drafting when useful.

### Goal-Mode Follow-up Suggestions

- `$ralph` is the required and default execution entrypoint for this approved plan. Section 14 is the sole active launch command and binds the complete RED→GREEN, WSL→Mac, commit, independent-review, and stop contract.
- `$ultragoal` or `$team` is not authorized by this plan. Either may be considered only after a new explicit user override, and that override must preserve every section-14 constraint, the sole AppModel/AppRuntime integration owner, exact source/evidence SHA closure, and the M2 stop.
- `$autoresearch-goal` is not appropriate: this is implementation, not a research deliverable. `$performance-goal` is also not appropriate: the 50,000-word check is an M2 smoke and M5 owns optimization/certification.

### Conditional parallel-lane verification path

This path is descriptive staffing guidance only. It becomes active only if the user later explicitly overrides the required `$ralph` entrypoint to authorize Team or Ultragoal.

1. Each authorized lane returns its targeted RED and GREEN commands plus exact changed-file set; parallel lanes do not merge two owners' edits to AppModel/AppRuntime.
2. Leader integrates and runs all section 7 targets, full WSL/static gate, protected checksums, no-network audit, and diff hygiene; the leader checkpoints that evidence.
3. On WSL, stop at candidate stages `1A`–`5B` and produce the local bundle/patch plus checksummed planning-gates/RED-manifest archive. A Mac owner verifies and replays every pair before the full automated/manual gate on `SOURCE_SHA`.
4. Mac owner creates evidence-only commit 6, proves product-source equality, reruns non-manual gates, then obtains code-reviewer → verifier → architect approval on `FINAL_SHA`.
5. Any authorized parallel runtime shuts down only after handing evidence to the leader's durable ledger; it may not cross into M3 or push before the plan's Mac gate.

### Conditional Team/Ultragoal launch hints — inactive without a new user override

These commands satisfy staffing documentation only; **do not run them for this approved handoff**. They become eligible solely after a new explicit user instruction that replaces section 14 while retaining every M2 safety/verification constraint:

```text
$ultragoal Execute only the approved Private Presenter M2 plan with the Ralph
constraints preserved verbatim. Own the durable ledger, AppModel integration,
RED-checkpoint manifest, WSL-to-Mac transfer, and source/evidence SHA closure.

$team 3 Execute only disjoint M2 lanes under the authorized Ultragoal leader:
executor owns editor/reader adapters plus leader-integrated AppModel effects;
test-engineer owns RED checkpoints and hostile cases; team-executor owns non-
overlapping display/safety UI files. No worker pushes or claims Mac evidence.

omx team 3 --task 'Execute only the approved M2 plan under a leader-owned durable
ledger; preserve section-14 safety, RED/GREEN, Mac-evidence, and stop gates.'
```

## 14. Exact `$ralph` implementation handoff

Use only after this plan's Planner → Architect → Critic consensus record says COMPLETE and the RALPLAN state is terminal:

```text
$ralph Implement only Private Presenter M2 from
`docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md`, using
`.omx/plans/prd-milestone-2-controller-editor-display-safety.md` and
`.omx/plans/test-spec-milestone-2-controller-editor-display-safety.md` as binding
gates. Start from `main` descended from exact clean baseline
`3526b4fa22f94c63c0237d55071f0d464a126e3a`; stop if protected source/history
bytes differ before implementation.

Implement M2.1–M2.3 only with TDD. Keep one @MainActor AppModel, one panel,
separate TextKit 2 editor/reader storage, incremental UTF-16 range/delta edits,
and exactly one latched authoritative resync per revision gap or contiguous
application/storage-divergence failure. Reuse SnapshotStore and
schema v1. Treat display query/mapping/duplicate/zero-serial ambiguity as unsafe;
never persist a raw display ID. Preserve pause/hide/shield/invalidate before
warning/reposition, per-display safe normalized frames, no auto reveal/resume,
menu/status privacy, DEBUG H/L, `.statusBar + frontRegardless`, nonactivation,
permanent non-key/non-main behavior, containment, and opacity.

The product controller may enable only title/editor, safe clear, Open/Close and
Hide/Show of the existing panel, lock, display selection/confirmation, font size,
left/center alignment, and static active band. Show Start/Pause/Restart/speed as
disabled M3 controls and Focus Mode as a disabled M4 control. Do not simulate
scrolling by entering playing state. Do not implement M3 scrolling, M4 product
hotkeys/Focus/menu, M5 hardening, or M6 polish.

Do not add dependencies, network, telemetry, cloud/accounts, WebView/JS,
Accessibility/event taps/global monitors, private API, focus-return hacks,
unbounded levels, entitlements, resources, or schema migration. Preserve PRD.md,
IMPLEMENTATION_PLAN.md, design/reference artifacts, M0 phase decisions, and the
entire historical proof plus owner transition byte-for-byte. Do not claim the
owner-deferred ordered-out repetitions or human remote/photo breadth passed.

Automatically execute the plan's named RED→GREEN sequence. Use an executor for
implementation and test-engineer for test evidence if native subagents materially
help, with shared AppModel/AppRuntime integration under one owner. Run every WSL-
safe/static gate available in the current environment, then run an independent
code-reviewer. Create test-only `1A`–`5A` RED checkpoints before paired `1B`–`5B`
implementation commits, each with honest Tested/Not-tested trailers. On WSL/Linux
prepare stages `1A`–`5B` only and mark all Swift RED/GREEN observations unverified.
On Mac, observe each RED checkpoint before accepting its paired GREEN commit.
Independently run verifier then architect after Mac evidence; fix high/critical
findings and restart affected gates.

If the current host is WSL/Linux, do not claim Swift/AppKit/TextKit/Keynote/display
success and do not push. Stop after candidate stages `1A`–`5B`; do not create the
M2 result, update HANDOFF, or fabricate evidence stage 6. Keep those commits local
and create the bundle/patch, RED/GREEN manifest, and checksummed planning-gates
archive in `.omx/tmp/` for Mac continuation. The Mac continuation verifies the
archive, replays every RED/GREEN pair, runs automated/manual gates on clean
SOURCE_SHA, writes result/HANDOFF with SOURCE_SHA only, creates evidence-only stage
6, proves product-source identity, records FINAL_SHA externally, reruns non-manual
gates, and performs reviews on clean FINAL_SHA. No Swift/AppKit changes may be pushed
until that sequence passes. Never force-push or publish private
script/title/snapshot/media. Stop at the M2 handoff; do not begin M3.
```

WSL handoff artifacts, when needed:

```bash
mkdir -p .omx/tmp
GATE_DIR=.omx/tmp/m2-planning-gates
rm -rf "$GATE_DIR"
mkdir -p "$GATE_DIR"
cp .omx/plans/prd-milestone-2-controller-editor-display-safety.md "$GATE_DIR/"
cp .omx/plans/test-spec-milestone-2-controller-editor-display-safety.md "$GATE_DIR/"
(cd "$GATE_DIR" && sha256sum \
  prd-milestone-2-controller-editor-display-safety.md \
  test-spec-milestone-2-controller-editor-display-safety.md > SHA256SUMS)
# Write one tab-separated line per stage: stage, RED_SHA, GREEN_SHA, exact Mac command.
test -s .omx/tmp/m2-red-green-manifest.tsv
awk -F '\t' 'NF != 4 || $1 !~ /^[1-5]$/ || length($2) != 40 || length($3) != 40 { exit 1 }' \
  .omx/tmp/m2-red-green-manifest.tsv
while IFS=$'\t' read -r stage red_sha green_sha command; do
  git cat-file -e "$red_sha^{commit}"
  git cat-file -e "$green_sha^{commit}"
  git merge-base --is-ancestor "$red_sha" "$green_sha"
done < .omx/tmp/m2-red-green-manifest.tsv
cp .omx/tmp/m2-red-green-manifest.tsv "$GATE_DIR/"
(cd "$GATE_DIR" && sha256sum m2-red-green-manifest.tsv >> SHA256SUMS)
tar -C .omx/tmp -cf \
  .omx/tmp/2026-07-14-milestone-2-planning-gates.tar \
  m2-planning-gates
sha256sum .omx/tmp/2026-07-14-milestone-2-planning-gates.tar \
  > .omx/tmp/2026-07-14-milestone-2-planning-gates.tar.sha256
git bundle create \
  .omx/tmp/2026-07-14-milestone-2-controller-editor-display-safety.bundle \
  3526b4fa22f94c63c0237d55071f0d464a126e3a..HEAD
git format-patch \
  --stdout 3526b4fa22f94c63c0237d55071f0d464a126e3a..HEAD \
  > .omx/tmp/2026-07-14-milestone-2-controller-editor-display-safety.patch
```

Transfer the bundle or patch **together with** the planning-gates tar and its
`.sha256` sidecar. On Mac, verify the outer checksum, extract, run
`(cd m2-planning-gates && sha256sum -c SHA256SUMS)`, restore the two files under
`.omx/plans/`, and replay the manifest before accepting `SOURCE_SHA`:

```bash
shasum -a 256 -c .omx/tmp/2026-07-14-milestone-2-planning-gates.tar.sha256
tar -xf "$PWD/.omx/tmp/2026-07-14-milestone-2-planning-gates.tar" -C .omx/tmp
(cd .omx/tmp/m2-planning-gates && shasum -a 256 -c SHA256SUMS)
mkdir -p .omx/plans
cp .omx/tmp/m2-planning-gates/{prd,test-spec}-milestone-2-controller-editor-display-safety.md \
  .omx/plans/
SOURCE_SHA="$(git rev-parse HEAD)"
while IFS=$'\t' read -r stage red_sha green_sha command; do
  git switch --detach "$red_sha"
  if bash -lc "$command"; then
    echo "Stage $stage did not produce the required RED" >&2
    exit 1
  fi
  git switch --detach "$green_sha"
  bash -lc "$command"
done < .omx/tmp/m2-planning-gates/m2-red-green-manifest.tsv
git switch main
test "$(git rev-parse HEAD)" = "$SOURCE_SHA"
test -z "$(git status --porcelain)"
```

The manifest's commands are the exact stage-specific `xcodebuild`/`swift test`
commands from section 7, serialized as one shell line with no tabs. Missing,
mismatched, or unrelated-failure gates are a hard stop. These are local handoff
artifacts, not permission to push.

## 15. Canonical planning publication

After Architect APPROVE and later Critic APPROVE, replace the draft status/consensus placeholders in this `.omx` source, then publish the byte-identical approved plan to `docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md`. That repository path—not the `.omx` working copy—is the canonical implementation handoff. Require an otherwise clean baseline, stage exactly that target, create one local Lore planning commit, capture `PLAN_SHA`, restore a clean tree, and re-run `cmp`. Only then mark the RALPLAN state terminal/consensus COMPLETE. The PRD/test spec/reviews remain durable `.omx/plans` gate artifacts referenced by the canonical plan.

Planning finalization checks:

```bash
cmp -s \
  .omx/plans/milestone-2-controller-editor-display-safety.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md
test "$(git status --porcelain)" = \
  '?? docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md'
git add docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md
test "$(git diff --cached --name-only)" = \
  'docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md'
git commit \
  -m 'Make the M2 implementation boundary independently executable' \
  -m 'The controller/editor and display-safety slice needs one reviewed canonical source before autonomous execution can begin.' \
  -m "$(printf '%s\n' \
    'Constraint: Historical M0 BLOCKED evidence and the owner transition remain immutable' \
    'Rejected: Uncommitted handoff plan | cannot bind Ralph to reviewed bytes' \
    'Confidence: high' \
    'Scope-risk: narrow' \
    'Tested: protected checksums, structure validator, WSL-safe gates, and planning consensus' \
    'Not-tested: Swift, AppKit, TextKit, Keynote, and physical display behavior')"
PLAN_SHA="$(git rev-parse HEAD)"
test "${#PLAN_SHA}" = 40
test -z "$(git status --porcelain)"
test "$(git log -1 --format=%B | git interpret-trailers --parse)" = \
  "$(printf '%s\n' \
    'Constraint: Historical M0 BLOCKED evidence and the owner transition remain immutable' \
    'Rejected: Uncommitted handoff plan | cannot bind Ralph to reviewed bytes' \
    'Confidence: high' \
    'Scope-risk: narrow' \
    'Tested: protected checksums, structure validator, WSL-safe gates, and planning consensus' \
    'Not-tested: Swift, AppKit, TextKit, Keynote, and physical display behavior')"
cmp -s \
  .omx/plans/milestone-2-controller-editor-display-safety.md \
  docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md
git diff --check
```

Do not invoke `$ralph` until that canonical target exists and the state records the approved Architect-then-Critic sequence.

## 16. Planning consensus record

- Planner: **READY.** Chose the revisioned, separate TextKit 2 adapter path; fail-closed persistent fingerprinting; capability-gated product UI; existing schema/store/window/privacy reuse; named M2 and missing concurrency/ambiguity/autosave tests. Durable record: `.omx/plans/m2-planner-review.md`.
- Architect iteration 5 repair verification: **APPROVE**. Confirmed the Ralph-only default, complete ADR, non-self-referential evidence SHA closure, replayable test-only RED checkpoints, and checksummed cross-host binding artifacts. Durable review: `.omx/plans/m2-architect-review.md`.
- Critic iteration 5, run only after that Architect approval: **APPROVE**. Confirmed every prior finding and later Architect blocker is closed without weakening technical, privacy, scope, TDD, Mac/WSL, or publication gates. Durable review: `.omx/plans/m2-critic-review.md`.
- Consensus gate: **COMPLETE** in required Planner → Architect → Critic order. No implementation was performed and `$ralph` was not invoked.

### Applied review improvements

- Made display fingerprint precedence, duplicate handling, session routing, and frame-key eligibility implementation-deterministic.
- Bound checked UTF-16 edit arithmetic and exactly-one latched resync for revision gaps or application/storage divergence.
- Closed canonical-plan publication, native Lore trailer, clean-tree, source-SHA, evidence-only final-SHA, and WSL→Mac handoff gaps.
- Preserved test-only RED checkpoints for WSL-prepared work, removed impossible evidence-commit self-reference, and checksummed the PRD/test/manifest cross-host transfer.
- Made section 14's exact `$ralph` command the only authorized default; parallel runtimes now require a new explicit user override.
- Added an explicit role roster, ownership boundaries, official Apple API sources, and the complete ADR Drivers/Alternatives/Why/Follow-ups fields.
