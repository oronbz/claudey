"""Normalize the soft-smooth pose sheet into an aligned, transparent atlas.

Requires Pillow. Run from any directory; all inputs are project-local.
"""

from pathlib import Path
import json
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'claudey'
SOURCE = ASSETS / 'source' / 'soft-smooth-spritesheet-v2.png'
CELL = 128
GROUND = 112
SCALE = .36
SOURCE_COLUMNS = [0, 325, 631, 952, 1254]
SOURCE_ROWS = [0, 306, 629, 907, 1254]
SPECK_ALPHA = 24
SOLID_ALPHA = 240
HARD_EDGE_ALPHA = 245
EDGE_RAMP = 3
SPECKLED_INK_FRAMES = {1, 3}
INK_LUMINANCE = 110
BODY_RED = 180
PALETTE_SIZE = 8
BODY_LUMINANCE = 120
LIFT = {7: 4}


def remove_debris(image, minimum=6):
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
    keep = set().union(*(c for c in components if len(c) >= minimum))
    image.putdata([pixel if (x, y) in keep else (0, 0, 0, 0)
                   for y in range(image.height) for x in range(image.width)
                   for pixel in (image.getpixel((x, y)),)])


def clean_alpha(image):
    image.putalpha(image.getchannel('A').point(
        lambda v: 0 if v < SPECK_ALPHA else 255 if v >= SOLID_ALPHA else v))


def body_mean(image):
    body = [pixel[:3] for pixel in image.get_flattened_data()
            if pixel[3] == 255
            and .299 * pixel[0] + .587 * pixel[1] + .114 * pixel[2] > BODY_LUMINANCE]
    return tuple(sum(channel) / len(body) for channel in zip(*body))


def match_body_colour(image, reference):
    gains = [target / current for target, current in zip(reference, body_mean(image))]
    channels = [channel.point(lambda v, g=gain: min(255, round(v * g)))
                for channel, gain in zip(image.split()[:3], gains)]
    return Image.merge('RGBA', channels + [image.getchannel('A')])


def exterior_filled(mask):
    filled = mask.copy()
    width, height = filled.size
    for corner in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if filled.getpixel(corner) == 0:
            ImageDraw.floodfill(filled, corner, 128)
    return filled.point(lambda v: 255 if v != 128 else 0)


def repair_speckled_ink(image):
    """Two source poses render ink strokes riddled with translucent light
    speckles, grey halos around the eyes and a soft shadow ramp. Fill the
    strokes, repaint the halos from their neighbours and rebuild the edge."""
    alpha = image.getchannel('A')
    inside = exterior_filled(alpha.point(lambda v: 255 if v >= 100 else 0)
                             .filter(ImageFilter.MaxFilter(5))
                             .filter(ImageFilter.MinFilter(5))).filter(ImageFilter.MinFilter(3))
    luminance = image.convert('RGB').convert('L')
    ink = ImageChops.darker(inside, ImageChops.darker(
        luminance.point(lambda v: 255 if v < INK_LUMINANCE else 0),
        alpha.point(lambda v: 255 if v >= 100 else 0)))
    filled_ink = ImageChops.darker(inside, ink.filter(ImageFilter.MaxFilter(7))
                                   .filter(ImageFilter.MinFilter(7)))
    ink_pixels = [pixel[:3] for pixel, flag in zip(image.get_flattened_data(),
                                                   ink.get_flattened_data()) if flag]
    ink_colour = tuple(round(sum(channel) / len(ink_pixels)) for channel in zip(*ink_pixels))
    holes = ImageChops.subtract(filled_ink, ink)
    image.paste(Image.new('RGBA', image.size, (*ink_colour, 255)), mask=holes)

    pixels = image.load()
    width, height = image.size
    improper = {(x, y) for y in range(height) for x in range(width)
                if inside.getpixel((x, y)) and not filled_ink.getpixel((x, y))
                and (pixels[x, y][3] < HARD_EDGE_ALPHA
                     or (pixels[x, y][0] <= BODY_RED and luminance.getpixel((x, y)) >= INK_LUMINANCE))}
    proper = {(x, y) for y in range(height) for x in range(width)
              if inside.getpixel((x, y))} - improper
    while improper:
        settled = []
        for x, y in improper:
            neighbours = [pixels[nx, ny] for nx in (x - 1, x, x + 1) for ny in (y - 1, y, y + 1)
                          if (nx, ny) in proper]
            if neighbours:
                pixels[x, y] = (*(round(sum(p[k] for p in neighbours) / len(neighbours))
                                  for k in range(3)), 255)
                settled.append((x, y))
        if not settled:
            break
        improper.difference_update(settled)
        proper.update(settled)

    image.paste(Image.new('RGBA', image.size, (*ink_colour, 255)), mask=ImageChops.invert(inside))
    image.putalpha(inside.filter(ImageFilter.GaussianBlur(EDGE_RAMP / 2)))


def representative_palette(atlas):
    opaque = [pixel[:3] for pixel in atlas.get_flattened_data() if pixel[3] == 255]
    swatch = Image.new('RGB', (len(opaque), 1))
    swatch.putdata(opaque)
    quantized = swatch.quantize(PALETTE_SIZE, method=Image.Quantize.MEDIANCUT)
    colors = quantized.getpalette()[:PALETTE_SIZE * 3]
    palette = [tuple(colors[i:i + 3]) for i in range(0, len(colors), 3)]
    return sorted(set(palette), key=lambda c: .299 * c[0] + .587 * c[1] + .114 * c[2])


def build():
    source = Image.open(SOURCE).convert('RGBA')
    if source.size != (1254, 1254):
        raise ValueError('Source grid lines were inspected for the 1254 × 1254 sheet')
    atlas = Image.new('RGBA', (CELL * 4, CELL * 4))
    rectangles = []
    reference = None
    for index in range(16):
        column, row = index % 4, index // 4
        pose = source.crop((SOURCE_COLUMNS[column], SOURCE_ROWS[row],
                            SOURCE_COLUMNS[column + 1], SOURCE_ROWS[row + 1]))
        clean_alpha(pose)
        if index in SPECKLED_INK_FRAMES:
            repair_speckled_ink(pose)
        bounds = pose.getbbox()
        if bounds is None:
            raise ValueError(f'No character in source cell {index}')
        pose = pose.crop(bounds)
        pose = pose.resize((round(pose.width * SCALE), round(pose.height * SCALE)),
                           Image.Resampling.LANCZOS)
        clean_alpha(pose)
        remove_debris(pose)
        reference = reference or body_mean(pose)
        pose = match_body_colour(pose, reference)
        left, top, right, bottom = pose.getbbox()
        x = (CELL - (right - left)) // 2 - left
        y = GROUND - bottom - LIFT.get(index, 0)
        if x + left < 4 or y + top < 4 or x + right > CELL - 4:
            raise ValueError(f'Pose {index} exceeds safe cell bounds')
        atlas.alpha_composite(pose, (column * CELL + x, row * CELL + y))
        rectangles.append(dict(x=column * CELL, y=row * CELL, width=CELL, height=CELL))

    atlas.save(ASSETS / 'sprites.png')

    def animation(playback, sequence, **extra):
        return dict(playback=playback,
                    frames=[dict(id=i, durationMs=ms) for i, ms in sequence], **extra)

    manifest = dict(
        version=1, image='sprites.png',
        sheet=dict(width=512, height=512, columns=4, rows=4),
        cell=dict(width=CELL, height=CELL), anchor=dict(x=64, y=GROUND),
        desktopScale=1,
        palette=['#%02x%02x%02x' % c for c in representative_palette(atlas)],
        frames=rectangles,
        animations={
            'idle': animation('loop', [(0, 1200), (1, 950), (0, 600), (2, 140), (0, 800), (1, 950)]),
            'working': animation('loop', [(3, 650), (4, 650)]),
            'finished': animation('once', [(5, 130), (6, 110), (7, 150), (6, 100), (8, 130), (14, 380)], previewReturnTo='idle'),
            'needs-you': animation('hold', [(9, 180), (10, 180), (9, 180), (10, 180), (9, 180), (12, 600)]),
            'resting': animation('hold', [(13, 1000)]),
            'hover': animation('loop', [(14, 450), (15, 450)]),
        })
    (ASSETS / 'animations.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Built assets/claudey/sprites.png and animations.json (16 frames, 6 animations)')


if __name__ == '__main__':
    build()
