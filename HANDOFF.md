# Private Presenter — Guarded Milestone 1 Source Handoff

## Status and boundary

- Branch: `main`
- Implementation parent: `dfaec0b3b933aca46907003530dead19ae01babc`
- Working-tree status: M1.1–M1.4 are committed in six logical local commits
  ending at `88d28cb950c4b2628075aaa408b8e7716864ae31`
- Origin: `https://github.com/thetomtimus/teleprompty.git` (fetch and push)
- Mac implementation underlying the physical run: `31dff6fdfa56a0987e0b76622c81939419096dbd`
- macOS automated status: reported as tested for `31dff6f`; raw command logs and
  authoritative test counts are not committed, and this WSL planning run did not
  independently reproduce the macOS suite
- Real Keynote + second-display/projector proof: **BLOCKED**, not PASS; see
  `docs/validation/overlay-proof-result.md`
- M1 execution status: source/static checks passed independently; Tom reported
  the complete Mac verification and DEBUG proof-harness smoke test passed. Raw
  Mac logs are not committed, so that platform result remains user-reported.
- Next guarded slice: **dedicated M0 stabilization**, not M2
- Hard gate: **M2 UI expansion, beta use, and readiness claims remain blocked**
  until the dedicated M0 stabilization slice passes the complete physical matrix

This handoff must not be read as an M0 pass. The 2026-07-12 physical run recorded
positive evidence for extended Keynote placement, later overlay visibility,
normal Keynote input/click-through, repeated toggling after the initial failure,
and fail-closed disconnect/reconnect. It also recorded an initial focus/full-screen
interruption and incomplete focus/key/main, physical-audience, Space, mirroring,
level-comparison, opacity, unlock/drag/resize boundary, and hostile-recovery gates.
Those defects remain explicit and the historical BLOCKED result must not be weakened.

This handoff records M1 acceptance using Tom's Mac-pass report plus independent
WSL/static checks and source-level OMX reviews. It does not upgrade the BLOCKED
M0 physical result, and M2, beta use, and readiness claims remain blocked.

## Milestone 0 implementation inventory

- M0.1 reproducible project shell: `project.yml`, `.xcodegen-version`,
  `Config/*`, `Makefile`, `Scripts/*`, app/package/test target shells,
  sandbox-only entitlements, structure validation, and prohibited-surface audit.
- M0.2 Foundation-only fail-closed display topology policy and named tests:
  `Packages/TeleprompterCore/Sources/TeleprompterCore/{Models,Display}` and
  `DisplayTopologyEvaluatorTests.swift`.
- M0.3 frame-pinning policy, clamped AppKit interaction adapter, and named tests:
  `PanelFramePolicy.swift`, `ClampedPanelInteractionController.swift`, wired
  drag header/eight resize zones, AppKit containment backstop, and frame tests.
- M0.4 single nonactivating `NSPanel` proof, bounded level/configuration,
  lock/click-through/no-key/no-main/no-activation contract, opaque rounded
  interior, and named tests: `PrivatePresenterApp/Overlay/*` and
  `OverlayPanelConfigurationTests.swift`.
- M0.5 minimal display/controller privacy coordination, ordered fail-closed
  effects, shield, selected-screen handling, and named tests:
  `SystemDisplayService.swift`, `Privacy/*`, and the former
  `DiagnosticHarnessModel.swift` implementation now mechanically renamed to `AppModel.swift`,
  both window controllers, and `AppModelTests.swift` /
  `OverlayPanelControllerTests.swift`.
- M0.6 DEBUG proof harness, immutable configuration snapshot, minimal
  select/show/lock/hide controls, and physical-proof template:
  `WorkspaceFocusProbe.swift`, `DiagnosticHotKeyService.swift`, controller
  proof UI, `docs/validation/overlay-proof-template.md`, and this handoff.
- Commit status: M0 source is committed through `31dff6f`; `cca4229` adds only the
  truthful BLOCKED physical result.
- Deliberately still absent after M1: editor UI, scrolling/display-link work,
  production hotkey customization, menu/status item, product polish, accounts,
  cloud/network, telemetry, signing/notarization, and distribution.

## Milestone 1 source inventory

- M1.1 durable core state: `ScriptDocument`, `ReadingAnchor`,
  `TeleprompterPreferences`, `OverlaySession`, `KeyboardShortcut`, the PRD
  default shortcut map, `PersistedSnapshot`, canonical v1 JSON, and
  `CoreStateModelTests.swift`.
- M1.2 refusal/restore policy: explicit v1 `SnapshotMigrator`, typed future and
  legacy refusal, malformed-data handling without content disclosure, and
  hidden/paused privacy-reassessment restore in `SnapshotMigratorTests.swift`.
- M1.3 local durability: actor-isolated `SnapshotStore`, Foundation-only
  filesystem/scheduling seams, 300 ms generation-safe debounce, flush/revision
  conflict handling, sibling-temp atomic replacement contract, malformed
  quarantine, future/quarantine-failure write blocking, privacy-safe diagnostics,
  and `SnapshotStoreTests.swift`.
- M1.4 single state owner: one `@MainActor @Observable AppModel`, typed
  `AppCommand`/`AppEffect`, `DependencyContainer`, pure `PrivacyDirective`
  planning, startup ordering seams, revision-bound clear flow, and mechanical
  DEBUG/M0 harness wiring through the same model.
- Audit/housekeeping: the validator inventories all M1 paths and named tests,
  retains the Foundation-only core audit, adds product data-safety scans, and
  `verify-wsl.sh` requires the exact expected fetch and push URLs for `origin`.

These are source/test artifacts only until the Mac commands below pass. In
particular, no WSL result proves Swift compilation, concurrency correctness,
AppKit lifecycle behavior, APFS replacement semantics, or physical privacy.

## WSL-safe verification

Run from the repository root:

```bash
./Scripts/verify-wsl.sh

bash -n Scripts/*.sh
python3 Scripts/validate_project_structure.py
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

Current guarded-M1 WSL record (`2026-07-12`, Asia/Seoul):

- `command -v swift`: exit `1`; Swift is absent. Consequently no named M1 test
  could be observed behavior-RED or GREEN here.
- `./Scripts/bootstrap-macos.sh`: exit `1` with exactly
  `error: bootstrap-macos.sh requires macOS.` This is the second explicit
  environment RED and prevents XcodeGen/Xcode/AppKit execution on this host.
- `bash -n Scripts/bootstrap-macos.sh Scripts/verify-macos.sh
  Scripts/verify-no-network.sh Scripts/verify-wsl.sh`: exit `0`.
- `python3 Scripts/validate_project_structure.py`: exit `0`, printing
  `Project structure validation passed (Milestone 0–1 source).`
- `git diff --check`, the XcodeGen pin, generated-project ignore/untracked
  checks, `sha256sum -c docs/validation/source-artifact-checksums.sha256`,
  `./Scripts/verify-no-network.sh`, and `./Scripts/verify-wsl.sh`: exit `0`.
- Exact origin-name/fetch/push checks: exit `0`; both URLs are exactly
  `https://github.com/thetomtimus/teleprompty.git`.
- Cached refs only: `HEAD` and `origin/main` both resolve to
  `dfaec0b3b933aca46907003530dead19ae01babc`, and
  `git rev-list --left-right --count origin/main...HEAD` prints `0 0`. This is
  **not** a fresh fetch/divergence proof; fetch remains mandatory before push.
- No commits were created because `.git` is read-only in this sandbox. The
  working tree must be committed from parent `dfaec0b3b933aca46907003530dead19ae01babc`
  using the six logical Lore commits in the M1 plan after Mac validation/fixes.

The requested RED→GREEN test order is represented by the named test sources and
their corresponding implementations, but it was not executable in WSL. Do not
rewrite the environment failures as application RED evidence and do not call
the source/static gate a Swift test pass.

### Writable-Git parent instructions

After copying the complete working tree to a Mac checkout whose `HEAD` is exactly
`dfaec0b3b933aca46907003530dead19ae01babc`, complete the pending tests/reviews
and any required fixes. Then create the section 12 Lore commits by staging these
path groups in order (use the matching section 12 intent as each commit's first
line and include `Confidence`, `Scope-risk`, `Tested`, and `Not-tested` trailers):
Each `# Commit` line below is a mandatory commit boundary before the next
`git add`; populate its `Tested` trailer from the actual Mac output.

```bash
git add Scripts/verify-wsl.sh
# Commit 1: Keep repository verification aligned with the intentional GitHub origin

git add Packages/TeleprompterCore/Sources/TeleprompterCore/Models/KeyboardShortcut.swift \
  Packages/TeleprompterCore/Sources/TeleprompterCore/Models/OverlaySession.swift \
  Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ReadingAnchor.swift \
  Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift \
  Packages/TeleprompterCore/Sources/TeleprompterCore/Models/TeleprompterPreferences.swift \
  Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift \
  Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift
# Commit 2: Make durable state explicit without persisting runtime playback

git add Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/SnapshotMigrator.swift \
  Packages/TeleprompterCore/Tests/TeleprompterCoreTests/SnapshotMigratorTests.swift
# Commit 3: Refuse unsafe snapshots without guessing at user data

git add PrivatePresenterApp/Interfaces/SnapshotFileSystem.swift \
  PrivatePresenterApp/Interfaces/SnapshotScheduling.swift \
  PrivatePresenterApp/Services/SnapshotStore.swift \
  PrivatePresenterAppTests/SnapshotStoreTests.swift
# Commit 4: Preserve the last good local script across interrupted saves

git add -A -- PrivatePresenterApp/App PrivatePresenterApp/Controller \
  PrivatePresenterApp/Overlay/OverlayPanelController.swift \
  PrivatePresenterApp/Privacy PrivatePresenterApp/Services/DiagnosticHotKeyService.swift \
  PrivatePresenterAppTests/AppModelTests.swift \
  PrivatePresenterAppTests/OverlayPanelControllerTests.swift
# Commit 5: Route script and session commands through one state owner

git add Scripts/validate_project_structure.py HANDOFF.md IMPLEMENTATION_PLAN.md \
  docs/plans/2026-07-12-milestone-1-core-state-durability.md
# Commit 6: Make M1 source and privacy invariants auditable
```

Run `git diff --cached --check` and the command evidence relevant to each group
before its commit, and verify `git status --short` is empty after the sixth.
Do not commit generated project files, `.omx` state, or protected artifacts.

Historical 2026-07-11 WSL result record (retained for provenance; superseded where
it describes Git/commit state):

- Date/time: `2026-07-11` (Asia/Seoul)
- `./Scripts/verify-wsl.sh`: exit `0`; source/static verification passed and
  printed the explicit macOS/physical-test deferral.
- `bash -n Scripts/*.sh`: exit `0`.
- `python3 Scripts/validate_project_structure.py`: exit `0`;
  `Project structure validation passed (Milestone 0 source).`
- `git diff --check`: exit `0` (tracked diff); an additional recursive
  trailing-whitespace scan over all new source/docs returned no findings.
- XcodeGen pin: exit `0`; `.xcodegen-version` is exactly `2.45.4`.
- generated-project ignore/untracked checks: exit `0`; the generated project
  path is ignored and no project file is tracked.
- required-file checks: exit `0` through the structure validator.
- source-artifact checksums: exit `0`; `PRD.md`, `design/concept.html`,
  `design/teleprompter-concept.png`, and the reference PNG each printed `OK`.
- `Scripts/verify-no-network.sh`: exit `0`; no prohibited product network,
  web/JavaScript runtime, telemetry, automation, event-tap, or global-monitor
  surface was found.
- `git remote -v`: was empty during that historical run; `origin` now intentionally
  points to `https://github.com/thetomtimus/teleprompty.git`.
- `git status --short`: intentional M0 diff (`.gitignore` modified; M0 source,
  tests, scripts, docs, and configuration untracked). Ignored `.omx` runtime
  state is not part of the delivery.
- Required named test inventory: `27/27`; `45` test methods total (`44` unique
  names), including additional fail-closed and harness regressions.

Final changed-files-only cleanup removed duplicate AppKit resize geometry in
favor of `PanelFramePolicy.resizedFrame`; the complete WSL/static gate passed
again afterward. Final role reviews: code reviewer **APPROVE**, verifier
**PASS**, architect **APPROVE**, each explicitly limited to source/static
evidence available in WSL.

A green record here proves source shape and prohibited-surface policy only. It
does **not** prove Swift compilation, Xcode project generation, AppKit behavior,
full-screen overlay compatibility, focus retention, click-through behavior,
selected-screen privacy, opacity, or the Keynote/projector gate.

## Exact macOS bootstrap, build, and test commands

Resume from the same local commit on a real Mac with Xcode 16.0 or newer and
Swift 6.0. Run from the repository root:

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

All commands in this section remain pending; none passed in WSL. Run the M1
targeted tests in plan order before accepting the full gate:

```bash
swift test --package-path Packages/TeleprompterCore --filter CoreStateModelTests
swift test --package-path Packages/TeleprompterCore
swift test --package-path Packages/TeleprompterCore --filter SnapshotMigratorTests
swift test --package-path Packages/TeleprompterCore

xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests

xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests

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

After fixes and full reruns, require fresh code-reviewer **APPROVE**, verifier
**PASS with independent command evidence**, and architect **APPROVE**. Critical
or high findings must be fixed and all affected gates rerun before commits or
push safety may be evaluated.

Run the Milestone 0 targeted gates as well:

```bash
swift test --package-path Packages/TeleprompterCore --filter DisplayTopologyEvaluatorTests
swift test --package-path Packages/TeleprompterCore --filter PanelFramePolicyTests

xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests

xcodebuild test \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests

xcodebuild \
  -project PrivatePresenter.xcodeproj \
  -scheme PrivatePresenter \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Record the Mac model, macOS build, Xcode, Swift, XcodeGen, and test counts/exits
here after the run. Do not backfill passing results from WSL or source review.

### DEBUG proof controls

- `.statusBar` was the Debug level used by the guided physical run. The committed
  result did not complete the required `.floating` versus `.statusBar` comparison,
  so no lowest passing level is approved.
- To retest the lower bounded level, run the Debug executable with
  `PRIVATE_PRESENTER_PROOF_LEVEL=floating`:

  ```bash
  PRIVATE_PRESENTER_PROOF_LEVEL=floating \
    ".build/DerivedData/Build/Products/Debug/Private Presenter.app/Contents/MacOS/Private Presenter"
  ```

- The DEBUG-only diagnostic chord is **Control-Option-H**. Registration status,
  the immutable initial configuration, and the latest frontmost PID/bundle plus
  panel key/main state are visible in the controller.
- The unlocked overlay has a drag header and eight edge/corner resize zones;
  every update is clamped before `setFrame`, with `constrainFrameRect` as a
  second defense.
- The fixed `Private M0 proof content` line is a harmless shield fixture, not a
  script editor. It must disappear behind the generic shield in hostile
  recovery step 14. M0 deliberately has no status item/menu, so record that no
  such private-text surface exists rather than inventing one.
- For hostile stale-frame step 14, seed a projector-coordinate controller frame
  in DEBUG, then verify startup ignores it and opens shielded on the safe
  candidate. Substitute coordinates from the recorded display arrangement:

  ```bash
  PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME='1440,100,620,360' \
    ".build/DerivedData/Build/Products/Debug/Private Presenter.app/Contents/MacOS/Private Presenter"
  ```

## Exact physical overlay proof

Open `docs/validation/overlay-proof-template.md` and perform all 15 steps on a
real Mac running macOS 14 or later, with a current Keynote and a real second
display/projector in extended mode:

1. Record the Mac, OS build, Keynote, displays, topology, separate-Spaces
   setting, and selected screen.
2. Put the Keynote audience slideshow on the external display and full-screen
   Presenter Display on the Mac.
3. Show the already-created panel after Keynote is full-screen and prove it
   joins that Space without ending full screen.
4. Capture both physical displays and prove no teleprompter pixel appears on
   the audience display.
5. Lock the panel; compare frontmost PID/bundle ID and key window before/after,
   proving Keynote stays frontmost and the panel never becomes key/main.
6. Prove click-through while mouse, ordinary Space/arrows, and a presentation
   remote still operate Keynote.
7. Hide/show with the diagnostic chord while Keynote remains active.
8. Enter/leave full screen and switch Spaces; prove recovery on the selected
   screen.
9. Disconnect then reconnect the external display; prove pause/hide occurs and
   recovery remains hidden/paused until confirmation.
10. Enable mirroring; prove pause/hide/block and the exact controller warning.
11. Test `.floating` first and `.statusBar` only if needed; retain the lowest
    level that passes every case.
12. Put the rounded surface over bright content and prove its entire interior
    is opaque.
13. Drag/resize toward every edge/corner and an adjacent display; prove no
    intermediate panel pixel crosses the selected-screen boundary.
14. Cold-launch with a controller frame saved on the projector, then enable
    mirroring with visible script and disconnect the private display; prove
    shield-before-warning/reposition, persistent shielding after recovery, and
    no script/title in status/menu text.
15. Only after the actual run, save dated/tester/focus/window/media evidence to
    `docs/validation/overlay-proof-result.md`.

If both `.floating` and `.statusBar` fail, do not try `.screenSaver`, a private
API, or a focus-stealing window. Record the blocker and reassess feasibility.

## Privacy callback timing limitation

macOS controls when mirroring pixels physically change. Private Presenter
cannot guarantee that zero mirrored frames occur before the system delivers a
display-reconfiguration callback. The required best-effort defense is to react
to the pre-change callback immediately and order effects fail closed:

1. pause scrolling;
2. hide the overlay;
3. shield the controller;
4. invalidate pending shows;
5. query the new topology;
6. evaluate privacy;
7. move windows while shielded only when a confirmed safe screen exists; then
8. request confirmation or publish the safe state.

The app must never auto-resume or auto-reveal after recovery. This limitation
must remain visible in future handoffs and must not be upgraded into a stronger
privacy claim without physical evidence from macOS.

## Source-of-truth and prohibited-surface audit

The following artifacts must retain the plan-recorded SHA-256 values:

```text
3980ec241d38901ef434b93afa3935ce5b8c3d1a14849ae2417ec6a940138f3d  PRD.md
b3c0e19bbef6285ece0fffa045032a806ccf915b8bb8415184e74f6556af2a2a  design/concept.html
d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e  design/teleprompter-concept.png
352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92  references/teleprompter-ui-reference.png
e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da  docs/validation/overlay-proof-result.md
```

Milestone 0 must retain a native-only runtime with no Electron, WebView,
JavaScript runtime, network surface, telemetry, accounts, cloud, AI,
Accessibility event tap, `CGEventTap`, or global `NSEvent` monitor fallback.
The generated `PrivatePresenter.xcodeproj` remains ignored and uncommitted.

## Guarded next slice and stop rule

M1 is accepted on Tom's reported Mac verification plus independent WSL/static
checks and source-level OMX review. The six implementation commits are followed
by a documentation closeout and may be pushed normally after the final origin
safety check.

The next implementation slice is the dedicated M0 stabilization slice for
focus/full-screen activation, unlock/drag/resize testability, mirroring, opacity,
boundary containment, bounded level comparison, hostile recovery, Space
switching, complete environment evidence, and physical audience isolation. It
must preserve the DEBUG proof harness and rerun the focused physical matrix.
Only a new complete physical run may change the historical `BLOCKED` result.

Stop before M2/editor/scrolling/product-hotkey/menu/visual-polish work. M2 remains
blocked until the stabilization fixes and focused physical rerun pass.
