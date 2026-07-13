# Private Presenter — Milestone 0 Phase A Stabilization Handoff

Status: **SOURCE IMPLEMENTATION ON WSL; REAL-MAC PHASE A DIAGNOSIS NOT RUN**
Planning/baseline commit: `45fc72cea2365952895310db4bd3932fbd592f67`
Historical implementation ancestor: `940e1821f36c4125b0f81f623a6d24a015c22dcc`
Branch/origin: `main` / `https://github.com/thetomtimus/teleprompty.git`

## Scope and mandatory stop

This handoff contains **Phase A only** from
`docs/plans/2026-07-12-milestone-0-stabilization.md`: M1 regression locks,
content-neutral causal evidence, deterministic application/workspace/window/
controller observation, bounded DEBUG proof configuration, local provenance
verification, and a practical exact 24-cell Mac diagnosis runner.

It deliberately does **not** implement Phase B, Control-Option-L, a controller
lifecycle split, a focus/full-screen fix, topology changes, an activation-policy
change, a Carbon-target change, drag/resize or opacity behavior changes, or any
M2/editor/scrolling/product UI. Control-Option-H and the current combined
`showShielded` → `showWindow` controller lifecycle are preserved and observed.

**Stop after the 24 valid diagnostic cells and Tom's causal note. Phase B and M2
remain blocked until that real-Mac evidence selects a permitted cause.**

## Phase A source inventory

Production Phase A surfaces:

- `PrivatePresenterApp/Services/DiagnosticEvidenceRecorder.swift`
- `PrivatePresenterApp/Services/DiagnosticObserverSet.swift`
- `PrivatePresenterApp/Services/WorkspaceFocusProbe.swift`
- `PrivatePresenterApp/Services/DiagnosticHotKeyService.swift`
- `PrivatePresenterApp/App/AppRuntime.swift`
- `PrivatePresenterApp/App/AppModel.swift`
- `PrivatePresenterApp/App/DependencyContainer.swift`
- `PrivatePresenterApp/App/PrivatePresenterApp.swift`
- `PrivatePresenterApp/Controller/ControllerWindowController.swift`
- `PrivatePresenterApp/Overlay/TeleprompterPanel.swift`
- `PrivatePresenterApp/Overlay/OverlayPanelController.swift`

Regression/evidence tests and tooling:

- `Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift`
- `PrivatePresenterAppTests/AppModelTests.swift`
- `PrivatePresenterAppTests/DiagnosticTestSupport.swift`
- `PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests.swift`
- `PrivatePresenterAppTests/DiagnosticObserverLifecycleTests.swift`
- `PrivatePresenterAppTests/DiagnosticHotKeyServiceTests.swift`
- `PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift`
- `PrivatePresenterAppTests/OverlayPanelControllerTests.swift`
- `Scripts/verify-m0-proof-provenance.sh`
- `Scripts/test-verify-m0-proof-provenance.sh`
- `Scripts/run-m0-phase-a-diagnosis.sh`
- `Scripts/validate_project_structure.py`
- `Scripts/verify-no-network.sh`
- `Scripts/verify-wsl.sh`
- `Scripts/verify-macos.sh`
- `docs/validation/overlay-proof-template.md`
- `HANDOFF.md`

No `project.yml`, `Package.swift`, target, entitlement, resource, dependency, or
build-phase change is required; source/test discovery is recursive.

## Tests present

The exact six M0S.0 locks are in the plan-mandated existing files:

- canonical PersistedSnapshot schema v1 after diagnostic lock state;
- hidden/paused/shielded restore until current privacy confirmation;
- restore → topology/privacy → diagnostic-control-last startup order;
- exactly one runtime AppModel;
- controller/hotkey services share that model identity; and
- diagnostic/session/provenance state never enters snapshot v1 bytes.

Every exact M0S.1 recorder test name and M0S.2 lifecycle/configuration test name
from plan sections M0S.1–M0S.2 is present. They cover typed envelope chronology,
fixed-capacity drop-newest ingress, nonblocking action paths, permanent first-
fault/overflow invalidation, content-neutral configuration errors, same-directory
pending publication, terminal completion and synchronize/close/rename order,
application/workspace/window observers, generation-cancelled timed samples,
both historical controller cohorts without manufacturing state, H-only direct
model dispatch, bounded levels/orderings and deterministic selection, source-
default retention, and prohibited Phase A behavior.

`Scripts/test-verify-m0-proof-provenance.sh` supplies generated local fixtures for
matching provenance; dirty tree; commit/executable/build-log mismatches; missing
build log; wrong/missing/duplicate build-log clean headers; smoke/physical
executable mismatch; cell config/repetition/cohort mismatch; overflow/permanent
fault; pending sibling; missing/duplicate terminal completion; and the exact
24-cell Cartesian product.

## Evidence recorder and proof acceptance

DEBUG evidence is UTF-8 JSON Lines rooted under the resolved user Application
Support directory:

```text
Private Presenter/Validation/<session-id>/overlay-diagnostics.txt
```

Ingress is fixed at 4,096 envelopes in production (smaller in saturation tests),
drops newest, never waits for the writer/file system, uses a monotonic sequence,
and permanently latches the first invalidation. `EVIDENCE_QUEUE_OVERFLOW`
remains invalid after drain, successful finalization, or a later error and emits
one fixed fault record. Content paths and payloads never contain script text,
title, anchor context, arbitrary error text, or raw malformed environment values.

The writer exclusively creates a unique sibling `.pending`, appends there,
drains each correlation through next-run-loop, +100 ms, +500 ms and
`correlationWindowClosed`, then on orderly quit appends `sessionEnded` and the
single terminal `sessionCompletion`, synchronizes, closes, and atomically renames.
The final path is the commit point. A pending file, absent final file, duplicate/
nonterminal completion, invalid terminal status, cohort/config mismatch, any
fixed fault, or overflow is not acceptable proof.

Proof environment values are DEBUG-only and bounded:

```text
PRIVATE_PRESENTER_PROOF_LEVEL=floating|statusBar
PRIVATE_PRESENTER_ORDERING=front|frontRegardless
PRIVATE_PRESENTER_EVIDENCE_COMMIT=<40 lowercase hex>
PRIVATE_PRESENTER_CONTROLLER_COHORT=visibleDesktopSpace|orderedOut
PRIVATE_PRESENTER_REPETITION=1|2|3
PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256=<64 lowercase hex>
PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG=<resolved absolute path>
PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256=<64 lowercase hex>
PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST=<resolved absolute path>
```

The shell verifier independently requires a clean current HEAD, an exact six-key
manifest, matching executable/build-log hashes, exactly one matching
`commit=<HEAD>` build-log header, exactly one empty `status_porcelain=` build-log
header, and (when evidence is supplied) exact cell fields, observed/declared
cohort equality, unique terminal completion, no pending sibling, and no permanent
fault. This is local provenance, not signing or attestation.

## WSL/source-static gate

Run from repository root:

```bash
bash -n Scripts/*.sh
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/run-m0-phase-a-diagnosis.sh --list | tee /tmp/m0-phase-a-cells.tsv
test "$(wc -l < /tmp/m0-phase-a-cells.tsv | tr -d ' ')" = 24
python3 Scripts/validate_project_structure.py
git diff --check
test "$(cat .xcodegen-version)" = 2.45.4
git check-ignore -q PrivatePresenter.xcodeproj/project.pbxproj
! git ls-files --error-unmatch PrivatePresenter.xcodeproj/project.pbxproj >/dev/null 2>&1
sha256sum -c docs/validation/source-artifact-checksums.sha256
./Scripts/verify-no-network.sh
./Scripts/verify-wsl.sh
```

WSL may establish file/test inventory, shell/Python behavior, protected hashes,
prohibited-surface absence, exact origin configuration, and patch hygiene only.
It cannot establish Swift 6 compilation/concurrency, Xcode/AppKit behavior,
Carbon delivery, APFS semantics, clean Mac proof-build provenance, Keynote focus/
full-screen/Spaces behavior, window ordering/visibility, or physical audience
privacy. Never report this gate as a Swift/AppKit/Keynote PASS.

## Required real-Mac automated gate

On a real arm64 Mac with Xcode 16+ and XcodeGen 2.45.4:

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
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/SnapshotStoreTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticHotKeyServiceTests \
  -only-testing:PrivatePresenterAppTests/DiagnosticObserverLifecycleTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
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
./Scripts/verify-macos.sh
```

Capture command exits/test counts and the Mac model/chip, macOS build, Xcode,
Swift, XcodeGen, and Keynote versions. Fix every compile/test/analyze/format issue
before building proof evidence. Source review approval cannot replace this gate.

## Clean proof build and exact 24-cell Phase A command

Use plan section 10.1's fresh clean-build recipe without modification. It writes
`commit=<HEAD>` and an empty `status_porcelain=` header into `proof-build.log`,
copies the Debug app into the commit-specific Application Support proof root,
hashes the copied executable and build log, writes the exact manifest, and runs:

```bash
./Scripts/verify-m0-proof-provenance.sh "$MANIFEST"
```

Do not rebuild or alter HEAD/defaults between proof build and diagnosis. Then:

```bash
EVIDENCE_ROOT="$HOME/Library/Application Support/Private Presenter/Validation"
./Scripts/run-m0-phase-a-diagnosis.sh "$MANIFEST" "$EVIDENCE_ROOT"
```

The live runner is macOS-only and interactive. `--list` is WSL-safe but runs no
cell. Live mode checks provenance before and after every launch, refuses a prior
Private Presenter process or pending evidence, binds every environment field,
requires normal exit, discovers exactly one new finalized file, verifies it, and
stops on the first mismatch. It finishes only after 24 unique files for:

```text
2 levels × 2 orderings × 2 controller cohorts × 3 repetitions = 24
```

For each cold cell: prepare the declared visible-desktop-Space or explicitly
ordered-out controller state; enter fresh Keynote full-screen Presenter Display;
capture pre-H state; press H for first show; retain immediate, next-main-loop,
+100 ms and +500 ms focus/window state; repeat H hide/show; explicitly switch a
**macOS Space** and return; wait for `correlationWindowClosed`; exit Keynote full
screen; only then activate Private Presenter solely to Cmd-Q. That activation
must be tagged `postCorrelationQuit`. The ordered-out quit path must not present
or order the controller. L, drag, resize, topology/opacity changes, and any focus
fix are intentionally absent.

## Invalidation and stop rules

Rerun a cell after correcting the fixed-code condition if any of these occur:

- dirty/mismatched HEAD, malformed/duplicate manifest, executable or build-log
  hash mismatch, bad/missing/duplicate build-log commit/clean header;
- configuration, cohort, repetition, manifest-path, executable, or log mismatch;
- declared and observed controller cohorts differ or the controller is missing;
- recorder fault, any permanent invalid status, especially queue overflow;
- action correlation lacks next/+100/+500/closure samples;
- missing final file, any pending sibling, duplicate or nonterminal completion;
- process is killed rather than completing the orderly termination path; or
- the evidence path cannot be resolved.

A provenance-valid cell still fails behaviorally if Private Presenter becomes
active/frontmost, Keynote exits full screen, panel becomes key/main or misses
required visibility, or controller presentation/order-on count increases. Do
not infer a fix from source tests or timing. Never try `.screenSaver`, raw/private
levels, native `.resizable`, focus return/reactivation, Accessibility, event taps,
or a global monitor.

## Causal decision output required from Tom

Return one retained Phase A note with:

1. exact instrumented clean commit and executable/build-log/manifest paths and
   SHA-256 values;
2. 24 rows: level, ordering, declared/observed cohort, repetition, proof validity,
   focus/full-screen outcome, panel visible/key/main chronology, controller
   `showShielded`/frame/`showWindow`/show-count/order-on chronology, and local
   evidence/media paths;
3. whether activation preceded or followed panel ordering in every failing row;
4. whether any controller presentation/order-on event occurred in either cohort;
5. the matching root-cause hypothesis/decision-table branch from plan section 5,
   or `NOT ISOLATED`;
6. the one permitted regression/fix branch proposed, or
   `NONE — KEEP M0/M2 BLOCKED`; and
7. explicit confirmation that no Phase B change was applied during diagnosis.

Only this valid real-Mac result may authorize the separate Phase B plan. If the
cause is not isolated to an allowed public path, keep M0/M2 blocked.

## Protected truth and hashes

The source checksum manifest must continue to report:

```text
3980ec241d38901ef434b93afa3935ce5b8c3d1a14849ae2417ec6a940138f3d  PRD.md
b3c0e19bbef6285ece0fffa045032a806ccf915b8bb8415184e74f6556af2a2a  design/concept.html
d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e  design/teleprompter-concept.png
352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92  references/teleprompter-ui-reference.png
```

`docs/validation/overlay-proof-result.md` retains its exact historical 14,486-
byte prefix at SHA-256
`e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da`.
Code-only Phase A must not edit it. A future actual run may append a new current-
decision ledger only; it never rewrites the historical BLOCKED record.

PersistedSnapshot remains schema v1; SnapshotStore/SnapshotMigrator, hidden-
paused restore/privacy ordering, and exactly one AppModel remain protected.

## Git and review closeout

Do not push this WSL-authored Phase A source. After the Mac automated gate and
source fixes, create small Lore commits on the exact parent, rerun the full gate,
then require independent source-level **code-reviewer APPROVE → verifier PASS
with command evidence → architect APPROVE**. Critical/high findings restart the
affected verification. Package/bundle only after parent-side verification.

Before any later normal push consideration:

```bash
test "$(git branch --show-current)" = main
test -z "$(git status --porcelain)"
test "$(git remote get-url origin)" = 'https://github.com/thetomtimus/teleprompty.git'
test "$(git remote get-url --push origin)" = 'https://github.com/thetomtimus/teleprompty.git'
git fetch --prune origin
# require zero behind; never force-push
```

Phase A source completion is not M0 PASS. The historical result remains BLOCKED,
and Phase B/M2 remain blocked pending Tom's valid real-Mac 24-cell evidence and
causal decision.
