extends MiniGameBase3D

# Dodge the bouncing blocks. One touch and you're out. Last alive wins. (3D)

var _blocks: Array = []

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.8
	var count := 3 + players.size()
	for i in count:
		var sz := randf_range(0.9, 1.6)
		var node := spawn_marker(Vector3.ZERO, Vector3(sz, sz, sz), Palette.DANGER, true)
		_blocks.append({
			"pos": Vector3(randf_range(-ARENA_HX + 2, ARENA_HX - 2), 0.5, randf_range(-ARENA_HZ + 2, ARENA_HZ - 2)),
			"vel": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.0, 5.0),
			"r": sz * 0.5,
			"node": node,
		})
	make_label("Dodge the red blocks — survive!", Vector2(430, 96), 24)

func _game_process(delta: float) -> void:
	for b in _blocks:
		b["pos"] += b["vel"] * delta
		var r: float = b["r"]
		if b["pos"].x - r < -ARENA_HX or b["pos"].x + r > ARENA_HX:
			b["vel"].x = -b["vel"].x
		if b["pos"].z - r < -ARENA_HZ or b["pos"].z + r > ARENA_HZ:
			b["vel"].z = -b["vel"].z
		b["pos"].x = clampf(b["pos"].x, -ARENA_HX + r, ARENA_HX - r)
		b["pos"].z = clampf(b["pos"].z, -ARENA_HZ + r, ARENA_HZ - r)
		b["node"].position = b["pos"]
		for p in players:
			if p.alive and avatars[p.id].global_position.distance_to(b["pos"]) < b["r"] + 0.7:
				eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
