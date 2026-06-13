extends MiniGameBase3D

# Pure tapping power. Tap as fast as you can — most pulls wins.
# Pure UI game: bars drawn on the 2D overlay (no 3D arena needed).

var _bg := {}
var _bar := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("TAP your button as fast as you can!", Vector2(405, 70), 26)
	var top := 200.0
	var bw := Palette.DESIGN_W - 240.0
	for i in players.size():
		var p: PlayerData = players[i]
		var y := top + i * 90.0
		_bg[p.id] = make_bar(Vector2(120, y), Vector2(bw, 56), Color(0.3, 0.3, 0.34, 0.5))
		_bar[p.id] = make_bar(Vector2(120, y), Vector2(6, 56), p.color)

func _game_process(_delta: float) -> void:
	var max_v := 1.0
	for p in players:
		if InputManager.get_action_just(p.id):
			p.round_value += 1.0
		max_v = maxf(max_v, p.round_value)
	var bw := Palette.DESIGN_W - 240.0
	for p in players:
		_bar[p.id].size.x = maxf(6.0, bw * (p.round_value / max_v))

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
