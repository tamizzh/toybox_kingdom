extends MiniGameBase3D

# Hold the central zone to earn points. Most time as king wins.  (3D)

const ZONE_HX := 4.0
const ZONE_HZ := 3.0

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	spawn_marker(Vector3(0, 0.06, 0), Vector3(ZONE_HX * 2, 0.12, ZONE_HZ * 2), Color(Palette.WARN, 0.25))
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.6
	make_label("Stand in the zone to score!", Vector2(440, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		var fp := avatars[p.id].global_position
		if absf(fp.x) < ZONE_HX and absf(fp.z) < ZONE_HZ:
			p.round_value += delta

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
