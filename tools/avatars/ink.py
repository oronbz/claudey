"""Hand-drawn ink and pencil primitives shared by every avatar.

Geometry is expressed in final cell pixels; the canvas renders at SS times
that size and downsamples, which is what gives strokes their antialiasing.
"""

import math
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4
CELL = 128
GROUND = 112

INK = (38, 26, 22)
LINE = 2.2
RIM = (248, 242, 230)
RIM_WIDTH = 1.6


class Noise:
    def __init__(self, rng, amplitude, octaves=3):
        self.terms = [(amplitude / (k + 1), k + 1 + rng.random() * .6, rng.random() * math.tau)
                      for k in range(octaves)]

    def __call__(self, t):
        return sum(a * math.sin(math.tau * f * t + p) for a, f, p in self.terms)


def rounded_rect(cx, cy, w, h, r, step=.35):
    corners = [(cx + w / 2 - r, cy - h / 2 + r, -90), (cx + w / 2 - r, cy + h / 2 - r, 0),
               (cx - w / 2 + r, cy + h / 2 - r, 90), (cx - w / 2 + r, cy - h / 2 + r, 180)]
    pts = []
    for i, (ox, oy, start) in enumerate(corners):
        n = max(3, int(r * math.pi / 2 / step))
        for k in range(n + 1):
            a = math.radians(start + 90 * k / n)
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a)))
        nx, ny, nstart = corners[(i + 1) % 4]
        end = pts[-1]
        target = (nx + r * math.cos(math.radians(nstart)), ny + r * math.sin(math.radians(nstart)))
        segments = int(math.dist(end, target) / step)
        for k in range(1, segments):
            t = k / segments
            pts.append((end[0] + (target[0] - end[0]) * t, end[1] + (target[1] - end[1]) * t))
    return pts


def ellipse(cx, cy, w, h, step=.3):
    n = max(16, int(math.pi * (w + h) / 2 / step))
    return [(cx + w / 2 * math.cos(math.tau * k / n), cy + h / 2 * math.sin(math.tau * k / n))
            for k in range(n)]


def capsule(x0, y0, x1, y1, r0, r1, step=.35):
    a = math.atan2(y1 - y0, x1 - x0)
    pts = []
    for cx, cy, r, start in ((x1, y1, r1, a - math.pi / 2), (x0, y0, r0, a + math.pi / 2)):
        n = max(8, int(r * math.pi / step))
        pts += [(cx + r * math.cos(start + math.pi * k / n), cy + r * math.sin(start + math.pi * k / n))
                for k in range(n + 1)]
    return pts


def wobble(pts, rng, amplitude):
    noise = Noise(rng, amplitude)
    n = len(pts)
    out = []
    for i, (x, y) in enumerate(pts):
        px, py = pts[i - 1]
        qx, qy = pts[(i + 1) % n]
        dx, dy = qx - px, qy - py
        length = math.hypot(dx, dy) or 1
        d = noise(i / n)
        out.append((x - dy / length * d, y + dx / length * d))
    return out


def rotate(pts, pivot, degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    px, py = pivot
    return [(px + (x - px) * c - (y - py) * s, py + (x - px) * s + (y - py) * c) for x, y in pts]


def scale(pts, pivot, sx, sy):
    px, py = pivot
    return [(px + (x - px) * sx, py + (y - py) * sy) for x, y in pts]


class Canvas:
    def __init__(self, hatch_dark, hatch_light):
        self.image = Image.new('RGBA', (CELL * SS, CELL * SS), (0, 0, 0, 0))
        self.hatch_colours = hatch_dark, hatch_light

    def mask(self, pts):
        m = Image.new('L', self.image.size, 0)
        ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
        return m

    def paint(self, colour, mask, alpha=255):
        self.image.paste(Image.new('RGBA', self.image.size, colour + (alpha,)), (0, 0), mask)

    def tint(self, colour, mask, alpha):
        layer = Image.new('RGBA', self.image.size, (0, 0, 0, 0))
        layer.paste(Image.new('RGBA', layer.size, colour + (alpha,)), (0, 0), mask)
        self.image.alpha_composite(layer)

    def stroke_mask(self, pts, width, rng, closed=True, jitter=.14):
        m = Image.new('L', self.image.size, 0)
        draw = ImageDraw.Draw(m)
        noise = Noise(rng, jitter)
        seq = pts + pts[:1] if closed else pts
        n = len(seq)
        for i in range(n - 1):
            (x0, y0), (x1, y1) = seq[i], seq[i + 1]
            steps = max(1, int(math.dist((x0, y0), (x1, y1)) * SS / 1.2))
            for k in range(steps):
                t = k / steps
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                taper = 1
                if not closed:
                    taper = .55 + .45 * math.sin(math.pi * (i + t) / (n - 1)) ** .4
                r = width / 2 * (1 + noise((i + t) / n)) * taper * SS
                draw.ellipse((x * SS - r, y * SS - r, x * SS + r, y * SS + r), fill=255)
        return m

    def hatch(self, region, rng, angle=62, spacing=2.3):
        layer = Image.new('RGBA', self.image.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        a = math.radians(angle)
        ux, uy = math.cos(a), -math.sin(a)
        vx, vy = math.sin(a), math.cos(a)
        reach = CELL * 1.5
        offset = -reach
        dark, light = self.hatch_colours
        while offset < reach:
            cx, cy = CELL / 2 + vx * offset, CELL / 2 + vy * offset
            s = -reach
            while s < reach:
                length = rng.uniform(6, 22)
                colour = dark if rng.random() < .8 else light
                alpha = rng.randint(50, 120)
                drift = rng.uniform(-.4, .4)
                x0, y0 = cx + ux * s, cy + uy * s
                x1, y1 = x0 + ux * length + drift, y0 + uy * length
                draw.line((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=colour + (alpha,),
                          width=rng.choice((3, 4, 4, 5)))
                s += length + rng.uniform(1, 7)
            offset += spacing * rng.uniform(.75, 1.25)
        clipped = Image.new('RGBA', self.image.size, (0, 0, 0, 0))
        clipped.paste(layer, (0, 0), ImageChops.multiply(layer.getchannel('A'), region))
        self.image.alpha_composite(clipped)

    def shape(self, pts, rng, fill, line=LINE):
        region = self.mask(pts)
        self.paint(fill, region)
        self.hatch(region, rng)
        self.paint(INK, self.stroke_mask(pts, line, rng))

    def silhouette(self, region, rng, fill, line=LINE):
        self.paint(fill, region)
        self.hatch(region, rng)
        blurred = region.filter(ImageFilter.GaussianBlur(line * SS * .37))
        outer = blurred.point(lambda v: 255 if v > 22 else 0)
        inner = blurred.point(lambda v: 255 if v > 233 else 0)
        self.paint(INK, ImageChops.subtract(outer, inner))

    def line(self, pts, width, rng, colour=INK):
        self.paint(colour, self.stroke_mask(pts, width, rng, closed=False, jitter=.1))

    def rim(self):
        """A cream sticker border so ink and effects still read on dark desktops."""
        spread = self.image.getchannel('A').filter(ImageFilter.GaussianBlur(RIM_WIDTH * SS * .5))
        halo = Image.new('RGBA', self.image.size, RIM + (0,))
        halo.putalpha(spread.point(lambda v: 255 if v > 12 else 0))
        halo.alpha_composite(self.image)
        self.image = halo

    def downsample(self):
        self.rim()
        small = self.image.convert('RGBa').resize((CELL, CELL), Image.LANCZOS).convert('RGBA')
        small.putalpha(small.getchannel('A').point(lambda v: 0 if v < 10 else 255 if v > 245 else v))
        return small
