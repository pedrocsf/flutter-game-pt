import json
import os
import sys
import xml.etree.ElementTree as ET

import hazard_strips
import traversal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAP_DIR = os.path.join(ROOT, "assets", "map")
OUTPUT = os.path.join(MAP_DIR, "procedural", "chunks.json")
BIOMES = ["A", "B", "C"]
TILE = 64
HEIGHT = 40
FLAGS = 0xE0000000
GID_MASK = 0x1FFFFFFF
MIN_WIDTH = 12
MAX_WIDTH = 40
MIN_START = 20
MIN_END = 20
MIN_RUNOUT = 16
GAME_LAYERS = {"decorations_terrain", "Ground", "decorations", "water/spikes", "treehouse_back", "treehouse_front"}
ENEMY_TYPES = {
    "Beetle": "Cramp",
    "Ant": "Soreness",
    "Grasshopper": "IcePack",
    "Bee": "FatigueHourglass",
    "Butterfly": "LazyCloud",
    "Firefly": "Bandage",
}
ENEMY_TILESET = "objects/tile_enemies_v2.tsx"


class Unifier:
    def __init__(self):
        self.tilesets = []
        self.by_source = {}
        self.next_gid = 1

    def register(self, source):
        if source in self.by_source:
            return self.by_source[source]
        tsx = ET.parse(os.path.join(MAP_DIR, source)).getroot()
        count = int(tsx.get("tilecount"))
        entry = {"source": source, "firstgid": self.next_gid, "tilecount": count}
        self.tilesets.append(entry)
        self.by_source[source] = entry
        self.next_gid += count
        return entry


def is_skipped(source):
    return os.path.basename(source).startswith("spritesheet_enemy_") and source.startswith("anim/")


class GameMap:
    def __init__(self, biome, unifier):
        self.biome = biome
        self.unifier = unifier
        self.root = ET.parse(os.path.join(MAP_DIR, "flutter_runnergame_map_%s.tmx" % biome)).getroot()
        self.width = int(self.root.get("width"))
        self.local = []
        for node in self.root.findall("tileset"):
            source = node.get("source")
            first = int(node.get("firstgid"))
            if is_skipped(source):
                self.local.append((first, source, None))
            else:
                self.local.append((first, source, unifier.register(source)))
        self.local.sort()

    def remap(self, raw):
        if raw == 0:
            return 0
        flags = raw & FLAGS
        base = raw & GID_MASK
        chosen = None
        for first, source, entry in self.local:
            if first <= base:
                chosen = (first, source, entry)
        if chosen is None or chosen[2] is None:
            raise ValueError("gid %d in map %s points to skipped tileset" % (base, self.biome))
        first, source, entry = chosen
        offset = base - first
        if offset >= entry["tilecount"]:
            raise ValueError("gid %d out of tileset %s" % (base, source))
        return (entry["firstgid"] + offset) | flags

    def parse_layer(self, node):
        text = node.find("data").text
        values = [int(v) for v in text.replace("\n", "").split(",") if v.strip() != ""]
        w = int(node.get("width"))
        columns = []
        for x in range(w):
            columns.append([self.remap(values[y * w + x]) for y in range(HEIGHT)])
        return columns

    def layer_info(self, node):
        return {
            "name": node.get("name"),
            "offsetx": float(node.get("offsetx", 0)),
            "offsety": float(node.get("offsety", 0)),
            "parallaxx": float(node.get("parallaxx", 1)),
            "parallaxy": float(node.get("parallaxy", 1)),
            "opacity": float(node.get("opacity", 1)),
            "columns": self.parse_layer(node),
        }

    def collect_layers(self):
        game = {}
        background = {"width": self.width, "groups": [], "layers": []}
        for child in self.root:
            if child.tag == "group":
                group = {
                    "name": child.get("name"),
                    "offsetx": float(child.get("offsetx", 0)),
                    "offsety": float(child.get("offsety", 0)),
                    "layers": [self.layer_info(n) for n in child.findall("layer")],
                }
                background["groups"].append(group)
            elif child.tag == "layer":
                has_parallax = child.get("parallaxx") is not None or child.get("parallaxy") is not None
                name = child.get("name")
                if name in GAME_LAYERS or not has_parallax:
                    game[name] = self.parse_layer(child)
                else:
                    background["layers"].append(self.layer_info(child))
        return game, background

    def collect_objects(self):
        result = {"items": [], "enemies": [], "respawn": [], "spawn": []}
        for group in self.root.findall("objectgroup"):
            name = group.get("name")
            if name not in result:
                continue
            for node in group.findall("object"):
                result[name].append(self.parse_object(node, name))
        return result

    def parse_object(self, node, group):
        properties = {}
        props = node.find("properties")
        if props is not None:
            for p in props.findall("property"):
                kind = p.get("type", "string")
                value = p.get("value")
                if kind == "bool":
                    value = value == "true"
                elif kind == "int":
                    value = int(value)
                elif kind == "float":
                    value = float(value)
                properties[p.get("name")] = value
        if group == "enemies" and "Type" in properties:
            properties["Type"] = ENEMY_TYPES.get(properties["Type"], properties["Type"])
        raw = int(node.get("gid", 0))
        if group == "enemies":
            gid = -1
        else:
            gid = self.remap(raw)
        return {
            "x": float(node.get("x")),
            "y": float(node.get("y")),
            "width": float(node.get("width", 0)),
            "height": float(node.get("height", 0)),
            "gid": gid,
            "type": node.get("type", node.get("class", "")),
            "properties": properties,
        }


def ground_top(ground, column):
    for row, gid in enumerate(ground[column]):
        if gid != 0:
            return row
    return -1


def has_hazard(hazard, column):
    return any(g != 0 for g in hazard[column])


def find_cuts(width, ground, hazard, objects, margin):
    blockers = [o["x"] for key in ("items", "enemies", "respawn") for o in objects[key]]
    cuts = []
    for c in range(1, width - 1):
        tops = {ground_top(ground, c - 1), ground_top(ground, c), ground_top(ground, c + 1)}
        if len(tops) != 1 or next(iter(tops)) < 0:
            continue
        if any(has_hazard(hazard, k) for k in range(c - margin, c + margin + 1)):
            continue
        low, high = (c - margin) * TILE, (c + margin + 1) * TILE
        if any(low <= x < high for x in blockers):
            continue
        cuts.append(c)
    return cuts


def choose_boundaries(width, cuts, first_min, last_min):
    boundaries = [0]
    start = 0
    minimum = first_min
    cut_set = cuts
    while True:
        candidates = [c for c in cut_set if c - start >= minimum and width - c >= MIN_WIDTH]
        if not candidates:
            break
        within = [c for c in candidates if c - start <= MAX_WIDTH]
        pick = candidates[0]
        boundaries.append(pick)
        start = pick
        minimum = MIN_WIDTH
    while len(boundaries) > 1 and width - boundaries[-1] < last_min:
        boundaries.pop()
    boundaries.append(width)
    return boundaries


def slice_columns(layer, start, end):
    return [list(col) for col in layer[start:end]]


def count_enemies(objs):
    return len(objs["enemies"])


def raw_score(layers, objs, start, end):
    ground = layers["Ground"]
    hazard = layers.get("water/spikes")
    width = end - start
    total = 0
    for c in range(start, end):
        if hazard is not None and has_hazard(hazard, c):
            total += 1
        if ground_top(ground, c) < 0:
            total += 1
    total += 3 * count_enemies(objs)
    return total * 10.0 / width


def annotate_traversal(chunks, tilesets):
    infos = traversal.load_tile_infos(tilesets, MAP_DIR)
    summaries = {}
    for c in chunks:
        strips = hazard_strips.annotate_chunk(c, infos)
        summaries[c["id"]] = {
            "strips": len(strips),
            "longest": max([len(s["columns"]) for s in strips], default=0),
            "replaced": hazard_strips.replaced_counts(strips),
        }
    return summaries


def flags(values):
    return "/".join("yes" if values[k] else "no" for k in traversal.SPEEDS)


def print_traversal_summary(chunks, summaries):
    header = "%-6s %-7s %4s %6s %6s %6s  %-9s %-9s %-9s"
    print(header % ("id", "kind", "note", "width", "strips", "widest", "replaced", "traversab", "linear"))
    for c in chunks:
        info = summaries[c["id"]]
        replaced = "/".join(str(info["replaced"][k]) for k in traversal.SPEEDS)
        print(
            header
            % (
                c["id"], c["kind"], c["difficulty"], c["width"], info["strips"],
                info["longest"], replaced, flags(c["traversable"]), flags(c["linear"]),
            )
        )
    for level in traversal.SPEEDS:
        usable = [c for c in chunks if c["linear"][level]]
        normal = sum(1 for c in usable if c["kind"] == "normal")
        print("%s: %d/%d linear (%d normal)" % (level, len(usable), len(chunks), normal))


def main():
    unifier = Unifier()
    maps = {b: GameMap(b, unifier) for b in BIOMES}
    enemy_entry = unifier.register(ENEMY_TILESET)
    enemy_gid = enemy_entry["firstgid"]

    backgrounds = {}
    chunks = []
    flat_runs = []

    for biome in BIOMES:
        gm = maps[biome]
        game, background = gm.collect_layers()
        backgrounds[biome] = background
        objects = gm.collect_objects()
        for o in objects["enemies"]:
            o["gid"] = enemy_gid
        for key in ("items", "enemies", "respawn", "spawn"):
            for o in objects[key]:
                if o["gid"] == -1:
                    o["gid"] = 0
        ground = game["Ground"]
        hazard = game.get("water/spikes", [[0] * HEIGHT for _ in range(gm.width)])
        game.setdefault("water/spikes", hazard)
        width = gm.width
        cuts = find_cuts(width, ground, hazard, objects, 1)
        first_min = MIN_START if biome == "A" else MIN_WIDTH
        last_min = MIN_END if biome == "C" else MIN_WIDTH
        bounds = choose_boundaries(width, cuts, first_min, last_min)
        if max(b2 - b1 for b1, b2 in zip(bounds, bounds[1:])) > MAX_WIDTH:
            relaxed = sorted(set(cuts) | set(find_cuts(width, ground, hazard, objects, 0)))
            bounds = choose_boundaries(width, relaxed, first_min, last_min)

        run_start = None
        for c in range(width + 1):
            flat = c < width and ground_top(ground, c) >= 0 and not has_hazard(hazard, c) and (
                run_start is None or ground_top(ground, c) == ground_top(ground, run_start)
            )
            if flat and run_start is None:
                run_start = c
            elif not flat and run_start is not None:
                if c - run_start >= MIN_RUNOUT:
                    flat_runs.append((biome, run_start, c))
                run_start = c if c < width and ground_top(ground, c) >= 0 and not has_hazard(hazard, c) else None

        for index in range(len(bounds) - 1):
            s, e = bounds[index], bounds[index + 1]
            lo, hi = s * TILE, e * TILE
            objs = {}
            for key in ("items", "enemies", "respawn", "spawn"):
                objs[key] = []
                for o in objects[key]:
                    if lo <= o["x"] < hi:
                        copy = dict(o)
                        copy["x"] = o["x"] - lo
                        objs[key].append(copy)
            if biome == "A" and index == 0:
                kind = "start"
            elif biome == "C" and index == len(bounds) - 2:
                kind = "end"
            else:
                kind = "normal"
                tops = {ground_top(ground, c) for c in range(s, e)}
                clean = not any(has_hazard(hazard, c) for c in range(s, e))
                if len(tops) == 1 and -1 not in tops and clean and not objs["enemies"] and e - s >= MIN_RUNOUT:
                    kind = "runout"
            if kind != "start":
                objs["spawn"] = []
            layers = {name: slice_columns(col, s, e) for name, col in game.items()}
            chunks.append({
                "id": "%s_%02d" % (biome, index),
                "biome": biome,
                "kind": kind,
                "width": e - s,
                "entryHeight": ground_top(ground, s),
                "exitHeight": ground_top(ground, e - 1),
                "difficulty": 0,
                "layers": layers,
                "objects": objs,
                "_score": raw_score(game, objs, s, e),
            })

    if not any(c["kind"] == "runout" for c in chunks) and flat_runs:
        biome, s, e = max(flat_runs, key=lambda r: r[2] - r[1])
        gm = maps[biome]
        game, _ = gm.collect_layers()
        game.setdefault("water/spikes", [[0] * HEIGHT for _ in range(gm.width)])
        end = min(e, s + MIN_RUNOUT)
        top = ground_top(game["Ground"], s)
        chunks.append({
            "id": "%s_run" % biome,
            "biome": biome,
            "kind": "runout",
            "width": end - s,
            "entryHeight": top,
            "exitHeight": top,
            "difficulty": 0,
            "layers": {name: slice_columns(col, s, end) for name, col in game.items()},
            "objects": {"items": [], "enemies": [], "respawn": [], "spawn": []},
            "_score": 0.0,
        })

    scored = sorted(c["_score"] for c in chunks if c["kind"] == "normal")
    if scored:
        n = len(scored)
        thresholds = [scored[max(0, min(n - 1, (n * q) // 4))] for q in (1, 2, 3)]
        for c in chunks:
            s = c["_score"]
            grade = 0
            for t in thresholds:
                if s > t:
                    grade += 1
            c["difficulty"] = grade
    for c in chunks:
        if c["kind"] == "runout":
            c["difficulty"] = 0
        del c["_score"]
    summaries = annotate_traversal(chunks, unifier.tilesets)

    for c in chunks:
        for name, cols in c["layers"].items():
            assert len(cols) == c["width"]
            assert all(len(col) == HEIGHT for col in cols)

    max_gid = unifier.next_gid - 1

    def check(col):
        for g in col:
            if g & GID_MASK > max_gid:
                raise ValueError("gid out of table")

    for c in chunks:
        for cols in c["layers"].values():
            for col in cols:
                check(col)
    for b in backgrounds.values():
        layers = list(b["layers"]) + [l for g in b["groups"] for l in g["layers"]]
        for l in layers:
            for col in l["columns"]:
                assert len(col) == HEIGHT
                check(col)

    output = {
        "tileWidth": TILE,
        "tileHeight": TILE,
        "mapHeight": HEIGHT,
        "tilesets": unifier.tilesets,
        "enemyGid": enemy_gid,
        "backgrounds": backgrounds,
        "chunks": chunks,
    }
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(output, f, separators=(",", ":"))

    print_traversal_summary(chunks, summaries)
    summary = {}
    for c in chunks:
        key = (c["biome"], c["kind"], c["difficulty"])
        summary[key] = summary.get(key, 0) + 1
    print("chunks: %d, tilesets: %d, enemyGid: %d" % (len(chunks), len(unifier.tilesets), enemy_gid))
    for key in sorted(summary):
        print("biome=%s kind=%s difficulty=%d: %d" % (key + (summary[key],)))
    kinds = {}
    for c in chunks:
        kinds[c["kind"]] = kinds.get(c["kind"], 0) + 1
    print("by kind:", kinds)
    print("by difficulty:", {d: sum(1 for c in chunks if c["difficulty"] == d) for d in range(4)})


if __name__ == "__main__":
    sys.exit(main())
