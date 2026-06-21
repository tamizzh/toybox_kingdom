# Headless Blender generator for low-poly environment props (tree / rock / bush).
# Each is a single joined mesh with a couple of material slots (so one MultiMesh
# instance draws the whole prop). Chunky low-poly to match the target art.
#
# Run:  blender --background --python tools/gen_props.py
import bpy, os

OUT = r"C:\Users\rpandian\Documents\toybox kingdom\assets\models"


def clear():
	bpy.ops.object.select_all(action='SELECT')
	bpy.ops.object.delete()
	for m in list(bpy.data.meshes):
		bpy.data.meshes.remove(m)
	for mat in list(bpy.data.materials):
		bpy.data.materials.remove(mat)


def mat(name, col, rough=0.9):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
	b.inputs["Roughness"].default_value = rough
	for key in ("Specular IOR Level", "Specular"):
		if key in b.inputs:
			b.inputs[key].default_value = 0.05
			break
	return m


def finalize(name):
	meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	if len(meshes) > 1:
		bpy.ops.object.join()
	o = bpy.context.active_object
	o.name = name
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
	bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"),
		export_format='GLB', use_selection=True)
	print("WROTE", name + ".glb")


# ── TREE: hex trunk + rounded foliage blob ───────────────────────────────────
clear()
brown = mat("trunk", (0.42, 0.27, 0.13))
green = mat("leaf", (0.27, 0.60, 0.24))
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=0.55, location=(0, 0, 0.27))
bpy.context.active_object.data.materials.append(brown)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0, 0, 0.95))
f = bpy.context.active_object
f.scale = (1.0, 1.0, 1.18)
f.data.materials.append(green)
finalize("tree")

# ── ROCK: squashed low-poly boulder ──────────────────────────────────────────
clear()
grey = mat("rock", (0.55, 0.55, 0.60))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.4, location=(0, 0, 0.16))
r = bpy.context.active_object
r.scale = (1.25, 1.0, 0.62)
r.data.materials.append(grey)
finalize("rock")

# ── BUSH: a few merged green blobs ───────────────────────────────────────────
clear()
bgreen = mat("bush", (0.30, 0.56, 0.24))
for dx, dy in [(0.0, 0.0), (0.22, 0.05), (-0.18, 0.12)]:
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.26, location=(dx, dy, 0.16))
	bpy.context.active_object.data.materials.append(bgreen)
finalize("bush")

print("PROPS_DONE")
