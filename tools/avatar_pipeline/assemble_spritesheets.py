import argparse
import json
import os

import numpy as np
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
DEFAULT_SPRITES_DIR = os.path.join(REPO_ROOT, "assets", "map", "anim", "avatar")
DEFAULT_POSES_DIR = os.path.join(SCRIPT_DIR, "poses")
FULL_TARGET = "full"
MANIFEST_NAME = "manifest.json"
REPORT_NAME = "assembly_report.json"
PRESENT_ALPHA = 0.05
DEFICIT_TOLERANCE = 0.01
TRANSPARENT_EPSILON = 1.0 / 512.0


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True)
    parser.add_argument("--sprites-dir", default=DEFAULT_SPRITES_DIR)
    parser.add_argument("--poses-dir", default=DEFAULT_POSES_DIR)
    parser.add_argument("--skip-poses", action="store_true")
    return parser.parse_args()


def load_premultiplied(path):
    pixels = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    pixels[..., :3] *= pixels[..., 3:4]
    return pixels


def downsample(pixels, factor):
    if factor == 1:
        return pixels
    height, width, channels = pixels.shape
    return pixels.reshape(height // factor, factor, width // factor, factor, channels).mean(axis=(1, 3))


def composite_alpha(alphas):
    remaining = np.ones_like(alphas[0]) if alphas else None
    for alpha in alphas:
        remaining = remaining * (1.0 - alpha)
    return 1.0 - remaining


def corrected_alphas(raw_alphas, full_alpha):
    stack = np.stack(raw_alphas)
    count = stack.shape[0]
    present = stack > PRESENT_ALPHA
    indices = np.arange(count)[:, None, None]
    top = np.where(present, indices, -1).max(axis=0)
    candidates = np.where(present & (indices < top[None]), stack, -1.0)
    occluder = candidates.argmax(axis=0)
    has_occluder = candidates.max(axis=0) > 0.0
    transmittance = np.prod(1.0 - stack, axis=0)
    deficit = full_alpha - (1.0 - transmittance)
    chosen = np.take_along_axis(stack, occluder[None], axis=0)[0]
    others = transmittance / np.maximum(1.0 - chosen, 1e-6)
    target = np.clip(1.0 - (1.0 - full_alpha) / np.maximum(others, 1e-6), chosen, 1.0)
    boost = has_occluder & (deficit > DEFICIT_TOLERANCE) & (chosen < 0.999)
    result = stack.copy()
    for index in range(count):
        mask = boost & (occluder == index)
        result[index] = np.where(mask, target, result[index])
    return list(result)


def straight_rgba(premultiplied, raw_alpha, alpha):
    color = np.where(raw_alpha[..., None] > TRANSPARENT_EPSILON, premultiplied[..., :3] / np.maximum(raw_alpha[..., None], 1e-9), 0.0)
    alpha = np.where(raw_alpha > TRANSPARENT_EPSILON, alpha, 0.0)
    rgba = np.concatenate([np.clip(color, 0.0, 1.0), alpha[..., None]], axis=-1)
    return np.round(rgba * 255.0).astype(np.uint8)


def composite_premultiplied(layers):
    result = np.zeros_like(layers[0])
    for layer in layers:
        result = layer + result * (1.0 - layer[..., 3:4])
    return result


def assemble_frame(raw_dir, animation, frame, order, factor):
    layers = [downsample(load_premultiplied(os.path.join(raw_dir, animation, layer, f"{frame:03d}.png")), factor) for layer in order]
    full = downsample(load_premultiplied(os.path.join(raw_dir, animation, FULL_TARGET, f"{frame:03d}.png")), factor)
    raw_alphas = [layer[..., 3] for layer in layers]
    alphas = corrected_alphas(raw_alphas, full[..., 3])
    outputs = {layer: straight_rgba(pixels, raw, alpha) for layer, pixels, raw, alpha in zip(order, layers, raw_alphas, alphas)}
    rebuilt = composite_premultiplied([decode(outputs[layer]) for layer in order])
    error = np.abs(rebuilt - full)
    return outputs, {"max_alpha_error": float(error[..., 3].max()), "max_color_error": float(error[..., :3].max()), "mean_error": float(error.mean())}


def decode(rgba):
    pixels = rgba.astype(np.float64) / 255.0
    pixels[..., :3] *= pixels[..., 3:4]
    return pixels


def assemble_animation(manifest, raw_dir, animation, sprites_dir):
    info = manifest["animations"][animation]
    order = manifest["layer_order"]
    size = manifest["frame_size"]
    count = info["count"]
    if len(info["frames"]) != count:
        raise SystemExit(f"{animation}: renderizados {len(info['frames'])} de {count} quadros")
    strips = {layer: np.zeros((size, size * count, 4), dtype=np.uint8) for layer in manifest["layers"]}
    errors = []
    for frame in range(count):
        outputs, error = assemble_frame(raw_dir, animation, frame, order, manifest["supersample"])
        errors.append(error)
        for layer in manifest["layers"]:
            strips[layer][:, frame * size:(frame + 1) * size] = outputs[layer]
    written = []
    for layer, strip in strips.items():
        path = os.path.join(sprites_dir, f"{layer}_{manifest['variant']}_{animation}.png")
        Image.fromarray(strip, "RGBA").save(path, optimize=True)
        written.append(path)
    return written, {
        "max_alpha_error": max(error["max_alpha_error"] for error in errors),
        "max_color_error": max(error["max_color_error"] for error in errors),
        "mean_error": float(np.mean([error["mean_error"] for error in errors])),
    }


def assemble_poses(manifest, raw_dir, poses_dir):
    os.makedirs(poses_dir, exist_ok=True)
    written = []
    for name in manifest["poses"]:
        pixels = downsample(load_premultiplied(os.path.join(raw_dir, "poses", f"{name}.png")), manifest["pose_supersample"])
        alpha = pixels[..., 3]
        path = os.path.join(poses_dir, f"{name}.png")
        Image.fromarray(straight_rgba(pixels, alpha, alpha), "RGBA").save(path, optimize=True)
        written.append(path)
    return written


def main():
    arguments = parse_arguments()
    raw_dir = os.path.abspath(arguments.raw)
    with open(os.path.join(raw_dir, MANIFEST_NAME), encoding="utf-8") as handle:
        manifest = json.load(handle)
    os.makedirs(arguments.sprites_dir, exist_ok=True)
    report = {"variant": manifest["variant"], "layers": manifest["layers"], "animations": {}, "files": []}
    for animation in manifest["animations"]:
        written, errors = assemble_animation(manifest, raw_dir, animation, arguments.sprites_dir)
        report["files"] += written
        report["animations"][animation] = errors
        print(f"{animation}: erro max alpha {errors['max_alpha_error']:.3f}, cor {errors['max_color_error']:.3f}")
    if manifest["poses"] and not arguments.skip_poses:
        report["poses"] = assemble_poses(manifest, raw_dir, arguments.poses_dir)
    with open(os.path.join(raw_dir, REPORT_NAME), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print(f"{len(report['files'])} spritesheets gravados em {arguments.sprites_dir}")


if __name__ == "__main__":
    main()
