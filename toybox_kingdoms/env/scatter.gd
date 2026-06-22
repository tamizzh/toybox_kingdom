extends Node3D

# ── Wilderness vegetation ────────────────────────────────────────────────────
# Scatters the Blender props (six tree shapes / rock / bush) across NEUTRAL land
# with a stable per-cell hash, so the unclaimed world reads as a lush, VARIED
# grassland (the target look). One MultiMesh per variant = ~8 draw calls total.
# Placed once at setup; as kingdoms claim land the colored slab rises under them.

# Six canopy shapes — all share [0]=trunk, [1]=foliage, so one colour pair fits
# every one. Mixing them is what makes the forest read as alive, not stamped.
const TREE_KINDS := [
	"res://assets/models/tree-round.glb",
	"res://assets/models/tree-conical.glb",
	"res://assets/models/tree-oval.glb",
	"res://assets/models/tree-pyramidal.glb",
	"res://assets/models/tree-spreading.glb",
	"res://assets/models/tree-vase.glb",
]
const TREE_COLORS := [Color("775123"), Color("3f8d2a")]
const ROCK := preload("res://assets/models/rock.glb")
const BUSH := preload("res://assets/models/bush.glb")

# Base caps (desktop multiplies these — see rebuild()).
const TREE_CAP := 1500
const ROCK_CAP := 520
const BUSH_CAP := 900

var grid
var cell: float = 0.6

var _trees: Array = []          # Array[MultiMeshInstance3D] — one per canopy shape
var _rock: MultiMeshInstance3D
var _bush: MultiMeshInstance3D

func setup(p_grid, p_cell: float) -> void:
	grid = p_grid
	cell = p_cell
	# Paint each mesh surface in code (one colour per material slot) so the props
	# are 2-tone without depending on the GLB's own material colours importing.
	for path in TREE_KINDS:
		var mmi := _batch(_mesh_of(load(path)), TREE_COLORS)
		_trees.append(mmi)
		add_child(mmi)
	_rock = _batch(_mesh_of(ROCK), [Color("9a9a9c")])
	_bush = _batch(_mesh_of(BUSH), [Color("4f9b30")])
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
	# vertex_color_use_as_albedo lets the per-instance MultiMesh colour modulate
	# each prop's brightness (subtle canopy variation — see _fill).
	for i in mesh.get_surface_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[mini(i, colors.size() - 1)]
		mat.roughness = 0.62
		mat.vertex_color_use_as_albedo = true
		mesh.surface_set_material(i, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# whole-map AABB so each batch frustum-culls instead of always drawing.
	var wx: float = grid.w * cell
	var wz: float = grid.h * cell
	mmi.custom_aabb = AABB(Vector3(-wx * 0.5, -1.0, -wz * 0.5), Vector3(wx, 8.0, wz))
	return mmi

# Place props on currently-neutral cells (hash-stable, capped for mobile).
func rebuild() -> void:
	if OS.get_environment("TBK_NOSCATTER") == "1":
		return
	# Desktop can afford a denser, more "alive" world than phones.
	var dense: float = 1.0 if DeviceMode.is_mobile else 1.8
	var tree_cap := int(TREE_CAP * dense)
	var rock_cap := int(ROCK_CAP * dense)
	var bush_cap := int(BUSH_CAP * dense)
	var w: int = grid.w
	var n: int = w * grid.h
	var tree_buckets: Array = []          # one transform list per canopy shape
	for _k in TREE_KINDS.size():
		tree_buckets.append([])
	var tree_total := 0
	var rocks: Array = []
	var bushes: Array = []
	var gh: int = grid.h
	# Shore zone (within 12 cells of edge) gets more trees; interior stays sparse.
	const SHORE_DEPTH  := 12
	const TREE_SHORE   := 16   # ~1.6% of shore cells get a tree
	const TREE_INLAND  := 4    # ~0.4% of interior cells get a tree
	for i in n:
		if grid.owner[i] != 0:
			continue
		var cx: int = i % w
		var cy: int = i / w
		var edge_dist: int = mini(mini(cx, w - 1 - cx), mini(cy, gh - 1 - cy))
		var tree_thresh: int = TREE_SHORE if edge_dist <= SHORE_DEPTH else TREE_INLAND
		var bucket: int = ((i * 2654435761) & 0x7fffffff) % 1000
		if bucket < tree_thresh and tree_total < tree_cap:
			# scatter across the six shapes by a separate spatial hash
			var kind: int = (((cx * 49157) ^ (cy * 98317)) & 0x7fffffff) % TREE_KINDS.size()
			tree_buckets[kind].append(_xform(cx, cy, bucket, 0.58))
			tree_total += 1
		elif bucket < tree_thresh + 10 and rocks.size() < rock_cap:
			rocks.append(_xform(cx, cy, bucket, 1.0))
		elif bucket < tree_thresh + 20 and bushes.size() < bush_cap:
			bushes.append(_xform(cx, cy, bucket, 1.08))
	for k in TREE_KINDS.size():
		_fill(_trees[k], tree_buckets[k], true)
	_fill(_rock, rocks, false)
	_fill(_bush, bushes, true)

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

func _fill(mmi: MultiMeshInstance3D, xforms: Array, jitter: bool) -> void:
	var mm := mmi.multimesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if jitter:
			# subtle per-prop brightness so the canopy isn't a flat green sheet
			var h: int = (k * 2246822519) & 0xff
			var v: float = 0.88 + float(h) / 255.0 * 0.22   # 0.88..1.10
			mm.set_instance_color(k, Color(v, v, v))
		else:
			mm.set_instance_color(k, Color.WHITE)
