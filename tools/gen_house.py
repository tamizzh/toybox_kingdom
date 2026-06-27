# gen_house.py — detailed toy house -> assets/models/house.glb
#
# Matches reference image: cream walls, steep kingdom-coloured gable, chimney
# with crown + pots, embedded window frames, door with lintel, picket fence,
# and a green lawn slab inside the fence.
#
# FOUR named submeshes (populace.gd loads each independently):
#   "body"  — walls + embedded window frames/sills + door + chimney  (cream)
#   "roof"  — gable prism with wide eave overhang                    (kingdom colour)
#   "fence" — picket fence with gate opening on front                (warm wood brown)
#   "lawn"  — flat green slab filling the fence interior             (bright garden green)
#
# Z-fighting rules applied throughout:
#   - Every protrusion's back face is placed 5 mm INSIDE the host surface (never flush).
#   - Roof prism sits 12 mm LOWER than the mathematical body-top so its base
#     is embedded inside the walls — eliminates the coplanar body-top / roof-bottom.
#   - Chimney box starts 8 cm below the body top so it has no coplanar cap face.
#
# Godot instance Y offsets (relative to PROP_Y = 0.07):
#   body  : PROP_Y + 0.380       (BH = 0.380 → body spans PROP_Y…PROP_Y+0.760)
#   roof  : PROP_Y + 0.988       (body_top(0.760) + RHH(0.240) - embed(0.012))
#   fence : PROP_Y + 0.125       (POST_H/2 = 0.125)
#   lawn  : PROP_Y + 0.125       (same origin; lawn is near fence bottom)
#
# Run:  blender --background --python tools/gen_house.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()

# ── dimensions ────────────────────────────────────────────────────────────────
BW = 0.252          # body half-footprint X/Y  (50.4 cm plan)
BH = 0.380          # body half-height         (76 cm walls — tall like the image)
RH = 0.480          # roof full height          (steep pitch)
RHH = RH / 2        # = 0.240
RW = BW + 0.082     # = 0.334  roof half-width (8.2 cm eave overhang per side)
RD = BW + 0.086     # = 0.338  roof half-depth

# Chimney — starts INSIDE the body so no face is flush with the body top
CHX, CHY  = 0.096, 0.074
CH_HW     = 0.052
CHIM_BOT  = BH - 0.080          # 8 cm inside body top
CHIM_TOP  = BH + 0.540          # pokes above roof peak
CHIM_HH   = (CHIM_TOP - CHIM_BOT) * 0.5
CHIM_CZ   = (CHIM_TOP + CHIM_BOT) * 0.5

# Fence
FHW    = 0.315      # fence half-footprint (63 cm) — 6.3 cm garden gap around house
POST_H = 0.250      # fence post full height
FHALF  = POST_H / 2 # = 0.125  (fence mesh centred at Blender Z=0)
GATE_HW = 0.078     # half-width of gate opening on front face

# Lawn — fills interior of fence, near-flush with fence bottom
LAWN_HW = FHW - 0.028    # = 0.287 — extends well beyond house walls (BW=0.252)
LAWN_HH = 0.005
LAWN_CZ = -(FHALF - LAWN_HH)  # -0.120 → bottom at Z=-0.125, top at Z=-0.115

# placeholder materials (Godot's material_override replaces these at runtime)
body_mat  = T.mat("body",  (0.93, 0.89, 0.81), rough=0.68)
roof_mat  = T.mat("roof",  (0.22, 0.52, 0.22), rough=0.50)
fence_mat = T.mat("fence", (0.52, 0.33, 0.14), rough=0.84)
lawn_mat  = T.mat("lawn",  (0.30, 0.60, 0.20), rough=0.90)

body_parts  = []
roof_parts  = []
fence_parts = []
lawn_parts  = []

# ─────────────────────────── BODY ─────────────────────────────────────────────
body_parts.append(T.box(BW, BW, BH, 0, 0, 0))

# Window frames — back face embedded 5 mm inside the front wall at Y = -BW
WFW, WFH, WFD = 0.058, 0.050, 0.016
_wy = -(BW + WFD - 0.005)   # back face at -(BW - 0.005) = inside wall
for wx in [-0.092, 0.092]:
    body_parts.append(T.box(WFW, WFD, WFH, wx, _wy, 0.060))
    # sill
    body_parts.append(T.box(WFW + 0.014, WFD + 0.004, 0.008,
                             wx, _wy - 0.002, 0.060 - WFH - 0.010))
    # header
    body_parts.append(T.box(WFW + 0.010, WFD + 0.002, 0.007,
                             wx, _wy - 0.001, 0.060 + WFH + 0.008))

# Door — embedded 5 mm into front wall
DW, DH, DD = 0.070, 0.118, 0.016
_dy = -(BW + DD - 0.005)
body_parts.append(T.box(DW, DD, DH, 0, _dy, -BH + DH))
# lintel above door
body_parts.append(T.box(DW + 0.014, DD + 0.002, 0.010,
                         0, _dy, -BH + DH * 2 + 0.010))

# Chimney shaft (starts inside body — no coplanar cap face with body top)
body_parts.append(T.box(CH_HW, CH_HW, CHIM_HH, CHX, CHY, CHIM_CZ))
# Crown flange
body_parts.append(T.box(CH_HW + 0.018, CH_HW + 0.018, 0.012,
                         CHX, CHY, CHIM_TOP + 0.012))
# Two pots
body_parts.append(T.cyl(0.014, 0.052, CHX - 0.016, CHY - 0.010, CHIM_TOP + 0.044, 6))
body_parts.append(T.cyl(0.014, 0.052, CHX + 0.014, CHY + 0.010, CHIM_TOP + 0.044, 6))

# ─────────────────────────── ROOF ─────────────────────────────────────────────
# Prism centred at Z=0 in roof-local coords.  populace.gd places this instance
# 12 mm below the mathematical body-top so the prism base is embedded inside
# the walls — eliminates the coplanar body-top / roof-bottom Z-fight.
roof_parts.append(T.prism(RW * 2, RD * 2, RH, 0, 0, 0))

# ─────────────────────────── FENCE ────────────────────────────────────────────
PHW    = 0.026   # post half-width
RAIL_T = 0.009   # rail half-thickness
PIK_HW = 0.011   # picket half-width
PIK_HH = 0.100   # picket half-height
PIK_CZ = -0.012  # picket centre Z (near fence base)
RAIL_ZL = -FHALF + 0.055
RAIL_ZH =  FHALF - 0.054


def _post(x, y, hh=FHALF):
    fence_parts.append(T.box(PHW, PHW, hh, x, y, 0))


def _sect_x(y, x0, x1, n=3):
    cx = (x0 + x1) * 0.5
    hl = (x1 - x0) * 0.5
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZL))
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZH))
    for k in range(n):
        fx = x0 + (k + 0.5) / n * (x1 - x0)
        fence_parts.append(T.box(PIK_HW, RAIL_T + 0.003, PIK_HH, fx, y, PIK_CZ))


def _sect_y(x, y0, y1, n=3):
    cy = (y0 + y1) * 0.5
    hl = (y1 - y0) * 0.5
    fence_parts.append(T.box(RAIL_T, hl, RAIL_T, x, cy, RAIL_ZL))
    fence_parts.append(T.box(RAIL_T, hl, RAIL_T, x, cy, RAIL_ZH))
    for k in range(n):
        fy = y0 + (k + 0.5) / n * (y1 - y0)
        fence_parts.append(T.box(RAIL_T + 0.003, PIK_HW, PIK_HH, x, fy, PIK_CZ))


# Corner posts
for cx, cy in [(-FHW, -FHW), (FHW, -FHW), (-FHW, FHW), (FHW, FHW)]:
    _post(cx, cy)

# Taller gate posts on front face (Y = -FHW)
_post(-GATE_HW, -FHW, FHALF * 1.16)
_post( GATE_HW, -FHW, FHALF * 1.16)

# Mid posts on sides and back
_post(-FHW, 0)
_post( FHW, 0)
_post(0,  FHW)

# Fence panels — back, sides, and front with gate opening
_sect_x( FHW, -FHW + PHW, -PHW, 3)
_sect_x( FHW,  PHW,  FHW - PHW, 3)
_sect_y(-FHW, -FHW + PHW, -PHW, 3)
_sect_y(-FHW,  PHW,  FHW - PHW, 3)
_sect_y( FHW, -FHW + PHW, -PHW, 3)
_sect_y( FHW,  PHW,  FHW - PHW, 3)
_sect_x(-FHW, -FHW + PHW, -GATE_HW - PHW, 2)
_sect_x(-FHW,  GATE_HW + PHW,  FHW - PHW, 2)

# ─────────────────────────── LAWN ─────────────────────────────────────────────
# Flat green slab in the fence coordinate system (Z=0 at fence centre height).
# In Godot (instance at PROP_Y + FHALF): lawn top ≈ PROP_Y + 0.010 (just above ground).
lawn_parts.append(T.box(LAWN_HW, LAWN_HW, LAWN_HH, 0, 0, LAWN_CZ))

# ─────────────────────── ASSEMBLE & EXPORT ────────────────────────────────────
for o in body_parts:  o.data.materials.append(body_mat)
for o in roof_parts:  o.data.materials.append(roof_mat)
for o in fence_parts: o.data.materials.append(fence_mat)
for o in lawn_parts:  o.data.materials.append(lawn_mat)

body_obj  = T.join(body_parts,  "body");   T.bevel(body_obj,  width=0.016, segments=2)
roof_obj  = T.join(roof_parts,  "roof");   T.bevel(roof_obj,  width=0.020, segments=2)
fence_obj = T.join(fence_parts, "fence");  T.bevel(fence_obj, width=0.006, segments=1)
lawn_obj  = T.join(lawn_parts,  "lawn")    # no bevel on flat slab

T.export("house")
print("HOUSE_DONE")
