import argparse
import glob
import os
import re
import sys
import time
from multiprocessing import Pool

import linearity
import traversal

PLAYER_SPEEDS = {"easy": 4.0, "medium": 5.0, "hard": 5.75}
DEFAULT_MAP_DIRECTORY = os.path.join("assets", "map")
DEFAULT_SECTION_COUNT = 3
GOAL_MARGIN_LAST_SECTION = 2
GOAL_MARGIN_OTHER_SECTION = 16
MAX_REPORTED_TRAPS = 4

TILESET_PATTERN = re.compile(r'<tileset firstgid="(\d+)" source="([^"]+)"')
GROUND_PATTERN = re.compile(
    r'name="Ground"[^>]*>\s*<data encoding="csv">\s*([\s\S]*?)</data>'
)
SPAWN_PATTERN = re.compile(
    r'<objectgroup[^>]*name="spawn"[^>]*>\s*<object[^>]*?x="([\d.]+)" y="([\d.]+)"'
)

DESCRIPTION = """
Checks generated map sections with the real physics of the game
(traversal.py and linearity.py): every section must be traversable from the
spawn to the end and must have no dead end (trap) reachable through safe jumps.

How to use:
  1. Generate the sections as .tmx files named <level>_<seed>_<section>.tmx
     (level = easy, medium or hard) with ProceduralMapGenerator.generateSection
     from a temporary Dart test, for example into /tmp/sections.
  2. Run from the project root:
       python3 tools/procedural_map/check_sections.py "/tmp/sections/*.tmx"
  3. Sections that fail are listed as (name, traversable, linear). Use --traps
     to print the column and row (in tiles) of the dead ends of each failure.

The exit code is 0 when every section passes and 1 otherwise.
"""


def parse_name(path):
    name = os.path.basename(path)[: -len(".tmx")]
    level, _, section = name.split("_")
    return name, level, int(section)


def read_ground_columns(xml):
    block = GROUND_PATTERN.search(xml).group(1).strip().split("\n")
    rows = [
        [int(value) & traversal.GID_MASK for value in line.split(",") if value.strip()]
        for line in block
    ]
    return [[row[column] for row in rows] for column in range(len(rows[0]))]


def first_row_of(column):
    for row, gid in enumerate(column):
        if gid:
            return row
    return 0


def start_position(xml, columns):
    spawn = SPAWN_PATTERN.search(xml)
    if spawn is None:
        return 1, first_row_of(columns[1])
    start_column = int(float(spawn.group(1)) // traversal.TILE)
    start_row = int(float(spawn.group(2)) // traversal.TILE)
    while not columns[start_column][start_row]:
        start_row += 1
    return start_column, start_row


def build_grid(path, section_count, map_directory):
    name, level, section = parse_name(path)
    with open(path) as handle:
        xml = handle.read()
    tilesets = [
        {"source": source, "firstgid": int(first_gid)}
        for first_gid, source in TILESET_PATTERN.findall(xml)
        if not source.startswith("anim")
    ]
    infos = traversal.load_tile_infos(tilesets, map_directory)
    columns = read_ground_columns(xml)
    width = len(columns)
    start_column, start_row = start_position(xml, columns)
    is_last = section == section_count - 1
    margin = GOAL_MARGIN_LAST_SECTION if is_last else GOAL_MARGIN_OTHER_SECTION
    chunk = {
        "width": width,
        "entryHeight": first_row_of(columns[0]),
        "exitHeight": first_row_of(columns[-1]),
        "layers": {"Ground": columns},
    }
    route = {
        "start_column": start_column,
        "start_row": start_row,
        "goal_column": width - margin,
    }
    grid = traversal.TileGrid(chunk, infos, route)
    return name, level, grid


def check_section(job):
    path, section_count, map_directory = job
    name, level, grid = build_grid(path, section_count, map_directory)
    traversable, linear = linearity.evaluate_grid(grid, PLAYER_SPEEDS[level])
    return name, traversable, linear


def locate_traps(job):
    path, section_count, map_directory = job
    name, level, grid = build_grid(path, section_count, map_directory)
    walk = linearity.WalkGraph(
        traversal.Simulator(grid, PLAYER_SPEEDS[level], traversal.TIME_STEPS[0])
    )
    walk.build()
    winning = walk.winning()
    entries = set(walk.entry.values()) - {linearity.WIN, linearity.DEAD}
    traps = [
        vertex
        for vertex in walk.reachable(True)
        if walk.is_trap(vertex, winning, entries)
    ]
    positions = sorted(
        {
            (
                round(vertex[0] * traversal.TAKEOFF_STEP / traversal.TILE
                      - traversal.EXTENSION_COLUMNS, 1),
                round((vertex[1] + traversal.PLAYER_SIZE) / traversal.TILE, 1),
            )
            for vertex in traps
        }
    )
    return name, positions


def expand(patterns):
    paths = []
    for pattern in patterns:
        paths.extend(glob.glob(pattern))
    return sorted(set(paths))


def report_traps(failures, jobs_by_name, workers):
    with Pool(workers) as pool:
        located = pool.map(locate_traps, [jobs_by_name[name] for name, _, _ in failures])
    for name, positions in located:
        shown = positions[:MAX_REPORTED_TRAPS]
        print(f"  {name}: {len(positions)} trap positions (column, row) e.g. {shown}")


def main():
    parser = argparse.ArgumentParser(
        description=DESCRIPTION,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("patterns", nargs="+", help='glob of .tmx files, quoted, e.g. "/tmp/sections/*.tmx"')
    parser.add_argument("--section-count", type=int, default=DEFAULT_SECTION_COUNT, help="sections per match used to find the last section (default 3)")
    parser.add_argument("--map-directory", default=DEFAULT_MAP_DIRECTORY, help="folder that holds the tileset .tsx files (default assets/map)")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1), help="parallel processes")
    parser.add_argument("--traps", action="store_true", help="print where the dead ends of the failing sections are")
    arguments = parser.parse_args()

    paths = expand(arguments.patterns)
    if not paths:
        print("no .tmx files found", file=sys.stderr)
        return 2
    jobs = [(path, arguments.section_count, arguments.map_directory) for path in paths]
    started = time.time()
    with Pool(arguments.workers) as pool:
        results = pool.map(check_section, jobs, chunksize=2)
    failures = [result for result in results if not (result[1] and result[2])]
    elapsed = round(time.time() - started)
    print(f"{len(results)} sections, {len(failures)} bad, {elapsed}s")
    for failure in failures:
        print(failure)
    if failures and arguments.traps:
        jobs_by_name = {parse_name(job[0])[0]: job for job in jobs}
        report_traps(failures, jobs_by_name, arguments.workers)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
