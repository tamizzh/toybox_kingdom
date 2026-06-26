# Headless Blender generator for a low-poly toy house -> assets/models/house.glb
# TWO named objects matching what populace.gd expects:
#   "body"  (cream box — constant colour; MaterialOverride applies kingdom tint to roof)
#   "roof"  (gable prism — tinted per-kingdom via MultiMesh instance colour)
# Dimensions match the current populace.gd MultiMesh setup so the swap is drop-in:
#   body: 0.444 × 0.444 × 0.580  (= cell*0.74 × cell*0.74 × 0.58, cell=0.6)
#   roof: 0.540 × 0.564 × 0.380  (= cell*0.90 × cell*0.94 × 0.38)
# Both are centred at the origin; populace.gd supplies the Y offsets via MultiMesh
# instance transforms (PROP_Y + 0.29 for body, PROP_Y + 0.76 for roof).
# Run:  blender --background --python tools/gen_house.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()

CELL = 0.6   # must match populace.gd's `cell` default

# Materials (placeholder colours — Godot overrides via shader)
body_mat = T.mat("body", (0.94, 0.85, 0.71), rough=0.78)   # warm cream
roof_mat = T.mat("roof", (0.30, 0.65, 0.30), rough=0.62)   # placeholder green

# ── house body: a slightly detailed box centred at origin ─────────────────────
# Half-extents: X=Y=CELL*0.74/2=0.222, Z(height)=0.58/2=0.290
BW = CELL * 0.74 / 2   # 0.222 — body half-width
BH = 0.58 / 2           # 0.290 — body half-height

body_parts = []
body_parts.append(T.box(BW, BW, BH, 0, 0, 0))   # main body

# Shallow door indent on the front face (facing +Y): recessed rectangle
DOOR_W, DOOR_H, DOOR_D = 0.10, 0.18, 0.04
body_parts.append(T.box(DOOR_W, DOOR_D, DOOR_H, 0, BW - DOOR_D * 0.5, -BH + DOOR_H))

# ── gable roof: prism centred at origin ──────────────────────────────────────
# Width(X)=CELL*0.90=0.54, Depth(Y)=CELL*0.94=0.564, Height(Z)=0.38
roof_parts = []
roof_parts.append(T.prism(CELL * 0.90, CELL * 0.94, 0.38, 0, 0, 0))

# ── assign materials, join, bevel ────────────────────────────────────────────
for o in body_parts:
	o.data.materials.append(body_mat)
for o in roof_parts:
	o.data.materials.append(roof_mat)

body_obj = T.join(body_parts, "body")
T.bevel(body_obj, width=0.025, segments=2)

roof_obj = T.join(roof_parts, "roof")
T.bevel(roof_obj, width=0.025, segments=2)

T.export("house")
print("HOUSE_DONE")
