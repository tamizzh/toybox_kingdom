extends MiniGameBase

# Dodge the bouncing blocks. One touch and you're out. Last alive wins.

var _blocks: Array = []

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].speed = 310.0
	var count := 3 + players.size()
	for i in count:
		var sz := randf_range(40.0, 70.0)
		var node := make_rect(Rect2(0, 0, sz, sz), Palette.DANGER, -4)
		_blocks.append({
			"pos": arena_rect.position + Vector2(randf_range(120, arena_rect.size.x - 120), randf_range(120, arena_rect.size.y - 120)),
			"vel": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(140, 240),
			"r": sz * 0.5,
			"node": node,
		})
	make_label("Dodge the red blocks — survive!", Vector2(430, 116), 24)

func _game_process(delta: float) -> void:
	var lo := arena_rect.position
	var hi := arena_rect.position + arena_rect.size
	for b in _blocks:
		b["pos"] += b["vel"] * delta
		if b["pos"].x - b["r"] < lo.x or b["pos"].x + b["r"] > hi.x:
			b["vel"].x = -b["vel"].x
		if b["pos"].y - b["r"] < lo.y or b["pos"].y + b["r"] > hi.y:
			b["vel"].y = -b["vel"].y
		b["pos"].x = clampf(b["pos"].x, lo.x + b["r"], hi.x - b["r"])
		b["pos"].y = clampf(b["pos"].y, lo.y + b["r"], hi.y - b["r"])
		b["node"].position = b["pos"] - Vector2(b["r"], b["r"])
		for p in players:
			if p.alive and avatars[p.id].position.distance_to(b["pos"]) < b["r"] + 24.0:
				eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
