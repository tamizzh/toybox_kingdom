extends MiniGameBase3D

# Hold your button to run (+X). First across the line wins.  (3D)

var _finish_x: float
var _start_x: float
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	_start_x = -ARENA_HX + 1.5
	_finish_x = ARENA_HX - 1.0
	# finish line (green strip across Z)
	spawn_marker(Vector3(_finish_x, 0.3, 0), Vector3(0.3, 0.6, ARENA_HZ * 2), Palette.SAFE)
	spawn_avatars(lane_spawns(_start_x))
	for av in avatars.values():
		av.auto_input = false
	make_label("HOLD your button to RUN!", Vector2(430, 96), 26)

func _game_process(delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		var av = avatars[p.id]
		if InputManager.get_action(p.id):
			av.global_position.x += 7.4 * delta
			av.face(Vector2(1, 0))
		if av.global_position.x >= _finish_x:
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
