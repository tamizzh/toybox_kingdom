extends MiniGameBase

# Gaps sweep along your lane. Tap to jump them. Miss one and you fall. Last alive wins.

const SPEED := 320.0
const JUMP_TIME := 0.5

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	var n := players.size()
	var spts := []
	for i in n:
		var p: PlayerData = players[i]
		var y: float = arena_rect.position.y + arena_rect.size.y * (i + 0.5) / n
		make_rect(Rect2(arena_rect.position.x, y + 26, arena_rect.size.x, 8), Palette.ARENA_FLOOR, -30)
		var x: float = arena_rect.position.x + arena_rect.size.x * 0.3
		_rows[p.id] = {"x": x, "y": y, "jump": 0.0, "t": 1.2, "gaps": []}
		spts.append(Vector2(x, y))
	spawn_avatars(spts)
	for av in avatars.values():
		av.auto_input = false
	make_label("Tap to JUMP the gaps!", Vector2(460, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var r = _rows[p.id]
		if InputManager.get_action_just(p.id) and r["jump"] <= 0.0:
			r["jump"] = JUMP_TIME
		r["jump"] = maxf(0.0, r["jump"] - delta)
		var hop := -55.0 * sin(PI * (1.0 - r["jump"] / JUMP_TIME)) if r["jump"] > 0.0 else 0.0
		avatars[p.id].position = Vector2(r["x"], r["y"] + hop)
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = maxf(0.7, 1.6 - elapsed * 0.02)
			var g := make_rect(Rect2(0, 0, 56, 10), Palette.DANGER, -5)
			r["gaps"].append({"x": arena_rect.position.x + arena_rect.size.x, "node": g})
		var keep := []
		for gap in r["gaps"]:
			gap["x"] -= SPEED * delta
			gap["node"].position = Vector2(gap["x"], r["y"] + 26)
			if absf(gap["x"] + 28 - r["x"]) < 34.0 and r["jump"] <= 0.0:
				eliminate(p.id)
			if gap["x"] < arena_rect.position.x - 60:
				gap["node"].queue_free()
			else:
				keep.append(gap)
		r["gaps"] = keep
	if survivors().size() <= 1 and players.size() > 1:
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	return survivor_results(3)
