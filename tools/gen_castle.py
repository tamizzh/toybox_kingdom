# Headless Blender generator for a low-poly toy castle -> assets/models/castle.glb
# TWO named objects so castle.gd can find + tint the "roof" per kingdom colour:
#   "stone" (cream keep / towers / walls / battlements)
#   "roof"  (conical tower caps + keep pyramid + pennants)
# Proportions matched to simple_target.png: wide footprint, tall corner towers,
# prominent battlements on towers/keep/walls, steep conical roofs.
# Run:  blender --background --python tools/gen_castle.py
import bpy, sys, os, math

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()
stone_mat = T.mat("stone", (0.50, 0.51, 0.56), rough=0.80)
roof_mat  = T.mat("roof",  (0.72, 0.22, 0.18), rough=0.50)

# ---------- geometry constants ----------
CORNER_D  = 1.42   # corner tower centres at ±1.42
TOWER_R   = 0.46   # tower cylinder radius
TOWER_H   = 2.20   # tower height (cylinder)
WALL_H    = 0.86   # connecting wall height
WALL_THK  = 0.22   # wall thickness
KEEP_HW   = 0.84   # keep half-width (full = 1.68)
KEEP_HALF = 1.55   # keep half-height → full keep = 3.10, top at z = 3.10

# half-span of wall between adjacent tower edges (gap 0.06 at each end vs tower)
WALL_HALF = CORNER_D - TOWER_R - 0.06   # = 0.90


def cone4(r, depth, x, y, z):
	"""4-sided pyramid (keep roof), rotated 45° so faces align with walls."""
	o = T.cone(r, depth, x, y, z, verts=4)
	o.rotation_euler[2] = math.radians(45)
	bpy.ops.object.transform_apply(rotation=True)
	return o


stone, roof = [], []
corners = [(-CORNER_D, -CORNER_D), (CORNER_D, -CORNER_D),
           (-CORNER_D,  CORNER_D), (CORNER_D,  CORNER_D)]

# ── foundation slab ────────────────────────────────────────────────────────────
stone.append(T.box(CORNER_D + TOWER_R + 0.18,
                   CORNER_D + TOWER_R + 0.18, 0.10, 0, 0, 0.05))

# ── central keep ──────────────────────────────────────────────────────────────
stone.append(T.box(KEEP_HW, KEEP_HW, KEEP_HALF, 0, 0, KEEP_HALF))

# Keep battlements: 8 merlons (4 corners + 4 face-centres), raised above keep top
KEEP_TOP  = KEEP_HALF * 2          # = 3.10
MERN_SZ   = 0.17
MERN_H    = 0.24
MERN_INSET = 0.58                  # distance from centre
for mx, my in [(-MERN_INSET, -MERN_INSET), ( MERN_INSET, -MERN_INSET),
               (-MERN_INSET,  MERN_INSET), ( MERN_INSET,  MERN_INSET),
               (0, -MERN_INSET), (0, MERN_INSET), (-MERN_INSET, 0), (MERN_INSET, 0)]:
	stone.append(T.box(MERN_SZ, MERN_SZ, MERN_H, mx, my, KEEP_TOP + MERN_H * 0.5))

# Keep roof (4-sided steep pyramid) + flag pole + pennant
roof.append(cone4(KEEP_HW + 0.20, 1.55, 0, 0, KEEP_TOP + 0.775))
stone.append(T.cyl(0.035, 0.85, 0, 0, KEEP_TOP + 1.55 + 0.425, 6))
roof.append(T.box(0.40, 0.03, 0.18, 0.24, 0, KEEP_TOP + 1.55 + 0.56))

# ── corner towers ─────────────────────────────────────────────────────────────
for cx, cy in corners:
	stone.append(T.cyl(TOWER_R, TOWER_H, cx, cy, TOWER_H * 0.5))

	# 6 merlons ringing the tower top
	N_MERN = 6
	for mi in range(N_MERN):
		ang = math.radians(mi * 360 / N_MERN + 30)
		mrx = cx + math.cos(ang) * (TOWER_R - 0.08)
		mry = cy + math.sin(ang) * (TOWER_R - 0.08)
		stone.append(T.box(0.13, 0.13, 0.19, mrx, mry, TOWER_H + 0.095))

	# Steep conical roof
	roof.append(T.cone(TOWER_R + 0.12, 1.25, cx, cy, TOWER_H + 0.625, verts=8))

	# Flag pole + pennant
	stone.append(T.cyl(0.028, 0.68, cx, cy, TOWER_H + 1.25 + 0.34, 6))
	roof.append(T.box(0.18, 0.025, 0.12, cx + 0.19, cy, TOWER_H + 1.35 + 0.19))

# ── connecting walls (N / S / E / W) with crenellations ──────────────────────
for wy in [-CORNER_D, CORNER_D]:
	stone.append(T.box(WALL_HALF, WALL_THK, WALL_H, 0, wy, WALL_H * 0.5))
	for wk in [-0.55, 0.0, 0.55]:
		stone.append(T.box(0.14, 0.14, 0.19, wk * WALL_HALF, wy, WALL_H + 0.095))

for wx in [-CORNER_D, CORNER_D]:
	stone.append(T.box(WALL_THK, WALL_HALF, WALL_H, wx, 0, WALL_H * 0.5))
	for wk in [-0.55, 0.0, 0.55]:
		stone.append(T.box(0.14, 0.14, 0.19, wx, wk * WALL_HALF, WALL_H + 0.095))

# ── assign materials + join + bevel ──────────────────────────────────────────
for o in stone:
	o.data.materials.append(stone_mat)
for o in roof:
	o.data.materials.append(roof_mat)

stone_obj = T.join(stone, "stone")
T.bevel(stone_obj, width=0.03, segments=2)
roof_obj  = T.join(roof,  "roof")
T.bevel(roof_obj,  width=0.03, segments=2)

T.export("castle")
print("CASTLE_DONE")
