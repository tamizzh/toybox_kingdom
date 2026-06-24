class_name Avatar3D
extends CharacterBody3D

# Generic 3D avatar. Loads the shared mascot GLB (cute blob) and recolours it
# per player. Falls back to procedural geometry if the GLB is not yet present.

@export var speed: float = 6.0
@export var momentum: float = 0.0
@export var acceleration: float = 40.0
var auto_input: bool = true
var data: PlayerData
var player_id: int = 0
var dead: bool = false

var _visual: Node3D
var _last_dir: Vector2 = Vector2.RIGHT
var _body_mats: Array[ShaderMaterial] = []

# Glossy designer-vinyl body shader (half-lambert + fake SSS + rim).
const _VINYL_SHADER := preload("res://shaders/vinyl_toy.gdshader")

var _bob_t: float = 0.0
var _dust_t: float = 0.0

static var _capsule_shape: CapsuleShape3D
static var _dust_mesh: CylinderMesh
static var _ring_mesh: CylinderMesh
static var _spark_mesh: SphereMesh

# ─────────────────────────────────────────────────────────────────── setup ──
func setup(p: PlayerData) -> void:
	data       = p
	player_id  = p.id
	collision_layer = 1
	collision_mask  = 1 | 2   # 2 = walls/crates, 1 = other avatars (no overlap)

	_bob_t = randf() * TAU   # stagger so avatars don't bob in sync

	var col := CollisionShape3D.new()
	col.shape = _shared_capsule_shape()
	col.position = Vector3(0, 0.56, 0)   # centre = height/2 keeps feet on y=0
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)
	_build_default_visual(p.color)

# ──────────────────────────────────────────────────── mascot GLB visual ──
const MASCOT := preload("res://assets/mascot.glb")

func _build_default_visual(c: Color) -> void:
	# Scale 1.6 (the new mascot reads better at double size). It's modelled around
	# its centre (AABB min_y ≈ -0.557), so lift it by -min_y*scale (≈0.891) to seat
	# the feet on Y=0 / the ground. +90° Y so its face points along travel.
	set_model(MASCOT, 1.6, 0.891, 90.0)
	_recolor_mascot(_visual, c)

func _recolor_mascot(node: Node, c: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var n := child.name.to_lower()
			# Skip small detail meshes — eyes, pupils, cheek blush keep their own colors.
			# NOTE: cheeks are intentionally recolored with the body so the pink
			# blush doesn't wash the body toward pink/purple (esp. on the blue ball).
			var is_detail := "eye" in n or "pupil" in n \
							 or "iris" in n or "shine" in n or "highlight" in n \
							 or "white" in n or "face" in n or "crown" in n
			# The new mascot.glb uses generic "Sphere_NNN" part names, so the name
			# check above can't spot its accents — also keep any part that's near-white
			# in the source art (eye/face/belly), which the kingdom colour would flood.
			if not is_detail:
				var src: Material = child.get_surface_override_material(0)
				if src == null and child.mesh != null:
					src = child.mesh.surface_get_material(0)
				if src is StandardMaterial3D:
					var a: Color = (src as StandardMaterial3D).albedo_color
					if a.r > 0.85 and a.g > 0.85 and a.b > 0.85:
						is_detail = true
			if not is_detail:
				# Deepen + saturate the base so the bright high-key lighting reads it
				# as vivid red/blue (raw palette colors wash out to pastel under fill).
				var deep := c
				deep.s = clampf(deep.s * 1.12, 0.0, 1.0)
				deep.v = deep.v * 0.82
				var mat := ShaderMaterial.new()
				mat.shader = _VINYL_SHADER
				mat.set_shader_parameter("base_color", deep)
				mat.set_shader_parameter("roughness", 0.20)
				mat.set_shader_parameter("wrap", 0.28)  # more shading contrast → deeper, truer red/blue
				mat.set_shader_parameter("sss_strength", 0.10)  # subtle warmth only — keeps red red and blue blue
				child.material_override = mat
				_body_mats.append(mat)
		_recolor_mascot(child, c)

# ───────────────────────────── external model (e.g. tank.glb) ──
func set_model(scene: PackedScene, model_scale: float = 1.0, y: float = 0.0, y_rot_deg: float = 0.0) -> void:
	for c in _visual.get_children():
		c.queue_free()
	_body_mats.clear()
	var m := scene.instantiate()
	m.scale    = Vector3.ONE * model_scale
	m.position = Vector3(0, y, 0)
	m.rotation = Vector3(0, deg_to_rad(y_rot_deg), 0)   # model's own facing offset (composes with face())
	_visual.add_child(m)

# ──────────────────────────────────────────────────── animations ──
func _process(delta: float) -> void:
	if dead or not _visual:
		return
	_bob_t += delta * 2.8
	_visual.position.y = sin(_bob_t) * 0.048

func _physics_process(_dt: float) -> void:
	if dead or not auto_input:
		return
	var mv     := InputManager.get_move(player_id)
	var target := Vector3(mv.x, 0.0, mv.y) * speed
	if momentum > 0.0:
		velocity = velocity.move_toward(target, acceleration * _dt)
	else:
		velocity = target
	move_and_slide()
	if mv.length() > 0.1:
		face(mv)

	# Dust puff while running
	_dust_t -= _dt
	if velocity.length() > 2.8 and _dust_t <= 0.0:
		_dust_t = 0.2
		_spawn_dust()

func _spawn_dust() -> void:
	var parent := get_parent()
	if not parent:
		return
	var d   := MeshInstance3D.new()
	d.mesh = _shared_dust_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color  = Color(1, 1, 1, 0.55)
	mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	d.material_override = mat
	parent.add_child(d)
	d.global_position = global_position + Vector3(0, 0.08, 0)
	var tw := d.create_tween()
	tw.parallel().tween_property(d, "scale", Vector3(2.2, 0.1, 2.2), 0.32)
	tw.parallel().tween_property(mat, "albedo_color", Color(1, 1, 1, 0.0), 0.32)
	tw.tween_callback(d.queue_free)

# ──────────────────────────────────────────────────── API ──
func set_body_color(c: Color) -> void:
	for mat in _body_mats:
		mat.set_shader_parameter("base_color", c)

func set_body_scale(s: float) -> void:
	if _visual:
		_visual.scale = Vector3.ONE * s

func face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	_last_dir = dir.normalized()
	_visual.rotation.y = atan2(-dir.y, dir.x)

func facing_dir() -> Vector2:
	return _last_dir

func set_dead() -> void:
	dead = true
	AudioManager.play("eliminate", randf_range(0.95, 1.08))
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask",  0)
	if _visual:
		_play_death_anim()
	else:
		visible = false

func _play_death_anim() -> void:
	# Squish on impact, then spin-shrink to nothing
	_visual.scale = Vector3(1.45, 0.45, 1.45)
	var tw := _visual.create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_visual, "rotation:y",
		_visual.rotation.y + TAU * 1.5, 0.36) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.30) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		_spawn_death_burst()
		visible = false
	)

func _spawn_death_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var c := data.color if data else Color.WHITE
	var origin := global_position + Vector3(0, 0.9, 0)

	# Shockwave ring
	var ring := MeshInstance3D.new()
	ring.mesh = _shared_ring_mesh()
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = c; rmat.emission_enabled = true
	rmat.emission = c; rmat.emission_energy_multiplier = 1.2
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rmat
	parent.add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.08, 0)
	var rtw := ring.create_tween()
	rtw.parallel().tween_property(ring, "scale", Vector3(7.0, 1.0, 7.0), 0.42)
	rtw.parallel().tween_property(rmat, "albedo_color", Color(c, 0.0), 0.42)
	rtw.tween_callback(ring.queue_free)

	# 8 sparks flying outward
	for i in 8:
		var spark := MeshInstance3D.new()
		spark.mesh = _shared_spark_mesh()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c; mat.emission_enabled = true
		mat.emission = c; mat.emission_energy_multiplier = 0.9
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark.material_override = mat
		parent.add_child(spark)
		spark.global_position = origin
		var angle := TAU * float(i) / 8.0
		var end_p := origin + Vector3(cos(angle), randf_range(0.4, 1.6), sin(angle)) \
			* randf_range(1.8, 3.2)
		var stw := spark.create_tween()
		stw.parallel().tween_property(spark, "global_position", end_p, 0.48)
		stw.parallel().tween_property(mat, "albedo_color", Color(c, 0.0), 0.48)
		stw.parallel().tween_property(spark, "scale", Vector3(0.15, 0.15, 0.15), 0.48)
		stw.tween_callback(spark.queue_free)

func revive(pos: Vector3) -> void:
	dead  = false
	visible = true
	global_position = pos
	if _visual:
		_visual.scale = Vector3.ONE
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask",  1 | 2)

func pop() -> void:
	if not _visual:
		return
	_visual.scale = Vector3(1.22, 0.78, 1.22)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_visual, "scale", Vector3.ONE, 0.2)

func _shared_capsule_shape() -> CapsuleShape3D:
	if not _capsule_shape:
		_capsule_shape = CapsuleShape3D.new()
		_capsule_shape.radius = 0.48
		_capsule_shape.height = 1.12
	return _capsule_shape

func _shared_dust_mesh() -> CylinderMesh:
	if not _dust_mesh:
		_dust_mesh = CylinderMesh.new()
		_dust_mesh.top_radius = 0.28
		_dust_mesh.bottom_radius = 0.28
		_dust_mesh.height = 0.05
	return _dust_mesh

func _shared_ring_mesh() -> CylinderMesh:
	if not _ring_mesh:
		_ring_mesh = CylinderMesh.new()
		_ring_mesh.top_radius = 0.25
		_ring_mesh.bottom_radius = 0.25
		_ring_mesh.height = 0.07
	return _ring_mesh

func _shared_spark_mesh() -> SphereMesh:
	if not _spark_mesh:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.20
		_spark_mesh.height = 0.40
	return _spark_mesh
