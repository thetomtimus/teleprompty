# Milestone 0 Keynote Overlay and Private-Display Proof

> **Template status: NOT RUN / PENDING REAL MAC AND HARDWARE**
>
> This file is a test procedure, not evidence that the gate passed. Run it on a
> real Mac with Keynote and a real second display/projector. Only after the run,
> copy this template to `docs/validation/overlay-proof-result.md` and replace
> every blank with observed evidence. WSL, mocks, a single display, and an
> ordinary desktop window cannot satisfy this gate.

## Result identity

- Overall result: `NOT RUN` / `PASS` / `FAIL` / `BLOCKED`
- Date and local time:
- Tester:
- Implementation commit:
- Working tree status before test:
- Evidence directory (repository-local or other local path; do not publish):
- DEBUG immutable configuration snapshot:
- Snapshot digest or identifier:
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
- Initial panel level: `.floating`
- Diagnostic show/hide chord: `Control-Option-H` (DEBUG only)

## Preconditions

- [ ] macOS 14 or later is running on a real Mac.
- [ ] A current Keynote is installed.
- [ ] A real second display or projector is connected in **extended** mode.
- [ ] The generated project was bootstrapped with XcodeGen `2.45.4`.
- [ ] The Debug app and tests completed successfully on this Mac.
- [ ] The controller starts shielded and the intended private screen has been
      selected and explicitly confirmed.
- [ ] A harmless test script is loaded; no private lecture content appears in
      screenshots, logs, filenames, or status/menu text.
- [ ] The evidence capture can show both physical displays at the same time.

## Mandatory 15-step physical gate

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
- Chord used:
- Controller registration status:
- Keynote PID/bundle ID before:
- Keynote PID/bundle ID after:
- Key window before/after:
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
- `.floating` result and evidence:
- Why `.statusBar` was or was not tested:
- `.statusBar` result and evidence (if tested):
- Lowest passing level retained:
- Immutable configuration snapshot matches retained level: `YES` / `NO`

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

Save evidence in `docs/validation/overlay-proof-result.md` with date/tester,
focus/window observations, and paths to local screenshots/photos/video.

- Result:
- Result-record path:
- Evidence inventory complete: `YES` / `NO`
- All paths resolve locally: `YES` / `NO`
- Reviewer:
- Review date:

## Required configuration conclusion

- Overall gate result:
- Retained window level:
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

If `.floating` and `.statusBar` both fail, do not try `.screenSaver`, private
APIs, or a focus-stealing window. Mark Milestone 0 blocked with evidence and
reassess feasibility. Do not begin Milestone 1 or visual product polish until a
real `overlay-proof-result.md` records a passing gate.
