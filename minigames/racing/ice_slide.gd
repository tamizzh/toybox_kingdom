extends MiniGameBase

# Slippery top-down race. Momentum makes steering tricky. First to the line wins.

var _finish_x: float
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	draw_background()
	add_child(WallArena.build(arena_rect))
	_finish_x = arena_rect.position.x + arena_rect.size.x - 90
	make_rect(Rect2(_finish_x, arena_rect.position.y, 10, arena_rect.size.y), Palette.SAFE, -15)
	spawn_avatars(lane_spawns(arena_rect, arena_rect.position.x + 70))
	for av in avatars.values():
		av.momentum = 700.0
		av.acceleration = 900.0
		av.speed = 420.0
	make_label("Slippery! Steer to the green line.", Vector2(420, 116), 24)

func _game_process(_delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		if avatars[p.id].position.x >= _finish_x:
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
