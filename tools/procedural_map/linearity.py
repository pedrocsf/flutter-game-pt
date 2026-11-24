import traversal

WIN = "win"
DEAD = "dead"
START = "start"
LANDING_GRID = 4
MIN_ROOM_CROSSINGS = 8


class WalkGraph:
    def __init__(self, simulator):
        self.simulator = simulator
        self.recorded = set()
        self.outcomes = {}
        self.neighbors = {}
        self.forced = {}
        self.entry = {}
        self.jump_targets = {}
        self.landings = set()
        self.pending = []

    def build(self):
        self.pending.append((START, self.simulator.initial_body()))
        while self.pending:
            landing_id, body = self.pending.pop()
            self.process_walk(landing_id, body)

    def process_walk(self, landing_id, body):
        crossings, status, merged = self.simulator.walk(body, self.recorded)
        keys = [key for key, _ in crossings]
        self.entry[landing_id] = self.entry_vertex(keys, status, merged)
        self.link_walk(keys, status, merged)
        for key, crossing_body in crossings:
            self.recorded.add(key)
            self.register_jump(key, crossing_body)

    def entry_vertex(self, keys, status, merged):
        if keys:
            return keys[0]
        if status == traversal.Outcome.GOAL:
            return WIN
        if status == traversal.Outcome.WALKING:
            return merged
        return DEAD

    def link_walk(self, keys, status, merged):
        for left, right in zip(keys, keys[1:]):
            self.forced.setdefault(left, set()).add(right)
            self.link_neighbors(left, right)
        if not keys:
            return
        last = keys[-1]
        if status == traversal.Outcome.GOAL:
            self.forced.setdefault(last, set()).add(WIN)
        if status == traversal.Outcome.WALKING:
            self.forced.setdefault(last, set()).add(merged)
            self.link_neighbors(last, merged)

    def link_neighbors(self, first, second):
        if abs(second[0] - first[0]) != 1:
            return
        self.neighbors.setdefault(first, set()).add(second)
        self.neighbors.setdefault(second, set()).add(first)

    def register_jump(self, key, body):
        outcome = self.simulator.jump(body)
        self.outcomes[key] = outcome
        kind, landing = outcome
        if kind == traversal.Outcome.GOAL:
            self.jump_targets[key] = WIN
        if kind == traversal.Outcome.LAND:
            landing_id = (round(landing.x / LANDING_GRID), round(landing.y))
            self.jump_targets[key] = landing_id
            self.queue_landing(landing_id, landing)

    def queue_landing(self, landing_id, body):
        if landing_id in self.landings:
            return
        self.landings.add(landing_id)
        self.pending.append((landing_id, body))

    def is_alive(self, key):
        outcome = self.outcomes.get(key)
        return outcome is not None and outcome[0] != traversal.Outcome.DEAD

    def is_safe(self, key):
        if not self.is_alive(key):
            return False
        return any(self.is_alive(other) for other in self.neighbors.get(key, ()))

    def targets(self, key, safe_only):
        found = set(self.forced.get(key, ()))
        target = self.jump_targets.get(key)
        if target is None:
            return found
        if safe_only and not self.is_safe(key):
            return found
        found.add(target if target == WIN else self.entry[target])
        return found

    def vertices(self):
        return set(self.outcomes) | set(self.forced)

    def reachable(self, safe_only=False):
        start = self.entry[START]
        seen = {start}
        stack = [start]
        while stack:
            vertex = stack.pop()
            for target in self.targets(vertex, safe_only):
                if target != DEAD and target not in seen:
                    seen.add(target)
                    stack.append(target)
        return seen

    def winning(self):
        reverse = {}
        for vertex in self.vertices():
            for target in self.targets(vertex, True):
                reverse.setdefault(target, set()).add(vertex)
        seen = {WIN}
        stack = [WIN]
        while stack:
            vertex = stack.pop()
            for source in reverse.get(vertex, ()):
                if source not in seen:
                    seen.add(source)
                    stack.append(source)
        return seen

    def room(self, vertex):
        count = 0
        seen = set()
        stack = [vertex]
        while stack and count < MIN_ROOM_CROSSINGS:
            current = stack.pop()
            if current in seen or current in (WIN, DEAD):
                continue
            seen.add(current)
            count += 1
            stack.extend(self.forced.get(current, ()))
        return count

    def is_trap(self, vertex, winning, entries):
        if vertex in winning or vertex not in entries:
            return False
        return self.room(vertex) >= MIN_ROOM_CROSSINGS

    def evaluate(self):
        winning = self.winning()
        start = self.entry[START]
        if start not in winning:
            return False, False
        entries = set(self.entry.values()) - {WIN, DEAD}
        traps = [v for v in self.reachable(True) if self.is_trap(v, winning, entries)]
        return True, not traps


def evaluate_grid(grid, speed):
    traversable = True
    linear = True
    for time_step in traversal.TIME_STEPS:
        graph = WalkGraph(traversal.Simulator(grid, speed, time_step))
        graph.build()
        passed, clean = graph.evaluate()
        traversable = traversable and passed
        linear = linear and clean
    return traversable, linear
