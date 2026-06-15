extends MiniGameBase3D

# Grab the ball (touch it), then tap to shoot at the hoop. Most baskets wins. (3D)

const BALL_R := 0.45
const HOOP_R := 1.3
const SHOT_SPEED := 20.0

var _ball: Vector3
var _vel: Vector3
var _state := "free"   # free | held | flying
var _holder: int = -1
var _hoop: Vector3
var _facing := {}
var _ball_node: MeshInstance3D

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	add_child(build_arena())
	_hoop = Vector3(ARENA_HX - 1.6, 1.8, 0)
	# hoop marker (ring approximated by a torus mesh)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = HOOP_R * 0.7
	tm.outer_radius = HOOP_R
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = _hoop
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Palette.WARN
	rmat.emission_enabled = true
	rmat.emission = Palette.WARN
	ring.material_override = rmat
	add_child(ring)
	_ball_node = spawn_ball(BALL_R, Palette.ACCENT)
	_reset_ball()
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.5
		_facing[p.id] = Vector3(1, 0, 0)
	make_label("Grab the ball, tap to shoot the hoop!", Vector2(405, 96), 24)

func _reset_ball() -> void:
	_ball = Vector3(0, BALL_R, 0)
	_vel = Vector3.ZERO
	_state = "free"
	_holder = -1

func _game_process(delta: float) -> void:
	for p in players:
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
	match _state:
		"free":
			for p in players:
				if avatars[p.id].global_position.distance_to(_ball) < 1.2 + BALL_R:
					_holder = p.id
					_state = "held"
					break
		"held":
			_ball = avatars[_holder].global_position + _facing[_holder] * 1.2 + Vector3(0, 0.9, 0)
			if InputManager.get_action_just(_holder):
				_vel = (_hoop - _ball).normalized() * SHOT_SPEED
				_state = "flying"
		"flying":
			_ball += _vel * delta
			if _ball.distance_to(_hoop) < HOOP_R:
				_player(_holder).round_value += 1.0
				_reset_ball()
			elif absf(_ball.x) > ARENA_HX or absf(_ball.z) > ARENA_HZ or _ball.y < 0.0:
				_state = "free"
				_holder = -1
	_ball_node.position = _ball

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
