extends MiniGameBase3D

# Watch the arrow sequence light up on 4 floor panels, then repeat it with your
# stick. First to finish the current sequence scores; the sequence grows.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIR_LABELS := [">", "<", "v", "^"]

var _seq: Array = []
var _phase := "show"
var _show_i := 0
var _show_t := 0.0
var _progress := {}
var _ready := {}

# 4 floor arrow panels (one per direction)
var _panels: Array[MeshInstance3D] = []
var _panel_mats: Array[StandardMaterial3D] = []
const _PANEL_OFF := Color(0.20, 0.22, 0.25)
# Panel positions: E(+X), W(-X), S(+Z), N(-Z) — matching DIRS order
const _PANEL_POS := [
	Vector3(5.0, 0.05, 0.0),   # East  (+X)
	Vector3(-5.0, 0.05, 0.0),  # West  (-X)
	Vector3(0.0, 0.05, 4.0),   # South (+Z)
	Vector3(0.0, 0.05, -4.0),  # North (-Z)
]
const _PANEL_COLORS := [
	Color("e83030"),  # East  — red
	Color("1878f0"),  # West  — blue
	Color("28c050"),  # South — green
	Color("f5c020"),  # North — yellow
]
var _active_panel := -1   # which panel is currently lit (-1 = none)
var _msg_label: Label
var _glow_t: float = 0.0

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "COPY"
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── 4 direction floor panels ───────────────────────────────────────────────
	for i in 4:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _PANEL_OFF
		mat.emission_enabled = true
		mat.emission = _PANEL_OFF
		mat.emission_energy_multiplier = 0.3
		_panel_mats.append(mat)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.08, 3.2)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = _PANEL_POS[i]
		add_child(mi)
		_panels.append(mi)

	# ── Centre display label (WATCH / GO / arrow symbol) ─────────────────────
	_msg_label = make_label("WATCH", Vector2(Palette.CENTER_X - 60, Palette.DESIGN_H * 0.34),
							80, Palette.ACCENT)

	spawn_avatars(corner_spawns(3.0))
	for p in players:
		avatars[p.id].speed = 4.5

	_grow_and_show()

func _light_panel(idx: int, on: bool) -> void:
	var mat: StandardMaterial3D = _panel_mats[idx]
	if on:
		mat.albedo_color = _PANEL_COLORS[idx]
		mat.emission     = _PANEL_COLORS[idx]
		mat.emission_energy_multiplier = 5.0
	else:
		mat.albedo_color = _PANEL_OFF
		mat.emission     = _PANEL_OFF
		mat.emission_energy_multiplier = 0.3

func _grow_and_show() -> void:
	_seq.append(DIRS[randi() % 4])
	_phase = "show"
	_show_i = 0
	_show_t = 0.5
	_active_panel = -1
	for p in players:
		_progress[p.id] = 0
		_ready[p.id] = true
	if _msg_label:
		_msg_label.text = "WATCH"
	# Turn all panels off
	for i in 4:
		_light_panel(i, false)

func _game_process(delta: float) -> void:
	_glow_t += delta

	match _phase:
		"show":
			_show_t -= delta
			if _show_t <= 0.0:
				# Turn off previous
				if _active_panel >= 0:
					_light_panel(_active_panel, false)
					_active_panel = -1
					_show_t = 0.20   # brief off-gap between panels
				elif _show_i < _seq.size():
					_active_panel = DIRS.find(_seq[_show_i])
					_light_panel(_active_panel, true)
					if _msg_label:
						_msg_label.text = DIR_LABELS[_active_panel]
					_show_i += 1
					_show_t = 0.65
					AudioManager.play("count")
				else:
					# Done showing — switch to input
					_phase = "input"
					if _msg_label:
						_msg_label.text = "GO!"
					# Dim all panels to standby
					for i in 4:
						_light_panel(i, false)
					AudioManager.play("go")

		"input":
			# Pulse all panels softly so players can see them
			for i in 4:
				_panel_mats[i].emission_energy_multiplier = 0.4 + 0.3 * sin(_glow_t * 2.0 + i)

			for p in players:
				var d := _dir_of(InputManager.get_move(p.id))
				if d == Vector2i.ZERO:
					_ready[p.id] = true
				elif _ready[p.id]:
					_ready[p.id] = false
					var panel_idx := DIRS.find(d)
					if panel_idx >= 0:
						_light_panel(panel_idx, true)
						# Brief visual feedback — turn off next frame via tween
						var mi: MeshInstance3D = _panels[panel_idx]
						var tw := mi.create_tween()
						tw.tween_callback(func(): _light_panel(panel_idx, false)).set_delay(0.25)

					if d == _seq[_progress[p.id]]:
						_progress[p.id] += 1
						if _progress[p.id] >= _seq.size():
							p.round_value += 1.0
							_phase = "cool"
							if _msg_label:
								_msg_label.text = "P%d!" % (p.id + 1)
							avatars[p.id].pop()
							AudioManager.play("collect")
							_cool_then_next()
							break
					else:
						_progress[p.id] = 0
						avatars[p.id].pop()

func _cool_then_next() -> void:
	await get_tree().create_timer(1.0).timeout
	if not _finished:
		_grow_and_show()

func _dir_of(mv: Vector2) -> Vector2i:
	if mv.length() < 0.6:
		return Vector2i.ZERO
	if absf(mv.x) > absf(mv.y):
		return Vector2i(int(sign(mv.x)), 0)
	return Vector2i(0, int(sign(mv.y)))

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
