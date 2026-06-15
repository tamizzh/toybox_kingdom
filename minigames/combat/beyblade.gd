extends MiniGameBase3D

# Beyblade — rip-launch spinning tops into the stadium and clash. Each player gets a
# real bey (not a mascot): aim with the stick, HOLD to wind up launch power, release
# to rip it in. A stronger launch = faster bey with more spin. After launch you can
# nudge it a little. Clashes drain spin from both tops (harder hits drain more) and
# spin also bleeds away on its own. When a top runs out of spin it topples — last
# bey spinning wins. (3D, no avatars)

const R := 6.2                 # stadium radius (tops bounce off the rim)
const TOP_R := 0.62            # collision radius of a bey
const MAX_SPEED := 13.0
const FRICTION := 1.2          # gentle drag per second once spinning
const SPIN_DRAIN := 0.045      # passive spin loss per second
const HIT_DRAIN := 0.024       # spin loss per unit of clash impact
const WALL_DRAIN := 0.010      # spin loss per unit of rim-impact speed
const STEER_ACCEL := 6.0       # post-launch nudge strength

# Rip-launch feel: drag the stick back to wind up, release to fling it in fast.
const CHARGE_TIME := 0.5       # seconds of wind-up for a full-power launch
const LAUNCH_MIN := 6.5        # speed of a flick launch
const LAUNCH_RANGE := 9.5      # extra speed added at full wind-up
const AIM_TIMEOUT := 3.6       # auto-rip if a player just sits there

const BAR_W := 200.0
const BAR_FILL := 188.0

var _beys := {}                # id -> per-bey state dict
var _clash_sfx_cd := 0.0
var _bars_fill := {}           # id -> ColorRect spin meter fill

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	action_label = "RIP"
	arena_color = Palette.category_arena("Combat")

	add_child(ArenaProps3D.ground(ARENA_HX, ARENA_HZ))
	add_child(ArenaProps3D.scatter(ARENA_HX, ARENA_HZ, 4242))
	_build_stadium()

	# Each player gets a bey parked on a launch pad around the rim, aimed inward.
	for i in players.size():
		var p: PlayerData = players[i]
		var ang := TAU * i / players.size() - PI * 0.5
		var pad := Vector3(cos(ang), 0, sin(ang)) * (R * 0.86)
		var aim := Vector2(-pad.x, -pad.z).normalized()    # face the centre
		var root := _build_bey(p.color)
		add_child(root)
		root.global_position = pad + Vector3(0, 0.35, 0)
		var arrow := _build_arrow(p.color)
		root.add_child(arrow)
		_beys[p.id] = {
			"root": root, "spin_root": root.get_node("Spin"), "arrow": arrow,
			"vel": Vector3.ZERO, "spin": 1.0, "state": "aim",
			"power": 0.0, "aim": aim, "pad": pad, "t": 0.0, "charging": false,
		}
		_build_meter(p)
		_aim_arrow(p.id)

func _game_process(delta: float) -> void:
	_clash_sfx_cd = maxf(0.0, _clash_sfx_cd - delta)
	for p in players:
		if not p.alive:
			continue
		var b = _beys[p.id]
		match b.state:
			"aim":   _aim_phase(p.id, b, delta)
			"spin":  _spin_phase(p.id, b, delta)
	_resolve_clashes()
	for p in players:
		if p.alive and _beys[p.id].state == "spin" and _beys[p.id].spin <= 0.0:
			_topple(p.id)

# --------------------------------------------------------------- aim + launch
func _aim_phase(id: int, b: Dictionary, delta: float) -> void:
	b.t += delta
	var mv := InputManager.get_move(id)
	var mag: float = mv.length()
	# Aim by pointing the stick. Drag the stick (or hold the button) to wind up.
	if mag > 0.3:
		b.aim = mv.normalized()
	var winding: bool = mag > 0.3 or InputManager.get_action(id)

	if winding:
		b.charging = true
		# Pushing the stick harder winds faster — a quick flick rips in fast.
		b.power = minf(1.0, b.power + delta / CHARGE_TIME * (0.6 + mag))
		b.spin_root.rotation.y += delta * (8.0 + b.power * 34.0)   # revs up
	else:
		# Stick (or button) released after winding → fling it in.
		if b.charging and b.power > 0.08:
			_launch(id, b)
			return
		b.spin_root.rotation.y += delta * 6.0

	if b.power >= 1.0 or b.t >= AIM_TIMEOUT:
		if b.power < 0.35:
			b.power = 0.7        # an auto-rip still has decent power
		_launch(id, b)
		return
	_aim_arrow(id)

func _launch(id: int, b: Dictionary) -> void:
	var dir := Vector3(b.aim.x, 0, b.aim.y).normalized()
	b.vel = dir * (LAUNCH_MIN + LAUNCH_RANGE * b.power)
	b.spin = 0.7 + 0.3 * b.power
	b.state = "spin"
	b.arrow.visible = false
	b.root.global_position.y = 0.0
	AudioManager.play("go", randf_range(0.95, 1.1))
	_spawn_burst(b.root.global_position)

func _spin_phase(id: int, b: Dictionary, delta: float) -> void:
	var v: Vector3 = b.vel
	# light steering after launch
	var mv := InputManager.get_move(id)
	v += Vector3(mv.x, 0, mv.y) * STEER_ACCEL * delta
	v *= maxf(0.0, 1.0 - FRICTION * delta)
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED

	var pos: Vector3 = b.root.global_position + v * delta
	pos.y = 0.0
	# rim bounce
	var radial := Vector2(pos.x, pos.z)
	if radial.length() > R - TOP_R:
		var n3 := Vector3(-radial.normalized().x, 0, -radial.normalized().y)
		var into := -v.dot(n3)
		if into > 0.0:
			v = v.reflect(n3) * 0.9
			b.spin = maxf(0.0, b.spin - into * WALL_DRAIN)
		radial = radial.normalized() * (R - TOP_R)
		pos.x = radial.x; pos.z = radial.y
	b.vel = v
	b.root.global_position = pos

	# spin down, spin-rotate, and wobble harder as spin fades
	b.spin = maxf(0.0, b.spin - SPIN_DRAIN * delta)
	b.spin_root.rotation.y += (5.0 + b.spin * 26.0) * delta
	var wob: float = (1.0 - b.spin) * 0.18
	b.spin_root.rotation.x = sin(elapsed * 9.0) * wob
	b.spin_root.rotation.z = cos(elapsed * 9.0) * wob
	b.root.scale = Vector3.ONE * (0.7 + b.spin * 0.35)
	_update_meter(id, b.spin)

func _resolve_clashes() -> void:
	var ids := []
	for p in players:
		if p.alive and _beys[p.id].state == "spin":
			ids.append(p.id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var ba = _beys[ids[i]]
			var bb = _beys[ids[j]]
			var diff: Vector3 = bb.root.global_position - ba.root.global_position
			diff.y = 0.0
			var dist := diff.length()
			if dist >= TOP_R * 2.0 or dist < 0.001:
				continue
			var n := diff / dist
			var overlap := TOP_R * 2.0 - dist
			ba.root.global_position -= n * overlap * 0.5
			bb.root.global_position += n * overlap * 0.5
			var va_n: float = (ba.vel as Vector3).dot(n)
			var vb_n: float = (bb.vel as Vector3).dot(n)
			var transfer := (vb_n - va_n) * 1.15
			ba.vel += n * transfer
			bb.vel -= n * transfer
			var impact := absf(va_n - vb_n)
			ba.spin = maxf(0.0, ba.spin - impact * HIT_DRAIN)
			bb.spin = maxf(0.0, bb.spin - impact * HIT_DRAIN)
			if impact > 3.0:
				_spawn_clash((ba.root.global_position + bb.root.global_position) * 0.5)
				if _clash_sfx_cd <= 0.0:
					AudioManager.play("hit", randf_range(1.05, 1.25))
					_clash_sfx_cd = 0.12

func _topple(id: int) -> void:
	var b = _beys[id]
	b.state = "dead"
	AudioManager.play("eliminate", randf_range(0.9, 1.05))
	# fall over and fade out
	var tw = b.root.create_tween()
	tw.tween_property(b.root, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(b.root, "position:y", 0.0, 0.35)
	tw.tween_property(b.root, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(b.root.queue_free)
	eliminate(id)     # base scoring / last-alive (works without an avatar)

# ----------------------------------------------------------------- visuals
func _build_bey(color: Color) -> Node3D:
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)

	# wide metal energy ring (the disc that does the hitting)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = TOP_R; rm.bottom_radius = TOP_R; rm.height = 0.28
	rm.radial_segments = 6                       # chunky hexagon = bladed look
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.metallic = 0.7; rmat.roughness = 0.3
	rmat.emission_enabled = true; rmat.emission = color
	rmat.emission_energy_multiplier = 0.25
	ring.material_override = rmat
	ring.position = Vector3(0, 0.45, 0)
	spin.add_child(ring)

	# crown / face bolt on top
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12; cm.bottom_radius = 0.34; cm.height = 0.3
	crown.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = color.lightened(0.35)
	cmat.metallic = 0.6; cmat.roughness = 0.35
	crown.material_override = cmat
	crown.position = Vector3(0, 0.72, 0)
	spin.add_child(crown)

	# tapering body down to the tip
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = TOP_R * 0.8; bm.bottom_radius = 0.12; bm.height = 0.45
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = color.darkened(0.25)
	bmat.metallic = 0.4; bmat.roughness = 0.5
	body.material_override = bmat
	body.position = Vector3(0, 0.13, 0)
	spin.add_child(body)

	# metal tip
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.07; tm.bottom_radius = 0.03; tm.height = 0.12
	tip.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color("d8d8e0"); tmat.metallic = 0.9; tmat.roughness = 0.2
	tip.material_override = tmat
	tip.position = Vector3(0, -0.08, 0)
	spin.add_child(tip)
	return root

func _build_arrow(color: Color) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.06, 1.0)
	arrow.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true; m.emission = color
	m.emission_energy_multiplier = 0.6
	arrow.material_override = m
	return arrow

func _aim_arrow(id: int) -> void:
	var b = _beys[id]
	var arrow: MeshInstance3D = b.arrow
	var aim: Vector2 = b.aim
	var ang := atan2(aim.x, aim.y)            # PrismMesh tip points +Z
	arrow.rotation.y = ang
	var reach: float = 0.9 + b.power * 1.8
	arrow.position = Vector3(aim.x, -0.2, aim.y) * reach
	arrow.scale = Vector3(1.0, 1.0, 0.6 + b.power * 1.6)

func _build_stadium() -> void:
	var floor := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = R + 0.5; cyl.bottom_radius = R + 0.9; cyl.height = 1.0
	floor.mesh = cyl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2b2f3a"); fm.roughness = 0.6
	floor.material_override = fm
	floor.position = Vector3(0, -0.5, 0)
	add_child(floor)

	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = R - 0.1; tor.outer_radius = R + 0.45
	rim.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("ff8c1a")
	rmat.emission_enabled = true; rmat.emission = Color("ff8c1a")
	rmat.emission_energy_multiplier = 0.5
	rim.material_override = rmat
	rim.position = Vector3(0, 0.05, 0)
	add_child(rim)

# Spin meters sit in a centred row near the bottom — clear of the HUD score chips,
# timer and title banner that own the top of the screen.
func _build_meter(p: PlayerData) -> void:
	var n := players.size()
	var i := players.find(p)
	var gap := 16.0
	var total := n * BAR_W + (n - 1) * gap
	var x := Palette.CENTER_X - total * 0.5 + i * (BAR_W + gap)
	var y := 628.0
	make_label(p.display_name, Vector2(x + 6, y - 30), 18, p.color)
	make_bar(Vector2(x, y), Vector2(BAR_W, 22), Color(0, 0, 0, 0.5))
	_bars_fill[p.id] = make_bar(Vector2(x + 6, y + 3), Vector2(BAR_FILL, 16), p.color)

func _update_meter(id: int, spin: float) -> void:
	if _bars_fill.has(id):
		_bars_fill[id].size.x = BAR_FILL * spin

func _spawn_burst(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35; cyl.bottom_radius = 0.35; cyl.height = 0.05
	ring.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	add_child(ring)
	ring.global_position = at + Vector3(0, 0.1, 0)
	var tw := ring.create_tween()
	tw.parallel().tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.3)
	tw.parallel().tween_property(m, "albedo_color", Color(1, 1, 1, 0.0), 0.3)
	tw.tween_callback(ring.queue_free)

func _spawn_clash(at: Vector3) -> void:
	for _i in 6:
		var spark := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.12; sph.height = 0.24
		spark.mesh = sph
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("fff0a0")
		m.emission_enabled = true; m.emission = Color("ffd23f")
		spark.material_override = m
		add_child(spark)
		spark.global_position = at + Vector3(0, 0.6, 0)
		var ang := randf() * TAU
		var end_p := spark.global_position + Vector3(cos(ang), randf_range(0.3, 1.0), sin(ang)) * randf_range(1.0, 2.0)
		var tw := spark.create_tween()
		tw.parallel().tween_property(spark, "global_position", end_p, 0.32)
		tw.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.32)
		tw.tween_callback(spark.queue_free)

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = (_beys[p.id].spin as float) if p.alive else -1.0
	return rank_by_value(vals, true)
