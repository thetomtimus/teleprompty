# Private Presenter — Milestone 0 Phase B Mac Handoff

Milestone 0 Phase A is complete. Its 24/24 valid diagnostic matrix proposed
`.floating + frontRegardless` as the lowest bounded candidate without adding a
focus workaround, Carbon target change, or activation-policy change. The first
Phase B physical screenshot then eliminated `.floating`: it ordered internally
but remained visually behind Keynote Presenter Display. `.statusBar +
frontRegardless` is therefore the lowest physically visible bounded candidate.

Phase B implements only the stabilization surfaces authorized by that result:

- controller placement is separate from startup presentation;
- Control-Option-H controls visibility and Control-Option-L controls lock state;
- both global chords route typed commands through the one authoritative model;
- all online Core Graphics displays participate in mirroring safety, while only
  NSScreen-backed displays are drawable destinations;
- the header and eight resize zones apply contained frames and export separate
  full, visible, containment, and applied-frame evidence;
- the rounded reading interior has rendered opacity coverage;
- mirroring, disconnect, reconnect, pending-show, and stale-frame recovery fail
  closed without automatically revealing or resuming content; and
- the retained bounded default is `.statusBar + frontRegardless`.

This handoff still stops before every M2 editor, reader, and scrolling surface.
M2 is unlocked only by the complete Mac automation, exact-binary focused smoke,
review sequence, and 15-step real-display PASS defined in the stabilization
plan and proof template.

## Phase A evidence

- Causal decision commit: `6485e33`
- Decision record:
  `docs/validation/m0-phase-a-causal-decision-2026-07-14.md`
- Result: 24/24 valid cells, no reproduced focus theft, no controller
  presentation during H, no Carbon or activation-policy correction selected
- Phase A candidate: `.floating + frontRegardless`
- Phase B physical candidate: `.statusBar + frontRegardless`

Do not overwrite the Phase A evidence or the historical 14,486-byte prefix of
`docs/validation/overlay-proof-result.md`.

## Automated Mac gate

From the repository root:

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

The UI-test shell remains intentionally skipped. It is not a substitute for the
physical gate.

## Exact clean proof build

After automation and reviews pass, commit the Phase B source. Require a clean
tree, then build and copy one proof app exactly as described in section 10.1 of
`docs/plans/2026-07-12-milestone-0-stabilization.md`. Record:

- exact 40-character clean commit;
- proof executable, build log, and manifest paths;
- executable and build-log SHA-256 values; and
- successful `Scripts/verify-m0-proof-provenance.sh` output.

Do not rebuild between focused smoke and the physical gate.

## Focused Phase B smoke

Use the source-default `.statusBar + frontRegardless` configuration. Enter a
fresh Keynote full-screen presentation in extended-display mode, then exercise:

1. H show, H hide, H show;
2. L unlock, header drag, and all eight resize zones;
3. L lock;
4. ordinary Keynote mouse, Space, and arrow input;
5. explicit macOS Space switch and return;
6. controller-visible and controller-ordered-out cohorts;
7. actual mirroring with the exact safety warning and blocked show;
8. external-display disconnect/reconnect with no auto reveal or resume; and
9. stale projector-frame recovery while the controller remains shielded.

Every accepted evidence file must bind the clean commit, source defaults,
cohort, repetition, executable hash, build-log hash, and manifest path; contain
three typed H correlations plus two typed L correlations; close every
correlation window; export applied-frame evidence; end with exactly one valid
`sessionCompletion`; and leave no `.pending` sibling.

Reject the smoke immediately if Private Presenter becomes active/frontmost,
Keynote exits full screen, the panel becomes key/main, the normal controller is
presented, any frame crosses the selected private display, any teleprompter
pixel appears externally, or any permanent recorder/configuration fault occurs.

## Complete physical gate and M2 decision

Run all 15 steps in `docs/validation/overlay-proof-template.md`. The run needs a
current Keynote, a real extended display/projector, mouse/Space/arrows/remote,
physical audience-display observation/photo, actual mirroring, actual
disconnect/reconnect, opacity and containment evidence, and resolved local paths.

Append the current decision to `docs/validation/overlay-proof-result.md`; never
edit its immutable historical prefix. M2 is unlocked only when every row is
PASS on the same clean source-default commit and proof binary, the required
review sequence approves that commit, and no critical/high/privacy issue remains.

If the remote, physical audience observation/photo, or another required physical
checkpoint is unavailable, record `BLOCKED`. A pushed commit, green automation,
or focused smoke alone cannot honestly unlock M2.
