# Generation record

## Soft-smooth sheet (current)

`source/soft-smooth-spritesheet-v2.png` was generated with the built-in imagegen tool on September 11, 2026 as a 1254 × 1254 RGBA sheet with real transparency, a dark outline and soft shading. A focused edit corrected frame 1 to an open-eyed subtle inhale without a sparkle and frame 3 to calm concentration; the other fourteen source cells were retained unchanged. The sheet follows the same 16-frame reading order as the original prompt below, except that the hop frames carry drawn motion lines instead of relying on a build-time lift. `tools/build-sprites.py` reads it directly; the earlier chroma-key, six-colour quantization and working-face repaint steps are no longer part of the build. Poses 1 and 3 in this sheet render redder, with speckled translucent ink and a soft shadow; the build normalises both to match pose 0.

## Pixel-art study (superseded)

Generated September 10, 2026 with the built-in imagegen tool, using `source/soft-spark-reference.png` as the user's identity reference. No CLI/API fallback was used.

The selected original output is committed as `source/generated-poses.png`. An imagegen follow-up requested real transparency but returned an opaque background again; that unused variant is not an input to this project. With the user's explicit permission, `tools/build-sprites.py` produces the final atlas and map locally. The original 64 px build was later replaced by native 128 px cells with antialiased edges after desktop review found it too chunky. No project asset depends on a temporary or generator-only path.

The working-expression edit was generated with the built-in imagegen tool and is committed as `source/working-expression-reference.png`. The edit established the calm expression direction; the build script transfers only the face treatment into frames 3 and 4 so atlas geometry and the other fourteen frames remain deterministic.

## Original prompt

```text
Use case: stylized-concept. Asset type: production transparent pixel-art sprite sheet for a small desktop companion.
Use the attached Soft Spark avatar as identity reference: warm orange rounded radial fluffy spark, tall central tuft, stubby feet, tiny dark brown eyes and friendly mouth. Preserve its simple silhouette and charm, translate it into crisp pixel art, no robot.
Create ONE final PNG sprite atlas, exactly 1024x1024 pixels, a strict 4-column by 4-row grid of 256x256 cells, no gaps. Real transparent alpha background, NO checkerboard drawn, NO text, labels, borders, shadows or props. Each sprite approximately 176 pixels wide and 176 tall built from crisp square pixels on a 64x64 logical grid enlarged 4x, no antialiasing, flat limited palette. Each cell same scale and same ground anchor at local (128,220). Keep every sprite fully within its cell with generous transparent margin. Consistent body, silhouette, eyes and palette across frames; only specified movement varies.
Reading order left to right then top to bottom, 16 frames:
0 neutral friendly standing eyes open;
1 same standing subtly inhaled body, feet fixed;
2 same standing eyes closed blink;
3 working concentrated eyebrows and small pursed mouth;
4 same working looking slightly downward;
5 completion crouch anticipation smiling;
6 completion hopping 16 pixels above ground both feet lifted, happy closed eyes mouth open;
7 completion hopping 32 pixels above ground, same happy expression;
8 completion landing slightly squashed happy;
9 needs-you neutral body one side ray raised waving, questioning raised eyebrow and small round mouth;
10 same needs-you wave ray tilted outward;
11 same needs-you wave ray raised again;
12 needs-you persistent held questioning expression, slightly tilted face, raised side ray relaxed; no question-mark icon;
13 resting sleepy squashed body and feet matching sleeping reference, closed eyes peaceful smile;
14 hover happy closed curved eyes, broad joyful mouth same standing body;
15 hover same happy face subtle upward buoyant stretch with feet still anchored.
Silhouette should match user's Soft Spark reference closely. Flat warm orange and dark brown face, optional one darker orange shade. No gradients. All 16 poses represent the SAME character.
```

## Transparency correction prompt (unused output)

```text
Edit this sprite sheet. Remove the entire gray and white checkerboard background and replace with REAL transparent alpha pixels (PNG RGBA), not an image of checkerboard. Keep every orange sprite and dark brown facial feature unchanged in exactly its original position. Output exactly 1024x1024 in a strict 4x4 equal grid of 256x256 cells. All gray, white and background pixels must have alpha zero. Preserve the 16 sprites, clean hard pixel edges. Do not draw checkerboards, backgrounds, shadows or any new content.
```

## Working-expression edit prompt

```text
Use case: precise-object-edit.
Asset type: transparent production sprite atlas.
Primary request: Change only the facial expressions in animation frames 3 and 4: the top-right sprite and the leftmost sprite in the second row. They currently look angry. Make both read as calm, gentle concentration: relaxed slightly lowered or softly curved eyes, no inward V-shaped angry eyebrows, and a tiny neutral focused mouth. Claudey should look absorbed in work, never upset or stern.
Constraints: preserve the exact 512x512 canvas, transparent alpha background, strict 4x4 grid, every sprite position, silhouette, scale, orange palette, antialiased edge, and all other 14 sprites pixel-for-pixel as closely as possible. Do not add symbols, props, sweat, text, borders, backgrounds, or checkerboards. The two edited sprites must remain the same character and remain aligned to the same baseline.
```
