extends MiniGameBase

# Top-down tanks. Move + shoot. Last tank alive wins.

const BULLET := preload("res://shared/bullet.tscn")

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
		avatars[p.id].speed = 235.0
		# tank body stays neutral white; player colour shown as a bar beneath it
		var fig = avatars[p.id].figure
		if fig:
			fig.body_color_as_line = true
			fig.queue_redraw()
	make_label("Move + shoot — last tank alive wins!", Vector2(410, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = mv.normalized()
			var fig = avatars[p.id].figure   # turn the tank toward the joystick
			if fig:
				fig.set_face_angle(_facing[p.id].angle())
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 0.5
			_shoot(p)

func _shoot(p: PlayerData) -> void:
	var b := BULLET.instantiate()
	add_child(b)
	b.position = avatars[p.id].position + _facing[p.id] * 38.0
	b.setup(p.id, _facing[p.id], p.color, 560.0)
	b.hit_player.connect(func(target, _owner): eliminate(target))
	avatars[p.id].pop()

func _compute_results() -> Dictionary:
	return survivor_results(3)
