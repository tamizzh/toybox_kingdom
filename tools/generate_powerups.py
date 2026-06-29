"""
Generate 3D power-up models for Toybox Kingdoms.
Run via: blender --background --python tools/generate_powerups.py

Outputs 6 GLB files to assets/powerups/:
  pu_speed.glb   — rocket arrow (thick arrow + 3 speed streaks, pointing upper-right)
  pu_ghost.glb   — cyan shield/dome
  pu_bomb.glb    — red spiky ball (sphere + 6 axis spikes)
  pu_clear.glb   — white/silver diamond gem
  pu_freeze.glb  — ice-blue snowflake (6-arm cross)
  pu_magnet.glb  — purple horseshoe torus
"""

import bpy
import bmesh
import math
import mathutils
import os

TAU = math.pi * 2
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "assets", "powerups")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── helpers ───────────────────────────────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for blk in [bpy.data.meshes, bpy.data.materials, bpy.data.objects]:
        for item in list(blk):
            try:
                blk.remove(item)
            except Exception:
                pass

def smooth_shade(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True

def make_material(name, rgb, emission_strength=5.0):
    """Single Principled BSDF with emission — exports as KHR_materials_emissive_strength
    which Godot 4 reads correctly on Mobile/Forward+ renderers."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out  = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')

    r, g, b = rgb
    bsdf.inputs['Base Color'].default_value = (r, g, b, 1.0)
    bsdf.inputs['Metallic'].default_value   = 0.55
    bsdf.inputs['Roughness'].default_value  = 0.15
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 1.0
    # Emission baked into the BSDF node exports via KHR_materials_emissive_strength
    if 'Emission Color' in bsdf.inputs:
        bsdf.inputs['Emission Color'].default_value    = (r, g, b, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emission_strength
    elif 'Emission' in bsdf.inputs:   # older Blender naming
        bsdf.inputs['Emission'].default_value          = (r, g, b, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emission_strength

    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat

def assign_mat(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)

def export_glb(obj, filename):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )
    print(f"POWERUP_SAVED: {path}")

def link(obj):
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return obj

# ── shape builders ────────────────────────────────────────────────────────────

def _extrude_profile(bm, profile_xy, depth):
    """
    Given a list of (x, y) 2D points (convex or simple polygon),
    build a front cap, back cap, and side wall quad-strip.
    Returns (front_verts, back_verts).
    """
    d = depth / 2.0
    fv = [bm.verts.new((x, y,  d)) for x, y in profile_xy]
    bv = [bm.verts.new((x, y, -d)) for x, y in profile_xy]
    bm.faces.new(fv)
    bm.faces.new(list(reversed(bv)))
    n = len(fv)
    for i in range(n):
        ni = (i + 1) % n
        bm.faces.new([fv[i], bv[i], bv[ni], fv[ni]])
    return fv, bv


def build_rocket_arrow(depth=0.10):
    """
    Gold rocket arrow pointing upper-right — Speed.

    Shape (in local +Y = up space, before 45° rotation):
      ┌ arrowhead triangle (wide tip)
      │ shaft (narrow rectangle)
      └ 3 speed-streak bars fanning out left of the tail

    After baking a −45° Z-rotation the arrow points upper-right,
    identical to the game's existing boost.png HUD icon.
    """
    bm = bmesh.new()

    # ── arrow geometry (pointing +Y) ──────────────────────────────────────
    shaft_w   = 0.11   # half-width of the shaft
    shaft_h   = 0.24   # height of the shaft
    head_half = 0.22   # half-width of the arrowhead base
    head_h    = 0.22   # height of the arrowhead triangle
    total_h   = shaft_h + head_h   # 0.46

    # Centre the shape vertically so it pivots cleanly
    cy = total_h / 2.0

    arrow_profile = [
        ( 0,           total_h - cy),   # tip
        ( head_half,   shaft_h  - cy),  # head right shoulder
        ( shaft_w,     shaft_h  - cy),  # shaft top-right
        ( shaft_w,    -cy),             # shaft bottom-right
        (-shaft_w,    -cy),             # shaft bottom-left
        (-shaft_w,     shaft_h  - cy),  # shaft top-left
        (-head_half,   shaft_h  - cy),  # head left shoulder
    ]
    _extrude_profile(bm, arrow_profile, depth)

    # ── 3 speed-streak bars ───────────────────────────────────────────────
    # Bars run parallel to the arrow (vertical in local space), offset to
    # the left of the shaft.  They're shorter and thinner than the shaft.
    streak_configs = [
        # (x_centre,  y_centre,  half_len,  half_w)
        (-0.20,  -cy + 0.18,  0.11,  0.03),   # nearest, longest
        (-0.28,  -cy + 0.12,  0.08,  0.03),   # middle
        (-0.36,  -cy + 0.07,  0.05,  0.03),   # furthest, shortest
    ]
    for sx, sy, hl, hw in streak_configs:
        streak = [
            ( sx - hw,  sy - hl),
            ( sx + hw,  sy - hl),
            ( sx + hw,  sy + hl),
            ( sx - hw,  sy + hl),
        ]
        _extrude_profile(bm, streak, depth * 0.7)

    bm.normal_update()
    mesh = bpy.data.meshes.new("rocket_arrow")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("pu_speed", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj

    # Rotate −45° around Z so the arrow points upper-right (NE), then bake
    # the rotation into the mesh so the GLB has no transform.
    obj.rotation_euler = (0.0, 0.0, math.radians(-45))
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    return obj


def build_shield(r=0.34, depth=0.10, sides=16):
    """Cyan shield dome — Ghost"""
    bm = bmesh.new()
    # Build a shield profile: semicircle top, V-bottom
    # top arc: 180 degrees of a circle, then two diagonal lines meeting at bottom point
    arc_pts_top = []
    arc_pts_bot = []
    half = sides // 2
    for i in range(half + 1):
        angle = math.pi * i / half   # 0 → π (right → left across top)
        x = r * math.cos(angle)
        y = r * math.sin(angle)
        arc_pts_top.append(bm.verts.new((x, y,  depth)))
        arc_pts_bot.append(bm.verts.new((x, y, -depth)))
    # Bottom tip
    tip_top = bm.verts.new((0.0, -r * 0.55,  depth))
    tip_bot = bm.verts.new((0.0, -r * 0.55, -depth))
    front_poly = arc_pts_top + [tip_top]
    back_poly  = [tip_bot] + list(reversed(arc_pts_bot))
    bm.faces.new(front_poly)
    bm.faces.new(back_poly)
    all_top = arc_pts_top + [tip_top]
    all_bot = arc_pts_bot + [tip_bot]
    n = len(all_top)
    for i in range(n - 1):
        ni = i + 1
        bm.faces.new([all_top[i], all_bot[i], all_bot[ni], all_top[ni]])
    # Close left and right edge
    bm.faces.new([all_top[-1], all_bot[-1], all_bot[0], all_top[0]])
    bm.normal_update()
    mesh = bpy.data.meshes.new("shield")
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new("pu_ghost", mesh)
    # Rotate so shield faces the camera (Z-up world): tilt it up
    obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False) if False else None
    return link(obj)


def build_spiky_ball(sphere_r=0.24, spike_r=0.065, spike_len=0.22, segments=10, rings=8):
    """Red spiky ball — Bomb: UV sphere + 6 axis-aligned cones"""
    clear_scene()

    # Central sphere
    bpy.ops.mesh.primitive_uv_sphere_add(radius=sphere_r, segments=segments, ring_count=rings)
    sphere = bpy.context.active_object
    sphere.name = "bomb_sphere"
    smooth_shade(sphere)

    # 6 spikes on ±X, ±Y, ±Z axes
    spike_dirs = [
        (( 0,  0,  1), (0,         0,         0        )),
        (( 0,  0, -1), (math.pi,   0,         0        )),
        (( 1,  0,  0), (0,         math.pi/2, 0        )),
        ((-1,  0,  0), (0,        -math.pi/2, 0        )),
        (( 0,  1,  0), (-math.pi/2,0,         0        )),
        (( 0, -1,  0), ( math.pi/2,0,         0        )),
    ]
    offset = sphere_r + spike_len * 0.5

    spikes = []
    for (dx, dy, dz), rot in spike_dirs:
        bpy.ops.mesh.primitive_cone_add(
            radius1=spike_r, radius2=0.005, depth=spike_len,
            location=(dx * offset, dy * offset, dz * offset),
            rotation=rot
        )
        c = bpy.context.active_object
        smooth_shade(c)
        spikes.append(c)

    # Join sphere + all spikes
    bpy.ops.object.select_all(action='DESELECT')
    for sp in spikes: sp.select_set(True)
    sphere.select_set(True)
    bpy.context.view_layer.objects.active = sphere
    bpy.ops.object.join()
    sphere.name = "pu_bomb"
    return sphere


def build_gem(r=0.30, crown_h=0.28, pav_h=0.18, girdle_r=0.30, sides=8):
    """White/silver gem — Clear"""
    bm = bmesh.new()
    # Top apex
    apex = bm.verts.new((0, 0, crown_h))
    # Upper ring (crown girdle)
    crown = []
    for i in range(sides):
        a = TAU * i / sides
        crown.append(bm.verts.new((girdle_r * math.cos(a), girdle_r * math.sin(a), 0.04)))
    # Lower ring (pavilion girdle)
    pav_r = girdle_r * 0.72
    pav   = []
    for i in range(sides):
        a = TAU * i / sides + TAU / (sides * 2)
        pav.append(bm.verts.new((pav_r * math.cos(a), pav_r * math.sin(a), -0.05)))
    # Bottom apex
    culet = bm.verts.new((0, 0, -pav_h))

    # Crown star facets (top apex → crown ring)
    for i in range(sides):
        ni = (i + 1) % sides
        bm.faces.new([apex, crown[i], crown[ni]])
    # Girdle band
    for i in range(sides):
        ni = (i + 1) % sides
        bm.faces.new([crown[i], pav[i], pav[ni], crown[ni]])
    # Pavilion facets
    for i in range(sides):
        ni = (i + 1) % sides
        bm.faces.new([pav[i], culet, pav[ni]])

    bm.normal_update()
    mesh = bpy.data.meshes.new("gem")
    bm.to_mesh(mesh); bm.free()
    return link(bpy.data.objects.new("pu_clear", mesh))


def build_snowflake(arm_len=0.38, arm_w=0.055, depth=0.07, arms=6, branch_frac=0.5):
    """Ice-blue snowflake — Freeze: 6 main arms + 6 shorter diagonal arms"""
    bm = bmesh.new()

    def add_rect_arm(angle, length, width, thick):
        """Add a rectangular arm from center outward at given angle"""
        hw = width / 2
        ht = thick / 2
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        def rot(lx, ly):
            return (lx * cos_a - ly * sin_a, lx * sin_a + ly * cos_a)
        # 4 corners top face, 4 corners bottom face
        corners = [
            rot(0.02, -hw), rot(length, -hw), rot(length, hw), rot(0.02, hw)
        ]
        top_v = [bm.verts.new((c[0], c[1],  ht)) for c in corners]
        bot_v = [bm.verts.new((c[0], c[1], -ht)) for c in corners]
        bm.faces.new(top_v)
        bm.faces.new(list(reversed(bot_v)))
        n = len(top_v)
        for i in range(n):
            ni = (i + 1) % n
            bm.faces.new([top_v[i], bot_v[i], bot_v[ni], top_v[ni]])

    # 6 main arms
    for i in range(arms):
        add_rect_arm(TAU * i / arms, arm_len, arm_w, depth)
    # 6 shorter diagonal arms (between main arms, half-length)
    for i in range(arms):
        add_rect_arm(TAU * i / arms + TAU / (arms * 2), arm_len * branch_frac, arm_w * 0.75, depth * 0.8)

    # Centre disc
    disc_verts_top = []
    disc_verts_bot = []
    disc_r = arm_w * 1.4
    disc_n = 10
    for i in range(disc_n):
        a = TAU * i / disc_n
        disc_verts_top.append(bm.verts.new((disc_r * math.cos(a), disc_r * math.sin(a),  depth / 2)))
        disc_verts_bot.append(bm.verts.new((disc_r * math.cos(a), disc_r * math.sin(a), -depth / 2)))
    bm.faces.new(disc_verts_top)
    bm.faces.new(list(reversed(disc_verts_bot)))
    n = disc_n
    for i in range(n):
        ni = (i + 1) % n
        bm.faces.new([disc_verts_top[i], disc_verts_bot[i], disc_verts_bot[ni], disc_verts_top[ni]])

    bm.normal_update()
    mesh = bpy.data.meshes.new("snowflake")
    bm.to_mesh(mesh); bm.free()
    return link(bpy.data.objects.new("pu_freeze", mesh))


def build_torus(major_r=0.26, minor_r=0.09, major_seg=24, minor_seg=12):
    """Purple torus — Magnet"""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r, minor_radius=minor_r,
        major_segments=major_seg, minor_segments=minor_seg
    )
    obj = bpy.context.active_object
    obj.name = "pu_magnet"
    smooth_shade(obj)
    return obj


# ── main generation loop ──────────────────────────────────────────────────────

SPECS = [
    ("pu_speed",  (0.01, 0.40, 0.04), build_rocket_arrow, {},                     1.0),
    ("pu_ghost",  (1.0,  0.80, 0.0),  build_shield,  {},                          1.0),
    ("pu_bomb",   (1.0,  0.05, 0.05), build_spiky_ball,{},                        1.0),
    ("pu_clear",  (0.85, 0.95, 1.0),  build_gem,     {},                          1.0),
    ("pu_freeze", (0.0,  0.80, 1.0),  build_snowflake,{},                         1.0),
    ("pu_magnet", (0.80, 0.10, 1.0),  build_torus,   {},                          1.0),
]

for name, rgb, builder, kwargs, strength in SPECS:
    print(f"\n--- Building {name} ---")
    if name != "pu_bomb":   # bomb calls clear_scene() internally
        clear_scene()
    obj = builder(**kwargs)
    mat = make_material(name + "_mat", rgb, strength)
    assign_mat(obj, mat)
    export_glb(obj, name + ".glb")

print("\nDONE — all 6 power-up models exported.")
