import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILES = os.path.join(ROOT, "assets", "map", "tiles")
ANIM = os.path.join(ROOT, "assets", "map", "anim")
S = 4
T = 64 * S

ORANGE = (248, 95, 0, 255)
ORANGE_DARK = (160, 60, 0, 255)
STONE = (62, 52, 47, 255)
STONE_LIGHT = (78, 66, 60, 255)
STONE_DARK = (44, 37, 34, 255)
RUBBER = (40, 33, 30, 255)
WALL = (26, 21, 19, 255)
WALL_PANEL = (32, 26, 23, 255)
OUTLINE = (20, 15, 13, 255)


def noise_layer(seed, amp):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, amp, (T, T))
    return n


def periodic_texture(base, seed, amp, blur):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (T, T))
    img = Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8))
    wide = np.concatenate([n, n, n], axis=1)
    tall = np.concatenate([wide, wide, wide], axis=0)
    big = Image.fromarray(((tall * 40) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    arr = np.asarray(big).astype(float)[T:2 * T, T:2 * T] - 128
    arr = arr / max(arr.std(), 1e-6) * amp
    out = np.zeros((T, T, 4), dtype=float)
    for c in range(3):
        out[..., c] = base[c] + arr
    out[..., 3] = 255
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def finish(img):
    return img.resize((64, 64), Image.LANCZOS)


def ceiling(kind):
    img = periodic_texture(STONE, 11, 5, 6)
    d = ImageDraw.Draw(img)
    for x in range(0, T, 128):
        d.line([(x, 0), (x, 200)], fill=STONE_DARK, width=3)
    d.line([(0, 100), (T, 100)], fill=STONE_DARK, width=3)
    d.rectangle([0, 0, T, 14], fill=STONE_DARK)
    d.rectangle([0, 196, T, 214], fill=ORANGE_DARK)
    d.rectangle([0, 200, T, 210], fill=ORANGE)
    d.rectangle([0, 214, T, 224], fill=OUTLINE)
    if kind in ("start", "end"):
        mask = Image.new("L", (T, T), 255)
        md = ImageDraw.Draw(mask)
        r = 150
        if kind == "start":
            md.rectangle([0, 224 - r, r, 224], fill=0)
            md.ellipse([0, 224 - 2 * r + 0, 2 * r, 224], fill=255)
            md.rectangle([0, 224, T, T], fill=0)
        else:
            md.rectangle([T - r, 224 - r, T, 224], fill=0)
            md.ellipse([T - 2 * r, 224 - 2 * r, T, 224], fill=255)
            md.rectangle([0, 224, T, T], fill=0)
        mask = mask.filter(ImageFilter.GaussianBlur(0.6))
        a = np.minimum(np.asarray(img)[..., 3], np.asarray(mask))
        arr = np.asarray(img).copy()
        arr[..., 3] = a
        img = Image.fromarray(arr, "RGBA")
        ring = Image.new("L", (T, T), 0)
        rd = ImageDraw.Draw(ring)
        if kind == "start":
            rd.ellipse([0, 224 - 2 * r, 2 * r, 224], outline=255, width=22)
            rd.rectangle([r, 0, T, T], fill=0)
        else:
            rd.ellipse([T - 2 * r, 224 - 2 * r, T, 224], outline=255, width=22)
            rd.rectangle([0, 0, T - r, T], fill=0)
        rd.rectangle([0, 224, T, T], fill=0)
        orange = Image.new("RGBA", (T, T), ORANGE)
        ringmask = Image.fromarray(np.minimum(np.asarray(ring), np.asarray(mask)))
        img = Image.composite(orange, img, ringmask.point(lambda v: 255 if v > 128 else 0))
    return img


def lamp():
    img = ceiling("mid")
    glow = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([40, 90, 216, 250], fill=(255, 170, 60, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.rectangle([124, 190, 132, 215], fill=OUTLINE)
    d.polygon([(70, 178), (186, 178), (206, 214), (50, 214)], fill=OUTLINE)
    d.polygon([(76, 182), (180, 182), (198, 210), (58, 210)], fill=ORANGE_DARK)
    d.polygon([(90, 190), (166, 190), (176, 206), (80, 206)], fill=(255, 190, 80, 255))
    d.ellipse([100, 206, 156, 236], fill=(255, 240, 190, 255), outline=OUTLINE, width=4)
    return img


def floor(top):
    img = periodic_texture(RUBBER, 21, 4, 3)
    d = ImageDraw.Draw(img)
    for x in range(0, T, 128):
        d.line([(x, 0 if not top else 40), (x, T)], fill=OUTLINE, width=3)
    if top:
        d.rectangle([0, 0, T, 12], fill=OUTLINE)
        d.rectangle([0, 12, T, 32], fill=ORANGE)
        d.rectangle([0, 12, T, 18], fill=(255, 140, 50, 255))
        d.rectangle([0, 32, T, 40], fill=ORANGE_DARK)
        d.rectangle([0, 40, T, 52], fill=OUTLINE)
        arr = np.asarray(img).astype(float)
        grad = np.linspace(1.0, 0.8, T - 52)[:, None]
        arr[52:, :, :3] *= grad[..., None]
        img = Image.fromarray(arr.astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(img)
        for x in range(64, T, 128):
            for y in range(90, T, 90):
                d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=OUTLINE)
    else:
        for x in range(64, T, 128):
            for y in range(40, T, 90):
                d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=OUTLINE)
    return img


def wall(kind):
    img = periodic_texture(WALL, 31, 2, 5)
    d = ImageDraw.Draw(img)
    for x in range(0, T, 128):
        d.rectangle([x, 0, x + 6, T], fill=(18, 14, 12, 255))
        d.rectangle([x + 6, 0, x + 9, T], fill=(40, 33, 30, 255))
    d.rectangle([0, 0, T, T], outline=None)
    if kind == "top":
        arr = np.asarray(img).astype(float)
        grad = np.linspace(0.6, 1.0, T)[:, None, None]
        arr[..., :3] *= grad
        img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    if kind == "led":
        glow = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.rectangle([0, 100, T, 156], fill=(255, 110, 20, 130))
        glow = glow.filter(ImageFilter.GaussianBlur(14))
        img = Image.alpha_composite(img, glow)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 112, T, 144], fill=OUTLINE)
        d.rectangle([0, 118, T, 138], fill=ORANGE)
        d.rectangle([0, 124, T, 130], fill=(255, 220, 150, 255))
    if kind == "base":
        d.rectangle([0, 0, T, 12], fill=(18, 14, 12, 255))
        d.rectangle([0, 12, T, 150], fill=(44, 36, 32, 255))
        d.rectangle([0, 12, T, 22], fill=(60, 50, 44, 255))
        d.rectangle([0, 150, T, 160], fill=OUTLINE)
        d.rectangle([0, 160, T, T], fill=(20, 16, 14, 255))
        for x in range(0, T, 128):
            d.rectangle([x, 12, x + 5, 150], fill=OUTLINE)
        arr = np.asarray(img).astype(float)
        arr[160:, :, :3] = arr[160:, :, :3]
        img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return img


def frame(side):
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = 112
    x0, x1 = (0, w) if side == "left" else (T - w, T)
    base = periodic_texture(STONE, 41, 5, 5)
    mask = Image.new("L", (T, T), 0)
    ImageDraw.Draw(mask).rectangle([x0, 0, x1, T], fill=255)
    img.paste(base, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.line([(x0, 0), (x0, T)], fill=OUTLINE, width=6) if side == "right" else None
    edge = (x1 - 28, x1) if side == "left" else (x0, x0 + 28)
    d.rectangle([edge[0], 0, edge[1], T], fill=ORANGE)
    d.rectangle([edge[0], 0, edge[0] + 8, T], fill=(255, 140, 50, 255))
    ox = edge[1] if side == "left" else edge[0] - 6
    d.rectangle([ox, 0, ox + 6, T], fill=OUTLINE)
    for y in range(64, T, 128):
        d.rectangle([x0, y, x1, y + 5], fill=STONE_DARK)
    ix = x0 if side == "left" else x1 - 6
    if side == "left":
        d.rectangle([0, 0, 6, T], fill=OUTLINE)
    return img


def build_tiles():
    ids = {
        0: ceiling("start"), 1: ceiling("mid"), 2: ceiling("end"), 3: lamp(),
        4: floor(True), 5: floor(False),
        8: wall("top"), 9: wall("mid"), 10: wall("led"), 11: wall("base"),
        12: frame("left"), 13: frame("right"),
    }
    sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for i, im in ids.items():
        sheet.paste(finish(im), ((i % 8) * 64, (i // 8) * 64))
    sheet.save(os.path.join(TILES, "tile_tunnel.png"))
    tsx = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<tileset version="1.10" tiledversion="1.10.2" name="tile_tunnel" tilewidth="64" tileheight="64" tilecount="16" columns="8">\n'
        ' <image source="tile_tunnel.png" width="512" height="128"/>\n'
        '</tileset>\n'
    )
    with open(os.path.join(TILES, "tile_tunnel.tsx"), "w") as f:
        f.write(tsx)
    return sheet


def low_bar_frame(angle):
    big = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for cx in (60, 196):
        d.rectangle([cx - 8, 0, cx + 8, 168], fill=OUTLINE)
        d.rectangle([cx - 4, 0, cx + 4, 168], fill=(130, 124, 120, 255))
        for y in range(8, 168, 24):
            d.ellipse([cx - 8, y, cx + 8, y + 16], outline=OUTLINE, width=3, fill=(160, 154, 150, 255))
    d.rectangle([28, 188, 228, 212], fill=OUTLINE)
    d.rectangle([34, 192, 222, 208], fill=(170, 165, 160, 255))
    d.rectangle([34, 192, 222, 198], fill=(205, 200, 196, 255))
    for x0, x1, col in ((16, 52, ORANGE), (204, 240, ORANGE)):
        d.rounded_rectangle([x0 - 4, 160, x1 + 4, 240], radius=8, fill=OUTLINE)
        d.rounded_rectangle([x0, 164, x1, 236], radius=6, fill=col)
        d.rectangle([x0 + 4, 168, x0 + 12, 232], fill=(255, 150, 70, 255))
    for x0, x1 in ((52, 68), (188, 204)):
        d.rectangle([x0, 168, x1, 232], fill=OUTLINE)
        d.rectangle([x0 + 3, 172, x1 - 3, 228], fill=(120, 116, 112, 255))
    big = big.rotate(angle, resample=Image.BICUBIC, center=(T // 2, 0))
    return big.resize((64, 64), Image.LANCZOS)


def build_low_bar():
    sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    for i, a in enumerate((-2.0, 0.0, 2.0, 0.0)):
        sheet.paste(low_bar_frame(a), (i * 64, 0))
    sheet.save(os.path.join(ANIM, "spritesheet_obstacle_low_bar.png"))
    return sheet


def build_preview(sheet, bar, path):
    ids = [
        [0, 1, 3, 1, 1, 3, 1, 1, 1, 2],
        [12, 8, 8, 8, 8, 8, 8, 8, 8, 13],
        [12, 9, 9, 9, 9, 9, 9, 9, 9, 13],
        [12, 10, 10, 10, 10, 10, 10, 10, 10, 13],
        [12, 11, 11, 11, 11, 11, 11, 11, 11, 13],
        [4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
    ]
    ids[5] = [4] * 10
    out = Image.new("RGBA", (640, 384 + 280), (90, 120, 160, 255))
    for r, row in enumerate(ids):
        for c, i in enumerate(row):
            out.alpha_composite(sheet.crop(((i % 8) * 64, (i // 8) * 64, (i % 8) * 64 + 64, (i // 8) * 64 + 64)), (c * 64, r * 64))
    bar4 = bar.resize((1024, 256), Image.NEAREST)
    strip = Image.new("RGBA", (1024, 256), (70, 70, 80, 255))
    strip.alpha_composite(bar4)
    out2 = Image.new("RGBA", (1024, 384 + 280), (90, 120, 160, 255))
    out2.alpha_composite(out, (0, 0))
    out2.alpha_composite(strip, (0, 400))
    out2.save(path)


if __name__ == "__main__":
    sheet = build_tiles()
    bar = build_low_bar()
    pv = os.environ.get("TUNNEL_PREVIEW")
    if pv:
        build_preview(sheet, bar, pv)
