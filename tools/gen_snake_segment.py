"""
gen_snake_segment.py — generates assets/models/snake_segment.glb

A single rounded cube for snake body segments, matching the reference art style.
Heavy bevel (very smooth corners) on a 0.85×0.85×0.85 cube.
White material so Godot can material_override with player colour.

Run:
  blender --background --python tools/gen_snake_segment.py
"""
import bpy, os

OUTPUT = bpy.path.abspath("//assets/models/snake_segment.glb")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
    for item in list(col):
        col.remove(item)

# Cube at 0.85 × 0.85 × 0.85  (half-size 0.425 each axis)
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0))
seg = bpy.context.active_object
seg.name = "snake_segment"
seg.scale = (0.425, 0.425, 0.425)
bpy.ops.object.transform_apply(scale=True)

# Very heavy bevel → almost sphere-like rounded cube
bev = seg.modifiers.new("Bevel", "BEVEL")
bev.width    = 0.16     # ~38% of half-extent → very rounded
bev.segments = 8
bpy.ops.object.modifier_apply(modifier="Bevel")
bpy.ops.object.shade_smooth()

m = bpy.data.materials.new("snake_segment")
m.use_fake_user = True
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.45
seg.data.materials.append(m)

os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print(f"GEN_OK: {OUTPUT}")
