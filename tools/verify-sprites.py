"""Verify the public sprite-atlas contract and desktop presentation quality."""

from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'claudey'


def component_sizes(alpha):
    pixels = alpha.load()
    unseen = {(x, y) for y in range(alpha.height) for x in range(alpha.width)
              if pixels[x, y] > 0}
    sizes = []
    while unseen:
        pending = [unseen.pop()]
        size = 0
        while pending:
            x, y = pending.pop()
            size += 1
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                             (x - 1, y - 1), (x + 1, y - 1),
                             (x - 1, y + 1), (x + 1, y + 1)):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    pending.append(neighbor)
        sizes.append(size)
    return sizes


def main():
    manifest = json.loads((ASSETS / 'animations.json').read_text())
    image = Image.open(ASSETS / manifest['image'])
    cell_width = manifest['cell']['width']
    cell_height = manifest['cell']['height']

    assert image.mode == 'RGBA'
    assert image.size == (manifest['sheet']['width'], manifest['sheet']['height'])
    assert cell_width >= 128 and manifest['desktopScale'] == 1, (
        'desktop preview must use at least 128 source pixels at native scale; '
        f'got {cell_width}px enlarged {manifest["desktopScale"]}x'
    )
    alpha_values = set(image.getchannel('A').get_flattened_data())
    assert 0 in alpha_values and 255 in alpha_values
    assert any(0 < value < 255 for value in alpha_values), 'silhouette edge is not antialiased'
    opaque_colors = {pixel[:3] for pixel in image.get_flattened_data() if pixel[3] == 255}
    assert opaque_colors.issubset({tuple(bytes.fromhex(color[1:]))
                                  for color in manifest['palette']})

    for index, frame in enumerate(manifest['frames']):
        box = (frame['x'], frame['y'], frame['x'] + frame['width'], frame['y'] + frame['height'])
        bounds = image.crop(box).getbbox()
        assert bounds is not None, f'frame {index} is empty'
        components = component_sizes(image.crop(box).getchannel('A'))
        assert min(components) >= 6, f'frame {index} contains tiny disconnected debris: {components}'
        left, top, right, bottom = bounds
        assert left >= 4 and right <= cell_width - 4, f'frame {index} clips horizontally: {bounds}'
        assert top >= 4 and bottom <= cell_height - 4, f'frame {index} clips vertically: {bounds}'
        expected_bottom = {6: 104, 7: 96}.get(index, manifest['anchor']['y'])
        assert bottom == expected_bottom, f'frame {index} drifts from its intended ground: {bounds}'

    for index in (14, 15):
        frame = manifest['frames'][index]
        box = (frame['x'], frame['y'], frame['x'] + frame['width'], frame['y'] + frame['height'])
        top = image.crop(box).getbbox()[1]
        assert top >= 16, f'happy-hover frame {index} has only {top}px top clearance'

    ink = tuple(bytes.fromhex(manifest['palette'][0][1:]))
    for index in (3, 4):
        frame = manifest['frames'][index]
        box = (frame['x'], frame['y'], frame['x'] + frame['width'], frame['y'] + frame['height'])
        cell = image.crop(box)
        angry_brow_pixels = [cell.getpixel((x, y)) for y in range(66, 71)
                             for x in range(44, 82)]
        assert all(pixel[:3] != ink for pixel in angry_brow_pixels), (
            f'working frame {index} contains dark marks in the angry-brow band'
        )
        assert cell.getpixel((52, 75))[:3] == ink
        assert cell.getpixel((76, 75))[:3] == ink
        assert cell.getpixel((64, 82))[:3] == ink

    for animation in manifest['animations'].values():
        assert animation['playback'] in ('loop', 'once', 'hold')
        for frame in animation['frames']:
            assert 0 <= frame['id'] < len(manifest['frames'])
            assert frame['durationMs'] > 0

    print('PASS: native 128px desktop cells, hover clearance, RGBA bounds, and animation map')


if __name__ == '__main__':
    main()
