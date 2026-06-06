extends MiniGameBase

# Lava rises from the bottom. Stay above it. Last one above the lava wins.

var _lava_y: float
var _rate := 14.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_lava_y = arena_rect.position.y + arena_rect.size.y
	var spts := []
	for i in players.size():
		var x := arena_rect.position.x + arena_rect.size.x * (i + 1.0) / (players.size() + 1.0)
		spts.append(Vector2(x, arena_rect.position.y + arena_rect.size.y - 60.0))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 300.0
	make_label("Climb! Don't touch the lava!", Vector2(440, 116), 24)

func _game_process(delta: float) -> void:
	_rate += delta * 1.5
	_lava_y = maxf(arena_rect.position.y, _lava_y - _rate * delta)
	for p in players:
		if p.alive:
			clamp_avatar(avatars[p.id])
			if avatars[p.id].position.y > _lava_y:
				eliminate(p.id)
	queue_redraw()

func _draw() -> void:
	if _finished:
		return
	var h := arena_rect.position.y + arena_rect.size.y - _lava_y
	draw_rect(Rect2(arena_rect.position.x, _lava_y, arena_rect.size.x, h), Color(0.9, 0.25, 0.15, 0.85))

func _compute_results() -> Dictionary:
	return survivor_results(3)
