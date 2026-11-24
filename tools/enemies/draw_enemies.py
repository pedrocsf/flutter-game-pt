import math
import os
from PIL import Image, ImageDraw, ImageFont

S = 4
F = 64
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "map", "anim")
DARK = (32, 26, 24, 255)
ORANGE = (248, 95, 0, 255)
GOLD = (255, 196, 61, 255)
WHITE = (255, 255, 255, 255)
RED = (214, 52, 40, 255)
RED_LIGHT = (240, 98, 78, 255)
RED_DARK = (150, 28, 24, 255)
BLUE = (150, 214, 240, 255)
BLUE_DARK = (70, 150, 200, 255)
GRAY = (176, 172, 170, 255)
GRAY_DARK = (110, 104, 102, 255)
BEIGE = (236, 200, 150, 255)
BEIGE_DARK = (196, 154, 104, 255)
PURPLE = (150, 70, 150, 255)
OW = 2.2


def sc(v):
    return [c * S for c in v]


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (F * S, F * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def ellipse(self, box, fill, outline=DARK, w=OW):
        self.d.ellipse(sc(box), fill=fill, outline=outline, width=int(w * S))

    def poly(self, pts, fill, outline=DARK, w=OW):
        p = [(x * S, y * S) for x, y in pts]
        self.d.polygon(p, fill=fill)
        if outline:
            self.d.line(p + [p[0]], fill=outline, width=int(w * S), joint="curve")

    def rrect(self, box, r, fill, outline=DARK, w=OW):
        self.d.rounded_rectangle(sc(box), r * S, fill=fill, outline=outline, width=int(w * S))

    def line(self, pts, fill, w):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill, width=int(w * S), joint="curve")

    def text(self, xy, s, fill, size):
        font = ImageFont.load_default(size * S)
        self.d.text((xy[0] * S, xy[1] * S), s, fill=fill, font=font, stroke_width=S, stroke_fill=DARK)

    def done(self):
        return self.img.resize((F, F), Image.LANCZOS)


def blob(c, cx, cy, rx, ry, fill, wob=0.0, ph=0.0, n=28):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1 + wob * math.sin(3 * a + ph)
        pts.append((cx + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
    c.poly(pts, fill)


def cramp(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    pulse = 0.5 + 0.5 * math.sin(t)
    rx, ry = 15 + 3 * pulse, 17 - 3 * pulse
    cx, cy = 32, 40
    c.ellipse((cx - 14, 52, cx + 14, 61), (0, 0, 0, 70), outline=None, w=0)
    for k in range(8):
        a = math.pi * 1.1 + k * math.pi * 0.8 / 7 + 0.12 * math.sin(t)
        r0 = 16 + 3 * pulse
        r1 = r0 + 5 + 4 * ((k + i) % 2) * pulse
        c.line([(cx + r0 * math.cos(a), 36 + r0 * 0.9 * math.sin(a)),
                (cx + r1 * math.cos(a), 36 + r1 * 0.9 * math.sin(a))], DARK, 4.4)
        c.line([(cx + r0 * math.cos(a), 36 + r0 * 0.9 * math.sin(a)),
                (cx + r1 * math.cos(a), 36 + r1 * 0.9 * math.sin(a))], GOLD, 2.2)
    blob(c, cx, cy, rx, ry, RED, 0.05, t)
    blob(c, cx - 3, cy - 4, rx * 0.55, ry * 0.5, RED_LIGHT, 0.04, t)
    for k in range(3):
        y = cy - 8 + k * 7
        c.line([(cx - rx * 0.6, y), (cx - 2, y + 3 + pulse * 2), (cx + rx * 0.6, y)], RED_DARK, 2)
    ey = cy - 2
    c.ellipse((cx - 8, ey - 4, cx - 2, ey + 3), WHITE, w=1.4)
    c.ellipse((cx + 2, ey - 4, cx + 8, ey + 3), WHITE, w=1.4)
    c.ellipse((cx - 6, ey - 1, cx - 3.5, ey + 2), DARK, outline=None, w=0)
    c.ellipse((cx + 3.5, ey - 1, cx + 6, ey + 2), DARK, outline=None, w=0)
    c.line([(cx - 9, ey - 7 + pulse), (cx - 2, ey - 4)], DARK, 2)
    c.line([(cx + 9, ey - 7 + pulse), (cx + 2, ey - 4)], DARK, 2)
    c.line([(cx - 5, ey + 9), (cx - 2, ey + 7), (cx + 2, ey + 9), (cx + 5, ey + 7)], DARK, 1.8)
    return c.done()


def soreness(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    sway = math.sin(t) * 4
    c.ellipse((16, 54, 48, 62), (0, 0, 0, 70), outline=None, w=0)
    bx = 32 + sway * 0.5
    c.line([(bx - 8 + sway * 0.3, 46), (bx - 10 - sway * 0.6, 57)], DARK, 8)
    c.line([(bx + 8 + sway * 0.3, 46), (bx + 10 - sway * 0.6, 57)], DARK, 8)
    c.line([(bx - 8 + sway * 0.3, 46), (bx - 10 - sway * 0.6, 57)], (230, 150, 110, 255), 4)
    c.line([(bx + 8 + sway * 0.3, 46), (bx + 10 - sway * 0.6, 57)], (230, 150, 110, 255), 4)
    c.rrect((bx - 11, 10, bx + 11, 28), 6, (230, 150, 110, 255))
    c.poly([(bx - 11 + sway, 28), (bx + 11 + sway, 28), (bx + 8, 50), (bx - 8, 50)], (230, 150, 110, 255))
    arm = [(bx - 8, 24), (bx - 22, 26 + sway * 0.3), (bx - 24, 14), (bx - 16, 8), (bx - 8, 14)]
    c.poly(arm, (230, 150, 110, 255))
    blob(c, bx - 17, 17 + sway * 0.2, 9.5, 11, (222, 128, 96, 255), 0.04, t)
    c.ellipse((bx - 21, 11, bx - 12, 20), (240, 176, 140, 255), outline=None, w=0)
    for (px, py, r) in [(bx - 18, 22, 3), (bx - 12, 14, 2.2), (bx + 3, 36, 3.2), (bx - 3, 42, 2.4)]:
        c.ellipse((px - r, py - r, px + r, py + r), PURPLE, outline=None, w=0)
    c.line([(bx + 2, 30), (bx + 6, 34)], RED_DARK, 1.6)
    c.line([(bx + 6, 30), (bx + 2, 34)], RED_DARK, 1.6)
    ey = 22
    for ex in (bx - 4 + sway * 0.3, bx + 5 + sway * 0.3):
        c.line([(ex - 2.5, ey - 2.5), (ex + 2.5, ey + 2.5)], DARK, 1.8)
        c.line([(ex + 2.5, ey - 2.5), (ex - 2.5, ey + 2.5)], DARK, 1.8)
    c.line([(bx - 4 + sway * 0.3, ey + 7), (bx - 1, ey + 5), (bx + 2, ey + 7), (bx + 5 + sway * 0.3, ey + 5)], DARK, 1.8)
    if i % 4 < 2:
        c.text((bx + 12, 4), "!", ORANGE, 14)
    return c.done()


def ice_pack(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    h = abs(math.sin(t / 2))
    lift = 14 * h
    sq = 1 + 0.12 * (1 - h) ** 4
    sh = 0.6 + 0.4 * (1 - h)
    c.ellipse((32 - 14 * sh, 56, 32 + 14 * sh, 62), (0, 0, 0, 70), outline=None, w=0)
    cy = 40 - lift
    w = 19 * sq
    hh = 17 / sq
    c.rrect((32 - w, cy - hh, 32 + w, cy + hh), 7, BLUE)
    c.rrect((32 - w + 4, cy - hh + 4, 32 + w - 4, cy - hh + 9), 3, (214, 240, 252, 255), outline=None, w=0)
    c.rrect((32 - 9, cy - hh - 7, 32 + 9, cy - hh + 1), 3, ORANGE)
    for k, (dx, dy, s) in enumerate([(-8, -2, 5), (6, 2, 5.5), (-1, 7, 4)]):
        r = s + 0.6 * math.sin(t + k)
        x, y = 32 + dx, cy + dy
        c.poly([(x - r, y - r * 0.6), (x, y - r * 1.1), (x + r, y - r * 0.6), (x + r, y + r * 0.7), (x - r, y + r * 0.7)],
               (232, 248, 255, 255), outline=BLUE_DARK, w=1.4)
    c.ellipse((32 - 9, cy - 3, 32 - 5, cy + 1), DARK, outline=None, w=0)
    c.ellipse((32 + 5, cy - 3, 32 + 9, cy + 1), DARK, outline=None, w=0)
    c.line([(32 - 4, cy + 5), (32, cy + 8), (32 + 4, cy + 5)], DARK, 1.6)
    if 0.35 < h < 0.9:
        c.line([(32 + w + 2, cy - 6), (32 + w + 5, cy - 10)], BLUE_DARK, 2)
    return c.done()


def fatigue_hourglass(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    bob = 3 * math.sin(t)
    flap = math.sin(t * 2)
    cx, top, bot = 32, 14 + bob, 50 + bob
    mid = (top + bot) / 2
    for side in (-1, 1):
        wy = mid - 2 - 6 * flap
        c.poly([(cx + side * 12, mid), (cx + side * 27, wy - 8), (cx + side * 30, wy + 2), (cx + side * 12, mid + 6)],
               (255, 255, 255, 235), outline=DARK, w=1.8)
    c.rrect((cx - 14, top - 5, cx + 14, top + 1), 2, ORANGE)
    c.rrect((cx - 14, bot - 1, cx + 14, bot + 5), 2, ORANGE)
    glass = [(cx - 11, top + 1), (cx + 11, top + 1), (cx + 2, mid), (cx + 11, bot - 1), (cx - 11, bot - 1), (cx - 2, mid)]
    c.poly(glass, (226, 238, 248, 235))
    f = (i % n) / n
    up = 1 - f
    sy = top + 1 + (mid - top - 1) * f
    c.poly([(cx - 9 * up - 1, mid - 2 * up), (cx + 9 * up + 1, mid - 2 * up), (cx + 1.5, mid), (cx - 1.5, mid)] if up > 0.1 else [(cx - 1, mid), (cx + 1, mid), (cx, mid)], GOLD, outline=None)
    top_h = (mid - top - 3) * up
    c.poly([(cx - 9 * up - 1.5, mid - 1), (cx + 9 * up + 1.5, mid - 1), (cx + 1.5, mid - 1 - top_h * 0.3), (cx - 1.5, mid - 1 - top_h * 0.3)], GOLD, outline=None)
    pile = (bot - mid - 3) * f
    c.poly([(cx - 9 * f - 1, bot - 2), (cx + 9 * f + 1, bot - 2), (cx, bot - 2 - pile)], GOLD, outline=None)
    c.line([(cx, mid), (cx, bot - 3 - pile)], GOLD, 1.4)
    c.poly(glass, None, outline=DARK, w=OW)
    c.line([(cx - 8, top + 4), (cx - 5, mid - 4)], WHITE, 1.4)
    c.ellipse((cx - 5, top + 7, cx - 2, top + 10), DARK, outline=None, w=0)
    c.ellipse((cx + 2, top + 7, cx + 5, top + 10), DARK, outline=None, w=0)
    return c.done()


def lazy_cloud(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    by = 3 * math.sin(t)
    bx = 2 * math.sin(t / 2)
    puff = 1 + 0.04 * math.sin(2 * t)
    cx, cy = 30 + bx, 40 + by
    c.ellipse((cx - 14, 56, cx + 14, 61), (0, 0, 0, 50), outline=None, w=0)
    parts = [(-14, 4, 10), (-5, -5, 12), (7, -3, 11), (14, 5, 9), (0, 6, 12)]
    for dx, dy, r in parts:
        r *= puff
        c.ellipse((cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r), GRAY, w=OW)
    for dx, dy, r in parts:
        r = (r - 1.2) * puff
        c.ellipse((cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r), GRAY, outline=None, w=0)
    c.ellipse((cx - 10, cy - 12, cx + 2, cy - 6), (214, 210, 208, 255), outline=None, w=0)
    c.rrect((cx - 16, cy + 8, cx + 16, cy + 14), 3, GRAY, outline=None, w=0)
    lid = 1.5 + 0.5 * math.sin(t)
    for ex in (cx - 7, cx + 6):
        c.line([(ex - 3.5, cy + 1), (ex, cy + 1 + lid), (ex + 3.5, cy + 1)], DARK, 2)
    c.ellipse((cx - 2, cy + 6, cx + 2, cy + 9 + math.sin(t)), GRAY_DARK, w=1.2)
    for k in range(3):
        ph = (i / n + k / 3) % 1
        zx = cx + 14 + ph * 12
        zy = cy - 12 - ph * 18
        size = 8 + 6 * ph
        a = int(255 * min(1, 2.2 * (1 - ph)))
        if a > 20 and zx < 58:
            c.text((zx, zy), "Z", (255, 224, 140, a), int(size))
    return c.done()


def bandage(i, n):
    t = 2 * math.pi * i / n
    c = Canvas()
    bob = 2.5 * math.sin(t / 2)
    flap = math.sin(t * 2)
    cx, cy = 32, 34 + bob
    for side in (-1, 1):
        wy = cy - 19 - 5 * flap
        c.poly([(cx + side * 6, cy - 6), (cx + side * 20, wy - 3), (cx + side * 25, wy + 6), (cx + side * 12, cy - 6)],
               (255, 255, 255, 235), outline=DARK, w=1.8)
        c.line([(cx + side * 9, cy - 7), (cx + side * 21, wy + 2)], (200, 210, 225, 255), 1.2)
    c.poly([(cx - 25, cy - 8), (cx + 25, cy - 8), (cx + 25, cy + 8), (cx - 25, cy + 8)], BEIGE)
    c.poly([(cx - 25, cy - 8), (cx - 25, cy + 8)], None)
    for k in range(-2, 3):
        if k:
            for dy in (-4, 0, 4):
                c.ellipse((cx + k * 4.6 - 0.6 - (14 if abs(k) == 0 else 0), cy + dy - 0.6, cx + k * 4.6 + 0.6, cy + dy + 0.6), BEIGE_DARK, outline=None, w=0)
    c.rrect((cx - 11, cy - 8, cx + 11, cy + 8), 2, (250, 228, 190, 255), outline=DARK, w=1.6)
    c.line([(cx - 10, cy - 5), (cx + 10, cy - 5)], BEIGE, 1.2)
    c.line([(cx - 25, cy - 2), (cx - 21, cy - 2)], BEIGE_DARK, 1.4)
    c.line([(cx + 21, cy + 2), (cx + 25, cy + 2)], BEIGE_DARK, 1.4)
    c.ellipse((cx - 8, cy - 4, cx - 3, cy + 1), DARK, outline=None, w=0)
    c.ellipse((cx + 3, cy - 4, cx + 8, cy + 1), DARK, outline=None, w=0)
    c.ellipse((cx - 7, cy - 3.5, cx - 5.5, cy - 2), WHITE, outline=None, w=0)
    c.ellipse((cx + 4, cy - 3.5, cx + 5.5, cy - 2), WHITE, outline=None, w=0)
    c.line([(cx - 3, cy + 4.5), (cx, cy + 6), (cx + 3, cy + 4.5)], DARK, 1.4)
    c.line([(cx - 3, cy + 15), (cx + 3, cy + 15)], (0, 0, 0, 0), 1)
    c.ellipse((cx - 8, 52 + bob * 0.3, cx + 8, 57 + bob * 0.3), (0, 0, 0, 45), outline=None, w=0)
    return c.done()


SHEETS = [
    ("cramp", cramp, 16, 8),
    ("soreness", soreness, 12, 6),
    ("ice_pack", ice_pack, 22, 11),
    ("fatigue_hourglass", fatigue_hourglass, 14, 7),
    ("lazy_cloud", lazy_cloud, 16, 8),
    ("bandage", bandage, 32, 8),
]


def main():
    for name, fn, amount, per_row in SHEETS:
        rows = math.ceil(amount / per_row)
        sheet = Image.new("RGBA", (per_row * F, rows * F), (0, 0, 0, 0))
        for i in range(amount):
            sheet.paste(fn(i, amount), ((i % per_row) * F, (i // per_row) * F))
        sheet.save(os.path.join(OUT, "spritesheet_enemy_%s.png" % name))


if __name__ == "__main__":
    main()
