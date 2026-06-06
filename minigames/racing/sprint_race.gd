extends MiniGameBase

# Hold your button to run right. First across the line wins.

var _finish_x: float
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	draw_background()
	_finish_x = arena_rect.position.x + arena_rect.size.x - 70
	for i in players.size():
		var y: float = arena_rect.position.y + arena_rect.size.y * (i + 1.0) / (players.size() + 1.0)
		make_rect(Rect2(arena_rect.position.x, y - 3, arena_rect.size.x, 6), Palette.WALL, -20)
	make_rect(Rect2(_finish_x, arena_rect.position.y, 8, arena_rect.size.y), Palette.SAFE, -15)
	spawn_avatars(lane_spawns(arena_rect, arena_rect.position.x + 60))
	for av in avatars.values():
		av.auto_input = false
	make_label("HOLD your button to RUN!", Vector2(430, 118), 26)

func _game_process(delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		var av: Node = avatars[p.id]
		if InputManager.get_action(p.id):
			av.position.x += 370.0 * delta
		if av.position.x >= _finish_x:
			p.finished = true
			_order.append(p.id)
	if _order.size() >= players.size():
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var ranking := _order.duplicate()
	var rest := []
	for p in players:
		if not p.finished:
			rest.append(p)
	rest.sort_custom(func(a, b): return avatars[a.id].position.x > avatars[b.id].position.x)
	for p in rest:
		ranking.append(p.id)
	return award_by_rank(ranking)
