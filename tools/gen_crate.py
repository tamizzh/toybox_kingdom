"""
gen_crate.py — generates assets/models/crate.glb via Blender 5.1 Python API.

A simple wooden crate prop (as seen in the snake_target reference):
  - Beveled box body
  - Six inset face panels to suggest wood-plank construction
  - Two materials: frame (dark wood) + panel (lighter wood)

Exported size: 1.0 × 1.0 × 1.0 units.

Run:
  blender --background --python tools/gen_crate.py
"""
import bpy
import bmesh

OUTPUT = bpy.path.abspath("//assets/models/crate.glb")

# ─── clear ───────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
    for item in list(col):
        col.remove(item)

# ─── crate body ──────────────────────────────────────────────────────────────
bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, 0.50))
crate = bpy.context.active_object
crate.name = "crate"
crate.scale = (0.50, 0.50, 0.50)
bpy.ops.object.transform_apply(scale=True)

# Bevel for rounded corner edges
bev = crate.modifiers.new("Bevel", "BEVEL")
bev.width = 0.055
bev.segments = 3
bpy.ops.object.modifier_apply(modifier="Bevel")

# Inset each face to create the panel look using bmesh
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(crate.data)
bm.faces.ensure_lookup_table()

# Select all, inset individual faces
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.inset(thickness=0.08, depth=-0.018, use_individual=True)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()

# ─── two materials: frame (dark) + panel (light) ─────────────────────────────
m_frame = bpy.data.materials.new("crate_frame")
m_frame.use_fake_user = True
m_frame.use_nodes = True
m_frame.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = \
    (0.28, 0.18, 0.09, 1.0)
m_frame.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.82

m_panel = bpy.data.materials.new("crate_panel")
m_panel.use_fake_user = True
m_panel.use_nodes = True
m_panel.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = \
    (0.55, 0.36, 0.17, 1.0)
m_panel.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.78

crate.data.materials.clear()
crate.data.materials.append(m_frame)
crate.data.materials.append(m_panel)

# Assign: inset (inner) faces → panel material (index 1)
# Outer faces (non-inset) → frame material (index 0)
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(crate.data)
bm.faces.ensure_lookup_table()

# The inset created extra faces. Inset inner panels are smaller area faces.
# Identify by face area: smaller faces = inset panels
face_areas = [f.calc_area() for f in bm.faces]
if face_areas:
    max_area = max(face_areas)
    threshold = max_area * 0.75  # inset panels are noticeably smaller
    for f in bm.faces:
        if f.calc_area() < threshold:
            f.material_index = 1
        else:
            f.material_index = 0

bmesh.update_edit_mesh(crate.data)
bpy.ops.object.mode_set(mode='OBJECT')

# ─── export ───────────────────────────────────────────────────────────────────
import os
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print(f"GEN_OK: {OUTPUT}")
