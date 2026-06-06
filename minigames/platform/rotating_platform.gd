extends MiniGameBase

# A spinning disc flings you outward. Steer back to the center. Fall off = out.
# Last one on the disc wins.

var _center: Vector2
var _radius: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	_center = arena_rect.position + arena_rect.size * 0.5
	_radius = minf(arena_rect.size.x, arena_rect.size.y) * 0.5 - 20.0
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(_center + Vector2(cos(ang), sin(ang)) * 70.0)
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 320.0
	make_label("Stay on the spinning disc!", Vector2(445, 116), 24)

func _game_process(delta: float) -> void:
	var drift := 60.0 + elapsed * 6.0
	var spin := 0.9 + elapsed * 0.03
	for p in players:
		if not p.alive:
			continue
		var rel: Vector2 = avatars[p.id].position - _center
		var radial := rel.normalized() if rel.length() > 1.0 else Vector2.RIGHT
		var tangent := Vector2(-radial.y, radial.x)
		avatars[p.id].position += radial * drift * delta + tangent * spin * rel.length() * delta
		if avatars[p.id].position.distance_to(_center) > _radius:
			eliminate(p.id)
	queue_redraw()

func _draw() -> void:
	if _finished:
		return
	draw_circle(_center, _radius, Color(Palette.WALL, 0.30))
	draw_arc(_center, _radius, 0, TAU, 64, Palette.ACCENT, 5.0)
	draw_circle(_center, 14, Palette.NEUTRAL)

func _compute_results() -> Dictionary:
	return survivor_results(3)
