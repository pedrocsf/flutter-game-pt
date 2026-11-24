# Tunnel art

Regenerate: `python3 tools/tunnel/draw_tunnel.py` (Pillow + numpy). Set `TUNNEL_PREVIEW=/path/preview.png` to also write a preview.

Outputs: `assets/map/tiles/tile_tunnel.png` (+ `.tsx`, 8x2 tiles of 64 px) and `assets/map/anim/spritesheet_obstacle_low_bar.png` (4 frames 64x64).

Tile ids:

| id | content |
|----|---------|
| 0 | ceiling start (entry arch) |
| 1 | ceiling middle |
| 2 | ceiling end (exit arch) |
| 3 | ceiling middle with lit lamp |
| 4 | floor top (orange line) |
| 5 | floor fill |
| 6, 7 | transparent |
| 8 | back wall top |
| 9 | back wall middle |
| 10 | back wall middle with orange LED strip |
| 11 | back wall base (baseboard) |
| 12 | entry arch frame (left pillar) |
| 13 | exit arch frame (right pillar) |
| 14, 15 | transparent |
