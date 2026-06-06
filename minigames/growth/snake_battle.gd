extends MiniGameBase

# Grid snakes. Steer with the stick, grow a trail, don't crash into walls or
# any trail. Last snake alive (or longest) wins.

const CELL := 28.0
const STEP := 0.12

var _cols := 0
var _rows := 0
var _origin: Vector2
var _snakes := {}
var _acc := 0.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_cols = int(arena_rect.size.x / CELL)
	_rows = int(arena_rect.size.y / CELL)
	_origin = arena_rect.position
	var starts := [Vector2i(3, 3), Vector2i(_cols - 4, _rows - 4), Vector2i(_cols - 4, 3), Vector2i(3, _rows - 4)]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(1, 0)]
	for i in players.size():
		_snakes[players[i].id] = {"cells": [starts[i]], "dir": dirs[i], "ndir": dirs[i], "grow": 4}
	make_label("Grow & survive — don't crash!", Vector2(430, 116), 24)

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
	queue_redraw()

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

func _draw() -> void:
	for p in players:
		if not _snakes.has(p.id):
			continue
		var col: Color = p.color if p.alive else Color(p.color, 0.3)
		for c in _snakes[p.id]["cells"]:
			draw_rect(Rect2(_origin + Vector2(c.x, c.y) * CELL + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), col)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = _snakes[p.id]["cells"].size() + (1000 if p.alive else 0)
	return rank_by_value(vals, true)
