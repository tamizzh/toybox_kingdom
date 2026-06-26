# gen_castle.py — 6 progressively grander toy castles, all sharing the
# classic multi-tower silhouette from the very first tier.
#
# Target aesthetic (target_art.png):
#   • Round towers (cylinders) topped with steep kingdom-coloured cones
#   • Cream stone walls + battlements between every tower pair
#   • Central keep taller than the curtain towers
#   • Even the smallest enemy castle reads unmistakably as a "castle"
#
# Tier progression:
#   T1 Mini Keep    — compact 4-turret courtyard, single low keep
#   T2 Small Castle — 4 round towers, proper curtain walls, taller keep
#   T3 Castle       — taller towers, deeper keep, corner merlons
#   T4 Grand Castle — large towers, wide keep, thick walls + gatehouse
#   T5 Fortress     — T4 inner ward + outer curtain ring with 4 towers
#   T6 Capital      — triple-ring palace, mid-wall towers, 3-stage keep
#
# Each GLB: "stone" node + "roof" node, found by castle.gd via find_child()
#
# Run:  blender --background --python tools/gen_castle.py
import bpy, sys, os, math

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T


# ─── shared geometry helpers ─────────────────────────────────────────────────

def cone_roof(r, h, x, y, z):
    """Steep conical roof atop a tower."""
    return T.cone(r + 0.10, h, x, y, z, verts=12)

def keep_pyramid(hw, h, x, y, z):
    """4-sided keep pyramid cap (rotated 45° to align with wall faces)."""
    o = T.cone(hw * 1.28, h, x, y, z, verts=4)
    o.rotation_euler[2] = math.radians(45)
    bpy.ops.object.transform_apply(rotation=True)
    return o

def ring_merlons(n, r, z_top, cx=0.0, cy=0.0):
    """n battlements around the parapet of a cylinder of radius r."""
    mr = max(r - 0.06, 0.08)
    out = []
    for i in range(n):
        a = math.radians(i * 360.0 / n)
        out.append(T.box(0.065, 0.065, 0.10,
                         cx + math.cos(a) * mr,
                         cy + math.sin(a) * mr,
                         z_top + 0.10))
    return out

def square_merlons(hw, z_top, n_per_side=2):
    """Battlements around all 4 sides of a square keep with half-width hw."""
    out = []
    for side in range(4):
        a = math.radians(side * 90)
        cos_a, sin_a = math.cos(a), math.sin(a)
        perp_x, perp_y = -sin_a, cos_a
        face_cx = cos_a * hw * 0.90
        face_cy = sin_a * hw * 0.90
        for k in range(n_per_side):
            t = (k + 0.5) / n_per_side - 0.5
            mx = face_cx + perp_x * t * hw * 1.50
            my = face_cy + perp_y * t * hw * 1.50
            out.append(T.box(0.07, 0.07, 0.10, mx, my, z_top + 0.10))
    return out

def wall_merlons(n, x0, x1, y, z_top):
    """n merlons along a wall running in X between x0 and x1."""
    out = []
    for k in range(n):
        t = (k + 0.5) / n
        out.append(T.box(0.065, 0.065, 0.10,
                         x0 + t * (x1 - x0), y, z_top + 0.10))
    return out

def wall_merlons_y(n, x, y0, y1, z_top):
    """n merlons along a wall running in Y between y0 and y1."""
    out = []
    for k in range(n):
        t = (k + 0.5) / n
        out.append(T.box(0.065, 0.065, 0.10,
                         x, y0 + t * (y1 - y0), z_top + 0.10))
    return out

def add_flag(stone, roof, x, y, z_base, h=0.50):
    stone.append(T.cyl(0.022, h, x, y, z_base + h * 0.5, 6))
    roof.append(T.box(0.11, 0.01, 0.065, x + 0.10, y, z_base + h * 0.76))

def _bake(stone, roof, name):
    sm = T.mat("stone", (0.52, 0.53, 0.58), rough=0.76)
    rm = T.mat("roof",  (0.72, 0.22, 0.18), rough=0.46)
    for o in stone: o.data.materials.append(sm)
    for o in roof:  o.data.materials.append(rm)
    so = T.join(stone, "stone");  T.bevel(so, width=0.028, segments=2)
    ro = T.join(roof,  "roof");   T.bevel(ro, width=0.028, segments=2)
    T.export(name)
    print(name.upper() + "_DONE")


# ─── T1: Mini Keep ────────────────────────────────────────────────────────────
# Compact 4-tower courtyard — reads instantly as a castle even at tiny scale.
def gen_t1():
    T.reset(); stone = []; roof = []
    CD = 0.70; TR = 0.26; TH = 1.10   # corner dist, tower radius/height
    KHW = 0.30; KHH = 0.62            # keep half-width / half-height
    WH = 0.56; WTH = 0.13

    stone.append(T.box(CD + TR + 0.12, CD + TR + 0.12, 0.07, 0, 0, 0.035))

    # Keep (central, taller than towers)
    stone.append(T.box(KHW, KHW, KHH, 0, 0, KHH))
    keep_top = KHH * 2
    stone += square_merlons(KHW, keep_top, n_per_side=1)
    roof.append(keep_pyramid(KHW, 0.80, 0, 0, keep_top + 0.40))
    add_flag(stone, roof, 0, 0, keep_top + 0.80, h=0.38)

    # 4 corner towers
    corners = [(-CD, -CD), (CD, -CD), (-CD, CD), (CD, CD)]
    for cx, cy in corners:
        stone.append(T.cyl(TR, TH, cx, cy, TH * 0.5))
        stone += ring_merlons(4, TR, TH, cx=cx, cy=cy)
        roof.append(cone_roof(TR, 0.72, cx, cy, TH + 0.36))
        add_flag(stone, roof, cx, cy, TH + 0.72, h=0.28)

    # Connecting walls
    WSPAN = CD - TR - 0.04
    for wy in [-CD, CD]:
        stone.append(T.box(WSPAN, WTH, WH * 0.5, 0, wy, WH * 0.5))
        stone += wall_merlons(2, -WSPAN * 0.70, WSPAN * 0.70, wy, WH)
    for wx in [-CD, CD]:
        stone.append(T.box(WTH, WSPAN, WH * 0.5, wx, 0, WH * 0.5))
        stone += wall_merlons_y(2, wx, -WSPAN * 0.70, WSPAN * 0.70, WH)

    _bake(stone, roof, "castle_t1")


# ─── T2: Small Castle ─────────────────────────────────────────────────────────
# 4 proper round towers, taller keep, front gate arch hint.
def gen_t2():
    T.reset(); stone = []; roof = []
    CD = 0.94; TR = 0.32; TH = 1.42
    KHW = 0.40; KHH = 0.86
    WH = 0.72; WTH = 0.16

    stone.append(T.box(CD + TR + 0.14, CD + TR + 0.14, 0.08, 0, 0, 0.04))

    # Keep
    stone.append(T.box(KHW, KHW, KHH, 0, 0, KHH))
    keep_top = KHH * 2
    stone += square_merlons(KHW, keep_top, n_per_side=2)
    roof.append(keep_pyramid(KHW, 1.00, 0, 0, keep_top + 0.50))
    add_flag(stone, roof, 0, 0, keep_top + 1.00, h=0.44)

    corners = [(-CD, -CD), (CD, -CD), (-CD, CD), (CD, CD)]
    for cx, cy in corners:
        stone.append(T.cyl(TR, TH, cx, cy, TH * 0.5))
        stone += ring_merlons(5, TR, TH, cx=cx, cy=cy)
        roof.append(cone_roof(TR, 0.88, cx, cy, TH + 0.44))
        add_flag(stone, roof, cx, cy, TH + 0.88, h=0.36)

    WSPAN = CD - TR - 0.05
    for wy in [-CD, CD]:
        stone.append(T.box(WSPAN, WTH, WH * 0.5, 0, wy, WH * 0.5))
        stone += wall_merlons(3, -WSPAN * 0.72, WSPAN * 0.72, wy, WH)
    for wx in [-CD, CD]:
        stone.append(T.box(WTH, WSPAN, WH * 0.5, wx, 0, WH * 0.5))
        stone += wall_merlons_y(3, wx, -WSPAN * 0.72, WSPAN * 0.72, WH)

    # Gate hint: two short pilasters on the south wall
    for gx in [-0.22, 0.22]:
        stone.append(T.box(0.08, 0.18, WH * 0.44, gx, -CD, WH * 0.44))

    _bake(stone, roof, "castle_t2")


# ─── T3: Castle ───────────────────────────────────────────────────────────────
# The iconic mid-range read: 4 tall round towers, imposing keep, deep merlons.
def gen_t3():
    T.reset(); stone = []; roof = []
    CD = 1.18; TR = 0.38; TH = 1.78
    KHW = 0.52; KHH = 1.12
    WH = 0.84; WTH = 0.19

    stone.append(T.box(CD + TR + 0.16, CD + TR + 0.16, 0.09, 0, 0, 0.045))

    # Two-stage keep
    stone.append(T.box(KHW, KHW, KHH * 0.60, 0, 0, KHH * 0.60))
    stone.append(T.box(KHW * 0.82, KHW * 0.82, KHH * 0.45, 0, 0, KHH * 1.30))
    keep_top = KHH * 1.95
    stone += square_merlons(KHW * 0.82, keep_top, n_per_side=2)
    roof.append(keep_pyramid(KHW * 0.82, 1.20, 0, 0, keep_top + 0.60))
    add_flag(stone, roof, 0, 0, keep_top + 1.20, h=0.52)

    corners = [(-CD, -CD), (CD, -CD), (-CD, CD), (CD, CD)]
    for cx, cy in corners:
        stone.append(T.cyl(TR, TH, cx, cy, TH * 0.5))
        stone += ring_merlons(6, TR, TH, cx=cx, cy=cy)
        roof.append(cone_roof(TR, 1.05, cx, cy, TH + 0.525))
        add_flag(stone, roof, cx, cy, TH + 1.05, h=0.44)

    WSPAN = CD - TR - 0.06
    for wy in [-CD, CD]:
        stone.append(T.box(WSPAN, WTH, WH * 0.5, 0, wy, WH * 0.5))
        stone += wall_merlons(3, -WSPAN * 0.74, WSPAN * 0.74, wy, WH)
    for wx in [-CD, CD]:
        stone.append(T.box(WTH, WSPAN, WH * 0.5, wx, 0, WH * 0.5))
        stone += wall_merlons_y(3, wx, -WSPAN * 0.74, WSPAN * 0.74, WH)

    # Gatehouse pilasters
    for gx in [-0.30, 0.30]:
        stone.append(T.box(0.10, 0.20, WH * 0.55, gx, -CD, WH * 0.55))

    _bake(stone, roof, "castle_t3")


# ─── T4: Grand Castle ─────────────────────────────────────────────────────────
# Like the blue kingdom in simple_target.png: large round towers, grand keep,
# prominent gatehouse tower on the south face.
def gen_t4():
    T.reset(); stone = []; roof = []
    CD = 1.42; TR = 0.44; TH = 2.10
    KHW = 0.64; KHH = 1.40
    WH = 0.90; WTH = 0.21

    stone.append(T.box(CD + TR + 0.18, CD + TR + 0.18, 0.10, 0, 0, 0.05))

    # Three-stage keep
    stone.append(T.box(KHW, KHW, KHH * 0.45, 0, 0, KHH * 0.45))
    stone.append(T.box(KHW * 0.86, KHW * 0.86, KHH * 0.40, 0, 0, KHH * 1.05))
    stone.append(T.box(KHW * 0.72, KHW * 0.72, KHH * 0.22, 0, 0, KHH * 1.70))
    keep_top = KHH * 1.92
    stone += square_merlons(KHW * 0.72, keep_top, n_per_side=2)
    roof.append(keep_pyramid(KHW * 0.72, 1.40, 0, 0, keep_top + 0.70))
    add_flag(stone, roof, 0, 0, keep_top + 1.40, h=0.62)
    for fx, fy in [(-KHW * 0.56, 0), (KHW * 0.56, 0), (0, -KHW * 0.56), (0, KHW * 0.56)]:
        add_flag(stone, roof, fx, fy, keep_top + 1.40, h=0.36)

    corners = [(-CD, -CD), (CD, -CD), (-CD, CD), (CD, CD)]
    for cx, cy in corners:
        stone.append(T.cyl(TR, TH, cx, cy, TH * 0.5))
        stone += ring_merlons(7, TR, TH, cx=cx, cy=cy)
        roof.append(cone_roof(TR, 1.22, cx, cy, TH + 0.61))
        add_flag(stone, roof, cx, cy, TH + 1.22, h=0.54)

    WSPAN = CD - TR - 0.06
    for wy in [-CD, CD]:
        stone.append(T.box(WSPAN, WTH, WH * 0.5, 0, wy, WH * 0.5))
        stone += wall_merlons(4, -WSPAN * 0.76, WSPAN * 0.76, wy, WH)
    for wx in [-CD, CD]:
        stone.append(T.box(WTH, WSPAN, WH * 0.5, wx, 0, WH * 0.5))
        stone += wall_merlons_y(4, wx, -WSPAN * 0.76, WSPAN * 0.76, WH)

    # Prominent gatehouse on the south face
    GR = 0.28; GH = 1.30
    stone.append(T.box(GR, GR, GH * 0.5, 0, -CD, GH * 0.5))
    stone += square_merlons(GR, GH, n_per_side=1)
    roof.append(keep_pyramid(GR, 0.72, 0, -CD, GH + 0.36))
    add_flag(stone, roof, 0, -CD, GH + 0.72, h=0.38)

    _bake(stone, roof, "castle_t4")


# ─── T5: Fortress ─────────────────────────────────────────────────────────────
# Grand inner ward (T4 quality) ringed by a full outer curtain wall + 4 towers.
def gen_t5():
    T.reset(); stone = []; roof = []

    # ── INNER WARD ────────────────────────────────────────────────────────────
    ICD = 1.34; ITR = 0.46; ITH = 2.28
    KHW = 0.68; KHH = 1.54
    IWH = 0.92; IWTH = 0.22

    stone.append(T.box(KHW, KHW, KHH * 0.45, 0, 0, KHH * 0.45))
    stone.append(T.box(KHW * 0.84, KHW * 0.84, KHH * 0.40, 0, 0, KHH * 1.05))
    stone.append(T.box(KHW * 0.70, KHW * 0.70, KHH * 0.24, 0, 0, KHH * 1.70))
    keep_top = KHH * 1.94
    stone += square_merlons(KHW * 0.70, keep_top, n_per_side=2)
    roof.append(keep_pyramid(KHW * 0.70, 1.52, 0, 0, keep_top + 0.76))
    add_flag(stone, roof, 0, 0, keep_top + 1.52, h=0.70)
    for fx, fy in [(-KHW * 0.54, 0), (KHW * 0.54, 0)]:
        add_flag(stone, roof, fx, fy, keep_top + 1.52, h=0.40)

    inner_corners = [(-ICD, -ICD), (ICD, -ICD), (-ICD, ICD), (ICD, ICD)]
    for cx, cy in inner_corners:
        stone.append(T.cyl(ITR, ITH, cx, cy, ITH * 0.5))
        stone += ring_merlons(7, ITR, ITH, cx=cx, cy=cy)
        roof.append(cone_roof(ITR, 1.30, cx, cy, ITH + 0.65))
        add_flag(stone, roof, cx, cy, ITH + 1.30, h=0.56)

    IWSPAN = ICD - ITR - 0.06
    for wy in [-ICD, ICD]:
        stone.append(T.box(IWSPAN, IWTH, IWH * 0.5, 0, wy, IWH * 0.5))
        stone += wall_merlons(4, -IWSPAN * 0.76, IWSPAN * 0.76, wy, IWH)
    for wx in [-ICD, ICD]:
        stone.append(T.box(IWTH, IWSPAN, IWH * 0.5, wx, 0, IWH * 0.5))
        stone += wall_merlons_y(4, wx, -IWSPAN * 0.76, IWSPAN * 0.76, IWH)

    # Inner gatehouse
    GR = 0.30; GH = 1.40
    stone.append(T.box(GR, GR, GH * 0.5, 0, -ICD, GH * 0.5))
    stone += square_merlons(GR, GH, n_per_side=1)
    roof.append(keep_pyramid(GR, 0.78, 0, -ICD, GH + 0.39))
    add_flag(stone, roof, 0, -ICD, GH + 0.78, h=0.40)

    # ── OUTER CURTAIN ─────────────────────────────────────────────────────────
    OCD = 1.92; OTR = 0.28; OTH = 1.14
    OWH = 0.72; OWTH = 0.17

    stone.append(T.box(OCD + OTR + 0.16, OCD + OTR + 0.16, 0.10, 0, 0, 0.05))

    outer_corners = [(-OCD, -OCD), (OCD, -OCD), (-OCD, OCD), (OCD, OCD)]
    for cx, cy in outer_corners:
        stone.append(T.cyl(OTR, OTH, cx, cy, OTH * 0.5))
        stone += ring_merlons(4, OTR, OTH, cx=cx, cy=cy)
        roof.append(cone_roof(OTR, 0.80, cx, cy, OTH + 0.40))
        add_flag(stone, roof, cx, cy, OTH + 0.80, h=0.36)

    OWSPAN = OCD - OTR - 0.06
    for wy in [-OCD, OCD]:
        stone.append(T.box(OWSPAN, OWTH, OWH * 0.5, 0, wy, OWH * 0.5))
        stone += wall_merlons(4, -OWSPAN * 0.76, OWSPAN * 0.76, wy, OWH)
    for wx in [-OCD, OCD]:
        stone.append(T.box(OWTH, OWSPAN, OWH * 0.5, wx, 0, OWH * 0.5))
        stone += wall_merlons_y(4, wx, -OWSPAN * 0.76, OWSPAN * 0.76, OWH)

    _bake(stone, roof, "castle_t5")


# ─── T6: Capital ──────────────────────────────────────────────────────────────
# Triple-ring grand palace: inner palace + middle ward + outer curtain.
def gen_t6():
    T.reset(); stone = []; roof = []

    stone.append(T.box(2.40, 2.40, 0.10, 0, 0, 0.05))

    # ── OUTER CURTAIN ─────────────────────────────────────────────────────────
    OCD = 2.08; OTR = 0.25; OTH = 1.06
    OMID_R = 0.20; OMID_H = 0.94
    OWH = 0.68; OWTH = 0.16; OWSPAN = OCD - OTR - 0.06

    outer_corners = [(-OCD, -OCD), (OCD, -OCD), (-OCD, OCD), (OCD, OCD)]
    for cx, cy in outer_corners:
        stone.append(T.cyl(OTR, OTH, cx, cy, OTH * 0.5))
        stone += ring_merlons(4, OTR, OTH, cx=cx, cy=cy)
        roof.append(cone_roof(OTR, 0.74, cx, cy, OTH + 0.37))
        add_flag(stone, roof, cx, cy, OTH + 0.74, h=0.32)

    for mx, my in [(0, -OCD), (0, OCD), (-OCD, 0), (OCD, 0)]:
        stone.append(T.cyl(OMID_R, OMID_H, mx, my, OMID_H * 0.5))
        stone += ring_merlons(4, OMID_R, OMID_H, cx=mx, cy=my)
        roof.append(cone_roof(OMID_R, 0.66, mx, my, OMID_H + 0.33))

    for wy in [-OCD, OCD]:
        stone.append(T.box(OWSPAN, OWTH, OWH * 0.5, 0, wy, OWH * 0.5))
        stone += wall_merlons(4, -OWSPAN * 0.78, OWSPAN * 0.78, wy, OWH)
    for wx in [-OCD, OCD]:
        stone.append(T.box(OWTH, OWSPAN, OWH * 0.5, wx, 0, OWH * 0.5))
        stone += wall_merlons_y(4, wx, -OWSPAN * 0.78, OWSPAN * 0.78, OWH)

    # ── MIDDLE WARD ───────────────────────────────────────────────────────────
    MCD = 1.54; MTR = 0.36; MTH = 1.60
    MMID_R = 0.26; MMID_H = 1.42
    MWH = 0.86; MWTH = 0.19; MWSPAN = MCD - MTR - 0.06

    middle_corners = [(-MCD, -MCD), (MCD, -MCD), (-MCD, MCD), (MCD, MCD)]
    for cx, cy in middle_corners:
        stone.append(T.cyl(MTR, MTH, cx, cy, MTH * 0.5))
        stone += ring_merlons(6, MTR, MTH, cx=cx, cy=cy)
        roof.append(cone_roof(MTR, 1.00, cx, cy, MTH + 0.50))
        add_flag(stone, roof, cx, cy, MTH + 1.00, h=0.48)

    for mx, my in [(0, -MCD), (0, MCD), (-MCD, 0), (MCD, 0)]:
        stone.append(T.cyl(MMID_R, MMID_H, mx, my, MMID_H * 0.5))
        stone += ring_merlons(5, MMID_R, MMID_H, cx=mx, cy=my)
        roof.append(cone_roof(MMID_R, 0.88, mx, my, MMID_H + 0.44))
        add_flag(stone, roof, mx, my, MMID_H + 0.88, h=0.36)

    for wy in [-MCD, MCD]:
        stone.append(T.box(MWSPAN, MWTH, MWH * 0.5, 0, wy, MWH * 0.5))
        stone += wall_merlons(4, -MWSPAN * 0.76, MWSPAN * 0.76, wy, MWH)
    for wx in [-MCD, MCD]:
        stone.append(T.box(MWTH, MWSPAN, MWH * 0.5, wx, 0, MWH * 0.5))
        stone += wall_merlons_y(4, wx, -MWSPAN * 0.76, MWSPAN * 0.76, MWH)

    # ── INNER PALACE ──────────────────────────────────────────────────────────
    ICD = 1.06; ITR = 0.48; ITH = 2.48
    KHW = 0.72; KHH = 1.78
    IWH = 0.96; IWTH = 0.22; IWSPAN = ICD - ITR - 0.06

    inner_corners = [(-ICD, -ICD), (ICD, -ICD), (-ICD, ICD), (ICD, ICD)]
    for cx, cy in inner_corners:
        stone.append(T.cyl(ITR, ITH, cx, cy, ITH * 0.5))
        stone += ring_merlons(8, ITR, ITH, cx=cx, cy=cy)
        roof.append(cone_roof(ITR, 1.44, cx, cy, ITH + 0.72))
        add_flag(stone, roof, cx, cy, ITH + 1.44, h=0.64)

    for wy in [-ICD, ICD]:
        stone.append(T.box(IWSPAN, IWTH, IWH * 0.5, 0, wy, IWH * 0.5))
        stone += wall_merlons(4, -IWSPAN * 0.76, IWSPAN * 0.76, wy, IWH)
    for wx in [-ICD, ICD]:
        stone.append(T.box(IWTH, IWSPAN, IWH * 0.5, wx, 0, IWH * 0.5))
        stone += wall_merlons_y(4, wx, -IWSPAN * 0.76, IWSPAN * 0.76, IWH)

    # 4-stage palace keep
    stone.append(T.box(KHW, KHW, KHH * 0.35, 0, 0, KHH * 0.35))
    stone.append(T.box(KHW * 0.82, KHW * 0.82, KHH * 0.32, 0, 0, KHH * 0.90))
    stone.append(T.box(KHW * 0.65, KHW * 0.65, KHH * 0.28, 0, 0, KHH * 1.42))
    stone.append(T.box(KHW * 0.50, KHW * 0.50, KHH * 0.16, 0, 0, KHH * 1.86))
    keep_top = KHH * 2.02
    stone += square_merlons(KHW * 0.50, keep_top, n_per_side=2)
    roof.append(keep_pyramid(KHW * 0.50, 1.76, 0, 0, keep_top + 0.88))
    add_flag(stone, roof, 0, 0, keep_top + 1.76, h=0.90)
    for fx, fy in [(-KHW * 0.46, 0), (KHW * 0.46, 0), (0, -KHW * 0.46), (0, KHW * 0.46)]:
        add_flag(stone, roof, fx, fy, keep_top + 1.76, h=0.52)

    # Grand gatehouse
    GR = 0.32; GH = 1.50; GX = 0; GY = -(MCD + 0.30)
    stone.append(T.box(GR, GR, GH * 0.5, GX, GY, GH * 0.5))
    stone += square_merlons(GR, GH, n_per_side=1)
    roof.append(keep_pyramid(GR, 0.84, GX, GY, GH + 0.42))
    add_flag(stone, roof, GX, GY, GH + 0.84, h=0.42)

    _bake(stone, roof, "castle_t6")


# ─── generate all 6 ──────────────────────────────────────────────────────────
gen_t1()
gen_t2()
gen_t3()
gen_t4()
gen_t5()
gen_t6()
print("ALL_CASTLES_DONE")
