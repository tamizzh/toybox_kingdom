extends MiniGameBase3D

# Slippery top-down race. Momentum makes steering tricky. First to the line (+X) wins. (3D)

var _finish_x: float
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	add_child(build_arena())
	_finish_x = ARENA_HX - 1.2
	spawn_marker(Vector3(_finish_x, 0.3, 0), Vector3(0.3, 0.6, ARENA_HZ * 2), Palette.SAFE)
	spawn_avatars(lane_spawns(-ARENA_HX + 1.5))
	for av in avatars.values():
		av.momentum = 14.0
		av.acceleration = 18.0
		av.speed = 9.0
	make_label("Slippery! Steer to the green line.", Vector2(420, 96), 24)

func _game_process(_delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		if avatars[p.id].global_position.x >= _finish_x:
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
	rest.sort_custom(func(a, b): return avatars[a.id].global_position.x > avatars[b.id].global_position.x)
	for p in rest:
		ranking.append(p.id)
	return award_by_rank(ranking)
