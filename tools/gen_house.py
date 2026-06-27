# gen_house.py — detailed toy house -> assets/models/house.glb
#
# Matches the reference image: cream walls, steep kingdom-coloured gable, chimney
# with crown + pots, embedded window frames (no Z-fight), door with lintel, and
# a surrounding picket fence with a gate opening on the front face.
#
# THREE named submeshes (populace.gd loads each independently):
#   "body"  — walls + window frames + door + chimney shaft/crown/pots  (cream)
#   "roof"  — gable prism with wide eave overhang                      (kingdom colour)
#   "fence" — picket fence with gate opening                           (warm wood brown)
#
# Blender → Godot axes: Z=up → Y, X=X, Y=depth → -Z.
# Front face (-Y in Blender) faces the isometric camera in Godot (+Z).
#
# Instance Y offsets for populace.gd (relative to PROP_Y):
#   body  : PROP_Y + BH        = PROP_Y + 0.330   (body spans PROP_Y … PROP_Y+0.660)
#   roof  : PROP_Y + BH*2+RHH  = PROP_Y + 0.890   (roof peak at PROP_Y+1.120)
#   fence : PROP_Y + FHALF     = PROP_Y + 0.125   (fence bottom on ground)
#
# Z-fighting prevention rule: every surface decoration's back face is placed
# 5 mm INSIDE the wall it sits on (embedded), so there is never a coplanar pair.
#
# Run:  blender --background --python tools/gen_house.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()

# ── dimensions ────────────────────────────────────────────────────────────────
BW = 0.240          # body half-footprint (48 × 48 cm plan)
BH = 0.330          # body half-height    (66 cm walls)
RH = 0.460          # roof full height    (steep 46 cm pitch)
RW = BW + 0.078     # = 0.318 roof half-width  (7.8 cm eave overhang per side)
RD = BW + 0.082     # = 0.322 roof half-depth

POST_H = 0.250      # fence post full height
FHALF  = POST_H / 2 # = 0.125  (fence mesh centred at Z=0)
FHW    = 0.286      # fence half-footprint (just within cell half of 0.300)
GATE_HW = 0.076     # half-width of gate opening on front fence

# chimney placement (Blender XY offset from house centre)
CHX, CHY  = 0.092, 0.070
CH_HW     = 0.050
CHIM_BOT  = BH - 0.080          # shaft start: 8 cm inside body top → no coplanar face
CHIM_TOP  = BH + 0.520          # shaft tip:   above roof peak at BH + RH/2 = 0.560
CHIM_HH   = (CHIM_TOP - CHIM_BOT) * 0.5
CHIM_CZ   = (CHIM_TOP + CHIM_BOT) * 0.5

# placeholder materials (Godot's material_override replaces these at runtime)
body_mat  = T.mat("body",  (0.93, 0.89, 0.81), rough=0.68)
roof_mat  = T.mat("roof",  (0.22, 0.52, 0.22), rough=0.50)
fence_mat = T.mat("fence", (0.52, 0.33, 0.14), rough=0.84)

body_parts  = []
roof_parts  = []
fence_parts = []

# ─────────────────────────── BODY ─────────────────────────────────────────────

# Main walls
body_parts.append(T.box(BW, BW, BH, 0, 0, 0))

# Window frames — front face is at Blender Y = -BW.
# Centre each frame so its back face sits 5 mm INSIDE the wall (no coplanar Z-fight).
WFW, WFH, WFD = 0.056, 0.048, 0.016
_wy = -(BW + WFD - 0.005)          # back face lands at -(BW - 0.005) = inside wall
for wx in [-0.090, 0.090]:
    body_parts.append(T.box(WFW, WFD, WFH,  wx, _wy, 0.055))
    # Sill: thin ledge below frame, same depth
    body_parts.append(T.box(WFW + 0.014, WFD + 0.004, 0.008,
                             wx, _wy - 0.002, 0.055 - WFH - 0.010))
    # Header: thin bar above frame
    body_parts.append(T.box(WFW + 0.010, WFD + 0.002, 0.007,
                             wx, _wy - 0.001, 0.055 + WFH + 0.008))

# Door — front face, bottom flush with house base
DW, DH, DD = 0.068, 0.112, 0.016
_dy = -(BW + DD - 0.005)           # same 5 mm embedding rule
body_parts.append(T.box(DW, DD, DH, 0, _dy, -BH + DH))
# Lintel above door
body_parts.append(T.box(DW + 0.014, DD + 0.002, 0.010,
                         0, _dy, -BH + DH * 2 + 0.010))

# Chimney shaft — starts inside the body so no face is shared with the body top
body_parts.append(T.box(CH_HW, CH_HW, CHIM_HH, CHX, CHY, CHIM_CZ))
# Crown: wider flange at the tip
body_parts.append(T.box(CH_HW + 0.018, CH_HW + 0.018, 0.012,
                         CHX, CHY, CHIM_TOP + 0.012))
# Two chimney pots
body_parts.append(T.cyl(0.013, 0.050, CHX - 0.014, CHY - 0.010, CHIM_TOP + 0.043, 6))
body_parts.append(T.cyl(0.013, 0.050, CHX + 0.014, CHY + 0.010, CHIM_TOP + 0.043, 6))

# ─────────────────────────── ROOF ─────────────────────────────────────────────

# Steep gable prism — ridge runs along Blender Y → Godot -Z
# Overhang: RW/RD each exceed BW/BD by ~8 cm on every side
roof_parts.append(T.prism(RW * 2, RD * 2, RH, 0, 0, 0))

# ─────────────────────────── FENCE ────────────────────────────────────────────
# Fence mesh centred at Blender Z = 0 → spans ±FHALF.
# Godot places it at PROP_Y + FHALF so the bottom sits exactly on the ground.

PHW    = 0.025   # post half-width
RAIL_T = 0.009   # rail half-thickness
PIK_HW = 0.011   # picket half-width
PIK_HH = 0.100   # picket half-height  (slightly shorter than post for visual clarity)
PIK_CZ = -0.012  # picket centre Z     (bottom near fence base, top below post top)
RAIL_ZL = -FHALF + 0.055   # lower rail Z
RAIL_ZH =  FHALF - 0.054   # upper rail Z


def _post(x, y, hh=FHALF):
    fence_parts.append(T.box(PHW, PHW, hh, x, y, 0))


def _sect_x(y, x0, x1, n=3):
    """Fence panel running in X at constant Y: two rails + n pickets."""
    cx = (x0 + x1) * 0.5
    hl = (x1 - x0) * 0.5
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZL))
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZH))
    for k in range(n):
        fx = x0 + (k + 0.5) / n * (x1 - x0)
        fence_parts.append(T.box(PIK_HW, RAIL_T + 0.003, PIK_HH, fx, y, PIK_CZ))


def _sect_y(x, y0, y1, n=3):
    """Fence panel running in Y at constant X: two rails + n pickets."""
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

# Gate posts on front face (Y = -FHW) — slightly taller for visual emphasis
_post(-GATE_HW, -FHW, FHALF * 1.14)
_post( GATE_HW, -FHW, FHALF * 1.14)

# Mid posts on sides and back
_post(-FHW, 0)   # left mid
_post( FHW, 0)   # right mid
_post(0,  FHW)   # back mid

# Back fence — two halves around the mid post
_sect_x(FHW, -FHW + PHW, -PHW, 3)
_sect_x(FHW,  PHW,  FHW - PHW, 3)

# Left fence — two halves around the mid post
_sect_y(-FHW, -FHW + PHW, -PHW, 3)
_sect_y(-FHW,  PHW,  FHW - PHW, 3)

# Right fence — two halves around the mid post
_sect_y(FHW, -FHW + PHW, -PHW, 3)
_sect_y(FHW,  PHW,  FHW - PHW, 3)

# Front fence — two halves with gate opening in the centre
_sect_x(-FHW, -FHW + PHW,     -GATE_HW - PHW, 2)
_sect_x(-FHW,  GATE_HW + PHW,  FHW - PHW,     2)

# ─────────────────────── ASSEMBLE & EXPORT ────────────────────────────────────
for o in body_parts:  o.data.materials.append(body_mat)
for o in roof_parts:  o.data.materials.append(roof_mat)
for o in fence_parts: o.data.materials.append(fence_mat)

body_obj  = T.join(body_parts,  "body");   T.bevel(body_obj,  width=0.016, segments=2)
roof_obj  = T.join(roof_parts,  "roof");   T.bevel(roof_obj,  width=0.018, segments=2)
fence_obj = T.join(fence_parts, "fence");  T.bevel(fence_obj, width=0.007, segments=1)

T.export("house")
print("HOUSE_DONE")
