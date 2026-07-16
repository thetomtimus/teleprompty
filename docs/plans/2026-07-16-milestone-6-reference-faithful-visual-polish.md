# Private Presenter — Milestone 6 Reference-Faithful Visual Polish and Visual Acceptance Plan

Status: **SEQUENTIAL PLANNER → ARCHITECT → CRITIC CONSENSUS APPROVED; IMPLEMENTATION NOT STARTED; ALL HOST/VISUAL/PHYSICAL PROOF PENDING**

Canonical publication target:
`docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md`

Exact planning baseline: clean `main` at
`1ac13dbbdae1c53eea06033c353d22ab0919e8a5`
(`Prevent replay evidence from outrunning the measured product path`), the M5 WSL source
candidate. The eventual plan commit must have that SHA as its sole parent and contain only the
canonical plan file.

## 1. Outcome, authorization, evidence boundary, and hard stop

Implement only `IMPLEMENTATION_PLAN.md` Milestone 6
(`IMPLEMENTATION_PLAN.md:593-609`): make the existing single private-display overlay
recognizably consistent with the committed references, retain complete reading-surface opacity,
and create reproducible automated and human visual acceptance. This is the last feature
milestone; it is not Milestone 7 final acceptance.

The owner explicitly authorizes immediate **M6 WSL-candidate continuation** from the exact clean
M5 candidate even though the implementation plan normally starts M6 only after M0-M5 gates pass
(`IMPLEMENTATION_PLAN.md:595`) and native M3-M5 gates are still pending. The authorization permits
test/source RED/GREEN candidate commits, WSL-static validation, and a checksummed controlled-Mac
handoff. It does not waive a predecessor gate, turn WSL into Swift/AppKit/Core Graphics evidence,
or authorize an M6 completion/readiness claim.

Evidence truth at this plan commit is deliberately narrow:

- historical M0/M2 records remain exactly as committed; this plan does not reinterpret or rewrite
  them;
- M3 Swift/AppKit/TextKit/display-link, Keynote, and physical display evidence is **PENDING**;
- M4 Swift/Carbon/AppKit, fresh-user TCC/hotkey, Keynote-focus, and physical input evidence is
  **PENDING**;
- M5 native accessibility, lifecycle, exact-50,000-word, VoiceOver, Full Keyboard Access,
  Accessibility Inspector, Instruments, Keynote, and display evidence is **PENDING**;
- all M6 Swift/AppKit/TextKit/Core Graphics, build, render, screenshot, visual, physical,
  VoiceOver, Instruments, Keynote, and display proof is **PENDING**.

Stop after the M6 source candidate, controlled-Mac replay when available, additive M6 visual
evidence when actually observed, exact-SHA/checksum closure, and independent code/designer/
verifier/architect review. Do not implement M7, edit `HANDOFF.md`, add a runtime dependency or
permission, change window level/ordering, rewrite prior plans/results, claim physical
verification, or push.

## 2. Sources of truth and current grounded delta

### 2.1 Authority order

When artifacts differ, use this order:

1. Privacy, focus, accessibility, performance, and behavior contracts in `PRD.md`,
   `IMPLEMENTATION_PLAN.md`, and accepted M0-M5 source/tests/evidence.
2. Primary proportions/language reference `references/teleprompter-ui-reference.png`.
3. Product-specific interpretation `design/teleprompter-concept.png`.
4. Non-shipping visual guidance `design/concept.html`; it is never executed or embedded in the
   app (`IMPLEMENTATION_PLAN.md:15-21`).

Protected reference identities:

| Artifact | Dimensions | SHA-256 |
|---|---:|---|
| `references/teleprompter-ui-reference.png` | 896×634 | `352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92` |
| `design/teleprompter-concept.png` | 1440×723 | `d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e` |
| `design/concept.html` | visual guidance | `b3c0e19bbef6285ece0fffa045032a806ccf915b8bb8415184e74f6556af2a2a` |
| `PRD.md` | requirements | `3980ec241d38901ef434b93afa3935ce5b8c3d1a14849ae2417ec6a940138f3d` |

The primary screenshot contributes rounded-card proportions, restrained blue palette, spacious
type, quiet header, subtle selected-line treatment, and a floating pill, but its wording,
collaboration actions, translucent glass, underlines, and dimensions are not product requirements
(`PRD.md:11-17,90-108`). The product concept supplies the document header and seven quick-control
arrangement (`design/concept.html:29-70,82-110`). The normative gradient endpoints remain the
PRD/implementation values `#34466F` and `#202B4B`, not the concept CSS's one-channel-different top
sample (`PRD.md:62-79`; `design/concept.html:29-36`).

### 2.2 Current pre-M6 surface

- The single root currently uses an 18-point clip and near-black solid fill
  (`PrivatePresenterApp/Overlay/OverlayRootView.swift:3-9,53-86`).
- The current header is a 36-point text-button row with Start/Pause, Hide/Show, and Lock/Unlock
  (`OverlayRootView.swift:6-8,58-70`; `OverlayChromeView.swift:7-37`).
- The reader uses a system font but no persisted weight mapping or explicit line-height multiple,
  white instead of the exact light token, and 28×24 insets
  (`ReaderTextSystem.swift:49-66,150-163`).
- The active band is a fixed 84-point, 10%-white rectangle over an opaque near-black AppKit
  backing (`ReaderTextView.swift:54-65,86-123,139-153`).
- The panel is correctly borderless/nonactivating, nonopaque only for clear corner pixels, and
  uses the selected bounded level/Space behavior (`TeleprompterPanel.swift:69-96`).
- Custom header/eight-zone interaction clamps before every frame application; native
  `.resizable` and unconstrained drag remain absent (`OverlayRootView.swift:87-164`;
  `ClampedPanelInteractionController.swift:4-89`; `PanelFramePolicy.swift:78-165`).
- Focus already has one tokenized two-second state machine and Reduce Motion bridge
  (`FocusChromeStateMachine.swift:33-72`; `FocusModeController.swift:78-131`). M6 styles that
  state; it creates no second timer or pointer owner.
- Accessibility semantics are centralized and existing overlay controls have dynamic state/help
  and 44×44 targets (`PresenterAccessibility.swift:117-125,268-291,345-370`). M6 extends this
  manifest instead of decorating controls ad hoc.

## 3. Preserved M0-M5 invariants, history, and non-goals

### 3.1 Invariants that every M6 commit carries

1. Exactly one `@MainActor @Observable AppModel`, one `TeleprompterPanel`, one AppKit-owned overlay
   controller, one TextKit reader, one viewport/session, and one Focus state machine remain the
   authorities. SwiftUI views only send typed `AppCommand` values.
2. Display privacy still pauses/hides/shields before query/reassignment, requires explicit
   confirmation, never infers an audience display, and never creates another overlay.
3. Locked mode remains non-key/non-main and click-through; no M6 button, hover, render harness, or
   screenshot path calls `NSApp.activate`, `makeKeyAndOrderFront`, an event monitor/tap, AX/TCC,
   Keynote automation, or screen capture from product code.
4. The retained level/order (`.statusBar`/`frontRegardless` at this candidate), style mask,
   collection behavior, dynamic key eligibility, Carbon-only global input, and ordinary Keynote
   Space/arrows remain unchanged.
5. Custom header drag and all eight resize zones remain clamped on every intermediate frame. No
   `.resizable`, `performWindowDrag(with:)`, cross-display correction-after-the-fact, title bar,
   traffic lights, or ordinary scrollbar is introduced.
6. Focus Mode reuses the existing state/deadline/pointer sampler. Chrome visibility changes only
   opacity, hit testing, and accessibility exposure; it does not change reader bounds, text
   storage, semantic anchor, band position, or reserved insets. Reduce Motion changes the
   decorative fade to zero, not reading motion.
7. Every interactive icon/control has a stable identifier, dynamic label/value/help/tooltip, at
   least 44×44 points, keyboard/VoiceOver semantics while unlocked, visible focus indication, and
   no color-only meaning. Decorative background, band, border, and resize zones stay ignored.
8. TextKit remains incremental. Appearance, Focus, hover, and live resize do not replace the
   script, publish state per frame, add logging metadata, or relax M5 load/edit/scroll/memory
   thresholds.
9. Sandbox/no-network/no-telemetry/no-analytics/no-cloud/no-runtime-package and privacy-safe
   signpost/logging contracts remain exact. The app never captures the screen; screenshots are a
   controlled human/test-host artifact with synthetic content.
10. Schema v1, stored script/settings/frames/shortcuts, source artifact checksums, and every prior
    plan/result remain unchanged. `docs/validation/visual-result.md` is the only new committed M6
    evidence path.

### 3.2 Protected bytes and historical validation

At implementation preflight, hash every tracked path present at the plan commit in `PRD.md`,
`IMPLEMENTATION_PLAN.md`, `HANDOFF.md`, `design/`, `references/`, all prior `docs/plans/`, and all
prior `docs/validation/`. Recheck the manifest before every evidence/review commit. The new M6
plan and later new `visual-result.md` are excluded only from the comparison against their own
absence; nothing existing may be edited.

M5's source validator intentionally rejects M6 tokens at the M5 epoch
(`Scripts/validate_project_structure.py:796-847,2200-2252`). M6 must not weaken that historical
stop rule. Exact M5 validation also requires ignored `.omx/handoff/private-presenter-m5/` artifacts
(`Scripts/validate_project_structure.py:2111-2114,2367-2437`), so a bare detached worktree is
insufficient. M6 binds the predecessor handoff to this exact seven-file inventory:
`MAC-CONTINUATION.md`, `m5-artifacts.sha256`, `m5-review-red-source-files.sha256`,
`m5-source-files.sha256`, `private-presenter-m5-review-red-source.tar`,
`private-presenter-m5-source.tar`, and `private-presenter-m5-wsl.bundle`. The manifest itself has
SHA-256 `2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9`; its six entries and
the bundle must verify before copying, and the manifest must verify again after the byte-exact copy.

M6.0 runs the **original M5 test and validator bytes** in a detached temporary worktree at exact
Git tree `1ac13db...` only after placing that verified immutable handoff at
`.omx/handoff/private-presenter-m5/`. Neither the source handoff nor
`Scripts/test_validate_project_structure_m5.py` is edited or repackaged as M6 evidence. In the
current tree, `main()` **replaces** its active
`validate_m5_source()` call/final M5 success label with one `validate_m6_source()` call/final M6
success label; it must not invoke both validators. The retained M5 function remains byte-for-byte
available for its exact-tree epoch, while the new M6 function independently reasserts every
still-applicable M0-M5 invariant plus M6 tokens and has a separate M6 mutation test. Historical
and current epochs are therefore executable without allowing M6 tokens through an M5 validator or
pretending an M6 tree is an M5 tree.

`validate_m6_source()` evolves only through the preserved RED/GREEN ledger; it has no runtime
stage flag or environment bypass. At 0B it validates carried M0-M5 invariants, exact plan ancestry,
protected bytes/PENDING claims, the exact future M6 path/token inventory, and the required
**absence** of not-yet-implemented M6.1-M6.6 production/evidence/handoff surfaces. Each later `nA`
adds the named requirement/mutation for that slice and intentionally turns current source RED;
the immediate `nB` supplies the minimum source and makes that progressively stronger validator
GREEN. Only 6B requires the complete final M6 path/token/evidence/handoff contract. Thus 0B never
claims future files/tokens already exist, while final validation cannot silently retain a phase-
zero allowance.

### 3.3 Non-goals

No controller redesign; new state authority; persistence migration; new font family; rich text;
automatic underlining; Keynote integration; slide synchronization; capture/recording; window
level/order change; native resize; new global shortcut; M5 threshold change; new permission,
entitlement, dependency, target, WebView/HTML runtime, network/logging/telemetry; prior evidence
rewrite; M7 final acceptance; push.

## 4. RALPLAN-DR deliberate decision summary

### Principles

1. **Reference-faithful, not reference-literal.** Match visual grammar and exact product tokens;
   do not copy unrelated wording/actions or demand cross-dimension pixel identity.
2. **Opacity and privacy outrank glass aesthetics.** Every rounded-interior pixel is final-alpha
   1.0 over bright content; only antialiased pixels outside the rounded mask may be clear.
3. **One behavioral path, visual-only additions.** Existing model/panel/TextKit/focus/resize
   owners remain authoritative; chrome sends existing typed commands.
4. **Automate objective structure; review perception independently.** Core Graphics locks
   bounds/tokens/opacity while a designer compares real screenshots to both supplied PNGs.
5. **Evidence never outruns the host.** WSL, Mac render, VoiceOver/Instruments, and physical
   Keynote/display claims stay separate and exact-SHA bound.

### Top decision drivers

1. A recognizably reference-consistent reading experience with exact opaque navy and comfortable
   type at default and resized dimensions.
2. Zero regression in private-display containment, Keynote focus/input, accessibility, semantic
   position, or 50,000-word performance.
3. Deterministic, dependency-free visual acceptance that detects gross drift without brittle
   font/wording pixel identity.

### Viable options

| Option | Advantages | Costs/limits | Decision |
|---|---|---|---|
| A. Shared native visual tokens + responsive overlay metrics + semantic Core Graphics baseline + independent reference review | Tests actual SwiftUI/AppKit/TextKit composition; exact tokens/regions/opacity; tolerant of glyph/OS variance; no dependency | Bounded SwiftUI/AppKit integration and Mac-only render execution; human visual review still required | **Chosen** |
| B. Committed full-pixel golden screenshot from one Mac | Simple byte/image diff; familiar snapshot flow | Brittle to SF glyph/OS/raster changes; baseline approval can self-ratify; encourages unrelated reference pixel identity; requires resource plumbing | Viable only for a future fixed-host lab, rejected for M6 portability |
| C. Manual screenshot/designer review only | Direct perceptual judgment; smallest test code | Cannot lock alpha, colors, geometry, resize containment, or regressions; unreproducible | Invalid as sole acceptance |
| D. Pixel-diff the two supplied references directly | No new baseline model | References have different dimensions, wording, controls, translucency, and context; would reward wrong product behavior | Invalid |

### Tradeoff synthesis

Use a fixed-size actual app render plus a programmatically drawn Core Graphics **semantic**
baseline for stable regions, with literal expected values independent from production token
definitions. Exclude glyph/icon antialias regions from strict pixel thresholds and test their
font attributes, labels, and frames separately. Use real screenshots and an independent designer
for perceptual fidelity. This retains deterministic automation without converting visual taste or
different reference content into a fake exact oracle.

## 5. Exact visual and interaction specification

### 5.1 Canonical tokens

Create `PrivatePresenterApp/Overlay/OverlayVisualTokens.swift` as the only production visual-token
surface. Test oracles repeat the numeric values intentionally; tests must not import expected
pixels from the production values.

| Token | Exact value/behavior |
|---|---|
| Card gradient | vertical stops `0.00: #34466F`, `0.42: #2C3D63`, `1.00: #202B4B`; all stop alpha `1.00`; named sRGB |
| Reading text | `#F7F8FC`, alpha `1.00` |
| Card border | 1.0 point inset stroke, white alpha `0.24` |
| Card radius | 30.0 points, continuous rounded rectangle; valid PRD range 28-30 resolved to 30 |
| Header divider | 1.0 point, white alpha `0.08` |
| Active band | horizontal stops `#82A0D5@0.28`, `#7191CA@0.35`, `#82A0D5@0.20`; 3-point leading inset `#BED3F8@0.62`; radius 8 |
| Toolbar fill | vertical `#5A71A5@0.98` to `#465C91@0.98`, composited inside the opaque card |
| Toolbar border/divider | 1 point white `0.13`; divider 1×29 points white `0.18` where the standard tier has room |
| Toolbar shadow | `#070C1E@0.34`, 16-point blur, y=8; no colored/white glow |
| Hover/pressed | white `0.09` / white `0.14`, within existing control bounds |
| Primary play fill | `#F7F8FC`; foreground `#263654` |
| Other icons | `#F7F8FC`, SF Symbols line style, no automatic underline |
| Outer separation | retain native restrained panel shadow (`TeleprompterPanel.hasShadow == true`); add no card glow or second outer shadow |

The gradient, border, band, and toolbar overlays may have local translucent colors, but they are
always composited over the fully opaque card. Final alpha inside the rounded mask is 1.0. Window
`isOpaque=false` remains solely for pixels outside the curved card
(`TeleprompterPanel.swift:69-92`).

Production must construct every SwiftUI color with `Color(.sRGB, red:green:blue:opacity:)` and
every AppKit color with `NSColor(srgbRed:green:blue:alpha:)`. Generic calibrated RGB, device RGB,
display-profile-derived components, and `Color(red:green:blue:)` without the named color space are
forbidden. Hex tokens above are converted to components by dividing each literal byte by 255.

### 5.2 Responsive geometry and spacing

Keep the inherited 320×180 minimum and unrestricted contained resizing; do not lock aspect ratio.
`OverlayLayoutMetrics` is a pure app-local value derived only from current root size:

| Tier | Entry condition | Header | Reading side inset | Reading top/bottom reserve | Exact centered toolbar |
|---|---|---:|---:|---:|---|
| Spacious/reference | width ≥800 and height ≥400 | 92 | 52 | top 124; bottom 114 | 65 high; bottom 24; `7×49 + 6×4 + 2×10 = 387` wide |
| Standard/default | width ≥520 and height ≥280 | 72 | 48 | top 96; bottom 90 | 56 high; bottom 18; `7×44 + 6×4 + 2×8 = 348` wide |
| Compact/safety | otherwise down to 320×180 | 52 | 20 | top 58; bottom **88** | 52 high; bottom **30**; `7×44 + 2×4 = 316` wide; zero gaps/dividers; no shadow |

For width above 1,154 points, grow the effective horizontal inset so the text measure never
exceeds 1,050 points: `max(tierInset, (width - 1050) / 2)`. Standard/reference sizes retain the
required 44-52-point padding (`PRD.md:71-76`). Compact mode is the explicit small-size degradation:
all actions remain, title truncates first, dividers/gaps/shadow disappear, and the usable reader
clips to its 34-point minimum-height rect; hit targets, opacity, privacy, and containment never
degrade. At exactly 320×180, the pill is centered at x=2, its controls occupy x=6...314, its
lowest pixel is 30 points above the card bottom, and the 30-point continuous corner has already
reached the straight side. Thus `320 = 2×2 + 2×4 + 7×44` is the frozen feasibility equality, not
an aspirational fit. A pure `CGPath`/raster-mask test must prove the complete pill rect, every
44×44 hit rect, and every nontransparent pill pixel are subsets of the continuous rounded-card
path at 320×180; a negative or boundary-only containment test is insufficient.

Effective interaction routing is frozen separately from visual overlap. Add a pure
`OverlayHitRegionResolver` whose half-open hit regions resolve in this exact precedence:
**control → corner resize → edge resize → title drag → none**. Render controls above resize zones
and resize zones above the title drag so SwiftUI/AppKit hit testing implements the same result.
At 320×180, dense app-host probes over every point of each first/last 44×44 toolbar target must
dispatch only that control even where the inherited 10-point side resize overlays geometrically
cross x=6...10 and x=310...314. The eight resize operations must still dispatch at independent
compact probes (bottom-origin points): bottom-left `(9,9)`, bottom `(110,5)`, bottom-right
`(311,9)`, left `(5,105)`, right `(315,105)`, top-left `(9,171)`, top `(110,175)`, and top-right
`(311,171)`. Equivalent resolver-generated probes run at every tier. Header horizontal padding is
20/32/46 points and action spacing is 4 points for compact/standard/spacious, keeping action
targets away from corner regions; where an action crosses the 10-point top edge, control
precedence wins and top resize remains reachable at its independent probe. Geometry tests and
actual `NSHostingView`/operation-callback hit tests must agree: each sampled point resolves exactly
one route, all seven full targets dispatch, and all eight resize callbacks remain reachable.

Header and toolbar are overlays. Reading bounds/reserves depend only on the size tier, not on
locked/Focus visibility. A Focus fade therefore cannot move a glyph, viewport, band, anchor, or
final line. The toolbar never overlaps the reading/band rect, including at minimum size.

Required size matrix: 320×180 compact, 700×350 current initial/standard, 1,036×460 canonical
reference render, and 1,440×460 wide. Also test the actual 70%×35% default from each controlled
display (`PanelFramePolicy.swift:30-45`).

### 5.3 Header

- Left: product document SF Symbol exactly 18/20/23 points and the current script title in system
  semibold exactly 16/18/23 points for compact/standard/spacious respectively, one line,
  truncating tail. Default renders `Lecture Teleprompter`; no generic `Private Presenter`
  substitution once the private overlay is
  confirmed (`PRD.md:81-88`).
- Right, in order: Start/Pause, Lock/Unlock, Settings/Show Controller; line icons, consistent
  optical sizes exactly 16/18/20 points for compact/standard/spacious respectively, 44-point
  minimum targets, exact dynamic accessibility semantics.
- Remove Hide/Show from the visual header; it remains available through controller, status menu,
  and Control-Option-H. This matches the committed header without deleting behavior.
- Attach custom drag only to the title/empty header region. Buttons win hit testing; no transparent
  whole-header overlay may consume them. Header drag still routes through
  `ClampedPanelInteractionController`.
- Settings sends existing `.showController`. It is pointer/keyboard reachable only while the
  overlay is unlocked/interactive; it creates no second controller and performs no activation
  workaround.

Exact SF Symbol contract (no executor-selected substitutes): document `doc.text`; header and pill
playback `play.fill` while paused and `pause.fill` while playing; lock `lock.open.fill` while
unlocked and `lock.fill` while locked; Settings `gearshape`; A− `textformat.size.smaller`; A+
`textformat.size.larger`; alignment `text.alignleft` for Left and `text.aligncenter` for Center;
slower `minus`; faster `plus`; Focus `eye` while off and `eye.slash` while on. State changes retain
the same stable accessibility identifier and update label/value/help; the symbol never supplies
the only state cue.

### 5.4 Reader typography

- `NSFont.systemFont(ofSize: preference, weight:)`, mapping persisted
  Regular/Medium/Semibold exactly to `.regular/.medium/.semibold`; default 42 Regular
  (`TeleprompterPreferences.swift:3-20,31-56`).
- Foreground named-sRGB `#F7F8FC`; paragraph `lineHeightMultiple = 1.42`; paragraph spacing 0; default left
  alignment; no underline, link detection, rich-text carryover, automatic hyphenation, or added
  tracking. Font range/step remains 24-96 by 2.
- TextKit scroll/document view remains transparent over the root gradient. Remove the competing
  near-black AppKit backing fill without permitting alpha holes: the SwiftUI root paints the
  entire rounded interior first, then transparent TextKit/band/chrome layers draw above it.
- Compute the text container inset from section 5.2 and cap line measure at 1,050 points. Keep
  scrollbars/elasticity/selection off (`ReaderTextView.swift:104-113`).
- Appearance and resize reconcile the current semantic anchor through existing
  `readerBoundsWillChange`/`readerBoundsChanged`; no text replacement or auto-resume.

### 5.5 Active reading band

- Draw behind the transparent TextKit scroll view, centered at the existing viewport fraction.
- Preserve TextKit 2 exclusively. `ReaderViewportContainerView.layout()` first calls the existing
  `ReaderViewportAdapter.ensureLayout()`, then calls a new read-only adapter query over its already-
  cached `LineFragmentEvidence` frames (derived from the existing `NSTextLayoutManager` and
  `NSTextLineFragment.typographicBounds`). The query does not call layout, create another text
  manager/container/storage, switch to TextKit-1 compatibility, or mutate the cache.
- The query target is exact document Y `clipOriginY + clipSize.height × viewportFraction`. From
  positive finite cached frames in vertical order, choose the nearest frame by midpoint, then the
  closer immediately adjacent frame (tie: following/larger minY), and sort the chosen pair by
  minY. With two or more frames, unconstrained band height is the two selected actual frame
  heights plus 12. With exactly one frame it is `2 × actualFrame.height + 12`. With zero frames it
  is `2 × ceilToBackingPixel((font.ascender - font.descender + font.leading) × 1.42) + 12`, using
  the effective named system font and current backing scale. Clamp only to the usable reading rect
  in compact/large-font cases; never extend beneath header/toolbar or beyond the rounded mask.
  Regular/medium/semibold at 42 and 96 points prove two-fragment sizing/no glyph clipping; explicit
  one-line, empty, tie, and compact-clamp tests prove deterministic fallback and selection.
- Horizontal band bounds are the readable line measure expanded 18 points on each side and then
  clipped to the card padding. Use the exact gradient/leading inset/radius from section 5.1.
- It is static, noninteractive, accessibility-ignored, and never mutates or selects text. Default
  text contrast must be ≥7:1 on the unbanded gradient and ≥4.5:1 at every composited band stop;
  test the literal sRGB calculations. Previously/upcoming text stays full-strength.

### 5.6 Bottom quick controls

Centered pill, exact order:

1. A−: `.setFontSize(current - 2)`, disabled at 24.
2. A+: `.setFontSize(current + 2)`, disabled at 96.
3. Alignment: toggle Left/Center.
4. Slower: `.setSpeed(current - 5)`, disabled at 10.
5. Start/Pause: `.togglePlayback`, using existing safety/empty-script policy; selected light circle.
6. Faster: `.setSpeed(current + 5)`, disabled at 240.
7. Focus: `.setFocusModeEnabled(!current)` with selected state visible and spoken.

Do not duplicate range, playback, or privacy policy in the view. Use existing typed commands and
model/presentation state. Give header and toolbar instances distinct stable identifiers even when
they dispatch the same command. Extend `PresenterAccessibility` with exact dynamic label, current
value/state, result-oriented help/tooltip, disabled state, and ≥44×44 target for every control.

### 5.7 Lock, Focus, opacity, and interaction

| State | Opacity | Pointer/keyboard | Accessibility | Presentation/focus |
|---|---:|---|---|---|
| Unlocked | 1 | header actions, title drag, eight resize zones, and pill enabled | controls exposed with exact semantics | Settings alone may dispatch existing `.showController`; no new controller or activation workaround |
| Locked-visible (Focus off, or pointer return) | 1 | panel click-through; every chrome hit target and resize/drag zone disabled | entire chrome subtree hidden/ignored so VoiceOver cannot navigate it | non-key/non-main; Keynote retains input |
| Locked-Focus-hidden after existing 2-second deadline | 0 after 0.18-second fade | hit testing disabled | entire chrome subtree hidden/ignored | non-key/non-main; Keynote retains input |

The existing location-only sampler may restore **visual** locked chrome, but locked-visible remains
noninteractive and absent from the accessibility tree. Unlock restores interaction and AX
exposure. The no-controller-presentation/no-activation invariant applies to drag, resize, hover,
Focus, layout, and render paths; Settings is the one intentional existing-controller action and
is reachable only unlocked. No visual path calls `NSApp.activate` or creates a controller.
- Reduce Motion: transition duration 0; reading motion continues.
- Focus visibility must not conditionally insert/remove header or toolbar. Screenshot and app-host
  tests compare pre/post reader bounds, text container inset, band frame, text-storage counters,
  semantic anchor, and panel frame exactly.
- Border and card remain fully visible in Focus-hidden state. Rounded-interior opacity is tested
  over both white and black checkerboards; only the antialiased exterior edge/corners may vary.

## 6. Acceptance criteria

All criteria are exact-SHA bound. Automated criteria prove only their stated layer.

1. Plan ancestry is exact: plan-only child of `1ac13db...`; implementation begins from the exact
   plan commit with a clean tree.
2. The four protected artifact hashes in section 2.1 pass, and every prior plan/result/HANDOFF
   blob matches the plan-commit preflight manifest.
3. Production root contains the exact three-stop opaque gradient, 30-point continuous radius,
   1-point/24% border, and no glow/title bar/traffic lights/ordinary scrollbar.
4. Every rounded-interior pixel in the eroded Core Graphics mask has alpha 255; white-versus-black
   checkerboard compositing produces identical interior RGB. The antialias edge is measured and
   excluded by at most a two-device-pixel ring.
5. Reader attributes are exact: system font, persisted weight mapping, `#F7F8FC`, default 42,
   1.42 line multiple, left default, 24-96/2, zero underline/link attributes, and only named-sRGB
   production color APIs.
6. Default/reference/standard layouts use 44-52-point reading padding and ≤1,050-point line
   measure. Compact mode preserves the inherited 320×180 minimum with the exact 316×52 pill at
   x=2/bottom=30, seven 44×44 targets, zero gaps/dividers/shadow, and no negative, overlapping,
   or rounded-path-exterior control/pill pixel.
7. Active band uses the exact tokens, leading accent, radius, and the sum of two actual TextKit
   line-fragment heights plus 12 (or the tested deterministic fallback); stays behind text/in the
   reading rect; remains ignored and nonselecting; literal contrast and glyph-clipping tests pass.
8. Header renders private current title plus exactly playback, lock, settings actions; all icons
   use the frozen SF Symbol/state table and have distinct IDs, labels/values/help/tooltips, focus
   indication, and ≥44×44 hit targets.
9. Quick pill renders exactly A−, A+, alignment, slower, playback, faster, Focus in that order;
   endpoint disabled states and typed command effects are exact; no view-owned state diverges.
10. Toolbar never intersects the band or text/final-line reading rect at any size in the matrix.
11. The half-open hit resolver and actual app-host hit tests prove control → corner resize → edge
    resize → title drag precedence at every tier: all seven complete 44×44 compact targets and all
    eight independent resize probes dispatch exactly once. Every resize frame remains contained.
    Drag, resize, hover, Focus, layout, and render never present a controller, activate the app,
    invoke native drag/resize, or create a second panel; unlocked Settings alone dispatches
    existing `.showController` once.
12. Focus state matrix uses the existing timer/pointer owner. Locked-visible and locked-hidden
    chrome are both noninteractive and absent from AX navigation; hidden changes only opacity.
    Reader geometry/anchor/storage/frame remain exact; Reduce Motion makes the fade immediate.
13. Appearance, hover, Focus, and 100 resize cycles cause zero full text replacement/resync,
    per-frame observation publish, logging metadata, network/permission, or signpost expansion.
14. All existing M0-M5 package/app/UI tests applicable to the current tree pass. The frozen M5
    handoff inventory/manifest verifies before and after its byte-exact disposable copy; original
    M5 Python test+validator pass only against exact `1ac13db...`. The revised WSL runner executes
    M2-M4 and staged/final M6 on current source, never M5 on M6. Every phase-appropriate M6
    mutation passes, and 6B proves the final validator has no phase-zero allowance.
15. The 1,036×460 actual app render passes the semantic Core Graphics baseline thresholds in
    section 8; compact/standard/wide structural renders pass containment/opacity.
16. Controlled-Mac Debug tests, analyze, Release build, format, no-network, checksum, and clean
    source tree pass on the exact M6 source SHA. This permits only `M6 native automated candidate`.
17. Five synthetic screenshots—unlocked, locked, Focus-hidden, bright-background, active-band—are
    source/executable/host/reference-hash bound. No private lecture, title, display identity, or
    user path enters committed evidence.
18. Independent designer/visual-verdict scores **each** supplied PNG comparison at least 90/100,
    with no critical-fail condition and written rationale. Scores are not averaged to hide a
    failure.
19. New controls pass keyboard, VoiceOver, Inspector, Increase Contrast, Differentiate Without
    Color, and Reduce Motion on a real Mac; no focus transfer to a locked overlay.
20. Exact M5 automated performance tests and the Release Instruments protocol retain all M5
    thresholds after visual changes; no render/layout loop rebuilds reader text.
21. Real extended, nonmirrored Keynote/private+audience displays prove locked focus/input,
    audience cleanliness, bright-background opacity, custom resize containment, and Focus return.
    App screenshots/offscreen renders never substitute for this.
22. `docs/validation/visual-result.md` stays PENDING until every row it marks PASS was observed on
    the recorded exact source/executable. Missing predecessor gates keep the maximum completion
    label blocked per section 11.7.
23. Independent code-reviewer, designer, verifier, then architect approve the same clean exact
    SHA; every finding preserves a RED/minimum-GREEN repair and reruns affected gates.
24. Implementation stops before M7/HANDOFF/push and makes no physical-verification claim while any
    required native/visual/physical/VoiceOver/Instruments/Keynote/display row is pending.

## 7. Planned file surface and ownership

### Create

| Path | Purpose |
|---|---|
| `PrivatePresenterApp/Overlay/OverlayVisualTokens.swift` | Exact production colors, metrics, typography mappings; no behavior authority. |
| `PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift` | Seven typed-command quick controls and responsive pill. |
| `PrivatePresenterAppTests/M6VisualTestSupport.swift` | Fixed synthetic state, sRGB/Core Graphics renderer, semantic baseline, masks/diff metrics. |
| `PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift` | Canonical token/opacity/baseline/size/focus render tests. |
| `Scripts/test_validate_project_structure_m6.py` | M6 path/token/mutation/history/claim/continuation contract. |
| `docs/validation/visual-result.md` | Additive PENDING template, later exact-SHA generic results only. |
| `.omx/handoff/private-presenter-m6/MAC-CONTINUATION.md` | Untracked content-neutral replay ledger/instructions. |
| `.omx/handoff/private-presenter-m6/m6-artifacts.sha256` | Untracked checksums for handoff artifacts. |
| `.omx/handoff/private-presenter-m6/m6-source-files.sha256` | Untracked sorted changed-source checksum manifest. |
| `.omx/handoff/private-presenter-m6/private-presenter-m6-source.tar` | Untracked exact source archive. |
| `.omx/handoff/private-presenter-m6/private-presenter-m6-wsl.bundle` | Untracked Git history/bundle with RED/GREEN ancestry. |

No committed golden PNG or third-party snapshot package is planned. Controlled screenshots stay
outside the repository and are referenced only by content-neutral evidence ID plus SHA-256.

### Modify only as required

| Path | Bounded change |
|---|---|
| `OverlayRootView.swift` | Opaque gradient/card/border, responsive metrics, overlay composition, nonintercepting interactions. |
| `OverlayChromeView.swift` | Reference header, typed icon actions, distinct accessibility IDs. |
| `ReaderTextSystem.swift` | Exact font weight/color/line-height attributes; no replacement path change. |
| `ReaderTextView.swift` | Transparent reader, responsive reading rect, exact band geometry/tokens. |
| `ReaderViewportAdapter.swift` | Read-only TextKit-2 cached-line query for deterministic band metrics; no second manager/cache owner. |
| `OverlayPanelController.swift` | Pass existing single model/reader callbacks into visual composition only if a RED requires it. |
| `PresenterAccessibility.swift` | Exact new header/toolbar semantics and target metadata. |
| `AppEffect.swift`, `AppModel.swift`, `DependencyContainer.swift` | Only thread persisted font weight through existing reader-attribute effect; no new command/authority. |
| Existing overlay/focus/accessibility/reader/panel tests | M6 assertions while retaining all prior behavior tests. |
| `Scripts/validate_project_structure.py` | Add current `validate_m6_source`; switch current `main()` from M5 to M6; retain epoch-specific M2-M5 definitions without weakening them. |
| `Scripts/verify-wsl.sh` | Route M2-M4 + staged M6 on current tree; verify/copy immutable M5 handoff and run M5 only in detached exact epoch; retain every other static gate. |

`project.yml`, package manifest, entitlements, Info.plist, Config, schema/migrator, Carbon/display/
privacy/persistence/signpost services, reference/design artifacts, old plans/results, and
`HANDOFF.md` do not change unless a named RED proves an unavoidable build integration defect and
Architect approves a bounded plan revision. `Scripts/test_validate_project_structure_m5.py` is
unconditionally outside the M6 write set. No resource manifest change is expected. The original
M5 Python test always runs with the original validator bytes from the detached exact-M5 worktree,
never against the M6 tree. The ignored `.omx/handoff/private-presenter-m5/` directory is read-only
predecessor input: M6 may verify and copy it into a disposable worktree, but may not change,
regenerate, commit, or relabel any byte.

## 8. Deterministic native Core Graphics visual harness

### 8.1 Render contract

On macOS, create the real `OverlayRootView`/TextKit reader offscreen with fixed synthetic title and
text, `darkAqua`, `en_US_POSIX`, left-to-right layout, animations disabled, 1,036×460 points, 2×
scale, 8-bit premultiplied RGBA in the named sRGB color space. Production colors use
explicit sRGB components; never device RGB. Use `NSBitmapImageRep`/`NSGraphicsContext` and AppKit
`cacheDisplay` to obtain a `CGImage`; do not use a browser, HTML, product capture API, or snapshot
library. Force layout and TextKit layout before capture. Record macOS/Xcode build for variance.

Synthetic copy is fixed and content-neutral, includes enough lines to cross the band, contains no
real title/script/display identity, and never enters normal Application Support. Test-only state
must not bypass production privacy in an executable app; it constructs the view directly in the
unit-test host.

### 8.2 Independent semantic baseline

The test harness independently constructs `CGColorSpace(name: CGColorSpace.sRGB)` and draws a
second `CGImage` using Core Graphics and **literal test-oracle** values for the rounded card,
three-stop gradient, divider, active-band region, pill, and primary control circle. It does not
import production `OverlayVisualTokens`, a production color object, or production geometry.
Text/icon regions and a two-device-pixel antialias boundary are explicit exclusion masks.

The strict corner mask is executable and independently literal: test support constructs
`RoundedRectangle(cornerRadius: 30, style: .continuous).path(in: literalBounds).cgPath` using the
framework `Shape` directly, adds that path to the named-sRGB Core Graphics context, and clips/fills
the semantic oracle. It never asks the production view/token surface for its path or radius. At
2×, filling this literal path creates the reference interior/exterior mask; one two-device-pixel
morphological dilation/erosion difference is the sole allowed antialias ring. Tests deliberately
replace the oracle mask with a 29-point path and a circular `.circular` path and require the radius/
edge metrics to fail, preventing a vacuous framework-mask assertion.

Mutation coverage is executable at three distinct layers:

1. Ordinary XCTest independently asserts that every production token converts to the expected
   named-sRGB components/API and exact metric; changing a literal makes that test RED.
2. Comparator-sensitivity tests copy the **actual rendered `CGImage`**, then independently (a)
   alter each top/middle/bottom gradient probe, (b) clear an interior alpha patch, (c) paint an
   exterior corner past the radius, and (d) translate the detected divider, band, pill, and primary
   control regions by four device pixels. Each corrupted copy is compared with the unchanged
   literal oracle and must fail its named metric. No rebuild or runtime style injection is
   implied.
3. Python M6 mutation tests alter source text in memory to prove removal/change of required token
   literals and forbidden evidence labels are rejected; they do not claim to render Swift.

Thresholds at 1,036×460/2×:

- interior eroded rounded mask: alpha exactly 255 for 100% of pixels;
- outside-corner mask: alpha 0 except the bounded two-pixel antialias ring;
- white/black checkerboard composite: interior RGB difference exactly 0;
- gradient probe rectangles: each channel within 2 of expected at top/middle/bottom;
- card bounds and measured radius: within one device pixel;
- header divider y/bounds, band bounds, pill bounds: intersection-over-union ≥0.98;
- band/pill non-glyph region mean absolute channel error ≤4/255;
- all nonexcluded structural pixels: mean absolute channel error ≤3/255, p99 ≤8/255, and at most
  1% exceed 8/255.

Typography is not hidden by the exclusion: separate tests inspect actual `NSTextStorage`
attributes and laid-out line fragment/inset/bounds. Icon tests inspect symbol names, frames,
accessibility, and action dispatch. A threshold failure is RED; do not regenerate an oracle,
expand masks, or loosen tolerance without independent designer + test-engineer + architect review.

### 8.3 Resize/focus render matrix

Render 320×180, 700×350, 1,036×460, and 1,440×460 in unlocked, locked-visible, and
locked-Focus-hidden states. Assert exact mask containment with the continuous rounded `CGPath`
and raster mask; nonnegative reading rect; seven in-bounds targets; the exact compact feasibility
equality and 30-point toolbar offset; header buttons clear of drag/resize regions; no toolbar/
band/text intersection; no alpha hole; and identical reader/band geometry across visibility
states. Assert locked-visible and locked-hidden chrome is absent from the AX tree. Pixel identity
is required only for the reader/background regions that Focus must not alter, not for the
intentionally faded chrome.

For each size, enumerate the pure resolver's half-open routes and drive actual app-host pointer/
gesture probes through the same points. At compact size, densely probe the full area of all seven
targets (including the side-overlay intersections) and the eight frozen resize points. Assert the
operation callback/identifier, not only the nominal frame: each point produces exactly one
expected control/resize/drag route, no control point resizes, and no resize probe invokes a
control or drag.

## 9. Test-first implementation slices and RED/GREEN commits

For every slice, commit `nA` with tests/validator contract only, observe the intended failure, then
commit immediate child `nB` with the minimum product/test-support change. Do not squash, amend, or
skip RED. WSL-authored Swift pairs are explicitly **unobserved candidates** until the controlled
Mac checks out each `nA` and `nB`; toolchain/configuration failure is not a valid RED.

Validator strength advances with the product ledger. Each `nA` adds its slice's exact M6 source/
path/token/mutation requirement to `Scripts/test_validate_project_structure_m6.py` and
`validate_m6_source()`, making the prior GREEN intentionally RED; each `nB` supplies the minimum
product/evidence surface and reruns both Python files. 0B is only phase-zero GREEN; 6B is the sole
final-inventory GREEN. No environment variable, mutable phase flag, or old-source allowlist may
make one checkout masquerade as another stage.

### M6.0 — ancestry, evidence, epoch validator, continuation contract (0A/0B)

0A adds M6 Python tests for exact plan ancestry, protected blobs, M3-M5 pending truth, no
dependency/permission/M7 creep, exact future M6 inventory with not-yet-built paths absent, frozen
M5 handoff inventory/manifest identity, and these runner contracts:
`testM5EpochRequiresVerifiedImmutableHandoffBeforeAndAfterCopy`,
`testVerifyWSLRunsM5OnlyInExactPreparedEpoch`,
`testPhaseZeroRequiresFutureM6InventoryAbsentAndClaimsPending`, and
`testFinalStageCannotRetainPhaseZeroAbsenceAllowance`. Expected RED is missing M6 validation and
the unsafe current WSL route. 0B adds the phase-zero validator/test plus bounded
`Scripts/verify-wsl.sh` routing; current `main()` removes its active M5 call, invokes M6 exactly
once, updates only the current success label, and all **phase-zero** M6 mutations pass.
`validate_m6_source()` reasserts the carried M0-M5 privacy/focus/accessibility/performance/history/
evidence invariants directly; it does not call or relax M5.

The WSL runner keeps its current bash syntax, provenance, fixture, source checksum, no-network,
remote, generated-project, diff, and status checks. It changes only Python epoch routing:

1. run M2-M4 tests on the current M6 tree;
2. verify the exact seven-file predecessor inventory, exact manifest hash, every manifest entry,
   and the Git bundle;
3. create a trapped detached worktree at exact M5 SHA/tree, copy the already-verified handoff into
   its ignored path, reverify the copied manifest/bundle, then run the original M5 test and
   validator there;
4. run the stage-appropriate M6 test and current validator on the current tree.

The executable epoch core is:

```bash
M5_HANDOFF="$PWD/.omx/handoff/private-presenter-m5"
M5_MANIFEST_SHA=2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9
M5_EXPECTED_FILES="$(printf '%s\n' MAC-CONTINUATION.md m5-artifacts.sha256 \
  m5-review-red-source-files.sha256 m5-source-files.sha256 \
  private-presenter-m5-review-red-source.tar private-presenter-m5-source.tar \
  private-presenter-m5-wsl.bundle | LC_ALL=C sort)"
test "$(find "$M5_HANDOFF" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)" = \
  "$M5_EXPECTED_FILES"
test "$(sha256sum "$M5_HANDOFF/m5-artifacts.sha256" | awk '{print $1}')" = \
  "$M5_MANIFEST_SHA"
(cd "$M5_HANDOFF" && sha256sum -c m5-artifacts.sha256 && \
  git bundle verify private-presenter-m5-wsl.bundle)
M5_ROOT="$(mktemp -d)"; trap 'git worktree remove --force "$M5_ROOT/tree" 2>/dev/null || true; rm -rf "$M5_ROOT"' EXIT
git worktree add --detach "$M5_ROOT/tree" 1ac13dbbdae1c53eea06033c353d22ab0919e8a5
test "$(git -C "$M5_ROOT/tree" rev-parse HEAD^{tree})" = \
  3d90bcd2c1851b36e0adc774c99a2416da7ba5b8
mkdir -p "$M5_ROOT/tree/.omx/handoff"
cp -a "$M5_HANDOFF" "$M5_ROOT/tree/.omx/handoff/private-presenter-m5"
(cd "$M5_ROOT/tree/.omx/handoff/private-presenter-m5" && \
  test "$(sha256sum m5-artifacts.sha256 | awk '{print $1}')" = "$M5_MANIFEST_SHA" && \
  sha256sum -c m5-artifacts.sha256 && git bundle verify private-presenter-m5-wsl.bundle)
(cd "$M5_ROOT/tree" && test -z "$(git status --porcelain=v1)" && \
  python3 -B Scripts/test_validate_project_structure_m5.py && \
  python3 Scripts/validate_project_structure.py)
git worktree remove --force "$M5_ROOT/tree"; rm -rf "$M5_ROOT"; trap - EXIT
python3 -B Scripts/test_validate_project_structure_m6.py
python3 Scripts/validate_project_structure.py
```

After 0B, run `./Scripts/verify-wsl.sh` once from the current M6 checkout; the script contains the
bounded routing above and must not invoke itself.

### M6.1 — opaque card and exact tokens (1A/1B)

Canonical tests: `testReferenceSurfaceUsesExactOpaqueNavyTokens`,
`testRoundedInteriorIsOpaqueOverWhiteAndBlack`,
`testNoTitleBarScrollbarGlowOrCompetingReaderFill`. 1A fails on current solid near-black/18-point
surface. 1B adds tokens/root/border and transparent reader backing only; rerun panel opacity and
configuration suites.

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M6 CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelConfigurationTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests
```

### M6.2 — typography, line measure, and active band (2A/2B)

Canonical tests: `testReaderUsesSystemTypographyAndReferenceSpacing`,
`testPersistedWeightMapsWithoutReplacingText`,
`testActiveBandUsesTwoCachedTextKit2LineFragmentsForEveryWeightAtDefaultAndLargeSizes`,
`testBandLineSelectionUsesNearestThenAdjacentWithFollowingTieBreak`,
`testActiveBandOneAndZeroFragmentFallbacksAndCompactClampDoNotClipGlyphs`,
`testBandMetricsCreateNoSecondTextLayoutManagerOrCacheOwner`,
`testLiteralTextAndBandContrastThresholds`. Expected RED is missing weight/line-height/padding and
old white band. GREEN threads weight through the existing attribute effect, applies exact
attributes/metrics/band, and proves zero full replacement/resync.

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M6 CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/ReaderTextSystemTests \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests \
  -only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests
```

### M6.3 — reference header, quick controls, Focus, accessibility (3A/3B)

Canonical tests: `testHeaderHasTitlePlaybackLockAndSettingsInOrder`,
`testQuickPillHasSevenTypedActionsInOrder`,
`testHeaderAndPillUseFrozenSymbolAndStateVariantsAtEveryTier`,
`testEveryM6IconHasDynamicSemanticsTooltipAndFortyFourPointTarget`,
`testHeaderDragNeverInterceptsControls`,
`testLockedVisibleAndHiddenChromeAreNotInteractiveOrAccessibilityNavigable`,
`testOnlyUnlockedSettingsDispatchesShowControllerWithoutActivationWorkaround`,
`testFocusModeFadesChromeWithoutChangingReaderGeometryOrAnchor`,
`testReduceMotionRemovesOnlyDecorativeFade`. Expected RED is current text-button header/missing
pill. GREEN adds views/manifest semantics and reuses existing commands/focus state only.

```bash
swift test --package-path Packages/TeleprompterCore --filter FocusChromeStateMachineTests
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M6 CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/PresenterAccessibilityTests \
  -only-testing:PrivatePresenterAppTests/FocusModeControllerTests \
  -only-testing:PrivatePresenterAppTests/AppModelTests \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests
```

### M6.4 — responsive resize, anchor, containment, performance guard (4A/4B)

Canonical tests: `testResizeMatrixKeepsEveryPixelAndControlInsideRoundedSurface`,
`testToolbarNeverOverlapsBandOrFinalLine`,
`testHundredResizesPreserveAnchorAndAvoidTextReplacement`,
`testEveryHeaderAndResizeFrameRemainsContainedExactlyOnce`,
`testCompactTierDenseHitGridRoutesEveryControlBeforeResize`,
`testAllEightResizeOperationsRemainReachableOutsideControlsAtEveryTier`. GREEN implements pure tier
metrics/hit resolution and reader layout updates through existing bounds callbacks; no minimum,
frame policy, resize callback, or native window behavior change.

```bash
swift test --package-path Packages/TeleprompterCore --filter PanelFramePolicyTests
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M6 CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayPanelControllerTests \
  -only-testing:PrivatePresenterAppTests/ReaderTextSystemTests \
  -only-testing:PrivatePresenterAppTests/ScrollSessionControllerTests \
  -only-testing:PrivatePresenterAppTests/FiftyThousandWordPerformanceTests \
  -only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests
```

### M6.5 — semantic Core Graphics baseline and mutation lock (5A/5B)

5A adds the actual-render/independent-oracle tests, production-literal assertions, and the
in-memory corrupted-render matrix from section 8.2. Expected RED is missing render support or a
structural mismatch, not an absent display/Keynote. 5B adds only native test support and any
minimum render-stability fix. No claim that compiled tests mutate production styles, no baseline-
record mode, committed golden, mask auto-expansion, test-only runtime style authority, or product
screen capture.

```bash
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-M6-Visual CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests
python3 -B Scripts/test_validate_project_structure_m6.py
```

### M6.6 — additive evidence template, WSL/Mac claim guard, reviews (6A/6B)

6A mutations omit a screenshot state/hash/reference/score/reviewer, overclaim WSL/native/physical
status, modify prior evidence, or allow a score average to mask <90. 6B adds only the PENDING
`visual-result.md` template, validator checks, and untracked continuation-package contract. A
PENDING template is not visual evidence. Review findings use additional preserved review
RED/minimum-GREEN pairs.

## 10. Logical Lore commit ledger

1. 0A/0B — **Keep visual work inside its exact evidence epoch.**
2. 1A/1B — **Make the reading card opaque before making it decorative.**
3. 2A/2B — **Keep long-form type spacious without replacing the script.**
4. 3A/3B — **Make reference chrome useful without taking Keynote input.**
5. 4A/4B — **Preserve readable structure through every contained resize.**
6. 5A/5B — **Detect visual drift without a brittle snapshot dependency.**
7. 6A/6B — **Keep visual acceptance reproducible and honestly host-bound.**
8. Evidence-only — **Bind visual observations to the exact private build.**
9. Review repair pairs — why-first finding RED, minimum GREEN, affected rerun.

Every commit uses Lore trailers. WSL Swift trailers say:
`Not-tested: Swift/AppKit/TextKit/Core Graphics/render/screenshot/VoiceOver/Instruments/Keynote/display behavior; WSL unobserved candidate`.
Never amend WSL commits to imply Mac replay or squash RED checkpoints. No push.

## 11. Verification, continuation, evidence, and claim gates

### 11.1 WSL/source-static candidate

```bash
test "$(git rev-parse "$PLAN_COMMIT^")" = 1ac13dbbdae1c53eea06033c353d22ab0919e8a5
test "$(git diff-tree --no-commit-id --name-only -r "$PLAN_COMMIT")" = \
  docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md
bash -n Scripts/*.sh
test "$(sha256sum .omx/handoff/private-presenter-m5/m5-artifacts.sha256 | awk '{print $1}')" = \
  2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9
(cd .omx/handoff/private-presenter-m5 && sha256sum -c m5-artifacts.sha256 && \
  git bundle verify private-presenter-m5-wsl.bundle)
./Scripts/verify-wsl.sh
./Scripts/test-verify-m0-proof-provenance.sh
./Scripts/verify-no-network.sh
sha256sum -c docs/validation/source-artifact-checksums.sha256
git diff --check
test -z "$(git status --porcelain=v1)"
```

The revised WSL script is the canonical aggregate router: M2-M4 and final M6 run on current source;
untouched M5 test/validator run only after verified-handoff preparation in exact detached
`1ac13db...`. Its M6 contract test mutates away the handoff hash/inventory checks, pre/post-copy
verification, exact SHA/tree checks, cleanup trap, current-M5 exclusion, current-M6 invocation,
and final-stage requirements; every mutation must fail. Current M6 independently carries its
privacy/focus/accessibility/performance/history checks.

WSL may claim Python/shell/static path/token markers, checksums, forbidden-surface absence, Git
ancestry, and diff hygiene. It cannot claim Swift compilation, Core Graphics rendering, system
font layout, AppKit/TextKit behavior, opacity pixels, screenshots, visual score, accessibility,
performance, Keynote, display, or physical behavior.

### 11.2 Checksummed controlled-Mac continuation

At the final clean WSL candidate SHA, create `.omx/handoff/private-presenter-m6/` in one
deterministic script/validator path modeled on the existing M5 handoff. `MAC-CONTINUATION.md`
records plan/source/tree SHAs, every A/B immediate-parent pair, exact expected RED/command, and
explicit `PENDING` for M3/M4/M5 plus all M6 native/render/screenshot/visual/physical/VoiceOver/
Instruments/Keynote/display proof.

Create a Git bundle containing plan through M6 candidate history, a sorted source tar, a sorted
SHA-256 manifest for every path changed from plan commit to source SHA, and an artifact manifest
covering the guide/bundle/tar/source manifest. The M6 validator rejects missing/extra/duplicate
paths, wrong hashes, nonconsecutive pairs, source/tree mismatch, or claim text. The directory is
untracked and contains no private content, screenshot, trace, display identity, or user path.

The M6 continuation records the M5 manifest SHA above as a prerequisite and instructs the Mac
operator to provide the separately preserved seven-file M5 handoff beside the clone before any
aggregate static replay. It verifies predecessor inventory/manifest/bundle before and after its
disposable copy. M6 does not embed, regenerate, or rename M5 artifacts; the predecessor handoff
remains a separate immutable evidence epoch.

On Mac, before checkout/build:

```bash
test "$(shasum -a 256 /path/to/private-presenter-m5/m5-artifacts.sha256 | awk '{print $1}')" = \
  2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9
(cd /path/to/private-presenter-m5 && shasum -a 256 -c m5-artifacts.sha256 && \
  git bundle verify private-presenter-m5-wsl.bundle)
shasum -a 256 -c m6-artifacts.sha256
git bundle verify private-presenter-m6-wsl.bundle
tar -tf private-presenter-m6-source.tar >/tmp/private-presenter-m6-tar.list
git fetch /path/to/private-presenter-m6-wsl.bundle HEAD:refs/remotes/m6-wsl/head
git switch --detach "$M6_SOURCE_SHA"
test "$(git rev-parse HEAD)" = "$M6_SOURCE_SHA"
test "$(git rev-parse HEAD^{tree})" = "$M6_TREE_SHA"
test -z "$(git status --porcelain=v1)"
shasum -a 256 -c /path/to/m6-source-files.sha256
```

Replay every RED checkout, capture the intended failure, then its immediate GREEN child/command.
A configuration, missing SDK, missing display, or missing Keynote is not a valid RED. Any source
repair changes source/tree/artifact hashes and requires a new pair plus regenerated handoff.

### 11.3 Controlled-Mac automated build/render gate

```bash
./Scripts/bootstrap-macos.sh
test "$(xcodegen --version)" = 'Version: 2.45.4'
python3 -B Scripts/test_validate_project_structure_m6.py
python3 Scripts/validate_project_structure.py
swift test --package-path Packages/TeleprompterCore
xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -skip-testing:PrivatePresenterUITests/ControllerAccessibilityUITests
xcodebuild analyze -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Analyze CODE_SIGNING_ALLOWED=NO
xcodebuild build -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData-Release CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive Packages PrivatePresenterApp \
  PrivatePresenterAppTests PrivatePresenterUITests
./Scripts/verify-macos.sh
./Scripts/verify-no-network.sh
shasum -a 256 -c docs/validation/source-artifact-checksums.sha256
git diff --check
test -z "$(git status --porcelain=v1)"
```

Hash the exact Release executable and record source/tree/toolchain/host. A green host/render test
permits only `M6 native automated candidate`; no screenshot, designer, VoiceOver, Instruments,
Keynote, display, or physical claim.

### 11.4 Controlled screenshot and reference-comparison gate

Use the exact hashed Release app, a synthetic generic script/title, a synthetic Keynote deck with
bright and dark slides, and no real lecture/private identifiers. The app never captures. A human
uses controlled macOS capture tooling and stores raw PNGs outside the repository. Capture:

1. unlocked, paused, active band on, reference/default size;
2. locked with chrome visible, Keynote frontmost;
3. locked Focus-hidden after ≥2.0 seconds;
4. bright white/near-white Keynote background showing complete interior opacity;
5. active band crossing exactly two laid-out lines, with bottom toolbar and final line clear.

Also inspect compact 320×180, standard 700×350, canonical 1,036×460, wide 1,440×460, and the
actual display's 70%×35% default; only the five representative states require evidence images.
Hash every image. The committed result records content-neutral IDs, dimensions, hashes, source/
executable, and outcomes, never absolute user paths or pixels.

Independent designer/visual-verdict evaluates **each** representative set against both protected
PNGs with this 100-point rubric: card proportions/shape 15; opaque palette/border/shadow 20;
typography/line measure/spacing 20; quiet header 10; active band 10; pill/control hierarchy 15;
Focus/resize consistency 10. Each reference score must be ≥90. Critical automatic failure:
translucent reading pixel, audience-display overlay, focus/input theft, clipping/bleed, missing
required header/pill/band, title bar/scrollbar, bright glow, automatic underline, private content,
or evidence/reference hash mismatch.

### 11.5 Accessibility and Focus regression gate

On a real extended nonmirrored display with the exact candidate, rerun the M5 physical-host UI
gate and then manually audit all new overlay controls with Full Keyboard Access, VoiceOver,
Accessibility Inspector, Increase Contrast, Differentiate Without Color, and Reduce Motion.
Verify labels/values/help/tooltips, disabled endpoints, 44-point targets, visible focus unlocked,
decorative elements ignored, no hidden-chrome navigation, no background-app activation, and
locked Keynote input retention. Result remains PENDING until observed; never infer speech/focus
from XCTest.

### 11.6 Performance, Keynote, display, and physical regression gate

- Rerun the exact M5 Release 50,000-word load/300-edit/six-minute scroll protocol and Time Profiler,
  Hangs, and Allocations thresholds. Record separate M5 predecessor state and M6 regression state;
  do not overwrite `performance-result.md` or relax a threshold.
- With real Keynote full-screen Presenter Display on confirmed private display and real extended
  audience display/projector: show/hide, lock/unlock, ordinary Space/arrows/remote, playback and
  speed controls, header/eight-zone resize at edges, Focus hide/return, and bright background.
- Prove Keynote remains frontmost/full-screen while locked, panel remains non-key/non-main,
  audience display contains no overlay pixel, every applied frame stays private, and mirroring/
  disconnect still fail closed. The five screenshots do not substitute for physical audience
  observation or predecessor M3-M5 procedures.

### 11.7 Exact-SHA claim matrix

| Highest evidence | Maximum honest label |
|---|---|
| Plan only | `M6 implementation-ready plan; all M6 proof pending` |
| WSL/static source only | `M6 WSL source candidate; M3-M5 native evidence pending` |
| Mac automated/render only | `M6 native automated candidate; visual/physical/VoiceOver/Instruments/Keynote/display proof pending` |
| Screenshots + designer only | `M6 visual candidate`; no accessibility/performance/physical completion |
| Accessibility only | `M6 accessibility candidate`; visual/performance/physical completion pending |
| Instruments only | `M6 performance-regression candidate`; predecessor/visual/physical gates pending |
| Keynote/display physical only | `M6 physical visual candidate`; predecessor/VoiceOver/Instruments/review gates pending |
| Every M6 gate passes but M3-M5 remain pending | `M6 fully exercised candidate; M3-M5/M6 completion blocked` |
| M3-M5 separately accepted + all M6 exact-SHA gates/reviews | `M6 complete`; M7 may be planned separately |

Authorization never promotes a row. A result must say PENDING rather than omit an unavailable
native, visual, physical, VoiceOver, Instruments, Keynote, or display field.

## 12. Expanded test strategy

- **Unit/pure:** token literals, sRGB contrast/compositing math, layout tiers/breakpoints, control
  command/range/disabled state, accessibility manifest, focus state, historical blob/claim schema.
- **AppKit/TextKit integration:** exact attributed-string properties, transparent reader over
  opaque root, active band layering, header hit routing, 44-point target frames, resize anchor and
  no replacement/resync, one model/panel.
- **Native render:** fixed sRGB actual `NSHostingView`/TextKit render versus independent Core
  Graphics semantic baseline, opacity checkerboards, region masks/tolerances, size/state matrix.
- **UI/assistive:** real display-gated UI tests, Full Keyboard Access, VoiceOver, Inspector,
  contrast/color/Reduce Motion; no fake topology as physical evidence.
- **Performance/observability:** exact M5 synthetic fixture/Release/Instruments; no new signpost,
  content metadata, capture, per-frame publish, or remote surface.
- **Physical e2e:** real Keynote, private+audience displays, full screen, focus/input, opacity,
  custom resize, Focus, mirroring/disconnect; human observation remains mandatory.
- **Regression/static:** every applicable M0-M5 suite, epoch validators, analyze, Release, format,
  no-network/permission/dependency, protected hashes, clean tree, exact RED/GREEN ancestry. Runner
  mutation tests remove each predecessor manifest/inventory/copy/reverify/exact-tree/cleanup/current-
  M6 marker and prove failure; stage mutations prove 0B accepts only planned absence while 6B
  requires full M6 inventory.

## 13. Deliberate pre-mortem

1. **Reference polish reintroduces translucent reading pixels.** Cause: transparent TextKit/root
   seam or local material. Detect alpha/checkerboard render and bright Keynote screenshot; prevent
   root-first alpha-1 gradient and prohibit Material; stop/hide candidate and repair before any
   visual score.
2. **Chrome controls steal input or drag overlay masks buttons.** Cause: whole-header gesture,
   locked accessibility target, activation workaround. Detect hit-priority/operation/focus tests
   and Keynote input run; keep gestures disjoint and locked click-through; revert offending slice.
3. **Responsive chrome shifts semantic reading position or masks final lines.** Cause: conditional
   layout/reserve changes or resize-time text replacement. Detect geometry/anchor/storage counters
   across state/size matrix and 100 resizes; use fixed tier reserves and existing reconcile path.
4. **Visual harness passes itself after a token changes.** Cause: expected image imports production
   tokens or masks expand. Detect literal independent oracle and mutation tests; require three-role
   approval for tolerance/mask changes.
5. **Good screenshots overstate privacy/accessibility/performance.** Cause: ordinary-window capture
   treated as physical gate. Detect claim schema/source/executable/reference hashes and mandatory
   PENDING fields; keep exact claim matrix and separate real-host gates.
6. **M6 edits erase the M5 evidence boundary.** Cause: weakening M5 stop validator or editing
   PENDING records. Detect exact M5 tree epoch suite plus protected blob manifest; carry invariants
   into M6 without rewriting history.
7. **Aggregate WSL verification either fails falsely or skips M5.** Cause: a bare detached tree
   lacks ignored M5 handoff bytes, or the old runner applies M5 rules to M6. Detect frozen seven-
   file inventory/manifest mutations and current-versus-epoch routing tests; verify/copy/reverify
   immutable M5 input, run it only at exact SHA/tree, then clean the disposable worktree. A missing
   predecessor handoff is an explicit blocked prerequisite, never a reason to skip the epoch.

## 14. Risks and mitigations

| Risk | Detection | Mitigation/stop |
|---|---|---|
| SF Symbol/font pixels vary by OS | glyph-excluded structural diff + recorded host | attribute/frame tests; designer review; never loosen opaque/geometry probes |
| Gradient duplicated in AppKit | probe color mismatch | one root fill; transparent TextKit backing |
| Border creates alpha seam | eroded/edge alpha maps | inset stroke over opaque root; bounded antialias ring |
| Band contrast too low | literal composite contrast test | fixed tokens; ≥4.5 band threshold |
| Wide text becomes unreadable | 1,440 matrix line measure | 1,050 cap/centered inset |
| Compact controls overflow, clip, or lose hit area to resize overlays | equality + CGPath/raster subset + dense actual hit grid at 320×180 | freeze 316×52 pill at x=2/bottom=30 and control-first half-open routing; keep seven 44-point actions and eight independent resize probes |
| Band metric creates a second TextKit owner or uses wrong line API | owner-count/source mutation + cached-frame selection tests | read only existing TextKit-2 adapter cache after `ensureLayout`; explicit two/one/zero rules |
| Header drag intercepts control | synthetic pointer/hit test | gesture only title/empty region |
| Focus changes layout | pre/post geometry/anchor hash | opacity/hit/accessibility only |
| Appearance rebuilds 50k text | mutation/full-replacement counters, Instruments | attributes only when preference changes; no per-resize storage change |
| Private title leaks in evidence | sentinel/content scan | fixed synthetic title; generic result IDs/hashes only |
| Screenshot permission enters app | entitlement/source audit | human/test-host capture only; no product API |
| M5 validator weakened | baseline epoch mutation suite | keep mutations; add M6 validator rather than allowlist M6 in M5 |
| M5 epoch replay lacks ignored handoff or current runner misroutes M5 | frozen manifest/inventory + pre/post-copy hash + runner source mutations | require separate immutable M5 handoff; exact detached SHA/tree; M2-M4/M6 current, M5 epoch only; trapped cleanup |
| Phase-zero validator accidentally blesses incomplete final M6 | per-slice validator RED/GREEN and final absence-allowance mutation | exact future inventory is absent at 0B; each slice promotes its requirements; 6B alone requires full inventory |
| Native gates unavailable | claim schema | remain WSL candidate/PENDING; never simulate |
| Fix invalidates screenshots | source/executable mismatch | new RED/GREEN, rebuild/hash, recapture/re-review |

## 15. Independent review and closure

1. `code-simplifier` xhigh may simplify only changed M6 production/test files without behavior or
   token change; rerun all affected gates.
2. Independent `code-reviewer` high reviews authority, alpha composition, TextKit/layout/anchor,
   hit routing, focus/nonactivation, accessibility, performance, privacy, and M6-only scope.
3. Independent `designer` high plus `vision`/visual-verdict reviews both protected PNGs, all five
   screenshot states, size matrix, exact rubric, critical failures, and score ≥90 per reference.
4. Independent `verifier` high reconstructs A/B ancestry, commands, render thresholds, screenshot/
   reference/source/executable hashes, predecessor/PENDING claims, protected bytes, and clean tree.
5. Independent `architect` high approves one-authority integration, opacity/resize/focus synthesis,
   historical validator boundary, no dependency/permission, and exact stop before M7.
6. Each finding becomes a preserved review RED/minimum GREEN; no self-approval or evidence
   promotion with a missing host gate.

## 16. ADR-006 — semantic native visual baseline on the existing overlay

**Decision.** Keep the one AppKit panel/SwiftUI chrome/TextKit reader and existing model/focus/
resize owners. Add exact shared production tokens and responsive view metrics; compare the real
native render to an independently literal Core Graphics semantic baseline; use controlled
screenshots and an independent designer for reference judgment.

**Drivers.** Opaque reference fidelity; no privacy/focus/accessibility/performance regression;
deterministic dependency-free evidence without brittle unrelated pixel identity.

**Alternatives considered.** Full-pixel committed golden; manual-only screenshots; direct pixel
diff to supplied references; HTML/WebView reproduction; separate visual state/view model;
translucent Material/glass.

**Why chosen.** Semantic regions make exact alpha, palette, bounds, band, and toolbar regressions
machine-detectable while excluding known SF glyph variance. Attribute/frame tests cover the
excluded typography/icons. Independent reference review supplies perceptual judgment. Existing
typed owners prevent visual polish from becoming a second behavior path.

**Consequences.** Mac-only render execution and controlled visual evidence remain necessary;
literal test-oracle values are intentionally duplicated and mutation-locked; compact mode has a
documented spacing degradation but never a target/privacy/opacity degradation. No new runtime
dependency, schema, permission, window, or capture path.

**Follow-ups.** M7 may aggregate accepted M0-M6 evidence and update `HANDOFF.md` only after all
predecessor and M6 gates close. A future fixed-host lab may add a full golden only through a new
ADR; it must not replace semantic alpha/geometry tests. No current follow-up may rewrite old
evidence or push.

## 17. Available roles and staffing

Installed roster: `planner`, `architect`, `critic`, `executor`, `team-executor`, `test-engineer`,
`designer`, `vision`, `debugger`, `verifier`, `code-reviewer`, `code-simplifier`, `git-master`,
`researcher`, `writer`, `explore`, `scholastic`.

- `executor`, xhigh: sole owner of shared overlay/reader/AppModel-effect integration.
- `test-engineer`, xhigh: REDs, CG harness/oracle/mutations, epoch validator, continuation and
  evidence schema; does not concurrently edit shared integration files.
- `designer`, high: exact tokens/metrics rubric and controlled screenshot comparison; no source
  self-approval.
- `vision`, high bounded: independent image-region/critical-fail assessment supporting designer.
- `debugger`, xhigh only after reproduced native render/font/layout/focus/performance failure.
- `git-master`, high bounded: immediate A/B ancestry, protected blobs, bundle/tar/checksums.
- `code-reviewer`, `verifier`, `architect`, high sequential final closure.
- `code-simplifier`, xhigh changed-files-only before full rerun.

One leader owns integration and evidence promotion. Do not parallelize files that couple root,
reader metrics, and model effects. Test harness/validator and designer rubric may proceed on
disjoint paths after their REDs.

## 18. Goal-mode, Team, and Ralph handoff

### Goal-mode suggestions

- `$ultragoal` is the default durable implementation ledger for A/B commits, host replay,
  screenshot/reference hashes, claim states, reviews, and the stop before M7.
- Use `$ultragoal + $team` only for disjoint implementation/harness/designer lanes; Ultragoal
  remains leader-owned and checkpoints Team evidence.
- `$performance-goal` is appropriate only after a reproduced M6-caused M5 threshold failure.
- `$autoresearch-goal` is inappropriate; requirements/references are committed and this is an
  implementation/validation plan.
- The owner explicitly requests an exact Ralph handoff, so Ralph is the selected persistent
  single-owner fallback; do not auto-start it during Ralplan.

### Team + Ultragoal launch hints

```text
$ultragoal Execute only the approved Private Presenter M6 plan. Preserve exact plan ancestry,
M0-M5 bytes/behavior/evidence, A/B ledger, WSL-to-Mac checksums, host claim matrix, and stop
before M7/push.

$team 3 Executor exclusively owns root/chrome/reader/model-effect integration; test-engineer owns
test-only REDs, Core Graphics oracle, validator, continuation, and evidence schema; designer owns
the frozen token/rubric and later controlled screenshots. No shared-file overlap or evidence
promotion by a worker.

omx team 3 --task 'Execute only docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md under a leader-owned Ultragoal ledger. Preserve exact M0-M5 behavior/history/evidence, keep all unavailable native/visual/physical/VoiceOver/Instruments/Keynote/display proof PENDING, execute every test-only RED then minimum GREEN, use no dependency or product capture, create the checksummed M6 Mac continuation, obtain independent code/designer/verifier/architect review, stop before M7, and do not push.'
```

Team verification before shutdown: each lane returns changed paths, RED SHA/intended observed
failure, immediate GREEN SHA/result, focused command, and no shared collision; leader runs
aggregate static/package/app/render/analyze/Release gates; controlled human runs own screenshots,
VoiceOver, Instruments, Keynote/display proof; verifier reconstructs checksums/claims; Ultragoal
records checkpoint-ready evidence. Team does not manufacture host evidence.

### Exact Ralph handoff — do not run during Ralplan

```text
PLAN=docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md
PLAN_COMMIT="$(git log -1 --format=%H -- "$PLAN")"
test -n "$PLAN_COMMIT"
test "$(git rev-parse "$PLAN_COMMIT^")" = 1ac13dbbdae1c53eea06033c353d22ab0919e8a5
test "$(git diff-tree --no-commit-id --name-only -r "$PLAN_COMMIT")" = "$PLAN"
test "$(git rev-parse HEAD)" = "$PLAN_COMMIT"
test -z "$(git status --porcelain=v1)"

$ralph Implement only Private Presenter Milestone 6 from "$PLAN" at exact plan commit
"$PLAN_COMMIT". The owner authorizes immediate M6 WSL-candidate continuation despite pending M3-
M5 native gates; this is not a waiver. Preserve all M0-M5 privacy, focus, accessibility,
performance, source/history, and evidence; keep every unavailable native, render, screenshot,
visual, physical, VoiceOver, Instruments, Keynote, and display field PENDING. Execute Lore pairs
0A/0B through 6A/6B test-first without squashing; label WSL Swift pairs unobserved; create and
verify the exact checksummed `.omx/handoff/private-presenter-m6` continuation; replay every pair
on controlled Mac. Treat the separate seven-file M5 handoff with manifest SHA-256
2370a865e22a9e1ea3d38b577e0078a9e2e62d0d02c8d30417621e04d976f8b9 as immutable prerequisite;
run M5 only in its prepared exact epoch and M6 only on current source. Implement exact opaque
#34466F/#2C3D63/#202B4B card, #F7F8FC 42-point system
type at 1.42 spacing, 30-point radius, exact active band/header/seven-control pill, responsive
contained resize, and Focus opacity-only behavior using the existing one model/panel/TextKit/
focus owners. Run the independent native Core Graphics semantic baseline, controlled synthetic
screenshots and ≥90-per-reference designer verdict, full accessibility/VoiceOver, M5
Release/Instruments thresholds, and real Keynote/private+audience display regression. Then run
independent code-reviewer → designer/vision → verifier → architect on the same exact SHA. If M3-
M5 or any M6 host gate remains pending, stop as `M6 candidate; completion blocked` and do not
enter M7, edit HANDOFF/prior evidence, add dependencies/permissions/capture, claim physical
verification, push, or amend WSL commits to imply native proof.
```

## 19. Completion and stop definition

This planning artifact is complete only after sequential Planner → Architect → Critic approval,
plan-only publication/commit, clean-tree verification, and terminal Ralplan state. That supplies
implementation readiness only.

M6 implementation is complete only when M3-M5 are separately accepted; every M6 A/B pair has
valid controlled-Mac replay; full static/package/app/render/analyze/Release/format/checksum gates
pass; five screenshots and both ≥90 designer comparisons pass; VoiceOver/accessibility,
Instruments, real Keynote/private+audience display, opacity/focus/resize/privacy proof pass; prior
bytes/evidence remain unchanged; exact source/executable/screenshot/reference checksums close;
independent code/designer/verifier/architect approve; and no known M6 errors/pending gates remain.
Otherwise retain the precise candidate label and stop before M7.

## 20. Consensus and publication record

- Planner iteration 1 grounded the exact baseline, current pre-M6 surface, protected artifacts,
  owner-authorized evidence exception, exact visual tokens/metrics/actions, semantic Core Graphics
  harness, TDD ledger, controlled screenshots/claims, checksummed Mac continuation, staffing,
  independent reviews, ADR, and exact Ralph handoff.
- Architect iteration 1: **ITERATE**. It accepted the overall authority/evidence architecture but
  required feasible compact geometry, actual TextKit line-fragment band sizing, an untouched M5
  test in a detached exact-tree replay, an explicit locked interaction/AX matrix, executable
  rendered-image corruption tests, exact three-tier icon/type mappings, and explicit sRGB.
- Planner revision 2 applied all seven repairs: the compact feasibility equation and rounded-path
  subset gate; measured two-fragment band with tested fallback; immutable M5 epoch bytes; locked-
  visible/hidden AX exclusion and Settings exception; production-literal plus corrupted-CGImage
  mutation layers; exact tier mappings; and independent named-sRGB production/oracle construction.
- Architect iteration 2: **ITERATE**. It required the existing TextKit-2 adapter rather than a
  TextKit-1 guess; an explicit current-validator M5→M6 call switch; disjoint effective routing for
  compact controls versus resize overlays; and literal SF Symbols, named-sRGB APIs, continuous-
  corner oracle construction, and one-line default title.
- Planner revision 3 repairs all iteration-2 findings: it binds band metrics to the cached
  `NSTextLineFragment.typographicBounds` evidence with deterministic two/one/zero selection;
  switches current `main()` to M6 while preserving detached M5 bytes; freezes control-first
  half-open hit resolution and eight resize probes with actual host hit testing; names every
  symbol/state/API; and constructs the independent literal continuous path for the CG mask.
- Architect iteration 3: **APPROVE** for exact normative draft SHA-256
  `51b7e47c2c9c2ac14cf79aec5ef8d5476a16ecc4e71ee9130ffe0d0983f9d9ec`. It confirmed all prior
  blockers resolved, the existing authorities/invariants preserved, executable M6-only gates and
  handoff defined, and every unavailable host/physical proof still unclaimed.
- Critic iteration 1: **ITERATE / REJECT** on Critic-candidate SHA-256
  `a4ac75d655bb4470e8da4de97f5fa510bf6aa10c165e89e09bd756f16cf02d74`. Representative M6.2,
  M6.4, and M6.5 simulations passed, but M6.0 was not executable because a bare detached worktree
  lacks ignored required M5 handoff bytes, the old aggregate runner applies M5 rules to M6, and 0B
  ambiguously required future M6.1-M6.6 surfaces.
- Planner revision 4 repairs the full Critic finding: it freezes/verifies the seven-file M5
  handoff and manifest before/after disposable copy; routes M2-M4/M6 current and M5 exact epoch in
  bounded `verify-wsl.sh`; makes the predecessor handoff a separate Mac prerequisite; and defines
  per-slice progressive validator RED/GREEN from phase-zero planned absence to 6B final inventory.
- Architect revision 4: **APPROVE** for exact normative draft SHA-256
  `5b171788a9f28365704dd96cf7910c41fc268aba1a08f664a3651daf250395c2`. It verified the M5 handoff
  inventory/manifest/bundle, exact disposable epoch route, current M6 route, progressive validator,
  separate Mac/Ralph prerequisite, and all prior architectural/evidence decisions. It also passed
  the existing M5 project validator and all 33 M5 validator contract tests.
- Critic revision 4, performed only after that approval: **APPROVE / OKAY** for exact candidate
  SHA-256 `f4fac70a62c74e38fe42f2d0129b3f968a49a7df2a02f97a8c9db7233dcfc32f`. It resimulated the
  predecessor epoch and staged M6 validator, passed principle/option, alternatives, risk,
  pre-mortem, expanded-test, acceptance, RED/GREEN, Mac/reference/review/handoff, and stop-boundary
  gates, and found M6.2/M6.4/M6.5 actionable. That candidate differed from the Architect-approved
  normative draft only by append-only status/consensus metadata; this publication adds only this
  later Critic verdict/status record.
- Sequential consensus gate: **COMPLETE**. No implementation, push, evidence rewrite, or host/
  physical verification occurred during planning.

This approved plan is the durable Ralph/Ultragoal/Team handoff artifact. Publication and its
plan-only commit do not activate execution. All native, render, screenshot, visual, physical,
VoiceOver, Instruments, Keynote, and display proof remains PENDING until actually observed on the
bound controlled Mac/physical host.
