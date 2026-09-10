# Ticket 01 verification

Verified September 10, 2026.

## Automated checks

- Rebuilt the atlas and frame map from committed source; SHA-256 hashes were unchanged.
- Verified 512 × 512 RGBA output with sixteen native 128 px cells, antialiased alpha, and six opaque palette colors.
- Checked all sixteen frame bounds: at least four transparent pixels from each cell edge, baseline at y=112 except intentional hop frames at y=104 and y=96.
- Checked every frame for tiny disconnected compression debris and both hover frames for at least sixteen pixels of top clearance.
- Checked every frame reference, positive duration, and loop/once/hold value in the six animation sequences.
- Passed `node --check tools/sprite-preview/preview.js`.
- Passed TypeScript checking of the JavaScript with `tsc --noEmit --allowJs --checkJs --target ES2022 --module ES2022 --lib ES2022,DOM,DOM.Iterable tools/sprite-preview/preview.js`.
- Passed `git diff --cached --check`.

There was no existing application test suite or typechecking configuration. No production behavior has been implemented, and the spec's agreed Herdr-event testing seam does not apply to this asset-only ticket. Validation consists of the asset integrity checks above and browser inspection below.

## Browser inspection

Opened the local study in Chrome. Inspected all six reactions on light and dark stages at the default 128 px cell size, plus idle at 64 px and 192 px. The background remains transparent, facial marks remain readable, and the character remains crisp without enlarging a low-resolution canvas. Feet remain anchored, with deliberate upward motion during the hop and a low body during rest.

Observed Working looping, Finished hopping and returning to Idle, and Needs you waving then settling on frame 12 with `hold · held`. Confirmed transition from held Needs you to Working, quiet resting, happy hover, pause, replay, and pointer entry/exit restoring the selected animation. No unrelated frame drift or clipping was observed. Reduced-motion initial pause is implemented but was not separately exercised by changing the system preference.

Corrected two defects before review: imagegen's opaque checkerboard was removed with user-approved local processing; inspected source row boundaries prevent the fourth row's tuft from leaking into the wave frame.

After desktop review, replaced the 64 px atlas enlarged 2× with native 128 px cells and softer silhouette sampling. The hover frames now have 23–24 px of top clearance. A regression check reproduces the old quality failure and rejects inadequate native resolution, insufficient hover clearance, alignment drift, and disconnected checkerboard debris. Browser inspection confirmed the final hover animation has visible space above the entire tuft on both backgrounds.

## Standards

Independent review: no findings. The assets and tools use canonical Working, Finished, and Needs you terminology and keep animation independent of Herdr, consistent with CONTEXT.md and ADR 0002. No actionable baseline code smells or documented-standard violations found.

## Spec

Independent review: no findings. All six reactions, transparent fixed-size frames, explicit timing and playback behavior, light/dark previews with transition controls, committed source assets, and generation provenance are covered. The Soft Spark identity and local processing follow the user's updated instructions. The review's outstanding visual-verification condition was completed as recorded above.

Total findings: Standards 0; Spec 0. No outstanding review issues.
