extends MiniGameBase3D

# Auto-run (+X); tap to JUMP (up in Y) over barriers. Hit one = out. Most distance wins. (3D)

const RUN := 4.6
const BAR := 6.0
const JUMP_TIME := 0.55
const JUMP_H := 1.6

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "JUMP"
	# No interior crates — the moving red barriers are the only obstacles.
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	var n := players.size()
	var start_x := -ARENA_HX + 1.5
	spawn_avatars(lane_spawns(start_x))
	for i in n:
		var p: PlayerData = players[i]
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 0.5) / n
		_rows[p.id] = {"z": z, "x": start_x, "t": 1.0, "jump": 0.0, "bars": []}
		avatars[p.id].global_position = Vector3(start_x, 0, z)
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))
	# Instruction shown by the HUD tagline banner.

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var r = _rows[p.id]
		if InputManager.get_action_just(p.id) and r["jump"] <= 0.0:
			r["jump"] = JUMP_TIME
		r["jump"] = maxf(0.0, r["jump"] - delta)
		p.round_value += RUN * delta
		var hop := JUMP_H * sin(PI * (1.0 - r["jump"] / JUMP_TIME)) if r["jump"] > 0.0 else 0.0
		avatars[p.id].global_position = Vector3(r["x"], hop, r["z"])
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = randf_range(0.9, 1.6)
			var bar := spawn_marker(Vector3.ZERO, Vector3(0.5, 1.0, 1.4), Palette.DANGER, true)
			r["bars"].append({"x": ARENA_HX - 1.0, "node": bar})
		var keep := []
		for b in r["bars"]:
			b["x"] -= BAR * delta
			b["node"].position = Vector3(b["x"], 0.5, r["z"])
			if absf(b["x"] - r["x"]) < 0.7 and r["jump"] <= 0.0:
				eliminate(p.id)
			if b["x"] < -ARENA_HX - 1.0:
				b["node"].queue_free()
			else:
				keep.append(b)
		r["bars"] = keep
	if survivors().size() <= 1 and players.size() > 1:
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value + (100000.0 if p.alive else 0.0)
	return rank_by_value(vals, true)
