extends MiniGameBase3D

# Close-range melee in 3D. Tap to slash in your facing direction; knockback + kill.
# Last fighter standing wins.

var _facing := {}
var _cool := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_facing[p.id] = Vector3(1, 0, 0)
		_cool[p.id] = 0.0
		avatars[p.id].speed = 7.0
	make_label("Tap to SLASH — last alive wins!", Vector2(430, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 0.55
			_slash(p)

func _slash(p: PlayerData) -> void:
	var av = avatars[p.id]
	av.pop()
	var pos: Vector3 = av.global_position
	var blade := spawn_marker(pos + _facing[p.id] * 1.7 + Vector3(0, 0.8, 0),
		Vector3(0.7, 0.7, 0.7), Palette.ACCENT, true)
	get_tree().create_timer(0.12).timeout.connect(blade.queue_free)
	for q in players:
		if q.id == p.id or not q.alive:
			continue
		var to: Vector3 = avatars[q.id].global_position - pos
		if to.length() < 3.6 and to.normalized().dot(_facing[p.id]) > 0.25:
			avatars[q.id].global_position += _facing[p.id] * 2.3
			eliminate(q.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
