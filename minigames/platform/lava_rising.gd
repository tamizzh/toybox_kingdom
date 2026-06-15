extends MiniGameBase3D

# Lava creeps in from the far (+Z) edge toward -Z. Stay ahead of it. Last safe wins. (3D)
# Camera sits at +Z, looking toward -Z, so lava visually rises from the camera side.

var _lava_z: float
var _rate := 0.8
var _lava: MeshInstance3D
var _lava_mat: StandardMaterial3D
var _glow_t := 0.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	_lava_z = ARENA_HZ    # starts flush with the near (+Z) wall

	# ── Main lava block ─────────────────────────────────────────────────────
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.albedo_color            = Color(0.95, 0.22, 0.06)
	_lava_mat.emission_enabled        = true
	_lava_mat.emission                = Color(1.0, 0.38, 0.05)
	_lava_mat.emission_energy_multiplier = 3.0
	_lava_mat.roughness               = 0.55

	_lava = MeshInstance3D.new()
	_lava.mesh = BoxMesh.new()
	_lava.material_override = _lava_mat
	add_child(_lava)

	# ── Bright leading-edge strip ────────────────────────────────────────────
	var edge := MeshInstance3D.new()
	edge.name = "LavaEdge"
	edge.mesh = BoxMesh.new()
	var em := StandardMaterial3D.new()
	em.albedo_color            = Color(1.0, 0.80, 0.05)
	em.emission_enabled        = true
	em.emission                = Color(1.0, 0.85, 0.10)
	em.emission_energy_multiplier = 4.5
	edge.material_override = em
	add_child(edge)

	# Players start safely at the far (-Z) end, away from the lava
	var spts := []
	for i in players.size():
		var x := -ARENA_HX + 2.0 * ARENA_HX * (i + 1.0) / (players.size() + 1.0)
		spts.append(Vector3(x, 0, -ARENA_HZ + 1.5))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 7.0

func _game_process(delta: float) -> void:
	_glow_t += delta
	_rate = minf(4.5, _rate + delta * 0.22)
	_lava_z = maxf(-ARENA_HZ + 0.5, _lava_z - _rate * delta)

	var depth := ARENA_HZ - _lava_z        # how far lava has advanced

	# Main lava block fills from the +Z edge up to _lava_z
	var lmesh := _lava.mesh as BoxMesh
	lmesh.size  = Vector3(ARENA_HX * 2, 0.60, maxf(0.1, depth))
	_lava.position = Vector3(0, 0.30, _lava_z + depth * 0.5)

	# Pulsing molten glow
	_lava_mat.emission_energy_multiplier = 2.5 + sin(_glow_t * 3.5) * 0.8

	# Leading edge strip (bright yellow/gold glowing strip at the front of lava)
	var edge_node := get_node_or_null("LavaEdge")
	if edge_node:
		var em_mesh := edge_node.mesh as BoxMesh
		em_mesh.size = Vector3(ARENA_HX * 2, 0.80, 0.45)
		edge_node.position = Vector3(0, 0.40, _lava_z)

	for p in players:
		if not p.alive:
			continue
		clamp_avatar(avatars[p.id])
		if avatars[p.id].global_position.z > _lava_z - 0.2:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
