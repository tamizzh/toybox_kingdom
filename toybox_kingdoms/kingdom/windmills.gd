extends Node3D

# ── Windmills: an animated kingdom landmark (target_art look) ──────────────────
# A couple per kingdom, placed at stable offsets from each castle. Procedural mesh
# (tapered cream tower + kingdom-tinted cap + 4 rotating blades). Few enough (~2 ×
# kingdoms) to be individual nodes; blades spin in _process. Built once — windmills
# are landmarks, they don't move as the realm grows.

var grid
var cell: float = 0.6
var colors := {}
var _homes := {}
var _blades: Array = []          # blade-hub Node3Ds to spin
var _built := {}                 # kid -> true once its windmills exist
var _mat_cache := {}             # colour html -> shared StandardMaterial3D

# fixed offsets (in cells) from the castle so the windmills frame the keep
const OFFSETS := [Vector2i(8, 5), Vector2i(-7, 6), Vector2i(6, -7)]
const PER_KINGDOM := 2
const MIN_TIER := 2              # windmills are a Village (T2) landmark, not an Outpost's

func setup(p_grid, p_cell: float, p_colors: Dictionary, p_homes: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	_homes = p_homes

# Build each kingdom's windmills the first tick it reaches T2 (they're fixed
# landmarks, so once built they stay — never rebuilt as the realm grows).
func rebuild(tiers: Dictionary = {}) -> void:
	for kid in _homes:
		if _built.get(kid, false):
			continue
		if int(tiers.get(kid, 1)) < MIN_TIER:
			continue
		_built[kid] = true
		var home: Vector2i = _homes[kid]
		var col: Color = colors.get(kid, Color.WHITE)
		# Each windmill is ~6 separate meshes (≈6 draw calls); on web/mobile single-thread
		# that draw-call cost matters, so build one per kingdom instead of two.
		for n in mini(_per_kingdom(), OFFSETS.size()):
			var off: Vector2i = OFFSETS[n]
			var cx := clampi(home.x + off.x, 0, grid.w - 1)
			var cy := clampi(home.y + off.y, 0, grid.h - 1)
			_make_windmill(_c2w(cx, cy), col)

func _process(delta: float) -> void:
	for hub in _blades:
		hub.rotation.z += delta * 1.7

func _make_windmill(pos: Vector3, col: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# tapered cream tower
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.15
	tm.bottom_radius = 0.24
	tm.height = 0.95
	tm.radial_segments = 8
	tower.mesh = tm
	tower.material_override = _mat(Color("e9d6ad"))
	tower.position = Vector3(0, 0.55, 0)
	root.add_child(tower)
	# kingdom-tinted conical cap
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.27
	cm.height = 0.3
	cm.radial_segments = 8
	cap.mesh = cm
	cap.material_override = _mat(col)
	cap.position = Vector3(0, 1.14, 0)
	root.add_child(cap)
	# blade hub on the front face; 4 arms as pivoted children so they form a cross
	var hub := Node3D.new()
	hub.position = Vector3(0, 1.0, 0.27)
	root.add_child(hub)
	for k in 4:
		var pivot := Node3D.new()
		pivot.rotation.z = float(k) * PI * 0.5
		hub.add_child(pivot)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.52, 0.03)
		blade.mesh = bm
		blade.material_override = _mat(Color("f4ead0"))
		blade.position = Vector3(0, 0.30, 0)
		pivot.add_child(blade)
	_blades.append(hub)

func _mat(c: Color) -> StandardMaterial3D:
	# Share one material per colour (tower cream, blade cream, kingdom cap) across all
	# windmills instead of newing ~6 per windmill.
	var key := c.to_html()
	var cached = _mat_cache.get(key)
	if cached != null:
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	_mat_cache[key] = m
	return m

func _per_kingdom() -> int:
	return 1 if DeviceMode.low_gfx else PER_KINGDOM

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)

# Returns world positions of this kingdom's built windmills for road connections.
func get_road_nodes(kid: int) -> PackedVector3Array:
	if not _built.get(kid, false):
		return PackedVector3Array()
	var home: Vector2i = _homes.get(kid, Vector2i(grid.w / 2, grid.h / 2))
	var out := PackedVector3Array()
	for n in mini(_per_kingdom(), OFFSETS.size()):
		var off: Vector2i = OFFSETS[n]
		var cx := clampi(home.x + off.x, 0, grid.w - 1)
		var cy := clampi(home.y + off.y, 0, grid.h - 1)
		out.append(_c2w(cx, cy))
	return out
