extends MiniGameBase3D

# Hold the central zone to earn points. Most time as king wins.  (3D)

const ZONE_HX := 4.0
const ZONE_HZ := 3.0

var _zone_fill: MeshInstance3D
var _zone_t: float = 0.0
var _zone_mat: StandardMaterial3D

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "HOLD"
	add_child(build_arena())

	# ── Bright glowing zone fill (cyan contrasts against yellow growth floor) ──
	const ZONE_COL := Color(0.0, 0.85, 1.0)
	_zone_mat = StandardMaterial3D.new()
	_zone_mat.albedo_color     = Color(ZONE_COL, 0.55)
	_zone_mat.emission_enabled = true
	_zone_mat.emission         = ZONE_COL
	_zone_mat.emission_energy_multiplier = 1.2
	_zone_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	_zone_fill = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ZONE_HX * 2, 0.10, ZONE_HZ * 2)
	_zone_fill.mesh = bm
	_zone_fill.material_override = _zone_mat
	_zone_fill.position = Vector3(0, 0.05, 0)
	add_child(_zone_fill)

	# ── 4 glowing corner posts ─────────────────────────────────────────────────
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			spawn_marker(Vector3(sx * ZONE_HX, 0.5, sz * ZONE_HZ),
						 Vector3(0.30, 1.0, 0.30), ZONE_COL)

	# ── 4 thin edge strips ────────────────────────────────────────────────────
	spawn_marker(Vector3(0, 0.12, -ZONE_HZ),  Vector3(ZONE_HX * 2, 0.24, 0.24), Color(ZONE_COL, 0.90))
	spawn_marker(Vector3(0, 0.12,  ZONE_HZ),  Vector3(ZONE_HX * 2, 0.24, 0.24), Color(ZONE_COL, 0.90))
	spawn_marker(Vector3(-ZONE_HX, 0.12, 0),  Vector3(0.24, 0.24, ZONE_HZ * 2), Color(ZONE_COL, 0.90))
	spawn_marker(Vector3( ZONE_HX, 0.12, 0),  Vector3(0.24, 0.24, ZONE_HZ * 2), Color(ZONE_COL, 0.90))

	spawn_avatars(corner_spawns(2.0))
	for p in players:
		avatars[p.id].speed = 6.6

func _game_process(delta: float) -> void:
	_zone_t += delta
	var any_king := false
	for p in players:
		var fp: Vector3 = avatars[p.id].global_position
		if absf(fp.x) < ZONE_HX and absf(fp.z) < ZONE_HZ:
			p.round_value += delta
			any_king = true
	var pulse_speed := 4.5 if any_king else 1.8
	_zone_mat.emission_energy_multiplier = 1.0 + 0.8 * sin(_zone_t * pulse_speed)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
