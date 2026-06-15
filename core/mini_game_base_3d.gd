class_name MiniGameBase3D
extends Node3D

# 3D counterpart of MiniGameBase. Same lifecycle, signals and scoring helpers so
# GameManager/HUD drive it identically, but the world is real 3D: a Camera3D,
# lighting, an XZ-plane arena and Avatar3D players. The HUD/countdown stay 2D on
# a CanvasLayer overlay.

enum WinType { LAST_ALIVE, HIGH_SCORE, FAST_TIME }

signal round_finished(results)
signal time_changed(seconds_left)
signal status_changed(text)

@export var game_title: String = "Mini Game"
@export var round_duration: float = 30.0
@export var win_condition: WinType = WinType.HIGH_SCORE

var category: String = ""
var slug: String = ""
var tagline: String = ""                    # short instruction shown in the HUD banner
var action_label: String = "ACTION"         # on-screen action-button verb; set in _setup_round
var arena_color: Color = Palette.ARENA_BG  # warm tabletop — override per-game if desired

# Illustrated floor texture paths per game category.
# build_arena() loads and passes these automatically.
const _FLOOR_TEX := {
	"Racing":   "res://assets/arenas/racing.png",
	"Combat":   "res://assets/arenas/combat.png",
	"Growth":   "res://assets/arenas/growth.png",
	"Sports":   "res://assets/arenas/sports.png",
	"Platform": "res://assets/arenas/platform.jpg",
	"Reaction": "res://assets/arenas/reaction.png",
}

# Drop-in replacement for `add_child(WallArena3D.build(...))` that automatically
# applies the illustrated category floor texture.
func build_arena(half_x: float = ARENA_HX, half_z: float = ARENA_HZ,
				  wall_h: float = 1.6, t: float = 0.95,
				  props: bool = true, crates: bool = true) -> Node3D:
	var tex: Texture2D = null
	if _FLOOR_TEX.has(category):
		tex = load(_FLOOR_TEX[category])
	return WallArena3D.build(half_x, half_z, wall_h, t, props, crates, tex)

const AVATAR := preload("res://players/avatar3d.gd")

# world-space play area (centred on origin, XZ plane)
const ARENA_HX := 12.0
const ARENA_HZ := 7.0

var players: Array = []
var avatars: Dictionary = {}      # id -> Avatar3D
var elapsed: float = 0.0

var _timer: RoundTimer
var _finished: bool = false
var _counting_down: bool = false
var _ui: CanvasLayer              # 2D overlay for countdown / labels
var _cam: Camera3D                # framed to fill the viewport at any aspect
var _cam_rest_pos: Vector3        # saved resting position for screen-shake restore

# camera framing: it sits along CAM_DIR looking at the origin; the distance is
# solved per-frame-size so the arena fits the screen. FRAME_MARGIN=1.0 fills the
# frame edge-to-edge (arena takes full width/height); >1.0 pulls back to show the
# garden border, <1.0 crops in.
const CAM_DIR := Vector3(0, 17, 12)
const CAM_FOV := 50.0
const FRAME_MARGIN := 1.14

# ------------------------------------------------------------------ lifecycle
func start_game(player_list: Array) -> void:
	players = player_list
	for p in players:
		p.reset_round()
	_build_world()
	_timer = RoundTimer.new()
	add_child(_timer)
	_timer.tick.connect(func(t): time_changed.emit(t))
	_timer.finished.connect(_on_time_up)
	_setup_round()
	status_changed.emit(game_title)
	_start_countdown()

func _build_world() -> void:
	# Toy-box lighting: bright characters over a dark stone floor.
	# Strong ambient + warm key + overhead fill keep mascots readable without
	# flattening the coloured walls.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = arena_color          # warm tabletop seen outside arena
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color("d8e8f8")  # cool sky tint
	env.ambient_light_energy = 0.65             # keep dark floor dark, characters still lit
	# Gentle bloom — makes bright walls, player discs and collectibles glow softly
	# for the glossy toy-box feel (supported on the mobile renderer).
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.95
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Key light — warm sun, soft shadow
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -35, 0)
	key.light_color    = Color("fff4e0")
	key.light_energy   = 1.6
	key.shadow_enabled = true
	key.shadow_opacity = 0.35
	add_child(key)

	# Fill light — cool blue opposite side
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 148, 0)
	fill.light_color    = Color("b8d0ff")
	fill.light_energy   = 0.50
	fill.shadow_enabled = false
	add_child(fill)

	# Overhead dome OmniLight — kills dark corners, keeps arena uniformly bright
	var dome := OmniLight3D.new()
	dome.position = Vector3(0, 10, 0)
	dome.light_color = Color("fff8f0")
	dome.light_energy = 0.9
	dome.omni_range = 28.0
	dome.shadow_enabled = false
	add_child(dome)

	# top-down-ish perspective camera, framed to fill whatever viewport we get
	# (desktop, mobile landscape, or portrait). Re-frames on rotation / resize.
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(_cam)
	_frame_camera()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_frame_camera):
		vp.size_changed.connect(_frame_camera)

	# 2D overlay layer for countdown + instruction labels
	_ui = CanvasLayer.new()
	add_child(_ui)

# Solve the camera distance so the entire arena (plus a little headroom for tall
# models) fits the current viewport, then sit there. Filling the smaller axis
# means the arena is as large as it can be while staying fully on-screen.
func _frame_camera() -> void:
	if not _cam:
		return
	var vp := get_viewport()
	if not vp:
		return
	var size := vp.get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	var t: float = tan(deg_to_rad(CAM_FOV) * 0.5)
	var th: float = t * aspect

	var vd := CAM_DIR.normalized()
	var f := -vd
	var r := f.cross(Vector3.UP).normalized()
	if r.length() < 0.001:
		r = Vector3.RIGHT
	var u := r.cross(f).normalized()

	var hy := 1.3
	var corners := [
		Vector3(-ARENA_HX, 0, -ARENA_HZ), Vector3(ARENA_HX, 0, -ARENA_HZ),
		Vector3(-ARENA_HX, 0,  ARENA_HZ), Vector3(ARENA_HX, 0,  ARENA_HZ),
		Vector3(-ARENA_HX, hy, -ARENA_HZ), Vector3(ARENA_HX, hy, -ARENA_HZ),
		Vector3(-ARENA_HX, hy,  ARENA_HZ), Vector3(ARENA_HX, hy,  ARENA_HZ),
	]

	var lo := 5.0
	var hi := 400.0
	for _i in 44:
		var mid := (lo + hi) * 0.5
		if _arena_fits(vd * mid, f, r, u, t, th, corners):
			hi = mid
		else:
			lo = mid

	_cam.position = vd * (hi * FRAME_MARGIN)
	_cam_rest_pos = _cam.position
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	_cam.make_current()

func _arena_fits(cpos: Vector3, f: Vector3, r: Vector3, u: Vector3, t: float, th: float, corners: Array) -> bool:
	for p in corners:
		var rel: Vector3 = p - cpos
		var depth: float = rel.dot(f)
		if depth <= 0.01:
			return false
		if absf(rel.dot(r) / depth) > th or absf(rel.dot(u) / depth) > t:
			return false
	return true

func _start_countdown() -> void:
	_counting_down = true
	for av in avatars.values():
		av.auto_input = false

	# First time this game is played: a quick rule card so players know the goal.
	if not SaveManager.game_seen(slug):
		SaveManager.mark_game_seen(slug)
		await _show_rule_card()

	# Container so we can animate scale from the screen centre in one tween.
	var ctr := Control.new()
	ctr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctr.pivot_offset = Vector2(Palette.DESIGN_W * 0.5, Palette.DESIGN_H * 0.5)
	_ui.add_child(ctr)

	# Drop shadow (slightly offset, semi-transparent dark)
	var shadow := Label.new()
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shadow.size = Vector2(Palette.DESIGN_W, Palette.DESIGN_H)
	shadow.position = Vector2(5, 8)
	shadow.add_theme_font_size_override("font_size", 152)
	shadow.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1, 0.45))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctr.add_child(shadow)

	var overlay := Label.new()
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.size = Vector2(Palette.DESIGN_W, Palette.DESIGN_H)
	overlay.add_theme_font_size_override("font_size", 152)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctr.add_child(overlay)

	# Steady "how to play" line under the count so first-timers know the goal.
	var howto: Label = null
	if tagline != "":
		howto = Label.new()
		howto.text = tagline
		howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		howto.size = Vector2(Palette.DESIGN_W, 60)
		howto.position = Vector2(0, Palette.DESIGN_H * 0.66)
		howto.add_theme_font_size_override("font_size", 34)
		howto.add_theme_color_override("font_color", Color.WHITE)
		howto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		howto.add_theme_constant_override("outline_size", 8)
		howto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(howto)

	for n in [3, 2, 1]:
		overlay.text = str(n)
		shadow.text = str(n)
		AudioManager.play("count")
		overlay.add_theme_color_override("font_color", Palette.WARN)
		ctr.modulate = Color.WHITE
		ctr.scale = Vector2(0.35, 0.35)
		var tw_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw_in.tween_property(ctr, "scale", Vector2(1.0, 1.0), 0.22)
		await tw_in.finished
		var tw_out := create_tween()
		tw_out.tween_property(ctr, "modulate:a", 0.05, 0.5)
		await tw_out.finished

	overlay.text = "GO!"
	shadow.text = "GO!"
	AudioManager.play("go")
	overlay.add_theme_color_override("font_color", Palette.SAFE)
	ctr.modulate = Color.WHITE
	ctr.scale = Vector2(0.25, 0.25)
	var tw_go := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_go.tween_property(ctr, "scale", Vector2(1.25, 1.25), 0.18)
	await tw_go.finished
	var tw_go_out := create_tween()
	tw_go_out.tween_property(ctr, "modulate:a", 0.0, 0.28)
	if howto:
		tw_go_out.parallel().tween_property(howto, "modulate:a", 0.0, 0.28)
	await tw_go_out.finished
	ctr.queue_free()
	if howto:
		howto.queue_free()

	_counting_down = false
	for av in avatars.values():
		av.auto_input = true
	_timer.start(round_duration)

func _process(delta: float) -> void:
	if _finished or _counting_down:
		return
	elapsed += delta
	_game_process(delta)

# -------------------------------------------------------------- virtuals
func _setup_round() -> void:
	pass

func _game_process(_delta: float) -> void:
	pass

func _compute_results() -> Dictionary:
	return {}

func _on_time_up() -> void:
	finish_round(_compute_results())

# True only while the round is actually playable (past the countdown, not finished).
# AIController uses this so CPUs don't fire inputs during the 3-2-1.
func is_playing() -> bool:
	return not _counting_down and not _finished

# Brief, auto-advancing "how to play" card for a game's first appearance.
func _show_rule_card() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	var card := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("23203f")
	st.border_color = Color(Palette.WARN, 0.9)
	st.set_border_width_all(3)
	st.set_corner_radius_all(26)
	card.add_theme_stylebox_override("panel", st)
	card.size = Vector2(720, 232)
	card.position = Vector2(Palette.CENTER_X - 360, Palette.DESIGN_H * 0.5 - 116)
	card.pivot_offset = Vector2(360, 116)
	card.scale = Vector2(0.5, 0.5)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(card)

	_card_label(game_title.to_upper(), 44, Vector2(0, 24), Vector2(720, 56), Color.WHITE, card)
	if tagline != "":
		_card_label(tagline, 26, Vector2(20, 92), Vector2(680, 64), Color(1, 1, 1, 0.9), card)
	var hint := "Move with the stick to play!"
	if action_label != "ACTION":
		hint = "Stick to move   ·   Button = %s" % action_label
	_card_label(hint, 20, Vector2(0, 174), Vector2(720, 30), Palette.WARN, card)

	var tw := dim.create_tween()
	tw.tween_property(dim, "color:a", 0.5, 0.18)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.32) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(2.4).timeout
	var out := dim.create_tween()
	out.tween_property(dim, "modulate:a", 0.0, 0.25)
	await out.finished
	dim.queue_free()

func _card_label(text: String, fs: int, pos: Vector2, sz: Vector2, color: Color, parent: Node) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

# ------------------------------------------------------------------ helpers
func make_label(text: String, pos: Vector2, font_size: int = 28, color: Color = Palette.ACCENT) -> Label:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.72)
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left   = 18
	style.content_margin_right  = 18
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	pill.position = pos
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(pill)

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(l)
	return l

func spawn_avatars(spawn_points: Array) -> void:
	for i in players.size():
		var p: PlayerData = players[i]
		var av := AVATAR.new()
		add_child(av)
		av.setup(p)
		av.global_position = spawn_points[i % spawn_points.size()]
		avatars[p.id] = av

func get_avatar(id: int) -> Node:
	return avatars.get(id, null)

func corner_spawns(margin: float = 1.5) -> Array:
	var x := ARENA_HX - margin
	var z := ARENA_HZ - margin
	return [
		Vector3(-x, 0.0, -z),
		Vector3( x, 0.0,  z),
		Vector3( x, 0.0, -z),
		Vector3(-x, 0.0,  z),
	]

func lane_spawns(at_x: float) -> Array:
	var pts := []
	var n := players.size()
	for i in n:
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 1.0) / (n + 1.0)
		pts.append(Vector3(at_x, 0.0, z))
	return pts

func clamp_avatar(av: Node, pad: float = 0.65) -> void:
	av.global_position.x = clampf(av.global_position.x, -ARENA_HX + pad, ARENA_HX - pad)
	av.global_position.z = clampf(av.global_position.z, -ARENA_HZ + pad, ARENA_HZ - pad)

func spawn_marker(center: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		m.emission_enabled = true
		m.emission = color
	mi.material_override = m
	mi.position = center
	add_child(mi)
	return mi

func xz(v: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)

func spawn_ball(radius: float, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.emission_enabled = true
		m.emission = color
	mi.material_override = m
	add_child(mi)
	return mi

func spawn_disc(radius: float, color: Color, y: float = 0.04) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(0, y, 0)
	add_child(mi)
	return mi

func make_bar(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = pos
	cr.size = size
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(cr)
	return cr

# -------------------------------------------------------------- scoring
func eliminate(id: int) -> void:
	var p := _player(id)
	if p and p.alive:
		p.alive = false
		if avatars.has(id):
			avatars[id].set_dead()
		check_last_alive()

func survivors() -> Array:
	var s := []
	for p in players:
		if p.alive:
			s.append(p)
	return s

func check_last_alive() -> void:
	if win_condition != WinType.LAST_ALIVE:
		return
	var threshold := 0 if players.size() <= 1 else 1
	if survivors().size() <= threshold:
		finish_round(_compute_results())

func award_by_rank(order: Array) -> Dictionary:
	var results := {}
	var n := order.size()
	if n == 1:
		results[order[0]] = 1
		return results
	for i in n:
		results[order[i]] = maxi(0, n - 1 - i)
	return results

func rank_by_value(values: Dictionary, higher_better: bool = true) -> Dictionary:
	var ids := values.keys()
	ids.sort_custom(func(a, b):
		return values[a] > values[b] if higher_better else values[a] < values[b])
	return award_by_rank(ids)

func survivor_results(points: int = 3) -> Dictionary:
	var results := {}
	for p in players:
		results[p.id] = points if p.alive else 0
	return results

func time_left() -> float:
	return _timer.time_left if _timer else 0.0

func finish_round(results: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	if _timer:
		_timer.stop()
	for p in players:
		if not results.has(p.id):
			results[p.id] = 0
	# Crown the round winner's mascot (games with on-field avatars).
	var win_id := -1
	var best := -10000000
	for id in results:
		if int(results[id]) > best:
			best = int(results[id])
			win_id = id
	if win_id >= 0 and best > 0 and avatars.has(win_id):
		_spawn_crown(avatars[win_id])
	_play_win_effects()
	round_finished.emit(results)

# Floating, spinning golden crown above the winning mascot — the celebratory beat
# from the reference win screens.
func _spawn_crown(av: Node3D) -> void:
	var crown := Node3D.new()
	add_child(crown)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffd23f")
	gold.metallic = 0.5
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color("ffae1f")
	gold.emission_energy_multiplier = 0.6
	# band
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.8; bm.bottom_radius = 0.88; bm.height = 0.6
	band.mesh = bm
	band.material_override = gold
	crown.add_child(band)
	# points
	for i in 6:
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0; sm.bottom_radius = 0.2; sm.height = 0.7
		spike.mesh = sm
		spike.material_override = gold
		var a := TAU * float(i) / 6.0
		spike.position = Vector3(cos(a) * 0.72, 0.6, sin(a) * 0.72)
		crown.add_child(spike)
	crown.global_position = av.global_position + Vector3(0, 2.9, 0)
	crown.scale = Vector3.ZERO
	var tw := crown.create_tween()
	tw.tween_property(crown, "scale", Vector3.ONE * 1.3, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(crown, "rotation:y", TAU * 2.0, 2.6)
	tw.parallel().tween_property(crown, "global_position:y",
		crown.global_position.y + 0.4, 1.3).set_trans(Tween.TRANS_SINE)

func _play_win_effects() -> void:
	AudioManager.play("round_win")
	# Camera shake — nudge then return to resting position
	if _cam and _cam_rest_pos != Vector3.ZERO:
		var orig := _cam_rest_pos
		var tw := create_tween()
		for _i in 5:
			tw.tween_property(_cam, "position",
				orig + Vector3(randf_range(-0.28, 0.28), randf_range(-0.14, 0.14), randf_range(-0.14, 0.14)),
				0.045)
		tw.tween_property(_cam, "position", orig, 0.07)

	# Confetti — coloured flat boxes falling from above
	var conf_colors := [
		Color("f02828"), Color("1878f0"), Color("10b83c"), Color("f5c018"),
		Color("f040a0"), Color("40e0ff"), Color("ff8820"),
	]
	for _i in 24:
		var conf := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.32, 0.06, 0.22)
		conf.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = conf_colors[randi() % conf_colors.size()]
		conf.material_override = cmat
		conf.position = Vector3(
			randf_range(-ARENA_HX * 0.75, ARENA_HX * 0.75),
			randf_range(4.5, 6.5),
			randf_range(-ARENA_HZ * 0.75, ARENA_HZ * 0.75)
		)
		add_child(conf)
		var fall := create_tween()
		var duration := randf_range(1.1, 2.0)
		fall.tween_property(conf, "position:y", -2.5, duration)
		fall.parallel().tween_property(conf, "rotation",
			Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU)), duration)
		fall.tween_callback(conf.queue_free)

func _player(id: int) -> PlayerData:
	for p in players:
		if p.id == id:
			return p
	return null
