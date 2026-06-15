"""
gen_brick.py — generates assets/models/brick.glb via Blender 5.1 Python API.

Brick is baked at the EXACT target dimensions so bevel stays uniform:
  Godot X  = 4.0  (along the wall)
  Godot Y  = 3.0  (height)
  Godot Z  = 1.5  (depth into arena / wall thickness)

After GLTF Y-up export (Blender Z→Godot Y, Blender Y→Godot -Z):
  Blender X = 4.0,  Blender Y = 1.5,  Blender Z = 3.0

No stud — heavy bevel (0.28 width, 6 segments) gives the chunky rounded-block
look matching the reference art. One material (white, recoloured per-brick in Godot).

For Z-aligned walls rotate the instance 90° around Y in Godot.

Run:
  blender --background --python tools/gen_brick.py
"""
import bpy, os

OUTPUT = bpy.path.abspath("//assets/models/brick.glb")

# ── clear ─────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
    for item in list(col):
        col.remove(item)

# ── brick body ─────────────────────────────────────────────────────────────────
# Default cube is 2×2×2. Scale to (4.0, 1.5, 3.0) in Blender units.
# After export:  Blender(X=4,Y=1.5,Z=3) → Godot(X=4,Y=3,Z=1.5)
bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, 0.0))
brick = bpy.context.active_object
brick.name = "brick"
brick.scale = (2.0, 0.75, 1.5)           # half-extents → 4 × 1.5 × 3 world dims
bpy.ops.object.transform_apply(scale=True)

# Heavy bevel for the chunky rounded-block look
bev = brick.modifiers.new("Bevel", "BEVEL")
bev.width    = 0.28      # large chamfer ≈ 7% of brick width → very rounded corners
bev.segments = 6         # smooth arc, not faceted
bpy.ops.object.modifier_apply(modifier="Bevel")
bpy.ops.object.shade_smooth()

# White material — Godot wall_arena3d overrides per brick
m = bpy.data.materials.new("brick")
m.use_fake_user = True
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
brick.data.materials.append(m)

# ── export ─────────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print(f"GEN_OK: {OUTPUT}")
