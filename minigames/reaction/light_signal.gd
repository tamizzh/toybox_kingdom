extends MiniGameBase3D

# Traffic-light start. Lights go red → red → GREEN. First to tap on green scores;
# early tap disqualifies that round. (3D arena with real glowing lights)

var _phase := "wait"
var _t := 1.5
var _lit := 0
var _dq := {}

# 3 light MeshInstance3D + their materials
var _light_nodes: Array[MeshInstance3D] = []
var _light_mats:  Array[StandardMaterial3D] = []
const _OFF_COL := Color(0.18, 0.20, 0.18, 1.0)
var _msg_label: Label
var _glow_t: float = 0.0

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "TAP"
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── 3 traffic-light spheres in a horizontal row ────────────────────────────
	var positions := [Vector3(-2.5, 1.0, -1.0), Vector3(0.0, 1.0, -1.0), Vector3(2.5, 1.0, -1.0)]
	for i in 3:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _OFF_COL
		mat.emission_enabled = true
		mat.emission = _OFF_COL
		mat.emission_energy_multiplier = 0.5
		_light_mats.append(mat)

		var sphere := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.70
		sm.height = 1.40
		sphere.mesh = sm
		sphere.material_override = mat
		sphere.position = positions[i]
		add_child(sphere)
		_light_nodes.append(sphere)

		# Housing box behind each light
		var hm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.8, 1.8, 0.5)
		hm.mesh = bm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.12, 0.12, 0.12)
		hm.material_override = hmat
		hm.position = positions[i] + Vector3(0, 0, -0.28)
		add_child(hm)

	# Stand pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12; pm.bottom_radius = 0.12; pm.height = 2.0
	pole.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.18, 0.18, 0.18)
	pole.material_override = pmat
	pole.position = Vector3(0, 0.0, -1.0)
	add_child(pole)

	# ── 2D status label ────────────────────────────────────────────────────────
	_msg_label = make_label("Get ready...", Vector2(Palette.CENTER_X - 120, Palette.DESIGN_H * 0.68),
							40, Palette.NEUTRAL)

	spawn_avatars(corner_spawns(3.0))
	for p in players:
		avatars[p.id].speed = 5.5

	_new_wait()

func _new_wait() -> void:
	_phase = "wait"
	_t = randf_range(1.0, 2.6)
	_lit = 0
	_dq = {}
	if _msg_label:
		_msg_label.text = "Get ready..."
	_refresh_lights()

func _refresh_lights() -> void:
	for i in 3:
		var mat: StandardMaterial3D = _light_mats[i]
		if _phase == "go":
			mat.albedo_color = Palette.SAFE
			mat.emission     = Palette.SAFE
			mat.emission_energy_multiplier = 5.0
		elif i < _lit:
			mat.albedo_color = Palette.DANGER
			mat.emission     = Palette.DANGER
			mat.emission_energy_multiplier = 4.0
		else:
			mat.albedo_color = _OFF_COL
			mat.emission     = _OFF_COL
			mat.emission_energy_multiplier = 0.4

func _game_process(delta: float) -> void:
	_glow_t += delta
	match _phase:
		"wait":
			_t -= delta
			var new_lit := clampi(3 - int(ceil(_t / 0.7)), 0, 3)
			if new_lit != _lit:
				_lit = new_lit
				_refresh_lights()
				if _lit > 0:
					AudioManager.play("count")
			for p in players:
				if InputManager.get_action_just(p.id):
					_dq[p.id] = true
					avatars[p.id].pop()
			if _t <= 0.0:
				_phase = "go"
				if _msg_label:
					_msg_label.text = "GO!"
				_refresh_lights()
				AudioManager.play("go")
		"go":
			# Pulse the green lights
			for i in 3:
				_light_mats[i].emission_energy_multiplier = 4.0 + 2.0 * sin(_glow_t * 5.0)
			for p in players:
				if InputManager.get_action_just(p.id) and not _dq.get(p.id, false):
					p.round_value += 1.0
					if _msg_label:
						_msg_label.text = "%s scores!" % p.display_name
					_phase = "cool"
					avatars[p.id].pop()
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
