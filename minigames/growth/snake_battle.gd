extends MiniGameBase3D

# Grid snakes in 3D. Steer with the stick, grow a trail of blocks, don't crash
# into walls or any trail. Last snake alive (or longest) wins.

const CELL := 1.0
const STEP := 0.12

var _cols := 0
var _rows := 0
var _origin: Vector3
var _snakes := {}
var _acc := 0.0
var _grid: Node3D

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	_cols = int(ARENA_HX * 2 / CELL)
	_rows = int(ARENA_HZ * 2 / CELL)
	_origin = Vector3(-ARENA_HX, 0, -ARENA_HZ)
	_grid = Node3D.new()
	add_child(_grid)
	var starts := [Vector2i(3, 3), Vector2i(_cols - 4, _rows - 4), Vector2i(_cols - 4, 3), Vector2i(3, _rows - 4)]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(1, 0)]
	for i in players.size():
		_snakes[players[i].id] = {"cells": [starts[i]], "dir": dirs[i], "ndir": dirs[i], "grow": 4}
	make_label("Grow & survive — don't crash!", Vector2(430, 96), 24)
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
			if s["grow"] > 0:
				s["grow"] -= 1
			else:
				s["cells"].pop_front()

func _render_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for p in players:
		if not _snakes.has(p.id):
			continue
		var col: Color = p.color if p.alive else Color(p.color, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		for c in _snakes[p.id]["cells"]:
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL * 0.85, CELL * 0.85, CELL * 0.85)
			box.mesh = bm
			box.material_override = mat
			box.position = _origin + Vector3((c.x + 0.5) * CELL, 0.45, (c.y + 0.5) * CELL)
			_grid.add_child(box)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = _snakes[p.id]["cells"].size() + (1000 if p.alive else 0)
	return rank_by_value(vals, true)
