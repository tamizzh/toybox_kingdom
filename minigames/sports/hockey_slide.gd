extends MiniGameBase3D

# Slippery puck + slippery skaters. Slam the puck into the goal. Most goals wins. (3D)

const PUCK_R := 0.5
const GOAL_HALF_Z := 2.6

var _puck: Vector3
var _vel: Vector3
var _last: int = -1
var _puck_node: MeshInstance3D

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(build_arena())
	_puck_node = spawn_ball(PUCK_R, Palette.ACCENT)
	spawn_marker(Vector3(ARENA_HX - 0.3, 0.5, 0), Vector3(0.4, 1.0, GOAL_HALF_Z * 2), Palette.SAFE)
	_reset_puck()
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].momentum = 13.0
		avatars[p.id].acceleration = 17.0
		avatars[p.id].speed = 8.0
	make_label("Slide the puck into the goal!", Vector2(440, 96), 24)

func _reset_puck() -> void:
	_puck = Vector3.ZERO
	_vel = Vector3.ZERO

func _game_process(delta: float) -> void:
	for p in players:
		var d: Vector3 = _puck - avatars[p.id].global_position
		d.y = 0
		if d.length() < 1.2 + PUCK_R:
			_vel = d.normalized() * 11.0
			_last = p.id
	_puck += _vel * delta
	_vel *= 0.992
	if _puck.x > ARENA_HX - 0.7 and absf(_puck.z) < GOAL_HALF_Z and _last >= 0:
		_player(_last).round_value += 1.0
		_reset_puck()
	else:
		var lx := ARENA_HX - PUCK_R
		var lz := ARENA_HZ - PUCK_R
		if _puck.x < -lx or _puck.x > lx:
			_vel.x = -_vel.x
		if _puck.z < -lz or _puck.z > lz:
			_vel.z = -_vel.z
		_puck.x = clampf(_puck.x, -lx, lx)
		_puck.z = clampf(_puck.z, -lz, lz)
	_puck_node.position = _puck + Vector3(0, PUCK_R, 0)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
