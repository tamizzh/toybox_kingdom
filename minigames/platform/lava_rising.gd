extends MiniGameBase3D

# Lava creeps in from the far (+Z) edge. Stay ahead of it (-Z). Last one safe wins.
# (3D: the 2D "rising" axis maps to Z.)

var _lava_z: float
var _rate := 1.0
var _lava: MeshInstance3D

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	_lava_z = ARENA_HZ
	_lava = MeshInstance3D.new()
	_lava.mesh = BoxMesh.new()
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.9, 0.25, 0.15)
	lm.emission_enabled = true
	lm.emission = Color(0.9, 0.3, 0.1)
	_lava.material_override = lm
	add_child(_lava)
	var spts := []
	for i in players.size():
		var x := -ARENA_HX + 2.0 * ARENA_HX * (i + 1.0) / (players.size() + 1.0)
		spts.append(Vector3(x, 0, ARENA_HZ - 1.5))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 6.8
	make_label("Flee the lava — don't get caught!", Vector2(430, 96), 24)

func _game_process(delta: float) -> void:
	_rate += delta * 0.18
	_lava_z = maxf(-ARENA_HZ, _lava_z - _rate * delta)
	var depth := ARENA_HZ - _lava_z
	(_lava.mesh as BoxMesh).size = Vector3(ARENA_HX * 2, 0.3, maxf(0.1, depth))
	_lava.position = Vector3(0, 0.2, _lava_z + depth * 0.5)
	for p in players:
		if not p.alive:
			continue
		clamp_avatar(avatars[p.id])
		if avatars[p.id].global_position.z > _lava_z:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
