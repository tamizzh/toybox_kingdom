extends MiniGameBase

# Auto-run forward; tap (or push up/down) to switch lane and dodge red blocks.
# Crossing the right edge scores a lap. Hit a block = out. Most laps wins.

const SUBLANE := [-52.0, 0.0, 52.0]
const RUN := 250.0
const OBS := 330.0

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	var n := players.size()
	var spts := []
	for i in n:
		var p: PlayerData = players[i]
		var y: float = arena_rect.position.y + arena_rect.size.y * (i + 0.5) / n
		make_rect(Rect2(arena_rect.position.x, y - 72, arena_rect.size.x, 144), Palette.ARENA_FLOOR, -30)
		_rows[p.id] = {"y": y, "x": arena_rect.position.x + 60.0, "lane": 1, "t": 0.0, "obs": []}
		spts.append(Vector2(arena_rect.position.x + 60.0, y))
	spawn_avatars(spts)
	for av in avatars.values():
		av.auto_input = false
	make_label("Tap to switch lane — dodge red!", Vector2(420, 116), 24)

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
		if r["x"] > arena_rect.position.x + arena_rect.size.x - 40:
			r["x"] = arena_rect.position.x + 60.0
			p.round_value += 1.0
		avatars[p.id].position = Vector2(r["x"], r["y"] + SUBLANE[r["lane"]])
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = randf_range(0.6, 1.2)
			var block := make_rect(Rect2(0, 0, 30, 30), Palette.DANGER, -5)
			r["obs"].append({"x": arena_rect.position.x + arena_rect.size.x - 30.0, "lane": randi() % 3, "node": block})
		var keep := []
		for o in r["obs"]:
			o["x"] -= OBS * delta
			o["node"].position = Vector2(o["x"], r["y"] + SUBLANE[o["lane"]] - 15)
			if o["lane"] == r["lane"] and absf(o["x"] - r["x"]) < 34.0:
				eliminate(p.id)
			if o["x"] < arena_rect.position.x - 40:
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
