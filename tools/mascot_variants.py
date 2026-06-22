"""
tools/mascot_variants.py — generate CUTE blob mascot OPTIONS and render a
contact sheet so we can pick one before committing it to players/mascot.glb.

Builds 5 variants in a row (along +Y) and renders one wide image:
    tools/_mascot_preview/mascot_options.png

Each variant keeps the in-game constraints:
    +X = face/forward, +Z = up, body bottom at Z=0, white-tintable body.
For the PREVIEW only, the body is tinted soft periwinkle so the form reads
(in-game it stays white and is team-recoloured by the vinyl_toy shader).

Run:
    blender --background --python tools/mascot_variants.py
"""
import bpy, math, os

# ─────────────────────────── scene reset ────────────────────────────────────
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
for col in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
            bpy.data.cameras, bpy.data.lights, bpy.data.objects):
    for item in list(col):
        try: col.remove(item)
        except Exception: pass

# ─────────────────────────── materials ──────────────────────────────────────
def mat(name, r, g, b, rough=0.5, metallic=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.new(name); m.use_fake_user = True; m.use_nodes = True
    b_ = m.node_tree.nodes["Principled BSDF"]
    b_.inputs["Base Color"].default_value = (r, g, b, 1.0)
    b_.inputs["Roughness"].default_value = rough
    b_.inputs["Metallic"].default_value = metallic
    if emit > 0:
        b_.inputs["Emission Color"].default_value = (r, g, b, 1.0)
        b_.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b_.inputs["Alpha"].default_value = alpha; m.blend_method = "BLEND"
    return m

BODY  = mat("body",      0.36, 0.54, 0.93, rough=0.42)   # preview periwinkle
WHITE = mat("eye_white", 1.00, 1.00, 1.00, rough=0.07)
DARK  = mat("pupil",     0.05, 0.04, 0.10, rough=0.18)
SHINE = mat("shine",     1.00, 1.00, 1.00, rough=0.02, metallic=0.2)
CHEEK = mat("cheek",     1.00, 0.46, 0.55, rough=0.85, alpha=0.65)
LEAF  = mat("leaf",      0.42, 0.78, 0.36, rough=0.45)
STEM  = mat("stem",      0.55, 0.42, 0.28, rough=0.6)

# ─────────────────────────── primitives ─────────────────────────────────────
def smooth(o):
    for p in o.data.polygons: p.use_smooth = True

def ball(name, loc, r, sx=1.0, sy=1.0, sz=1.0, m=BODY, segs=32, rings=22, subsurf=0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segs, ring_count=rings, location=loc)
    o = bpy.context.active_object; o.name = name
    if (sx, sy, sz) != (1, 1, 1):
        o.scale = (sx, sy, sz); bpy.ops.object.transform_apply(scale=True)
    smooth(o)
    if subsurf:
        s = o.modifiers.new("s", "SUBSURF"); s.levels = subsurf
        bpy.ops.object.modifier_apply(modifier="s")
    o.data.materials.clear(); o.data.materials.append(m)
    return o

def cone(name, loc, r1, r2, depth, m=BODY, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=depth, location=loc)
    o = bpy.context.active_object; o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(rotation=True)
    smooth(o)
    o.data.materials.clear(); o.data.materials.append(m)
    return o

def arc(name, cy, cz, half_w, sag, xf, bevel, m, n=26, smile=True):
    """Bevelled poly arc on the +X face. smile=True → U (valley at centre)."""
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"
    cu.bevel_depth = bevel; cu.bevel_resolution = 4
    sp = cu.splines.new("POLY"); sp.points.add(n - 1)
    for i in range(n):
        t = i / (n - 1) * 2 - 1            # -1..1
        y = cy + t * half_w
        if smile:                           # valley at centre, ends up
            z = cz + sag * (t * t)
        else:                               # arch (^) peak at centre
            z = cz + sag * (1 - t * t)
        sp.points[i].co = (xf, y, z, 1.0)
    o = bpy.data.objects.new(name, cu); bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    return o

# parts that should sit just proud of an ellipsoid front face
def front_x(y, z, cz, rx, ry, rz, eps=0.02):
    k = 1 - (y / ry) ** 2 - ((z - cz) / rz) ** 2
    return rx * math.sqrt(max(0.04, k)) + eps

def eyes(yoff, cz, rx, ry, rz, ew_r, sep, ez, gaze_dn=0.04, sparkle=False, m_scale=1.0):
    """Big glossy googly eyes on +X face. yoff shifts whole rig along Y (row layout)."""
    out = []
    for tag, s in (("l", -1), ("r", 1)):
        ey = s * sep
        xw = front_x(ey, ez, cz, rx, ry, rz, eps=-0.05)     # whites sink into body a touch
        w = ball(f"eye_white_{tag}", (xw, yoff + ey, ez), ew_r, m=WHITE, segs=20, rings=16)
        xp = xw + ew_r * 0.85
        p = ball(f"pupil_{tag}", (xp, yoff + ey, ez - gaze_dn), ew_r * 0.52, m=DARK, segs=16, rings=12)
        sh = ball(f"shine_{tag}", (xp + ew_r * 0.30, yoff + ey - ew_r * 0.28, ez + ew_r * 0.30),
                  ew_r * 0.20, m=SHINE, segs=10, rings=8)
        out += [w, p, sh]
        if sparkle:
            out.append(ball(f"shine2_{tag}", (xp + ew_r * 0.30, yoff + ey + ew_r * 0.18, ez - ew_r * 0.22),
                            ew_r * 0.10, m=SHINE, segs=8, rings=6))
    return out

def cheeks(yoff, cz, rx, ry, rz, cy_sep, cz_h, r=0.16):
    out = []
    for s in (-1, 1):
        y = s * cy_sep
        x = front_x(y, cz_h, cz, rx, ry, rz, eps=0.0)
        out.append(ball(f"cheek_{'l' if s<0 else 'r'}", (x, yoff + y, cz_h), r, sx=0.12, m=CHEEK, segs=16, rings=10))
    return out

def feet(yoff, sep=0.17, fx=0.18, fz=0.07, r=0.17):
    return [ball(f"foot_{'l' if s<0 else 'r'}", (fx, yoff + s*sep, fz), r, sx=0.95, sy=0.85, sz=0.55, m=BODY, segs=14, rings=10)
            for s in (-1, 1)]

# ─────────────────────────── variants ───────────────────────────────────────
# Each returns nothing; just spawns its parts at the given row offset (along Y).

def v_chonk(y):   # 1: extra-round chubby, huge close eyes, big blush, lil smile
    cz, r = 0.74, 0.82
    ball("c_body", (0, y, cz), r, sz=0.95, m=BODY, segs=44, rings=30)
    rx = ry = r; rz = r * 0.95
    eyes(y, cz, rx, ry, rz, 0.26, 0.235, cz + 0.18, gaze_dn=0.05)
    cheeks(y, cz, rx, ry, rz, 0.42, cz - 0.12, r=0.18)
    arc("c_smile", y, cz - 0.04, 0.16, 0.10, front_x(0, cz-0.04, cz, rx, ry, rz, 0.01), 0.028, DARK, smile=True)
    feet(y, sep=0.2)

def v_bean(y):    # 2: taller rounded bean, eyes high & close, soft smile, feet
    cz, r = 0.88, 0.62
    ball("b_body", (0, y, cz), r, sz=1.30, m=BODY, segs=44, rings=32)
    rx = ry = r; rz = r * 1.30
    eyes(y, cz, rx, ry, rz, 0.165, 0.165, cz + 0.34, gaze_dn=0.03)
    cheeks(y, cz, rx, ry, rz, 0.30, cz + 0.06, r=0.12)
    arc("b_smile", y, cz + 0.18, 0.11, 0.07, front_x(0, cz+0.18, cz, rx, ry, rz, 0.01), 0.022, DARK, smile=True)
    feet(y, sep=0.15, r=0.14)

def v_sleepy(y):  # 3: wide squashed dumpling, happy closed (^_^) eyes, big blush
    cz, r = 0.62, 0.92
    ball("s_body", (0, y, cz), r, sz=0.78, m=BODY, segs=44, rings=30)
    rx = ry = r; rz = r * 0.78
    ez = cz + 0.16
    for s in (-1, 1):
        ey = s * 0.30
        xf = front_x(ey, ez, cz, rx, ry, rz, 0.01)
        arc(f"s_eye_{'l' if s<0 else 'r'}", y + ey, ez, 0.13, 0.10, xf, 0.026, DARK, smile=False)
    cheeks(y, cz, rx, ry, rz, 0.50, cz - 0.06, r=0.20)
    arc("s_smile", y, cz - 0.10, 0.12, 0.06, front_x(0, cz-0.10, cz, rx, ry, rz, 0.01), 0.022, DARK, smile=True)

def v_sprout(y):  # 4: round body + leaf sprout on top, sparkly eyes, open smile
    cz, r = 0.74, 0.74
    ball("p_body", (0, y, cz), r, sz=1.02, m=BODY, segs=44, rings=30)
    rx = ry = r; rz = r * 1.02
    eyes(y, cz, rx, ry, rz, 0.20, 0.205, cz + 0.22, gaze_dn=0.03, sparkle=True)
    cheeks(y, cz, rx, ry, rz, 0.40, cz - 0.04, r=0.15)
    # open "o" smile = small dark flattened ball
    xs = front_x(0, cz - 0.06, cz, rx, ry, rz, 0.0)
    ball("p_mouth_pupil", (xs, y, cz - 0.06), 0.075, sx=0.5, sy=0.9, sz=0.7, m=DARK, segs=14, rings=10)
    # stem + leaves on top
    top = cz + rz
    cone("p_stem", (0, y, top + 0.10), 0.045, 0.03, 0.22, m=STEM)
    ball("p_leaf_l", (0, y - 0.10, top + 0.22), 0.12, sx=0.4, sy=1.0, sz=0.6, m=LEAF, segs=14, rings=10)
    ball("p_leaf_r", (0, y + 0.10, top + 0.22), 0.12, sx=0.4, sy=1.0, sz=0.6, m=LEAF, segs=14, rings=10)

def v_cat(y):     # 5: round body + kitty ears, big eyes, :3 mouth, paw feet
    cz, r = 0.72, 0.78
    ball("k_body", (0, y, cz), r, sz=1.00, m=BODY, segs=44, rings=30)
    rx = ry = r; rz = r
    eyes(y, cz, rx, ry, rz, 0.21, 0.205, cz + 0.16, gaze_dn=0.04)
    cheeks(y, cz, rx, ry, rz, 0.42, cz - 0.10, r=0.16)
    # :3 mouth — two little smile arcs meeting at centre
    zc = cz - 0.10
    xf = front_x(0.0, zc, cz, rx, ry, rz, 0.01)
    arc("k_m_l", y - 0.07, zc, 0.07, 0.05, xf, 0.02, DARK, smile=True)
    arc("k_m_r", y + 0.07, zc, 0.07, 0.05, xf, 0.02, DARK, smile=True)
    # ears — flattened cones on top, tilted outward
    top = cz + rz
    cone("k_ear_l", (0, y - 0.34, top - 0.02), 0.20, 0.0, 0.34, m=BODY, rot=(-0.5, 0, 0))
    cone("k_ear_r", (0, y + 0.34, top - 0.02), 0.20, 0.0, 0.34, m=BODY, rot=(0.5, 0, 0))
    feet(y, sep=0.18)

VARIANTS = [v_chonk, v_bean, v_sleepy, v_sprout, v_cat]
SPACING = 3.0
y0 = -(len(VARIANTS) - 1) / 2 * SPACING
for i, fn in enumerate(VARIANTS):
    fn(y0 + i * SPACING)

# ─────────────────────────── lighting / world ───────────────────────────────
world = bpy.data.worlds.new("w"); bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.74, 0.80, 0.90, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9

def light(kind, loc, energy, rot=(0, 0, 0), size=5.0, color=(1, 1, 1)):
    d = bpy.data.lights.new("L", kind); d.energy = energy; d.color = color
    if kind == "AREA": d.size = size
    o = bpy.data.objects.new("L", d); o.location = loc; o.rotation_euler = rot
    bpy.context.collection.objects.link(o); return o

light("AREA", (8, -4, 9), 1300, rot=(math.radians(-35), math.radians(20), 0), size=12, color=(1.0, 0.97, 0.92))
light("AREA", (6, 6, 5), 550, rot=(math.radians(-25), math.radians(-30), 0), size=10, color=(0.85, 0.92, 1.0))
light("SUN",  (0, 0, 10), 0.5, rot=(math.radians(-20), math.radians(10), 0))

# ground plane (soft) for contact shadows
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.001))
gp = bpy.context.active_object
gp.data.materials.append(mat("ground", 0.80, 0.85, 0.93, rough=0.9))

# ─────────────────────────── camera (ortho, symmetric 3/4) ──────────────────
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = 14.2
cam = bpy.data.objects.new("cam", cam_d)
cam.location = (11, 0, 5.4)
bpy.context.collection.objects.link(cam)
tgt = bpy.data.objects.new("tgt", None); tgt.location = (0, 0, 0.85)
bpy.context.collection.objects.link(tgt)
c = cam.constraints.new("TRACK_TO"); c.target = tgt
c.track_axis = "TRACK_NEGATIVE_Z"; c.up_axis = "UP_Y"
bpy.context.scene.camera = cam

# ─────────────────────────── render ─────────────────────────────────────────
sc = bpy.context.scene
try: sc.render.engine = "BLENDER_EEVEE_NEXT"
except Exception:
    try: sc.render.engine = "BLENDER_EEVEE"
    except Exception: pass
try: sc.eevee.taa_render_samples = 32
except Exception: pass
sc.render.resolution_x = 2600
sc.render.resolution_y = 720
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
sc.view_settings.exposure = -0.3

here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
outdir = os.path.join(here, "_mascot_preview")
os.makedirs(outdir, exist_ok=True)
sc.render.filepath = os.path.join(outdir, "mascot_options.png")
bpy.ops.render.render(write_still=True)
print(f"RENDER_OK: {sc.render.filepath}")
