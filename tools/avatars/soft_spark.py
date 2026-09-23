"""Soft Spark: a radial fluffy spark with a tall tuft and two padded feet."""

import math
import random
from PIL import Image, ImageChops, ImageDraw

from ink import CELL, GROUND, SS, Canvas, capsule, ellipse, rotate, scale, wobble

ID = 'soft-spark'
NAME = 'Soft Spark'

BODY = (221, 128, 90)
HATCH_DARK = (190, 98, 64)
HATCH_LIGHT = (236, 150, 112)
FACE = (62, 34, 24)
BLUSH = (238, 116, 106)

SIZE = .9
CORE = 29 * SIZE
CENTER_Y = 72
RAYS = tuple((name, angle, length * SIZE) for name, angle, length in (
    ('tuft', -90, 42), ('upper-left', -130, 37), ('upper-right', -52, 36.5), ('left', -166, 37),
    ('right', -16, 36), ('lower-left', 160, 37.5), ('lower-right', 18, 37), ('low-left', 132, 36),
    ('low-right', 48, 35.5),
))
FEET = ((106, 39 * SIZE), (74, 39 * SIZE))
RAY_BASE, RAY_TIP = 7.4 * SIZE, 9 * SIZE
PAD_W, PAD_H = 17 * SIZE, 9 * SIZE
EYE_DX, EYE_DY = 12, -1
LEGS_OF_LYING = {'low-left', 'low-right'}


def pose(**changes):
    values = dict(sx=1, sy=1, lift=0, tilt=0, sway=0, wave=None, eyes='open', mouth='smile', look=(0, 0),
                  lying=False, extras=())
    values.update(changes)
    return values


def union(canvas, shapes):
    region = Image.new('L', canvas.image.size, 0)
    for pts in shapes:
        region = ImageChops.lighter(region, canvas.mask(pts))
    return region


def draw_face(canvas, cx, cy, p, rng, transform):
    lx, ly = p['look']
    kind = p['eyes']
    for side in (-1, 1):
        ex, ey = cx + side * EYE_DX + lx, cy + EYE_DY + ly
        if kind in ('open', 'wide', 'focus'):
            w, h = {'open': (7.5, 11), 'wide': (8.5, 12.5), 'focus': (7, 8)}[kind]
            canvas.paint(FACE, canvas.mask(transform(wobble(ellipse(ex, ey, w, h), rng, .1))))
            hx, hy = transform([(ex - w * .18, ey - h * .22)])[0]
            canvas.paint((255, 255, 255), canvas.mask(ellipse(hx, hy, 2.6, 2.6)))
            if kind == 'wide':
                canvas.paint((255, 255, 255), canvas.mask(ellipse(hx + w * .38, hy + h * .42, 1.3, 1.3)))
        elif kind == 'closed':
            canvas.line(transform([(ex - 3.6, ey + .8), (ex, ey + 1.2), (ex + 3.6, ey + .8)]), 1.9, rng, FACE)
        elif kind == 'happy':
            canvas.line(transform([(ex - 4, ey + 2), (ex - 2.2, ey - 1.6), (ex, ey - 2.3),
                                   (ex + 2.2, ey - 1.6), (ex + 4, ey + 2)]), 2, rng, FACE)
        elif kind == 'sleepy':
            canvas.line(transform([(ex - 4, ey), (ex - 2, ey + 2.2), (ex, ey + 2.8),
                                   (ex + 2, ey + 2.2), (ex + 4, ey)]), 1.9, rng, FACE)

    mx, my = cx + lx * .6, cy + 8 + ly * .5
    mouth = p['mouth']
    if mouth == 'smile':
        canvas.line(transform([(mx - 4.5, my - 1), (mx - 2, my + 1.4), (mx, my + 1.9),
                               (mx + 2, my + 1.4), (mx + 4.5, my - 1)]), 1.8, rng, FACE)
    elif mouth == 'grin':
        grin = [(mx - 5, my - 1.5)] + [(mx + 5 * math.cos(a), my - 1.5 + 5.5 * math.sin(a))
                                       for a in (math.pi * k / 16 for k in range(17))][::-1]
        canvas.paint(FACE, canvas.mask(transform(grin)))
    elif mouth == 'o':
        canvas.paint(FACE, canvas.mask(transform(ellipse(mx, my + .5, 3.8, 4.4))))
    elif mouth == 'flat':
        canvas.line(transform([(mx - 3, my + .5), (mx + 3, my + .8)]), 1.8, rng, FACE)


def render(p, seed):
    rng = random.Random(seed)
    canvas = Canvas(HATCH_DARK, HATCH_LIGHT)
    cx, cy = CELL / 2, (GROUND - CORE * .6 if p['lying'] else CENTER_Y) - p['lift']
    ground = (cx, GROUND - p['lift'])
    lying = p['lying']

    def place(pts):
        pts = scale(pts, ground, p['sx'], p['sy'])
        return rotate(pts, ground, p['tilt']) if p['tilt'] else pts

    shapes = [wobble(ellipse(cx, cy, CORE * 2, CORE * 2), rng, .3)]
    for name, angle, length in RAYS:
        if lying and name in LEGS_OF_LYING:
            continue
        if name == 'right' and p['wave'] is not None:
            angle = p['wave']
        elif name != 'tuft':
            angle += p['sway'] * (1 if math.sin(math.radians(angle)) < 0 else -.5)
        a = math.radians(angle)
        tip = (cx + length * math.cos(a), cy + length * math.sin(a))
        base = (cx + CORE * .45 * math.cos(a), cy + CORE * .45 * math.sin(a))
        shapes.append(wobble(capsule(*base, *tip, RAY_BASE, RAY_TIP), rng, .22))
    shapes = [place(s) for s in shapes]

    if not lying:
        for angle, length in FEET:
            a = math.radians(angle)
            pad = (cx + length * math.cos(a), GROUND - p['lift'] - PAD_H / 2)
            leg = capsule(cx + CORE * .5 * math.cos(a), cy + CORE * .5 * math.sin(a), *pad, 6.5, 5.5)
            foot = ellipse(pad[0] + (pad[0] - cx) * .12, pad[1], PAD_W, PAD_H)
            shapes += [scale(wobble(leg, rng, .2), ground, p['sx'], 1), scale(wobble(foot, rng, .2), ground, p['sx'], 1)]

    region = union(canvas, shapes)
    if lying:
        ImageDraw.Draw(region).rectangle((0, GROUND * SS, CELL * SS, CELL * SS), fill=0)
    canvas.silhouette(region, rng, BODY)

    face_x, face_y = place([(cx, cy)])[0]
    if lying:
        for side in (-1, 1):
            px = cx + side * 24
            paw = [(x, min(y, GROUND)) for x, y in ellipse(px, GROUND - 4, 20, 12)]
            canvas.shape(wobble(paw, rng, .15), rng, BODY, line=1.9)
        face_y -= 6
    draw_face(canvas, face_x, face_y, p, rng, lambda pts: rotate(pts, ground, p['tilt']) if p['tilt'] else pts)

    extras = p['extras']
    for side in (-1, 1):
        canvas.tint(BLUSH, canvas.mask(ellipse(face_x + side * 19, face_y + 6, 7.5, 4)),
                    150 if 'blush' in extras else 80)
    if 'ticks' in extras:
        tx, ty = place([(cx + 44, cy - 34)])[0]
        for dx, dy, ex, ey in ((0, 0, 3, -5), (4, 3, 8.5, -.5), (6, 8, 11.5, 6)):
            canvas.line([(tx + dx, ty + dy), (tx + ex, ty + ey)], 1.6, rng)
    if 'motion' in extras:
        for ox in (-16, 16):
            canvas.line([(cx + ox - 5, GROUND - 2), (cx + ox + 5, GROUND - 2 + rng.uniform(-.4, .4))], 1.5, rng)
    if 'sparkle' in extras:
        for sx, sy, r in ((cx - 40, cy - 31, 3.6), (cx + 38, cy - 38, 3)):
            canvas.line([(sx - r, sy), (sx + r, sy)], 1.4, rng)
            canvas.line([(sx, sy - r), (sx, sy + r)], 1.4, rng)
    return canvas.downsample()


NEUTRAL = pose()
BREATH = pose(sx=.985, sy=1.03)
HAPPY = pose(eyes='happy', mouth='grin', extras=('blush',))
WAVE_UP = pose(eyes='wide', mouth='o', look=(.6, -1), wave=-58, extras=('ticks',))
WAVE_OUT = pose(eyes='wide', mouth='o', look=(.6, -1), wave=-32)
HOP_LOW = pose(sx=.97, sy=1.03, lift=8, eyes='happy', mouth='grin', extras=('motion',))

ANIMATIONS = {
    'idle': ('loop', [(NEUTRAL, 1200), (BREATH, 950), (NEUTRAL, 600), (pose(eyes='closed'), 140),
                      (NEUTRAL, 800), (BREATH, 950)]),
    'working': ('loop', [
        (pose(eyes='focus', mouth='flat', look=(-1.2, 2), sway=4), 650),
        (pose(eyes='focus', mouth='flat', look=(1.2, 2), sway=-4), 650),
    ]),
    'finished': ('once', [
        (pose(sx=1.07, sy=.88, eyes='happy', mouth='smile'), 130),
        (HOP_LOW, 110),
        (pose(sx=.97, sy=1.03, lift=12, eyes='happy', mouth='grin', sway=-5), 150),
        (HOP_LOW, 100),
        (pose(sx=1.08, sy=.89, eyes='happy', mouth='grin'), 130),
        (HAPPY, 380),
    ]),
    'needs-you': ('hold', [
        (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180),
        (pose(eyes='wide', mouth='o', look=(1, -1), wave=-45, tilt=-5), 600),
    ]),
    'resting': ('hold', [
        (pose(sx=1.08, sy=.92, eyes='sleepy', mouth='smile', lying=True), 1000),
    ]),
    'hover': ('loop', [
        (HAPPY, 450),
        (pose(sx=.97, sy=1.04, eyes='happy', mouth='grin', extras=('blush', 'sparkle')), 450),
    ]),
}
