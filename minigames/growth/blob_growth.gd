extends MiniGameBase3D

# Eat orbs to grow. Biggest blob at the end wins.  (3D)

const ORB_COUNT := 18
const ORB_R := 0.45

var _orbs: Array = []     # { pos: Vector3, node: MeshInstance3D }
var _rad := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_rad[p.id] = 0.7
		avatars[p.id].speed = 6.5
	for _i in ORB_COUNT:
		var node := spawn_ball(ORB_R, Palette.SAFE, true)
		var o := {"pos": _rand_point(), "node": node}
		node.position = o["pos"]
		_orbs.append(o)
	make_label("Eat orbs to grow the biggest!", Vector2(425, 96), 24)

func _rand_point() -> Vector3:
	return Vector3(
		randf_range(-ARENA_HX + 1.5, ARENA_HX - 1.5),
		ORB_R,
		randf_range(-ARENA_HZ + 1.5, ARENA_HZ - 1.5))

func _game_process(_delta: float) -> void:
	for p in players:
		var av = avatars[p.id]
		for o in _orbs:
			var d := av.global_position.distance_to(o["pos"])
			if d < _rad[p.id] + ORB_R:
				p.round_value += 1.0
				_rad[p.id] = minf(2.2, 0.7 + p.round_value * 0.05)
				av.set_body_scale(_rad[p.id] / 0.7)
				o["pos"] = _rand_point()
				o["node"].position = o["pos"]

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
