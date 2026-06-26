# gen_castle.py — generates 6 tier-appropriate toy castle GLBs:
#   castle_t1.glb  Watchtower   – lone sentinel post
#   castle_t2.glb  Twin Towers  – first proper fort
#   castle_t3.glb  Keep         – imposing square keep + flanking towers
#   castle_t4.glb  Castle       – classic 4-tower castle (the iconic mid-game form)
#   castle_t5.glb  Fortress     – double-walled; inner keep + outer curtain ring
#   castle_t6.glb  Capital      – grand triple-ringed palace with gate tower
#
# Each GLB has exactly two named mesh nodes:
#   "stone"  – keep body / towers / walls / battlements (tinted cream by castle.gd)
#   "roof"   – cone caps / pyramids / pennants        (tinted to kingdom colour)
#
# Run:  blender --background --python tools/gen_castle.py
import bpy, sys, os, math

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T


# ─── shared geometry helpers ─────────────────────────────────────────────────

def _cone4(r, depth, x, y, z):
    """4-sided keep pyramid, faces aligned to walls (rotated 45°)."""
    o = T.cone(r, depth, x, y, z, verts=4)
    o.rotation_euler[2] = math.radians(45)
    bpy.ops.object.transform_apply(rotation=True)
    return o


def _ring_merlons(n, tower_r, z_top, cx=0.0, cy=0.0, offset_deg=0.0):
    """n battlements ringing the top of a cylinder of radius tower_r."""
    mr = max(tower_r - 0.07, 0.08)   # merlon centres just inside the wall face
    out = []
    for i in range(n):
        a = math.radians(i * 360.0 / n + offset_deg)
        out.append(T.box(0.065, 0.065, 0.095,
                         cx + math.cos(a) * mr,
                         cy + math.sin(a) * mr,
                         z_top + 0.095))
    return out


def _keep_merlons(hw, z_top):
    """8 merlons around the parapet of a square keep with half-width hw."""
    out = []
    for mx, my in [(-1, -1), (1, -1), (-1, 1), (1, 1),
                   (0, -1),  (0,  1), (-1, 0), (1, 0)]:
        out.append(T.box(0.075, 0.075, 0.100,
                         mx * hw * 0.82, my * hw * 0.82, z_top + 0.100))
    return out


def _wall_crens(n, x0, x1, y, z_top):
    """n crenellations spaced evenly along a wall running in X."""
    out = []
    for k in range(n):
        t = (k + 0.5) / n
        out.append(T.box(0.065, 0.065, 0.095,
                         x0 + t * (x1 - x0), y, z_top + 0.095))
    return out


def _wall_crens_y(n, x, y0, y1, z_top):
    """n crenellations spaced evenly along a wall running in Y."""
    out = []
    for k in range(n):
        t = (k + 0.5) / n
        out.append(T.box(0.065, 0.065, 0.095,
                         x, y0 + t * (y1 - y0), z_top + 0.095))
    return out


def _flag(stone, roof, x, y, z_base, h=0.55):
    """Add a flag pole (stone) + pennant (roof) at (x,y), base at z_base."""
    stone.append(T.cyl(0.025, h, x, y, z_base + h * 0.5, 6))
    roof.append(T.box(0.13, 0.01, 0.07, x + 0.12, y, z_base + h * 0.78))


def _bake(stone, roof, name):
    """Assign materials, join lists, bevel, export GLB."""
    sm = T.mat("stone", (0.52, 0.53, 0.58), rough=0.76)
    rm = T.mat("roof",  (0.72, 0.22, 0.18), rough=0.46)
    for o in stone:
        o.data.materials.append(sm)
    for o in roof:
        o.data.materials.append(rm)
    so = T.join(stone, "stone")
    T.bevel(so, width=0.030, segments=2)
    ro = T.join(roof, "roof")
    T.bevel(ro, width=0.030, segments=2)
    T.export(name)
    print(name.upper() + "_DONE")


# ─── T1: Watchtower ──────────────────────────────────────────────────────────
def gen_t1():
    """Single sentinel cylinder — barely a castle, but the beginning."""
    T.reset(); stone = []; roof = []
    TR = 0.42; TH = 1.15

    stone.append(T.box(0.62, 0.62, 0.045, 0, 0, 0.045))   # foundation
    stone.append(T.cyl(TR, TH, 0, 0, TH * 0.5))            # tower body
    stone += _ring_merlons(5, TR, TH, offset_deg=18)        # 5 battlements

    roof.append(T.cone(TR + 0.11, 0.74, 0, 0, TH + 0.37, verts=8))
    _flag(stone, roof, 0, 0, TH + 0.74, h=0.50)

    _bake(stone, roof, "castle_t1")


# ─── T2: Twin Towers ─────────────────────────────────────────────────────────
def gen_t2():
    """Two flanking towers with a low front gate wall."""
    T.reset(); stone = []; roof = []
    TR = 0.37; TH = 1.42; TX = 0.74   # tower radius, height, X offset

    stone.append(T.box(TX + TR + 0.14, 0.62, 0.045, 0, 0, 0.045))  # slab

    for sx in [-TX, TX]:
        stone.append(T.cyl(TR, TH, sx, 0, TH * 0.5))
        stone += _ring_merlons(4, TR, TH, cx=sx, offset_deg=45)
        roof.append(T.cone(TR + 0.12, 0.90, sx, 0, TH + 0.45, verts=8))
        _flag(stone, roof, sx, 0, TH + 0.90, h=0.52)

    # Gate wall: two short pilasters + lintel + parapet panels
    GH = TX - TR - 0.06   # half-width of the gate opening = 0.31
    WH = 0.80              # gate wall height
    stone.append(T.box(0.11, 0.14, WH * 0.5, -GH + 0.11, 0, WH * 0.5))  # left pilaster
    stone.append(T.box(0.11, 0.14, WH * 0.5,  GH - 0.11, 0, WH * 0.5))  # right pilaster
    stone.append(T.box(GH, 0.14, 0.12, 0, 0, WH + 0.12))                  # lintel
    stone += _wall_crens(3, -GH * 0.7, GH * 0.7, 0, WH + 0.24)

    _bake(stone, roof, "castle_t2")


# ─── T3: Keep ────────────────────────────────────────────────────────────────
def gen_t3():
    """Square keep with two front flanking towers and a gate wall."""
    T.reset(); stone = []; roof = []
    KHW = 0.56; KHH = 1.52   # keep half-width, half-height → full h = 3.04
    TR = 0.38; TH = 1.60; TX = 1.04   # front towers

    stone.append(T.box(TX + TR + 0.14, KHW + 0.84, 0.045, 0, 0, 0.045))  # foundation

    # Central keep (slightly offset back so front towers frame it)
    stone.append(T.box(KHW, KHW, KHH, 0, KHW * 0.18, KHH))
    KEEP_TOP = KHH * 2
    stone += _keep_merlons(KHW, KEEP_TOP)
    roof.append(_cone4(KHW + 0.20, 1.40, 0, KHW * 0.18, KEEP_TOP + 0.70))
    _flag(stone, roof, 0, KHW * 0.18, KEEP_TOP + 1.40, h=0.62)

    # Two front flanking towers
    for sx in [-TX, TX]:
        stone.append(T.cyl(TR, TH, sx, -KHW * 0.05, TH * 0.5))
        stone += _ring_merlons(4, TR, TH, cx=sx, cy=-KHW * 0.05, offset_deg=45)
        roof.append(T.cone(TR + 0.11, 0.95, sx, -KHW * 0.05, TH + 0.475, verts=8))
        _flag(stone, roof, sx, -KHW * 0.05, TH + 0.95, h=0.48)

    # Front gate wall (low, between the flanking towers)
    WALL_HALF = TX - TR - 0.08   # = 0.58
    WH = 0.82
    stone.append(T.box(WALL_HALF, 0.16, WH * 0.5, 0, -(KHW + 0.24), WH * 0.5))
    stone += _wall_crens(4, -WALL_HALF * 0.80, WALL_HALF * 0.80, -(KHW + 0.24), WH)

    # Rear wall connecting keep to back
    stone.append(T.box(KHW + 0.04, 0.16, WH * 0.4, 0, KHW + 0.36, WH * 0.4))
    stone += _wall_crens(3, -KHW * 0.7, KHW * 0.7, KHW + 0.36, WH * 0.8)

    _bake(stone, roof, "castle_t3")


# ─── T4: Castle ──────────────────────────────────────────────────────────────
def gen_t4():
    """Classic 4-tower castle — the iconic mid-game form."""
    T.reset(); stone = []; roof = []
    CD = 1.20; TR = 0.42; TH = 2.04         # corner distance, tower radius/height
    KHW = 0.76; KHH = 1.42                   # keep half-width / half-height
    WH = 0.86; WTH = 0.20                    # wall height / wall thickness half
    WSPAN = CD - TR - 0.07                   # wall half-span between towers

    corners = [(-CD, -CD), (CD, -CD), (-CD, CD), (CD, CD)]

    stone.append(T.box(CD + TR + 0.16, CD + TR + 0.16, 0.10, 0, 0, 0.05))  # slab

    # Central keep
    stone.append(T.box(KHW, KHW, KHH, 0, 0, KHH))
    KEEP_TOP = KHH * 2
    stone += _keep_merlons(KHW, KEEP_TOP)
    roof.append(_cone4(KHW + 0.20, 1.48, 0, 0, KEEP_TOP + 0.74))
    _flag(stone, roof, 0, 0, KEEP_TOP + 1.48, h=0.72)

    # Four corner towers
    for cx, cy in corners:
        stone.append(T.cyl(TR, TH, cx, cy, TH * 0.5))
        stone += _ring_merlons(6, TR, TH, cx=cx, cy=cy, offset_deg=30)
        roof.append(T.cone(TR + 0.12, 1.22, cx, cy, TH + 0.61, verts=8))
        _flag(stone, roof, cx, cy, TH + 1.22, h=0.58)

    # Connecting walls with crenellations
    for wy in [-CD, CD]:
        stone.append(T.box(WSPAN, WTH, WH * 0.5, 0, wy, WH * 0.5))
        stone += _wall_crens(3, -WSPAN * 0.72, WSPAN * 0.72, wy, WH)
    for wx in [-CD, CD]:
        stone.append(T.box(WTH, WSPAN, WH * 0.5, wx, 0, WH * 0.5))
        stone += _wall_crens_y(3, wx, -WSPAN * 0.72, WSPAN * 0.72, WH)

    _bake(stone, roof, "castle_t4")


# ─── T5: Fortress ────────────────────────────────────────────────────────────
def gen_t5():
    """Double-walled fortress: tall inner castle + lower outer curtain ring."""
    T.reset(); stone = []; roof = []

    # ── INNER WARD (like T4 but taller) ─────────────────────────────────────
    ICD = 1.14; ITR = 0.44; ITH = 2.30     # inner corners/towers
    KHW = 0.80; KHH = 1.60                  # keep
    IWH = 0.90; IWTH = 0.20
    IWSPAN = ICD - ITR - 0.06

    inner_corners = [(-ICD, -ICD), (ICD, -ICD), (-ICD, ICD), (ICD, ICD)]

    # Central keep
    stone.append(T.box(KHW, KHW, KHH, 0, 0, KHH))
    KEEP_TOP = KHH * 2
    stone += _keep_merlons(KHW, KEEP_TOP)
    roof.append(_cone4(KHW + 0.22, 1.60, 0, 0, KEEP_TOP + 0.80))
    _flag(stone, roof, 0, 0, KEEP_TOP + 1.60, h=0.78)

    for cx, cy in inner_corners:
        stone.append(T.cyl(ITR, ITH, cx, cy, ITH * 0.5))
        stone += _ring_merlons(6, ITR, ITH, cx=cx, cy=cy, offset_deg=30)
        roof.append(T.cone(ITR + 0.12, 1.30, cx, cy, ITH + 0.65, verts=8))
        _flag(stone, roof, cx, cy, ITH + 1.30, h=0.60)

    for wy in [-ICD, ICD]:
        stone.append(T.box(IWSPAN, IWTH, IWH * 0.5, 0, wy, IWH * 0.5))
        stone += _wall_crens(3, -IWSPAN * 0.72, IWSPAN * 0.72, wy, IWH)
    for wx in [-ICD, ICD]:
        stone.append(T.box(IWTH, IWSPAN, IWH * 0.5, wx, 0, IWH * 0.5))
        stone += _wall_crens_y(3, wx, -IWSPAN * 0.72, IWSPAN * 0.72, IWH)

    # ── OUTER CURTAIN ────────────────────────────────────────────────────────
    OCD = 1.64; OTR = 0.30; OTH = 1.18    # outer corner towers
    OWH = 0.74; OWTH = 0.18
    OWSPAN = OCD - OTR - 0.06

    outer_corners = [(-OCD, -OCD), (OCD, -OCD), (-OCD, OCD), (OCD, OCD)]

    stone.append(T.box(OCD + OTR + 0.16, OCD + OTR + 0.16, 0.10, 0, 0, 0.05))  # slab

    for cx, cy in outer_corners:
        stone.append(T.cyl(OTR, OTH, cx, cy, OTH * 0.5))
        stone += _ring_merlons(4, OTR, OTH, cx=cx, cy=cy, offset_deg=45)
        roof.append(T.cone(OTR + 0.09, 0.84, cx, cy, OTH + 0.42, verts=8))
        _flag(stone, roof, cx, cy, OTH + 0.84, h=0.44)

    for wy in [-OCD, OCD]:
        stone.append(T.box(OWSPAN, OWTH, OWH * 0.5, 0, wy, OWH * 0.5))
        stone += _wall_crens(3, -OWSPAN * 0.72, OWSPAN * 0.72, wy, OWH)
    for wx in [-OCD, OCD]:
        stone.append(T.box(OWTH, OWSPAN, OWH * 0.5, wx, 0, OWH * 0.5))
        stone += _wall_crens_y(3, wx, -OWSPAN * 0.72, OWSPAN * 0.72, OWH)

    _bake(stone, roof, "castle_t5")


# ─── T6: Capital ─────────────────────────────────────────────────────────────
def gen_t6():
    """Grand triple-walled capital: inner palace + middle ward + outer curtain."""
    T.reset(); stone = []; roof = []

    # ── OUTER SLAB ───────────────────────────────────────────────────────────
    stone.append(T.box(2.36, 2.36, 0.10, 0, 0, 0.05))

    # ── OUTER CURTAIN (4 corner + 4 mid-wall towers) ─────────────────────────
    OCD = 2.00; OTR = 0.26; OTH = 1.10
    OMID_D = OCD; OMID_R = 0.22; OMID_H = 1.00
    OWH = 0.72; OWTH = 0.17
    OWSPAN = OCD - OTR - 0.06

    outer_corners = [(-OCD, -OCD), (OCD, -OCD), (-OCD, OCD), (OCD, OCD)]
    for cx, cy in outer_corners:
        stone.append(T.cyl(OTR, OTH, cx, cy, OTH * 0.5))
        stone += _ring_merlons(4, OTR, OTH, cx=cx, cy=cy, offset_deg=45)
        roof.append(T.cone(OTR + 0.08, 0.78, cx, cy, OTH + 0.39, verts=8))
        _flag(stone, roof, cx, cy, OTH + 0.78, h=0.40)

    # mid-wall towers (one per wall face, centered)
    for mx, my in [(0, -OCD), (0, OCD), (-OCD, 0), (OCD, 0)]:
        stone.append(T.cyl(OMID_R, OMID_H, mx, my, OMID_H * 0.5))
        stone += _ring_merlons(4, OMID_R, OMID_H, cx=mx, cy=my, offset_deg=0)
        roof.append(T.cone(OMID_R + 0.07, 0.68, mx, my, OMID_H + 0.34, verts=8))

    for wy in [-OCD, OCD]:
        stone.append(T.box(OWSPAN, OWTH, OWH * 0.5, 0, wy, OWH * 0.5))
        stone += _wall_crens(4, -OWSPAN * 0.78, OWSPAN * 0.78, wy, OWH)
    for wx in [-OCD, OCD]:
        stone.append(T.box(OWTH, OWSPAN, OWH * 0.5, wx, 0, OWH * 0.5))
        stone += _wall_crens_y(4, wx, -OWSPAN * 0.78, OWSPAN * 0.78, OWH)

    # ── MIDDLE WARD (4 towers, compact ring) ─────────────────────────────────
    MCD = 1.46; MTR = 0.34; MTH = 1.52
    MWH = 0.88; MWTH = 0.20; MWSPAN = MCD - MTR - 0.06

    middle_corners = [(-MCD, -MCD), (MCD, -MCD), (-MCD, MCD), (MCD, MCD)]
    for cx, cy in middle_corners:
        stone.append(T.cyl(MTR, MTH, cx, cy, MTH * 0.5))
        stone += _ring_merlons(5, MTR, MTH, cx=cx, cy=cy, offset_deg=36)
        roof.append(T.cone(MTR + 0.11, 1.10, cx, cy, MTH + 0.55, verts=8))
        _flag(stone, roof, cx, cy, MTH + 1.10, h=0.52)

    for wy in [-MCD, MCD]:
        stone.append(T.box(MWSPAN, MWTH, MWH * 0.5, 0, wy, MWH * 0.5))
        stone += _wall_crens(4, -MWSPAN * 0.74, MWSPAN * 0.74, wy, MWH)
    for wx in [-MCD, MCD]:
        stone.append(T.box(MWTH, MWSPAN, MWH * 0.5, wx, 0, MWH * 0.5))
        stone += _wall_crens_y(4, wx, -MWSPAN * 0.74, MWSPAN * 0.74, MWH)

    # ── INNER PALACE (4 tall towers + grand keep + gatehouse) ────────────────
    ICD = 1.02; ITR = 0.46; ITH = 2.60
    KHW = 0.86; KHH = 1.85                 # keep half-extents
    IWH = 0.96; IWTH = 0.21; IWSPAN = ICD - ITR - 0.06

    inner_corners = [(-ICD, -ICD), (ICD, -ICD), (-ICD, ICD), (ICD, ICD)]

    # Grand keep (tall, two-stage: wide base + narrower upper)
    stone.append(T.box(KHW, KHW, KHH * 0.55, 0, 0, KHH * 0.55))            # base stage
    stone.append(T.box(KHW * 0.80, KHW * 0.80, KHH * 0.50, 0, 0, KHH * 1.30))  # upper stage
    KEEP_TOP = KHH * 2 * 0.925   # approximate keep overall top
    stone += _keep_merlons(KHW * 0.80, KEEP_TOP)
    roof.append(_cone4(KHW * 0.80 + 0.24, 1.80, 0, 0, KEEP_TOP + 0.90))
    _flag(stone, roof, 0, 0, KEEP_TOP + 1.80, h=0.88)
    # Extra side flags on the keep upper stage
    for fx, fy in [(-KHW * 0.60, 0), (KHW * 0.60, 0)]:
        _flag(stone, roof, fx, fy, KEEP_TOP + 1.80, h=0.52)

    for cx, cy in inner_corners:
        stone.append(T.cyl(ITR, ITH, cx, cy, ITH * 0.5))
        stone += _ring_merlons(7, ITR, ITH, cx=cx, cy=cy, offset_deg=25)
        roof.append(T.cone(ITR + 0.14, 1.50, cx, cy, ITH + 0.75, verts=8))
        _flag(stone, roof, cx, cy, ITH + 1.50, h=0.68)

    for wy in [-ICD, ICD]:
        stone.append(T.box(IWSPAN, IWTH, IWH * 0.5, 0, wy, IWH * 0.5))
        stone += _wall_crens(4, -IWSPAN * 0.76, IWSPAN * 0.76, wy, IWH)
    for wx in [-ICD, ICD]:
        stone.append(T.box(IWTH, IWSPAN, IWH * 0.5, wx, 0, IWH * 0.5))
        stone += _wall_crens_y(4, wx, -IWSPAN * 0.76, IWSPAN * 0.76, IWH)

    # Front gatehouse: a wide square tower straddling the south curtain (between middle and outer)
    GX = 0; GY = -(MCD + 0.45); GW = 0.38; GH = 1.28
    stone.append(T.box(GW, GW, GH * 0.5, GX, GY, GH * 0.5))
    stone += _ring_merlons(4, GW * 1.10, GH, cx=GX, cy=GY, offset_deg=45)
    roof.append(_cone4(GW + 0.16, 0.90, GX, GY, GH + 0.45))
    _flag(stone, roof, GX, GY, GH + 0.90, h=0.50)

    _bake(stone, roof, "castle_t6")


# ─── generate all 6 ──────────────────────────────────────────────────────────
gen_t1()
gen_t2()
gen_t3()
gen_t4()
gen_t5()
gen_t6()
print("ALL_CASTLES_DONE")
