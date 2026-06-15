class_name Avatar3D
extends CharacterBody3D

# Generic 3D avatar. Loads the shared mascot GLB (cute blob) and recolours it
# per player. Adds a cartoon outline via a normal-expansion shader. Falls back
# to procedural geometry if the GLB is not yet present.

@export var speed: float = 6.0
@export var momentum: float = 0.0
@export var acceleration: float = 40.0
var auto_input: bool = true
var data: PlayerData
var player_id: int = 0
var dead: bool = false

var _visual: Node3D
var _last_dir: Vector2 = Vector2.RIGHT
var _body_mats: Array[StandardMaterial3D] = []

var _bob_t: float = 0.0
var _dust_t: float = 0.0

# Shared outline shader across all avatar instances (created once, reused).
static var _outline_shader: Shader
static var _outline_material: ShaderMaterial
static var _capsule_shape: CapsuleShape3D
static var _disc_mesh: CylinderMesh
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

	# Glowing player-colour disc on the ground
	var disc := MeshInstance3D.new()
	disc.mesh = _shared_disc_mesh()
	var dm := StandardMaterial3D.new()
	dm.albedo_color            = p.color
	dm.emission_enabled        = true
	dm.emission                = p.color
	dm.emission_energy_multiplier = 0.5
	disc.material_override = dm
	disc.position = Vector3(0, 0.04, 0)
	add_child(disc)

	_visual = Node3D.new()
	add_child(_visual)
	_build_default_visual(p.color)

# ──────────────────────────────────────────────────── mascot GLB visual ──
const MASCOT := preload("res://players/mascot.glb")

func _build_default_visual(c: Color) -> void:
	# Blob sits with bottom at Y=0 (no offset). Scale 0.8 makes the mascots small
	# toys in a big arena, matching the reference art.
	set_model(MASCOT, 0.8, 0.0)
	_recolor_mascot(_visual, c)
	_add_outline(_visual)

func _recolor_mascot(node: Node, c: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var n := child.name.to_lower()
			# Skip outline passes added by _add_outline, and small detail meshes.
			var is_detail := "outline_" in n or "eye" in n or "pupil" in n \
							 or "iris" in n or "shine" in n or "highlight" in n \
							 or "white" in n or "cheek" in n
			if not is_detail:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = c
				mat.roughness = 0.50
				mat.metallic = 0.04
				child.material_override = mat
				_body_mats.append(mat)
		_recolor_mascot(child, c)

func _get_outline_shader() -> Shader:
	if not _outline_shader:
		_outline_shader = Shader.new()
		_outline_shader.code = """
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;
uniform float width : hint_range(0.001, 0.20) = 0.055;
uniform vec3  color : source_color = vec3(0.03, 0.02, 0.05);
void vertex() { VERTEX += NORMAL * width; }
	void fragment() { ALBEDO = color; }
"""
	return _outline_shader

func _get_outline_material() -> ShaderMaterial:
	if not _outline_material:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = _get_outline_shader()
	return _outline_material

func _add_outline(node: Node) -> void:
	for child in node.get_children():
		var n := child.name.to_lower()
		if "outline_" in n:
			continue  # never recurse into our own outline passes
		if child is MeshInstance3D and child.mesh != null:
			# Only outline the body — eye/pupil/shine/cheek parts look bad with outlines
			if "shine" not in n and "cheek" not in n and "eye" not in n and "pupil" not in n:
				var ol := MeshInstance3D.new()
				ol.name = "Outline_" + child.name
				ol.mesh = child.mesh
				ol.material_override = _get_outline_material()
				child.add_child(ol)
		_add_outline(child)

# ───────────────────────────── external model (e.g. tank.glb) ──
func set_model(scene: PackedScene, model_scale: float = 1.0, y: float = 0.0) -> void:
	for c in _visual.get_children():
		c.queue_free()
	_body_mats.clear()
	var m := scene.instantiate()
	m.scale    = Vector3.ONE * model_scale
	m.position = Vector3(0, y, 0)
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
		mat.albedo_color = c

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

func _shared_disc_mesh() -> CylinderMesh:
	if not _disc_mesh:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 0.52
		_disc_mesh.bottom_radius = 0.52
		_disc_mesh.height = 0.07
	return _disc_mesh

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
