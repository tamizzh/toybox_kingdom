# tbk_lib.py — shared toolkit for Toybox Kingdoms headless Blender generators.
#
# The whole art style hangs off three rules this module enforces:
#   1. Every asset is ONE joined mesh (so Godot draws it as a single MultiMesh).
#   2. Every edge is BEVELLED — rounded edges are what make a cube read as a
#      painted wooden toy instead of a Minecraft block (the close-up "blocky"
#      look came from raw cubes; bevel() is the fix).
#   3. Detail is silhouette + flat colour zones, never texture. A grayscale
#      "zone" vertex-colour channel lets Godot tint trunk≠foliage from one mesh.
#
# Import from a generator:
#     import bpy, sys, os
#     sys.path.append(os.path.dirname(__file__)); import tbk_lib as T
#
# Z is up in Blender; the glTF exporter converts to Y-up for Godot.
import bpy, os

ROOT = r"C:\Users\rpandian\Documents\toybox kingdom"
MODELS = os.path.join(ROOT, "assets", "models")


def reset():
	"""Wipe the scene + orphan data so each generator starts clean."""
	bpy.ops.object.select_all(action='SELECT')
	bpy.ops.object.delete()
	for col in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
		for it in list(col):
			col.remove(it)


# ── primitives (return the active object) ────────────────────────────────────
def box(sx, sy, sz, x, y, z):
	bpy.ops.mesh.primitive_cube_add(location=(x, y, z))
	o = bpy.context.active_object
	o.scale = (sx, sy, sz)
	bpy.ops.object.transform_apply(scale=True)
	return o


def cyl(r, depth, x, y, z, verts=10):
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=(x, y, z))
	return bpy.context.active_object


def cone(r1, depth, x, y, z, verts=8, r2=0.0):
	bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=(x, y, z))
	return bpy.context.active_object


def ico(r, x, y, z, subdiv=1):
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=(x, y, z))
	return bpy.context.active_object


def prism(sx, sy, sz, x=0, y=0, z=0):
	"""Triangular prism (gable roof). sx=width, sy=depth (ridge runs along Y), sz=height.
	Mesh is centered at (x,y,z). Use bevel() after to round the ridge and eave edges."""
	import bmesh as _bm
	mesh_data = bpy.data.meshes.new("prism_mesh")
	bm = _bm.new()
	hw, hd, hh = sx / 2, sy / 2, sz / 2
	# 4 base corners + 2 ridge points
	v = [
		bm.verts.new((-hw, -hd, -hh)),  # 0 front-left base
		bm.verts.new(( hw, -hd, -hh)),  # 1 front-right base
		bm.verts.new(( hw,  hd, -hh)),  # 2 back-right base
		bm.verts.new((-hw,  hd, -hh)),  # 3 back-left base
		bm.verts.new((  0, -hd,  hh)),  # 4 front ridge
		bm.verts.new((  0,  hd,  hh)),  # 5 back ridge
	]
	bm.faces.new([v[1], v[0], v[4]])         # front gable
	bm.faces.new([v[3], v[2], v[5]])         # back gable
	bm.faces.new([v[0], v[3], v[5], v[4]])  # left slope
	bm.faces.new([v[2], v[1], v[4], v[5]])  # right slope
	bm.faces.new([v[3], v[0], v[1], v[2]])  # bottom (closed for clean bevel)
	bm.to_mesh(mesh_data)
	bm.free()
	mesh_data.update()
	obj = bpy.data.objects.new("prism", mesh_data)
	bpy.context.collection.objects.link(obj)
	obj.location = (x, y, z)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.transform_apply(location=True)
	return obj


# ── the toybox ingredients ───────────────────────────────────────────────────
def bevel(obj, width=0.03, segments=2, angle=0.7):
	"""Round the sharp edges. ANGLE limit keeps large flat faces flat so only
	the silhouette edges soften — the toy-paint look. Applied immediately."""
	bpy.ops.object.select_all(action='DESELECT')
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	m = obj.modifiers.new("bev", 'BEVEL')
	m.width = width
	m.segments = segments
	m.limit_method = 'ANGLE'
	m.angle_limit = angle
	bpy.ops.object.modifier_apply(modifier=m.name)
	bpy.ops.object.shade_smooth()


def smooth(obj):
	"""Smooth-shade without adding geometry. Use for sphere-based organic props
	(foliage / rock / bush) that are already round — bevelling them just bloats
	the mesh for no silhouette gain."""
	bpy.ops.object.select_all(action='DESELECT')
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.shade_smooth()


def mat(name, col, rough=0.85, spec=0.08):
	"""Matte painted-toy material. col = (r,g,b) 0..1."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
	b.inputs["Roughness"].default_value = rough
	for k in ("Specular IOR Level", "Specular"):
		if k in b.inputs:
			b.inputs[k].default_value = spec
			break
	return m


# ── assembly + export ────────────────────────────────────────────────────────
def join(objs, name):
	"""Join a list of mesh objects into one, named `name`. Materials already on
	the objects are preserved as separate surfaces."""
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1:
		bpy.ops.object.join()
	o = bpy.context.active_object
	o.name = name
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
	return o


def export(name):
	"""Export every mesh in the scene as MODELS/<name>.glb."""
	path = os.path.join(MODELS, name + ".glb")
	os.makedirs(MODELS, exist_ok=True)
	bpy.ops.object.select_all(action='SELECT')
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
		export_apply=True)
	print("WROTE", name + ".glb")
	return path
