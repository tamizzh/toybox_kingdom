# gen_house.py — detailed toy house -> assets/models/house.glb
#
# House is 40 % wider/longer than the previous version; wall height unchanged.
# Roof is now a 4-sided HIP roof (all four faces slope to a central ridge) so
# the slope is visible from every camera angle — not just the gable ends.
#
# FOUR named submeshes (populace.gd loads each independently):
#   "body"  — walls + embedded window frames/sills/headers + door + chimney (cream)
#   "roof"  — 4-sided hip roof with wide eave overhang                      (kingdom colour)
#   "fence" — picket fence with gate opening on front                       (warm wood brown)
#   "lawn"  — flat green slab filling the fence interior                    (bright garden green)
#
# Godot instance Y offsets (PROP_Y = 0.07, unchanged from previous version):
#   body  : PROP_Y + 0.380   (BH = 0.380; body spans PROP_Y…PROP_Y+0.760)
#   roof  : PROP_Y + 0.988   (body_top 0.760 + RHH 0.240 − embed 0.012)
#   fence : PROP_Y + 0.125   (POST_H/2 = 0.125)
#   lawn  : PROP_Y + 0.125   (same coordinate origin as fence)
#
# Run:  blender --background --python tools/gen_house.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()

# ── dimensions ────────────────────────────────────────────────────────────────
BW  = 0.353          # body half-footprint  (previous 0.252 × 1.40)
BH  = 0.380          # body half-height — UNCHANGED
RH  = 0.480          # hip roof full height
RHH = RH / 2         # = 0.240
# Eave overhang — hip roof base is wider than body on all four sides
RW  = BW + 0.092     # = 0.445  half-width  (roof wider than body by 9.2 cm per side)
RD  = BW + 0.096     # = 0.449  half-depth
# Hip ridge runs along Y; length < RD → the front/back faces become sloping hips
RIDGE_L = RD * 0.38  # = 0.171  (short ridge → steep hip, prominent slope on front/back)

# Chimney (scaled with BW)
CHX, CHY  = 0.133, 0.103
CH_HW     = 0.058
CHIM_BOT  = BH - 0.080
CHIM_TOP  = BH + 0.540
CHIM_HH   = (CHIM_TOP - CHIM_BOT) * 0.5
CHIM_CZ   = (CHIM_TOP + CHIM_BOT) * 0.5

# Fence
FHW    = 0.441       # fence half-footprint (garden gap 8.8 cm from house wall per side)
POST_H = 0.250
FHALF  = POST_H / 2  # = 0.125
GATE_HW = 0.082

# Lawn
LAWN_HW = FHW - 0.028   # = 0.413
LAWN_HH = 0.005
LAWN_CZ = -(FHALF - LAWN_HH)   # = -0.120

# ── materials ─────────────────────────────────────────────────────────────────
body_mat  = T.mat("body",  (0.93, 0.89, 0.81), rough=0.68)
roof_mat  = T.mat("roof",  (0.22, 0.52, 0.22), rough=0.50)
fence_mat = T.mat("fence", (0.52, 0.33, 0.14), rough=0.84)
lawn_mat  = T.mat("lawn",  (0.30, 0.60, 0.20), rough=0.90)

body_parts  = []
roof_parts  = []
fence_parts = []
lawn_parts  = []

# ─────────────────────────── HIP ROOF ─────────────────────────────────────────
def hip_roof(rw, rd, rh, ridge_l):
    """4-sided hip roof. Ridge runs along Y from -ridge_l to +ridge_l at top."""
    import bmesh as _bm
    mesh_data = bpy.data.meshes.new("hip_mesh")
    bm = _bm.new()
    hh = rh / 2
    v = [
        bm.verts.new((-rw, -rd, -hh)),  # 0 front-left base
        bm.verts.new(( rw, -rd, -hh)),  # 1 front-right base
        bm.verts.new(( rw,  rd, -hh)),  # 2 back-right base
        bm.verts.new((-rw,  rd, -hh)),  # 3 back-left base
        bm.verts.new((  0, -ridge_l, hh)),  # 4 front ridge end
        bm.verts.new((  0,  ridge_l, hh)),  # 5 back ridge end
    ]
    bm.faces.new([v[0], v[1], v[4]])              # front hip  (triangle)
    bm.faces.new([v[2], v[3], v[5]])              # back hip   (triangle)
    bm.faces.new([v[3], v[0], v[4], v[5]])        # left slope (quad)
    bm.faces.new([v[1], v[2], v[5], v[4]])        # right slope (quad)
    bm.faces.new([v[3], v[2], v[1], v[0]])        # bottom (closed base)
    bm.to_mesh(mesh_data)
    bm.free()
    mesh_data.update()
    obj = bpy.data.objects.new("hip_roof", mesh_data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj


roof_parts.append(hip_roof(RW, RD, RH, RIDGE_L))

# ─────────────────────────── BODY ─────────────────────────────────────────────
body_parts.append(T.box(BW, BW, BH, 0, 0, 0))

# Window frames — back face 5 mm INSIDE front wall (Y = -BW)
WFW, WFH, WFD = 0.064, 0.052, 0.016
_wy = -(BW + WFD - 0.005)
for wx in [-0.128, 0.128]:
    body_parts.append(T.box(WFW, WFD, WFH, wx, _wy, 0.062))
    # sill
    body_parts.append(T.box(WFW + 0.016, WFD + 0.004, 0.009,
                             wx, _wy - 0.002, 0.062 - WFH - 0.011))
    # header
    body_parts.append(T.box(WFW + 0.012, WFD + 0.002, 0.008,
                             wx, _wy - 0.001, 0.062 + WFH + 0.009))

# Door — embedded 5 mm into front wall
DW, DH, DD = 0.084, 0.118, 0.016
_dy = -(BW + DD - 0.005)
body_parts.append(T.box(DW, DD, DH, 0, _dy, -BH + DH))
body_parts.append(T.box(DW + 0.016, DD + 0.002, 0.011,
                         0, _dy, -BH + DH * 2 + 0.011))

# Chimney (starts inside body)
body_parts.append(T.box(CH_HW, CH_HW, CHIM_HH, CHX, CHY, CHIM_CZ))
body_parts.append(T.box(CH_HW + 0.020, CH_HW + 0.020, 0.013,
                         CHX, CHY, CHIM_TOP + 0.013))
body_parts.append(T.cyl(0.015, 0.054, CHX - 0.018, CHY - 0.012, CHIM_TOP + 0.046, 6))
body_parts.append(T.cyl(0.015, 0.054, CHX + 0.016, CHY + 0.012, CHIM_TOP + 0.046, 6))

# ─────────────────────────── FENCE ────────────────────────────────────────────
PHW    = 0.028
RAIL_T = 0.010
PIK_HW = 0.012
PIK_HH = 0.100
PIK_CZ = -0.012
RAIL_ZL = -FHALF + 0.055
RAIL_ZH =  FHALF - 0.054


def _post(x, y, hh=FHALF):
    fence_parts.append(T.box(PHW, PHW, hh, x, y, 0))


def _sect_x(y, x0, x1, n=4):
    cx = (x0 + x1) * 0.5;  hl = (x1 - x0) * 0.5
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZL))
    fence_parts.append(T.box(hl, RAIL_T, RAIL_T, cx, y, RAIL_ZH))
    for k in range(n):
        fx = x0 + (k + 0.5) / n * (x1 - x0)
        fence_parts.append(T.box(PIK_HW, RAIL_T + 0.003, PIK_HH, fx, y, PIK_CZ))


def _sect_y(x, y0, y1, n=4):
    cy = (y0 + y1) * 0.5;  hl = (y1 - y0) * 0.5
    fence_parts.append(T.box(RAIL_T, hl, RAIL_T, x, cy, RAIL_ZL))
    fence_parts.append(T.box(RAIL_T, hl, RAIL_T, x, cy, RAIL_ZH))
    for k in range(n):
        fy = y0 + (k + 0.5) / n * (y1 - y0)
        fence_parts.append(T.box(RAIL_T + 0.003, PIK_HW, PIK_HH, x, fy, PIK_CZ))


for cx, cy in [(-FHW, -FHW), (FHW, -FHW), (-FHW, FHW), (FHW, FHW)]:
    _post(cx, cy)
_post(-GATE_HW, -FHW, FHALF * 1.16)
_post( GATE_HW, -FHW, FHALF * 1.16)
_post(-FHW, 0); _post(FHW, 0); _post(0, FHW)

_sect_x( FHW, -FHW + PHW, -PHW, 4);    _sect_x(FHW,  PHW,  FHW - PHW, 4)
_sect_y(-FHW, -FHW + PHW, -PHW, 4);    _sect_y(-FHW, PHW,  FHW - PHW, 4)
_sect_y( FHW, -FHW + PHW, -PHW, 4);    _sect_y( FHW, PHW,  FHW - PHW, 4)
_sect_x(-FHW, -FHW + PHW, -GATE_HW - PHW, 3)
_sect_x(-FHW,  GATE_HW + PHW,  FHW - PHW,  3)

# ─────────────────────────── LAWN ─────────────────────────────────────────────
lawn_parts.append(T.box(LAWN_HW, LAWN_HW, LAWN_HH, 0, 0, LAWN_CZ))

# ─────────────────────── ASSEMBLE & EXPORT ────────────────────────────────────
for o in body_parts:  o.data.materials.append(body_mat)
for o in roof_parts:  o.data.materials.append(roof_mat)
for o in fence_parts: o.data.materials.append(fence_mat)
for o in lawn_parts:  o.data.materials.append(lawn_mat)

body_obj  = T.join(body_parts,  "body");   T.bevel(body_obj,  width=0.018, segments=2)
roof_obj  = T.join(roof_parts,  "roof");   T.bevel(roof_obj,  width=0.022, segments=2)
fence_obj = T.join(fence_parts, "fence");  T.bevel(fence_obj, width=0.006, segments=1)
lawn_obj  = T.join(lawn_parts,  "lawn")

T.export("house")
print("HOUSE_DONE")
