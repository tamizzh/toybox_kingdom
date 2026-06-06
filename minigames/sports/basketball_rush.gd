extends MiniGameBase

# Grab the ball (touch it), then tap to shoot at the hoop. Most baskets wins.

const BALL_R := 15.0
const HOOP_R := 42.0
const SHOT_SPEED := 720.0

var _ball: Vector2
var _vel: Vector2
var _state := "free"   # free | held | flying
var _holder: int = -1
var _hoop: Vector2
var _facing := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_hoop = Vector2(arena_rect.position.x + arena_rect.size.x * 0.5, arena_rect.position.y + 46.0)
	_reset_ball()
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].speed = 300.0
		_facing[p.id] = Vector2.UP
	make_label("Grab the ball, tap to shoot the hoop!", Vector2(405, 116), 24)

func _reset_ball() -> void:
	_ball = arena_rect.position + arena_rect.size * 0.5
	_vel = Vector2.ZERO
	_state = "free"
	_holder = -1

func _game_process(delta: float) -> void:
	for p in players:
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = mv.normalized()
	match _state:
		"free":
			for p in players:
				if avatars[p.id].position.distance_to(_ball) < 26.0 + BALL_R:
					_holder = p.id
					_state = "held"
					break
		"held":
			_ball = avatars[_holder].position + _facing[_holder] * 30.0
			if InputManager.get_action_just(_holder):
				_vel = (_hoop - _ball).normalized() * SHOT_SPEED
				_state = "flying"
		"flying":
			_ball += _vel * delta
			if _ball.distance_to(_hoop) < HOOP_R:
				_player(_holder).round_value += 1.0
				_reset_ball()
			elif not arena_rect.grow(-BALL_R).has_point(_ball):
				_state = "free"
				_holder = -1
	queue_redraw()

func _draw() -> void:
	draw_arc(_hoop, HOOP_R, 0, TAU, 40, Palette.WARN, 6.0)
	draw_circle(_ball, BALL_R, Palette.ACCENT)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
