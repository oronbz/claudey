"""Ram: Herdr's ram as a little desktop sheep in Catppuccin Mocha colours, with a prompt for an eye.

He is drawn facing left and mirrored at the end, so text-like marks are written back to front.
"""

import math
import random
from PIL import Image, ImageChops, ImageDraw, ImageOps

from ink import CELL, GROUND, SS, Canvas, capsule, ellipse, rotate, scale, wobble

ID = 'ram'
NAME = 'Ram'

WOOL = (200, 208, 252)
WOOL_HATCH = ((168, 174, 211), (214, 220, 252))
CURL = (164, 170, 206)
FACE = (69, 71, 90)
FACE_HATCH = ((57, 59, 75), (106, 108, 123))
LEG_NEAR = (49, 50, 68)
LEG_FAR = (39, 40, 54)
HOOF = (27, 27, 37)
HORN = (245, 224, 220)
GLYPH = (205, 214, 244)
MOUTH = (245, 194, 231)
BLUSH = (245, 194, 231)
ACCENT = (203, 166, 247)
GRASS = (166, 227, 161)
OUTLINE = (17, 17, 27)

BODY_X, BODY_Y, BODY_W, BODY_H = 79, 74, 58, 42
BUMPS = ((-150, 12.5), (-120, 13.5), (-90, 14), (-60, 13.5), (-30, 13), (0, 12.5), (30, 13), (60, 12.5),
         (90, 13), (120, 12.5), (150, 13), (180, 12.5))
CURLS = ((70, 62, 20), (85, 59, -10), (99, 65, 30), (74, 76, 0), (90, 75, 15), (103, 80, -20), (82, 88, 10))
NECK = (57, 68)
HIP_Y = 90
LEGS = (('far', 'front', 59), ('far', 'back', 94), ('near', 'front', 66), ('near', 'back', 101))
EYE = (32, 62)


def pose(**changes):
    values = dict(sx=1, sy=1, lift=0, drop=0, head=0, head_drop=0, legs=None, tail=0, eyes='prompt',
                  mouth='smile', lying=False, extras=())
    values.update(changes)
    return values


def union(canvas, shapes):
    region = Image.new('L', canvas.image.size, 0)
    for pts in shapes:
        region = ImageChops.lighter(region, canvas.mask(pts))
    return region


def spiral(cx, cy, radius, start, sweep, tighten, steps=60):
    return [(cx + radius * (1 - tighten * t) * math.cos(math.radians(start + sweep * t)),
             cy + radius * (1 - tighten * t) * math.sin(math.radians(start + sweep * t)))
            for t in (k / steps for k in range(steps + 1))]


def draw_eye(canvas, kind, rng, head):
    x, y = EYE
    if kind in ('prompt', 'cursor-off'):
        canvas.line(head([(x + 8, y - 3.8), (x + 3.8, y), (x + 8, y + 3.8)]), 2.3, rng, GLYPH)
        if kind == 'prompt':
            canvas.line(head([(x + 1.8, y + 4), (x - 3, y + 4)]), 2.3, rng, GLYPH)
    elif kind == 'happy':
        canvas.line(head([(x - 4.2, y + 2.4), (x - 2.3, y - 1.6), (x, y - 2.6), (x + 2.3, y - 1.6),
                          (x + 4.2, y + 2.4)]), 2.3, rng, GLYPH)
    elif kind == 'closed':
        canvas.line(head([(x - 4.2, y), (x - 2.1, y + 2.1), (x, y + 2.7), (x + 2.1, y + 2.1), (x + 4.2, y)]),
                    2.2, rng, GLYPH)


def draw_mouth(canvas, kind, rng, head):
    if kind == 'smile':
        canvas.line(head([(23.5, 77.2), (26.5, 79), (30, 78.2)]), 1.6, rng)
    elif kind == 'chew':
        canvas.line(head([(23.5, 78.4), (27, 77.8), (30, 79)]), 1.6, rng)
    elif kind == 'open':
        jaw = [(29.5 + 3.4 * math.cos(math.radians(a)), 77.6 + 3.8 * math.sin(math.radians(a))) for a in range(0, 181, 12)]
        canvas.shape(head(wobble(jaw, rng, .08)), rng, MOUTH, line=1.6)


def accent(canvas, pts, width, rng, colour=ACCENT):
    canvas.line(pts, width + 1.8, rng)
    canvas.line(pts, width, rng, colour)


def render(p, seed):
    rng = random.Random(seed)
    canvas = Canvas(*FACE_HATCH, OUTLINE)
    ground = GROUND - p['lift']
    dy = p['drop'] - p['lift']
    anchor = (CELL / 2, ground)
    lying = p['lying']

    def place(pts):
        return scale([(x, y + dy) for x, y in pts], anchor, p['sx'], p['sy'])

    def head(pts):
        return place([(x, y + p['head_drop']) for x, y in rotate(pts, NECK, p['head'])])

    if not lying:
        swings = p['legs'] or {}
        for depth, end, x in LEGS:
            swing, raise_ = swings.get((depth, end), swings.get(end, (0, 0)))
            hip = place([(x, HIP_Y)])[0]
            foot_y = ground - 2 - raise_
            foot = (hip[0] - (foot_y - hip[1]) * math.tan(math.radians(swing)), foot_y)
            colour = LEG_FAR if depth == 'far' else LEG_NEAR
            canvas.shape(wobble(capsule(*hip, *foot, 4.4, 3.9), rng, .15), rng, colour, line=1.9)
            canvas.shape(wobble(ellipse(foot[0] - .6, foot[1] - .4, 9, 5), rng, .1), rng, HOOF, line=1.7)

    width, height = BODY_W * (1.06 if lying else 1), BODY_H
    wool = [wobble(ellipse(BODY_X, BODY_Y, width - 8, height - 6), rng, .3)]
    for angle, r in BUMPS:
        a = math.radians(angle)
        wool.append(wobble(ellipse(BODY_X + (width / 2 - 9) * math.cos(a), BODY_Y + (height / 2 - 8) * math.sin(a),
                                   r * 2, r * 2), rng, .25))
    tail = rotate(ellipse(109, 67, 13, 12), (104, 71), p['tail'])
    wool.append(wobble(tail, rng, .25))
    region = union(canvas, [place(s) for s in wool])
    if lying:
        ImageDraw.Draw(region).rectangle((0, GROUND * SS, CELL * SS, CELL * SS), fill=0)
    canvas.hatch_colours = WOOL_HATCH
    canvas.silhouette(region, rng, WOOL)
    canvas.hatch_colours = FACE_HATCH
    for cx, cy, turn in CURLS:
        arc = [(cx + 2.8 * math.cos(math.radians(a + turn)), cy + 2.4 * math.sin(math.radians(a + turn)))
               for a in range(150, 400, 25)]
        canvas.line(place(arc), 1.3, rng, CURL)

    if lying:
        for x in (50, 63):
            nub = [(px, min(py, GROUND)) for px, py in ellipse(x, GROUND - 3.5, 15, 9)]
            canvas.shape(wobble(nub, rng, .12), rng, LEG_NEAR, line=1.7)

    skull = ellipse(41, 60, 31, 28)
    snout = capsule(39, 66, 27, 71, 12.5, 10)
    neck = capsule(*NECK, 43, 62, 11, 11)
    face = union(canvas, [head(wobble(s, rng, .2)) for s in (skull, snout, neck)])
    canvas.silhouette(face, rng, FACE)
    ear = rotate(ellipse(61, 65, 14, 7), (55, 64), 28)
    canvas.shape(head(wobble(ear, rng, .12)), rng, FACE, line=1.8)

    horn = spiral(50, 58, 11.5, -155, 470, .72)
    canvas.line(head(horn), 7.2, rng)
    canvas.line(head(horn), 4.3, rng, HORN)

    draw_eye(canvas, p['eyes'], rng, head)
    draw_mouth(canvas, p['mouth'], rng, head)

    extras = p['extras']
    canvas.tint(BLUSH, canvas.mask(head(ellipse(36.5, 71.5, 8.5, 4.4))), 150 if 'blush' in extras else 70)
    if 'grass' in extras:
        for x, lean, h in ((21, -1.5, 6), (24.5, .5, 8), (28, 2, 6.5), (32, -1, 5)):
            accent(canvas, [(x, GROUND - 1), (x + lean, GROUND - h)], 1.6, rng, GRASS)
    if 'bang' in extras:
        bx, by = head([(36, 34)])[0]
        accent(canvas, [(bx, by - 8), (bx + .4, by)], 2.4, rng)
        canvas.paint(OUTLINE, canvas.mask(ellipse(bx + .5, by + 4.2, 4.8, 4.8)))
        canvas.paint(ACCENT, canvas.mask(ellipse(bx + .5, by + 4.2, 3, 3)))
    if 'sound' in extras:
        sx, sy = head([(15, 72)])[0]
        for r in (4, 7.5):
            arc = [(sx + r * math.cos(math.radians(a)), sy + r * math.sin(math.radians(a))) for a in range(145, 216, 10)]
            canvas.line(arc, 1.5, rng)
    if 'zzz' in extras:
        for zx, zy, zs in ((30, 56, 6.5), (40, 45, 5)):
            accent(canvas, [(zx + zs, zy), (zx, zy), (zx + zs, zy + zs), (zx, zy + zs)], 1.7, rng)
    if 'sparkle' in extras:
        for sx, sy, r in ((16, 46, 4.6), (108, 44, 3.8)):
            cross = ([(sx - r, sy), (sx + r, sy)], [(sx, sy - r), (sx, sy + r)])
            for stroke in cross:
                canvas.line(stroke, 3.6, rng)
            for stroke in cross:
                canvas.line(stroke, 1.8, rng, ACCENT)
    if 'motion' in extras:
        for ox in (-22, 22):
            canvas.line([(79 + ox - 5, GROUND - 2), (79 + ox + 5, GROUND - 2 + rng.uniform(-.4, .4))], 1.5, rng)
    return ImageOps.mirror(canvas.downsample())


def trot(a, b, **changes):
    return pose(legs={('near', 'front'): a, ('far', 'back'): a, ('far', 'front'): b, ('near', 'back'): b},
                **changes)


FORWARD, BACK, PLANTED, PASSING = (20, 0), (-16, 0), (0, 0), (6, 5)
TUCK = {'front': (28, 7), 'back': (-26, 7)}

NEUTRAL = pose()
BREATH = pose(sx=.99, sy=1.03)
GRAZE = pose(head=-44, head_drop=11, eyes='closed', mouth='chew', extras=('grass',))
CHEW = pose(head=-42, head_drop=11, eyes='closed', mouth='smile', extras=('grass',))
HAPPY = pose(eyes='happy', mouth='smile', tail=14, extras=('blush',))
BLEAT = pose(head=20, eyes='prompt', mouth='open', tail=-8, extras=('sound', 'bang'))
LISTEN = pose(head=10, eyes='prompt', mouth='smile', extras=('bang',))
HOP_LOW = pose(sy=1.04, lift=8, legs=TUCK, eyes='happy', tail=18, extras=('motion',))

ANIMATIONS = {
    'idle': ('loop', [
        (NEUTRAL, 900), (pose(eyes='cursor-off'), 500), (NEUTRAL, 500), (BREATH, 900), (NEUTRAL, 500),
        (GRAZE, 380), (CHEW, 380), (GRAZE, 380), (CHEW, 380), (NEUTRAL, 700), (pose(eyes='closed'), 140),
        (BREATH, 900),
    ]),
    'working': ('loop', [
        (trot(FORWARD, BACK), 170),
        (trot(PLANTED, PASSING, drop=-1, eyes='prompt'), 170),
        (trot(BACK, FORWARD, eyes='cursor-off'), 170),
        (trot(PASSING, PLANTED, drop=-1, eyes='cursor-off'), 170),
    ]),
    'finished': ('once', [
        (pose(sx=1.04, sy=.9, drop=3, eyes='happy'), 130),
        (HOP_LOW, 110),
        (pose(sy=1.04, lift=13, legs=TUCK, eyes='happy', tail=24), 150),
        (HOP_LOW, 100),
        (pose(sx=1.05, sy=.9, drop=3, eyes='happy', tail=10), 130),
        (HAPPY, 380),
    ]),
    'needs-you': ('hold', [
        (BLEAT, 260), (LISTEN, 220), (BLEAT, 260), (LISTEN, 220), (BLEAT, 260), (LISTEN, 600),
    ]),
    'resting': ('hold', [
        (pose(sy=.94, drop=21, head=-14, head_drop=4, eyes='closed', mouth='smile', lying=True,
              extras=('zzz',)), 1000),
    ]),
    'hover': ('loop', [
        (HAPPY, 300),
        (pose(sx=.99, sy=1.03, eyes='happy', mouth='open', tail=-14, extras=('blush', 'sparkle')), 300),
    ]),
}
