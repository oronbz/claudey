"""Draw every avatar and write one strip per animation plus its frame map.

Requires Pillow. Output is deterministic, so rebuilding unchanged code leaves
the committed PNGs byte-identical.
"""

from pathlib import Path
import argparse
import json
import sys
import zlib
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))

import block
import catpuccino
import ram
import soft_spark
from ink import CELL, GROUND

AVATARS = (ram, block, soft_spark, catpuccino)
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'avatars'
PAPER = (237, 235, 231, 255)


def seed(avatar, pose):
    return zlib.crc32(f'{avatar.ID}:{sorted(pose.items())}'.encode())


def grounded(frame, shift):
    moved = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    moved.paste(frame, (0, shift), frame)
    return moved


def build(avatar):
    shift = GROUND - avatar.render(avatar.NEUTRAL, seed(avatar, avatar.NEUTRAL)).getbbox()[3]
    directory = OUT / avatar.ID
    directory.mkdir(parents=True, exist_ok=True)
    animations = {}
    strips = {}
    for name, (playback, steps) in avatar.ANIMATIONS.items():
        poses = []
        for pose, _ in steps:
            if pose not in poses:
                poses.append(pose)
        strip = Image.new('RGBA', (CELL * len(poses), CELL), (0, 0, 0, 0))
        for index, pose in enumerate(poses):
            frame = avatar.render(pose, seed(avatar, pose))
            settle = shift if pose['lift'] else GROUND - frame.getbbox()[3]
            strip.paste(grounded(frame, settle), (index * CELL, 0))
        file = f'{name}.png'
        strip.save(directory / file, optimize=True)
        strips[name] = strip
        animations[name] = {
            'strip': file,
            'frameCount': len(poses),
            'playback': playback,
            'frames': [{'index': poses.index(pose), 'durationMs': ms} for pose, ms in steps],
        }
    manifest = {
        'version': 2,
        'id': avatar.ID,
        'name': avatar.NAME,
        'cell': {'width': CELL, 'height': CELL},
        'anchor': {'x': CELL // 2, 'y': GROUND},
        'desktopScale': 1,
        'animations': animations,
    }
    (directory / 'avatar.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return strips


def contact_sheet(all_strips, path):
    rows = [(avatar, name, strip) for avatar, strips in all_strips for name, strip in strips.items()]
    width = max(strip.width for _, _, strip in rows)
    sheet = Image.new('RGBA', (width, CELL * len(rows)), PAPER)
    draw = ImageDraw.Draw(sheet)
    for row, (avatar, name, strip) in enumerate(rows):
        y = row * CELL
        draw.line((0, y + GROUND, width, y + GROUND), fill=(120, 112, 104, 255))
        draw.text((4, y + 4), f'{avatar.ID} / {name}', fill=(120, 112, 104, 255))
        sheet.alpha_composite(strip, (0, y))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--contact-sheet', type=Path, help='also write a 2x review sheet on paper')
    args = parser.parse_args()
    built = [(avatar, build(avatar)) for avatar in AVATARS]
    if args.contact_sheet:
        contact_sheet(built, args.contact_sheet)
    for avatar, strips in built:
        print(f'Built {avatar.ID}: ' + ', '.join(f'{n} ({s.width // CELL})' for n, s in strips.items()))


if __name__ == '__main__':
    main()
