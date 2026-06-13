extends MiniGameBase3D

# Push the ball into the goal. Whoever last touched it scores. Most goals wins. (3D)

const BALL_R := 0.5
const GOAL_HALF_Z := 2.5

var _ball: Vector3
var _vel: Vector3
var _last: int = -1
var _ball_node: MeshInstance3D

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	_ball_node = spawn_ball(BALL_R, Palette.ACCENT)
	spawn_marker(Vector3(ARENA_HX - 0.3, 0.5, 0), Vector3(0.4, 1.0, GOAL_HALF_Z * 2), Palette.SAFE)
	_reset_ball()
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.5
	make_label("Kick the ball into the goal!", Vector2(440, 96), 24)

func _reset_ball() -> void:
	_ball = Vector3.ZERO
	_vel = Vector3.ZERO

func _game_process(delta: float) -> void:
	for p in players:
		var d: Vector3 = _ball - avatars[p.id].global_position
		d.y = 0
		if d.length() < 1.2 + BALL_R:
			_vel = d.normalized() * 9.5
			_last = p.id
	_ball += _vel * delta
	_vel *= 0.985
	# goal check before bouncing off the far wall
	if _ball.x > ARENA_HX - 0.7 and absf(_ball.z) < GOAL_HALF_Z and _last >= 0:
		_player(_last).round_value += 1.0
		_reset_ball()
	else:
		var lx := ARENA_HX - BALL_R
		var lz := ARENA_HZ - BALL_R
		if _ball.x < -lx or _ball.x > lx:
			_vel.x = -_vel.x
		if _ball.z < -lz or _ball.z > lz:
			_vel.z = -_vel.z
		_ball.x = clampf(_ball.x, -lx, lx)
		_ball.z = clampf(_ball.z, -lz, lz)
	_ball_node.position = _ball + Vector3(0, BALL_R, 0)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
