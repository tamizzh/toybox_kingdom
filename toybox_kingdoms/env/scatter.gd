extends Node3D

# ── Wilderness vegetation ────────────────────────────────────────────────────
# Scatters the Blender props (tree/rock/bush) across NEUTRAL land with a stable
# per-cell hash, so the unclaimed world reads as a lush grassland (the target
# look). One MultiMesh per prop type = 3 draw calls total. Placed once at setup;
# as kingdoms claim land the colored slab simply rises under the props.

const TREE := preload("res://assets/models/tree.glb")
const ROCK := preload("res://assets/models/rock.glb")
const BUSH := preload("res://assets/models/bush.glb")

const TREE_CAP := 2400
const ROCK_CAP := 700
const BUSH_CAP := 1600

var grid
var cell: float = 0.6

var _tree: MultiMeshInstance3D
var _rock: MultiMeshInstance3D
var _bush: MultiMeshInstance3D

func setup(p_grid, p_cell: float) -> void:
	grid = p_grid
	cell = p_cell
	# Paint each mesh surface in code (one colour per material slot) so the props
	# are 2-tone without depending on the GLB's own material colours importing.
	# The tree mesh has two surfaces: [0]=trunk, [1]=foliage (see gen_props.py).
	_tree = _batch(_mesh_of(TREE), [Color("4a3216"), Color("2e6a22")])  # dark trunk, deep-green canopy
	_rock = _batch(_mesh_of(ROCK), [Color("8a8a90")])
	_bush = _batch(_mesh_of(BUSH), [Color("2f6e26")])
	add_child(_tree)
	add_child(_rock)
	add_child(_bush)

func _mesh_of(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var mi := _find_mi(inst)
	var mesh: Mesh = null
	if mi != null:
		mesh = mi.mesh
		# GLTF import often stores materials as surface OVERRIDES on the MeshInstance3D,
		# not on the Mesh itself — bake them onto the mesh so the MultiMesh keeps them.
		for i in mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mesh.surface_get_material(i)
			if m != null:
				mesh.surface_set_material(i, m)
	inst.free()
	return mesh

func _find_mi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and n.mesh != null:
		return n
	for c in n.get_children():
		var r := _find_mi(c)
		if r != null:
			return r
	return null

func _batch(mesh: Mesh, colors: Array) -> MultiMeshInstance3D:
	# One matte material per surface (no material_override → per-surface colours
	# survive). Fewer colours than surfaces falls back to the last colour.
	for i in mesh.get_surface_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[mini(i, colors.size() - 1)]
		mat.roughness = 1.0
		mesh.surface_set_material(i, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

# Place props on currently-neutral cells (hash-stable, capped for mobile).
func rebuild() -> void:
	if OS.get_environment("TBK_NOSCATTER") == "1":
		return
	var w: int = grid.w
	var n: int = w * grid.h
	var trees: Array = []
	var rocks: Array = []
	var bushes: Array = []
	for i in n:
		if grid.owner[i] != 0:
			continue
		var bucket: int = ((i * 2654435761) & 0x7fffffff) % 1000
		var cx: int = i % w
		var cy: int = i / w
		if bucket < 42 and trees.size() < TREE_CAP:
			trees.append(_xform(cx, cy, bucket, 1.1))
		elif bucket < 50 and rocks.size() < ROCK_CAP:
			rocks.append(_xform(cx, cy, bucket, 0.8))
		elif bucket < 76 and bushes.size() < BUSH_CAP:
			bushes.append(_xform(cx, cy, bucket, 0.85))
	_fill(_tree, trees)
	_fill(_rock, rocks)
	_fill(_bush, bushes)

func _xform(cx: int, cy: int, seed: int, base: float) -> Transform3D:
	# jitter position within the cell so the wilderness doesn't read as a grid
	var h1: int = ((cx * 73856093) ^ (cy * 19349663)) & 0x7fffffff
	var h2: int = ((cx * 83492791) ^ (cy * 12582917)) & 0x7fffffff
	var jx: float = (float(h1 % 1000) / 1000.0 - 0.5) * 0.9 * cell
	var jz: float = (float(h2 % 1000) / 1000.0 - 0.5) * 0.9 * cell
	var wx: float = (cx + 0.5 - grid.w * 0.5) * cell + jx
	var wz: float = (cy + 0.5 - grid.h * 0.5) * cell + jz
	var rot: float = float(h1 % 628) / 100.0
	var s: float = base * (0.7 + float(h2 % 70) / 100.0)   # wider size variation
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s, s)), Vector3(wx, 0.05, wz))

func _fill(mmi: MultiMeshInstance3D, xforms: Array) -> void:
	var mm := mmi.multimesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
