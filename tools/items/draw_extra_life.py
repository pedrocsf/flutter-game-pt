import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 8
F = 64
FRAMES = 8
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "map", "anim", "spritesheet_item_extra_life.png")
DARK = (42, 26, 20, 255)
CORAL = (255, 77, 77, 255)
CORAL_DARK = (214, 52, 62, 255)
SHINE = (255, 190, 170, 255)
WHITE = (255, 255, 255, 255)
HALO = (255, 140, 40)
OUTLINE_WIDTH = 3
HEART_SIZE = 44
MIN_SCALE = 0.85


def heart_points(cx, cy, size, n=120):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((x, y))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    k = size / (max(xs) - min(xs))
    mx = (max(xs) + min(xs)) / 2
    my = (max(ys) + min(ys)) / 2
    return [(cx + (x - mx) * k, cy + (y - my) * k) for x, y in pts]


def shrink(pts, cx, cy, f):
    return [(cx + (x - cx) * f, cy + (y - cy) * f) for x, y in pts]


def draw_frame(i):
    t = i / FRAMES
    scale = MIN_SCALE + (1 - MIN_SCALE) * (0.5 + 0.5 * math.cos(2 * math.pi * t))
    size = HEART_SIZE * scale
    c = F / 2
    big = F * S
    halo = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    r = (size / 2 + 8) * S
    hd.ellipse([c * S - r, c * S - r, c * S + r, c * S + r], fill=HALO + (110,))
    halo = halo.filter(ImageFilter.GaussianBlur(5 * S))
    img = halo
    d = ImageDraw.Draw(img)
    pts = heart_points(c, c + 1, size)
    sp = [(x * S, y * S) for x, y in pts]
    d.polygon(sp, fill=DARK)
    inner = [(x * S, y * S) for x, y in shrink(pts, c, c + 1, 1 - 2 * OUTLINE_WIDTH / size)]
    d.polygon(inner, fill=CORAL)
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(inner, fill=255)
    shade = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([(c - size * 0.9) * S, (c + size * 0.12) * S, (c + size * 0.9) * S, (c + size * 1.1) * S], fill=CORAL_DARK)
    shade = Image.composite(shade, Image.new("RGBA", (big, big), (0, 0, 0, 0)), mask)
    inner_mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(inner_mask).polygon([(x * S, y * S) for x, y in shrink(pts, c, c + 1, 1 - 2 * OUTLINE_WIDTH / size)], fill=255)
    base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    base.paste(CORAL, mask=inner_mask)
    ring = Image.new("L", (big, big), 0)
    rc = (c - 0.06 * size, c - 0.14 * size)
    rr = 0.66 * size
    ImageDraw.Draw(ring).ellipse([(rc[0] - rr) * S, (rc[1] - rr) * S, (rc[0] + rr) * S, (rc[1] + rr) * S], fill=255)
    shade_mask = ImageChops_subtract(inner_mask, ring)
    shade_layer = Image.new("RGBA", (big, big), CORAL_DARK)
    img.paste(shade_layer, mask=shade_mask)
    s = size / HEART_SIZE
    d = ImageDraw.Draw(img)
    d.ellipse([(c - 13 * s) * S, (c - 12 * s) * S, (c - 6 * s) * S, (c - 6 * s) * S], fill=SHINE)
    d.ellipse([(c - 5 * s) * S, (c - 14 * s) * S, (c - 2 * s) * S, (c - 11 * s) * S], fill=SHINE)
    arm = 6 * s
    th = 3.4 * s
    cy = c + 1 * s
    d.rounded_rectangle([(c - arm) * S, (cy - th / 2) * S, (c + arm) * S, (cy + th / 2) * S], th * S / 2, fill=WHITE, outline=DARK, width=int(0.8 * S))
    d.rounded_rectangle([(c - th / 2) * S, (cy - arm) * S, (c + th / 2) * S, (cy + arm) * S], th * S / 2, fill=WHITE, outline=DARK, width=int(0.8 * S))
    d.rounded_rectangle([(c - arm) * S + int(0.8 * S), (cy - th / 2) * S + int(0.8 * S), (c + arm) * S - int(0.8 * S), (cy + th / 2) * S - int(0.8 * S)], th * S / 2, fill=WHITE)
    d.rounded_rectangle([(c - th / 2) * S + int(0.8 * S), (cy - arm) * S + int(0.8 * S), (c + th / 2) * S - int(0.8 * S), (cy + arm) * S - int(0.8 * S)], th * S / 2, fill=WHITE)
    return img.resize((F, F), Image.LANCZOS)


def ImageChops_invert(m):
    from PIL import ImageChops
    return ImageChops.invert(m)


def ImageChops_subtract(a, b):
    from PIL import ImageChops
    return ImageChops.subtract(a, b)


def main():
    sheet = Image.new("RGBA", (F * FRAMES, F), (0, 0, 0, 0))
    for i in range(FRAMES):
        sheet.paste(draw_frame(i), (i * F, 0))
    sheet.save(OUT)
    prev = Image.new("RGBA", sheet.size, (40, 34, 38, 255))
    prev.alpha_composite(sheet)
    prev.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
        "/tmp/claude-1000/-home-pedro-Github-flutter-game-pt/5330e737-4629-4dbb-8636-60fbef20c145/scratchpad/extra_life_preview.png")


if __name__ == "__main__":
    main()
