import math
import os
import xml.etree.ElementTree as ET

TILE = 64
MAP_ROWS = 40
PLAYER_SIZE = TILE * 0.5
GRAVITY = TILE * 32.0
MAX_VELOCITY = TILE * 20.0
JUMP_IMPULSE = GRAVITY * 0.6
JUMP_HOLD_SECONDS = 0.04
HOLD_VELOCITY_FACTOR = 0.7
GROUNDED_GRAVITY_RATE = 1.0
AIRBORNE_GRAVITY_RATE = 2.2
STUCK_SECONDS = 1.0
FALL_LIMIT = MAP_ROWS * TILE + TILE
MAX_FLIGHT_SECONDS = 8.0
MAX_WALK_SECONDS = 60.0
TAKEOFF_STEP = 8
EXTENSION_COLUMNS = 4
SPEEDS = {"easy": 4.0, "medium": 5.0, "hard": 5.75}
TIME_STEPS = (1.0 / 60.0, 1.0 / 120.0)
HAZARD_CLASS = "Hazard"
PLATFORM_CLASS = "Platform"
SLOPE_CLASS = "Slope"
SPIKES_LAYER = "water/spikes"
GROUND_LAYER = "Ground"
GID_MASK = 0x1FFFFFFF


class TileInfo:
    __slots__ = ("kind", "left_top", "right_top")

    def __init__(self, kind, left_top=0, right_top=0):
        self.kind = kind
        self.left_top = left_top
        self.right_top = right_top


SOLID_INFO = TileInfo("solid")


class GroundTile:
    __slots__ = (
        "gx", "gy", "left", "right", "top", "bottom", "platform", "hazard",
        "slope", "left_top", "right_top", "from_left", "from_right",
    )

    def __init__(self, gx, gy, info):
        self.gx = gx
        self.gy = gy
        self.left = gx * TILE
        self.right = self.left + TILE
        self.top = gy * TILE
        self.bottom = self.top + TILE
        self.platform = info.kind == PLATFORM_CLASS
        self.hazard = info.kind == HAZARD_CLASS
        self.slope = info.kind == SLOPE_CLASS
        self.left_top = info.left_top
        self.right_top = info.right_top
        self.from_left = self.slope and info.left_top < info.right_top
        self.from_right = self.slope and info.left_top > info.right_top

    def relative_top(self, other_left, other_right):
        if self.from_left:
            delta = self.right_top - self.left_top
            ratio = min(1.0, max(0.0, (other_right - self.left) / TILE))
            return (self.bottom - self.left_top) - delta * ratio
        if self.from_right:
            delta = self.left_top - self.right_top
            ratio = 1.0 - min(1.0, max(0.0, (other_left - self.left) / TILE))
            return (self.bottom - self.right_top) - delta * ratio
        return self.top


def load_tile_infos(tilesets, map_dir):
    infos = {}
    for entry in tilesets:
        root = ET.parse(os.path.join(map_dir, entry["source"])).getroot()
        for node in root.findall("tile"):
            kind = node.get("class") or node.get("type")
            if kind not in (HAZARD_CLASS, PLATFORM_CLASS, SLOPE_CLASS):
                continue
            properties = {}
            holder = node.find("properties")
            if holder is not None:
                for prop in holder.findall("property"):
                    properties[prop.get("name")] = prop.get("value")
            gid = entry["firstgid"] + int(node.get("id"))
            infos[gid] = build_info(kind, properties)
    return infos


def build_info(kind, properties):
    if kind != SLOPE_CLASS:
        return TileInfo(kind)
    if "LeftTop" not in properties or "RightTop" not in properties:
        return SOLID_INFO
    return TileInfo(kind, int(properties["LeftTop"]), int(properties["RightTop"]))


def hazard_columns(chunk, infos):
    ground = chunk["layers"][GROUND_LAYER]
    spikes = chunk["layers"].get(SPIKES_LAYER)
    flags = []
    for index in range(chunk["width"]):
        marked = any(is_hazard_gid(g, infos) for g in ground[index])
        if spikes is not None:
            marked = marked or any(g != 0 for g in spikes[index])
        flags.append(marked)
    return flags


def is_hazard_gid(gid, infos):
    if gid == 0:
        return False
    info = infos.get(gid & GID_MASK)
    return info is not None and info.kind == HAZARD_CLASS


def longest_hazard_span(chunk, infos):
    best = 0
    current = 0
    for marked in hazard_columns(chunk, infos):
        current = current + 1 if marked else 0
        best = max(best, current)
    return best


class TileGrid:
    def __init__(self, chunk, infos, route=None):
        width = chunk["width"]
        self.columns = width + 2 * EXTENSION_COLUMNS
        self.tiles = [[None] * MAP_ROWS for _ in range(self.columns)]
        self.goal_left = (EXTENSION_COLUMNS + width - 1) * TILE
        self.exit_feet = chunk["exitHeight"] * TILE
        self.start_x = EXTENSION_COLUMNS * TILE
        self.start_feet = chunk["entryHeight"] * TILE
        self.fill_extension(0, EXTENSION_COLUMNS, chunk["entryHeight"])
        self.fill_extension(
            EXTENSION_COLUMNS + width, self.columns, chunk["exitHeight"]
        )
        ground = chunk["layers"][GROUND_LAYER]
        for index in range(width):
            for row in range(MAP_ROWS):
                gid = ground[index][row]
                if gid == 0:
                    continue
                info = infos.get(gid & GID_MASK, SOLID_INFO)
                self.put(EXTENSION_COLUMNS + index, row, info)
        if route is not None:
            self.apply_route(route)

    def apply_route(self, route):
        self.start_x = (EXTENSION_COLUMNS + route["start_column"]) * TILE
        self.start_feet = route["start_row"] * TILE
        self.goal_left = (EXTENSION_COLUMNS + route["goal_column"]) * TILE
        self.exit_feet = float("-inf")

    def fill_extension(self, first, last, top_row):
        for column in range(first, last):
            for row in range(top_row, MAP_ROWS):
                self.put(column, row, SOLID_INFO)

    def put(self, column, row, info):
        self.tiles[column][row] = GroundTile(column, row, info)

    def tile_at(self, column, row):
        if 0 <= column < self.columns and 0 <= row < MAP_ROWS:
            return self.tiles[column][row]
        return None

    def tiles_near(self, x, y, width, height):
        first_column = max(0, math.floor(x / TILE) - 1)
        last_column = min(self.columns - 1, math.ceil((x + width) / TILE) + 1)
        first_row = max(0, math.floor(y / TILE) - 1)
        last_row = min(MAP_ROWS - 1, math.ceil((y + height) / TILE) + 1)
        found = []
        for column in range(first_column, last_column + 1):
            line = self.tiles[column]
            for row in range(first_row, last_row + 1):
                tile = line[row]
                if tile is not None:
                    found.append(tile)
        return found


def overlaps(x, y, width, height, tile):
    top = tile.relative_top(x, x + width)
    tile_height = tile.bottom - top
    if abs((x + width / 2) - (tile.left + TILE / 2)) * 2 >= width + TILE:
        return False
    center_y = tile.bottom - tile_height / 2
    return abs((y + height / 2) - center_y) * 2 < height + tile_height


def insertion_sort(items, compare):
    result = []
    for element in items:
        low = 0
        high = len(result)
        while low < high:
            middle = low + ((high - low) >> 1)
            if compare(element, result[middle]) < 0:
                high = middle
            else:
                low = middle + 1
        result.insert(low, element)
    return result


class Body:
    __slots__ = (
        "x", "y", "vx", "vy", "rate", "jumping", "timer", "down", "stuck",
        "previous_x",
    )

    def copy(self):
        clone = Body()
        for name in Body.__slots__:
            setattr(clone, name, getattr(self, name))
        return clone


class Outcome:
    DEAD = "dead"
    GOAL = "goal"
    LAND = "land"
    WALKING = "walking"


class Simulator:
    def __init__(self, grid, speed, time_step):
        self.grid = grid
        self.walk_speed = TILE * speed
        self.dt = time_step

    def initial_body(self):
        body = Body()
        body.x = float(self.grid.start_x)
        body.y = self.grid.start_feet - PLAYER_SIZE
        body.vx = self.walk_speed
        body.vy = 0.0
        body.rate = GROUNDED_GRAVITY_RATE
        body.jumping = False
        body.timer = -1.0
        body.down = None
        body.stuck = None
        body.previous_x = body.x
        return body

    def detect_right(self, body):
        grid = self.grid
        width = PLAYER_SIZE + body.vx * self.dt
        hits = []
        for tile in grid.tiles_near(body.x, body.y, width, PLAYER_SIZE):
            if tile.platform or not overlaps(body.x, body.y, width, PLAYER_SIZE, tile):
                continue
            if tile.left <= body.x + width and tile.right >= body.x + width:
                hits.append(tile)
        if not hits:
            return None, None
        first = min(hits, key=lambda t: t.left)
        if first.from_left:
            if body.vy >= 0:
                return first, None
            return None, first
        if first.left >= body.x + PLAYER_SIZE:
            return None, first
        return None, None

    def detect_down(self, body):
        if body.vy <= 0:
            return None
        height = PLAYER_SIZE + body.vy * self.dt
        bottom = body.y + PLAYER_SIZE
        proxy_bottom = body.y + height
        hits = []
        for tile in self.grid.tiles_near(body.x, body.y, PLAYER_SIZE, height):
            if not overlaps(body.x, body.y, PLAYER_SIZE, height, tile):
                continue
            top = tile.relative_top(body.x, body.x + PLAYER_SIZE)
            if tile.bottom >= bottom and top <= proxy_bottom:
                hits.append(tile)
        if not hits:
            return None
        return insertion_sort(hits, self.compare_down(body))[0]

    def compare_down(self, body):
        def compare(first, second):
            if first.slope and not second.slope:
                return -1
            if not first.slope and second.slope:
                return 1
            top = first.relative_top(body.x, body.x + PLAYER_SIZE)
            return (top > second.top) - (top < second.top)

        return compare

    def detect_up(self, body):
        if body.vy >= 0:
            return None
        y = body.y + body.vy * self.dt
        height = PLAYER_SIZE + abs(body.vy) * self.dt
        hits = []
        for tile in self.grid.tiles_near(body.x, y, PLAYER_SIZE, height):
            if tile.platform or not overlaps(body.x, y, PLAYER_SIZE, height, tile):
                continue
            if tile.top <= body.y and tile.bottom >= y:
                hits.append(tile)
        if not hits:
            return None
        return min(hits, key=lambda t: t.bottom)

    def slope_stick(self, body, previous_down):
        if body.vy <= 0 or previous_down is None:
            return None
        delta = 1 if previous_down.right_top == 0 and previous_down.slope else 0
        following = self.grid.tile_at(previous_down.gx + 1, previous_down.gy + delta)
        if previous_down.right >= body.x:
            return previous_down
        if following is not None and following.from_right:
            return following
        return None

    def detect(self, body, previous_down):
        down, right = self.detect_right(body)
        if down is None:
            down = self.detect_down(body)
        up = self.detect_up(body)
        if body.vy > 0 and down is None and previous_down is not None:
            down = self.slope_stick(body, previous_down)
        return up, down, right

    def apply_velocity(self, body, up, down, right):
        if up is not None:
            body.vy = 0.0
            body.y = up.bottom
        if down is not None:
            body.vy = 0.0
            top = down.relative_top(body.x, body.x + PLAYER_SIZE)
            body.y = top - PLAYER_SIZE
        if right is not None:
            self.apply_right(body, right)
        body.x += body.vx * self.dt
        body.y += body.vy * self.dt

    def apply_right(self, body, right):
        if right.from_left:
            top = right.relative_top(body.x, body.x + PLAYER_SIZE)
            body.y = min(body.y + PLAYER_SIZE, top) - PLAYER_SIZE
            return
        body.vx = 0.0
        body.x = right.left - PLAYER_SIZE

    def apply_jumper(self, body, down):
        if body.jumping:
            if down is not None:
                body.vy = -JUMP_IMPULSE
                body.rate = GROUNDED_GRAVITY_RATE
            else:
                body.vy = min(-JUMP_IMPULSE * HOLD_VELOCITY_FACTOR, body.vy)
        elif down is None:
            body.rate = AIRBORNE_GRAVITY_RATE
        else:
            body.rate = GROUNDED_GRAVITY_RATE
        body.vx = self.walk_speed

    def apply_timer(self, body):
        if body.timer < 0:
            return
        body.timer -= self.dt
        if body.timer <= 0:
            body.jumping = False

    def check_player(self, body, down):
        if down is not None and down.hazard:
            return True
        if body.y > FALL_LIMIT:
            return True
        if body.x == body.previous_x:
            body.stuck = (STUCK_SECONDS if body.stuck is None else body.stuck) - self.dt
            if body.stuck <= 0:
                return True
        else:
            body.stuck = None
        body.previous_x = body.x
        return False

    def step(self, body):
        body.vy = min(body.vy + GRAVITY * body.rate * self.dt, MAX_VELOCITY)
        previous_down = body.down
        up, down, right = self.detect(body, previous_down)
        body.down = down
        self.apply_velocity(body, up, down, right)
        self.apply_jumper(body, down)
        self.apply_timer(body)
        return self.check_player(body, down)

    def reached_goal(self, body):
        if body.down is None:
            return False
        if body.x < self.grid.goal_left:
            return False
        return body.y + PLAYER_SIZE >= self.grid.exit_feet - 1e-6

    def jump(self, start):
        body = start.copy()
        body.jumping = True
        body.timer = JUMP_HOLD_SECONDS
        airborne = False
        for _ in range(int(MAX_FLIGHT_SECONDS / self.dt)):
            if self.step(body):
                return Outcome.DEAD, None
            if self.reached_goal(body) and airborne:
                return Outcome.GOAL, None
            if body.down is None:
                airborne = True
            elif airborne:
                return Outcome.LAND, body
        return Outcome.DEAD, None

    def walk(self, start, recorded):
        body = start.copy()
        crossings = []
        last_index = None
        for _ in range(int(MAX_WALK_SECONDS / self.dt)):
            if self.step(body):
                return crossings, Outcome.DEAD, None
            if self.reached_goal(body):
                return crossings, Outcome.GOAL, None
            if body.down is None:
                continue
            index = int(body.x // TAKEOFF_STEP)
            if index == last_index:
                continue
            last_index = index
            key = (index, round(body.y))
            if key in recorded:
                return crossings, Outcome.WALKING, key
            crossings.append((key, body.copy()))
        return crossings, Outcome.DEAD, None


class Explorer:
    def __init__(self, simulator):
        self.simulator = simulator
        self.recorded = set()
        self.outcomes = {}
        self.neighbors = {}
        self.processed = set()
        self.landings = set()
        self.pending = []

    def link(self, first, second):
        self.neighbors.setdefault(first, set()).add(second)
        self.neighbors.setdefault(second, set()).add(first)

    def register_walk(self, crossings, merged_key):
        keys = [key for key, _ in crossings]
        for left, right in zip(keys, keys[1:]):
            if right[0] - left[0] == 1:
                self.link(left, right)
        if merged_key is not None and keys and merged_key[0] - keys[-1][0] == 1:
            self.link(keys[-1], merged_key)
        for key, body in crossings:
            self.recorded.add(key)
            self.outcomes[key] = self.simulator.jump(body)

    def is_alive(self, key):
        outcome = self.outcomes.get(key)
        return outcome is not None and outcome[0] != Outcome.DEAD

    def is_safe_takeoff(self, key):
        if not self.is_alive(key):
            return False
        return any(self.is_alive(other) for other in self.neighbors.get(key, ()))

    def queue_landing(self, body):
        key = (round(body.x / 4), round(body.y))
        if key in self.landings:
            return
        self.landings.add(key)
        self.pending.append(body)

    def collect_takeoffs(self):
        found_goal = False
        for key in list(self.outcomes):
            if key in self.processed or not self.is_safe_takeoff(key):
                continue
            self.processed.add(key)
            kind, body = self.outcomes[key]
            if kind == Outcome.GOAL:
                found_goal = True
            else:
                self.queue_landing(body)
        return found_goal

    def run(self):
        self.pending.append(self.simulator.initial_body())
        while True:
            while self.pending:
                crossings, status, merged = self.simulator.walk(
                    self.pending.pop(), self.recorded
                )
                if status == Outcome.GOAL:
                    return True
                self.register_walk(crossings, merged)
            if self.collect_takeoffs():
                return True
            if not self.pending:
                return False


def is_traversable(chunk, infos, speed):
    grid = TileGrid(chunk, infos)
    for time_step in TIME_STEPS:
        explorer = Explorer(Simulator(grid, speed, time_step))
        if not explorer.run():
            return False
    return True


def traversable_by_level(chunk, infos):
    return {
        level: is_traversable(chunk, infos, speed)
        for level, speed in SPEEDS.items()
    }
