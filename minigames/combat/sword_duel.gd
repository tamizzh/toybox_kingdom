extends MiniGameBase

# Close-range melee. Tap to slash in your facing direction; knockback + kill.
# Last fighter standing wins.

var _facing := {}
var _cool := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		_facing[p.id] = Vector2.RIGHT
		_cool[p.id] = 0.0
		avatars[p.id].speed = 300.0
	make_label("Tap to SLASH — last alive wins!", Vector2(430, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = mv.normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 0.55
			_slash(p)

func _slash(p: PlayerData) -> void:
	avatars[p.id].pop()
	var pos: Vector2 = avatars[p.id].position
	var blade := make_rect(Rect2(-8, -8, 16, 16), Palette.ACCENT, -2)
	blade.position = pos + _facing[p.id] * 60.0
	get_tree().create_timer(0.12).timeout.connect(blade.queue_free)
	for q in players:
		if q.id == p.id or not q.alive:
			continue
		var to: Vector2 = avatars[q.id].position - pos
		if to.length() < 95.0 and to.normalized().dot(_facing[p.id]) > 0.25:
			avatars[q.id].position += _facing[p.id] * 55.0
			eliminate(q.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
