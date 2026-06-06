extends MiniGameBase

# Eat orbs to grow. Biggest blob at the end wins.

const ORB_COUNT := 18
const ORB_R := 11.0

var _orbs: Array = []

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for _i in ORB_COUNT:
		_orbs.append(_rand_point())
	make_label("Eat orbs to grow the biggest!", Vector2(425, 116), 24)

func _rand_point() -> Vector2:
	return Vector2(
		randf_range(arena_rect.position.x + 40, arena_rect.position.x + arena_rect.size.x - 40),
		randf_range(arena_rect.position.y + 40, arena_rect.position.y + arena_rect.size.y - 40))

func _game_process(_delta: float) -> void:
	for p in players:
		var av = avatars[p.id]
		for i in _orbs.size():
			if av.position.distance_to(_orbs[i]) < av.radius + ORB_R:
				p.round_value += 1.0
				av.radius = minf(64.0, 26.0 + p.round_value * 0.9)
				av.figure.set_radius(av.radius)
				_orbs[i] = _rand_point()
	queue_redraw()

func _draw() -> void:
	for o in _orbs:
		draw_circle(o, ORB_R, Palette.SAFE)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
