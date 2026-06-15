extends MiniGameBase3D

# Hold to accelerate uphill; gravity pulls you back. First to the top (+X) wins. (3D)

const GRAVITY := 0.16
const PUSH := 0.55

var _rows := {}
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	# No interior crates — keep the climb lanes clear.
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	var n := players.size()
	var left := -ARENA_HX + 1.5
	spawn_avatars(lane_spawns(left))
	for i in n:
		var p: PlayerData = players[i]
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 0.5) / n
		spawn_marker(Vector3(ARENA_HX - 1.2, 0.4, z), Vector3(0.3, 1.2, 1.0), Palette.SAFE)
		_rows[p.id] = {"z": z, "prog": 0.0, "vel": 0.0}
		avatars[p.id].global_position = Vector3(left, 0, z)
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))
	make_label("HOLD to climb — don't roll back!", Vector2(430, 96), 24)

func _game_process(delta: float) -> void:
	var left := -ARENA_HX + 1.5
	var span := (ARENA_HX - 1.2) - left
	for p in players:
		if p.finished:
			continue
		var r = _rows[p.id]
		if InputManager.get_action(p.id):
			r["vel"] += PUSH * delta
		r["vel"] -= GRAVITY * delta
		r["prog"] = clampf(r["prog"] + r["vel"] * delta, 0.0, 1.0)
		if r["prog"] <= 0.0:
			r["vel"] = 0.0
		avatars[p.id].global_position = Vector3(left + span * r["prog"], 0, r["z"])
		if r["prog"] >= 1.0:
			p.finished = true
			_order.append(p.id)
	if _order.size() >= players.size():
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var ranking := _order.duplicate()
	var rest := []
	for p in players:
		if not p.finished:
			rest.append(p)
	rest.sort_custom(func(a, b): return _rows[a.id]["prog"] > _rows[b.id]["prog"])
	for p in rest:
		ranking.append(p.id)
	return award_by_rank(ranking)
