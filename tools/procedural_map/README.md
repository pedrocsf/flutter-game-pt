# Procedural map chunks

Slices `assets/map/flutter_runnergame_map_{A,B,C}.tmx` into reusable chunks and writes `assets/map/procedural/chunks.json`.

```
python3 tools/procedural_map/extract_chunks.py
```

Python 3 stdlib only. Run again whenever the .tmx maps change. Prints a summary of chunks by biome, kind and difficulty, plus a table (id, kind, note, width, hazard strips, widest strip, strips turned into ground per level, traversable and linear per level) and how many chunks each level can use.

## Traversal (`traversal.py`)

Every chunk gets `"traversable": {"easy": bool, "medium": bool, "hard": bool}`. The generator only places chunks that are traversable on the current level.

`traversal.py` replays the physics of the game (leap `CollisionDetectionBehavior`, `VelocityBehavior`, `JumperBehavior` and `PlayerControllerBehavior`) frame by frame on the chunk tiles:

- gravity 2048 px/s², max velocity 1280 px/s, jump impulse 1228.8 px/s, gravity rate 1.0 while the jump is held (0.04 s) and 2.2 afterwards, player 32x32 px, constant horizontal speed 64 * playerSpeed (easy 4, medium 5, hard 5.75), no double jump.
- Tile classes come from the `.tsx` files: `Platform` collides only from above, `Slope` uses `LeftTop`/`RightTop`, `Hazard` kills when landed on, unclassified tiles are solid. Only the `Ground` layer collides; `water/spikes` is visual.
- Death by landing on a hazard, falling below the map, or staying still against a wall for 1 s.

The search starts running on the entry ground (column 0, top at `entryHeight`) and explores jumps from every 8 px of ground, following each landing, until the player stands on the last column at `exitHeight` or beyond (flat virtual ground is added before and after the chunk). Flight paths are conservative:

- a takeoff only counts if the takeoff 8 px earlier or later also survives (timing margin);
- the whole search must succeed with time steps of 1/60 s and 1/120 s.

Sanity values from the simulator: jump reach is about 2.4 / 3.0 / 3.45 tiles and rise about 2.96 tiles; flat gaps of 2 / 3 / 3 tiles pass on easy / medium / hard and wider ones fail; walls up to 2 tiles pass.

## Hazard strips and linear chunks (`hazard_strips.py`, `linearity.py`)

The game is meant to be linear: the lower path must always let the player progress, and the upper routes (where the items are) are the incentive. Hazard strips too wide to jump become safe ground on the levels where they cannot be jumped; short strips stay as obstacles. Items are never moved.

Every chunk gets:

```
"hazardStrips": [{
  "columns": [22, 23, 24, 25],
  "rows": [33, 34],
  "surfaceRow": 32,
  "safeGround": {"23": {"32": 1517, "33": 1535, "34": 1535}},
  "clearSpikes": {"23": [33]},
  "jumpable": {"easy": true, "medium": true, "hard": true}
}],
"linear": {"easy": true, "medium": true, "hard": true},
"traversable": {...}
```

- A strip is a run of contiguous columns that have at least one hazard cell: a nonzero tile in `water/spikes` or a `Ground` tile whose class is `Hazard` (this is how leap tags `hazard`: only the class of the `Ground` tile). `rows` is the first and last hazard row of the strip.
- `jumpable[level]`: starting on the flat ground right before the strip (up to 6 columns of run-up) at the speed of the level, the simulator must be able to land on safe ground past the strip. Ground above `surfaceRow` inside the strip columns is removed for this test, so stepping stones in the upper routes do not count. A strip that can simply be walked over (hazard only in an upper route) is jumpable.
- `surfaceRow`: row where the safe ground starts. It is the floor row before the strip; if that is below the hazard, the floor after it, then the first hazard row. The safe ground is leveled with the floor, not with the first hazard row, to avoid ditches and walls.
- `safeGround`: `column -> row -> gid` for the `Ground` layer. The top row uses one of the two most common flat floor-top tiles of the chunk (solid, empty above, solid on both sides), the rows below use the most common tile under such tops. Cells that already hold non-hazard ground are kept. The spec asked for class `Platform` tops, but most chunks have none and a Platform tile is a one-way platform of different art, so the chunk own floor tiles are used.
- `clearSpikes`: `column -> rows` set to 0 in `water/spikes`.
- The generator (`MapChunk.layersForLevel`) applies `safeGround` and `clearSpikes` only for strips with `jumpable[level] == false`, before the vertical shift and the fill below.

`linearity.py` builds a graph of the walking states of a chunk (the same crossings every 8 px and jumps of `traversal.py`) with the substitutions of the level applied:

- `traversable[level]`: the exit is reachable (it now includes the substitutions).
- `linear[level]`: traversable and, from every landing state reachable through safe takeoffs, there is a path to the exit. Deaths caused by timing in a jump do not count: landings with less than one tile of ground ahead (hair-edge landings) and landings that die before any step are ignored. Standing against a wall for 1 s or running into a dead-end pocket counts as a trap.
- If a chunk is not linear, other `surfaceRow` candidates of the non-jumpable strips are tried and the best is kept.

The generator only places chunks that are traversable and linear on the level (the end chunk keeps a last-resort fallback). C_01 is the only chunk that is not linear on any level: it is a diagonal climbing cave with dead-end alcoves and lower tiers closed by hazard tiles that are not hazard strips problems, so floor substitution does not fix it.

## Checking generated sections (`check_sections.py`)

Replays the physics on whole generated sections (not chunks) and lists the ones that are not traversable or that have a dead end reachable through safe jumps. Generate `.tmx` files named `<level>_<seed>_<section>.tmx` with `ProceduralMapGenerator.generateSection` (for example from a temporary Dart test, 3 sections per match) and run from the project root:

```
python3 tools/procedural_map/check_sections.py "/tmp/sections/*.tmx"
python3 tools/procedural_map/check_sections.py --traps "/tmp/sections/hard_*.tmx"
```

The exit code is 1 when any section fails. `--help` lists the options (`--section-count`, `--map-directory`, `--workers`, `--traps`).
