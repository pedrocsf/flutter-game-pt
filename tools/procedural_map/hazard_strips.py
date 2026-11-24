from collections import Counter

import linearity
import traversal

RUN_UP_COLUMNS = 6
TOP_VARIANTS = 2
SOLID_KINDS = ("solid", "Slope")
GROUND = traversal.GROUND_LAYER
SPIKES = traversal.SPIKES_LAYER
MASK = traversal.GID_MASK
MAP_ROWS = traversal.MAP_ROWS


class TileKinds:
    def __init__(self, infos):
        self.infos = infos

    def of(self, gid):
        if gid == 0:
            return None
        info = self.infos.get(gid & MASK)
        return info.kind if info is not None else "solid"

    def is_hazard(self, gid):
        return self.of(gid) == traversal.HAZARD_CLASS

    def is_walkable_solid(self, gid):
        return self.of(gid) in SOLID_KINDS


def hazard_rows_by_column(chunk, kinds):
    ground = chunk["layers"][GROUND]
    spikes = chunk["layers"].get(SPIKES)
    result = []
    for column in range(chunk["width"]):
        rows = []
        for row in range(MAP_ROWS):
            marked = kinds.is_hazard(ground[column][row])
            marked = marked or (spikes is not None and spikes[column][row] != 0)
            if marked:
                rows.append(row)
        result.append(rows)
    return result


def column_ranges(rows_by_column):
    ranges = []
    first = None
    for column, rows in enumerate(rows_by_column):
        if rows and first is None:
            first = column
        if not rows and first is not None:
            ranges.append((first, column - 1))
            first = None
    if first is not None:
        ranges.append((first, len(rows_by_column) - 1))
    return ranges


def walkway_row(chunk, kinds, column):
    ground = chunk["layers"][GROUND][column]
    for row in range(MAP_ROWS):
        if kinds.is_walkable_solid(ground[row]):
            return row
    return None


def floor_row_before(chunk, kinds, first):
    if first == 0:
        return chunk["entryHeight"]
    return walkway_row(chunk, kinds, first - 1)


def floor_row_after(chunk, kinds, last):
    if last == chunk["width"] - 1:
        return chunk["exitHeight"]
    return walkway_row(chunk, kinds, last + 1)


def surface_candidates(chunk, kinds, first, last, hazard_top, hazard_bottom):
    options = [
        floor_row_before(chunk, kinds, first),
        floor_row_after(chunk, kinds, last),
        hazard_top,
    ]
    ordered = []
    for row in options:
        if row is None or row > hazard_bottom or row in ordered:
            continue
        ordered.append(row)
    return ordered or [hazard_top]


def flat_top_gids(chunk, kinds):
    ground = chunk["layers"][GROUND]
    width = chunk["width"]
    tops = Counter()
    fills = Counter()
    for column in range(1, width - 1):
        for row in range(1, MAP_ROWS - 1):
            gid = ground[column][row]
            if not is_flat_top(ground, kinds, column, row):
                continue
            tops[gid] += 1
            below = ground[column][row + 1]
            if kinds.of(below) == "solid":
                fills[below] += 1
    return tops, fills


def is_flat_top(ground, kinds, column, row):
    if kinds.of(ground[column][row]) != "solid" or ground[column][row - 1] != 0:
        return False
    return all(kinds.of(ground[column + step][row]) == "solid" for step in (-1, 1))


def pick_safe_tiles(chunk, kinds):
    tops, fills = flat_top_gids(chunk, kinds)
    if not tops:
        return None
    top_list = [gid for gid, _ in tops.most_common(TOP_VARIANTS)]
    fill = fills.most_common(1)[0][0] if fills else top_list[0]
    return top_list, fill


def build_strip(chunk, kinds, rows_by_column, first, last, safe_tiles, surface):
    ground = chunk["layers"][GROUND]
    spikes = chunk["layers"].get(SPIKES)
    top_list, fill = safe_tiles
    safe_ground = {}
    clear_spikes = {}
    for column in range(first, last + 1):
        rows = [r for r in rows_by_column[column] if r >= surface]
        if not rows:
            continue
        cells = {}
        for row in range(surface, max(rows) + 1):
            if ground[column][row] != 0 and not kinds.is_hazard(ground[column][row]):
                continue
            cells[str(row)] = top_list[column % len(top_list)] if row == surface else fill
        if cells:
            safe_ground[str(column)] = cells
        cleared = [r for r in rows if spikes is not None and spikes[column][r] != 0]
        if cleared:
            clear_spikes[str(column)] = cleared
    return safe_ground, clear_spikes


def apply_strips(chunk, strips):
    if not strips:
        return chunk
    layers = dict(chunk["layers"])
    ground = [list(column) for column in layers[GROUND]]
    spikes = [list(column) for column in layers[SPIKES]]
    for strip in strips:
        for column, cells in strip["safeGround"].items():
            for row, gid in cells.items():
                ground[int(column)][int(row)] = gid
        for column, rows in strip["clearSpikes"].items():
            for row in rows:
                spikes[int(column)][row] = 0
    layers[GROUND] = ground
    layers[SPIKES] = spikes
    clone = dict(chunk)
    clone["layers"] = layers
    return clone


def route_for(chunk, kinds, strip):
    first, last = strip["columns"][0], strip["columns"][-1]
    row = floor_row_before(chunk, kinds, first)
    if row is None:
        return None
    start = first - 1
    steps = 0
    while steps < RUN_UP_COLUMNS and extends_run_up(chunk, kinds, start, row):
        start -= 1
        steps += 1
    return {"start_column": start + 1, "start_row": row, "goal_column": last + 1}


def extends_run_up(chunk, kinds, column, row):
    if column < 0:
        return column > -traversal.EXTENSION_COLUMNS
    return walkway_row(chunk, kinds, column) == row


def clear_above_surface(chunk, strip):
    layers = dict(chunk["layers"])
    ground = list(layers[GROUND])
    for column in strip["columns"]:
        trimmed = list(ground[column])
        for row in range(strip["surfaceRow"]):
            trimmed[row] = 0
        ground[column] = trimmed
    layers[GROUND] = ground
    clone = dict(chunk)
    clone["layers"] = layers
    return clone


def can_cross(chunk, infos, kinds, strip):
    route = route_for(chunk, kinds, strip)
    chunk = clear_above_surface(chunk, strip)
    result = {}
    for level, speed in traversal.SPEEDS.items():
        if route is None:
            result[level] = False
            continue
        grid = traversal.TileGrid(chunk, infos, route)
        result[level] = crosses(grid, speed)
    return result


def crosses(grid, speed):
    for time_step in traversal.TIME_STEPS:
        explorer = traversal.Explorer(traversal.Simulator(grid, speed, time_step))
        if not explorer.run():
            return False
    return True


def detect_strips(chunk, infos):
    kinds = TileKinds(infos)
    rows_by_column = hazard_rows_by_column(chunk, kinds)
    safe_tiles = pick_safe_tiles(chunk, kinds)
    strips = []
    for first, last in column_ranges(rows_by_column):
        strips.append(describe_strip(chunk, kinds, rows_by_column, first, last, safe_tiles))
    return strips


def describe_strip(chunk, kinds, rows_by_column, first, last, safe_tiles):
    rows = [r for column in range(first, last + 1) for r in rows_by_column[column]]
    hazard_top, hazard_bottom = min(rows), max(rows)
    candidates = surface_candidates(chunk, kinds, first, last, hazard_top, hazard_bottom)
    strip = {
        "columns": list(range(first, last + 1)),
        "rows": [hazard_top, hazard_bottom],
        "surfaceRow": candidates[0],
        "candidates": candidates,
        "safeGround": {},
        "clearSpikes": {},
        "jumpable": {level: True for level in traversal.SPEEDS},
    }
    if safe_tiles is not None:
        fill_strip(chunk, kinds, rows_by_column, strip, safe_tiles, candidates[0])
    return strip


def fill_strip(chunk, kinds, rows_by_column, strip, safe_tiles, surface):
    first, last = strip["columns"][0], strip["columns"][-1]
    ground, spikes = build_strip(chunk, kinds, rows_by_column, first, last, safe_tiles, surface)
    strip["surfaceRow"] = surface
    strip["safeGround"] = ground
    strip["clearSpikes"] = spikes


def solved_chunk(chunk, strips, level):
    replaced = [s for s in strips if not s["jumpable"][level]]
    return apply_strips(chunk, replaced)


def mark_jumpable(chunk, infos, strips):
    kinds = TileKinds(infos)
    for strip in strips:
        others = [s for s in strips if s is not strip]
        base = apply_strips(chunk, others)
        strip["jumpable"] = can_cross(base, infos, kinds, strip)


def evaluate_levels(chunk, infos, strips):
    result = {}
    for level, speed in traversal.SPEEDS.items():
        grid = traversal.TileGrid(solved_chunk(chunk, strips, level), infos)
        result[level] = linearity.evaluate_grid(grid, speed)
    return result


def failing_levels(evaluation):
    return [level for level, (_, linear) in evaluation.items() if not linear]


def retarget(chunk, infos, strip, surface, safe_tiles):
    kinds = TileKinds(infos)
    rows_by_column = hazard_rows_by_column(chunk, kinds)
    fill_strip(chunk, kinds, rows_by_column, strip, safe_tiles, surface)


def count_linear(evaluation):
    return sum(1 for _, linear in evaluation.values() if linear)


def improve_surfaces(chunk, infos, strips, evaluation):
    kinds = TileKinds(infos)
    safe_tiles = pick_safe_tiles(chunk, kinds)
    for strip in strips:
        if safe_tiles is None or not failing_levels(evaluation):
            break
        if all(strip["jumpable"].values()):
            continue
        evaluation = best_surface(chunk, infos, strips, strip, safe_tiles, evaluation)
    return evaluation


def best_surface(chunk, infos, strips, strip, safe_tiles, evaluation):
    best_row = strip["surfaceRow"]
    best = evaluation
    for row in strip["candidates"]:
        if row == strip["surfaceRow"]:
            continue
        retarget(chunk, infos, strip, row, safe_tiles)
        trial = evaluate_levels(chunk, infos, strips)
        if count_linear(trial) > count_linear(best):
            best, best_row = trial, row
    retarget(chunk, infos, strip, best_row, safe_tiles)
    return best


def annotate_chunk(chunk, infos):
    strips = detect_strips(chunk, infos)
    mark_jumpable(chunk, infos, strips)
    evaluation = evaluate_levels(chunk, infos, strips)
    improve_surfaces(chunk, infos, strips, evaluation)
    mark_jumpable(chunk, infos, strips)
    evaluation = evaluate_levels(chunk, infos, strips)
    chunk["hazardStrips"] = [public_strip(s) for s in strips]
    chunk["traversable"] = {level: ok for level, (ok, _) in evaluation.items()}
    chunk["linear"] = {level: linear for level, (_, linear) in evaluation.items()}
    return strips


def public_strip(strip):
    return {
        "columns": strip["columns"],
        "rows": strip["rows"],
        "surfaceRow": strip["surfaceRow"],
        "safeGround": strip["safeGround"],
        "clearSpikes": strip["clearSpikes"],
        "jumpable": strip["jumpable"],
    }


def replaced_counts(strips):
    return {
        level: sum(1 for s in strips if not s["jumpable"][level])
        for level in traversal.SPEEDS
    }
