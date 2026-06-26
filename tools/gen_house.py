# gen_house.py — detailed toy house -> assets/models/house.glb
#
# Target aesthetic (target_art.png):
#   Chimneys, raised window frames + sills, door frame with lintel,
#   corner quoins, wide roof overhang — recognisably a house even at tiny scale.
#
# Two named objects so populace.gd can tint each independently:
#   "body"  — walls + chimney shaft + quoins + door/window details (cream stone)
#   "roof"  — main gable + chimney cap (kingdom colour)
#
# Blender convention:
#   Z = up (→ Godot Y),  X = right (→ Godot X),  Y = depth (→ Godot -Z)
#   Front face of house = -Y in Blender (faces viewer in Godot +Z isometric view)
#
# Dimensions chosen so populace.gd instance offsets below work:
#   body center at Godot  PROP_Y + 0.32   (body spans PROP_Y to PROP_Y+0.64)
#   roof center at Godot  PROP_Y + 0.85   (roof sits on top, peak at +1.06)
#
# Run:  blender --background --python tools/gen_house.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()

CELL = 0.6

# ── dimensions ────────────────────────────────────────────────────────────────
BW  = CELL * 0.76 / 2   # body half-footprint  = 0.228
BH  = 0.32               # body half-height     → full height 0.64
RW  = CELL * 0.96 / 2   # roof half-footprint  = 0.288 (overhang = BW+0.060)
RD  = CELL * 1.00 / 2   # roof half-depth      = 0.300
RH  = 0.42               # roof full height

# Materials (Godot overrides via material_override, these are placeholder colours)
body_mat = T.mat("body", (0.92, 0.88, 0.80), rough=0.72)
roof_mat = T.mat("roof", (0.25, 0.55, 0.25), rough=0.55)

body_parts = []
roof_parts  = []

# ── BODY ──────────────────────────────────────────────────────────────────────

# Main walls
body_parts.append(T.box(BW, BW, BH, 0, 0, 0))

# Horizontal string course (thin belt midway up the wall = a classic toy-house read)
body_parts.append(T.box(BW + 0.007, BW + 0.007, 0.013, 0, 0, -BH * 0.10))

# Corner quoins — raised square strips at the 4 vertical edges give depth + scale
for qx, qy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
    body_parts.append(T.box(0.024, 0.024, BH + 0.004, qx * (BW - 0.012), qy * (BW - 0.012), 0.002))

# ── Front face windows (front = -Y in Blender) ──
WFW, WFH, WFD = 0.058, 0.050, 0.013   # frame half-width, half-height, protrusion depth
WFSY = -(BW + WFD)                     # Y position (just beyond front face)
for wx in [-0.090, 0.090]:
    # Window frame (raised rectangle)
    body_parts.append(T.box(WFW, WFD, WFH,  wx, WFSY, 0.050))
    # Window sill (thin ledge below frame)
    body_parts.append(T.box(WFW + 0.014, WFD + 0.004, 0.009,  wx, WFSY - 0.002, 0.050 - WFH - 0.011))
    # Window header (thin bar above frame)
    body_parts.append(T.box(WFW + 0.008, WFD + 0.002, 0.008,  wx, WFSY - 0.001, 0.050 + WFH + 0.009))

# ── Side windows (one per side, centred, slightly higher) ──
SWY = 0.035   # Z centre
for sx, sy in [(BW + WFD, 0), (-(BW + WFD), 0)]:
    body_parts.append(T.box(WFD, WFW, WFH,  sx, 0, SWY))
    body_parts.append(T.box(WFD + 0.004, WFW + 0.012, 0.009,  sx * 0.998, 0, SWY - WFH - 0.011))

# ── Door (front face, centred, near the bottom) ──
DW, DH, DD = 0.070, 0.108, 0.015
DY = -(BW + DD)
DZ = -BH + DH                           # door bottom sits at the house base
body_parts.append(T.box(DW, DD, DH, 0, DY, DZ))
# Lintel bar above door opening
body_parts.append(T.box(DW + 0.014, DD + 0.002, 0.010, 0, DY, DZ + DH + 0.010))
# Tiny door step at the base
body_parts.append(T.box(DW + 0.018, 0.024, 0.016, 0, -(BW + 0.012), -BH - 0.010))

# ── Chimney (stone-coloured, rises from mid-body through the roof peak) ──
# Placed at Blender (+X, +Y) offset so it reads clearly against the roof slope.
# Z range: from BH*0.05 (starts inside the body near the top) up to BH + 0.52
#          In Godot Y: body instance at +0.32, so chimney tip at 0.32 + 0.32 + 0.52 = 1.16
#          Roof peak in Godot Y: 0.85 + 0.21 = 1.06  → chimney pokes 0.10 above the peak.
CHX, CHY = 0.092, 0.074        # Blender XY offset of chimney centre from house centre
CHIM_BOT_Z = BH * 0.05        # = 0.016
CHIM_TOP_Z = BH + 0.52        # = 0.84
CHIM_CZ = (CHIM_BOT_Z + CHIM_TOP_Z) * 0.5   # = 0.428
CHIM_HH = (CHIM_TOP_Z - CHIM_BOT_Z) * 0.5   # = 0.412
CH_HW = 0.054
body_parts.append(T.box(CH_HW, CH_HW, CHIM_HH, CHX, CHY, CHIM_CZ))

# Chimney crown (wider flange at the very top, Godot will see as a stone cap)
body_parts.append(T.box(CH_HW + 0.016, CH_HW + 0.016, 0.012,
                         CHX, CHY, CHIM_TOP_Z + 0.012))

# Two chimney pots (small cylinders rising from the crown)
body_parts.append(T.cyl(0.015, 0.058, CHX - 0.016, CHY - 0.012, CHIM_TOP_Z + 0.045, 6))
body_parts.append(T.cyl(0.015, 0.058, CHX + 0.016, CHY + 0.012, CHIM_TOP_Z + 0.045, 6))

# ── ROOF ──────────────────────────────────────────────────────────────────────

# Main gable prism (overhangs the body on all sides for a proper eave)
# prism: sx=X-width, sy=Y-depth (ridge runs along Y), sz=full height
roof_parts.append(T.prism(RW * 2, RD * 2, RH, 0, 0, 0))

# Chimney cap — small decorative flange at chimney tip, coloured with the roof
# In ROOF-local coordinates:
#   chimney tip Godot Y = PROP_Y + 1.16  (calculated above)
#   roof instance Godot Y = PROP_Y + 0.85
#   → chimney tip roof-local Blender Z = 1.16 - 0.85 = 0.31
CAP_Z = 0.31
roof_parts.append(T.box(CH_HW + 0.024, CH_HW + 0.024, 0.010,
                         CHX, CHY, CAP_Z))

# ── assemble ──────────────────────────────────────────────────────────────────
for o in body_parts: o.data.materials.append(body_mat)
for o in roof_parts:  o.data.materials.append(roof_mat)

body_obj = T.join(body_parts, "body")
T.bevel(body_obj, width=0.018, segments=2)

roof_obj = T.join(roof_parts, "roof")
T.bevel(roof_obj, width=0.018, segments=2)

T.export("house")
print("HOUSE_DONE")
