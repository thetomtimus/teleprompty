# Milestone 0 Phase A Causal Decision — 2026-07-14

## Decision

The 2026-07-12 first-show interruption did not reproduce in the exact 24-cell
Phase A matrix. All four bounded level/ordering combinations passed three cold
repetitions in both controller cohorts. No H-correlated application activation,
controller presentation, controller order-on transition, panel key transition,
or panel main transition occurred.

Section 5 branch: **failure does not reproduce**. The activation cause is
therefore **NOT ISOLATED**, and no Carbon-target, activation-policy, focus-return,
or other causal behavior change is authorized by this trace.

Phase B may proceed only with the plan-mandated bounded stabilization
invariants: separate controller placement from presentation, keep H/L routed
directly through the one AppModel, add the L/interaction/topology/opacity and
hostile-recovery proof surfaces, and rerun the complete gate. The controller
split is an invariant, not a claim that the combined lifecycle caused the
historical interruption.

## Exact proof identity

- Instrumented commit: `911f62830be96275d2aed9aacd631c75800b6a87`
- Proof executable: `/Users/thomas/Library/Application Support/Private Presenter/Validation/Builds/911f62830be96275d2aed9aacd631c75800b6a87/Private Presenter.app/Contents/MacOS/Private Presenter`
- Executable SHA-256: `e8c5843354ad6a85a6f8356868fd1209742cffd9423e49d4f480974019d418fb`
- Build log: `/Users/thomas/Library/Application Support/Private Presenter/Validation/Builds/911f62830be96275d2aed9aacd631c75800b6a87/proof-build.log`
- Build-log SHA-256: `92c635fb502fbb02b716997328edc15e9a87ad93a1ebb5d7e9166335bfafecf5`
- Manifest: `/Users/thomas/Library/Application Support/Private Presenter/Validation/Builds/911f62830be96275d2aed9aacd631c75800b6a87/proof-build-manifest.txt`
- Evidence root: `/Users/thomas/Library/Application Support/Private Presenter/Validation`
- Display topology: built-in Retina display plus `AAA` 1920×1080 external
  display, both online, mirroring off
- Presentation: Keynote 14.5 Presenter Display on the built-in/private screen;
  audience slide on `AAA`

## Outcome legend

- `F`: all 15 focus samples in the cell retained Keynote as frontmost, Private
  Presenter remained inactive, and the automated presentation state remained
  playing through H/H/H and the macOS Space round-trip.
- `A`: no activation occurred from first Carbon receipt through the final
  `correlationWindowClosed`; the panel ordered without activation. The only
  later activation was the explicit normal-quit activation, tagged
  `postCorrelationQuit` after the final correlation.
- `P`: panel show/hide/show completed, every required show sample was visible,
  and the panel was never key or main.
- `CV`: no H-correlated controller operation or order-on transition. The
  visible controller remained non-key/non-main during H. Its later quit-only
  key/main/order events were tagged `postCorrelationQuit`.
- `CO`: no H-correlated controller operation or order-on transition. The
  explicitly ordered-out controller remained ordered out through H and the
  quit path.

## Exact 24-cell outcome table

| Level | Ordering | Controller cohort | Repetition | Validity | Focus/full-screen | Activation chronology | Panel | Controller | Evidence file under evidence root |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| floating | front | visibleDesktopSpace | 1 | PASS | F | A | P | CV | `07821a0a-b858-48a1-a5e8-4e5d9d6c4dd5/overlay-diagnostics.txt` |
| floating | front | visibleDesktopSpace | 2 | PASS | F | A | P | CV | `553fae19-1fed-4846-934e-150b7d2b98de/overlay-diagnostics.txt` |
| floating | front | visibleDesktopSpace | 3 | PASS | F | A | P | CV | `968b0164-1ecb-4061-8b72-08255f900b85/overlay-diagnostics.txt` |
| floating | front | orderedOut | 1 | PASS | F | A | P | CO | `dac350b2-4ee9-4d2e-ba7f-fcc2090ff5c2/overlay-diagnostics.txt` |
| floating | front | orderedOut | 2 | PASS | F | A | P | CO | `03466b3c-682c-44b7-a608-17d19e7ed58b/overlay-diagnostics.txt` |
| floating | front | orderedOut | 3 | PASS | F | A | P | CO | `dee4a1f6-c58b-49ee-9b2b-780e5c9cac59/overlay-diagnostics.txt` |
| floating | frontRegardless | visibleDesktopSpace | 1 | PASS | F | A | P | CV | `644f7773-50f1-40c4-aa1b-08c2ee778a7d/overlay-diagnostics.txt` |
| floating | frontRegardless | visibleDesktopSpace | 2 | PASS | F | A | P | CV | `c7699b48-4693-4726-a4a7-29b622b6ae6c/overlay-diagnostics.txt` |
| floating | frontRegardless | visibleDesktopSpace | 3 | PASS | F | A | P | CV | `ad8e3bdd-6957-439c-8763-a155778345ab/overlay-diagnostics.txt` |
| floating | frontRegardless | orderedOut | 1 | PASS | F | A | P | CO | `ddbe3e75-2115-4d05-b729-8680b6174141/overlay-diagnostics.txt` |
| floating | frontRegardless | orderedOut | 2 | PASS | F | A | P | CO | `a9d724c2-a4d4-4bbd-ada7-7e3444a74bf9/overlay-diagnostics.txt` |
| floating | frontRegardless | orderedOut | 3 | PASS | F | A | P | CO | `fc7237ea-acaa-4753-8b1a-6b80a2594a55/overlay-diagnostics.txt` |
| statusBar | front | visibleDesktopSpace | 1 | PASS | F | A | P | CV | `54c8b223-4137-4045-b20d-20a16b15611c/overlay-diagnostics.txt` |
| statusBar | front | visibleDesktopSpace | 2 | PASS | F | A | P | CV | `9f11dc18-8b7d-447d-b5aa-b05a1d5785e7/overlay-diagnostics.txt` |
| statusBar | front | visibleDesktopSpace | 3 | PASS | F | A | P | CV | `10f06aa4-ef02-4b4b-9cae-0886d61517f5/overlay-diagnostics.txt` |
| statusBar | front | orderedOut | 1 | PASS | F | A | P | CO | `94cdaea3-a633-460d-82ba-fa5d5b552620/overlay-diagnostics.txt` |
| statusBar | front | orderedOut | 2 | PASS | F | A | P | CO | `6a7721cc-de33-4889-8070-64cd90699517/overlay-diagnostics.txt` |
| statusBar | front | orderedOut | 3 | PASS | F | A | P | CO | `71306a77-d6e3-4b23-9644-a200ea67e5ff/overlay-diagnostics.txt` |
| statusBar | frontRegardless | visibleDesktopSpace | 1 | PASS | F | A | P | CV | `9c5bd023-cc88-43f1-b23e-7d0a9b94d0d1/overlay-diagnostics.txt` |
| statusBar | frontRegardless | visibleDesktopSpace | 2 | PASS | F | A | P | CV | `12515f17-cf98-49b1-b929-fe985bddc64e/overlay-diagnostics.txt` |
| statusBar | frontRegardless | visibleDesktopSpace | 3 | PASS | F | A | P | CV | `2ce8f8fb-12b4-4230-99bf-f35e78ab7123/overlay-diagnostics.txt` |
| statusBar | frontRegardless | orderedOut | 1 | PASS | F | A | P | CO | `27697e81-2893-49da-9d2e-f109921a263f/overlay-diagnostics.txt` |
| statusBar | frontRegardless | orderedOut | 2 | PASS | F | A | P | CO | `cdf75388-7521-4f8e-ac09-a87d41e6ebfa/overlay-diagnostics.txt` |
| statusBar | frontRegardless | orderedOut | 3 | PASS | F | A | P | CO | `a72bd923-d215-4ff2-af81-ac52eff6e09e/overlay-diagnostics.txt` |

## Chronology and section 5 mapping

- Activation did not precede or follow panel ordering in any H correlation; it
  was absent throughout every H correlation window.
- Every cell recorded exactly three panel operations: show, hide, show. Each
  show completed before `focusImmediate`; Keynote remained frontmost and the
  panel remained non-key/non-main at immediate, next-loop, +100 ms, and +500 ms.
- No controller operation occurred between the first Carbon receipt and the
  final correlation close in any cell.
- The existing Phase A combined controller lifecycle did run before H during
  startup/confirmation: each cell recorded three
  `showShielded → frameChanged → showWindow → showShieldedExit` sequences.
- In `orderedOut`, no controller presentation/order-on transition occurred
  after preparation, during H, or during normal quit.
- In `visibleDesktopSpace`, controller key/main/order-on transitions occurred
  only after the explicit post-correlation quit activation and were tagged
  `postCorrelationQuit`.
- All four bounded pairs have an equal safety vector: zero H activation
  transitions, zero H controller presentation/order operations, zero panel
  key/main transitions, and zero missed required visibility samples.
- Under section 10.3, the lowest passing level is `.floating`; because both
  orderings tie, retain the source-default ordering `frontRegardless`. The
  proposed Phase B default pair is therefore `.floating + frontRegardless`.

## Phase boundary confirmation

No Phase B behavior was applied during this diagnosis. The matrix contained no
Control-Option-L registration, controller placement/presentation split,
all-online mirroring implementation, interaction/opacity behavior change,
activation-policy change, Carbon-target change, or focus workaround.
