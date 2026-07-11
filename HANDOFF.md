# Private Presenter — Milestone 0 Handoff

## Status and boundary

- Branch: `main`
- Planning baseline supplied for this run: `a58afbd`
- Delivery: local-only; no remote, push, publication, signing, notarization, or
  distribution
- Current milestone: **Milestone 0 only (M0.1–M0.6)**
- WSL status: source/static validation is the only evidence available here
- macOS Swift/AppKit status: **PENDING**
- Real Keynote + second-display/projector proof: **PENDING**
- Milestone 1: **NOT STARTED — HARD STOP**

This handoff must not be read as a claim that the app compiled, its tests ran,
or its overlay/privacy behavior passed on macOS. WSL cannot establish any of
those facts. `docs/validation/overlay-proof-result.md` must not exist until a
human performs the real physical gate and records the result.

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
  `SystemDisplayService.swift`, `Privacy/*`, `DiagnosticHarnessModel.swift`,
  both window controllers, and `AppModelTests.swift` /
  `OverlayPanelControllerTests.swift`.
- M0.6 DEBUG proof harness, immutable configuration snapshot, minimal
  select/show/lock/hide controls, and physical-proof template:
  `WorkspaceFocusProbe.swift`, `DiagnosticHotKeyService.swift`, controller
  proof UI, `docs/validation/overlay-proof-template.md`, and this handoff.
- Commit status: source is an intentional uncommitted M0 diff because this WSL
  sandbox exposes `.git` read-only. Exact parent-closeout commit commands are
  included below.
- Deliberately absent: Milestone 1+ state/persistence/editor/scrolling/hotkey/
  product-polish work and any fake `overlay-proof-result.md`.

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
git remote -v
git status --short
```

Fresh WSL result record:

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
- `git remote -v`: empty; no remote exists.
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

- `.floating` is the default bounded proof level.
- To test the only alternate bounded level, run the Debug executable with
  `PRIVATE_PRESENTER_PROOF_LEVEL=statusBar`:

  ```bash
  PRIVATE_PRESENTER_PROOF_LEVEL=statusBar \
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
```

Milestone 0 must retain a native-only runtime with no Electron, WebView,
JavaScript runtime, network surface, telemetry, accounts, cloud, AI,
Accessibility event tap, `CGEventTap`, or global `NSEvent` monitor fallback.
The generated `PrivatePresenter.xcodeproj` remains ignored and uncommitted.

## Hard stop and next command

Do **not** begin Milestone 1 or visual product polish in this WSL run. The next
maintainer's first command on macOS is:

```bash
./Scripts/bootstrap-macos.sh
```

Then run the automated macOS commands above and the complete real-hardware
proof. Milestone 1 remains blocked until
`docs/validation/overlay-proof-result.md` contains a passing Keynote
full-screen Presenter Display plus extended second-display record.

## Parent closeout commit (Git metadata is read-only in this WSL sandbox)

After reviewing the intentional diff in a checkout where `.git` is writable,
create the single plan-prescribed logical M0 commit locally:

```bash
git add .gitignore .xcodegen-version Config HANDOFF.md Makefile \
  Packages PrivatePresenterApp PrivatePresenterAppTests PrivatePresenterUITests \
  Scripts docs project.yml
git commit -F - <<'EOF'
Make the riskiest macOS behavior reproducible

Milestone 0 establishes the native project shell, fail-closed display and frame
policies, the bounded nonactivating panel/privacy proof harness, and honest
environment-separated validation before any product expansion.

Constraint: WSL cannot compile AppKit or satisfy the real Keynote/projector gate
Rejected: Fake overlay result or later-milestone polish | violates the physical hard gate
Confidence: medium
Scope-risk: moderate
Directive: Do not begin M1 until overlay-proof-result.md records a passing real-hardware gate
Tested: ./Scripts/verify-wsl.sh; structure, policy, checksum, ignore, and no-remote checks
Not-tested: XcodeGen generation, Swift/Xcode tests, AppKit behavior, and real Keynote/projector proof
EOF
git status --short
```

Do not add a remote, push, sign, notarize, publish, or distribute during closeout.
