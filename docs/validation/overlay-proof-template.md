# Milestone 0 Keynote Overlay and Private-Display Proof

> **Template status: NOT RUN / PENDING REAL MAC AND HARDWARE**
>
> This file is a test procedure, not evidence that the gate passed. Run it on a
> real Mac with Keynote and a real second display/projector. Only after the run,
> use it as the checklist for a new append-only current-decision entry in
> `docs/validation/overlay-proof-result.md`. Never replace or edit that file's
> 14,486-byte historical prefix. WSL, mocks, a single display, and an ordinary
> desktop window cannot satisfy this gate.

## Result identity

- Overall result: `NOT RUN` / `PASS` / `FAIL` / `BLOCKED`
- Date and local time:
- Tester:
- Exact clean implementation commit (40 lowercase hex):
- Working tree status before proof build and each cell:
- Proof executable local path and SHA-256:
- Proof build-log local path and SHA-256:
- Proof manifest resolved local path:
- Focused-smoke executable SHA-256:
- Physical-matrix executable SHA-256:
- Smoke/physical executable equality: `YES` / `NO`
- Evidence root (local path; do not publish private media):
- DEBUG immutable configuration identifier:
- Declared and observed controller cohort:
- Repetition (`1`, `2`, or `3`):
- Correlation windows closed before quit: `YES` / `NO`
- Terminal `sessionCompletion`: `YES` / `NO`
- Pending evidence sibling absent: `YES` / `NO`
- Proof validity: `valid` / `invalid(<fixed code>)`
- DEBUG stale-controller-frame seed (step 14):

## Required environment record

- Mac model and chip:
- macOS version and build:
- Xcode version:
- Swift version:
- XcodeGen version (must be `2.45.4`):
- Keynote version:
- Built-in/private display name and model:
- External display/projector name and model:
- Cable, dock, or adapter:
- Display topology and arrangement:
- Mirroring disabled at start: `YES` / `NO`
- “Displays have separate Spaces” setting:
- Screen selected in Private Presenter:
- Candidate levels: `.floating`, `.statusBar` only
- Candidate ordering modes: `front`, `frontRegardless` only
- Phase B source defaults: `.statusBar` / `frontRegardless`
- Phase A controller cohorts: `visibleDesktopSpace`, `orderedOut`
- Phase A repetitions: `1`, `2`, `3`
- Diagnostic show/hide chord: `Control-Option-H` (DEBUG only)
- Diagnostic unlock/lock chord: `Control-Option-L` (DEBUG only)

## Preconditions

- [ ] macOS 14 or later is running on a real Mac.
- [ ] A current Keynote is installed.
- [ ] A real second display or projector is connected in **extended** mode.
- [ ] The generated project was bootstrapped with XcodeGen `2.45.4`.
- [ ] The Debug app and all Phase A and Phase B named tests completed successfully on this Mac.
- [ ] `Scripts/verify-m0-proof-provenance.sh` accepted the manifest immediately
      before this launch; the clean HEAD, executable, and build-log hashes match.
- [ ] The same copied Phase B proof executable will be used for focused smoke and the physical gate.
- [ ] No prior Private Presenter process or `.pending` evidence file remains.
- [ ] The controller starts shielded and the intended private screen has been
      selected and explicitly confirmed.
- [ ] A harmless test script is loaded; no private lecture content appears in
      screenshots, logs, filenames, or status/menu text.
- [ ] The evidence capture can show both physical displays at the same time.

## Retained Phase A causal diagnosis

The completed Phase A diagnosis remains immutable evidence for selecting the
bounded Phase B implementation. Do not rerun or relabel it as final proof. The
retained causal decision is in
`docs/validation/m0-phase-a-causal-decision-2026-07-14.md`.

Build the proof app from a clean HEAD using the recipe in the stabilization plan,
then run the exact matrix from an interactive terminal:

```bash
./Scripts/verify-m0-proof-provenance.sh "$MANIFEST"
./Scripts/run-m0-phase-a-diagnosis.sh "$MANIFEST" "$EVIDENCE_ROOT"
```

The runner enumerates exactly:

```text
2 levels × 2 ordering modes × 2 controller cohorts × 3 repetitions = 24 cells
```

Use `./Scripts/run-m0-phase-a-diagnosis.sh --list` to audit the matrix without
launching the app. `--list` is source/tooling evidence only; it is not a Mac run.
For every cold cell:

1. start from the exact clean proof commit and independently verify manifest,
   executable, and build-log provenance before launch;
2. prepare the declared controller cohort without manufacturing it through the
   cohort validator (`visibleDesktopSpace` or explicitly closed/`orderedOut`);
3. enter a fresh Keynote full-screen Presenter Display, capture the pre-H state,
   press H for the first show, then capture command-receipt, after-application,
   next-main-run-loop, `+100 ms`, and `+500 ms` states;
4. repeat H hide/show, verify Keynote remains frontmost/full-screen, explicitly
   switch to another **macOS Space** and return, and wait for the final
   `correlationWindowClosed`;
5. exit Keynote full screen, then activate Private Presenter solely to Cmd-Q;
   that activation must be tagged `postCorrelationQuit` and an ordered-out
   cohort must not present/order the controller;
6. require normal process exit, verify provenance again, then require exactly
   one new final evidence file, no pending sibling, exactly one terminal
   `sessionCompletion`, matching commit/configuration/cohort/repetition/hashes,
   matching observed cohort, and no permanent invalidation; and
7. reject and rerun the cell on any mismatch, recorder fault, unresolved path,
   incomplete publication, duplicate completion, or `EVIDENCE_QUEUE_OVERFLOW`.

### Per-correlation focus/window record

| Observation | Before H | Receipt | After apply | Next loop | +100 ms | +500 ms |
| --- | --- | --- | --- | --- | --- | --- |
| Frontmost PID / bundle ID |  |  |  |  |  |  |
| Private Presenter policy / `isActive` |  |  |  |  |  |  |
| Panel visible / key / main / order / occlusion |  |  |  |  |  |  |
| Controller visible / key / main / shielded |  |  |  |  |  |  |
| Controller show count / order-on count |  |  |  |  |  |  |
| Keynote Presenter Display full-screen |  |  |  |  |  |  |
| Correlation ID and evidence sequence |  |  |  |  |  |  |

### Phase A causal decision output required from Tom

After all 24 cells are valid, preserve every evidence file and return a causal
note containing:

- exact instrumented commit, executable/build-log/manifest paths and hashes;
- a 24-row outcome table with configuration/cohort/repetition, validity, focus/
  full-screen result, activation chronology, panel visibility/key/main result,
  controller `showShielded`/`showWindow`/presentation/order-on chronology, and
  local evidence/media paths;
- whether activation preceded or followed panel ordering in each failing cell;
- whether any controller presentation/order-on event occurred in each cohort;
- the matching hypothesis/decision-table branch from plan section 5, or
  `NOT ISOLATED`;
- the proposed permitted regression/fix branch, or `NONE — KEEP BLOCKED`; and
- explicit confirmation that no Phase B code was applied during diagnosis.

Any invalid or incomplete cell, or a cause outside the permitted public paths,
keeps M0 and M2 blocked. Do not select a fix or default from timing alone.

## Current complete 15-step Phase B physical gate

The Phase A causal selection is complete. Run the following gate with the exact
clean Phase B source-default commit and the same copied proof binary used for
focused smoke. A rebuild or source/default change invalidates downstream proof.


For every step, record `PASS`, `FAIL`, or `BLOCKED`, observations, and local
evidence paths. Do not mark the overall result `PASS` unless all 15 steps pass.

### 1. Record the test environment

Record Mac model, macOS build, Keynote version, display/projector models,
topology, separate-Spaces setting, and selected screen.

- Result:
- Observations:
- Evidence paths:

### 2. Establish the Keynote extended-display presentation

Put Keynote audience slideshow on the external display and Presenter Display
full-screen on the Mac.

- Result:
- Presenter Display screen:
- Audience slideshow screen:
- Observations:
- Evidence paths:

### 3. Show the panel after Keynote is full-screen

Show the already-created panel after Keynote is full-screen; verify it joins
the Presenter Display Space without forcing Keynote out of full screen.

- Result:
- Panel was created before entering this step: `YES` / `NO`
- Keynote remained full-screen: `YES` / `NO`
- Observations:
- Evidence paths:

### 4. Prove audience-display isolation

Photograph/capture both displays and verify no teleprompter pixel exists on the
audience display.

- Result:
- Private-display evidence path:
- Audience-display evidence path:
- Both-displays evidence path:
- Observations:

### 5. Prove no focus, key-window, or main-window theft

Lock the panel; record frontmost application PID/bundle ID and key window
before/after show/lock. Keynote must stay frontmost and the panel must not
become key/main.

| Observation | Before show | After show | After lock |
| --- | --- | --- | --- |
| Frontmost PID |  |  |  |
| Frontmost bundle ID |  |  |  |
| Key window |  |  |  |
| Panel `isKeyWindow` |  |  |  |
| Panel `isMainWindow` |  |  |  |

- Result:
- Observations:
- Diagnostic log/evidence paths:

### 6. Prove click-through and normal Keynote input

Click through the panel; operate Keynote with mouse, ordinary Space/arrows, and
a presentation remote.

- Result:
- Mouse click-through:
- Ordinary Space:
- Ordinary arrows:
- Presentation remote:
- Keynote remained active:
- Observations:
- Evidence paths:

### 7. Prove diagnostic hide/show without activation

Hide/show with the diagnostic chord while Keynote stays active.

- Result:
- H registration OSStatus and direct typed visibility command evidence:
- L registration OSStatus and direct typed lock command evidence:
- Keynote PID/bundle ID before/immediate/next-loop/+100 ms/+500 ms:
- App policy/active before/immediate/next-loop/+100 ms/+500 ms:
- Panel visible/key/main/locked before/immediate/next-loop/+100 ms/+500 ms:
- Controller visible/key/main/shielded/presentation count at every sample:
- Correlation closure and terminal publication evidence:
- Observations:
- Evidence paths:

### 8. Prove full-screen and Space recovery

Move Keynote into/out of full screen and switch Spaces; panel remains
recoverable on the selected screen.

- Result:
- Full-screen exit/re-entry observation:
- Space-switch observation:
- Selected-screen observation:
- Evidence paths:

### 9. Prove disconnect/reconnect fails closed

Disconnect the external display: overlay pauses/hides before recovery.
Reconnect: it remains hidden/paused until confirmation.

- Result:
- State/effect order observed on disconnect:
- State immediately after reconnect:
- Confirmation required before show: `YES` / `NO`
- Automatic resume occurred: `YES` / `NO` (must be `NO`)
- Observations:
- Evidence paths:

### 10. Prove mirroring fails closed with exact warning

Enable mirroring: overlay immediately pauses/hides/blocks and displays the exact
warning in the controller.

Required warning:

> **Display mirroring is on. Students may see the teleprompter. Use Extended Display mode.**

- Result:
- State/effect order observed:
- Warning text observed exactly: `YES` / `NO`
- Overlay remained blocked:
- Observations:
- Evidence paths:

### 11. Select the lowest passing bounded window level

Run `.floating` first; test `.statusBar` only if necessary. Record and keep the
lowest configuration that passes every case.

- Result:
- `.floating` / `front` result, safety vector, and evidence:
- `.floating` / `frontRegardless` result, safety vector, and evidence:
- Why `.statusBar` was or was not required:
- `.statusBar` / `front` result, safety vector, and evidence:
- `.statusBar` / `frontRegardless` result, safety vector, and evidence:
- Lowest passing level and deterministic ordering retained:
- Tie-break/source-default reason:
- Configuration matches source defaults at the exact commit: `YES` / `NO`

### 12. Prove the rounded reading surface is opaque

Place the panel over bright Presenter Display content and verify the rounded
reading surface is fully opaque.

- Result:
- Bright-content description:
- Interior bleed-through observed: `YES` / `NO` (must be `NO`)
- Clear pixels limited to outside rounded mask: `YES` / `NO`
- Observations:
- Evidence paths:

### 13. Prove every intermediate drag/resize frame is contained

Drag and resize toward every edge/corner, including an adjacent display; no
intermediate panel pixel may cross the selected-screen boundary.

- Result:
- Edges exercised: top / right / bottom / left
- Corners exercised: top-left / top-right / bottom-right / bottom-left
- Adjacent-display boundary exercised:
- Intermediate unsafe frame observed: `YES` / `NO` (must be `NO`)
- Diagnostic frame record path:
- Observations:
- Video/evidence paths:

### 14. Prove the controller privacy shield across hostile recovery

Cold-launch with the saved controller frame on the projector, enable mirroring
while a script is visible, and disconnect the private display. Verify the
controller becomes generic/shielded before warning or reposition, stays
shielded after recovery, and never exposes script/title in its status-menu
text.

- Result:
- Saved projector frame was established:
- `PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME` value:
- Cold-launch controller state:
- Shield-before-warning/reposition evidence:
- Shield state after recovery:
- Script/title appeared in status/menu text: `YES` / `NO` (must be `NO`)
- Observed effect ordering:
- Observations:
- Evidence paths:

### 15. Save the real result record

Append a new current-decision ledger to `docs/validation/overlay-proof-result.md`
with date/tester, focus/window observations, proof hashes, and paths to local
screenshots/photos/video. The historical 14,486-byte prefix must remain exact.

- Result:
- Result-record path:
- Evidence inventory complete: `YES` / `NO`
- All paths resolve locally: `YES` / `NO`
- Reviewer:
- Review date:

## Required configuration conclusion

- Overall gate result:
- Exact clean implementation commit:
- Retained window level:
- Retained ordering mode:
- Configuration matches source defaults: `YES` / `NO`
- Evidence validity and 24/24 Phase A completion:
- Proof executable/build-log/manifest hashes reverified:
- Retained style mask:
- Retained collection behavior:
- Locked `ignoresMouseEvents` value:
- Panel became key or main at any time while locked: `YES` / `NO`
- Private-display boundary crossed at any time: `YES` / `NO`
- Audience display showed any teleprompter pixel: `YES` / `NO`
- Keynote was forced out of full screen: `YES` / `NO`
- Automatic reveal or resume after topology recovery: `YES` / `NO`
- Known compatibility constraints:
- Follow-up defects/blockers:

## Stop rule

Do not begin M2 until every current Phase B row passes on the exact clean source-
default commit and the append-only current-decision ledger records that PASS. If
both bounded levels/orderings fail, do not try `.screenSaver`, raw/private
levels, focus return, or a focus-stealing window. Append a truthful BLOCKED
result and reassess feasibility.
