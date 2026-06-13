extends MiniGameBase3D

# Shove rivals out of the ring. Off the edge = out. Last sumo standing wins. (3D)

var _ring: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	_ring = ARENA_HZ - 0.5
	spawn_disc(_ring, Color(0.30, 0.32, 0.40, 0.6))
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(Vector3(cos(ang), 0, sin(ang)) * (_ring * 0.55))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 7.2
	make_label("Push rivals out of the ring!", Vector2(440, 96), 24)

func _game_process(delta: float) -> void:
	var ids := []
	for p in players:
		if p.alive:
			ids.append(p.id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a = avatars[ids[i]]
			var b = avatars[ids[j]]
			var diff: Vector3 = b.global_position - a.global_position
			diff.y = 0
			var dist := diff.length()
			if dist < 1.5 and dist > 0.05:
				var dir := diff / dist
				var closing := maxf(0.0, (a.velocity - b.velocity).dot(dir))
				var force := closing * delta * 0.6 + (1.5 - dist) * 0.5
				b.global_position += dir * force
				a.global_position -= dir * force
	for p in players:
		if not p.alive:
			continue
		var fp := avatars[p.id].global_position
		fp.y = 0
		if fp.length() > _ring:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
