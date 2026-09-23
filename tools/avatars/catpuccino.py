"""Catpuccino: an anime caramel cat sitting in a cappuccino cup, wearing its foam, with its tail for a handle."""

import math
import random
from PIL import Image, ImageChops, ImageFilter

from ink import SS, Canvas, capsule, ellipse, rotate, scale, wobble

ID = 'catpuccino'
NAME = 'Catpuccino'

FUR = (208, 156, 114)
FUR_HATCH = ((190, 140, 102), (222, 178, 142))
CREAM = (248, 234, 216)
FOAM = (250, 244, 236)
CUP = (240, 232, 228)
SAUCER = (222, 212, 208)
COFFEE = (120, 80, 58)
EYE = (36, 26, 26)
PINK = (245, 194, 231)
MOUTH = (232, 150, 170)
IRIS = (92, 70, 64)
BLUSH_MARK = (190, 90, 120)
STEAM = (232, 234, 244)
ACCENT = (203, 166, 247)
OUTLINE = (46, 30, 26)

RIM_Y = 74
HEAD_W, HEAD_H = 60, 46
PAWS = {
    'rim': ((49, 76), (79, 76), 14, 9, False),
    'press': ((49, 77.5), (79, 72.5), 15, 8, False),
    'press-other': ((49, 72.5), (79, 77.5), 15, 8, False),
    'up': ((34, 42), (94, 42), 13, 12, True),
    'wave-up': ((49, 76), (97, 42), 14, 12, True),
    'wave-out': ((49, 76), (104, 53), 14, 12, True),
}


def pose(**changes):
    values = dict(lift=0, rise=0, tilt=0, breath=1, eyes='open', mouth='w', paws='rim', ear=0, tail=0,
                  steam=None, extras=())
    values.update(changes)
    return values


def hatched(canvas, fill):
    canvas.hatch_colours = (tuple(int(c * .84) for c in fill), tuple(int(c + (255 - c) * .2) for c in fill))


def filled(canvas, pts, rng, fill, line=2.2):
    hatched(canvas, fill)
    canvas.shape(pts, rng, fill, line)


def union(canvas, shapes):
    region = Image.new('L', canvas.image.size, 0)
    for pts in shapes:
        region = ImageChops.lighter(region, canvas.mask(pts))
    return region


def segment(p, q, n=24):
    return [(p[0] + (q[0] - p[0]) * k / n, p[1] + (q[1] - p[1]) * k / n) for k in range(1, n)]


def arc(cx, cy, rx, ry, start, end, steps=40):
    return [(cx + rx * math.cos(math.radians(start + (end - start) * k / steps)),
             cy + ry * math.sin(math.radians(start + (end - start) * k / steps))) for k in range(steps + 1)]


def rounded(pts, rounds=4):
    for _ in range(rounds):
        smooth = []
        for i, p in enumerate(pts):
            q = pts[(i + 1) % len(pts)]
            smooth += [(p[0] * .75 + q[0] * .25, p[1] * .75 + q[1] * .25), (p[0] * .25 + q[0] * .75, p[1] * .25 + q[1] * .75)]
        pts = smooth
    return pts


CHEEK_TUFTS = ((150, 6), (165, 7), (180, 5.5))


def cheek_tuft(hx, hy, angle, length):
    pts = []
    for a, r in ((angle - 7, 0), (angle - 2, length * .7), (angle + 1, length), (angle + 7, 0)):
        rad = math.radians(a)
        pts.append((hx + (HEAD_W / 2 - 2 + r) * math.cos(rad), hy + (HEAD_H / 2 - 2 + r) * math.sin(rad)))
    pts.append((hx + (HEAD_W / 2 - 8) * math.cos(math.radians(angle)), hy + (HEAD_H / 2 - 8) * math.sin(math.radians(angle))))
    return rounded(pts, 2)


def fluffy(cx, cy, rx, ry, spike, turn, spikes=9):
    pts = []
    for k in range(spikes * 2):
        a = math.radians(turn + 180 * k / spikes)
        r = 1 + (spike / max(rx, ry) if k % 2 else 0)
        pts.append((cx + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
    return rounded(pts, 2)


def heart(cx, cy, size):
    return [(cx + size * 16 * math.sin(t) ** 3 / 17,
             cy - size * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17)
            for t in (math.tau * k / 60 for k in range(60))]


def accent(canvas, pts, width, rng, colour=ACCENT):
    canvas.line(pts, width + 1.8, rng)
    canvas.line(pts, width, rng, colour)


def cup_front():
    top = arc(64, RIM_Y, 33, 4.5, 0, 180)
    bottom = arc(64, 101, 25, 4, 180, 0)
    return top + segment(top[-1], bottom[0]) + bottom + segment(bottom[-1], top[0])


def draw_eyes(canvas, hx, hy, p, rng, face):
    for side in (-1, 1):
        ex, ey = hx + side * 13, hy + 2
        kind = p['eyes']
        if kind in ('open', 'wide', 'focus'):
            w, h = {'open': (11.5, 15), 'wide': (12.5, 16.5), 'focus': (11, 13)}[kind]
            dy = 1.5 if kind == 'focus' else 0
            canvas.paint(EYE, canvas.mask(face(wobble(ellipse(ex, ey + dy, w, h), rng, .1))))
            canvas.paint(IRIS, canvas.mask(face(ellipse(ex, ey + dy + h * .22, w * .62, h * .42))))
            canvas.paint((255, 255, 255), canvas.mask(face(ellipse(ex - w * .2, ey + dy - h * .2, 4.4, h * .32))))
            canvas.paint((255, 255, 255), canvas.mask(face(ellipse(ex + w * .22, ey + dy + h * .18, 2, 2))))
        elif kind == 'happy':
            canvas.line(face([(ex - 5.5, ey + 3), (ex - 3, ey - 2.2), (ex, ey - 3.4), (ex + 3, ey - 2.2),
                              (ex + 5.5, ey + 3)]), 2.5, rng, EYE)
        elif kind == 'closed':
            canvas.line(face([(ex - 5.5, ey), (ex - 2.8, ey + 3), (ex, ey + 3.7), (ex + 2.8, ey + 3),
                              (ex + 5.5, ey)]), 2.4, rng, EYE)
        elif kind == 'blink':
            canvas.line(face([(ex - 5.2, ey + 1.5), (ex, ey + 2.2), (ex + 5.2, ey + 1.5)]), 2.4, rng, EYE)


def draw_mouth(canvas, hx, hy, p, rng, face):
    filled(canvas, face([(hx - 2.8, hy + 9), (hx + 2.8, hy + 9), (hx, hy + 11.8)]), rng, PINK, line=1.3)
    mouth = p['mouth']
    if mouth == 'w':
        canvas.line(face([(hx - 5, hy + 13), (hx - 2.5, hy + 15.2), (hx, hy + 12.6), (hx + 2.5, hy + 15.2),
                          (hx + 5, hy + 13)]), 1.5, rng)
    elif mouth == 'open':
        jaw = arc(hx, hy + 13.2, 4, 4.4, 0, 180, 20)
        filled(canvas, face(wobble(jaw, rng, .08)), rng, MOUTH, line=1.5)
    elif mouth == 'flat':
        canvas.line(face([(hx - 3.5, hy + 14), (hx + 3.5, hy + 14.2)]), 1.5, rng)
    for side in (-1, 1):
        for dy, ey in ((10, 8), (13.5, 15)):
            canvas.line(face([(hx + side * 20, hy + dy), (hx + side * 35, hy + ey)]), 1.2, rng)
        for k in (-1, 0, 1):
            x = hx + side * 18 + k * 2.6
            canvas.line(face([(x + 1.2, hy + 9.5), (x - 1.2, hy + 13.5)]), 1.2, rng, BLUSH_MARK)


def draw_paw(canvas, x, y, w, h, arm, shoulder, rng, palm):
    if arm:
        filled(canvas, wobble(capsule(*shoulder, x, y, 5.2, 5), rng, .12), rng, FUR, line=2)
    filled(canvas, wobble(ellipse(x, y, w, h), rng, .12), rng, FUR, line=2)
    if palm:
        canvas.paint(PINK, canvas.mask(ellipse(x, y + 1.2, w * .42, h * .36)))
        for dx in (-3.6, 0, 3.6):
            canvas.paint(PINK, canvas.mask(ellipse(x + dx, y - h * .28, 2.4, 2.2)))
    else:
        for dx in (-2.4, 2.4):
            canvas.line([(x + dx, y + h * .1), (x + dx, y + h * .5)], 1.2, rng)


def render(p, seed):
    rng = random.Random(seed)
    canvas = Canvas(FUR, FUR, OUTLINE)
    rise = p['rise']
    hx, hy = 64, 54 - rise
    neck = (64, 72 - rise)

    def face(pts):
        pts = scale(pts, (hx, hy + HEAD_H / 2), 1, p['breath'])
        return rotate(pts, neck, p['tilt']) if p['tilt'] else pts

    filled(canvas, wobble(ellipse(64, 106, 92, 12), rng, .2), rng, SAUCER)

    tip = rotate([(106, 71), (101, 74.5), (95, 79)], (95, 80), p['tail'])
    tail = tip + arc(93, 89, 12, 9, -90, 90)
    canvas.line(tail, 10.6, rng)
    canvas.line(tail, 7, rng, FUR)
    puff = rotate([(107.5, 69.5)], (95, 80), p['tail'])[0]
    filled(canvas, wobble(fluffy(*puff, 5.2, 7, 2.2, rng.random() * 40), rng, .1), rng, FUR, line=2)

    filled(canvas, wobble(ellipse(64, RIM_Y, 68, 11), rng, .15), rng, CUP)
    filled(canvas, wobble(ellipse(64, RIM_Y + .5, 60, 7.5), rng, .12), rng, COFFEE, line=1.5)

    ears = []
    for side in (-1, 1):
        base = (hx + side * 17, hy - 17)
        ear = [(hx + side * 31, hy - 1), (hx + side * 30, hy - 29), (hx + side * 25, hy - 35), (hx + side * 17, hy - 34),
               (hx + side * 5, hy - 22)]
        ear = rotate(ear, base, side * p['ear'] if p['ear'] else 0)
        ears.append(ear)
    body = wobble(ellipse(64, 78 - rise, 42, 30), rng, .2)
    head = wobble(ellipse(hx, hy, HEAD_W, HEAD_H), rng, .3)
    tufts = [cheek_tuft(hx, hy, angle, length) for angle, length in CHEEK_TUFTS]
    tufts += [cheek_tuft(hx, hy, 180 - angle, length) for angle, length in CHEEK_TUFTS]
    canvas.hatch_colours, canvas.hatch_spacing = FUR_HATCH, 3.6
    canvas.silhouette(union(canvas, [body] + [face(s) for s in [head] + tufts + [wobble(rounded(e, 6), rng, .15) for e in ears]]),
                      rng, FUR)
    canvas.hatch_spacing = 2.3
    muzzle = canvas.mask(face(ellipse(hx, hy + 11, 30, 17))).filter(ImageFilter.GaussianBlur(2.2 * SS))
    canvas.tint(CREAM, muzzle, 200)
    for ear in ears:
        cx, cy = sum(x for x, _ in ear) / len(ear), sum(y for _, y in ear) / len(ear)
        inner = rounded([(cx + (x - cx) * .55, cy + (y - cy) * .55 + 1.5) for x, y in ear], 6)
        canvas.paint(PINK, canvas.mask(face(inner)))
        for k in (-1, 0, 1):
            canvas.line(face([(cx + k * 2.2, cy + 5), (cx + k * 3.4 + (cx - hx) * .04, cy - 3.5)]), 1.3, rng, CREAM)

    ruff = [fluffy(64, hy + 27, 13, 6, 3, 90), fluffy(55, hy + 25, 7, 4, 2.4, 70), fluffy(73, hy + 25, 7, 4, 2.4, 110)]
    hatched(canvas, CREAM)
    canvas.silhouette(union(canvas, [face(wobble(r, rng, .12)) for r in ruff]), rng, CREAM, line=1.9)

    dollop = [ellipse(hx, hy - 19, 24, 9), ellipse(hx - 5, hy - 23, 12, 10), ellipse(hx + 5, hy - 23, 12, 10),
              ellipse(hx, hy - 27.5, 10, 9), ellipse(hx + 1.5, hy - 31, 4.5, 4.5)]
    hatched(canvas, FOAM)
    canvas.silhouette(union(canvas, [face(wobble(d, rng, .15)) for d in dollop]), rng, FOAM, line=1.9)
    canvas.line(face([(hx - 7, hy - 21.5), (hx - 2, hy - 20.5), (hx + 4, hy - 21.8)]), 1.1, rng, (214, 204, 192))
    canvas.paint(COFFEE, canvas.mask(face(heart(hx, hy - 18.5, 3.4))))

    draw_eyes(canvas, hx, hy, p, rng, face)
    draw_mouth(canvas, hx, hy, p, rng, face)
    extras = p['extras']
    for side in (-1, 1):
        canvas.tint(PINK, canvas.mask(face(ellipse(hx + side * 19, hy + 10.5, 8.5, 4.6))),
                    190 if 'blush' in extras else 130)

    filled(canvas, wobble(cup_front(), rng, .25), rng, CUP)
    for x, y, r in ((56, 90, 2.3), (61, 87, 2.3), (67, 87, 2.3), (72, 90, 2.3)):
        canvas.paint(COFFEE, canvas.mask(wobble(ellipse(x, y, r * 2, r * 2.2), rng, .08)))
    canvas.paint(COFFEE, canvas.mask(wobble(ellipse(64, 95, 11, 8.5), rng, .1)))

    left, right, w, h, arm = PAWS[p['paws']]
    for side, (x, y) in ((-1, left), (1, right)):
        lifted = arm and (y < RIM_Y - 6)
        shoulder = (64 + side * 17, 72 - rise)
        draw_paw(canvas, x, y - (rise if p['paws'] == 'up' else 0), w, h, lifted, shoulder, rng, lifted)

    if p['steam'] is not None:
        for x0, top, phase in ((25, 38, 0), (106, 44, .5)):
            wisp = [(x0 + 2.8 * math.sin(math.tau * (t * 1.1 + phase + p['steam'] * .5)), 64 - (64 - top) * t)
                    for t in (k / 24 for k in range(25))]
            accent(canvas, wisp, 1.7, rng, STEAM)
    if 'splash' in extras:
        for x, y, r in ((30, 66, 2.6), (98, 62, 2.4), (24, 54, 2)):
            canvas.paint(OUTLINE, canvas.mask(ellipse(x, y, r * 2 + 1.8, r * 2 + 1.8)))
            canvas.paint(FOAM, canvas.mask(ellipse(x, y, r * 2, r * 2)))
    if 'bang' in extras:
        bx, by = 98, 22
        accent(canvas, [(bx, by - 8), (bx + .4, by)], 2.4, rng)
        canvas.paint(OUTLINE, canvas.mask(ellipse(bx + .5, by + 4.2, 4.8, 4.8)))
        canvas.paint(ACCENT, canvas.mask(ellipse(bx + .5, by + 4.2, 3, 3)))
    if 'zzz' in extras:
        for zx, zy, zs in ((88, 38, 6.5), (98, 27, 5)):
            accent(canvas, [(zx, zy), (zx + zs, zy), (zx, zy + zs), (zx + zs, zy + zs)], 1.7, rng)
    if 'sparkle' in extras:
        for sx, sy, r in ((20, 34, 4.6), (108, 30, 3.8)):
            cross = ([(sx - r, sy), (sx + r, sy)], [(sx, sy - r), (sx, sy + r)])
            for stroke in cross:
                canvas.line(stroke, 3.6, rng)
            for stroke in cross:
                canvas.line(stroke, 1.8, rng, ACCENT)
    return canvas.downsample()


NEUTRAL = pose(steam=0)
BREATH = pose(breath=1.03, steam=1)
HAPPY = pose(eyes='happy', tail=-14, extras=('blush',))
WAVE_UP = pose(eyes='wide', mouth='open', paws='wave-up', extras=('bang',))
WAVE_OUT = pose(eyes='wide', mouth='open', paws='wave-out', extras=('bang',))
POP = pose(rise=5, eyes='happy', mouth='open', paws='up', tail=-10)

ANIMATIONS = {
    'idle': ('loop', [
        (NEUTRAL, 1000), (BREATH, 900), (pose(steam=0, eyes='blink'), 140), (NEUTRAL, 600),
        (pose(steam=1, ear=12), 260), (BREATH, 900), (pose(steam=0, tail=10), 500), (BREATH, 900),
    ]),
    'working': ('loop', [
        (pose(eyes='focus', mouth='flat', paws='press', steam=0), 320),
        (pose(eyes='focus', mouth='flat', paws='press-other', steam=1), 320),
    ]),
    'finished': ('once', [
        (pose(rise=-4, breath=.97, eyes='happy'), 130),
        (POP, 110),
        (pose(rise=8, eyes='happy', mouth='open', paws='up', tail=-18, extras=('splash',)), 170),
        (POP, 100),
        (pose(rise=-2, eyes='happy', tail=-6), 130),
        (pose(eyes='happy', tail=-14, extras=('blush', 'sparkle')), 380),
    ]),
    'needs-you': ('hold', [
        (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180), (WAVE_OUT, 180), (WAVE_UP, 180),
        (pose(eyes='wide', mouth='w', paws='wave-up', tilt=-6, extras=('bang',)), 600),
    ]),
    'resting': ('hold', [
        (pose(rise=-9, eyes='closed', extras=('zzz',)), 1000),
    ]),
    'hover': ('loop', [
        (HAPPY, 300),
        (pose(eyes='happy', mouth='open', tail=12, breath=1.02, extras=('blush', 'sparkle')), 300),
    ]),
}
