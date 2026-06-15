extends MiniGameBase3D

# Floor tiles flash then drop away. Don't be standing over a gap. Last alive wins. (3D)

const CELL := 2.0

var _cols := 0
var _rows := 0
var _origin: Vector3
var _state := {}     # Vector2i -> 0 solid, 1 warning, 2 gone
var _warn := {}
var _tiles := {}     # Vector2i -> MeshInstance3D
var _spawn_t := 1.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	_cols = int(ARENA_HX * 2 / CELL)
	_rows = int(ARENA_HZ * 2 / CELL)
	_origin = Vector3(-ARENA_HX, 0, -ARENA_HZ)
	for x in _cols:
		for y in _rows:
			var k := Vector2i(x, y)
			_state[k] = 0
			var t := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL * 0.92, 0.3, CELL * 0.92)
			t.mesh = bm
			t.material_override = StandardMaterial3D.new()
			t.position = _origin + Vector3((x + 0.5) * CELL, -0.15, (y + 0.5) * CELL)
			add_child(t)
			_tiles[k] = t
			_paint(k)
	var c := Vector2i(_cols / 2, _rows / 2)
	var spts := []
	for i in players.size():
		spts.append(_origin + Vector3((c.x + (i % 2) + 0.5) * CELL, 0, (c.y + (i / 2) + 0.5) * CELL))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 7.0
	# Instruction shown by the HUD tagline banner.

func _paint(k: Vector2i) -> void:
	var t: MeshInstance3D = _tiles[k]
	var s: int = _state[k]
	if s == 2:
		t.visible = false
		return
	t.visible = true
	(t.material_override as StandardMaterial3D).albedo_color = (Palette.ARENA_FLOOR if s == 0 else Palette.WARN)

func _game_process(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = maxf(0.12, 0.6 - elapsed * 0.012)
		var k := Vector2i(randi() % _cols, randi() % _rows)
		if _state[k] == 0:
			_state[k] = 1
			_warn[k] = 0.8
			_paint(k)
	for k in _warn.keys():
		_warn[k] -= delta
		if _warn[k] <= 0.0:
			_state[k] = 2
			_warn.erase(k)
			_paint(k)
	for p in players:
		if not p.alive:
			continue
		clamp_avatar(avatars[p.id])
		var fp: Vector3 = avatars[p.id].global_position - _origin
		var cell := Vector2i(int(fp.x / CELL), int(fp.z / CELL))
		if _state.get(cell, 2) == 2:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
