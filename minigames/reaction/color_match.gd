extends MiniGameBase3D

# A box flashes a player color. Tap only when it's YOUR color. Right +1, wrong -1.
# Highest score wins. (UI on the 2D overlay)

var _cur: int = 0
var _t := 1.2
var _box: ColorRect

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("Tap ONLY when the box is YOUR color!", Vector2(390, 96), 22)
	_box = make_bar(Vector2(440, 250), Vector2(400, 200), Color.WHITE)
	_pick()

func _pick() -> void:
	_cur = players[randi() % players.size()].id
	_t = randf_range(0.8, 1.5)
	if _box:
		_box.color = Palette.player_color(_cur)

func _game_process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_pick()
	for p in players:
		if InputManager.get_action_just(p.id):
			if p.id == _cur:
				p.round_value += 1.0
			else:
				p.round_value = maxf(0.0, p.round_value - 1.0)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
