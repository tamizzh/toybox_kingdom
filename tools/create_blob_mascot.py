"""
Cute Crowned Blob Mascot  —  Blender 5.1  →  game-ready GLB for Godot
=====================================================================

Builds the "Cute Crowned Blob" from the reference art as a LOW-POLY game asset
and exports it to ``players/mascot.glb`` for the Toybox Kingdoms game.

Silhouette: a soft "gumdrop" — a sphere flared wider at the bottom, with arms
and feet melted into one seamless body via a VOXEL REMESH + corrective smooth
(no visible sphere intersections).

Meshes (named to match how players/avatar3d.gd recolors the model):
  * Body  — single recolorable seamless mesh (arms + feet merged in).
            Bottom sits at Z=0 (→ Godot Y=0). Front faces +X (→ Godot +X).
  * Face  — eyes + pupils + highlights + blush + smile joined into ONE mesh
            named "Face" (keeps its own white/black/pink materials; the in-game
            body recolor skips anything named "face").
  * Crown — gold crown, stays gold for every player (recolor skips "crown").

Run headless:
    blender --background --python tools/create_blob_mascot.py -- --out players/mascot.glb

Args (after the `--`):
    --out PATH        output .glb (default: players/mascot.glb)
    --color r,g,b     body color 0..1 (default 0.02,0.45,1.0 — vibrant blue)
    --render PATH     also save a quick preview PNG (optional; slow)
"""

import bpy
import bmesh
import math
import os
import sys

from mathutils import Vector


# ---------------------------------------------------------------------------
# Body silhouette params (shared by create_body + surf_x so they stay in sync).
# Rounder + slightly taller than wide = cuter (vs. a flat pancake).
# ---------------------------------------------------------------------------
FLARE  = 0.22      # how much the lower body flares out
ZSCALE = 1.12      # >1 makes the blob taller than wide


# ---------------------------------------------------------------------------
# Args (everything after the standalone "--")
# ---------------------------------------------------------------------------

def parse_args():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    out = {"out": "players/mascot.glb",
           "color": (0.02, 0.45, 1.0),
           "render": None}
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--out":
            out["out"] = args[i + 1]; i += 2
        elif a == "--color":
            out["color"] = tuple(float(x) for x in args[i + 1].split(","))[:3]; i += 2
        elif a == "--render":
            out["render"] = args[i + 1]; i += 2
        else:
            i += 1
    return out


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for blk in (bpy.data.materials, bpy.data.meshes, bpy.data.curves,
                bpy.data.lights, bpy.data.cameras, bpy.data.worlds):
        for item in list(blk):
            blk.remove(item)


def create_material(name, color_rgb, roughness=0.3, metallic=0.0,
                    specular=0.5, ior=1.45):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = (*color_rgb, 1.0)
    bsdf.inputs['Roughness'].default_value  = roughness
    bsdf.inputs['Metallic'].default_value   = metallic
    if 'IOR' in bsdf.inputs:
        bsdf.inputs['IOR'].default_value = ior
    for key in ('Specular IOR Level', 'Specular'):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = specular
            break
    return mat


def select_only(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transforms(obj):
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def apply_all_modifiers(obj):
    select_only(obj)
    for m in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError:
            obj.modifiers.remove(m)


def shade_smooth(obj):
    select_only(obj)
    bpy.ops.object.shade_smooth()


def join_objects(objs, name):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


# ---------------------------------------------------------------------------
# Body  (gumdrop taper + seamless voxel-remesh merge of arms & feet)
# Front faces +X (→ Godot +X).  Built around origin; floored at the end.
# ---------------------------------------------------------------------------

def create_body(material):
    # ---- base sphere ----
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32,
                                          radius=1.0, location=(0, 0, 0))
    body = bpy.context.active_object
    body.name = "Body"

    # ---- rounder "egg-dome": gentle bottom flare, taller than wide ----
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for v in bm.verts:
        flare = max(0.0, (0.5 - v.co.z)) * FLARE     # bottom flares out a little
        v.co.x *= (1.0 + flare)
        v.co.y *= (1.0 + flare)
        v.co.z *= ZSCALE                             # stretch taller
    bm.to_mesh(body.data)
    bm.free()

    # ---- chunky stubby arms that clearly poke out the sides (±Y) ----
    limbs = []
    for side in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.34,
                                             location=(0.10, side * 1.05, -0.05))
        arm = bpy.context.active_object
        arm.scale = (0.75, 1.05, 1.25)
        arm.rotation_euler = (math.radians(side * 22), 0, 0)
        limbs.append(arm)

    # ---- two small oval feet at the bottom ----
    for side in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.30,
                                             location=(0.18, side * 0.42, -1.02))
        foot = bpy.context.active_object
        foot.scale = (1.25, 1.0, 0.6)
        limbs.append(foot)

    body = join_objects([body] + limbs, "Body")

    # ---- melt intersections into one seamless surface ----
    rem = body.modifiers.new("Voxel", 'REMESH')
    rem.mode = 'VOXEL'
    rem.voxel_size = 0.035                            # smooth but game-friendly
    rem.use_smooth_shade = True

    sm = body.modifiers.new("Smooth", 'CORRECTIVE_SMOOTH')
    sm.factor = 0.8
    sm.iterations = 18                               # iron out voxel blocks

    # ---- decimate to a sane tri budget for the game ----
    dec = body.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = 0.30

    apply_all_modifiers(body)
    shade_smooth(body)
    body.data.materials.clear()
    body.data.materials.append(material)
    print(f"[mascot] body tris: {len(body.data.polygons)}")
    return body


# ---------------------------------------------------------------------------
# Face  (geometry eyes/mouth, joined into ONE "Face" mesh).  Front = +X.
# ---------------------------------------------------------------------------

# The body flares wider toward the bottom + stretches taller, so its +X surface
# bulges past x=1. surf_x() inverts create_body's per-vertex transform so face
# features sit ON the surface instead of sinking inside it.
def surf_x(z, y):
    zo = max(-1.0, min(1.0, z / ZSCALE))            # undo the z stretch
    flare = max(0.0, (0.5 - zo)) * FLARE
    yo = y / (1.0 + flare)                          # undo the y flare
    inner = 1.0 - zo * zo - yo * yo                 # back on the unit sphere
    xo = math.sqrt(inner) if inner > 0 else 0.0
    return xo * (1.0 + flare)


def _sphere(name, radius, loc, scale, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc,
                                         segments=24, ring_count=16)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    apply_transforms(o)
    shade_smooth(o)
    o.data.materials.clear()
    o.data.materials.append(mat)
    return o


def create_smile(mat_dark):
    cu = bpy.data.curves.new('SmileCurve', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = 0.032
    cu.bevel_resolution = 3
    cu.fill_mode = 'FULL'
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(2)
    p = sp.bezier_points
    # On the +X face; smile dips down in Z, spans ±Y. X follows the flared
    # surface (pushed out slightly) so it never sinks into the body.
    def P(y, z):
        return Vector((surf_x(z, y) + 0.015, y, z))
    p[0].co = P(-0.18, 0.12); p[0].handle_left = P(-0.25, 0.12);  p[0].handle_right = P(-0.09, 0.03)
    p[1].co = P(0.00, -0.02); p[1].handle_left = P(-0.09, -0.02); p[1].handle_right = P(0.09, -0.02)
    p[2].co = P(0.18, 0.12); p[2].handle_left = P(0.09, 0.03);    p[2].handle_right = P(0.25, 0.12)
    obj = bpy.data.objects.new('Smile', cu)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_dark)
    select_only(obj)
    bpy.ops.object.convert(target='MESH')             # so it can join the Face mesh
    return bpy.context.active_object


def create_face(mat_white, mat_black, mat_blush):
    parts = []
    for side in (-1, 1):                              # ±Y = left/right eyes
        y  = side * 0.27                              # closer together
        ez = 0.42                                     # higher up the face
        sx = surf_x(ez, y)
        # BIG round sclera — the dominant cute feature
        parts.append(_sphere(f"EyeWhite_{side}", 0.27, (sx - 0.06, y, ez),
                             (0.26, 1.05, 1.12), mat_white))
        # big black pupil — centered for a straight-ahead gaze
        parts.append(_sphere(f"Pupil_{side}", 0.185, (sx + 0.02, y, ez),
                             (0.24, 1.0, 1.05), mat_black))
        # glossy highlight dots (big upper-outer + small lower)
        parts.append(_sphere(f"Shine_{side}", 0.065, (sx + 0.09, y - side * 0.06, ez + 0.10),
                             (0.4, 1.0, 1.0), mat_white))
        parts.append(_sphere(f"Shine2_{side}", 0.032, (sx + 0.09, y + side * 0.05, ez - 0.08),
                             (0.4, 1.0, 1.0), mat_white))
        # pink blush (lower + outer), on the flared cheek
        by = side * 0.52; bz = 0.04
        bx = surf_x(bz, by)
        parts.append(_sphere(f"Blush_{side}", 0.14, (bx - 0.03, by, bz),
                             (0.20, 1.35, 0.7), mat_blush))

    parts.append(create_smile(mat_black))
    return join_objects(parts, "Face")


# ---------------------------------------------------------------------------
# Crown  (low-poly gold — stays gold).  Front gem on +X.
# ---------------------------------------------------------------------------

def create_crown(mat_gold, mat_gem_blue, mat_gem_red):
    # Chunky classic crown: a tall gold band, 5 fat points each capped with a
    # rounded gold ball, a big blue gem set into the front of the band, and red
    # gems between the points.  Front = +X.
    crown_z = 0.92                                   # rests on the taller dome
    band_r  = 0.44
    n = 5
    gold = []

    # ---- band: a short tapered ring (slightly conical, wider at the bottom) ----
    bpy.ops.mesh.primitive_cone_add(radius1=band_r + 0.03, radius2=band_r,
                                    depth=0.26, location=(0, 0, crown_z + 0.13),
                                    vertices=48)
    band = bpy.context.active_object
    # hollow it: solidify gives the ring real thickness
    sol = band.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = 0.05
    # delete the top & bottom caps so it's an open band
    apply_all_modifiers(band)
    bm = bmesh.new(); bm.from_mesh(band.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces
                               if abs(f.normal.z) > 0.7], context='FACES')
    bm.to_mesh(band.data); bm.free()
    sol2 = band.modifiers.new("Sol2", 'SOLIDIFY'); sol2.thickness = 0.045
    apply_all_modifiers(band)
    gold.append(band)

    # ---- 5 fat points, each topped by a rounded gold ball ----
    heights = [0.30, 0.24, 0.27, 0.27, 0.24]         # i=0 → +X front, tallest
    band_top = crown_z + 0.26
    for i in range(n):
        ang = (i / n) * 2 * math.pi
        x, y = band_r * math.cos(ang), band_r * math.sin(ang)
        h = heights[i]
        bpy.ops.mesh.primitive_cone_add(radius1=0.145, radius2=0.05, depth=h,
                                        location=(x, y, band_top + h * 0.5 - 0.04),
                                        vertices=12)
        gold.append(bpy.context.active_object)
        # rounded ball cap on the tip
        ball = _sphere(f"Tip_{i}", 0.072, (x, y, band_top + h - 0.05),
                       (1.0, 1.0, 1.0), mat_gold)
        gold.append(ball)

    for g in gold:
        sub = g.modifiers.new("S", 'SUBSURF'); sub.levels = 1
        apply_all_modifiers(g); shade_smooth(g)
        g.data.materials.clear(); g.data.materials.append(mat_gold)

    # ---- big blue gem set into the front of the band (+X) ----
    gem_c = _sphere("GemCenter", 0.105, (band_r + 0.04, 0, crown_z + 0.12),
                    (0.45, 1.05, 1.25), mat_gem_blue)
    # ---- red gems between the front points ----
    reds = []
    for sgn in (-1, 1):
        ang = sgn * (2 * math.pi / n) * 0.5         # halfway to the next point
        x, y = band_r * math.cos(ang), band_r * math.sin(ang)
        reds.append(_sphere(f"GemSide_{sgn}", 0.062, (x + 0.03, y, crown_z + 0.13),
                            (0.5, 1.0, 1.0), mat_gem_red))

    return join_objects(gold + [gem_c] + reds, "Crown")


# ---------------------------------------------------------------------------
# Finalize + export
# ---------------------------------------------------------------------------

def drop_to_floor(objs):
    min_z = min((obj.matrix_world @ Vector(v.co)).z
                for obj in objs if obj.type == 'MESH'
                for v in obj.data.vertices)
    for obj in objs:
        obj.location.z -= min_z


def export_glb(path):
    abspath = os.path.abspath(path)
    os.makedirs(os.path.dirname(abspath), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=abspath, export_format='GLB',
                              export_yup=True, use_selection=True,
                              export_apply=True)
    print(f"[mascot] exported GLB -> {abspath}")


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    opts = parse_args()
    clear_scene()

    C_BODY  = opts["color"]
    mat_body  = create_material("BodyMat",  C_BODY,           roughness=0.30, specular=0.6)
    mat_white = create_material("WhiteMat", (1.0, 1.0, 1.0),  roughness=0.10, specular=0.8)
    mat_black = create_material("BlackMat", (0.02, 0.02, 0.03), roughness=0.10)
    mat_blush = create_material("BlushMat", (1.0, 0.32, 0.5), roughness=0.55)
    mat_gold  = create_material("GoldMat",  (1.0, 0.7, 0.05), roughness=0.15, metallic=0.95, specular=1.0)
    mat_gem_b = create_material("GemBlue",  (0.0, 0.2, 0.85), roughness=0.05, specular=1.0)
    mat_gem_r = create_material("GemRed",   (0.9, 0.1, 0.05), roughness=0.05, specular=1.0)

    create_body(mat_body)
    create_face(mat_white, mat_black, mat_blush)
    create_crown(mat_gold, mat_gem_b, mat_gem_r)

    drop_to_floor(list(bpy.data.objects))
    export_glb(opts["out"])

    if opts["render"]:
        _quick_render(opts["render"])

    print("[mascot] done. meshes:",
          [o.name for o in bpy.data.objects if o.type == 'MESH'])


def _quick_render(path):
    scene = bpy.context.scene
    engines = [e.identifier for e in
               bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'CYCLES'

    target = bpy.data.objects.new("LookAt", None)
    bpy.context.collection.objects.link(target)
    target.location = (0.0, 0.0, 1.05)

    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (6.5, -0.6, 1.6)
    tc = cam.constraints.new('TRACK_TO'); tc.target = target
    tc.track_axis = 'TRACK_NEGATIVE_Z'; tc.up_axis = 'UP_Y'
    scene.camera = cam

    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'SUN'))
    bpy.context.collection.objects.link(key)
    key.data.energy = 4.0
    key.rotation_euler = (math.radians(55), math.radians(15), math.radians(40))

    world = bpy.data.worlds.new("W"); scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (0.7, 0.82, 1.0, 1.0)
    bg.inputs['Strength'].default_value = 0.9

    scene.render.resolution_x = 800; scene.render.resolution_y = 800
    scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    print(f"[mascot] preview render -> {path}")


main()
