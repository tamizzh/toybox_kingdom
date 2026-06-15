extends MiniGameBase3D

# Shove rivals out of the ring. Off the edge = out. Last sumo standing wins. (3D)

var _ring: float

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	_ring = ARENA_HZ - 0.5
	# Grassy surround + scattered props (no walls — you push rivals OFF the edge).
	add_child(ArenaProps3D.ground(ARENA_HX, ARENA_HZ))
	add_child(ArenaProps3D.scatter(ARENA_HX, ARENA_HZ))
	_build_ring()
	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(Vector3(cos(ang), 0, sin(ang)) * (_ring * 0.55))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 7.2
	# Instruction shown by the HUD tagline banner.

func _game_process(delta: float) -> void:
	var ids := []
	for p in players:
		if p.alive:
			ids.append(p.id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a = avatars[ids[i]]
			var b = avatars[ids[j]]
			var diff: Vector3 = b.global_position - a.global_position
			diff.y = 0
			var dist := diff.length()
			if dist < 1.5 and dist > 0.05:
				var dir := diff / dist
				var closing := maxf(0.0, (a.velocity - b.velocity).dot(dir))
				var force := closing * delta * 0.6 + (1.5 - dist) * 0.5
				b.global_position += dir * force
				a.global_position -= dir * force
	for p in players:
		if not p.alive:
			continue
		var fp: Vector3 = avatars[p.id].global_position
		fp.y = 0
		if fp.length() > _ring:
			eliminate(p.id)

# Raised clay-coloured dohyo: a solid platform with its top at the y=0 play
# plane, ringed by a darker rim so the drop-off edge is obvious.
func _build_ring() -> void:
	var plat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = _ring; cyl.bottom_radius = _ring + 0.4; cyl.height = 1.2
	plat.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("c9a06a")   # clay
	pm.roughness = 0.7
	plat.material_override = pm
	plat.position = Vector3(0, -0.6, 0)   # top sits at y=0
	add_child(plat)
	# Bright rim marking the edge.
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = _ring - 0.25; tor.outer_radius = _ring + 0.05
	rim.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("f5f0e6")
	rmat.emission_enabled = true
	rmat.emission = Color("f5f0e6")
	rmat.emission_energy_multiplier = 0.25
	rim.material_override = rmat
	rim.position = Vector3(0, 0.02, 0)
	add_child(rim)

func _compute_results() -> Dictionary:
	return survivor_results(3)
