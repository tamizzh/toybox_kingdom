extends MiniGameBase

# Hold the central zone to earn points. Most time as king wins.

var _zone: Rect2

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	var c := arena_rect.position + arena_rect.size * 0.5
	_zone = Rect2(c - Vector2(150, 115), Vector2(300, 230))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].speed = 290.0
	make_label("Stand in the zone to score!", Vector2(440, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if _zone.has_point(avatars[p.id].position):
			p.round_value += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(_zone, Color(Palette.WARN, 0.15))
	draw_rect(_zone, Palette.WARN, false, 4.0)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
