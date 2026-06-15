"""
tools/mascot_gen.py
===================
Generates the Party Pals Arena cute blob mascot as players/mascot.glb.

Orientation matches tank_model.py:
    +X = forward (face/eyes point +X)
    +Y = left / right
    +Z = up  (ground at Z = 0)

After GLTF → Godot import:
    Blender +X → Godot +X  (forward)
    Blender +Y → Godot -Z  (sides)
    Blender +Z → Godot +Y  (up)

Run headless:
    blender --background --python tools/mascot_gen.py
"""

import bpy, bmesh, math, os
from mathutils import Vector

# ──────────────────────── helpers ───────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials,
                  bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def make_mat(name, r, g, b, rough=0.5, metallic=0.0, alpha=1.0):
    """Create a Principled BSDF material; fake_user keeps it alive through GC."""
    mat = bpy.data.materials.new(name)
    mat.use_fake_user = True          # prevent GC during metaball conversion
    nodes = mat.node_tree.nodes
    bsdf  = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value  = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value   = rough
    bsdf.inputs["Metallic"].default_value    = metallic
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


def sphere(name, loc, radius, sx=1.0, sy=1.0, sz=1.0,
           segs=20, rings=14, mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, segments=segs, ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.name = name
    smooth(o)
    if sx != 1.0 or sy != 1.0 or sz != 1.0:
        o.scale = (sx, sy, sz)
        bpy.ops.object.transform_apply(scale=True)
    if mat:
        assign(o, mat)
    return o


def sel(*objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[-1]


# ──────────────────────── build ─────────────────────────────────────────────

def build_mascot():
    # Clean, symmetric cute blob: ONE rounded egg body + two big googly eyes,
    # pink cheeks and small feet. No metaball (that pinched into a lumpy neck).
    # Blender: +X = face/forward, +Z = up, ground at z=0.
    M_BODY  = make_mat("body",      1.00, 1.00, 1.00, rough=0.42)
    M_WHITE = make_mat("eye_white", 1.00, 1.00, 1.00, rough=0.08)
    M_DARK  = make_mat("pupil",     0.05, 0.04, 0.10, rough=0.20)
    M_SHINE = make_mat("shine",     1.00, 1.00, 1.00, rough=0.02, metallic=0.2)
    M_CHEEK = make_mat("cheek",     1.00, 0.46, 0.50, rough=0.80, alpha=0.70)

    # ── Body — single smooth egg (slightly taller than wide), base on ground ──
    body = sphere("body", (0, 0, 0.80), 0.72, sz=1.08,
                  segs=40, rings=28, mat=M_BODY)

    # ── Eyes — big, symmetric, close together, on the +X upper front ─────────
    EX, ESEP, EZ = 0.52, 0.23, 1.06
    ew_l = sphere("eye_white_l", (EX, -ESEP, EZ), 0.205, segs=22, rings=18, mat=M_WHITE)
    ew_r = sphere("eye_white_r", (EX,  ESEP, EZ), 0.205, segs=22, rings=18, mat=M_WHITE)
    # Pupils — sit in FRONT of the whites, gaze forward + slightly down
    ep_l = sphere("pupil_l", (EX + 0.135, -ESEP, EZ - 0.04), 0.105, segs=16, rings=12, mat=M_DARK)
    ep_r = sphere("pupil_r", (EX + 0.135,  ESEP, EZ - 0.04), 0.105, segs=16, rings=12, mat=M_DARK)
    # Shine — small dot, upper-outer of each pupil
    es_l = sphere("shine_l", (EX + 0.21, -ESEP - 0.05, EZ + 0.06), 0.045, segs=10, rings=8, mat=M_SHINE)
    es_r = sphere("shine_r", (EX + 0.21,  ESEP - 0.05, EZ + 0.06), 0.045, segs=10, rings=8, mat=M_SHINE)

    # ── Cheeks — flat pink discs below the eyes ──────────────────────────────
    ck_l = sphere("cheek_l", (0.58, -0.34, 0.82), 0.13, sx=0.18, segs=16, rings=10, mat=M_CHEEK)
    ck_r = sphere("cheek_r", (0.58,  0.34, 0.82), 0.13, sx=0.18, segs=16, rings=10, mat=M_CHEEK)

    # ── Feet — small nubs at the bottom front, close together ────────────────
    fl = sphere("foot_l", (0.16, -0.17, 0.07), 0.17, sx=0.95, sy=0.85, sz=0.55,
                segs=14, rings=10, mat=M_BODY)
    fr = sphere("foot_r", (0.16,  0.17, 0.07), 0.17, sx=0.95, sy=0.85, sz=0.55,
                segs=14, rings=10, mat=M_BODY)

    # ── Parent all parts to the body ─────────────────────────────────────────
    parts = [ew_l, ew_r, ep_l, ep_r, es_l, es_r, ck_l, ck_r, fl, fr]
    for part in parts:
        sel(part, body)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)

    return body, parts


# ──────────────────────────── main ──────────────────────────────────────────

def main():
    clear_scene()
    blob, parts = build_mascot()

    if bpy.app.background:
        try:
            here = os.path.dirname(os.path.abspath(__file__))
        except NameError:
            here = os.getcwd()

        project_root = os.path.dirname(here)  # tools/../ = project root
        out = os.path.join(project_root, "players", "mascot.glb")

        sel(*([blob] + parts))
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
        )
        print(f"\n✓  Mascot exported → {out}\n")


if __name__ == "__main__":
    main()
