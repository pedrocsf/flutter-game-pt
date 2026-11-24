import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG_PATH = os.path.join(SCRIPT_DIR, "avatar_config.json")
DEFAULT_VARIANT = "default"
LAYER_PROPERTY = "avatar_layer"
JOINT_PROPERTY = "avatar_joint"
OUTLINE_PROPERTY = "avatar_outline"
EXTERNAL_MATERIAL_PREFIX = "avatar:"
COLLECTION_PREFIX = "avatar_"
RIG_COLLECTION = "avatar_rig"
SIDE_SIGN = {"R": -1.0, "L": 1.0}
SHOULDER_REST_SPREAD_DEG = 7.0
HIP_REST_SPREAD_DEG = 2.0
PITCH_JOINTS = ("pelvis", "spine", "neck", "head")
DEFAULT_PIVOT_HEIGHT = 0.9
CAMERA_DISTANCE = 12.0
CAMERA_TARGET = Vector((0.0, 0.0, 0.9))
BLINK_SQUASH = 0.85

HEAD_CENTER = Vector((0.02, 0.0, 1.6))
HEAD_RADII = Vector((0.198, 0.182, 0.218))


def joint_table():
    joints = [
        ("root", None, (0.0, 0.0, 0.0)),
        ("pelvis", "root", (0.0, 0.0, 0.90)),
        ("spine", "pelvis", (0.0, 0.0, 0.98)),
        ("neck", "spine", (0.0, 0.0, 1.35)),
        ("head", "neck", (0.01, 0.0, 1.43)),
    ]
    for side, sign in SIDE_SIGN.items():
        joints += [
            (f"shoulder_{side}", "spine", (0.0, 0.225 * sign, 1.29)),
            (f"elbow_{side}", f"shoulder_{side}", (0.0, 0.225 * sign, 1.035)),
            (f"wrist_{side}", f"elbow_{side}", (0.0, 0.225 * sign, 0.81)),
            (f"hip_{side}", "pelvis", (0.0, 0.1 * sign, 0.86)),
            (f"knee_{side}", f"hip_{side}", (0.0, 0.1 * sign, 0.48)),
            (f"ankle_{side}", f"knee_{side}", (0.0, 0.1 * sign, 0.11)),
        ]
    return joints


def load_config(path=DEFAULT_CONFIG_PATH):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def resolve_variants(config, variant, layers):
    resolved = {}
    for layer in config["layers"]:
        chosen = variant if layer in layers else DEFAULT_VARIANT
        if chosen not in config["variants"][layer]:
            raise ValueError(f"Variante '{chosen}' nao existe para a camada '{layer}'")
        resolved[layer] = chosen
    return resolved


def hex_to_linear(hex_color):
    value = hex_color.lstrip("#")
    channels = [int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)]
    return [srgb_to_linear(channel) for channel in channels]


def srgb_to_linear(channel):
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def superellipse(angle, exponent):
    cosine = math.cos(angle)
    sine = math.sin(angle)
    power = 2.0 / exponent
    return (
        math.copysign(abs(cosine) ** power, cosine),
        math.copysign(abs(sine) ** power, sine),
    )


def axis_point(axis, along, first, second):
    if axis == "X":
        return (along, first, second)
    if axis == "Y":
        return (first, along, second)
    return (first, second, along)


def normalize_ring(ring):
    return tuple(ring) + (0.0,) * (5 - len(ring))


def expand_rings(rings, dome_start, dome_end, dome_steps):
    normalized = [normalize_ring(ring) for ring in rings]
    first = normalized[0]
    last = normalized[-1]
    expanded = []
    for step in range(dome_steps - 1, 0, -1):
        theta = step / dome_steps * math.pi / 2
        expanded.append((
            first[0] - dome_start * math.sin(theta),
            first[1] * math.cos(theta),
            first[2] * math.cos(theta),
            first[3],
            first[4],
        ))
    expanded += normalized
    for step in range(1, dome_steps):
        theta = step / dome_steps * math.pi / 2
        expanded.append((
            last[0] + dome_end * math.sin(theta),
            last[1] * math.cos(theta),
            last[2] * math.cos(theta),
            last[3],
            last[4],
        ))
    start_apex = (first[0] - dome_start, first[3], first[4])
    end_apex = (last[0] + dome_end, last[3], last[4])
    return expanded, start_apex, end_apex


def loft_mesh(name, rings, axis="Z", segments=24, exponent=2.0, dome_start=0.0, dome_end=0.0, dome_steps=5):
    expanded, start_apex, end_apex = expand_rings(rings, dome_start, dome_end, dome_steps)
    profile = [superellipse(2 * math.pi * index / segments, exponent) for index in range(segments)]
    vertices = [axis_point(axis, *start_apex)]
    for along, half_first, half_second, offset_first, offset_second in expanded:
        vertices += [
            axis_point(axis, along, offset_first + half_first * first, offset_second + half_second * second)
            for first, second in profile
        ]
    vertices.append(axis_point(axis, *end_apex))

    def ring_vertex(ring, index):
        return 1 + ring * segments + index % segments

    last_ring = len(expanded) - 1
    end_vertex = len(vertices) - 1
    faces = [(0, ring_vertex(0, index + 1), ring_vertex(0, index)) for index in range(segments)]
    for ring in range(last_ring):
        for index in range(segments):
            faces.append((
                ring_vertex(ring, index),
                ring_vertex(ring, index + 1),
                ring_vertex(ring + 1, index + 1),
                ring_vertex(ring + 1, index),
            ))
    faces += [(ring_vertex(last_ring, index), ring_vertex(last_ring, index + 1), end_vertex) for index in range(segments)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    finalize_mesh(mesh)
    return mesh


def finalize_mesh(mesh):
    surface = bmesh.new()
    surface.from_mesh(mesh)
    bmesh.ops.remove_doubles(surface, verts=surface.verts[:], dist=1e-7)
    bmesh.ops.recalc_face_normals(surface, faces=surface.faces[:])
    surface.to_mesh(mesh)
    surface.free()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()


def ellipsoid_mesh(name, center, radii, segments=24, steps=8):
    ring = (center[2], radii[0], radii[1], center[0], center[1])
    return loft_mesh(name, [ring], "Z", segments, 2.0, radii[2], radii[2], steps)


def capsule_mesh(name, top, length, radius_top, radius_bottom, segments=20):
    x, y, z = top
    rings = [(z - length, radius_bottom, radius_bottom, x, y), (z, radius_top, radius_top, x, y)]
    return loft_mesh(name, rings, "Z", segments, 2.0, radius_bottom, radius_top, 5)


def cut_mesh(mesh, plane_point, plane_normal):
    surface = bmesh.new()
    surface.from_mesh(mesh)
    geometry = surface.verts[:] + surface.edges[:] + surface.faces[:]
    bmesh.ops.bisect_plane(
        surface,
        geom=geometry,
        dist=1e-6,
        plane_co=plane_point,
        plane_no=plane_normal,
        clear_inner=True,
    )
    bmesh.ops.holes_fill(surface, edges=surface.edges[:], sides=0)
    bmesh.ops.recalc_face_normals(surface, faces=surface.faces[:])
    surface.to_mesh(mesh)
    surface.free()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()
    return mesh


def facing_matrix(normal):
    forward = Vector(normal).normalized()
    side = Vector((0.0, 0.0, 1.0)).cross(forward).normalized()
    up = forward.cross(side)
    return Matrix((forward, side, up)).transposed().to_4x4()


def head_surface(azimuth_deg, elevation_deg, inset=0.0):
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    direction = Vector((
        math.cos(elevation) * math.cos(azimuth),
        math.cos(elevation) * math.sin(azimuth),
        math.sin(elevation),
    ))
    point = HEAD_CENTER + Vector((HEAD_RADII.x * direction.x, HEAD_RADII.y * direction.y, HEAD_RADII.z * direction.z))
    normal = Vector((direction.x / HEAD_RADII.x, direction.y / HEAD_RADII.y, direction.z / HEAD_RADII.z)).normalized()
    return point - normal * inset, normal


def surface_feature_mesh(name, radii, normal):
    mesh = ellipsoid_mesh(name, (0.0, 0.0, 0.0), radii, 16, 6)
    mesh.transform(facing_matrix(normal))
    return mesh


class AvatarRig:
    def __init__(self, config, variants):
        self.config = config
        self.variants = variants
        self.joints = {}
        self.rest = {}
        self.collections = {}
        self.materials = {}
        self.layer_objects = {layer: [] for layer in config["layers"]}
        self.blink_objects = []
        self.outline_material = None
        self.camera = None

    @property
    def all_objects(self):
        return [obj for layer in self.config["layers"] for obj in self.layer_objects[layer]]

    def colors(self, layer):
        return self.config["variants"][layer][self.variants[layer]]["colors"]

    def mesh_name(self, layer):
        return self.config["variants"][layer][self.variants[layer]]["mesh"]

    def material(self, layer, key):
        name = f"{layer}_{key}"
        if name not in self.materials:
            self.materials[name] = toon_material(name, self.colors(layer)[key], self.config["shading"])
        return self.materials[name]

    def part(self, layer, name, mesh, joint, color_key, outline=True, origin=None, subdivide=True):
        obj = bpy.data.objects.new(f"{layer}_{name}", mesh)
        mesh.materials.append(self.material(layer, color_key))
        self.collections[layer].objects.link(obj)
        obj[LAYER_PROPERTY] = layer
        obj[JOINT_PROPERTY] = joint
        self.parent_to_joint(obj, joint)
        if origin is not None:
            obj.location = origin
        if subdivide:
            modifier = obj.modifiers.new("Smooth", "SUBSURF")
            modifier.levels = 1
            modifier.render_levels = 1
        if outline:
            self.add_outline(obj)
        self.layer_objects[layer].append(obj)
        return obj

    def parent_to_joint(self, obj, joint):
        obj.parent = self.joints[joint]
        obj.matrix_parent_inverse = Matrix.Translation(-self.rest[joint])

    def add_outline(self, obj):
        thickness = self.config["outline"]["thickness"]
        if thickness <= 0:
            return
        slot_count = len(obj.data.materials)
        obj.data.materials.append(self.outline_material)
        modifier = obj.modifiers.new("Outline", "SOLIDIFY")
        modifier.thickness = thickness
        modifier.offset = 1.0
        modifier.use_flip_normals = True
        modifier.use_rim = False
        modifier.use_even_offset = True
        modifier.material_offset = slot_count


def toon_material(name, hex_color, shading):
    lit = hex_to_linear(hex_color)
    shadow = [channel * factor for channel, factor in zip(lit, shading["shadow_multiplier"])]
    highlight = [min(1.0, channel * shading["highlight_multiplier"]) for channel in lit]
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    nodes = tree.nodes
    links = tree.links
    nodes.clear()
    geometry = nodes.new("ShaderNodeNewGeometry")
    key = light_term(nodes, links, geometry, shading["key_light"], 1.0)
    fill = light_term(nodes, links, geometry, shading["fill_light"], shading["fill_strength"])
    total = math_node(nodes, "ADD")
    links.new(key, total.inputs[0])
    links.new(fill, total.inputs[1])
    lighting = math_node(nodes, "ADD")
    links.new(total.outputs[0], lighting.inputs[0])
    lighting.inputs[1].default_value = shading["ambient"]
    band = band_node(nodes, links, lighting.outputs[0], shading["band"], shading["band_softness"])
    highlight_band = band_node(nodes, links, lighting.outputs[0], shading["highlight_band"], shading["band_softness"])
    base_mix = color_mix(nodes, links, band, shadow, lit)
    final_mix = color_mix(nodes, links, highlight_band, None, highlight, base_mix)
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = 1.0
    links.new(final_mix, emission.inputs["Color"])
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(emission.outputs[0], output.inputs["Surface"])
    return material


def math_node(nodes, operation):
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    return node


def light_term(nodes, links, geometry, direction, strength):
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    links.new(geometry.outputs["Normal"], dot.inputs[0])
    dot.inputs[1].default_value = Vector(direction).normalized()
    clamped = math_node(nodes, "MAXIMUM")
    links.new(dot.outputs["Value"], clamped.inputs[0])
    clamped.inputs[1].default_value = 0.0
    scaled = math_node(nodes, "MULTIPLY")
    links.new(clamped.outputs[0], scaled.inputs[0])
    scaled.inputs[1].default_value = strength
    return scaled.outputs[0]


def band_node(nodes, links, value, center, softness):
    node = nodes.new("ShaderNodeMapRange")
    node.interpolation_type = "SMOOTHSTEP"
    node.clamp = True
    links.new(value, node.inputs["Value"])
    node.inputs["From Min"].default_value = center - softness
    node.inputs["From Max"].default_value = center + softness
    node.inputs["To Min"].default_value = 0.0
    node.inputs["To Max"].default_value = 1.0
    return node.outputs["Result"]


def color_mix(nodes, links, factor, color_a, color_b, socket_a=None):
    node = nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    links.new(factor, node.inputs["Factor"])
    input_a = next(socket for socket in node.inputs if socket.name == "A" and socket.type == "RGBA")
    input_b = next(socket for socket in node.inputs if socket.name == "B" and socket.type == "RGBA")
    if socket_a is not None:
        links.new(socket_a, input_a)
    else:
        input_a.default_value = (*color_a, 1.0)
    input_b.default_value = (*color_b, 1.0)
    return next(socket for socket in node.outputs if socket.name == "Result" and socket.type == "RGBA")


def outline_material(hex_color):
    material = bpy.data.materials.new("avatar_outline")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*hex_to_linear(hex_color), 1.0)
    emission.inputs["Strength"].default_value = 1.0
    output = nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    material.use_backface_culling = True
    return material


def build_body_standard(rig):
    rig.part("body", "head", ellipsoid_mesh("head", HEAD_CENTER, HEAD_RADII, 28, 10), "head", "skin")
    rig.part("body", "neck", capsule_mesh("neck", (0.01, 0.0, 1.47), 0.16, 0.064, 0.066), "neck", "skin")
    nose_point, nose_normal = head_surface(-4, -10, 0.012)
    rig.part("body", "nose", surface_feature_mesh("nose", (0.036, 0.03, 0.036), nose_normal), "head", "skin", origin=nose_point)
    for side, sign in SIDE_SIGN.items():
        ear_point, ear_normal = head_surface(92 * sign, -4, 0.01)
        rig.part("body", f"ear_{side}", surface_feature_mesh(f"ear_{side}", (0.022, 0.04, 0.056), ear_normal), "head", "skin", origin=ear_point)
        eye_point, eye_normal = head_surface(28 * sign, 4, 0.006)
        eye = rig.part("body", f"eye_{side}", surface_feature_mesh(f"eye_{side}", (0.014, 0.022, 0.038), eye_normal), "head", "eyes", outline=False, origin=eye_point, subdivide=False)
        eye["avatar_blink"] = 1
        rig.blink_objects.append(eye)
        shoulder = rig.rest[f"shoulder_{side}"]
        elbow = rig.rest[f"elbow_{side}"]
        wrist = rig.rest[f"wrist_{side}"]
        rig.part("body", f"upper_arm_{side}", capsule_mesh(f"upper_arm_{side}", shoulder, 0.255, 0.064, 0.058), f"shoulder_{side}", "skin")
        rig.part("body", f"forearm_{side}", capsule_mesh(f"forearm_{side}", elbow, 0.225, 0.058, 0.05), f"elbow_{side}", "skin")
        hand_center = (wrist.x + 0.006, wrist.y, wrist.z - 0.064)
        rig.part("body", f"hand_{side}", ellipsoid_mesh(f"hand_{side}", hand_center, (0.058, 0.042, 0.072), 20, 6), f"wrist_{side}", "skin")
    mouth_point, mouth_normal = head_surface(-16, -30, 0.004)
    rig.part("body", "mouth", surface_feature_mesh("mouth", (0.01, 0.034, 0.009), mouth_normal), "head", "mouth", outline=False, origin=mouth_point, subdivide=False)


def build_hair_short(rig):
    center = HEAD_CENTER + Vector((-0.014, 0.0, 0.026))
    radii = (HEAD_RADII.x + 0.016, HEAD_RADII.y + 0.016, HEAD_RADII.z + 0.008)
    cap = ellipsoid_mesh("hair_cap", center, radii, 28, 10)
    front = HEAD_CENTER + Vector((0.17, 0.0, 0.1))
    back = HEAD_CENTER + Vector((-0.21, 0.0, -0.1))
    direction = front - back
    normal = Vector((-direction.z, 0.0, direction.x)).normalized()
    cut_mesh(cap, front, normal)
    rig.part("hair", "cap", cap, "head", "hair")
    quiff_center = HEAD_CENTER + Vector((0.08, 0.0, 0.165))
    rig.part("hair", "quiff", ellipsoid_mesh("hair_quiff", quiff_center, (0.1, 0.13, 0.06), 20, 6), "head", "hair")
    for side, sign in SIDE_SIGN.items():
        brow_point, brow_normal = head_surface(27 * sign, 19, -0.004)
        rig.part("hair", f"brow_{side}", surface_feature_mesh(f"brow_{side}", (0.012, 0.034, 0.011), brow_normal), "head", "hair", outline=False, origin=brow_point, subdivide=False)


def torso_rings():
    return [
        (0.83, 0.142, 0.178, 0.0),
        (0.95, 0.138, 0.172, 0.006),
        (1.12, 0.148, 0.186, 0.014),
        (1.27, 0.145, 0.198, 0.0),
        (1.34, 0.12, 0.18, -0.006),
    ]


def build_shirt_common(rig, rings):
    rig.part("shirt", "torso", loft_mesh("shirt_torso", rings, "Z", 28, 2.6, 0.02, 0.05, 5), "spine", "fabric")
    collar = [(1.355, 0.082, 0.082, 0.012), (1.39, 0.078, 0.078, 0.012)]
    rig.part("shirt", "collar", loft_mesh("shirt_collar", collar, "Z", 24, 2.0, 0.006, 0.006, 3), "spine", "trim", outline=False)


def build_shirt_tshirt(rig):
    build_shirt_common(rig, torso_rings())
    for side in SIDE_SIGN:
        shoulder = rig.rest[f"shoulder_{side}"]
        sleeve = [(shoulder.z - 0.15, 0.084, 0.084, shoulder.x, shoulder.y), (shoulder.z, 0.09, 0.09, shoulder.x, shoulder.y)]
        rig.part("shirt", f"sleeve_{side}", loft_mesh(f"sleeve_{side}", sleeve, "Z", 20, 2.0, 0.0, 0.075, 5), f"shoulder_{side}", "fabric")
        cuff = [(shoulder.z - 0.16, 0.087, 0.087, shoulder.x, shoulder.y), (shoulder.z - 0.13, 0.087, 0.087, shoulder.x, shoulder.y)]
        rig.part("shirt", f"sleeve_cuff_{side}", loft_mesh(f"sleeve_cuff_{side}", cuff, "Z", 20, 2.0, 0.004, 0.004, 3), f"shoulder_{side}", "trim", outline=False)


def build_shirt_tank(rig):
    rings = [(z, depth, width * 0.93, offset) for z, depth, width, offset in torso_rings()]
    build_shirt_common(rig, rings)


def build_pants_jogger(rig):
    pelvis = [(0.75, 0.138, 0.178), (0.88, 0.142, 0.186), (0.97, 0.135, 0.176)]
    rig.part("pants", "pelvis", loft_mesh("pants_pelvis", pelvis, "Z", 24, 2.4, 0.03, 0.015, 4), "pelvis", "fabric")
    for side in SIDE_SIGN:
        hip = rig.rest[f"hip_{side}"]
        knee = rig.rest[f"knee_{side}"]
        rig.part("pants", f"thigh_{side}", capsule_mesh(f"thigh_{side}", hip, 0.38, 0.1, 0.082), f"hip_{side}", "fabric")
        rig.part("pants", f"shin_{side}", capsule_mesh(f"shin_{side}", knee, 0.32, 0.08, 0.064), f"knee_{side}", "fabric")
        cuff = [(0.115, 0.07, 0.07, knee.x, knee.y), (0.185, 0.072, 0.072, knee.x, knee.y)]
        rig.part("pants", f"cuff_{side}", loft_mesh(f"cuff_{side}", cuff, "Z", 20, 2.0, 0.012, 0.008, 3), f"knee_{side}", "cuff")


def build_shoes_sneaker(rig):
    for side, sign in SIDE_SIGN.items():
        ankle = rig.rest[f"ankle_{side}"]
        y = ankle.y
        upper = [
            (-0.08, 0.054, 0.046, y, 0.064),
            (-0.04, 0.061, 0.062, y, 0.072),
            (0.045, 0.063, 0.058, y, 0.066),
            (0.14, 0.06, 0.045, y, 0.052),
            (0.195, 0.05, 0.034, y, 0.044),
        ]
        rig.part("shoes", f"upper_{side}", loft_mesh(f"shoe_upper_{side}", upper, "X", 24, 2.6, 0.025, 0.035, 5), f"ankle_{side}", "upper")
        sole = [(-0.1, 0.064, 0.016, y, 0.018), (0.05, 0.066, 0.016, y, 0.018), (0.21, 0.056, 0.016, y, 0.02)]
        rig.part("shoes", f"sole_{side}", loft_mesh(f"shoe_sole_{side}", sole, "X", 24, 4.0, 0.012, 0.022, 4), f"ankle_{side}", "sole")
        accent_center = (0.035, y + sign * 0.058, 0.064)
        rig.part("shoes", f"accent_{side}", ellipsoid_mesh(f"shoe_accent_{side}", accent_center, (0.055, 0.012, 0.017), 16, 5), f"ankle_{side}", "accent", outline=False)


MESH_BUILDERS = {
    "body": {"standard": build_body_standard},
    "hair": {"short": build_hair_short},
    "shirt": {"tshirt": build_shirt_tshirt, "tank": build_shirt_tank},
    "pants": {"jogger": build_pants_jogger},
    "shoes": {"sneaker": build_shoes_sneaker},
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def configure_render(config, size):
    scene = bpy.context.scene
    render = scene.render
    render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = config["render"]["taa_samples"]
    render.film_transparent = True
    render.filter_size = config["render"]["filter_size"]
    render.resolution_x = size
    render.resolution_y = size
    render.resolution_percentage = 100
    render.dither_intensity = 0.0
    render.use_compositing = False
    render.use_sequencer = False
    render.image_settings.file_format = "PNG"
    render.image_settings.color_mode = "RGBA"
    render.image_settings.color_depth = "8"
    render.image_settings.compression = 15
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0


def create_world():
    world = bpy.data.worlds.new("avatar_world")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    background.inputs["Strength"].default_value = 0.0
    bpy.context.scene.world = world


def create_camera(config):
    data = bpy.data.cameras.new("avatar_camera")
    data.type = "ORTHO"
    data.ortho_scale = 2.0
    data.clip_start = 0.1
    data.clip_end = CAMERA_DISTANCE * 3
    camera = bpy.data.objects.new("avatar_camera", data)
    bpy.context.scene.collection.objects.link(camera)
    azimuth = math.radians(config["camera"]["azimuth_deg"])
    elevation = math.radians(config["camera"]["elevation_deg"])
    direction = Vector((
        math.sin(azimuth) * math.cos(elevation),
        -math.cos(azimuth) * math.cos(elevation),
        math.sin(elevation),
    ))
    camera.location = CAMERA_TARGET + direction * CAMERA_DISTANCE
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    return camera


def create_collections(rig):
    scene_collection = bpy.context.scene.collection
    rig_collection = bpy.data.collections.new(RIG_COLLECTION)
    scene_collection.children.link(rig_collection)
    for layer in rig.config["layers"]:
        collection = bpy.data.collections.new(COLLECTION_PREFIX + layer)
        scene_collection.children.link(collection)
        rig.collections[layer] = collection
    return rig_collection


def create_joints(rig, rig_collection, rest_override=None):
    for name, parent, position in joint_table():
        rest = Vector(rest_override.get(name, position) if rest_override else position)
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "SPHERE"
        empty.empty_display_size = 0.03
        empty.rotation_mode = "XYZ"
        empty[JOINT_PROPERTY] = name
        rig_collection.objects.link(empty)
        if parent is not None:
            empty.parent = rig.joints[parent]
            empty.matrix_parent_inverse = Matrix.Translation(-rig.rest[parent])
        empty.location = rest
        rig.joints[name] = empty
        rig.rest[name] = rest


def chained_world(obj):
    if obj.parent is None:
        return obj.matrix_basis.copy()
    return chained_world(obj.parent) @ obj.matrix_parent_inverse @ obj.matrix_basis


def read_external_joints(path):
    with bpy.data.libraries.load(path, link=False) as (source, target):
        target.objects = list(source.objects)
    objects = [obj for obj in target.objects if obj is not None]
    worlds = {obj.name: chained_world(obj) for obj in objects}
    rest = {}
    meshes = []
    for obj in objects:
        if obj.type == "MESH" and LAYER_PROPERTY in obj:
            meshes.append((obj, worlds[obj.name]))
        elif obj.type == "EMPTY" and JOINT_PROPERTY in obj:
            rest[obj[JOINT_PROPERTY]] = tuple(worlds[obj.name].translation)
    for obj in objects:
        if not (obj.type == "MESH" and LAYER_PROPERTY in obj):
            bpy.data.objects.remove(obj)
    return rest, meshes


def attach_external_meshes(rig, meshes):
    for obj, world in meshes:
        layer = obj[LAYER_PROPERTY]
        joint = obj[JOINT_PROPERTY]
        obj.parent = None
        obj.matrix_basis = world
        rig.collections[layer].objects.link(obj)
        for slot in obj.material_slots:
            if slot.material is not None and slot.material.name.startswith(EXTERNAL_MATERIAL_PREFIX):
                slot.material = rig.material(layer, slot.material.name[len(EXTERNAL_MATERIAL_PREFIX):])
        obj.parent = rig.joints[joint]
        obj.matrix_parent_inverse = Matrix.Translation(-rig.rest[joint])
        if obj.get(OUTLINE_PROPERTY, 1) and not any(modifier.type == "SOLIDIFY" for modifier in obj.modifiers):
            rig.add_outline(obj)
        if obj.get("avatar_blink", 0):
            rig.blink_objects.append(obj)
        rig.layer_objects[layer].append(obj)


def build(config, variants, model_blend=None):
    reset_scene()
    configure_render(config, config["render"]["frame_size"] * config["render"]["supersample"])
    create_world()
    rig = AvatarRig(config, variants)
    rig.outline_material = outline_material(config["outline"]["color"])
    rig_collection = create_collections(rig)
    if model_blend:
        rest, meshes = read_external_joints(model_blend)
        create_joints(rig, rig_collection, rest)
        attach_external_meshes(rig, meshes)
    else:
        create_joints(rig, rig_collection)
        for layer in config["layers"]:
            MESH_BUILDERS[layer][rig.mesh_name(layer)](rig)
    rig.camera = create_camera(config)
    bpy.context.view_layer.update()
    return rig


def joint_rotation(name, channels):
    def value(channel, default=0.0):
        return math.radians(channels.get(f"{name}.{channel}", default))

    if name in PITCH_JOINTS:
        return (value("roll"), value("pitch"), value("yaw"))
    kind, side = name.split("_")
    sign = SIDE_SIGN[side]
    if kind == "shoulder":
        spread = value("spread") + math.radians(SHOULDER_REST_SPREAD_DEG)
        return (sign * spread, -value("swing"), value("twist"))
    if kind == "hip":
        spread = value("spread") + math.radians(HIP_REST_SPREAD_DEG)
        return (sign * spread, -value("swing"), value("twist"))
    if kind == "knee":
        return (0.0, value("bend"), 0.0)
    return (0.0, -value("bend"), 0.0)


def root_matrix(channels):
    pivot = Vector((0.0, 0.0, channels.get("root.pivot", DEFAULT_PIVOT_HEIGHT)))
    offset = Vector((channels.get("root.x", 0.0), 0.0, channels.get("root.z", 0.0)))
    rotation = Matrix.Rotation(math.radians(channels.get("root.pitch", 0.0)), 4, "Y")
    scale = Matrix.Scale(channels.get("root.scale", 1.0), 4)
    return Matrix.Translation(offset + pivot) @ rotation @ scale @ Matrix.Translation(-pivot)


def evaluated_points(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    chunks = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        coordinates = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", coordinates)
        coordinates = coordinates.reshape(-1, 3)
        world = np.array(evaluated.matrix_world)
        chunks.append(coordinates @ world[:3, :3].T + world[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(chunks)


def apply_pose(rig, pose):
    channels = pose["channels"]
    for name, joint in rig.joints.items():
        if name == "root":
            continue
        joint.rotation_euler = joint_rotation(name, channels)
    rig.joints["spine"].scale = (1.0, 1.0, 1.0 + channels.get("spine.stretch", 0.0))
    for obj in rig.blink_objects:
        obj.scale = (1.0, 1.0, 1.0 - BLINK_SQUASH * channels.get("face.blink", 0.0))
    root = rig.joints["root"]
    root.matrix_world = root_matrix(channels)
    bpy.context.view_layer.update()
    centering = channels.get("root.center", 0.0)
    if centering > 0.0:
        points = evaluated_points(rig.all_objects)
        middle = (points[:, 0].min() + points[:, 0].max()) / 2.0
        root.location.x += centering * (channels.get("root.x", 0.0) - middle)
        bpy.context.view_layer.update()
    ground = pose.get("ground")
    if ground is None:
        return
    objects = rig.layer_objects["shoes"] if ground == "feet" else rig.all_objects
    lowest = evaluated_points(objects)[:, 2].min()
    root.location.z += channels.get("root.lift", 0.0) - lowest
    bpy.context.view_layer.update()


def camera_space_bounds(rig):
    points = evaluated_points(rig.all_objects)
    inverse = np.array(rig.camera.matrix_world.inverted())
    local = points @ inverse[:3, :3].T + inverse[:3, 3]
    return local[:, 0].min(), local[:, 0].max(), local[:, 1].min(), local[:, 1].max()


def fit_sprite_camera(rig):
    camera = rig.config["camera"]
    frame = rig.config["render"]["frame_size"]
    _, _, bottom, top = camera_space_bounds(rig)
    scale = (top - bottom) * frame / camera["standing_height_px"]
    data = rig.camera.data
    data.ortho_scale = scale
    data.shift_x = 0.5 - camera["center_x_px"] / frame
    data.shift_y = camera["baseline_px"] / frame - 0.5 + bottom / scale
    return {"ortho_scale": scale, "shift_x": data.shift_x, "shift_y": data.shift_y}


def fit_pose_camera(rig, scale, bounds):
    margin = rig.config["render"]["pose_margin"]
    left, right, bottom, _ = bounds
    data = rig.camera.data
    data.ortho_scale = scale
    data.shift_x = (left + right) / 2 / scale
    data.shift_y = bottom / scale + 0.5 - margin


def parse_arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--variant", default=DEFAULT_VARIANT)
    parser.add_argument("--layers", default="")
    parser.add_argument("--model-blend", default="")
    parser.add_argument("--save", required=True)
    return parser.parse_args(argv)


def main():
    arguments = parse_arguments()
    config = load_config(arguments.config)
    layers = arguments.layers.split(",") if arguments.layers else config["layers"]
    variants = resolve_variants(config, arguments.variant, layers)
    build(config, variants, arguments.model_blend or None)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arguments.save))


if __name__ == "__main__":
    main()
