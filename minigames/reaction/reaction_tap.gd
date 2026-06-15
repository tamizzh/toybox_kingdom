extends MiniGameBase3D

# Wait for GREEN, then tap. First valid tap scores; early tap = disqualified
# for that round. Most round wins takes it. (3D arena)

var _phase := "wait"
var _t := 1.5
var _dq := {}

# 3D signal disc + material
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _glow_t: float = 0.0
var _msg_label: Label     # 2D overlay label (big GO! / WAIT...)

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "TAP"
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── Big floor signal disc ───────────────────────────────────────────────────
	# Starts red (WAIT). Turns bright green on GO!
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color              = Palette.DANGER
	_disc_mat.emission_enabled          = true
	_disc_mat.emission                  = Palette.DANGER
	_disc_mat.emission_energy_multiplier = 2.5
	_disc_mat.transparency              = BaseMaterial3D.TRANSPARENCY_DISABLED

	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 4.5
	cyl.bottom_radius = 4.5
	cyl.height        = 0.12
	cyl.rings         = 1
	_disc.mesh = cyl
	_disc.material_override = _disc_mat
	_disc.position = Vector3(0, 0.06, 0)
	add_child(_disc)

	# Ring outline around disc
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1, 1, 1, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color.WHITE
	ring_mat.emission_energy_multiplier = 1.5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.35
	torus.outer_radius = 4.65
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = ring_mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0.10, 0)
	add_child(ring)

	# ── 2D overlay message (GO! / WAIT...) ────────────────────────────────────
	_msg_label = make_label("WAIT...", Vector2(Palette.CENTER_X - 80, Palette.DESIGN_H * 0.35),
							72, Palette.DANGER)

	spawn_avatars(corner_spawns(3.5))
	for p in players:
		avatars[p.id].speed = 5.5

	_new_wait()

func _new_wait() -> void:
	_phase = "wait"
	_t = randf_range(0.8, 2.4)
	_dq = {}
	_set_disc_color(Palette.DANGER, "WAIT...")

func _set_disc_color(col: Color, msg: String) -> void:
	_disc_mat.albedo_color = col
	_disc_mat.emission     = col
	if _msg_label:
		_msg_label.text           = msg
		_msg_label.add_theme_color_override("font_color", col)

func _game_process(delta: float) -> void:
	_glow_t += delta
	# Pulse emission for drama
	var pulse := 0.5 + 0.5 * sin(_glow_t * (4.0 if _phase == "go" else 2.0))
	_disc_mat.emission_energy_multiplier = 2.0 + pulse * 1.8

	match _phase:
		"wait":
			_t -= delta
			for p in players:
				if InputManager.get_action_just(p.id):
					_dq[p.id] = true
					avatars[p.id].pop()
			if _t <= 0.0:
				_phase = "go"
				_set_disc_color(Palette.SAFE, "GO!")
				AudioManager.play("go")
		"go":
			for p in players:
				if InputManager.get_action_just(p.id) and not _dq.get(p.id, false):
					p.round_value += 1.0
					avatars[p.id].pop()
					_set_disc_color(Palette.player_color(p.id),
									"%s!" % p.display_name)
					_phase = "cool"
					AudioManager.play("collect")
					_cool_then_wait()
					break

func _cool_then_wait() -> void:
	await get_tree().create_timer(0.8).timeout
	if not _finished:
		_new_wait()

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
