extends MiniGameBase3D

# The safe circle shrinks over time. Step outside and you're out. Last alive wins. (3D)

const SHRINK := 0.5

var _radius: float
var _base_r: float
var _zone: MeshInstance3D

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	_base_r = ARENA_HZ - 0.5
	_radius = _base_r
	_zone = spawn_disc(_base_r, Color(Palette.SAFE, 0.22))
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(Vector3(cos(ang), 0, sin(ang)) * (_base_r * 0.6))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 6.8
	make_label("Stay inside the shrinking zone!", Vector2(420, 96), 24)

func _game_process(delta: float) -> void:
	_radius = maxf(1.2, _radius - SHRINK * delta)
	var s := _radius / _base_r
	_zone.scale = Vector3(s, 1, s)
	for p in players:
		if not p.alive:
			continue
		var fp := avatars[p.id].global_position
		fp.y = 0
		if fp.length() > _radius:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
