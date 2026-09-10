"""Normalize the imagegen pose study into an aligned, transparent pixel atlas.

Requires Pillow. Run from any directory; all inputs are project-local.
"""

from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'claudey'
SOURCE = ASSETS / 'source' / 'generated-poses.png'
CELL = 64
PALETTE = [(83, 41, 24), (177, 76, 38), (225, 111, 57), (239, 128, 66)]
SOURCE_ROWS = [0, 313, 625, 918, 1254]


def build():
    source = Image.open(SOURCE).convert('RGB')
    if source.size != (1254, 1254):
        raise ValueError('Source crops were inspected for the 1254 × 1254 pose study')
    atlas = Image.new('RGBA', (CELL * 4, CELL * 4))
    rectangles = []
    for index in range(16):
        column, row = index % 4, index // 4
        pose = source.crop((round(column * source.width / 4),
                            SOURCE_ROWS[row],
                            round((column + 1) * source.width / 4),
                            SOURCE_ROWS[row + 1]))
        # The generated background is achromatic; all character colors are warm.
        mask = Image.new('L', pose.size)
        mask.putdata([255 if r > g * 1.35 and r - b > 30 else 0
                      for r, g, b in pose.get_flattened_data()])
        bounds = mask.getbbox()
        if bounds is None:
            raise ValueError(f'No character in source cell {index}')
        pose.putalpha(mask)
        pose = pose.crop(bounds)
        # One scale for every pose preserves relative width and squash/stretch.
        pose = pose.resize((round(pose.width * .19), round(pose.height * .19)),
                           Image.Resampling.NEAREST)
        # Quantize to four opaque colors, eliminating gradient and matte fringes.
        pixels = []
        for r, g, b, alpha in pose.get_flattened_data():
            color = min(PALETTE, key=lambda c: sum((a - v) ** 2 for a, v in zip(c, (r, g, b))))
            pixels.append((*color, 255) if alpha else (0, 0, 0, 0))
        pose.putdata(pixels)
        lift = {6: 4, 7: 8}.get(index, 0)
        x = (CELL - pose.width) // 2
        y = 56 - pose.height - lift
        if x < 2 or y < 2 or x + pose.width > CELL - 2:
            raise ValueError(f'Pose {index} exceeds safe cell bounds')
        atlas.alpha_composite(pose, (column * CELL + x, row * CELL + y))
        rectangles.append(dict(x=column * CELL, y=row * CELL, width=CELL, height=CELL))

    atlas.save(ASSETS / 'sprites.png')

    def animation(playback, sequence, **extra):
        return dict(playback=playback,
                    frames=[dict(id=i, durationMs=ms) for i, ms in sequence], **extra)

    manifest = dict(
        version=1, image='sprites.png',
        sheet=dict(width=256, height=256, columns=4, rows=4),
        cell=dict(width=CELL, height=CELL), anchor=dict(x=32, y=56),
        desktopScale=2, palette=['#%02x%02x%02x' % c for c in PALETTE],
        frames=rectangles,
        animations={
            'idle': animation('loop', [(0, 1200), (1, 950), (0, 600), (2, 140), (0, 800), (1, 950)]),
            'working': animation('loop', [(3, 650), (4, 650)]),
            'finished': animation('once', [(5, 130), (6, 110), (7, 150), (6, 100), (8, 130), (14, 380)], previewReturnTo='idle'),
            'needs-you': animation('hold', [(9, 180), (10, 180), (11, 180), (10, 180), (11, 180), (12, 600)]),
            'resting': animation('hold', [(13, 1000)]),
            'hover': animation('loop', [(14, 450), (15, 450)]),
        })
    (ASSETS / 'animations.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Built assets/claudey/sprites.png and animations.json (16 frames, 6 animations)')


if __name__ == '__main__':
    build()
