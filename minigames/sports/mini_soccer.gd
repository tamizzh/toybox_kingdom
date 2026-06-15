extends MiniGameBase3D

# Push the ball into the goal. Whoever last touched it scores. Most goals wins. (3D)

const BALL_R := 0.55
const GOAL_HALF_Z := 2.8

var _ball: Vector3
var _vel: Vector3
var _last: int = -1
var _ball_node: MeshInstance3D
var _score_labels := {}   # id -> Label (2D score popup)

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "KICK"
	# Clean pitch — no interior crates (the ball only collides with the outer walls)
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── Glowing ball ───────────────────────────────────────────────────────
	_ball_node = spawn_ball(BALL_R, Color("ffffff"), true)   # true = emissive

	# ── Right goal (scoring goal) ──────────────────────────────────────────
	_make_goal(Vector3(ARENA_HX - 0.15, 0, 0), true)

	# ── Left goal (decorative mirror — adds visual symmetry & depth) ───────
	_make_goal(Vector3(-ARENA_HX + 0.15, 0, 0), false)

	# ── Centre circle (thin disc) ──────────────────────────────────────────
	spawn_disc(3.0, Color(1, 1, 1, 0.18))

	_reset_ball()
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.5

func _make_goal(center: Vector3, active: bool) -> void:
	var col := Palette.SAFE if active else Color(0.9, 0.9, 0.9, 0.80)
	# Crossbar — wide and visible
	spawn_marker(center + Vector3(0, 1.3, 0),
				 Vector3(0.28, 0.28, GOAL_HALF_Z * 2.1), col)
	# Left post
	spawn_marker(center + Vector3(0, 0.65, -GOAL_HALF_Z),
				 Vector3(0.28, 1.3, 0.28), col)
	# Right post
	spawn_marker(center + Vector3(0, 0.65, GOAL_HALF_Z),
				 Vector3(0.28, 1.3, 0.28), col)
	# Net (semi-transparent fill, taller)
	var net_col := Color(Palette.SAFE, 0.22) if active else Color(0.9, 0.9, 0.9, 0.12)
	spawn_marker(center, Vector3(0.55, 1.3, GOAL_HALF_Z * 2.0), net_col)

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
	# Goal check before bouncing off the far wall
	if _ball.x > ARENA_HX - 0.8 and absf(_ball.z) < GOAL_HALF_Z and _last >= 0:
		_player(_last).round_value += 1.0
		_flash_score(_last)
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

func _flash_score(pid: int) -> void:
	AudioManager.play("collect")
	var cx := Palette.CENTER_X - 80.0
	var cy := Palette.DESIGN_H * 0.38
	var lbl := make_label("GOAL!", Vector2(cx, cy), 52, Palette.player_color(pid))
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.6)
	tw.tween_callback(lbl.queue_free)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
