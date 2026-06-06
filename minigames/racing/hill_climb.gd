extends MiniGameBase

# Hold to accelerate uphill; gravity pulls you back. First to the top wins.

const GRAVITY := 0.16
const PUSH := 0.55

var _rows := {}
var _order: Array = []

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	draw_background()
	var n := players.size()
	var spts := []
	for i in n:
		var p: PlayerData = players[i]
		var y: float = arena_rect.position.y + arena_rect.size.y * (i + 0.5) / n
		make_rect(Rect2(arena_rect.position.x, y + 34, arena_rect.size.x, 6), Palette.WALL, -30)
		make_rect(Rect2(arena_rect.position.x + arena_rect.size.x - 80, y - 40, 8, 80), Palette.SAFE, -20)
		_rows[p.id] = {"y": y, "prog": 0.0, "vel": 0.0}
		spts.append(Vector2(arena_rect.position.x + 60.0, y))
	spawn_avatars(spts)
	for av in avatars.values():
		av.auto_input = false
	make_label("HOLD to climb — don't roll back!", Vector2(430, 116), 24)

func _game_process(delta: float) -> void:
	var left := arena_rect.position.x + 60.0
	var span := arena_rect.size.x - 140.0
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
		avatars[p.id].position = Vector2(left + span * r["prog"], r["y"])
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
