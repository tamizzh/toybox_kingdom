extends MiniGameBase

# Pure tapping power. Tap as fast as you can — most pulls wins.

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	make_label("TAP your button as fast as you can!", Vector2(405, 116), 26)

func _game_process(_delta: float) -> void:
	for p in players:
		if InputManager.get_action_just(p.id):
			p.round_value += 1.0
	queue_redraw()

func _draw() -> void:
	var n := players.size()
	var top := arena_rect.position.y + 40.0
	var max_v := 1.0
	for p in players:
		max_v = maxf(max_v, p.round_value)
	for i in n:
		var p: PlayerData = players[i]
		var y := top + i * 90.0
		var w := (arena_rect.size.x - 120.0) * (p.round_value / max_v)
		draw_rect(Rect2(arena_rect.position.x + 60, y, arena_rect.size.x - 120, 56), Color(Palette.WALL, 0.3))
		draw_rect(Rect2(arena_rect.position.x + 60, y, maxf(6.0, w), 56), p.color)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
