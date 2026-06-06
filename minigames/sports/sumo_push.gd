extends MiniGameBase

# Shove rivals out of the ring. Off the edge = out. Last sumo standing wins.

var _center: Vector2
var _ring: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	_center = arena_rect.position + arena_rect.size * 0.5
	_ring = minf(arena_rect.size.x, arena_rect.size.y) * 0.5 - 16.0
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(_center + Vector2(cos(ang), sin(ang)) * 110.0)
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 330.0
	make_label("Push rivals out of the ring!", Vector2(440, 116), 24)

func _game_process(delta: float) -> void:
	var ids := []
	for p in players:
		if p.alive:
			ids.append(p.id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a = avatars[ids[i]]
			var b = avatars[ids[j]]
			var diff: Vector2 = b.position - a.position
			var dist := diff.length()
			if dist < 56.0 and dist > 0.1:
				var dir := diff / dist
				var closing := maxf(0.0, (a.velocity - b.velocity).dot(dir))
				var force := closing * delta * 1.6 + (56.0 - dist) * 0.5
				b.position += dir * force
				a.position -= dir * force
	for p in players:
		if p.alive and avatars[p.id].position.distance_to(_center) > _ring:
			eliminate(p.id)
	queue_redraw()

func _draw() -> void:
	if _finished:
		return
	draw_circle(_center, _ring, Color(Palette.WALL, 0.30))
	draw_arc(_center, _ring, 0, TAU, 64, Palette.ACCENT, 5.0)

func _compute_results() -> Dictionary:
	return survivor_results(3)
