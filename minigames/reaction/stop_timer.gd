extends MiniGameBase3D

# A marker sweeps the bar. Tap to lock it as close to the target as you can.
# Closest each round scores. (UI on the 2D overlay)

const X0 := 120.0
const Y := 360.0

var _pos := 0.0
var _target := 0.5
var _tapped := {}
var _lockpos := {}
var _cooling := false
var _w := 0.0
var _target_node: ColorRect
var _sweep_node: ColorRect
var _lock_nodes: Array = []

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("Tap to STOP the marker on the target!", Vector2(390, 96), 22)
	_w = Palette.DESIGN_W - 240.0
	make_bar(Vector2(X0, Y - 18), Vector2(_w, 36), Color(0.3, 0.3, 0.34, 0.45))
	_target_node = make_bar(Vector2(0, Y - 40), Vector2(12, 80), Palette.SAFE)
	_sweep_node = make_bar(Vector2(0, Y - 30), Vector2(8, 60), Palette.ACCENT)
	_new_round()

func _new_round() -> void:
	_tapped = {}
	_lockpos = {}
	_target = randf_range(0.2, 0.8)
	for n in _lock_nodes:
		n.queue_free()
	_lock_nodes = []

func _game_process(_delta: float) -> void:
	_pos = (sin(elapsed * 2.2) + 1.0) * 0.5
	_target_node.position.x = X0 + _w * _target - 6
	_sweep_node.position.x = X0 + _w * _pos - 4
	if not _cooling:
		for p in players:
			if not _tapped.get(p.id, false) and InputManager.get_action_just(p.id):
				_tapped[p.id] = true
				_lockpos[p.id] = _pos
				var lk := make_bar(Vector2(X0 + _w * _pos - 3, Y - 14), Vector2(6, 28), p.color)
				_lock_nodes.append(lk)
		if _tapped.size() >= players.size():
			_award()

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

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
