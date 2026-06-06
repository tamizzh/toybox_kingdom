extends MiniGameBase

# Rotating laser beams sweep the arena from the center. Dodge to survive.
# Last alive wins.

const SPIN := 0.85
const BEAM_HALF := 16.0

var _angle := 0.0
var _center: Vector2

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_center = arena_rect.position + arena_rect.size * 0.5
	spawn_avatars(corner_spawns(arena_rect, 60.0))
	for p in players:
		avatars[p.id].speed = 300.0
	make_label("Dodge the lasers — survive!", Vector2(440, 116), 24)

func _game_process(delta: float) -> void:
	_angle += SPIN * delta
	queue_redraw()
	for p in players:
		if not p.alive:
			continue
		var rel: Vector2 = avatars[p.id].position - _center
		for a in [_angle, _angle + PI, _angle + PI * 0.5, _angle + PI * 1.5]:
			var dir := Vector2(cos(a), sin(a))
			var along := rel.dot(dir)
			var perp := absf(rel.dot(Vector2(-dir.y, dir.x)))
			if along > 0.0 and perp < BEAM_HALF:
				eliminate(p.id)
				break

func _draw() -> void:
	if _finished:
		return
	var r := arena_rect.size.length()
	for a in [_angle, _angle + PI, _angle + PI * 0.5, _angle + PI * 1.5]:
		var dir := Vector2(cos(a), sin(a))
		draw_line(_center, _center + dir * r, Color(1, 0.25, 0.3, 0.8), BEAM_HALF * 2.0)

func _compute_results() -> Dictionary:
	return survivor_results(3)
