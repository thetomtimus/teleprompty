# Milestone 0 Keynote Overlay and Private-Display Proof Result

> **Overall result: BLOCKED**
>
> This records the guided physical run performed on 2026-07-12. It is not a
> Milestone 0 pass. The run produced useful positive evidence for full-screen
> overlay visibility, Keynote controls, repeated toggling, and fail-closed
> disconnect/reconnect behavior. It also exposed an initial focus/full-screen
> interruption and did not complete the mirroring, bright-content opacity,
> drag/resize boundary, window-level comparison, or hostile-recovery gates.

## Result identity

- Overall result: `BLOCKED`
- Date and local time: 2026-07-12 18:01–18:08 KST
- Tester: user performed physical/input actions; Codex supplied spoken prompts,
  timestamped captures, foreground-app sampling, and evidence review
- Implementation commit: `31dff6fdfa56a0987e0b76622c81939419096dbd`
- Working tree status before test: clean (`main...origin/main`)
- Evidence directory: `/Users/thomas/Library/Application Support/Private Presenter/Validation/2026-07-12-guided-run`
- Evidence handling: local only; captures include unrelated on-screen content
  outside the Keynote checkpoints and must not be published
- DEBUG immutable configuration snapshot: controller visibly reported
  `level=statusBar`, `panels=1`, `borderless=true`, `nonactivating=true`, and
  `resizable=false`; the remainder was truncated in the captured controller UI
- Snapshot digest or identifier: implementation commit above; no exported
  runtime digest was captured
- DEBUG stale-controller-frame seed (step 14): not run

## Required environment record

- Mac model and chip: MacBook Pro (Mac16,8), Apple M4 Pro
- macOS version and build: macOS 26.5.2 (25F84)
- Xcode version: 26.6 (17F113)
- Swift version: Apple Swift 6.3.3
- XcodeGen version: 2.45.4
- Keynote version: 14.5
- Built-in/private display: Built-in Retina Display / Color LCD, 3024×1964
  physical pixels, main display
- External display/projector: `AAA`, 1920×1080 at 60 Hz
- Cable, dock, or adapter: not recorded
- Display topology and arrangement: two online displays in extended mode at
  start; built-in display was main; exact physical arrangement not recorded
- Mirroring disabled at start: `YES`
- “Displays have separate Spaces” setting: not recorded
- Screen selected in Private Presenter: Built-in Retina Display
- Initial panel level: `.statusBar`
- Diagnostic show/hide chord: Control-Option-H

## Mandatory 15-step physical gate

### 1. Record the test environment

- Result: `BLOCKED`
- Observations: core software and display facts were captured. Cable/adapter,
  exact arrangement, and separate-Spaces setting were not recorded.
- Evidence paths: this result record; system inventory captured during the run

### 2. Establish the Keynote extended-display presentation

- Result: `PASS`
- Presenter Display screen: built-in/private display
- Audience slideshow screen: external `AAA` display
- Observations: the built-in capture showed Keynote Presenter Display at slide
  22 while the external capture showed only the audience slide.
- Evidence paths:
  - `00-keynote-presenter-start-display-1.png`
  - `00-keynote-presenter-start-display-2.png`

### 3. Show the panel after Keynote is full-screen

- Result: `FAIL`
- Panel was created before entering this step: `YES`
- Keynote remained full-screen at the immediate post-show checkpoint: `NO`
- Observations: before show, Keynote Presenter Display was full-screen and
  Keynote was foreground. Immediately after Control-Option-H, the capture showed
  the ordinary desktop/controller and the sampled foreground app was Private
  Presenter. At a later checkpoint, the overlay was successfully visible above
  Keynote Presenter Display, but that does not erase the initial interruption.
- Evidence paths:
  - `00-keynote-presenter-start-display-1.png`
  - `01-overlay-visible-display-1.png`
  - `03-after-space-display-1.png`

### 4. Prove audience-display isolation

- Result: `BLOCKED`
- Private-display evidence path: `03-after-space-display-1.png`
- Audience-display evidence path: `03-after-space-display-2.png`
- Both-displays evidence path: paired files above
- Observations: all captured full-screen checkpoints with the overlay visible
  showed a clean audience slide on display 2. A physical observation or photo
  of the actual audience panel was not recorded in this result, so the mandatory
  hardware proof remains incomplete.

### 5. Prove no focus, key-window, or main-window theft

- Result: `FAIL`

| Observation | Before show | After show | After lock |
| --- | --- | --- | --- |
| Frontmost application | Keynote | Private Presenter | Private Presenter |
| Frontmost PID | not recorded | not recorded | not recorded |
| Frontmost bundle ID | not recorded | not recorded | not recorded |
| Key window | not exported | not exported | not exported |
| Panel `isKeyWindow` | not exported | not exported | not exported |
| Panel `isMainWindow` | not exported | not exported | not exported |

- Observations: shell foreground-app sampling recorded Keynote before show,
  Private Presenter after show, and Private Presenter after lock. Keynote was
  foreground again at every later input checkpoint. The initial show/lock
  sequence therefore fails this gate, and the complete key/main diagnostics
  were not exported.
- Evidence paths:
  - `00-keynote-presenter-start-display-1.png`
  - `01-overlay-visible-display-1.png`
  - `02-overlay-locked-display-1.png`
  - `03-after-space-display-1.png`

### 6. Prove click-through and normal Keynote input

- Result: `PASS`
- Mouse click-through: slide state changed after a click directly in the locked
  overlay region
- Ordinary Space: advanced the presentation
- Ordinary arrows: right advanced and left returned to the prior state
- Presentation remote: presentation state changed after the remote prompt
- Keynote remained active: `YES` at every post-input foreground sample
- Observations: paired presenter/audience captures changed in the expected
  sequence. The locked overlay remained visible on the private display only.
- Evidence paths:
  - `03-after-space-display-1.png` and `03-after-space-display-2.png`
  - `04-after-right-arrow-display-1.png` and `04-after-right-arrow-display-2.png`
  - `05-after-left-arrow-display-1.png` and `05-after-left-arrow-display-2.png`
  - `06-after-keynote-click-display-1.png` and `06-after-keynote-click-display-2.png`
  - `07-after-overlay-click-display-1.png` and `07-after-overlay-click-display-2.png`
  - `08-after-remote-display-1.png` and `08-after-remote-display-2.png`

### 7. Prove diagnostic hide/show without activation

- Result: `PASS` for the repeated-toggle checkpoint; initial-show focus failure
  remains recorded in steps 3 and 5
- Chord used: Control-Option-H five times
- Controller registration status: not exported
- Keynote before/after: foreground at the input checkpoint before the sequence
  and foreground at the capture after the sequence
- Key window before/after: not exported
- Observations: five toggles completed without leaving the Keynote presentation;
  because the starting state was visible, the odd toggle count ended hidden.
- Evidence paths:
  - `08-after-remote-display-1.png`
  - `09-after-repeated-toggle-display-1.png`
  - `09-after-repeated-toggle-display-2.png`

### 8. Prove full-screen and Space recovery

- Result: `BLOCKED`
- Full-screen exit/re-entry observation: `PASS`; the overlay was visible above
  Presenter Display after re-entry
- Space-switch observation: not separately exercised
- Selected-screen observation: overlay remained on the built-in display in the
  captured re-entry state
- Evidence paths:
  - `10-after-fullscreen-reentry-display-1.png`
  - `10-after-fullscreen-reentry-display-2.png`

### 9. Prove disconnect/reconnect fails closed

- Result: `PASS`
- State/effect order observed on disconnect: exact internal effect order was not
  exported; the overlay was absent after the physical disconnect
- State immediately after reconnect: overlay hidden and controller returned to
  the private-display confirmation screen
- Confirmation required before show: `YES`
- Automatic resume occurred: `NO`
- Observations: capture of display 2 failed during disconnect with “Only 1
  display,” positively confirming the physical topology change. After reconnect,
  both displays were capturable and no overlay automatically reappeared.
- Evidence paths:
  - `15-external-disconnected-display-1.png`
  - `16-external-reconnected-display-1.png`
  - `16-external-reconnected-display-2.png`
  - `post-run-diagnostics-display-1.png`

### 10. Prove mirroring fails closed with exact warning

- Result: `BLOCKED`
- State/effect order observed: not tested
- Warning text observed exactly: `NO`
- Overlay remained blocked: not established
- Observations: the checkpoint labeled as mirroring still captured distinct
  3024×1964 and 1920×1080 desktops, so mirroring was not actually enabled. No
  warning was visible. This is untested, not an implementation failure claim.
- Evidence paths:
  - `13-mirroring-enabled-display-1.png`
  - `13-mirroring-enabled-display-2.png`

### 11. Select the lowest passing bounded window level

- Result: `BLOCKED`
- `.floating` result and evidence: not run in this guided session
- Why `.statusBar` was tested: it was the running Debug configuration
- `.statusBar` result: mixed; it appeared over Presenter Display later in the
  run, but the initial show/focus checkpoint failed
- Lowest passing level retained: none established by this run
- Immutable configuration snapshot matches retained level: not applicable

### 12. Prove the rounded reading surface is opaque

- Result: `BLOCKED`
- Bright-content description: a bright Keynote slide was selected, but the
  fixed overlay remained over Keynote’s dark Presenter Display header rather
  than the bright slide area
- Interior bleed-through observed: none visible, but the required bright
  background condition was not met
- Clear pixels limited to outside rounded mask: not conclusively measured
- Evidence paths:
  - `12-opacity-bright-slide-display-1.png`
  - `12-opacity-bright-slide-display-2.png`

### 13. Prove every intermediate drag/resize frame is contained

- Result: `BLOCKED`
- Edges exercised: none conclusively recorded
- Corners exercised: none conclusively recorded
- Adjacent-display boundary exercised: no
- Intermediate unsafe frame observed: no captured crossing, but the interaction
  itself was not completed
- Diagnostic frame record path: not exported
- Observations: after the run, the user explicitly confirmed that the overlay
  could not be moved toward the extended display and could not be resized during
  this checkpoint. The overlay stayed in its default frame. The run did not
  establish whether the panel had successfully transitioned out of locked
  click-through mode; therefore this is a blocked interaction/testability gate,
  not evidence that boundary containment passed. The physical proof needs an
  unlock path that is operable without losing or leaving Keynote Presenter
  Display, followed by recorded edge, corner, and adjacent-display attempts.
- Evidence paths:
  - `11-boundary-attempt-display-1.png`
  - `11-boundary-attempt-display-2.png`

### 14. Prove the controller privacy shield across hostile recovery

- Result: `BLOCKED`
- Saved projector frame was established: no
- `PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME` value: not set
- Cold-launch controller state: not tested
- Shield-before-warning/reposition evidence: not tested
- Shield state after recovery: the post-reconnect controller was shielded and
  required renewed display confirmation
- Script/title appeared in status/menu text: no status/menu surface evaluated
- Observed effect ordering: not exported
- Evidence paths:
  - `post-run-diagnostics-display-1.png`

### 15. Save the real result record

- Result: `PASS`
- Result-record path: `docs/validation/overlay-proof-result.md`
- Evidence inventory complete: `NO`; physical audience confirmation, focus
  key/main export, mirroring, opacity, boundary video/frame log, level comparison,
  and hostile-recovery evidence remain missing
- All referenced image paths resolve locally: `YES` at creation time
- Reviewer: pending
- Review date: pending

## Required configuration conclusion

- Overall gate result: `BLOCKED`
- Retained window level: none approved by this run; tested Debug level was
  `.statusBar`
- Retained style mask: observed controller prefix reported borderless and
  nonactivating; full runtime export remains pending
- Retained collection behavior: not approved by this run
- Locked `ignoresMouseEvents` value: click-through behavior was observed, but
  the runtime value was not exported
- Panel became key or main at any time while locked: unknown; the Private
  Presenter application did become foreground during the initial show/lock
  checkpoints
- Private-display boundary crossed at any time: not observed, but interaction
  boundary test was not completed
- Audience display showed any teleprompter pixel: none in captured display-2
  screenshots; physical-panel confirmation pending
- Keynote was forced out of full screen: the immediate initial-show checkpoint
  was outside full screen; a focused reproduction is required before assigning
  causality to the app rather than the test interaction
- Automatic reveal or resume after topology recovery: `NO`
- Known compatibility constraints: this run used Keynote 14.5 on macOS 26.5.2
  with an external 1080p display identified as `AAA`
- Follow-up defects/blockers:
  1. Reproduce and diagnose the initial Control-Option-H show/lock activation and
     full-screen interruption with exported PID, bundle, key, and main-window
     diagnostics.
  2. Rerun mirroring with verified mirrored topology and capture the exact
     warning plus blocked overlay state.
  3. Provide an operable way to unlock and drag/resize the panel during the
     physical full-screen gate. The 2026-07-12 tester could neither move nor
     resize it at the prompted checkpoint. Then record every edge/corner and
     adjacent-display attempt.
  4. Reposition the overlay over genuinely bright Presenter Display pixels and
     capture opacity evidence.
  5. Complete `.floating` versus `.statusBar`, explicit Space switching, hostile
     stale-frame recovery, and a physical audience-display observation/photo.

## Stop rule outcome

Milestone 0 remains blocked. Do not begin Milestone 1 from this result.

---

## Owner-approved transition record — 2026-07-14

The immutable historical result above remains unchanged. On 2026-07-14, the
project owner explicitly approved moving into M2 based on the current exact
proof-build run and the observed extended-display behavior. This is an owner
waiver of the remaining formal matrix breadth, not a claim that every
historical M0 row was rerun.

- Transition decision: `M2 APPROVED BY OWNER`
- Source/proof commit: `06d7d5ff77305bed7bbab8656553a52c8fb5141f`
- Proof executable SHA-256: `7b01662ab57a4b38cc1472b3e38a9bc813141b83e8d8480d1d6f5d02f253d07a`
- Build-log SHA-256: `719f6d9b3868a918094d7c4e72f2c224d8ff7dd3770fa7b97b748131a2a9c655`
- Accepted diagnostic evidence: `/Users/thomas/Library/Application Support/Private Presenter/Validation/709f59a3-c23f-4ab3-a51f-012d69e1e177/overlay-diagnostics.txt`
- Verified behavior: Keynote slideshow remained frontmost; the overlay appeared
  only on the built-in presenter display; the external audience display stayed
  clean; H/L, Space/arrows, drag, all eight resize zones, mirroring shielding,
  and disconnect/reconnect fresh-confirmation behavior were exercised.
- Deferred evidence: ordered-out cohort, three cold repetitions per cohort,
  and any remaining human-only remote/photo evidence may be completed during
  M2 hardening if needed.

M2 work may begin from this transition record. Future release/readiness claims
must not describe the deferred items as completed until they are actually run.
