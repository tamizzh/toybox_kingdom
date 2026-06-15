extends MiniGameBase3D

# Grid snakes in 3D. Steer with the stick, grow a trail of blocks, don't crash
# into walls or any trail. Last snake alive (or longest) wins.

const CELL := 1.0
const STEP := 0.12
const SEGMENT_SCENE := preload("res://assets/models/snake_segment.glb")
const FOOD_COUNT := 4
const GROW_PER_FOOD := 3

var _cols := 0
var _rows := 0
var _origin: Vector3
var _snakes := {}
var _acc := 0.0
var _grid: Node3D
var _food: Array = []
var _food_node: Node3D
var _spin := 0.0
var _segment_pool: Dictionary = {}
var _head_nodes: Dictionary = {}
var _food_nodes: Array[Node3D] = []

static var _segment_material_cache: Dictionary = {}
static var _head_material_cache: Dictionary = {}
static var _eye_material: StandardMaterial3D
static var _pupil_material: StandardMaterial3D
static var _head_mesh: SphereMesh
static var _eye_mesh: SphereMesh
static var _pupil_mesh: SphereMesh

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	_cols = int(ARENA_HX * 2 / CELL)
	_rows = int(ARENA_HZ * 2 / CELL)
	_origin = Vector3(-ARENA_HX, 0, -ARENA_HZ)
	_grid = Node3D.new()
	add_child(_grid)
	var starts := [Vector2i(3, 3), Vector2i(_cols - 4, _rows - 4), Vector2i(_cols - 4, 3), Vector2i(3, _rows - 4)]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(1, 0)]
	for i in players.size():
		var id: int = players[i].id
		_snakes[id] = {"cells": [starts[i]], "dir": dirs[i], "ndir": dirs[i], "grow": 4}
		_segment_pool[id] = []
	_food_node = Node3D.new()
	add_child(_food_node)
	_refill_food()
	_render_food()
	_render_grid()

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var s = _snakes[p.id]
		var mv := InputManager.get_move(p.id)
		if absf(mv.x) > absf(mv.y):
			if mv.x > 0.4 and s["dir"] != Vector2i(-1, 0):
				s["ndir"] = Vector2i(1, 0)
			elif mv.x < -0.4 and s["dir"] != Vector2i(1, 0):
				s["ndir"] = Vector2i(-1, 0)
		else:
			if mv.y > 0.4 and s["dir"] != Vector2i(0, -1):
				s["ndir"] = Vector2i(0, 1)
			elif mv.y < -0.4 and s["dir"] != Vector2i(0, 1):
				s["ndir"] = Vector2i(0, -1)
	_acc += delta
	if _acc >= STEP:
		_acc = 0.0
		_step_snakes()
		_render_grid()
	if _food_node:
		_spin += delta * 2.2
		for star in _food_nodes:
			if star.visible:
				star.rotation.y = _spin

func _step_snakes() -> void:
	var occ := {}
	for p in players:
		if p.alive:
			for c in _snakes[p.id]["cells"]:
				occ[c] = true
	var heads := {}
	for p in players:
		if p.alive:
			var s = _snakes[p.id]
			s["dir"] = s["ndir"]
			heads[p.id] = s["cells"][s["cells"].size() - 1] + s["dir"]
	for p in players:
		if not p.alive:
			continue
		var h: Vector2i = heads[p.id]
		var dead := h.x < 0 or h.y < 0 or h.x >= _cols or h.y >= _rows or occ.has(h)
		if not dead:
			for q in players:
				if q.id != p.id and q.alive and heads.get(q.id) == h:
					dead = true
		if dead:
			eliminate(p.id)
		else:
			var s = _snakes[p.id]
			s["cells"].append(h)
			var fi := _food.find(h)
			if fi != -1:
				_food.remove_at(fi)
				s["grow"] += GROW_PER_FOOD
				AudioManager.play("collect", randf_range(0.95, 1.1))
			if s["grow"] > 0:
				s["grow"] -= 1
			else:
				s["cells"].pop_front()
	if _food.size() < FOOD_COUNT:
		_refill_food()
		_render_food()

func _render_grid() -> void:
	for p in players:
		if not _snakes.has(p.id):
			continue
		var col: Color = p.color if p.alive else Color(p.color, 0.35)
		var cells: Array = _snakes[p.id]["cells"]
		var game_dir: Vector2i = _snakes[p.id]["dir"]
		var pool: Array = _segment_pool[p.id]
		var body_count := maxi(cells.size() - 1, 0)
		while pool.size() < body_count:
			var inst := SEGMENT_SCENE.instantiate()
			_tint_segment(inst, col)
			inst.visible = false
			_grid.add_child(inst)
			pool.append(inst)
		for i in pool.size():
			var seg: Node3D = pool[i]
			if i < body_count:
				var cell: Vector2i = cells[i]
				seg.visible = true
				seg.position = _origin + Vector3((cell.x + 0.5) * CELL, CELL * 0.425, (cell.y + 0.5) * CELL)
				_tint_segment(seg, col)
			else:
				seg.visible = false
		var head: Node3D = _head_nodes.get(p.id)
		if not head:
			head = _build_head(col)
			_head_nodes[p.id] = head
			_grid.add_child(head)
		var head_cell: Vector2i = cells[cells.size() - 1]
		head.visible = true
		head.position = _origin + Vector3((head_cell.x + 0.5) * CELL, 0.5, (head_cell.y + 0.5) * CELL)
		head.rotation.y = atan2(-float(game_dir.y), float(game_dir.x))
		_set_head_color(head, col)

func _refill_food() -> void:
	while _food.size() < FOOD_COUNT:
		var c := _random_empty_cell()
		if c.x < 0:
			break
		_food.append(c)

func _random_empty_cell() -> Vector2i:
	var taken := {}
	for p in players:
		if _snakes.has(p.id):
			for c in _snakes[p.id]["cells"]:
				taken[c] = true
	for f in _food:
		taken[f] = true
	for _try in 60:
		var c := Vector2i(randi() % _cols, randi() % _rows)
		if not taken.has(c):
			return c
	return Vector2i(-1, -1)

func _render_food() -> void:
	if not _food_node:
		return
	while _food_nodes.size() < _food.size():
		var star := ArenaProps3D.star()
		star.rotation.x = PI * 0.5
		_food_node.add_child(star)
		_food_nodes.append(star)
	for i in _food_nodes.size():
		var star: Node3D = _food_nodes[i]
		if i < _food.size():
			var cell: Vector2i = _food[i]
			star.visible = true
			star.position = _origin + Vector3((cell.x + 0.5) * CELL, 0.55, (cell.y + 0.5) * CELL)
		else:
			star.visible = false

func _tint_segment(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _segment_material(color)
	for child in node.get_children():
		_tint_segment(child, color)

func _build_head(color: Color) -> Node3D:
	var root := Node3D.new()
	var head := MeshInstance3D.new()
	head.mesh = _shared_head_mesh()
	head.material_override = _head_material(color)
	root.add_child(head)
	for sy in [-0.24, 0.24]:
		var ew := MeshInstance3D.new()
		ew.mesh = _shared_eye_mesh()
		ew.material_override = _white_eye_material()
		ew.position = Vector3(0.42, 0.22, sy)
		root.add_child(ew)
		var pu := MeshInstance3D.new()
		pu.mesh = _shared_pupil_mesh()
		pu.material_override = _dark_pupil_material()
		pu.position = Vector3(0.55, 0.20, sy)
		root.add_child(pu)
	return root

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = _snakes[p.id]["cells"].size() + (1000 if p.alive else 0)
	return rank_by_value(vals, true)

func _set_head_color(head_root: Node3D, color: Color) -> void:
	if head_root.get_child_count() == 0:
		return
	var head := head_root.get_child(0)
	if head is MeshInstance3D:
		head.material_override = _head_material(color)

func _segment_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _segment_material_cache.has(key):
		return _segment_material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_segment_material_cache[key] = mat
	return mat

func _head_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _head_material_cache.has(key):
		return _head_material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_head_material_cache[key] = mat
	return mat

func _white_eye_material() -> StandardMaterial3D:
	if not _eye_material:
		_eye_material = StandardMaterial3D.new()
		_eye_material.albedo_color = Color.WHITE
		_eye_material.roughness = 0.1
	return _eye_material

func _dark_pupil_material() -> StandardMaterial3D:
	if not _pupil_material:
		_pupil_material = StandardMaterial3D.new()
		_pupil_material.albedo_color = Color(0.05, 0.04, 0.10)
	return _pupil_material

func _shared_head_mesh() -> SphereMesh:
	if not _head_mesh:
		_head_mesh = SphereMesh.new()
		_head_mesh.radius = 0.55
		_head_mesh.height = 1.1
	return _head_mesh

func _shared_eye_mesh() -> SphereMesh:
	if not _eye_mesh:
		_eye_mesh = SphereMesh.new()
		_eye_mesh.radius = 0.17
		_eye_mesh.height = 0.34
	return _eye_mesh

func _shared_pupil_mesh() -> SphereMesh:
	if not _pupil_mesh:
		_pupil_mesh = SphereMesh.new()
		_pupil_mesh.radius = 0.09
		_pupil_mesh.height = 0.18
	return _pupil_mesh
