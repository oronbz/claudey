# Soft Spark sprites

Ticket 01: a standalone asset pack and motion study based on the user's Soft Spark reference. The latest reference replaces the earlier robot-reference direction: orange radial fluff, a tall central tuft, stubby feet and a simple brown face, rendered as pixel art.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Open http://127.0.0.1:8765/tools/sprite-preview/. Select any of the six reactions, interrupt it with another, pause or replay, and choose 64, 128 or 192 px. Both backgrounds play the same frame. Optional hover temporarily plays the happy reaction and restarts the selected reaction on pointer exit. Reduced-motion preference starts playback paused.

This is an asset-review tool; it does not observe sessions or implement production state priority. No Herdr, macOS app, sound, remote assets or runtime dependencies are involved.

## Asset contract

- `sprites.png`: 256 × 256 RGBA PNG, 4 × 4 grid, sixteen 64 × 64 cells. Alpha is binary, with four shared opaque palette colors.
- `animations.json`: versioned frame map. Frame IDs are zero-based row-major indices; rectangles and the anchor use pixels measured from the top-left.
- Every cell has the same ground anchor `(32, 56)`. Draw the entire cell relative to that anchor. Do not crop and independently recenter frames. The hop is already baked into the atlas, at 4 and 8 pixels above the baseline.
- Display at integer scaling with nearest-neighbor sampling. Default: 128 × 128 px cell, with a roughly 96 px wide standing character; 64 px cells provide a compact option.
- Each animation lists ordered frame IDs and positive `durationMs` values. `loop` repeats the sequence; `hold` plays it once and retains its final frame indefinitely; `once` ends after the final frame's duration and yields control to the caller. `previewReturnTo` is only the study's fallback, not an instruction to override production session state.
- `finished` denotes a response ending, not task success. `needs-you` waves briefly and holds a questioning face. `resting` is a quiet closed-eye pose with no warning or request-for-input symbol.

## Rebuild

Requires Python 3 and Pillow 12.1 or newer. The committed PNG and JSON are ready to use without installing anything.

```sh
python3 -m pip install 'Pillow>=12.1,<14'
python3 tools/build-sprites.py
```

The build uses only the committed source image. The original imagegen study has an opaque checkerboard and uneven row spacing. The normalization script uses inspected row boundaries, removes achromatic background, samples at a shared scale, quantizes to four colors, and aligns feet while retaining intentional hopping and squash/stretch. It fails if source dimensions or safe margins change. The user explicitly approved this local cleanup after imagegen failed twice to provide alpha.

See `generation.md` for the exact prompt and source provenance, and `verification.md` for the review record.
