"""
gen_jelly_mascot.py
-------------------
Blender 4.x Python script — run via:
  blender --background --python tools/gen_jelly_mascot.py
or open in Blender's Text Editor and press Run Script.

Generates a cute jelly-blob mascot with crown, face, idle animation,
blink animation, shape keys, studio lighting, and Cycles render setup.
"""

import bpy
import bmesh
import math
from mathutils import Vector, Matrix


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)


def ensure_collection(name):
    if name in bpy.data.collections:
        return bpy.data.collections[name]
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def link_to(obj, collection):
    """Move obj from scene root into collection."""
    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)


def apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def new_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes.clear()
    return mat


def add_node(mat, bl_type, location=(0, 0)):
    return mat.node_tree.nodes.new(bl_type)


def link_nodes(mat, from_node, from_socket, to_node, to_socket):
    mat.node_tree.links.new(from_node.outputs[from_socket],
                            to_node.inputs[to_socket])


# ---------------------------------------------------------------------------
# 1. MATERIALS
# ---------------------------------------------------------------------------

def create_materials():
    mats = {}

    # --- Jelly body -----------------------------------------------------------
    m = new_material("Mat_JellyBody")
    out  = add_node(m, "ShaderNodeOutputMaterial", (600, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (200, 0))
    bsdf.inputs["Base Color"].default_value    = (0.15, 0.45, 0.95, 1.0)
    bsdf.inputs["Roughness"].default_value     = 0.25
    bsdf.inputs["Specular IOR Level"].default_value = 0.6
    bsdf.inputs["Transmission Weight"].default_value = 0.35
    bsdf.inputs["Subsurface Weight"].default_value   = 0.4
    bsdf.inputs["Subsurface Radius"].default_value   = (0.3, 0.6, 1.0)
    bsdf.inputs["Subsurface Scale"].default_value    = 0.15
    bsdf.inputs["IOR"].default_value           = 1.45
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["body"] = m

    # --- Gold crown -----------------------------------------------------------
    m = new_material("Mat_Gold")
    out  = add_node(m, "ShaderNodeOutputMaterial", (600, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (200, 0))
    bsdf.inputs["Base Color"].default_value  = (1.0, 0.75, 0.05, 1.0)
    bsdf.inputs["Metallic"].default_value    = 1.0
    bsdf.inputs["Roughness"].default_value   = 0.12
    bsdf.inputs["Specular IOR Level"].default_value = 1.0
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["gold"] = m

    # --- Blue gemstone --------------------------------------------------------
    m = new_material("Mat_Gem")
    out  = add_node(m, "ShaderNodeOutputMaterial", (600, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (200, 0))
    bsdf.inputs["Base Color"].default_value           = (0.05, 0.3, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value            = 0.0
    bsdf.inputs["Transmission Weight"].default_value  = 0.9
    bsdf.inputs["IOR"].default_value                  = 2.4
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["gem"] = m

    # --- White sclera ---------------------------------------------------------
    m = new_material("Mat_Sclera")
    out  = add_node(m, "ShaderNodeOutputMaterial", (400, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (0, 0))
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value  = 0.05
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["sclera"] = m

    # --- Black pupil ----------------------------------------------------------
    m = new_material("Mat_Pupil")
    out  = add_node(m, "ShaderNodeOutputMaterial", (400, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (0, 0))
    bsdf.inputs["Base Color"].default_value = (0.01, 0.01, 0.01, 1.0)
    bsdf.inputs["Roughness"].default_value  = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = 1.0
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["pupil"] = m

    # --- Pink blush -----------------------------------------------------------
    m = new_material("Mat_Blush")
    out  = add_node(m, "ShaderNodeOutputMaterial", (400, 0))
    bsdf = add_node(m, "ShaderNodeBsdfPrincipled", (0, 0))
    bsdf.inputs["Base Color"].default_value    = (1.0, 0.55, 0.65, 1.0)
    bsdf.inputs["Roughness"].default_value     = 0.9
    bsdf.inputs["Alpha"].default_value         = 0.55
    # Blender 4.2+ removed blend_method/shadow_method; use surface_render_method instead
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    elif hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["blush"] = m

    # --- Ground plane ---------------------------------------------------------
    m = new_material("Mat_Ground")
    out  = add_node(m, "ShaderNodeOutputMaterial", (400, 0))
    bsdf = add_node(m, "ShaderNodeBsdfDiffuse", (0, 0))
    bsdf.inputs["Color"].default_value     = (0.9, 0.9, 0.9, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    link_nodes(m, bsdf, "BSDF", out, "Surface")
    mats["ground"] = m

    return mats


# ---------------------------------------------------------------------------
# 2. BLOB BODY
# ---------------------------------------------------------------------------

def create_blob(mats, col):
    """Smooth jelly blob, slightly wider at bottom."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24,
                                          radius=1.0, location=(0, 0, 0))
    blob = bpy.context.active_object
    blob.name = "Blob_Body"

    # Sculpt the bottom wider via BMesh proportional scale
    bm = bmesh.new()
    bm.from_mesh(blob.data)
    bm.verts.ensure_lookup_table()

    for v in bm.verts:
        # Blend: 0 at top, 1 at bottom — widen x/y
        t = (1.0 - (v.co.z + 1.0) / 2.0)   # 0 top, 1 bottom
        scale_xy = 1.0 + 0.18 * t
        v.co.x *= scale_xy
        v.co.y *= scale_xy
        # Flatten bottom slightly
        if v.co.z < -0.7:
            v.co.z = v.co.z * 0.85 - 0.08

    bm.to_mesh(blob.data)
    bm.free()
    blob.data.update()

    # Smooth shading
    for poly in blob.data.polygons:
        poly.use_smooth = True

    # Subdivision Surface
    sub = blob.modifiers.new("Subd", "SUBSURF")
    sub.levels         = 3
    sub.render_levels  = 3

    # Material
    blob.data.materials.append(mats["body"])

    # Shape keys for expressions / jelly
    blob.shape_key_add(name="Basis", from_mix=False)
    blob.shape_key_add(name="Squash",    from_mix=False)
    blob.shape_key_add(name="Stretch",   from_mix=False)
    blob.shape_key_add(name="WobbleL",   from_mix=False)
    blob.shape_key_add(name="WobbleR",   from_mix=False)
    blob.shape_key_add(name="Happy",     from_mix=False)
    blob.shape_key_add(name="Surprised", from_mix=False)
    blob.shape_key_add(name="Sad",       from_mix=False)

    keys = blob.data.shape_keys.key_blocks

    # Squash: scale XY up, Z down
    for v, sk_v in zip(blob.data.vertices, keys["Squash"].data):
        sk_v.co = Vector((v.co.x * 1.22, v.co.y * 1.22, v.co.z * 0.78))

    # Stretch: scale XY down, Z up
    for v, sk_v in zip(blob.data.vertices, keys["Stretch"].data):
        sk_v.co = Vector((v.co.x * 0.88, v.co.y * 0.88, v.co.z * 1.20))

    # WobbleL / WobbleR — lean sideways
    for v, sk_v in zip(blob.data.vertices, keys["WobbleL"].data):
        t = (v.co.z + 1.0) / 2.0
        sk_v.co = Vector((v.co.x + 0.18 * t, v.co.y, v.co.z))
    for v, sk_v in zip(blob.data.vertices, keys["WobbleR"].data):
        t = (v.co.z + 1.0) / 2.0
        sk_v.co = Vector((v.co.x - 0.18 * t, v.co.y, v.co.z))

    apply_transforms(blob)
    link_to(blob, col)
    return blob


# ---------------------------------------------------------------------------
# 3. FACE (eyes, pupils, blush, mouth)
# ---------------------------------------------------------------------------

def _add_sphere(name, radius, location, mat, col):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16,
                                          radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    for p in obj.data.polygons:
        p.use_smooth = True
    sub = obj.modifiers.new("Subd", "SUBSURF")
    sub.levels = 2
    obj.data.materials.append(mat)
    link_to(obj, col)
    return obj


def create_face(mats, blob, col):
    face_parts = []
    eye_z     = 0.42
    eye_y     =  0.88   # pushed forward into blob surface
    eye_x_off =  0.30

    # --- Scleras (big anime eyes) ---
    for side, sign in (("L", -1), ("R", 1)):
        sc = _add_sphere(
            f"Eye_Sclera_{side}", 0.195,
            (sign * eye_x_off, eye_y, eye_z),
            mats["sclera"], col
        )
        face_parts.append(sc)

        # Pupil (inset slightly)
        pu = _add_sphere(
            f"Eye_Pupil_{side}", 0.115,
            (sign * eye_x_off, eye_y + 0.09, eye_z),
            mats["pupil"], col
        )
        # Tiny highlight spec
        sp = _add_sphere(
            f"Eye_Spec_{side}", 0.038,
            (sign * eye_x_off + 0.05, eye_y + 0.12, eye_z + 0.08),
            mats["sclera"], col
        )
        face_parts += [pu, sp]

        # Blush circle
        bpy.ops.mesh.primitive_circle_add(
            vertices=32, radius=0.14,
            location=(sign * (eye_x_off + 0.18), eye_y - 0.01, eye_z - 0.20)
        )
        bl = bpy.context.active_object
        bl.name = f"Blush_{side}"
        # Fill the circle
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.fill()
        bpy.ops.object.mode_set(mode="OBJECT")
        # Rotate to face forward
        bl.rotation_euler.x = math.radians(90)
        apply_transforms(bl)
        bl.data.materials.append(mats["blush"])
        link_to(bl, col)
        face_parts.append(bl)

    # --- Mouth (tiny arc) ---
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.14, minor_radius=0.025,
        major_segments=24, minor_segments=8,
        location=(0, 0.90, eye_z - 0.32)
    )
    mouth = bpy.context.active_object
    mouth.name = "Mouth"
    for p in mouth.data.polygons:
        p.use_smooth = True

    # Mask top half so only a smile arc remains
    bm = bmesh.new()
    bm.from_mesh(mouth.data)
    bm.verts.ensure_lookup_table()
    to_del = [v for v in bm.verts if v.co.z > 0.01]
    bmesh.ops.delete(bm, geom=to_del, context="VERTS")
    bm.to_mesh(mouth.data)
    bm.free()

    mouth.data.materials.append(mats["pupil"])
    link_to(mouth, col)
    face_parts.append(mouth)

    # --- Blink shape key on each sclera (flatten Y scale to 0) ---
    for side in ("L", "R"):
        sc_name = f"Eye_Sclera_{side}"
        sc = bpy.data.objects[sc_name]
        sc.shape_key_add(name="Basis", from_mix=False)
        blink_key = sc.shape_key_add(name="Blink", from_mix=False)
        for v, sk_v in zip(sc.data.vertices, blink_key.data):
            sk_v.co = Vector((v.co.x, v.co.y, sc.location.z + (v.co.z - sc.location.z) * 0.05))

    return face_parts


# ---------------------------------------------------------------------------
# 4. CROWN
# ---------------------------------------------------------------------------

def create_crown(mats, col):
    """Five-spike cartoon crown with gold + gem."""
    crown_z = 0.98   # sit on top of blob

    # --- Crown base ring ---
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=0.52, depth=0.18,
        location=(0, 0, crown_z)
    )
    crown = bpy.context.active_object
    crown.name = "Crown_Base"
    for p in crown.data.polygons:
        p.use_smooth = True

    # Bevel modifier for soft base edge
    bv = crown.modifiers.new("Bevel", "BEVEL")
    bv.width      = 0.025
    bv.segments   = 3

    crown.data.materials.append(mats["gold"])
    link_to(crown, col)

    # --- Five spikes ---
    spike_objects = []
    for i in range(5):
        angle  = math.radians(i * 72)
        # Alternate heights: 3 taller outer, 2 shorter inner
        height = 0.45 if i % 2 == 0 else 0.30
        radius = 0.09

        tip_x = math.sin(angle) * 0.38
        tip_y = math.cos(angle) * 0.38

        bpy.ops.mesh.primitive_cone_add(
            vertices=12, radius1=radius, radius2=0.04, depth=height,
            location=(tip_x, tip_y, crown_z + 0.09 + height / 2)
        )
        spike = bpy.context.active_object
        spike.name = f"Crown_Spike_{i}"
        for p in spike.data.polygons:
            p.use_smooth = True

        # Smooth rounded tip via SubSurf
        sub = spike.modifiers.new("Subd", "SUBSURF")
        sub.levels = 2
        bv2 = spike.modifiers.new("Bevel", "BEVEL")
        bv2.width    = 0.02
        bv2.segments = 2

        spike.data.materials.append(mats["gold"])
        link_to(spike, col)
        spike_objects.append(spike)

    # --- Front gemstone (diamond shape via icosphere) ---
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.10,
                                           location=(0, 0.50, crown_z + 0.15))
    gem = bpy.context.active_object
    gem.name = "Crown_Gem"
    # Squish into diamond
    gem.scale = (0.65, 0.30, 0.95)
    apply_transforms(gem)
    for p in gem.data.polygons:
        p.use_smooth = True
    sub_g = gem.modifiers.new("Subd", "SUBSURF")
    sub_g.levels = 2
    gem.data.materials.append(mats["gem"])
    link_to(gem, col)

    return crown, spike_objects, gem


# ---------------------------------------------------------------------------
# 5. GROUND PLANE
# ---------------------------------------------------------------------------

def create_ground(mats, col):
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -1.15))
    ground = bpy.context.active_object
    ground.name = "Ground"
    ground.data.materials.append(mats["ground"])

    # Smooth shadow catcher (Cycles)
    ground.is_shadow_catcher = True
    link_to(ground, col)
    return ground


# ---------------------------------------------------------------------------
# 6. IDLE ANIMATION  (blob bounce + jelly + secondary crown)
# ---------------------------------------------------------------------------

def animate_idle(blob, crown, spike_objects, gem):
    fps   = 24
    cycle = fps * 2   # 2-second loop

    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end   = cycle

    keys = blob.data.shape_keys.key_blocks

    for frame_offset in range(0, cycle + 1, 2):
        t = frame_offset / cycle
        s = math.sin(2 * math.pi * t)   # -1..1
        frame = frame_offset + 1

        scene.frame_set(frame)

        # Blob Z bounce
        blob.location.z = 0.12 * abs(s)
        blob.keyframe_insert("location", index=2)

        # Squash on land (s near -1), stretch at apex (s near 1)
        squash_val  = max(0.0, -s) * 0.65
        stretch_val = max(0.0,  s) * 0.45
        wobble_l    = max(0.0,  math.sin(2 * math.pi * t + 0.4)) * 0.25
        wobble_r    = max(0.0, -math.sin(2 * math.pi * t + 0.4)) * 0.25

        keys["Squash"].value  = squash_val
        keys["Stretch"].value = stretch_val
        keys["WobbleL"].value = wobble_l
        keys["WobbleR"].value = wobble_r
        keys["Squash"].keyframe_insert("value")
        keys["Stretch"].keyframe_insert("value")
        keys["WobbleL"].keyframe_insert("value")
        keys["WobbleR"].keyframe_insert("value")

        # Crown secondary — delayed by ~6 frames, smaller amplitude
        delay_t = ((t - 6 / cycle) % 1.0)
        ds = math.sin(2 * math.pi * delay_t)
        crown.location.z = 0.98 + 0.07 * abs(s) + 0.03 * ds
        crown.rotation_euler.y = math.radians(ds * 3)
        crown.keyframe_insert("location", index=2)
        crown.keyframe_insert("rotation_euler", index=1)

        # Gem follow crown
        gem.location.z = crown.location.z + 0.15
        gem.keyframe_insert("location", index=2)

        # Spikes subtle wiggle
        for i, sp in enumerate(spike_objects):
            phase = i * (2 * math.pi / 5)
            sp.rotation_euler.y = math.radians(math.sin(2 * math.pi * t + phase) * 2.5)
            sp.keyframe_insert("rotation_euler", index=1)

    # Make all fcurves cyclic
    if blob.animation_data and blob.animation_data.action:
        for fc in blob.animation_data.action.fcurves:
            mod = fc.modifiers.new("CYCLES")
            mod.mode_before = "REPEAT"
            mod.mode_after  = "REPEAT"


# ---------------------------------------------------------------------------
# 7. BLINK ANIMATION
# ---------------------------------------------------------------------------

def animate_blink(face_parts):
    """Insert a blink at frame 60, then again at frame 108."""
    for blink_start in (60, 108):
        for side in ("L", "R"):
            sc = bpy.data.objects.get(f"Eye_Sclera_{side}")
            if sc is None:
                continue
            sk = sc.data.shape_keys.key_blocks.get("Blink")
            if sk is None:
                continue

            for f, val in ((blink_start,     0.0),
                           (blink_start + 2, 1.0),
                           (blink_start + 4, 0.0)):
                bpy.context.scene.frame_set(f)
                sk.value = val
                sk.keyframe_insert("value")


# ---------------------------------------------------------------------------
# 8. LIGHTING
# ---------------------------------------------------------------------------

def setup_lighting(col):
    def add_light(name, light_type, energy, location, color=(1, 1, 1)):
        bpy.ops.object.light_add(type=light_type, location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color  = color
        if light_type == "AREA":
            light.data.size = 2.0
        link_to(light, col)
        return light

    # Key light (warm)
    key = add_light("Light_Key", "AREA", 800,
                    (3.5, -3.5, 5.0), color=(1.0, 0.95, 0.85))
    key.rotation_euler = (math.radians(50), math.radians(20), math.radians(30))

    # Fill light (cool)
    fill = add_light("Light_Fill", "AREA", 250,
                     (-4.0, -2.0, 3.0), color=(0.75, 0.85, 1.0))
    fill.rotation_euler = (math.radians(40), math.radians(-30), math.radians(-20))

    # Rim light (back)
    rim = add_light("Light_Rim", "SPOT", 500,
                    (0, 4.5, 4.0), color=(0.9, 0.8, 1.0))
    rim.rotation_euler = (math.radians(-45), 0, 0)
    rim.data.spot_size   = math.radians(45)
    rim.data.spot_blend  = 0.25

    return key, fill, rim


# ---------------------------------------------------------------------------
# 9. CAMERA
# ---------------------------------------------------------------------------

def setup_camera(col):
    bpy.ops.object.camera_add(location=(3.8, -4.2, 2.8))
    cam = bpy.context.active_object
    cam.name = "Camera_Main"
    cam.rotation_euler = (math.radians(68), 0, math.radians(42))

    cam.data.lens       = 70      # slight tele for character feel
    cam.data.dof.use_dof = True

    # Focus on blob origin
    bpy.ops.object.empty_add(location=(0, 0, 0.3))
    focus_empty = bpy.context.active_object
    focus_empty.name = "Camera_Focus"
    cam.data.dof.focus_object     = focus_empty
    cam.data.dof.aperture_fstop   = 5.6

    bpy.context.scene.camera = cam
    link_to(cam, col)
    link_to(focus_empty, col)
    return cam


# ---------------------------------------------------------------------------
# 10. RENDER SETTINGS (Cycles)
# ---------------------------------------------------------------------------

def setup_render():
    scene = bpy.context.scene
    scene.render.engine            = "CYCLES"
    scene.cycles.device            = "GPU"   # falls back to CPU if no GPU
    scene.cycles.samples           = 256
    scene.cycles.use_denoising     = True
    scene.cycles.denoiser          = "OPENIMAGEDENOISE"
    scene.render.resolution_x      = 1080
    scene.render.resolution_y      = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"

    # World: simple sky gradient
    world = bpy.data.worlds.new("World_Studio")
    scene.world = world
    world.use_nodes = True
    wn = world.node_tree.nodes
    wn.clear()
    bg   = wn.new("ShaderNodeBackground")
    sky  = wn.new("ShaderNodeTexSky")
    out  = wn.new("ShaderNodeOutputWorld")
    sky.sky_type = "NISHITA"
    world.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
    world.node_tree.links.new(bg.outputs["Background"], out.inputs["Surface"])
    bg.inputs["Strength"].default_value = 0.4


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    clear_scene()

    # Collections
    col_char  = ensure_collection("Character")
    col_crown = ensure_collection("Crown")
    col_face  = ensure_collection("Face")
    col_env   = ensure_collection("Environment")
    col_rig   = ensure_collection("Rig")

    mats = create_materials()

    blob               = create_blob(mats, col_char)
    face_parts         = create_face(mats, blob, col_face)
    crown, spikes, gem = create_crown(mats, col_crown)
    ground             = create_ground(mats, col_env)

    animate_idle(blob, crown, spikes, gem)
    animate_blink(face_parts)

    setup_lighting(col_env)
    setup_camera(col_rig)
    setup_render()

    # Reset to frame 1 for viewport
    bpy.context.scene.frame_set(1)

    print("[gen_jelly_mascot] Done — scene built successfully.")


if __name__ == "__main__":
    main()
