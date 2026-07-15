# Milestone 2 macOS Physical Smoke Result — 2026-07-15

> **M2 physical smoke result: PASS**
>
> The package-level Keynote/private-display smoke test passed on the real Mac.
> M3 may begin.

## Result identity

- Source commit: `3526b4fa22f94c63c0237d55071f0d464a126e3a`
- Tested executable SHA-256: `93016a94d19ad3ba69f240715dfb63edfab06d27b9a099c50c9e2452028160c6`
- Tested application: `/Applications/Private Presenter.app`
- Updated package application: `/Users/thomas/Desktop/package/Private Presenter.app`
- Local evidence: `/Users/thomas/Library/Application Support/Private Presenter/Validation/2026-07-15-m2-smoke`
- Test time: 2026-07-15 19:35–19:47 KST

The original Desktop package binary was built with Xcode 16.4/macOS 15.5 and
crashed immediately after display confirmation on this Mac with
`-[__NSCFNumber length]: unrecognized selector`. The application was rebuilt
from the source checkout with the current Xcode 26.6/macOS 26.5.2 toolchain.
The rebuilt executable passed the same confirmation path and was copied back
into the Desktop package.

## Environment

- Mac: MacBook Pro, Apple M4 Pro, arm64
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- XcodeGen: 2.45.4
- Keynote: 14.5
- Presentation: `APHG Unit 1 Topic 1_ Introduction to Maps`
- Private display: Built-in Retina Display / Color LCD, 3024×1964 pixels
- Audience display: LG ULTRAGEAR, 2560×1440 pixels
- Display mode: extended; mirroring off

## Smoke sequence

| Gate | Result | Evidence |
| --- | --- | --- |
| Confirm the built-in display as private | PASS | Controller confirmed `Built-in Retina Display` and opened without crashing |
| Start Keynote Presenter Display with the audience slide on the LG | PASS | `captures/00-keynote-presenter-before-show.png`, `captures/00-keynote-audience-before-show.png` |
| Show the overlay with Control-Option-H | PASS | Overlay visible on the built-in display at the bounded `statusBar` level |
| Keep the audience display clean | PASS | `captures/01-overlay-shown-audience.png` and `captures/08-final-locked-audience.png` contain no overlay |
| Keep Keynote focus and avoid panel key/main transitions | PASS | Keynote remained frontmost; diagnostics recorded `panelKey=false` and `panelMain=false` before/after show, unlock, and lock |
| Advance with the right arrow and Space | PASS | `captures/03-after-right-*` and `captures/04-after-space-*`; Keynote remained frontmost |
| Click through the locked overlay | PASS | Click at the overlay region advanced the audience presentation while the presenter overlay stayed visible |
| Hide and restore with Control-Option-H | PASS | `captures/06-after-hide-*` and `captures/07-after-reshow-*` |
| Unlock and relock the panel | PASS | Controller changed `Unlock` → `Lock` → `Unlock`; Keynote remained frontmost |
| Final locked state | PASS | `captures/08-final-locked-presenter.png`, `captures/08-final-locked-audience.png` |

The final controller proof snapshot reported:

```text
level=statusBar | panels=1 | borderless=true | nonactivating=true |
resizable=false | allSpaces=true | fullScreenAuxiliary=true | opaqueInterior=true
```

## Automated checks completed

- XcodeGen bootstrap: PASS
- Structure and M0 proof-provenance checks: PASS
- `swift test --package-path Packages/TeleprompterCore`: PASS, 42 tests, 0 failures
- Standalone Debug app build with Xcode 26.6/macOS 26.5 SDK: PASS
- Xcode analyze: PASS
- Release arm64 app build: PASS
- Swift-format lint: PASS
- No-network/prohibited-surface audit: PASS

The repository's combined `xcodebuild test` command was interrupted after its
app-host test worker failed to materialize under this Xcode 26.6 environment.
It produced no source-test failures; the standalone app build and the complete
Foundation test suite passed. This remains a separate test-host tooling
follow-up, not a failure of the M2 physical smoke gate.

## Milestone decision

M2's package-level real-Mac smoke requirement is complete. Proceed to M3.

## Repository provenance note

This result is preserved as the project owner's real-Mac completion record. The supplied
`3526b4fa22f94c63c0237d55071f0d464a126e3a` source identity is the pre-M2 baseline and
does not independently reconstruct the rebuilt executable. The executable SHA-256 and
physical observations bind the tested application. Tom explicitly accepted this result
as M2 completion and authorized M3. Exact rebuilt-source-to-executable provenance remains
a release-evidence follow-up; it is not represented here as completed and does not
retroactively alter the historical M0 evidence.
