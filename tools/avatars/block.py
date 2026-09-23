"""Block: a hatched terracotta box on four thin legs."""

import math
import random
from PIL import Image

from ink import CELL, GROUND, Canvas, ellipse, rotate, rounded_rect, wobble

ID = 'block'
NAME = 'Block'

BODY = (222, 131, 80)
HATCH_DARK = (192, 102, 58)
HATCH_LIGHT = (236, 152, 102)
EYE = (26, 20, 17)
BLUSH = (238, 120, 110)

BW, BH = 80, 46
LEG_W, LEG_H = 8, 16
LEG_X = (-29.5, -16, 16, 29.5)
ARM_W, ARM_H = 11, 12.5
EYE_W, EYE_H = 9, 14
EYE_DX, EYE_Y = 15, .39


def pose(**changes):
    values = dict(sx=1, sy=1, lift=0, legs=1, tilt=0, arm_l=0, arm_r=0, arm_dy_l=0, arm_dy_r=0,
                  reach_r=1, eyes='open', look=(0, 0), splay=0, extras=())
    values.update(changes)
    return values


def draw_eye(canvas, cx, cy, p, rng, transform):
    kind = p['eyes']
    lx, ly = p['look']
    cx, cy = cx + lx, cy + ly
    if kind in ('open', 'wide', 'focus'):
        h = EYE_H * (.8 if kind == 'focus' else 1)
        pts = wobble(rounded_rect(cx, cy, EYE_W, h, min(EYE_W, h) / 2 - .01), rng, .12)
        canvas.paint(EYE, canvas.mask(transform(pts)))
        hx, hy = transform([(cx - EYE_W * .18 + lx * .15, cy - h * .24)])[0]
        size = 2.6 if kind == 'wide' else 2.2
        canvas.paint((255, 255, 255), canvas.mask(rounded_rect(hx, hy, size, size, .7)))
        if kind == 'wide':
            canvas.paint((255, 255, 255), canvas.mask(ellipse(hx + EYE_W * .4, hy + h * .42, 1.3, 1.3)))
    elif kind == 'closed':
        canvas.line(transform([(cx - EYE_W * .65, cy + 1.5), (cx, cy + 1.9), (cx + EYE_W * .65, cy + 1.5)]),
                    2.1, rng)
    elif kind == 'sleepy':
        canvas.line(transform([(cx - EYE_W * .7, cy + 2), (cx, cy + 3.2), (cx + EYE_W * .7, cy + 2)]), 2, rng)
    elif kind == 'happy':
        canvas.line(transform([(cx - EYE_W * .75, cy + 2.5), (cx - EYE_W * .35, cy - 1.8), (cx, cy - 2.6),
                               (cx + EYE_W * .35, cy - 1.8), (cx + EYE_W * .75, cy + 2.5)]), 2.3, rng)


def render(p, seed):
    rng = random.Random(seed)
    canvas = Canvas(HATCH_DARK, HATCH_LIGHT)
    lift = p['lift']
    bw, bh = BW * p['sx'], BH * p['sy']
    bottom = GROUND - LEG_H * p['legs'] - lift
    cx, cy = CELL / 2, bottom - bh / 2
    pivot = (cx, bottom)

    def transform(pts):
        return rotate(pts, pivot, p['tilt']) if p['tilt'] else pts

    for ox in LEG_X:
        x = cx + ox * p['sx']
        splay = p['splay'] * (1 if ox > 0 else -1) * (1.4 if abs(ox) > 25 else .7)
        top = bottom - 6
        h = GROUND - lift - top
        pts = rotate(rounded_rect(x, top + h / 2, LEG_W, h, 1.2), (x, top), -splay)
        canvas.shape(wobble(pts, rng, .18), rng, BODY)

    for side, angle, dy, reach in ((-1, p['arm_l'], p['arm_dy_l'], 1), (1, p['arm_r'], p['arm_dy_r'], p['reach_r'])):
        shoulder = (cx + side * bw / 2, cy + dy)
        inner = 6
        length = ARM_W * reach
        pts = rounded_rect(shoulder[0] + side * (length - inner) / 2, shoulder[1], length + inner, ARM_H, 1.4)
        pts = rotate(pts, shoulder, -side * angle)
        push = side * ARM_H / 2 * math.sin(math.radians(max(angle, 0))) * .95
        pts = [(x + push, y) for x, y in pts]
        canvas.shape(transform(wobble(pts, rng, .18)), rng, BODY)

    canvas.shape(transform(wobble(rounded_rect(cx, cy, bw, bh, 3.2), rng, .38)), rng, BODY)

    eye_y = bottom - bh + bh * EYE_Y + (BH - bh) * .15
    for side in (-1, 1):
        draw_eye(canvas, cx + side * EYE_DX * p['sx'], eye_y, p, rng, transform)

    extras = p['extras']
    if 'blush' in extras:
        for side in (-1, 1):
            canvas.tint(BLUSH, canvas.mask(transform(ellipse(cx + side * (EYE_DX + 6) * p['sx'], eye_y + 9, 8, 4))),
                        150)
    if 'motion' in extras:
        for ox in (-26, 0, 26):
            canvas.line([(cx + ox - 5, GROUND - 3 + rng.uniform(-.5, .5)), (cx + ox + 5, GROUND - 3)], 1.6, rng)
    if 'zzz' in extras:
        for zx, zy, zs in ((cx + bw / 2 - 2, bottom - bh - 8, 7), (cx + bw / 2 + 8, bottom - bh - 19, 5)):
            canvas.line([(zx, zy), (zx + zs, zy), (zx, zy + zs), (zx + zs, zy + zs)], 1.7, rng)
    if 'sparkle' in extras:
        for sx, sy, r in ((cx - bw / 2 - 6, bottom - bh - 4, 4), (cx + bw / 2 + 5, bottom - bh - 9, 3)):
            canvas.line([(sx - r, sy), (sx + r, sy)], 1.5, rng)
            canvas.line([(sx, sy - r), (sx, sy + r)], 1.5, rng)
    return canvas.downsample()


NEUTRAL = pose()
BREATH = pose(sx=.985, sy=1.04)
BLINK = pose(eyes='closed')
HAPPY = pose(eyes='happy', arm_l=12, arm_r=12, extras=('blush',))
WAVE_UP = pose(eyes='wide', look=(.5, -1.5), arm_r=80, arm_dy_r=-14, reach_r=1.3)
WAVE_OUT = pose(eyes='wide', look=(.5, -1.5), arm_r=52, arm_dy_r=-14, reach_r=.95)
HOP_LOW = pose(sx=.95, sy=1.07, lift=10, legs=.9, eyes='happy', arm_l=40, arm_r=40, splay=6, extras=('motion',))

ANIMATIONS = {
    'idle': ('loop', [(NEUTRAL, 1200), (BREATH, 950), (NEUTRAL, 600), (BLINK, 140), (NEUTRAL, 800), (BREATH, 950)]),
    'working': ('loop', [
        (pose(eyes='focus', look=(-1, 2.5), arm_l=-18, arm_dy_l=2, arm_r=4), 650),
        (pose(eyes='focus', look=(1, 2.5), arm_l=4, arm_r=-18, arm_dy_r=2), 650),
    ]),
    'finished': ('once', [
        (pose(sx=1.05, sy=.86, legs=.7, eyes='happy', arm_l=-25, arm_r=-25), 130),
        (HOP_LOW, 110),
        (pose(sx=.94, sy=1.08, lift=20, legs=.9, eyes='happy', arm_l=62, arm_r=62, splay=9), 150),
        (HOP_LOW, 100),
        (pose(sx=1.06, sy=.87, legs=.8, eyes='happy', arm_l=-10, arm_r=-10), 130),
        (HAPPY, 380),
    ]),
    'needs-you': ('hold', [
        (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180),
        (pose(eyes='wide', look=(1, -1.5), arm_r=60, arm_dy_r=-12, reach_r=1.2, tilt=-5), 600),
    ]),
    'resting': ('hold', [
        (pose(sx=1.04, sy=.84, legs=.3, eyes='sleepy', arm_l=-30, arm_r=-30, extras=('zzz',)), 1000),
    ]),
    'hover': ('loop', [
        (HAPPY, 450),
        (pose(sx=.97, sy=1.05, eyes='happy', arm_l=24, arm_r=24, extras=('blush', 'sparkle')), 450),
    ]),
}
