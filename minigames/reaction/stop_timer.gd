extends MiniGameBase

# A marker sweeps the bar. Tap to lock it as close to the target as you can.
# Closest each round scores. Most round wins takes it.

var _pos := 0.0
var _target := 0.5
var _tapped := {}
var _lockpos := {}
var _cooling := false

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	make_label("Tap to STOP the marker on the target!", Vector2(390, 116), 22)
	_new_round()

func _new_round() -> void:
	_tapped = {}
	_lockpos = {}
	_target = randf_range(0.2, 0.8)

func _game_process(_delta: float) -> void:
	_pos = (sin(elapsed * 2.2) + 1.0) * 0.5
	if not _cooling:
		for p in players:
			if not _tapped.get(p.id, false) and InputManager.get_action_just(p.id):
				_tapped[p.id] = true
				_lockpos[p.id] = _pos
		if _tapped.size() >= players.size():
			_award()
	queue_redraw()

func _award() -> void:
	_cooling = true
	var best := -1
	var bd := 999.0
	for p in players:
		var d: float = absf(_lockpos.get(p.id, 1.0) - _target)
		if d < bd:
			bd = d
			best = p.id
	if best >= 0:
		_player(best).round_value += 1.0
	_cool_then_new()

func _cool_then_new() -> void:
	await get_tree().create_timer(1.0).timeout
	_cooling = false
	if not _finished:
		_new_round()

func _draw() -> void:
	var x0 := arena_rect.position.x + 90.0
	var w := arena_rect.size.x - 180.0
	var y := arena_rect.position.y + arena_rect.size.y * 0.5
	draw_rect(Rect2(x0, y - 18, w, 36), Color(Palette.WALL, 0.4))
	draw_rect(Rect2(x0 + w * _target - 6, y - 40, 12, 80), Palette.SAFE)
	draw_rect(Rect2(x0 + w * _pos - 4, y - 30, 8, 60), Palette.ACCENT)
	for p in players:
		if _lockpos.has(p.id):
			draw_rect(Rect2(x0 + w * _lockpos[p.id] - 3, y - 14, 6, 28), p.color)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
