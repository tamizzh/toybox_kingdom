extends MiniGameBase3D

# Watch the arrow sequence, then repeat it with your stick. First to finish the
# current sequence scores; the sequence grows. (UI on the 2D overlay)

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _seq: Array = []
var _phase := "show"
var _show_i := 0
var _show_t := 0.0
var _progress := {}
var _ready := {}
var _msg: Label

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("Watch the arrows, then repeat with your stick!", Vector2(355, 96), 22)
	_msg = make_label("", Vector2(600, 280), 120, Palette.ACCENT)
	_grow_and_show()

func _grow_and_show() -> void:
	_seq.append(DIRS[randi() % 4])
	_phase = "show"
	_show_i = 0
	_show_t = 0.5
	for p in players:
		_progress[p.id] = 0
		_ready[p.id] = true
	_msg.text = "WATCH"

func _game_process(delta: float) -> void:
	match _phase:
		"show":
			_show_t -= delta
			if _show_t <= 0.0:
				if _show_i < _seq.size():
					_msg.text = _arrow(_seq[_show_i])
					_show_i += 1
					_show_t = 0.65
				else:
					_msg.text = "GO"
					_phase = "input"
		"input":
			for p in players:
				var d := _dir_of(InputManager.get_move(p.id))
				if d == Vector2i.ZERO:
					_ready[p.id] = true
				elif _ready[p.id]:
					_ready[p.id] = false
					if d == _seq[_progress[p.id]]:
						_progress[p.id] += 1
						if _progress[p.id] >= _seq.size():
							p.round_value += 1.0
							_phase = "cool"
							_msg.text = "%s!" % p.display_name
							_cool_then_next()
							break
					else:
						_progress[p.id] = 0

func _cool_then_next() -> void:
	await get_tree().create_timer(1.0).timeout
	if not _finished:
		_grow_and_show()

func _dir_of(mv: Vector2) -> Vector2i:
	if mv.length() < 0.6:
		return Vector2i.ZERO
	if absf(mv.x) > absf(mv.y):
		return Vector2i(int(sign(mv.x)), 0)
	return Vector2i(0, int(sign(mv.y)))

func _arrow(d: Vector2i) -> String:
	if d == Vector2i(1, 0):
		return ">"
	if d == Vector2i(-1, 0):
		return "<"
	if d == Vector2i(0, 1):
		return "v"
	return "^"

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
