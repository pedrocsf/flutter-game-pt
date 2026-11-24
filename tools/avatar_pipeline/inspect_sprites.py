import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
DEFAULT_SPRITES_DIR = os.path.join(REPO_ROOT, "assets", "map", "anim", "avatar")
DEFAULT_CONFIG = os.path.join(SCRIPT_DIR, "avatar_config.json")
BACKGROUNDS = {"escuro": (0x20, 0x1A, 0x18, 255), "laranja": (0xFF, 0xD9, 0xC2, 255)}
PREVIEW_SCALE = 3
FRAMES_PER_ROW = 6
GAME_SIZE = 64
HOLE_ALPHA = 0.5
SEAM_ALPHA = 0.85
SOLID_ALPHA = 0.97
EXITING_ANIMATIONS = {"deathPit"}
LOOPING_ANIMATIONS = {"idle", "run", "slide"}


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprites-dir", default=DEFAULT_SPRITES_DIR)
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--variant", default="default")
    parser.add_argument("--preview-dir", required=True)
    return parser.parse_args()


def load_strip(path):
    return Image.open(path)


def check_file(path, frame_count, frame_size, problems):
    if not os.path.exists(path):
        problems.append(f"ausente: {path}")
        return None
    if os.path.getsize(path) == 0:
        problems.append(f"arquivo vazio: {path}")
        return None
    image = Image.open(path)
    if image.mode != "RGBA":
        problems.append(f"modo {image.mode} (esperado RGBA): {path}")
    expected = (frame_count * frame_size, frame_size)
    if image.size != expected:
        problems.append(f"tamanho {image.size} (esperado {expected}): {path}")
    pixels = np.asarray(image.convert("RGBA"))
    if pixels[..., 3].max() == 0:
        problems.append(f"sem pixels visiveis: {path}")
    return pixels


def composite(strips):
    result = np.zeros(strips[0].shape, dtype=np.float64)
    for strip in strips:
        pixels = strip.astype(np.float64) / 255.0
        alpha = pixels[..., 3:4]
        result[..., :3] = pixels[..., :3] * alpha + result[..., :3] * (1.0 - alpha)
        result[..., 3:4] = alpha + result[..., 3:4] * (1.0 - alpha)
    color = np.where(result[..., 3:4] > 0, result[..., :3] / np.maximum(result[..., 3:4], 1e-9), 0.0)
    return np.round(np.concatenate([color, result[..., 3:4]], axis=-1) * 255.0).astype(np.uint8)


def enclosed_holes(alpha):
    mask = Image.fromarray(np.where(alpha > HOLE_ALPHA, 255, 0).astype(np.uint8), "L")
    padded = Image.new("L", (mask.width + 2, mask.height + 2), 0)
    padded.paste(mask, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    filled = np.asarray(padded)[1:-1, 1:-1]
    return int((filled == 0).sum())


def seams(alpha):
    padded = np.pad(alpha, 1)
    neighbours = [padded[1 + dy:1 + dy + alpha.shape[0], 1 + dx:1 + dx + alpha.shape[1]] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]
    solid_around = np.min(neighbours, axis=0) > SOLID_ALPHA
    return int((solid_around & (alpha < SEAM_ALPHA)).sum())


def frame_checks(name, frames, frame_size, problems):
    report = []
    for index, frame in enumerate(frames):
        alpha = frame[..., 3].astype(np.float64) / 255.0
        visible = np.argwhere(alpha > 0.1)
        entry = {"frame": index, "holes": enclosed_holes(alpha), "seams": seams(alpha)}
        if len(visible):
            entry["bbox"] = [int(visible[:, 1].min()), int(visible[:, 0].min()), int(visible[:, 1].max()), int(visible[:, 0].max())]
            touches = []
            if entry["bbox"][0] == 0:
                touches.append("esquerda")
            if entry["bbox"][2] == frame_size - 1:
                touches.append("direita")
            if entry["bbox"][1] == 0:
                touches.append("topo")
            if entry["bbox"][3] == frame_size - 1 and name not in EXITING_ANIMATIONS:
                touches.append("base")
            if touches:
                problems.append(f"{name} quadro {index}: encosta na borda ({', '.join(touches)})")
        elif name not in EXITING_ANIMATIONS:
            problems.append(f"{name} quadro {index}: vazio")
        if entry["seams"] > 0:
            problems.append(f"{name} quadro {index}: {entry['seams']} pixels de fresta")
        report.append(entry)
    return report


def loop_metric(frames):
    def difference(first, second):
        return float(np.abs(first.astype(np.float64) - second.astype(np.float64)).mean())

    steps = [difference(frames[index], frames[index + 1]) for index in range(len(frames) - 1)]
    return {"wrap": difference(frames[-1], frames[0]), "step_mean": float(np.mean(steps)), "step_max": float(np.max(steps))}


def sheet(frames, background, scale, per_row, guides=None):
    size = frames[0].shape[0]
    rows = (len(frames) + per_row - 1) // per_row
    columns = min(per_row, len(frames))
    gap = 2
    canvas = Image.new("RGBA", (columns * (size * scale + gap) + gap, rows * (size * scale + gap) + gap), (90, 90, 90, 255))
    draw = ImageDraw.Draw(canvas)
    for index, frame in enumerate(frames):
        left = gap + (index % per_row) * (size * scale + gap)
        top = gap + (index // per_row) * (size * scale + gap)
        cell = Image.new("RGBA", (size, size), background)
        cell.alpha_composite(Image.fromarray(frame, "RGBA"))
        canvas.paste(cell.resize((size * scale, size * scale), Image.NEAREST), (left, top))
        for row in guides or []:
            y = top + int(row * scale)
            draw.line([(left, y), (left + size * scale - 1, y)], fill=(80, 200, 255, 255))
    return canvas


def game_frames(frames):
    return [np.asarray(Image.fromarray(frame, "RGBA").resize((GAME_SIZE, GAME_SIZE), Image.NEAREST)) for frame in frames]


def main():
    arguments = parse_arguments()
    with open(arguments.config, encoding="utf-8") as handle:
        config = json.load(handle)
    frame_size = config["render"]["frame_size"]
    baseline = config["camera"]["baseline_px"]
    os.makedirs(arguments.preview_dir, exist_ok=True)
    problems = []
    report = {"animations": {}}
    for name, count in config["animations"].items():
        strips = []
        for layer in config["layers"]:
            path = os.path.join(arguments.sprites_dir, f"{layer}_{arguments.variant}_{name}.png")
            pixels = check_file(path, count, frame_size, problems)
            if pixels is not None:
                strips.append(pixels)
        if len(strips) != len(config["layers"]) or any(strip.shape != strips[0].shape for strip in strips):
            continue
        combined = composite(strips)
        frames = [combined[:, index * frame_size:(index + 1) * frame_size] for index in range(count)]
        entry = {"frames": frame_checks(name, frames, frame_size, problems)}
        if name in LOOPING_ANIMATIONS:
            entry["loop"] = loop_metric(frames)
        report["animations"][name] = entry
        for label, background in BACKGROUNDS.items():
            sheet(frames, background, PREVIEW_SCALE, FRAMES_PER_ROW, [baseline]).save(os.path.join(arguments.preview_dir, f"{name}_{label}_3x.png"))
        small = game_frames(frames)
        sheet(small, BACKGROUNDS["escuro"], 1, count).save(os.path.join(arguments.preview_dir, f"{name}_64px_1x.png"))
        sheet(small, BACKGROUNDS["laranja"], PREVIEW_SCALE, 8).save(os.path.join(arguments.preview_dir, f"{name}_64px_3x.png"))
        if name in LOOPING_ANIMATIONS:
            seam = [frames[-2], frames[-1], frames[0], frames[1]]
            sheet(seam, BACKGROUNDS["escuro"], PREVIEW_SCALE, 4, [baseline]).save(os.path.join(arguments.preview_dir, f"{name}_loop_3x.png"))
    with open(os.path.join(arguments.preview_dir, "verification.json"), "w", encoding="utf-8") as handle:
        json.dump({"problems": problems, **report}, handle, indent=2)
    for name, entry in report["animations"].items():
        holes = sum(frame["holes"] for frame in entry["frames"])
        line = f"{name}: buracos fechados {holes}"
        if "loop" in entry:
            loop = entry["loop"]
            line += f", loop wrap {loop['wrap']:.2f} (passo medio {loop['step_mean']:.2f}, max {loop['step_max']:.2f})"
        print(line)
    if problems:
        print("PROBLEMAS:")
        for problem in problems:
            print(f"  - {problem}")
        sys.exit(1)
    print("Verificacao OK")


if __name__ == "__main__":
    main()
