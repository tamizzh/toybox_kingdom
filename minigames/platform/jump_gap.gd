extends MiniGameBase3D

# Gaps sweep along your lane (-X). Tap to jump (up in Y). Miss one and you fall.
# Last alive wins. (3D)

const SPEED := 6.0
const JUMP_TIME := 0.5
const JUMP_H := 1.4

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	var n := players.size()
	spawn_avatars(lane_spawns(-ARENA_HX * 0.4))
	for i in n:
		var p: PlayerData = players[i]
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 0.5) / n
		# a lane strip (visual floor)
		spawn_marker(Vector3(0, -0.15, z), Vector3(ARENA_HX * 2, 0.3, 1.4), Palette.ARENA_FLOOR)
		var x := -ARENA_HX * 0.4
		_rows[p.id] = {"x": x, "z": z, "jump": 0.0, "t": 1.2, "gaps": []}
		avatars[p.id].global_position = Vector3(x, 0, z)
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))
	make_label("Tap to JUMP the gaps!", Vector2(460, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var r = _rows[p.id]
		if InputManager.get_action_just(p.id) and r["jump"] <= 0.0:
			r["jump"] = JUMP_TIME
		r["jump"] = maxf(0.0, r["jump"] - delta)
		var hop := JUMP_H * sin(PI * (1.0 - r["jump"] / JUMP_TIME)) if r["jump"] > 0.0 else 0.0
		avatars[p.id].global_position = Vector3(r["x"], hop, r["z"])
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = maxf(0.7, 1.6 - elapsed * 0.02)
			var g := spawn_marker(Vector3.ZERO, Vector3(1.2, 0.35, 1.4), Palette.DANGER, true)
			r["gaps"].append({"x": ARENA_HX, "node": g})
		var keep := []
		for gap in r["gaps"]:
			gap["x"] -= SPEED * delta
			gap["node"].position = Vector3(gap["x"], 0.0, r["z"])
			if absf(gap["x"] - r["x"]) < 0.8 and r["jump"] <= 0.0:
				eliminate(p.id)
			if gap["x"] < -ARENA_HX - 1.5:
				gap["node"].queue_free()
			else:
				keep.append(gap)
		r["gaps"] = keep
	if survivors().size() <= 1 and players.size() > 1:
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	return survivor_results(3)
