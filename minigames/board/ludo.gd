extends MiniGameBase3D

# Ludo — the real board game. Turn-based: the active player taps to ROLL the die,
# then (if more than one token can move) steers left/right to pick a token and taps
# again to move it. Roll a 6 to bring a token out of the yard; rolling a 6, capturing
# a rival, or sending a token home all grant another turn. Land on a rival on an
# unsafe square and it goes back to its yard. A token must reach the centre by exact
# count. First player to get all four tokens home wins; on a timeout, the most
# progress wins. (3D, turn-based, no avatars)

const S := 0.82                 # world size of one board cell
const LOOP_LEN := 56            # cells in the shared ring (clean cross => 56)
const MAIN_END := 54            # last main-ring position a token occupies
const GOAL := 61                # 55..60 = home column, 61 = centre (finished)
const START := [0, 14, 28, 42]  # ring index where each colour enters
const HOP := 0.13               # seconds per single-cell hop
const ROLL_ANIM := 0.6          # dice tumble time
const ROLL_WAIT := 6.0          # auto-roll if the active player stalls
const SELECT_WAIT := 6.0        # auto-pick if they stall on selection
const SAFE := [0, 8, 14, 22, 28, 36, 42, 50]   # start + star squares

var LOOP: Array = []            # Vector2i grid cells of the ring
var HOME: Array = []            # HOME[ci] -> Array of 6 Vector2i (colour's run home)

var _tokens: Array = []         # each: {pid, ci, tidx, pos, node}
var _by_player := {}            # pid -> Array of its 4 token dicts

var _order: Array = []          # turn order (player ids)
var _current := 0
var _die := 0
var _phase := "intro"
var _pt := 0.0                  # time in the current phase
var _movables: Array = []
var _sel := 0
var _latch := false

var _banner: Label
var _hint: Label
var _dice_by_pid := {}           # pid -> { root, cube, pips, cube_mat, halo_mat, base_y }
var _hl: MeshInstance3D          # selection highlight ring

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "ROLL"
	arena_color = Palette.category_arena("Board")
	_build_geometry()

	add_child(ArenaProps3D.ground(ARENA_HX, ARENA_HZ))
	add_child(ArenaProps3D.scatter(ARENA_HX, ARENA_HZ, 909))
	_build_board()
	_build_dice()
	_build_highlight()

	for i in players.size():
		var p: PlayerData = players[i]
		_order.append(p.id)
		_by_player[p.id] = []
		for tk in 4:
			var node := _build_pawn(p.color)
			add_child(node)
			var t := {"pid": p.id, "ci": i, "tidx": tk, "pos": -1, "node": node}
			node.global_position = _token_world(t, -1)
			_tokens.append(t)
			_by_player[p.id].append(t)

	# Turn prompts live below the board, clear of the HUD timer/banner up top.
	_banner = make_label("", Vector2(560, 566), 34, Palette.ACCENT)
	_hint = make_label("", Vector2(560, 612), 26, Palette.NEUTRAL)
	_current = 0
	_set_phase("intro")

# The default toy-box lighting + bloom blow out Ludo's big bright cream board into a
# washed-white sheet. Calm the glow and key/dome a touch so the board reads cleanly.
func _build_world() -> void:
	super._build_world()
	for c in get_children():
		if c is WorldEnvironment:
			var e: Environment = c.environment
			e.glow_intensity = 0.10
			e.glow_hdr_threshold = 1.6
			e.ambient_light_energy = 0.48
		elif c is DirectionalLight3D and c.light_energy > 1.0:
			c.light_energy = 1.15          # warm key — less blowout on white
		elif c is OmniLight3D:
			c.light_energy = 0.5           # overhead dome

# --------------------------------------------------------------- turn engine
func _game_process(delta: float) -> void:
	if _phase == "done":
		return
	_pt += delta
	_animate_dice(delta)
	match _phase:
		"intro":
			if _pt > 0.5:
				_set_phase("roll")
				_update_banner()
		"roll":
			var cur := _cur_id()
			if InputManager.get_action_just(cur) or _pt > ROLL_WAIT:
				_do_roll()
		"rolling":
			var d := _active_die()
			if not d.is_empty():
				d.cube.rotation.x += delta * 22.0
				d.cube.rotation.z += delta * 17.0
			if _pt > ROLL_ANIM:
				_after_roll()
		"select":
			_select_input()
			if _pt > SELECT_WAIT:
				_confirm_select()
		"passing":
			if _pt > 0.9:
				_end_turn(false)
		"moving":
			pass   # advanced by the move tween's callback

func _do_roll() -> void:
	_die = randi_range(1, 6)
	var d := _active_die()
	if not d.is_empty():
		_clear_pips(d.pips)
	AudioManager.play("tap", 1.1)
	_set_phase("rolling")

func _after_roll() -> void:
	var d := _active_die()
	if not d.is_empty():
		d.cube.rotation = Vector3.ZERO
		_show_pips(d.pips, _die)
	var cur := _cur_id()
	_movables = _movable_tokens(cur, _die)
	if _movables.is_empty():
		_hint.text = "Rolled %d — no move" % _die
		_set_phase("passing")
	elif _movables.size() == 1:
		_begin_move(_movables[0])
	else:
		_sel = 0
		_latch = false
		_hint.text = "Steer ◀ ▶ to pick • tap to move"
		_move_highlight()
		_hl.visible = true
		_set_phase("select")

func _select_input() -> void:
	var cur := _cur_id()
	var ax := InputManager.get_move(cur).x
	var n := _movables.size()
	if absf(ax) < 0.3:
		_latch = false
	elif not _latch:
		_sel = (_sel + (1 if ax > 0.0 else -1) + n) % n
		_latch = true
		_move_highlight()
		AudioManager.play("tap", 1.3)
	if InputManager.get_action_just(cur):
		_confirm_select()

func _confirm_select() -> void:
	_hl.visible = false
	_begin_move(_movables[_sel])

func _begin_move(t: Dictionary) -> void:
	_set_phase("moving")
	_hl.visible = false
	var node: Node3D = t.node
	var from: int = t.pos
	var to: int = (from + _die) if from >= 0 else 0
	var tw := node.create_tween()
	if from < 0:
		tw.tween_property(node, "global_position", _token_world(t, 0), 0.2) \
			.set_trans(Tween.TRANS_BACK)
	else:
		for s in range(from + 1, to + 1):
			tw.tween_property(node, "global_position", _token_world(t, s), HOP) \
				.set_trans(Tween.TRANS_SINE)
	AudioManager.play("tap", 0.95)
	tw.tween_callback(func() -> void: _land(t, to))

func _land(t: Dictionary, to: int) -> void:
	t.pos = to
	t.node.global_position = _token_world(t, to)
	var extra := (_die == 6)
	if _resolve_capture(t):
		extra = true
	if to == GOAL:
		extra = true
		AudioManager.play("collect")
		_flash(t.node.global_position)
	_update_status()
	if _all_home(t.pid):
		_banner.text = "%s WINS!" % _name(t.pid)
		_phase = "done"
		AudioManager.play("win")
		finish_round(_compute_results())
		return
	_end_turn(extra)

func _end_turn(extra: bool) -> void:
	if not extra:
		_current = (_current + 1) % _order.size()
	_set_phase("roll")
	_update_banner()

func _set_phase(name: String) -> void:
	_phase = name
	_pt = 0.0

func _cur_id() -> int:
	return _order[_current]

# --------------------------------------------------------------- rules
func _movable_tokens(pid: int, die: int) -> Array:
	var out := []
	for t in _by_player[pid]:
		if _can_move(t, die):
			out.append(t)
	return out

func _can_move(t: Dictionary, die: int) -> bool:
	if t.pos == GOAL:
		return false
	if t.pos < 0:
		return die == 6
	return t.pos + die <= GOAL

# Knock any rival sharing this token's ring square back to its yard.
func _resolve_capture(t: Dictionary) -> bool:
	if t.pos < 0 or t.pos > MAIN_END:
		return false
	var idx: int = (START[t.ci] + t.pos) % LOOP_LEN
	if idx in SAFE:
		return false
	var captured := false
	for other in _tokens:
		if other.pid == t.pid or other.pos < 0 or other.pos > MAIN_END:
			continue
		if (START[other.ci] + other.pos) % LOOP_LEN == idx:
			other.pos = -1
			var node: Node3D = other.node
			var tw := node.create_tween()
			tw.tween_property(node, "global_position", _token_world(other, -1), 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			AudioManager.play("hit", 1.05)
			_flash(t.node.global_position)
			captured = true
	return captured

func _all_home(pid: int) -> bool:
	for t in _by_player[pid]:
		if t.pos != GOAL:
			return false
	return true

# --------------------------------------------------------------- geometry
func _build_geometry() -> void:
	# Clean cross-shaped ring, orthogonally adjacent, walking clockwise.
	LOOP = [
		Vector2i(1,6),Vector2i(2,6),Vector2i(3,6),Vector2i(4,6),Vector2i(5,6),
		Vector2i(6,6),
		Vector2i(6,5),Vector2i(6,4),Vector2i(6,3),Vector2i(6,2),Vector2i(6,1),
		Vector2i(6,0),Vector2i(7,0),Vector2i(8,0),
		Vector2i(8,1),Vector2i(8,2),Vector2i(8,3),Vector2i(8,4),Vector2i(8,5),
		Vector2i(8,6),
		Vector2i(9,6),Vector2i(10,6),Vector2i(11,6),Vector2i(12,6),Vector2i(13,6),
		Vector2i(14,6),Vector2i(14,7),Vector2i(14,8),
		Vector2i(13,8),Vector2i(12,8),Vector2i(11,8),Vector2i(10,8),Vector2i(9,8),
		Vector2i(8,8),
		Vector2i(8,9),Vector2i(8,10),Vector2i(8,11),Vector2i(8,12),Vector2i(8,13),
		Vector2i(8,14),Vector2i(7,14),Vector2i(6,14),
		Vector2i(6,13),Vector2i(6,12),Vector2i(6,11),Vector2i(6,10),Vector2i(6,9),
		Vector2i(6,8),
		Vector2i(5,8),Vector2i(4,8),Vector2i(3,8),Vector2i(2,8),Vector2i(1,8),
		Vector2i(0,8),Vector2i(0,7),Vector2i(0,6),
	]
	# Home columns: from just inside each edge along the middle lane to the centre.
	HOME = [
		[Vector2i(1,7),Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7),Vector2i(6,7)],
		[Vector2i(7,1),Vector2i(7,2),Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6)],
		[Vector2i(13,7),Vector2i(12,7),Vector2i(11,7),Vector2i(10,7),Vector2i(9,7),Vector2i(8,7)],
		[Vector2i(7,13),Vector2i(7,12),Vector2i(7,11),Vector2i(7,10),Vector2i(7,9),Vector2i(7,8)],
	]

func _grid_world(c: int, r: int) -> Vector3:
	return Vector3((c - 7) * S, 0.0, (r - 7) * S)

func _token_world(t: Dictionary, pos: int) -> Vector3:
	var y := 0.12
	if pos < 0:
		var cell: Vector2i = _yard_slot(t.ci, t.tidx)
		return _grid_world(cell.x, cell.y) + Vector3(0, y, 0)
	if pos <= MAIN_END:
		var cell2: Vector2i = LOOP[(START[t.ci] + pos) % LOOP_LEN]
		return _grid_world(cell2.x, cell2.y) + Vector3(0, y, 0)
	if pos < GOAL:
		var cell3: Vector2i = HOME[t.ci][pos - (MAIN_END + 1)]
		return _grid_world(cell3.x, cell3.y) + Vector3(0, y, 0)
	# centre — fan the four finishers out a touch so they're all visible
	var off := Vector3(cos(t.tidx * TAU / 4.0), 0, sin(t.tidx * TAU / 4.0)) * 0.28
	return _grid_world(7, 7) + Vector3(0, y + 0.15, 0) + off

# 2x2 cluster of slots inside each colour's corner yard.
func _yard_slot(ci: int, tidx: int) -> Vector2i:
	var centers := [Vector2i(2,2), Vector2i(12,2), Vector2i(12,12), Vector2i(2,12)]
	var offs := [Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]
	return centers[ci] + offs[tidx]

# --------------------------------------------------------------- board visuals
func _build_board() -> void:
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(15.0 * S, 0.2, 15.0 * S)
	plate.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("e6dcc4"); pm.roughness = 0.95
	plate.material_override = pm
	plate.position = Vector3(0, -0.04, 0)
	add_child(plate)

	# Corner yards.
	for ci in 4:
		var c: Vector2i = [Vector2i(2,2), Vector2i(12,2), Vector2i(12,12), Vector2i(2,12)][ci]
		_yard(ci, c)

	# Ring tiles — start squares wear their colour, safe stars are highlighted.
	for i in LOOP.size():
		var col := Color("e3e7ee")   # soft off-white path (pure white blooms out)
		var bright := false
		if i in START:
			col = Palette.player_color(START.find(i))   # owner of this start
			bright = true
		elif i in SAFE:
			col = Color("ffd877"); bright = true
		_tile(LOOP[i], col, bright)

	# Home columns.
	for ci in 4:
		for cell in HOME[ci]:
			_tile(cell, Palette.player_color(ci), true)

	# Centre goal pad.
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = S * 1.4; cyl.bottom_radius = S * 1.4; cyl.height = 0.16
	pad.mesh = cyl
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("ffd23f")
	cm.emission_enabled = true; cm.emission = Color("ffae1f")
	cm.emission_energy_multiplier = 0.18
	pad.material_override = cm
	pad.position = _grid_world(7, 7) + Vector3(0, 0.08, 0)
	add_child(pad)

func _yard(ci: int, center: Vector2i) -> void:
	var col := Palette.player_color(ci)
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.0 * S, 0.12, 5.0 * S)
	pad.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true; m.emission = col
	m.emission_energy_multiplier = 0.1
	pad.material_override = m
	pad.position = _grid_world(center.x, center.y) + Vector3(0, 0.02, 0)
	add_child(pad)
	# white inset
	var inset := MeshInstance3D.new()
	var ib := BoxMesh.new()
	ib.size = Vector3(3.6 * S, 0.14, 3.6 * S)
	inset.mesh = ib
	var im := StandardMaterial3D.new()
	im.albedo_color = Color("e6dcc4")
	inset.material_override = im
	inset.position = _grid_world(center.x, center.y) + Vector3(0, 0.03, 0)
	add_child(inset)
	# four base rings where tokens park
	for tk in 4:
		var slot := _yard_slot(ci, tk)
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = S * 0.34; cyl.bottom_radius = S * 0.34; cyl.height = 0.06
		ring.mesh = cyl
		var rm := StandardMaterial3D.new()
		rm.albedo_color = col.darkened(0.1)
		ring.material_override = rm
		ring.position = _grid_world(slot.x, slot.y) + Vector3(0, 0.08, 0)
		add_child(ring)

func _tile(cell: Vector2i, color: Color, bright: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(S * 0.92, 0.1, S * 0.92)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = 0.75
	if bright:
		m.emission_enabled = true; m.emission = color
		m.emission_energy_multiplier = 0.12
	mi.material_override = m
	mi.position = _grid_world(cell.x, cell.y) + Vector3(0, 0.06, 0)
	add_child(mi)

func _build_pawn(color: Color) -> Node3D:
	var n := Node3D.new()
	# base
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = S * 0.22; bc.bottom_radius = S * 0.3; bc.height = 0.14
	base.mesh = bc
	base.material_override = _pawn_mat(color)
	base.position = Vector3(0, 0.07, 0)
	n.add_child(base)
	# body
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = S * 0.08; bm.bottom_radius = S * 0.22; bm.height = 0.42
	body.mesh = bm
	body.material_override = _pawn_mat(color)
	body.position = Vector3(0, 0.34, 0)
	n.add_child(body)
	# head
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = S * 0.18; sm.height = S * 0.36
	head.mesh = sm
	head.material_override = _pawn_mat(color.lightened(0.1))
	head.position = Vector3(0, 0.62, 0)
	n.add_child(head)
	return n

func _pawn_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	m.emission_enabled = true; m.emission = color
	m.emission_energy_multiplier = 0.18
	return m

# --------------------------------------------------------------- dice + hud
# One die per player, parked in that player's corner yard. On mobile the active
# player simply taps their die to roll (3D touch-picking); the button/keyboard also
# work. Only as many dice as there are players.
func _build_dice() -> void:
	get_viewport().physics_object_picking = true
	var centers := [Vector2i(2,2), Vector2i(12,2), Vector2i(12,12), Vector2i(2,12)]
	for i in players.size():
		var p: PlayerData = players[i]
		var base_y := 0.95
		var root := Node3D.new()
		add_child(root)
		root.position = _grid_world(centers[i].x, centers[i].y) + Vector3(0, base_y, 0)

		var cube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 1.1, 1.1)
		cube.mesh = bm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = p.color; cmat.roughness = 0.3; cmat.metallic = 0.1
		cmat.emission_enabled = true; cmat.emission = p.color
		cmat.emission_energy_multiplier = 0.18
		cube.material_override = cmat
		root.add_child(cube)

		var pips := Node3D.new()
		cube.add_child(pips)

		# Player-coloured halo disc under the die marks whose die it is.
		var halo := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.82; cyl.bottom_radius = 0.82; cyl.height = 0.08
		halo.mesh = cyl
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = p.color
		hmat.emission_enabled = true; hmat.emission = p.color
		hmat.emission_energy_multiplier = 0.3
		halo.material_override = hmat
		halo.position = Vector3(0, -0.78, 0)
		root.add_child(halo)

		# Generous invisible tap target for touch picking.
		var body := StaticBody3D.new()
		body.input_ray_pickable = true
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 2.0, 2.0)
		cs.shape = box
		body.add_child(cs)
		root.add_child(body)
		body.input_event.connect(_on_die_input.bind(p.id))

		_dice_by_pid[p.id] = {
			"root": root, "cube": cube, "pips": pips,
			"cube_mat": cmat, "halo_mat": hmat, "base_y": base_y,
		}

func _active_die() -> Dictionary:
	return _dice_by_pid.get(_cur_id(), {})

# Tap your own die (when it's your turn and time to roll) to roll it.
func _on_die_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, pid: int) -> void:
	if pid != _cur_id() or _phase != "roll":
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		_do_roll()

# Idle bob + halo pulse on the active player's die; dim the rest.
func _animate_dice(delta: float) -> void:
	for pid in _dice_by_pid:
		var d: Dictionary = _dice_by_pid[pid]
		var active: bool = pid == _cur_id() and _phase != "done"
		d.halo_mat.emission_energy_multiplier = (0.5 + 0.5 * absf(sin(elapsed * 3.2))) if active else 0.12
		d.cube_mat.emission_energy_multiplier = 0.22 if active else 0.04
		var bob: float = sin(elapsed * 3.2) * 0.12 if (active and _phase == "roll") else 0.0
		d.root.position.y = lerpf(d.root.position.y, float(d.base_y) + bob, clampf(delta * 8.0, 0.0, 1.0))

func _clear_pips(pips: Node3D) -> void:
	for c in pips.get_children():
		c.queue_free()

func _show_pips(pips: Node3D, n: int) -> void:
	_clear_pips(pips)
	# layout of pip slots on the top face (local +Y), in a 3x3 grid
	var layouts := {
		1: [Vector2(0,0)],
		2: [Vector2(-1,-1), Vector2(1,1)],
		3: [Vector2(-1,-1), Vector2(0,0), Vector2(1,1)],
		4: [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)],
		5: [Vector2(-1,-1), Vector2(1,-1), Vector2(0,0), Vector2(-1,1), Vector2(1,1)],
		6: [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,0), Vector2(1,0), Vector2(-1,1), Vector2(1,1)],
	}
	for slot in layouts[n]:
		var pip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12; sm.height = 0.24
		pip.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("fbfbff")
		m.emission_enabled = true; m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.4
		pip.material_override = m
		pip.position = Vector3(slot.x * 0.27, 0.57, slot.y * 0.27)
		pip.scale = Vector3(1, 0.4, 1)
		pips.add_child(pip)

func _build_highlight() -> void:
	_hl = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = S * 0.32; tor.outer_radius = S * 0.46
	_hl.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffffff")
	m.emission_enabled = true; m.emission = Color("ffffff")
	m.emission_energy_multiplier = 0.8
	_hl.material_override = m
	_hl.visible = false
	add_child(_hl)

func _move_highlight() -> void:
	var t: Dictionary = _movables[_sel]
	_hl.global_position = t.node.global_position + Vector3(0, -0.05, 0)

func _update_banner() -> void:
	var pid := _cur_id()
	_banner.text = "● %s — ROLL!" % _name(pid)
	_banner.add_theme_color_override("font_color", _color(pid))
	_hint.text = "Roll a 6 to leave the yard"

func _update_status() -> void:
	var pid := _cur_id()
	var home := 0
	for t in _by_player[pid]:
		if t.pos == GOAL:
			home += 1
	_hint.text = "%s home: %d / 4" % [_name(pid), home]

func _name(pid: int) -> String:
	return _player(pid).display_name

func _color(pid: int) -> Color:
	return _player(pid).color

func _flash(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4; cyl.bottom_radius = 0.4; cyl.height = 0.05
	ring.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.9, 0.4, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color("ffd23f")
	ring.material_override = m
	add_child(ring)
	ring.global_position = at + Vector3(0, 0.15, 0)
	var tw := ring.create_tween()
	tw.parallel().tween_property(ring, "scale", Vector3(4.0, 1.0, 4.0), 0.4)
	tw.parallel().tween_property(m, "albedo_color", Color(1, 0.9, 0.4, 0.0), 0.4)
	tw.tween_callback(ring.queue_free)

func _compute_results() -> Dictionary:
	# Rank by tokens home (heavily weighted) then total distance travelled.
	var vals := {}
	for p in players:
		var score := 0.0
		for t in _by_player[p.id]:
			if t.pos == GOAL:
				score += 10000.0
			elif t.pos > 0:
				score += float(t.pos)
		vals[p.id] = score
	return rank_by_value(vals, true)
