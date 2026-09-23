"""Verify every avatar pack against the contract the app loads."""

from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
AVATARS = ROOT / 'assets' / 'avatars'
REACTIONS = {'idle', 'working', 'finished', 'needs-you', 'resting', 'hover'}
MARGIN = 4


def component_sizes(alpha):
    pixels = alpha.load()
    unseen = {(x, y) for y in range(alpha.height) for x in range(alpha.width) if pixels[x, y] > 0}
    sizes = []
    while unseen:
        pending = [unseen.pop()]
        size = 0
        while pending:
            x, y = pending.pop()
            size += 1
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    neighbour = (x + dx, y + dy)
                    if neighbour in unseen:
                        unseen.remove(neighbour)
                        pending.append(neighbour)
        sizes.append(size)
    return sizes


def verify(directory):
    manifest = json.loads((directory / 'avatar.json').read_text())
    label = manifest['id']
    assert manifest['version'] == 2 and manifest['id'] == directory.name, label
    assert manifest['desktopScale'] == 1 and manifest['cell']['width'] >= 128, f'{label}: not native desktop cells'
    assert set(manifest['animations']) == REACTIONS, f'{label}: reactions {sorted(manifest["animations"])}'
    width, height = manifest['cell']['width'], manifest['cell']['height']
    ground = manifest['anchor']['y']

    for name, animation in manifest['animations'].items():
        strip = Image.open(directory / animation['strip'])
        where = f'{label}/{name}'
        assert strip.mode == 'RGBA', where
        assert strip.size == (width * animation['frameCount'], height), f'{where}: strip is {strip.size}'
        assert animation['playback'] in ('loop', 'once', 'hold'), where
        assert all(0 <= f['index'] < animation['frameCount'] and f['durationMs'] > 0
                   for f in animation['frames']), f'{where}: bad frame reference'
        assert {f['index'] for f in animation['frames']} == set(range(animation['frameCount'])), \
            f'{where}: strip holds unused frames'
        alpha_values = set(strip.getchannel('A').get_flattened_data())
        assert any(0 < v < 255 for v in alpha_values), f'{where}: edges are not antialiased'

        for index in range(animation['frameCount']):
            cell = strip.crop((index * width, 0, (index + 1) * width, height))
            bounds = cell.getbbox()
            assert bounds, f'{where}[{index}] is empty'
            left, top, right, bottom = bounds
            assert left >= MARGIN and right <= width - MARGIN, f'{where}[{index}] clips horizontally: {bounds}'
            assert top >= MARGIN, f'{where}[{index}] clips vertically: {bounds}'
            assert bottom <= ground, f'{where}[{index}] sinks below the ground: {bounds}'
            if name == 'hover':
                assert top >= 8, f'{where}[{index}] has only {top}px top clearance'
            debris = min(component_sizes(cell.getchannel('A')))
            assert debris >= 6, f'{where}[{index}] has a {debris}px speck'

        first = strip.crop((0, 0, width, height)).getbbox()
        assert first[3] == ground, f'{where} does not start on the ground: {first}'
    return label


def main():
    verified = [verify(directory) for directory in sorted(AVATARS.iterdir()) if directory.is_dir()]
    print('PASS: ' + ', '.join(verified))


if __name__ == '__main__':
    main()
