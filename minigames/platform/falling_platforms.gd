extends MiniGameBase

# Floor tiles flash then drop away. Don't be standing over a gap. Last alive wins.

const CELL := 74.0

var _cols := 0
var _rows := 0
var _origin: Vector2
var _state := {}    # Vector2i -> 0 solid, 1 warning, 2 gone
var _warn := {}     # Vector2i -> time left as warning
var _spawn_t := 1.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	_cols = int(arena_rect.size.x / CELL)
	_rows = int(arena_rect.size.y / CELL)
	_origin = arena_rect.position
	for x in _cols:
		for y in _rows:
			_state[Vector2i(x, y)] = 0
	var c := Vector2i(_cols / 2, _rows / 2)
	var spts := []
	for i in players.size():
		spts.append(_origin + Vector2(c.x + (i % 2), c.y + (i / 2)) * CELL + Vector2(CELL, CELL) * 0.5)
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 320.0
	make_label("Tiles are falling — keep off the gaps!", Vector2(400, 116), 24)

func _game_process(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = maxf(0.12, 0.6 - elapsed * 0.012)
		var k := Vector2i(randi() % _cols, randi() % _rows)
		if _state[k] == 0:
			_state[k] = 1
			_warn[k] = 0.8
	for k in _warn.keys():
		_warn[k] -= delta
		if _warn[k] <= 0.0:
			_state[k] = 2
			_warn.erase(k)
	for p in players:
		if not p.alive:
			continue
		clamp_avatar(avatars[p.id])
		var cell := Vector2i(int((avatars[p.id].position.x - _origin.x) / CELL), int((avatars[p.id].position.y - _origin.y) / CELL))
		if _state.get(cell, 2) == 2:
			eliminate(p.id)
	queue_redraw()

func _draw() -> void:
	for k in _state.keys():
		var s: int = _state[k]
		if s == 2:
			continue
		var col := Palette.ARENA_FLOOR if s == 0 else Palette.WARN
		draw_rect(Rect2(_origin + Vector2(k.x, k.y) * CELL + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), col)

func _compute_results() -> Dictionary:
	return survivor_results(3)
