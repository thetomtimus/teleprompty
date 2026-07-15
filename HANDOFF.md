# Private Presenter — Milestone 2 Closeout and Milestone 3 Handoff

Status: **M2 COMPLETED BY OWNER-APPROVED REAL-MAC PHYSICAL PASS; M3 AUTHORIZED**

## M2 source and evidence

- M2 implementation lineage ends at `87a8e4f` plus the verified Mac-toolchain
  reconciliation in `38521e1`.
- The temporary GitHub packaging workflow is disabled and is not part of this
  clean M2 source branch or intended `main` history.
- GitHub run `29392288263` completed the macOS compile, tests, analyze, Release,
  format, no-network, signing, and packaging gates on the code-equivalent test
  branch. Its Xcode 16.4/macOS 15.5 package later crashed on Tom's macOS 26.5.2
  machine after display confirmation.
- Tom rebuilt the application with Xcode 26.6/macOS 26.5.2 and completed the
  package-level Keynote/private-display physical smoke on 2026-07-15.
- Owner-reported tested executable SHA-256:
  `93016a94d19ad3ba69f240715dfb63edfab06d27b9a099c50c9e2452028160c6`.
- Canonical owner report:
  `docs/validation/m2-controller-editor-display-safety-result.md`.
- Historical M0 evidence and its prior owner transition remain unchanged.

The physical report supplied `3526b4fa22f94c63c0237d55071f0d464a126e3a`
as the source identity. That commit is the pre-M2 baseline, so it does not
independently reconstruct the rebuilt executable. Tom explicitly accepted the
physical result as M2 completion and authorized M3. Exact rebuilt-source-to-
executable provenance remains visible as release evidence rather than being
represented as completed.

## Physical behavior accepted for M2

The real-Mac run confirmed the selected private display, visible bounded
`.statusBar` overlay, clean audience display, permanent non-key/non-main panel,
Keynote focus and ordinary slide input, click-through while locked, hide/show,
unlock/relock, and final locked state. The app remained on the built-in private
display while the LG ULTRAGEAR carried the audience presentation.

## Remaining toolchain follow-up

Under Xcode 26.6, the combined app-host `xcodebuild test` worker failed to
materialize and was interrupted without a source-test failure. The standalone
Debug app, Release arm64 app, Foundation suite (42 tests), analyze, format,
structure/provenance, and prohibited-surface checks passed. Treat app-host test
materialization and exact rebuilt-binary provenance as hardening/release follow-
ups, not as completed evidence and not as a reopened M2 product gate.

## M3 boundary

M3 is the first usable rehearsal-scrolling alpha. Implement only:

1. a pure elapsed-time scroll engine independent of display refresh rate;
2. UTF-16-safe reading-anchor mapping that preserves position across edits;
3. a clipped, nonselectable reader viewport with a stable active band and no
   text mutation during scroll ticks; and
4. a display-link session controller that does not publish SwiftUI state every
   frame and stops cleanly when paused, hidden, ended, or stale.

Preserve one `@MainActor` AppModel, one panel, separate editor/reader TextKit 2
stacks, current display privacy, `.statusBar + frontRegardless`, permanent non-
key/non-main behavior, containment, opacity, durability, menu/content privacy,
and the M2 incremental edit/resync contract.

Do not pull M4 product hotkeys, Focus Mode, menu-bar control, global event
monitoring, Accessibility permission, focus-return hacks, M5 hardening, or M6
visual polish into M3.

## Environment-separated verification

WSL may run structure/static/prohibited-surface checks and prepare Foundation-
only source/tests, but it cannot claim Swift/AppKit/TextKit/display-link success.
The M3 Mac handoff must run the pinned bootstrap, Foundation and app tests,
analyze, Release, format/no-network checks, then a focused real-Mac scrolling
smoke using the current Xcode/macOS toolchain.
