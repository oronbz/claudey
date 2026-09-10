"""Normalize the imagegen pose study into an aligned, transparent pixel atlas.

Requires Pillow. Run from any directory; all inputs are project-local.
"""

from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'claudey'
SOURCE = ASSETS / 'source' / 'generated-poses.png'
CELL = 128
PALETTE = [
    (83, 41, 24),
    (154, 62, 30),
    (185, 77, 37),
    (211, 94, 45),
    (225, 111, 57),
    (239, 128, 66),
]
SOURCE_ROWS = [0, 313, 625, 918, 1254]


def remove_compression_debris(image):
    """Drop colored compression flecks left by the generated checkerboard."""
    alpha = image.getchannel('A')
    pixels = alpha.load()
    unseen = {(x, y) for y in range(alpha.height) for x in range(alpha.width)
              if pixels[x, y] > 0}
    components = []
    while unseen:
        component = {unseen.pop()}
        pending = list(component)
        while pending:
            x, y = pending.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                             (x - 1, y - 1), (x + 1, y - 1),
                             (x - 1, y + 1), (x + 1, y + 1)):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    component.add(neighbor)
                    pending.append(neighbor)
        components.append(component)
    largest = max(components, key=len)
    # Eyes and mouths can be isolated by a one-pixel transparent antialias gap;
    # retain meaningful marks while rejecting tiny compression debris.
    keep = set().union(*(component for component in components
                         if component is largest or len(component) >= 6))
    cleaned = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, value = image.getpixel((x, y))
            cleaned.append((r, g, b, value) if (x, y) in keep else (0, 0, 0, 0))
    image.putdata(cleaned)


def draw_calm_working_face(atlas, index):
    """Replace the generated angry brow shapes with a quiet focused face."""
    column, row = index % 4, index // 4
    origin = (column * CELL, row * CELL)
    cell = atlas.crop((*origin, origin[0] + CELL, origin[1] + CELL))
    draw = ImageDraw.Draw(cell)
    draw.rectangle((42, 66, 84, 86), fill=(*PALETTE[-1], 255))

    ink = (*PALETTE[0], 255)
    draw.ellipse((48, 72, 56, 77), fill=ink)
    draw.ellipse((72, 72, 80, 77), fill=ink)
    draw.line((61, 82, 67, 82), fill=ink, width=2)
    atlas.paste(cell, origin)


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
        mask.putdata([max(0, min(255, (r - max(g, b) - 7) * 9))
                      for r, g, b in pose.get_flattened_data()])
        bounds = mask.getbbox()
        if bounds is None:
            raise ValueError(f'No character in source cell {index}')
        pose.putalpha(mask)
        pose = pose.crop(bounds)
        # One scale preserves relative width and squash/stretch. Native 128 px
        # cells avoid enlarging a low-resolution atlas for desktop display.
        pose = pose.resize((round(pose.width * .36), round(pose.height * .36)),
                           Image.Resampling.LANCZOS)
        # Quantize opaque color while retaining clean antialiased edge alpha.
        pixels = []
        for r, g, b, alpha in pose.get_flattened_data():
            color = min(PALETTE, key=lambda c: sum((a - v) ** 2 for a, v in zip(c, (r, g, b))))
            pixels.append((*color, alpha) if alpha else (0, 0, 0, 0))
        pose.putdata(pixels)
        remove_compression_debris(pose)
        lift = {6: 8, 7: 16}.get(index, 0)
        visible = pose.getbbox()
        left, top, right, bottom = visible
        x = (CELL - (right - left)) // 2 - left
        y = 112 - bottom - lift
        if x + left < 4 or y + top < 4 or x + right > CELL - 4:
            raise ValueError(f'Pose {index} exceeds safe cell bounds')
        atlas.alpha_composite(pose, (column * CELL + x, row * CELL + y))
        rectangles.append(dict(x=column * CELL, y=row * CELL, width=CELL, height=CELL))

    for index in (3, 4):
        draw_calm_working_face(atlas, index)

    atlas.save(ASSETS / 'sprites.png')

    def animation(playback, sequence, **extra):
        return dict(playback=playback,
                    frames=[dict(id=i, durationMs=ms) for i, ms in sequence], **extra)

    manifest = dict(
        version=1, image='sprites.png',
        sheet=dict(width=512, height=512, columns=4, rows=4),
        cell=dict(width=CELL, height=CELL), anchor=dict(x=64, y=112),
        desktopScale=1, palette=['#%02x%02x%02x' % c for c in PALETTE],
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
