extends MiniGameBase

# Auto-run right; tap to JUMP over barriers. Hit one = out. Most distance wins.

const RUN := 230.0
const BAR := 300.0
const JUMP_TIME := 0.55

var _rows := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	var n := players.size()
	var spts := []
	for i in n:
		var p: PlayerData = players[i]
		var y: float = arena_rect.position.y + arena_rect.size.y * (i + 0.5) / n
		make_rect(Rect2(arena_rect.position.x, y + 30, arena_rect.size.x, 6), Palette.WALL, -30)
		_rows[p.id] = {"y": y, "x": arena_rect.position.x + 70.0, "t": 1.0, "jump": 0.0, "bars": []}
		spts.append(Vector2(arena_rect.position.x + 70.0, y))
	spawn_avatars(spts)
	for av in avatars.values():
		av.auto_input = false
	make_label("Tap to JUMP the barriers!", Vector2(440, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var r = _rows[p.id]
		if InputManager.get_action_just(p.id) and r["jump"] <= 0.0:
			r["jump"] = JUMP_TIME
		r["jump"] = maxf(0.0, r["jump"] - delta)
		p.round_value += RUN * delta
		var hop := -60.0 * sin(PI * (1.0 - r["jump"] / JUMP_TIME)) if r["jump"] > 0.0 else 0.0
		avatars[p.id].position = Vector2(r["x"], r["y"] + hop)
		r["t"] -= delta
		if r["t"] <= 0.0:
			r["t"] = randf_range(0.9, 1.6)
			var bar := make_rect(Rect2(0, 0, 26, 46), Palette.DANGER, -5)
			r["bars"].append({"x": arena_rect.position.x + arena_rect.size.x - 30.0, "node": bar})
		var keep := []
		for b in r["bars"]:
			b["x"] -= BAR * delta
			b["node"].position = Vector2(b["x"], r["y"] - 16)
			if absf(b["x"] - r["x"]) < 30.0 and r["jump"] <= 0.0:
				eliminate(p.id)
			if b["x"] < arena_rect.position.x - 40:
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
