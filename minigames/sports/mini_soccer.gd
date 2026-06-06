extends MiniGameBase

# Push the ball into the goal. Whoever last touched it scores. Most goals wins.

const BALL_R := 16.0

var _ball: Vector2
var _vel: Vector2
var _last: int = -1
var _goal: Rect2

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_reset_ball()
	_goal = Rect2(arena_rect.position.x + arena_rect.size.x - 16, arena_rect.position.y + arena_rect.size.y * 0.5 - 75, 26, 150)
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].speed = 300.0
	make_label("Kick the ball into the goal!", Vector2(440, 116), 24)

func _reset_ball() -> void:
	_ball = arena_rect.position + arena_rect.size * 0.5
	_vel = Vector2.ZERO

func _game_process(delta: float) -> void:
	for p in players:
		var d: Vector2 = _ball - avatars[p.id].position
		if d.length() < 26.0 + BALL_R:
			_vel = d.normalized() * 430.0
			_last = p.id
	_ball += _vel * delta
	_vel *= 0.985
	var lo := arena_rect.position + Vector2(BALL_R, BALL_R)
	var hi := arena_rect.position + arena_rect.size - Vector2(BALL_R, BALL_R)
	if _ball.x < lo.x or _ball.x > hi.x:
		_vel.x = -_vel.x
	if _ball.y < lo.y or _ball.y > hi.y:
		_vel.y = -_vel.y
	_ball.x = clampf(_ball.x, lo.x, hi.x)
	_ball.y = clampf(_ball.y, lo.y, hi.y)
	if _goal.has_point(_ball) and _last >= 0:
		_player(_last).round_value += 1.0
		_reset_ball()
	queue_redraw()

func _draw() -> void:
	draw_rect(_goal, Palette.SAFE)
	draw_circle(_ball, BALL_R, Palette.ACCENT)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
