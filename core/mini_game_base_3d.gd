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
var arena_color: Color = Color(0.10, 0.11, 0.14)

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
	# environment + lights
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = arena_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)

	# top-down-ish perspective camera framing the whole arena
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.position = Vector3(0, 17.0, 12.0)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	cam.make_current()

	# 2D overlay layer for countdown + instruction labels
	_ui = CanvasLayer.new()
	add_child(_ui)

func _start_countdown() -> void:
	_counting_down = true
	for av in avatars.values():
		av.auto_input = false

	var overlay := Label.new()
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.size = Vector2(Palette.DESIGN_W, Palette.DESIGN_H)
	overlay.add_theme_font_size_override("font_size", 150)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(overlay)

	for n in [3, 2, 1]:
		overlay.text = str(n)
		overlay.add_theme_color_override("font_color", Palette.ACCENT)
		overlay.modulate = Color.WHITE
		var tw := create_tween()
		tw.tween_property(overlay, "modulate:a", 0.1, 0.75)
		await tw.finished

	overlay.text = "GO!"
	overlay.add_theme_color_override("font_color", Palette.SAFE)
	overlay.modulate = Color.WHITE
	var tw2 := create_tween()
	tw2.tween_property(overlay, "modulate:a", 0.0, 0.45)
	await tw2.finished
	overlay.queue_free()

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

# ------------------------------------------------------------------ helpers
func make_label(text: String, pos: Vector2, font_size: int = 28, color: Color = Palette.ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
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

func corner_spawns(margin: float = 2.0) -> Array:
	var x := ARENA_HX - margin
	var z := ARENA_HZ - margin
	return [
		Vector3(-x, 0.0, -z),
		Vector3( x, 0.0,  z),
		Vector3( x, 0.0, -z),
		Vector3(-x, 0.0,  z),
	]

func lane_spawns(at_x: float) -> Array:
	# evenly spaced along Z at a given X (X in [-ARENA_HX, ARENA_HX])
	var pts := []
	var n := players.size()
	for i in n:
		var z := -ARENA_HZ + 2.0 * ARENA_HZ * (i + 1.0) / (n + 1.0)
		pts.append(Vector3(at_x, 0.0, z))
	return pts

func clamp_avatar(av: Node, pad: float = 0.9) -> void:
	av.global_position.x = clampf(av.global_position.x, -ARENA_HX + pad, ARENA_HX - pad)
	av.global_position.z = clampf(av.global_position.z, -ARENA_HZ + pad, ARENA_HZ - pad)

# A quick coloured box marker in the world (slashes, bombs, obstacles, zones…).
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

# flat disc on the ground (rings/zones), returns the MeshInstance3D
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

# a Control bar on the 2D overlay (tug-of-war style meters)
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
	round_finished.emit(results)

func _player(id: int) -> PlayerData:
	for p in players:
		if p.id == id:
			return p
	return null
