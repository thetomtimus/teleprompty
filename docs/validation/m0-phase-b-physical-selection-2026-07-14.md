# M0 Phase B Physical Configuration Selection — 2026-07-14

## Bound run

- Commit: `88dbfb9be1e90815d499235ece15d410ed561a5c`
- Proof executable SHA-256:
  `a67c2174b3ba01022f37c758a4cd508eac3f224fdb91c9b58ff04ecf8523986a`
- Proof build-log SHA-256:
  `2ac15c19641298b6b3cd08c1dd6bad1914ea3c309c48d8894e92d3610ea8760c`
- Built-in/private display: 1512 × 982 points
- External audience display: AAA, 1920 × 1080
- Topology: extended, external origin `(1512, 0)`, mirroring off
- Keynote: full-screen Presenter Display on the built-in display and audience
  slideshow on the external display

The accepted manifest format at this exploratory commit hashed Xcode's stable
Debug launcher while the actual code lived in a sibling debug dylib. The visual
observations remain configuration-selection evidence, but this run is not final
M0 proof. The downstream gate restarts after disabling that indirection.

## Candidate observations

### `.floating + frontRegardless`

The H command was received and the panel reported visible at `(226, 57)` with a
size of `1059 × 301`, while Keynote remained frontmost. The built-in screenshot
showed no overlay because the panel was visually behind Presenter Display. The
external screenshot correctly showed only the audience slide.

Result: **FAIL — required private-display visibility absent.**

Local evidence:

- `/tmp/private-presenter-phase-b-captures/cell1-h1-built-in.png`
- `/tmp/private-presenter-phase-b-captures/cell1-h1-external.png`
- `~/Library/Application Support/Private Presenter/Quarantine/phase-b-failed-floating-visibility-2026-07-14/d4af590a-4281-4455-b6df-628217b0ddee/overlay-diagnostics.txt`

### `.statusBar + frontRegardless`

The overlay was visibly above Presenter Display on the built-in/private screen
and absent from the external audience screenshot. Keynote remained frontmost
through the initial H and both L correlations. The first unlocked header drag
then made Private Presenter frontmost, exposing a separate non-key interaction
defect in the candidate commit.

Result: **VISIBLE CANDIDATE; FAIL — unlocked drag activated the app.**

Local evidence:

- `/tmp/private-presenter-phase-b-captures/statusbar-h1-built-in.png`
- `/tmp/private-presenter-phase-b-captures/statusbar-h1-external.png`
- `~/Library/Application Support/Private Presenter/Quarantine/phase-b-failed-statusbar-drag-focus-2026-07-14/f546abd9-5ddd-4050-ab68-b732f14e4861/overlay-diagnostics.txt`

## Decision

Retain `.statusBar + frontRegardless` as the lowest physically visible bounded
configuration. Keep the existing public AppKit/Carbon paths. Make the overlay
permanently non-key while preserving unlocked custom pointer gestures, add the
regression, and restart the entire Mac automated and exact-binary physical gate
on the resulting clean commit.
