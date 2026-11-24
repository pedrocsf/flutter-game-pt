import argparse
import json
import os
import sys
import time

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import animations
import build_avatar

FULL_TARGET = "full"
POSES_FOLDER = "poses"
MANIFEST_NAME = "manifest.json"


def parse_arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=build_avatar.DEFAULT_CONFIG_PATH)
    parser.add_argument("--variant", default=build_avatar.DEFAULT_VARIANT)
    parser.add_argument("--layers", default="")
    parser.add_argument("--out", required=True)
    parser.add_argument("--animations", default="")
    parser.add_argument("--frames", default="")
    parser.add_argument("--skip-poses", action="store_true")
    parser.add_argument("--only-poses", action="store_true")
    parser.add_argument("--model-blend", default="")
    parser.add_argument("--save-blend", default="")
    return parser.parse_args(argv)


def split_list(value, fallback):
    return [item for item in value.split(",") if item] if value else list(fallback)


def selected_layers(config, variant, requested):
    if requested:
        return requested
    return [layer for layer in config["layers"] if variant in config["variants"][layer]]


def set_target(rig, target):
    order = rig.config["layers"]
    children = bpy.context.view_layer.layer_collection.children
    for index, layer in enumerate(order):
        collection = rig.collections[layer]
        layer_collection = children[collection.name]
        if target == FULL_TARGET:
            collection.hide_render = False
            layer_collection.holdout = False
            continue
        target_index = order.index(target)
        collection.hide_render = index > target_index
        layer_collection.holdout = index < target_index


def render_to(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_animations(rig, arguments, out_dir):
    config = rig.config
    names = split_list(arguments.animations, config["animations"])
    frame_filter = [int(frame) for frame in split_list(arguments.frames, [])]
    targets = config["layers"] + [FULL_TARGET]
    rendered = {}
    for name in names:
        count = config["animations"][name]
        frames = [frame for frame in range(count) if not frame_filter or frame in frame_filter]
        started = time.time()
        for frame in frames:
            build_avatar.apply_pose(rig, animations.pose_for(name, frame, count))
            for target in targets:
                set_target(rig, target)
                render_to(os.path.join(out_dir, name, target, f"{frame:03d}.png"))
        rendered[name] = frames
        print(f"[avatar] {name}: {len(frames)} quadros em {time.time() - started:.1f}s", flush=True)
    return rendered


def render_poses(rig, out_dir):
    config = rig.config
    size = config["render"]["pose_size"] * config["render"]["pose_supersample"]
    margin = config["render"]["pose_margin"]
    scene = bpy.context.scene
    previous = (scene.render.resolution_x, rig.camera.data.ortho_scale, rig.camera.data.shift_x, rig.camera.data.shift_y)
    set_target(rig, FULL_TARGET)
    bounds = {}
    for name in config["poses"]:
        build_avatar.apply_pose(rig, animations.still_pose(name))
        bounds[name] = build_avatar.camera_space_bounds(rig)
    scale = max(max(right - left, top - bottom) for left, right, bottom, top in bounds.values()) / (1.0 - 2.0 * margin)
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    for name in config["poses"]:
        build_avatar.apply_pose(rig, animations.still_pose(name))
        build_avatar.fit_pose_camera(rig, scale, bounds[name])
        render_to(os.path.join(out_dir, POSES_FOLDER, f"{name}.png"))
    scene.render.resolution_x = previous[0]
    scene.render.resolution_y = previous[0]
    rig.camera.data.ortho_scale, rig.camera.data.shift_x, rig.camera.data.shift_y = previous[1:]
    return list(config["poses"])


def main():
    arguments = parse_arguments()
    config = build_avatar.load_config(arguments.config)
    layers = selected_layers(config, arguments.variant, split_list(arguments.layers, []))
    if not layers:
        raise SystemExit(f"Nenhuma camada define a variante '{arguments.variant}'")
    variants = build_avatar.resolve_variants(config, arguments.variant, layers)
    out_dir = os.path.abspath(arguments.out)
    os.makedirs(out_dir, exist_ok=True)
    rig = build_avatar.build(config, variants, arguments.model_blend or None)
    build_avatar.apply_pose(rig, animations.pose_for("idle", 0, config["animations"]["idle"]))
    camera = build_avatar.fit_sprite_camera(rig)
    if arguments.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arguments.save_blend))
    rendered = {} if arguments.only_poses else render_animations(rig, arguments, out_dir)
    poses = [] if arguments.skip_poses else render_poses(rig, out_dir)
    manifest = {
        "variant": arguments.variant,
        "layers": layers,
        "variants": variants,
        "layer_order": config["layers"],
        "frame_size": config["render"]["frame_size"],
        "supersample": config["render"]["supersample"],
        "pose_size": config["render"]["pose_size"],
        "pose_supersample": config["render"]["pose_supersample"],
        "animations": {name: {"count": config["animations"][name], "frames": frames} for name, frames in rendered.items()},
        "poses": poses,
        "camera": camera,
    }
    with open(os.path.join(out_dir, MANIFEST_NAME), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)


if __name__ == "__main__":
    main()
