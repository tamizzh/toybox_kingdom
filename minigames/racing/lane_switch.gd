extends MiniGameBase3D

# Auto-run forward (+X); tap (or push up/down) to switch lane and dodge red blocks.
# Crossing the right edge scores a lap. Hit a block = out. Most laps wins.  (3D)

const SUBLANE := [-1.0, 0.0, 1.0]      # Z offsets within a player's strip
const RUN := 5.0
const OBS := 6.5

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	var n := players.size()
	var start_x := -ARENA_HX + 1.5
	for i in n:
		var p: PlayerData = players[i]
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 0.5) / n
		_rows[p.id] = {"z": z, "x": start_x, "lane": 1, "t": 0.0, "obs": []}
		avatars[p.id].global_position = Vector3(start_x, 0, z)
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))
	make_label("Tap to switch lane — dodge red!", Vector2(420, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var r = _rows[p.id]
		if InputManager.get_action_just(p.id):
			r["lane"] = (r["lane"] + 1) % 3
		var mv := InputManager.get_move(p.id)
		if mv.y < -0.6:
			r["lane"] = maxi(0, r["lane"] - 1)
		elif mv.y > 0.6:
			r["lane"] = mini(2, r["lane"] + 1)
		r["x"] += RUN * delta
		if r["x"] > ARENA_HX - 1.0:
			r["x"] = -ARENA_HX + 1.5
			p.round_value += 1.0
		avatars[p.id].global_position = Vector3(r["x"], 0, r["z"] + SUBLANE[r["lane"]])
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = randf_range(0.6, 1.2)
			var block := spawn_marker(Vector3.ZERO, Vector3(0.6, 0.8, 0.6), Palette.DANGER, true)
			r["obs"].append({"x": ARENA_HX - 1.0, "lane": randi() % 3, "node": block})
		var keep := []
		for o in r["obs"]:
			o["x"] -= OBS * delta
			o["node"].position = Vector3(o["x"], 0.4, r["z"] + SUBLANE[o["lane"]])
			if o["lane"] == r["lane"] and absf(o["x"] - r["x"]) < 0.7:
				eliminate(p.id)
			if o["x"] < -ARENA_HX - 1.0:
				o["node"].queue_free()
			else:
				keep.append(o)
		r["obs"] = keep
	if survivors().size() <= 1 and players.size() > 1:
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value + (100.0 if p.alive else 0.0)
	return rank_by_value(vals, true)
