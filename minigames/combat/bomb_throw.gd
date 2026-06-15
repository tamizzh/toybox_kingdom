extends MiniGameBase3D

# Throw timed bombs in your facing direction; explosions eliminate anyone close.
# Last alive wins.  (3D)

const FUSE := 1.4
const RADIUS := 3.2

var _facing := {}
var _cool := {}
var _bombs: Array = []

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	action_label = "THROW"
	add_child(build_arena())
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_facing[p.id] = Vector3(1, 0, 0)
		_cool[p.id] = 0.0
		avatars[p.id].speed = 6.8
	# Instruction shown by the HUD tagline banner.

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 1.0
			_throw(p)
	var keep := []
	for b in _bombs:
		b["fuse"] -= delta
		b["vel"] *= 0.95
		b["pos"] += b["vel"] * delta
		b["node"].position = b["pos"]
		# Pulse + flash red faster as the fuse runs out, so the threat is readable.
		var f: float = b["fuse"] / FUSE
		var blink: float = 0.5 + 0.5 * sin(b["fuse"] * lerpf(22.0, 6.0, f))
		var mat: StandardMaterial3D = b["mat"]
		mat.emission = Color(1.0, 0.25, 0.1).lerp(Color(1.0, 0.85, 0.2), f)
		mat.emission_energy_multiplier = 0.6 + blink * 2.2
		var s: float = 1.0 + (1.0 - f) * 0.35 + blink * 0.12
		b["node"].scale = Vector3(s, s, s)
		if b["fuse"] <= 0.0:
			_explode(b)
			b["node"].queue_free()
		else:
			keep.append(b)
	_bombs = keep

func _throw(p: PlayerData) -> void:
	AudioManager.play("tap", 0.8)
	var n := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.42; sph.height = 0.84
	n.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.10, 0.14)   # dark bomb body
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	n.material_override = mat
	add_child(n)
	_bombs.append({
		"pos": avatars[p.id].global_position + Vector3(0, 0.5, 0),
		"vel": _facing[p.id] * 8.0,
		"fuse": FUSE,
		"node": n,
		"mat": mat,
	})

func _explode(b: Dictionary) -> void:
	AudioManager.play("hit", randf_range(0.85, 1.0))
	for p in players:
		if p.alive and avatars[p.id].global_position.distance_to(b["pos"]) < RADIUS:
			eliminate(p.id)
	# Expanding shockwave so the blast radius is clearly visible.
	var flash := spawn_ball(0.4, Color(1.0, 0.7, 0.2), true)
	flash.position = b["pos"]
	var fmat: StandardMaterial3D = flash.material_override
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tw := flash.create_tween()
	tw.parallel().tween_property(flash, "scale", Vector3.ONE * (RADIUS / 0.4), 0.28)
	tw.parallel().tween_property(fmat, "albedo_color", Color(1.0, 0.4, 0.1, 0.0), 0.28)
	tw.tween_callback(flash.queue_free)

func _compute_results() -> Dictionary:
	return survivor_results(3)
