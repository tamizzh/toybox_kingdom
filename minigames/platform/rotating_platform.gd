extends MiniGameBase3D

# A spinning disc flings you outward. Steer back to the centre. Fall off = out.
# Last one on the disc wins. (3D)

var _radius: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	_radius = ARENA_HZ - 0.5
	spawn_disc(_radius, Color(0.30, 0.32, 0.40, 0.9))
	spawn_ball(0.5, Palette.NEUTRAL)   # centre hub marker
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(Vector3(cos(ang), 0, sin(ang)) * (_radius * 0.45))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 7.0
	make_label("Stay on the spinning disc!", Vector2(445, 96), 24)

func _game_process(delta: float) -> void:
	var drift := 1.2 + elapsed * 0.12
	var spin := 0.9 + elapsed * 0.03
	for p in players:
		if not p.alive:
			continue
		var rel: Vector3 = avatars[p.id].global_position
		rel.y = 0
		var radial := rel.normalized() if rel.length() > 0.05 else Vector3.RIGHT
		var tangent := Vector3(-radial.z, 0, radial.x)
		avatars[p.id].global_position += radial * drift * delta + tangent * spin * rel.length() * delta
		if avatars[p.id].global_position.length() > _radius:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
