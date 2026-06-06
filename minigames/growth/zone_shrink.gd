extends MiniGameBase

# The safe circle shrinks over time. Step outside and you're out. Last alive wins.

const SHRINK := 24.0

var _center: Vector2
var _radius: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	_center = arena_rect.position + arena_rect.size * 0.5
	_radius = minf(arena_rect.size.x, arena_rect.size.y) * 0.5 - 20.0
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(_center + Vector2(cos(ang), sin(ang)) * 90.0)
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 300.0
	make_label("Stay inside the shrinking zone!", Vector2(420, 116), 24)

func _game_process(delta: float) -> void:
	_radius = maxf(40.0, _radius - SHRINK * delta)
	for p in players:
		if p.alive and avatars[p.id].position.distance_to(_center) > _radius:
			eliminate(p.id)
	queue_redraw()

func _draw() -> void:
	if _finished:
		return
	draw_circle(_center, _radius, Color(Palette.SAFE, 0.18))
	draw_arc(_center, _radius, 0, TAU, 64, Palette.SAFE, 4.0)

func _compute_results() -> Dictionary:
	return survivor_results(3)
