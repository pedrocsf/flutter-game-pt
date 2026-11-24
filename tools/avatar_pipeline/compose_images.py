import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_IMAGES_DIR = REPO_ROOT / "assets" / "images"
DEFAULT_POSES_DIR = Path(__file__).resolve().parent / "poses"
SUPERSAMPLE = 4

ORANGE = (248, 95, 0)
ORANGE_LIGHT = (255, 160, 102)
ORANGE_PALE = (255, 214, 186)
DARK = (32, 26, 24)

DASH_WINS = "dash_wins.png"
AUTO_RUN = "auto_run_instruction.png"

DASH_WINS_REMOVE_ABOVE_Y = 45
DASH_WINS_AVATAR_FEET_Y = 74
DASH_WINS_AVATAR_TOP_Y = 1
DASH_WINS_AVATAR_CENTER_X = 112
DASH_WINS_SPARKLES = [
    (80, 12, 6.5, ORANGE_LIGHT),
    (68, 32, 4.5, ORANGE),
    (146, 9, 6.5, ORANGE_PALE),
    (158, 29, 4.5, ORANGE),
    (136, 38, 3.0, ORANGE_LIGHT),
    (88, 36, 3.0, ORANGE_PALE),
]

AUTO_RUN_AVATAR_HEIGHT = 168
AUTO_RUN_AVATAR_FEET_Y = 186
AUTO_RUN_AVATAR_CENTER_X = 112
SPEED_LINES_FADE_START_X = 4
SPEED_LINES_FADE_LENGTH = 34


def load_pose(poses_dir, name):
    pose = Image.open(poses_dir / f"{name}.png").convert("RGBA")
    box = pose.getbbox()
    if box is None:
        raise ValueError(f"pose {name} is empty")
    return pose.crop(box)


def scale_to_height(image, height):
    width = max(1, round(image.width * height / image.height))
    return image.resize((width, height), Image.LANCZOS)


def connected_components(mask):
    height, width = mask.shape
    labels = np.zeros((height, width), dtype=np.int32)
    count = 0
    for start_y, start_x in zip(*np.nonzero(mask)):
        if labels[start_y, start_x]:
            continue
        count += 1
        labels[start_y, start_x] = count
        queue = deque([(start_y, start_x)])
        while queue:
            y, x = queue.popleft()
            for next_y in range(max(0, y - 1), min(height, y + 2)):
                for next_x in range(max(0, x - 1), min(width, x + 2)):
                    if mask[next_y, next_x] and not labels[next_y, next_x]:
                        labels[next_y, next_x] = count
                        queue.append((next_y, next_x))
    return labels, count


def remove_components_reaching_above(image, limit_y):
    pixels = np.array(image)
    labels, count = connected_components(pixels[:, :, 3] > 0)
    removed = 0
    for label in range(1, count + 1):
        rows = np.nonzero(labels == label)[0]
        if rows.min() >= limit_y:
            continue
        if rows.max() > DASH_WINS_AVATAR_FEET_Y + 2:
            raise ValueError("character touches the trophy or the wreath")
        pixels[labels == label] = 0
        removed += 1
    if removed == 0:
        raise ValueError("no character found above the wreath")
    return Image.fromarray(pixels, "RGBA")


def compose_dash_wins(source, poses_dir):
    base = remove_components_reaching_above(source, DASH_WINS_REMOVE_ABOVE_Y)
    avatar = scale_to_height(
        load_pose(poses_dir, "celebrate"),
        DASH_WINS_AVATAR_FEET_Y - DASH_WINS_AVATAR_TOP_Y,
    )
    base.alpha_composite(sparkles_layer(base.size, DASH_WINS_SPARKLES))
    base.alpha_composite(
        avatar,
        (DASH_WINS_AVATAR_CENTER_X - avatar.width // 2, DASH_WINS_AVATAR_TOP_Y),
    )
    return base


def sparkle_points(center_x, center_y, radius):
    waist = radius * 0.28
    return [
        (center_x, center_y - radius),
        (center_x + waist, center_y - waist),
        (center_x + radius, center_y),
        (center_x + waist, center_y + waist),
        (center_x, center_y + radius),
        (center_x - waist, center_y + waist),
        (center_x - radius, center_y),
        (center_x - waist, center_y - waist),
    ]


def sparkles_layer(size, sparkles):
    big = Image.new("RGBA", (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    for center_x, center_y, radius, color in sparkles:
        points = sparkle_points(
            center_x * SUPERSAMPLE, center_y * SUPERSAMPLE, radius * SUPERSAMPLE
        )
        draw.polygon(points, fill=color + (255,))
    return big.resize(size, Image.LANCZOS)


def draw_speed_line(draw, start, end, thickness, color):
    radius = thickness / 2
    draw.line([start, end], fill=color, width=round(thickness))
    for point in (start, end):
        draw.ellipse(
            [point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius],
            fill=color,
        )


def speed_lines_layer(size):
    big = Image.new("RGBA", (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    lines = [
        (22, 70, 64, 7, ORANGE, 255),
        (8, 98, 58, 7, ORANGE_LIGHT, 255),
        (26, 126, 60, 7, ORANGE, 230),
        (14, 152, 46, 6, ORANGE_LIGHT, 220),
    ]
    for start_x, y, end_x, thickness, color, alpha in lines:
        draw_speed_line(
            draw,
            (start_x * SUPERSAMPLE, y * SUPERSAMPLE),
            (end_x * SUPERSAMPLE, y * SUPERSAMPLE),
            thickness * SUPERSAMPLE,
            color + (alpha,),
        )
    fade = np.clip(
        (np.arange(big.width) / SUPERSAMPLE - SPEED_LINES_FADE_START_X)
        / SPEED_LINES_FADE_LENGTH,
        0.0,
        1.0,
    )
    pixels = np.array(big).astype(np.float32)
    pixels[:, :, 3] *= fade[np.newaxis, :]
    big = Image.fromarray(pixels.round().astype(np.uint8), "RGBA")
    return big.resize(size, Image.LANCZOS)


def ground_shadow_layer(size, center_x, center_y, half_width):
    big = Image.new("RGBA", (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    half_height = half_width * 0.16
    draw.ellipse(
        [
            (center_x - half_width) * SUPERSAMPLE,
            (center_y - half_height) * SUPERSAMPLE,
            (center_x + half_width) * SUPERSAMPLE,
            (center_y + half_height) * SUPERSAMPLE,
        ],
        fill=DARK + (110,),
    )
    big = big.filter(ImageFilter.GaussianBlur(2.5 * SUPERSAMPLE))
    return big.resize(size, Image.LANCZOS)


def compose_auto_run(size, poses_dir):
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    avatar = scale_to_height(load_pose(poses_dir, "run"), AUTO_RUN_AVATAR_HEIGHT)
    canvas.alpha_composite(
        ground_shadow_layer(size, AUTO_RUN_AVATAR_CENTER_X, AUTO_RUN_AVATAR_FEET_Y - 2, 52)
    )
    canvas.alpha_composite(speed_lines_layer(size))
    canvas.alpha_composite(
        avatar,
        (
            AUTO_RUN_AVATAR_CENTER_X - avatar.width // 2,
            AUTO_RUN_AVATAR_FEET_Y - avatar.height,
        ),
    )
    return canvas


def save_like(result, reference, path):
    if result.size != reference.size:
        raise ValueError(f"{path.name}: size {result.size} != {reference.size}")
    result.convert(reference.mode).save(path, optimize=True)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_IMAGES_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_IMAGES_DIR)
    parser.add_argument("--poses-dir", type=Path, default=DEFAULT_POSES_DIR)
    return parser.parse_args()


def main():
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    dash_wins_source = Image.open(args.source_dir / DASH_WINS)
    save_like(
        compose_dash_wins(dash_wins_source.convert("RGBA"), args.poses_dir),
        dash_wins_source,
        args.out_dir / DASH_WINS,
    )

    auto_run_reference = Image.open(args.source_dir / AUTO_RUN)
    save_like(
        compose_auto_run(auto_run_reference.size, args.poses_dir),
        auto_run_reference,
        args.out_dir / AUTO_RUN,
    )

    for name in (DASH_WINS, AUTO_RUN):
        print(f"{args.out_dir / name}")


if __name__ == "__main__":
    main()
