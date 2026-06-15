extends MiniGameBase3D

# The safe circle shrinks over time. Step outside and you're out. Last alive wins. (3D)

const SHRINK := 0.5

var _radius: float
var _base_r: float
var _zone: MeshInstance3D       # green safe-zone disc
var _ring: MeshInstance3D       # pulsing danger torus at the zone edge
var _ring_mat: StandardMaterial3D
var _pulse := 0.0

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	_base_r = ARENA_HZ - 0.5
	_radius = _base_r

	# ── Bright green safe-zone disc ────────────────────────────────────────
	_zone = spawn_disc(_base_r, Color(Palette.SAFE, 0.45))

	# ── Danger torus ring at the zone boundary ─────────────────────────────
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color     = Color(1.0, 0.15, 0.05, 0.9)
	_ring_mat.emission_enabled = true
	_ring_mat.emission         = Color(1.0, 0.15, 0.05)
	_ring_mat.emission_energy_multiplier = 2.0

	var torus := TorusMesh.new()
	torus.inner_radius   = _base_r - 0.30
	torus.outer_radius   = _base_r + 0.30
	torus.rings          = 48
	torus.ring_segments  = 6

	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.rotation_degrees  = Vector3(90, 0, 0)   # flat on the XZ plane
	_ring.position          = Vector3(0, 0.06, 0)
	add_child(_ring)

	var spts := []
	for i in players.size():
		var ang := TAU * i / players.size()
		spts.append(Vector3(cos(ang), 0, sin(ang)) * (_base_r * 0.6))
	spawn_avatars(spts)
	for p in players:
		avatars[p.id].speed = 6.8

func _game_process(delta: float) -> void:
	_radius = maxf(1.2, _radius - SHRINK * delta)
	var s := _radius / _base_r

	# Scale both the disc and the ring together
	_zone.scale = Vector3(s, 1, s)
	_ring.scale = Vector3(s, 1, s)

	# Pulse ring emission — faster as zone shrinks
	_pulse += delta * (3.0 + (1.0 - s) * 8.0)
	var pulse := 0.65 + 0.35 * sin(_pulse)
	_ring_mat.emission_energy_multiplier = 1.5 + pulse * 2.0

	for p in players:
		if not p.alive:
			continue
		var fp: Vector3 = avatars[p.id].global_position
		fp.y = 0
		if fp.length() > _radius:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
