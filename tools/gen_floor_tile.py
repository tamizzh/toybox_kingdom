"""
gen_floor_tile.py — generates assets/models/floor_tile.glb

A single 4×4 floor tile (matching ts=4.0 in wall_arena3d.gd) with a heavily
rounded top so each tile reads as a soft "pillow/cushion" — matching the
plush, rounded checkerboard tiles in the reference art.

Tile dimensions in Godot:
  X = 4.0, Y = 0.45 (slab height), Z = 4.0

In Blender (Z-up, Y-up export):
  X = 4.0, Y = 4.0, Z = 0.45  →  scale = (2.0, 2.0, 0.225)

Run:
  blender --background --python tools/gen_floor_tile.py
"""
import bpy, os

OUTPUT = bpy.path.abspath("//assets/models/floor_tile.glb")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
    for item in list(col):
        col.remove(item)

# Tile slab: 4.0 × 0.40 × 4.0  (Blender X×Z×Y) — slightly lower profile, more rubber-like
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0))
tile = bpy.context.active_object
tile.name = "floor_tile"
tile.scale = (2.0, 2.0, 0.225)          # → 4.0 × 4.0 × 0.45 world dims (top sits at y=0)
bpy.ops.object.transform_apply(scale=True)

# Tight chamfer: target.png tiles read as flat-topped slate slabs with a small
# rounded lip, not soft pillows. A narrow bevel (0.10) with 3 segments keeps the
# top face a large flat plateau and gives a crisp edge so the seam/groove between
# tiles reads as a clean dark line. Angle limit keeps the top face flat.
bev = tile.modifiers.new("Bevel", "BEVEL")
bev.width            = 0.10
bev.segments         = 3
bev.limit_method     = "ANGLE"
bev.angle_limit      = 0.70   # ~40° — only perimeter edges, not interior faces
bpy.ops.object.modifier_apply(modifier="Bevel")
bpy.ops.object.shade_smooth()

m = bpy.data.materials.new("floor_tile")
m.use_fake_user = True
m.use_nodes = True
bsdf = m.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value  = (0.247, 0.290, 0.361, 1.0)  # Palette.ARENA_FLOOR
bsdf.inputs["Roughness"].default_value   = 0.90
bsdf.inputs["Metallic"].default_value    = 0.0
tile.data.materials.append(m)

os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print(f"GEN_OK: {OUTPUT}")
