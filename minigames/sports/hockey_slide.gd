extends MiniGameBase

# Slippery puck + slippery skaters. Slam the puck into the goal. Most goals wins.

const PUCK_R := 15.0

var _puck: Vector2
var _vel: Vector2
var _last: int = -1
var _goal: Rect2

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_reset_puck()
	_goal = Rect2(arena_rect.position.x + arena_rect.size.x - 16, arena_rect.position.y + arena_rect.size.y * 0.5 - 80, 26, 160)
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].momentum = 650.0
		avatars[p.id].acceleration = 850.0
		avatars[p.id].speed = 380.0
	make_label("Slide the puck into the goal!", Vector2(440, 116), 24)

func _reset_puck() -> void:
	_puck = arena_rect.position + arena_rect.size * 0.5
	_vel = Vector2.ZERO

func _game_process(delta: float) -> void:
	for p in players:
		var d: Vector2 = _puck - avatars[p.id].position
		if d.length() < 26.0 + PUCK_R:
			_vel = d.normalized() * 520.0
			_last = p.id
	_puck += _vel * delta
	_vel *= 0.992
	var lo := arena_rect.position + Vector2(PUCK_R, PUCK_R)
	var hi := arena_rect.position + arena_rect.size - Vector2(PUCK_R, PUCK_R)
	if _puck.x < lo.x or _puck.x > hi.x:
		_vel.x = -_vel.x
	if _puck.y < lo.y or _puck.y > hi.y:
		_vel.y = -_vel.y
	_puck.x = clampf(_puck.x, lo.x, hi.x)
	_puck.y = clampf(_puck.y, lo.y, hi.y)
	if _goal.has_point(_puck) and _last >= 0:
		_player(_last).round_value += 1.0
		_reset_puck()
	queue_redraw()

func _draw() -> void:
	draw_rect(_goal, Palette.SAFE)
	draw_circle(_puck, PUCK_R, Palette.ACCENT)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
