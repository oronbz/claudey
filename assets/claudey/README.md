# Soft Spark sprites

Ticket 01: a standalone asset pack and motion study based on the user's Soft Spark reference. The current source is the soft-smooth sheet: orange radial fluff with a dark outline and gentle shading, a tall central tuft, stubby feet and a simple brown face. It replaces the earlier flat pixel-art build.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Open http://127.0.0.1:8765/tools/sprite-preview/. Select any of the six reactions, interrupt it with another, pause or replay, and choose 64, 128 or 192 px. Both backgrounds play the same frame. Optional hover temporarily plays the happy reaction and restarts the selected reaction on pointer exit. Reduced-motion preference starts playback paused.

This is an asset-review tool; it does not observe sessions or implement production state priority. No Herdr, macOS app, sound, remote assets or runtime dependencies are involved.

## Asset contract

- `sprites.png`: 512 × 512 RGBA PNG, 4 × 4 grid, sixteen 128 × 128 cells. Body shading is full colour with antialiased alpha at the silhouette edge; `palette` in the map is a representative eight-colour summary sorted dark to light, not an exhaustive list.
- `animations.json`: versioned frame map. Frame IDs are zero-based row-major indices; rectangles and the anchor use pixels measured from the top-left.
- Every cell has the same ground anchor `(64, 112)` and every frame's lowest visible pixel sits on it. Draw the entire cell relative to that anchor. Do not crop and independently recenter frames. The hop is drawn into frames 6 and 7 with motion lines under the feet; the build lifts frame 7 a further 4 pixels so the arc peaks.
- Display the 128 × 128 px cell at native scale for the intended desktop presentation. The 64 px compact view downsamples it; 192 px is provided for close inspection.
- Each animation lists ordered frame IDs and positive `durationMs` values. `loop` repeats the sequence; `hold` plays it once and retains its final frame indefinitely; `once` ends after the final frame's duration and yields control to the caller. `previewReturnTo` is only the study's fallback, not an instruction to override production session state.
- `finished` denotes a response ending, not task success. `needs-you` waves briefly and holds a questioning face. `resting` is a quiet closed-eye pose with no warning or request-for-input symbol.

## Rebuild

Requires Python 3 and Pillow 12.1 or newer. The committed PNG and JSON are ready to use without installing anything.

```sh
python3 -m pip install 'Pillow>=12.1,<14'
python3 tools/build-sprites.py
python3 tools/verify-sprites.py
```

The build uses only the committed source image `source/soft-smooth-spritesheet-v2.png`, which already has real alpha but uneven grid spacing and faint stray specks. The normalization script splits the sheet at inspected column and row gaps, clears near-transparent specks, repairs frames 1 and 3 whose ink is speckled with translucent light pixels and a grey shadow ramp (every non-ink non-body pixel inside the silhouette is repainted from its neighbours and the interior made opaque, keeping the outer antialias ramp), samples every pose at one shared scale into native 128 px cells, snaps near-opaque body alpha to fully opaque, drops tiny disconnected debris, matches every frame's mean body colour to frame 0 (the source sheet renders two poses noticeably redder), and rests every frame on the shared ground while preserving squash/stretch and the drawn hop. It fails if source dimensions or safe margins change.

See `generation.md` for the exact prompt and source provenance, and `verification.md` for the review record.
