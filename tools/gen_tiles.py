# Slice territory tiles out of assets/texture.png.
# Grid: 8 cols x 4 rows, ~111px.
#   row 0 = kingdom-coloured ground tiles
#   row 1 = sandy soil / cracked dirt tiles (8 variants)
#   row 2 = 7 green grass shade variants
# Run:  python tools/gen_tiles.py
from PIL import Image

im = Image.open("assets/texture.png").convert("RGBA")
COLS = [(21, 133), (140, 252), (258, 369), (375, 487), (493, 601), (607, 712), (718, 825), (831, 936)]
ROWS = [(51, 168), (174, 287), (292, 403), (409, 520)]
SIZE = 128


def tile(c, r):
	x0, x1 = COLS[c]
	y0, y1 = ROWS[r]
	return im.crop((x0, y0, x1, y1)).resize((SIZE, SIZE), Image.LANCZOS)


# 7 grass shade variants (row 2, cols 0-6)
for c in range(7):
	tile(c, 2).save("assets/tile_grass_%d.png" % c)

# 8 kingdom-coloured ground tiles (row 0) — used for captured territory
for c in range(8):
	tile(c, 0).save("assets/tile_color_%d.png" % c)

# 8 soil/dirt variants (row 1 — sandy cracked ground from atlas)
for c in range(8):
	tile(c, 1).save("assets/tile_soil_%d.png" % c)

# tile_dirt.png = first soil variant (used by territory_ground.tres as default)
tile(0, 1).save("assets/tile_dirt.png")

# foam relief from a coloured tile's luminance, rebrightened for tinting
foam = tile(0, 0).convert("L").point(lambda p: max(165, min(255, int(216 + (p - 128) * 0.5))))
foam.convert("RGBA").save("assets/tile_foam.png")

print("TILES_DONE", SIZE)
