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
	"res://assets/models/tree-spreading.glb",
]
const TREE_COLORS := [Color("775123"), Color("33a23a")]  # [0]=trunk brown, [1]=foliage = the green kingdom/castle-roof green
const ROCK := preload("res://assets/models/rock.glb")

# Base caps (desktop multiplies these — see rebuild()).
const TREE_CAP := 1500
const ROCK_CAP := 520

# Forest border: trees keep going past the play grid (off-grid "apron" cells),
# dense at the board edge and thinning out into the fog. Own budget so the
# wilderness inside the board is never starved by the surround.
const APRON_CELLS    := 34   # how many cells the forest extends beyond the grid
const APRON_TREE_CAP := 2400
const APRON_ROCK_CAP := 480
const APRON_BUSH_CAP := 1100

var grid
var cell: float = 0.6

var _trees: Array = []          # Array[MultiMeshInstance3D] — one per canopy shape
var _rock: MultiMeshInstance3D

func setup(p_grid, p_cell: float) -> void:
	grid = p_grid
	cell = p_cell
	# Paint each mesh surface in code (one colour per material slot) so the props
	# are 2-tone without depending on the GLB's own material colours importing.
	for path in TREE_KINDS:
		# Flatten each tree's trunk+foliage surfaces into ONE vertex-coloured surface so
		# a whole tree variant draws in a single call (was one draw call per surface).
		var merged := _merge(_mesh_of(load(path)), TREE_COLORS)
		var mmi := _batch_vc(merged)
		_trees.append(mmi)
		add_child(mmi)
	_rock = _batch(_mesh_of(ROCK), [Color("9a9a9c")])
	add_child(_rock)

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
	return _make_mmi(mesh)

# Batch a pre-merged single-surface mesh whose base colour is baked into vertex
# colours (see _merge). One material, so the whole prop is one draw call; the
# per-instance MultiMesh colour multiplies in for brightness variation.
func _batch_vc(mesh: Mesh) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.62
	mat.vertex_color_use_as_albedo = true
	# Baked vertex colours (TREE_COLORS) are authored in sRGB; convert them to linear so the
	# foliage lands on the exact same tone as the castle roof (whose albedo_color converts too).
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	return _make_mmi(mesh)

func _make_mmi(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# AABB spans the board PLUS the forest apron so off-grid trees frustum-cull
	# correctly (a grid-only box would clip the surrounding forest away).
	var pad: float = APRON_CELLS * cell
	var fw: float = grid.w * cell + pad * 2.0
	var fz: float = grid.h * cell + pad * 2.0
	mmi.custom_aabb = AABB(Vector3(-fw * 0.5, -1.0, -fz * 0.5), Vector3(fw, 8.0, fz))
	return mmi

# Flatten a multi-surface prop into ONE surface, baking each source surface's base
# colour into vertex colours. Halves tree draw calls (trunk+foliage → one surface)
# while preserving the exact 2-tone look (same surface→colour mapping as _batch).
func _merge(mesh: Mesh, colors: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in mesh.get_surface_count():
		var base: Color = colors[mini(si, colors.size() - 1)]
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms = arrays[Mesh.ARRAY_NORMAL]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var has_norm: bool = norms != null and norms.size() == verts.size()
		if indices != null and indices.size() > 0:
			for ii in indices:
				if has_norm:
					st.set_normal(norms[ii])
				st.set_color(base)
				st.add_vertex(verts[ii])
		else:
			for vi in verts.size():
				if has_norm:
					st.set_normal(norms[vi])
				st.set_color(base)
				st.add_vertex(verts[vi])
	st.index()
	return st.commit()

# Place props on currently-neutral cells (hash-stable, capped for mobile).
func rebuild() -> void:
	if OS.get_environment("TBK_NOSCATTER") == "1":
		return
	# Desktop can afford a denser, more "alive" world than phones; phones thin the
	# forest hard (fewer instances = less vertex + overdraw cost).
	var dense: float = 0.6 if DeviceMode.is_mobile else 1.8
	var tree_cap := int(TREE_CAP * dense)
	var rock_cap := int(ROCK_CAP * dense)
	var w: int = grid.w
	var n: int = w * grid.h
	var tree_buckets: Array = []          # one transform list per canopy shape
	for _k in TREE_KINDS.size():
		tree_buckets.append([])
	var tree_total := 0
	var rocks: Array = []
	var gh: int = grid.h
	# Shore zone (within 12 cells of edge) gets more trees; interior stays sparse.
	const SHORE_DEPTH  := 12
	const TREE_SHORE   := 8    # ~0.8% of shore cells get a tree
	const TREE_INLAND  := 2    # ~0.2% of interior cells get a tree
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
		elif bucket < tree_thresh + 3 and rocks.size() < rock_cap:
			rocks.append(_xform(cx, cy, bucket, 1.0))
	# (Forest apron retired — the board is now an ISLAND ringed by open sea, so there is
	#  no off-grid land to plant. Trees only grow on the grid; the on-grid shore pass
	#  above already lines the coast densely, framing the island against the water.)
	for k in TREE_KINDS.size():
		_fill(_trees[k], tree_buckets[k], true)
	_fill(_rock, rocks, false)

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
