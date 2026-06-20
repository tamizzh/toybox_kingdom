extends MiniGameBase3D

# MASH your button to run (+X). Each tap gives a burst of speed that quickly
# decays, so the fastest tapper wins. First across the line takes it.  (3D)

const TAP_IMPULSE := 3.0    # speed gained per tap
const MAX_SPEED := 11.0     # cap so mashing has a ceiling
const FRICTION := 8.0       # how fast speed bleeds off — forces you to keep tapping

var _finish_x: float
var _start_x: float
var _order: Array = []
var _spd := {}              # id -> current run speed

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	action_label = "RUN"
	# No interior crates — they would block the running lanes.
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	_start_x = -ARENA_HX + 1.5
	_finish_x = ARENA_HX - 1.0

	# ── Finish & start markers: bold dashed lines (blue finish, red start) ───
	# Matches the dashed colored lines in the reference floor art. Finish
	# detection still uses _finish_x in _game_process — these are purely visual.
	_dashed_line(_finish_x, Palette.player_color(1))   # blue dashes, finish end
	_dashed_line(_start_x,  Palette.player_color(0))   # red dashes,  start end

	# ── Painted golden chevron runway down the centre, pointing to the finish ───
	# Crisp arrow_decal segments projected on the slate (no pixelation at angle).
	var seg_w := 3.4
	var count := int((_finish_x - _start_x) / seg_w)
	for i in count:
		var cx := _start_x + seg_w * (float(i) + 0.7)
		# Float width → depth auto-derived from the arrow texture's aspect (no skew).
		paint_decal(ARROW_DECAL, Vector3(cx, 0.0, 0.0), seg_w * 0.92, Palette.WARN)

	# ── Decorative golden stars + centre trophy emblem (reference floor art) ──
	_scatter_stars()
	_trophy_emblem()

	spawn_avatars(lane_spawns(_start_x))
	for p in players:
		_spd[p.id] = 0.0
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))

func _dashed_line(x: float, color: Color) -> void:
	# A bold dashed line running across the arena (along Z) at the given X —
	# the red (start) / blue (finish) dashed lines from the reference floor.
	var n := 7
	var z0 := -ARENA_HZ + 0.7
	var z1 := ARENA_HZ - 0.7
	for i in n:
		var z: float = lerp(z0, z1, float(i) / float(n - 1))
		spawn_marker(Vector3(x, 0.07, z), Vector3(0.42, 0.14, 1.05), color)

func _scatter_stars() -> void:
	# Small painted golden stars sprinkled across the floor (purely decorative),
	# kept clear of the centre trophy and the player lanes' spawn band.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i in 13:
		var px := rng.randf_range(-ARENA_HX + 2.0, ARENA_HX - 2.0)
		var pz := rng.randf_range(-ARENA_HZ + 1.2, ARENA_HZ - 1.2)
		if absf(px) < 1.8 and absf(pz) < 1.8:
			continue   # leave the centre clear for the trophy
		paint_decal(STAR_DECAL, Vector3(px, 0.0, pz),
					rng.randf_range(0.7, 1.0), Palette.WARN, rng.randf_range(-0.6, 0.6))

func _trophy_emblem() -> void:
	# A flat golden trophy emblem painted on the arena centre — the toy-box
	# "goal" icon from the reference. Built from thin shapes laid on the floor
	# (XZ plane), oriented upright toward the camera (cup toward -Z = up-screen).
	# Emissive so it glows like painted floor art.
	var root := Node3D.new()
	add_child(root)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Palette.WARN
	gold.roughness = 0.35
	gold.metallic = 0.2
	gold.emission_enabled = true
	gold.emission = Palette.WARN
	gold.emission_energy_multiplier = 0.6
	var y := 0.05
	var th := 0.06   # emblem thickness

	# (x_size, z_size, z_center) blocky pieces forming a trophy silhouette
	var parts := [
		Vector2(1.10, 0.60),   # cup bowl
		Vector2(0.46, 0.22),   # neck
		Vector2(0.18, 0.30),   # stem
		Vector2(0.66, 0.16),   # base plate
	]
	var z_centers := [-0.62, -0.20, 0.06, 0.34]
	for i in parts.size():
		var p: Vector2 = parts[i]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(p.x, th, p.y)
		mi.mesh = bm; mi.material_override = gold
		mi.position = Vector3(0, y, z_centers[i])
		root.add_child(mi)

	# Two ring handles flanking the cup (flat tori read as rings from above)
	for sx in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		var h_m := TorusMesh.new(); h_m.inner_radius = 0.10; h_m.outer_radius = 0.22
		h.mesh = h_m; h.material_override = gold
		h.position = Vector3(sx * 0.62, y, -0.62)
		root.add_child(h)

func _game_process(delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		var av = avatars[p.id]
		if InputManager.get_action_just(p.id):
			_spd[p.id] = minf(MAX_SPEED, _spd[p.id] + TAP_IMPULSE)
			av.pop()
		_spd[p.id] = maxf(0.0, _spd[p.id] - FRICTION * delta)
		if _spd[p.id] > 0.01:
			av.global_position.x += _spd[p.id] * delta
			av.face(Vector2(1, 0))
		if av.global_position.x >= _finish_x:
			p.finished = true
			_order.append(p.id)
	if _order.size() >= players.size():
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var ranking := _order.duplicate()
	var rest := []
	for p in players:
		if not p.finished:
			rest.append(p)
	rest.sort_custom(func(a, b): return avatars[a.id].global_position.x > avatars[b.id].global_position.x)
	for p in rest:
		ranking.append(p.id)
	return award_by_rank(ranking)
