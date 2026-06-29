"""
modify_mascot_jelly.py
----------------------
Blender 4.x Python script.

Workflow:
  1. Import assets/mascot.glb — keep eyes, crown, face parts
  2. Delete the original body + all arm meshes
  3. Build a NEW rounded-square jelly blob body procedurally
  4. Re-parent / reposition face parts onto the new body
  5. Add jelly shape keys + material to the new body
  6. Animate idle bounce (shape keys + Z)
  7. Studio lighting + camera
  8. Export → assets/mascot_jelly.glb

Run:
  blender --background --python tools/modify_mascot_jelly.py
Or: paste into Blender Text Editor → Run Script
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
_HARDCODED_ROOT = r"C:\Users\rpandian\Documents\toybox kingdom"

def _resolve_project_root():
    if "__file__" in dir():
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    blend = bpy.data.filepath
    if blend:
        candidate = os.path.dirname(blend)
        for _ in range(4):
            if os.path.isdir(os.path.join(candidate, "assets")):
                return candidate
            candidate = os.path.dirname(candidate)
    return _HARDCODED_ROOT

PROJECT_ROOT = _resolve_project_root()
GLB_IN  = os.path.join(PROJECT_ROOT, "assets", "mascot.glb")
GLB_OUT = os.path.join(PROJECT_ROOT, "assets", "mascot_jelly.glb")

# ---------------------------------------------------------------------------
# Keywords
# ---------------------------------------------------------------------------
# Objects whose names match these → DELETE (arms + original body)
DELETE_KEYWORDS = [
    "arm", "hand", "finger", "thumb", "wrist", "elbow",
    "shoulder", "forearm", "upperarm",
    "l_arm", "r_arm", "arm_l", "arm_r",
    "body", "torso", "chest", "trunk", "skin",
]

# Objects whose names match these → KEEP (eyes, crown, face accessories)
KEEP_KEYWORDS = [
    "eye", "pupil", "iris", "sclera", "brow", "eyebrow",
    "mouth", "smile", "lip", "blush", "cheek", "teeth",
    "crown", "hat", "gem", "jewel", "accessory",
    "head",   # keep head if separate from body
    "nose", "ear",
]

def _should_delete(name):
    low = name.lower()
    return any(kw in low for kw in DELETE_KEYWORDS)

def _should_keep(name):
    low = name.lower()
    return any(kw in low for kw in KEEP_KEYWORDS)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)

def ensure_collection(name):
    if name in bpy.data.collections:
        return bpy.data.collections[name]
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col

def link_to(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

def set_active(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)

def new_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes.clear()
    return mat

def iter_fcurves(action):
    """Compatible fcurve iterator for Blender 3.x – 4.4+."""
    if hasattr(action, "fcurves"):
        yield from action.fcurves
        return
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                yield from bag.fcurves

# ---------------------------------------------------------------------------
# 1. IMPORT + CATEGORISE
# ---------------------------------------------------------------------------

def import_and_categorise():
    if not os.path.exists(GLB_IN):
        raise FileNotFoundError(f"Not found: {GLB_IN}")
    bpy.ops.import_scene.gltf(filepath=GLB_IN)

    # Snapshot names immediately — before any deletion
    all_names = [o.name for o in bpy.context.selected_objects]
    print(f"[jelly] Imported: {all_names}")

    to_delete = []
    to_keep   = []
    ambiguous = []

    for name in all_names:
        if _should_keep(name):
            to_keep.append(name)
        elif _should_delete(name):
            to_delete.append(name)
        else:
            ambiguous.append(name)

    # Ambiguous objects that are MESH and not obviously face = delete (likely body parts)
    for name in ambiguous:
        ob = bpy.data.objects.get(name)
        if ob and ob.type == "MESH":
            to_delete.append(name)
        else:
            to_keep.append(name)   # keep armatures, empties, etc.

    print(f"[jelly] KEEP  : {to_keep}")
    print(f"[jelly] DELETE: {to_delete}")

    # Batch delete
    bpy.ops.object.select_all(action="DESELECT")
    for name in to_delete:
        ob = bpy.data.objects.get(name)
        if ob:
            ob.select_set(True)
    bpy.ops.object.delete()

    # Return fresh refs to kept objects
    kept = [bpy.data.objects[n] for n in to_keep if n in bpy.data.objects]
    return kept

# ---------------------------------------------------------------------------
# 2. COMPUTE FACE BBOX  (so we know where to place eyes on the new body)
# ---------------------------------------------------------------------------

def face_bbox(kept_objects):
    """Return (center, z_min, z_max, y_max) of the kept face parts."""
    xs, ys, zs = [], [], []
    for obj in kept_objects:
        if obj.type != "MESH":
            continue
        for v in obj.data.vertices:
            wco = obj.matrix_world @ v.co
            xs.append(wco.x); ys.append(wco.y); zs.append(wco.z)
    if not xs:
        return Vector((0, 0, 1)), 0.0, 2.0, 1.0
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    cz = (min(zs) + max(zs)) / 2
    return Vector((cx, cy, cz)), min(zs), max(zs), max(ys)

# ---------------------------------------------------------------------------
# 3. BUILD NEW SQUARE JELLY BLOB BODY
#    Rounded cube → Bevel → Subdivision → BMesh squeeze
# ---------------------------------------------------------------------------

def create_square_blob(col):
    """
    Rounded-cube jelly blob: start with a unit cube, apply a bevel whose
    width equals almost half the shortest side — this gives a true
    marshmallow / squircle silhouette rather than a chamfered box.

    Proportions (Blender units):
        W  = 1.8  (left–right)
        D  = 1.4  (front–back, slightly flatter)
        H  = 2.0  (height, a touch taller than wide)
    Bevel width = 0.46 × smallest half-side ≈ very round.
    """
    W, D, H = 1.8, 1.4, 2.0   # total extents

    # --- 1. Cube with exact target size ---
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 0))
    blob = bpy.context.active_object
    blob.name = "Body_JellyBlob"

    # primitive_cube_add size=2 → half-extents 1; scale to target
    blob.scale = (W / 2, D / 2, H / 2)
    bpy.ops.object.transform_apply(scale=True)

    # --- 2. BMesh: slightly widen base, add tiny cute forward tilt ---
    bm = bmesh.new()
    bm.from_mesh(blob.data)
    bm.verts.ensure_lookup_table()
    z_vals = [v.co.z for v in bm.verts]
    z_lo, z_hi = min(z_vals), max(z_vals)
    z_rng = z_hi - z_lo or 1.0
    for v in bm.verts:
        t = (v.co.z - z_lo) / z_rng          # 0=bottom, 1=top
        v.co.x *= 1.0 + 0.06 * (1.0 - t)    # wider at base
        v.co.y *= 1.0 + 0.04 * (1.0 - t)
        v.co.y -= 0.03 * t * H               # lean forward at top
    bm.to_mesh(blob.data)
    bm.free()
    blob.data.update()

    # --- 3. Bevel: width ≈ 46 % of half the shortest side ---
    # With W=1.8, half=0.9 → bevel_width = 0.9 * 0.46 ≈ 0.41
    # This rounds every edge into a large arc, giving the marshmallow look.
    bevel_w = (D / 2) * 0.46
    bv = blob.modifiers.new("Bevel", "BEVEL")
    bv.width        = bevel_w
    bv.segments     = 16          # high segment count = perfectly smooth arc
    bv.profile      = 1.0         # circular cross-section on each edge
    bv.limit_method = "NONE"      # bevel ALL edges equally

    # --- 4. Subdivision Surface to smooth the pole-less topology ---
    sub = blob.modifiers.new("Subd", "SUBSURF")
    sub.levels        = 2
    sub.render_levels = 2

    for p in blob.data.polygons:
        p.use_smooth = True

    # Centre base at z=0
    blob.location.z = H / 2
    bpy.ops.object.transform_apply(location=True)

    link_to(blob, col)
    print(f"[jelly] Rounded cube body: W={W} D={D} H={H}  bevel={bevel_w:.3f}")
    return blob

# ---------------------------------------------------------------------------
# 4. REPOSITION FACE PARTS ONTO NEW BODY
# ---------------------------------------------------------------------------

def reposition_face(kept_objects, blob):
    """
    Translate all kept face parts so they sit on the front face of the new body.
    Strategy: centre X on blob, push Y to blob's front surface, keep relative Z.
    """
    # Estimate blob front surface Y at mid-height (after modifiers, approx)
    # The cube before bevel goes from -body_w*0.75/2 to +body_w*0.75/2 in Y.
    # After rounding/bevel the front face is pulled in slightly — use 85 % of half-depth.
    bb  = blob.bound_box   # local space
    # bound_box is 8 corners, index 1 has max Y in local
    local_y_front = max(corner[1] for corner in bb)
    front_y = (blob.matrix_world @ Vector((0, local_y_front, 0))).y * 0.88

    # Find current centroid of face mesh objects
    face_meshes = [o for o in kept_objects if o.type == "MESH"]
    if not face_meshes:
        return

    # Centre of all face parts in world space
    cx = sum(o.location.x for o in face_meshes) / len(face_meshes)
    cy = sum(o.location.y for o in face_meshes) / len(face_meshes)
    cz = sum(o.location.z for o in face_meshes) / len(face_meshes)

    # Re-derive blob centre Z from actual bounding box
    blob_bb_z = [(blob.matrix_world @ Vector(c)).z for c in blob.bound_box]
    blob_z_mid = (min(blob_bb_z) + max(blob_bb_z)) / 2
    blob_z_top = max(blob_bb_z)

    # Offset to apply to every face part
    dx = -cx                          # centre X on blob
    dy = front_y - cy                 # push to front face
    dz = (blob_z_mid + (blob_z_top - blob_z_mid) * 0.35) - cz  # upper-mid area

    for obj in kept_objects:
        obj.location.x += dx
        obj.location.y += dy
        obj.location.z += dz
        print(f"[jelly] Repositioned {obj.name} → {obj.location}")

# ---------------------------------------------------------------------------
# 5. SHAPE KEYS
# ---------------------------------------------------------------------------

def add_jelly_shape_keys(blob):
    if blob.data.shape_keys:
        set_active(blob)
        bpy.ops.object.shape_key_clear()

    blob.shape_key_add(name="Basis",   from_mix=False)
    blob.shape_key_add(name="Squash",  from_mix=False)
    blob.shape_key_add(name="Stretch", from_mix=False)
    blob.shape_key_add(name="WobbleL", from_mix=False)
    blob.shape_key_add(name="WobbleR", from_mix=False)

    keys  = blob.data.shape_keys.key_blocks
    verts = blob.data.vertices
    z_vals = [v.co.z for v in verts]
    z_min, z_max = min(z_vals), max(z_vals)
    z_rng  = z_max - z_min or 1.0

    for v in verts:
        t = (v.co.z - z_min) / z_rng

        keys["Squash"].data[v.index].co = Vector((
            v.co.x * 1.20,
            v.co.y * 1.15,
            z_min + (v.co.z - z_min) * 0.75,
        ))
        keys["Stretch"].data[v.index].co = Vector((
            v.co.x * 0.88,
            v.co.y * 0.88,
            z_min + (v.co.z - z_min) * 1.22,
        ))
        keys["WobbleL"].data[v.index].co = Vector((
            v.co.x + 0.18 * t,
            v.co.y,
            v.co.z,
        ))
        keys["WobbleR"].data[v.index].co = Vector((
            v.co.x - 0.18 * t,
            v.co.y,
            v.co.z,
        ))

    print("[jelly] Shape keys added.")
    return keys

# ---------------------------------------------------------------------------
# 6. JELLY MATERIAL
# ---------------------------------------------------------------------------

def apply_jelly_material(blob):
    blob.data.materials.clear()
    mat  = new_material("Mat_JellyBody")
    out  = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    out.location  = (600, 0)
    bsdf.location = (200, 0)

    bsdf.inputs["Base Color"].default_value          = (0.15, 0.45, 0.95, 1.0)
    bsdf.inputs["Roughness"].default_value           = 0.20
    bsdf.inputs["Transmission Weight"].default_value = 0.28
    bsdf.inputs["Subsurface Weight"].default_value   = 0.42
    bsdf.inputs["Subsurface Radius"].default_value   = (0.30, 0.60, 1.00)
    bsdf.inputs["Subsurface Scale"].default_value    = 0.20
    bsdf.inputs["IOR"].default_value                 = 1.45

    spec_key = "Specular IOR Level" if "Specular IOR Level" in bsdf.inputs else "Specular"
    bsdf.inputs[spec_key].default_value = 0.65

    mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    blob.data.materials.append(mat)
    print("[jelly] Jelly material applied.")

# ---------------------------------------------------------------------------
# 7. ANIMATE
# ---------------------------------------------------------------------------

def animate_jelly(blob, crown_obj=None):
    fps   = 24
    cycle = fps * 2
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end   = cycle

    keys   = blob.data.shape_keys.key_blocks
    orig_z = blob.location.z

    for fo in range(0, cycle + 1, 2):
        t = fo / cycle
        s = math.sin(2 * math.pi * t)
        scene.frame_set(fo + 1)

        blob.location.z = orig_z + 0.10 * max(0.0, s)
        blob.keyframe_insert("location", index=2)

        squash_v  = max(0.0, -s) * 0.65
        stretch_v = max(0.0,  s) * 0.45
        wl = max(0.0,  math.sin(2 * math.pi * t + 0.5)) * 0.28
        wr = max(0.0, -math.sin(2 * math.pi * t + 0.5)) * 0.28

        keys["Squash"].value  = squash_v
        keys["Stretch"].value = stretch_v
        keys["WobbleL"].value = wl
        keys["WobbleR"].value = wr
        for k in ("Squash", "Stretch", "WobbleL", "WobbleR"):
            keys[k].keyframe_insert("value")

        if crown_obj:
            dt = ((t - 6 / cycle) % 1.0)
            ds = math.sin(2 * math.pi * dt)
            crown_obj.rotation_euler.y = math.radians(ds * 4)
            crown_obj.keyframe_insert("rotation_euler", index=1)

    if blob.animation_data and blob.animation_data.action:
        for fc in iter_fcurves(blob.animation_data.action):
            m = fc.modifiers.new("CYCLES")
            m.mode_before = "REPEAT"
            m.mode_after  = "REPEAT"

    print("[jelly] Animation keyed.")

# ---------------------------------------------------------------------------
# 8. LIGHTING + CAMERA
# ---------------------------------------------------------------------------

def setup_lighting(col):
    def add_light(name, ltype, energy, loc, color=(1,1,1)):
        bpy.ops.object.light_add(type=ltype, location=loc)
        l = bpy.context.active_object
        l.name = name
        l.data.energy = energy
        l.data.color  = color
        if ltype == "AREA":
            l.data.size = 2.5
        link_to(l, col)
        return l

    key  = add_light("Light_Key",  "AREA", 800, ( 3.5,-3.5, 5.0), (1.0,0.95,0.85))
    fill = add_light("Light_Fill", "AREA", 250, (-4.0,-2.0, 3.0), (0.75,0.85,1.0))
    rim  = add_light("Light_Rim",  "SPOT", 500, ( 0.0, 4.5, 4.0), (0.9,0.8,1.0))
    key.rotation_euler  = (math.radians(50),  math.radians(20),  math.radians(30))
    fill.rotation_euler = (math.radians(40),  math.radians(-30), math.radians(-20))
    rim.rotation_euler  = (math.radians(-45), 0, 0)
    rim.data.spot_size  = math.radians(45)
    rim.data.spot_blend = 0.25

def setup_camera(col):
    bpy.ops.object.camera_add(location=(3.8, -5.0, 3.2))
    cam = bpy.context.active_object
    cam.name = "Camera_Main"
    cam.rotation_euler = (math.radians(65), 0, math.radians(40))
    cam.data.lens = 70
    bpy.context.scene.camera = cam
    link_to(cam, col)

def setup_render():
    scene = bpy.context.scene
    scene.render.engine        = "CYCLES"
    scene.cycles.samples       = 128
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1080

# ---------------------------------------------------------------------------
# 9. EXPORT
# ---------------------------------------------------------------------------

def export_glb():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        export_animations=True,
        export_morph=True,
        export_morph_normal=False,
        export_apply=False,
    )
    print(f"[jelly] Exported → {GLB_OUT}")

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    clear_scene()

    col_char = ensure_collection("Character")
    col_env  = ensure_collection("Environment")

    # 1 — Import + categorise (keeps eyes/crown, deletes body+arms)
    kept = import_and_categorise()

    for obj in kept:
        link_to(obj, col_char)

    # 2 — Measure where the face parts live so we can align to new body
    _, fz_min, fz_max, fy_max = face_bbox(kept)
    print(f"[jelly] Face bbox Z: {fz_min:.2f} – {fz_max:.2f}  front Y: {fy_max:.2f}")

    # 3 — Build new square jelly blob body
    blob = create_square_blob(col_char)

    # 4 — Snap face parts onto new body front face
    reposition_face(kept, blob)

    # 5 — Shape keys
    add_jelly_shape_keys(blob)

    # 6 — Jelly material
    apply_jelly_material(blob)

    # 7 — Find crown for secondary motion
    crown = next(
        (o for o in kept if o.type == "MESH" and "crown" in o.name.lower()),
        None
    )

    # 8 — Animate
    animate_jelly(blob, crown)

    # 9 — Lighting + camera
    setup_lighting(col_env)
    setup_camera(col_env)
    setup_render()

    bpy.context.scene.frame_set(1)

    # 10 — Export
    export_glb()

    print("[jelly] All done.")


if __name__ == "__main__":
    main()
