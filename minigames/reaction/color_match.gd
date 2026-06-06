extends MiniGameBase

# A box flashes a player color. Tap only when it's YOUR color. Right = +1,
# wrong = -1. Highest score wins.

var _cur: int = 0
var _t := 1.2

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	make_label("Tap ONLY when the box is YOUR color!", Vector2(390, 116), 22)
	_pick()

func _pick() -> void:
	_cur = players[randi() % players.size()].id
	_t = randf_range(0.8, 1.5)

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
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(440, 250, 400, 200), Palette.player_color(_cur))

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
