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
var _death_tween: Tween    # the spin-shrink death anim; killed on revive so it can't hide a revived avatar
var _last_dir: Vector2 = Vector2.RIGHT
var _body_mats: Array[Material] = []

# Glossy designer-vinyl body shader (half-lambert + fake SSS + rim).
const _VINYL_SHADER := preload("res://shaders/vinyl_toy.gdshader")

var _bob_t: float = 0.0
var _dust_t: float = 0.0
var _anim: AnimationPlayer = null
var _cape: Node3D = null          # royal cape (player only); sways while moving
var _sway_t: float = 0.0
const ANIM_WALK := "ArmatureAction"   # rename if a different action is the walk cycle

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
	# y=0.750 lifts feet to Y=0 (GLB min_y=-0.750 at scale 1.0).
	# z=-1.629 corrects the GLB's X-center offset after the 90° Y rotation.
	set_model(MASCOT, 1.0, 0.750, 90.0)
	if _visual.get_child_count() > 0:
		_visual.get_child(0).position.z = -1.629
	_recolor_mascot(_visual, c)
	_anim = _find_anim_player(_visual)
	if _anim:
		_anim.speed_scale = 1.5
		_anim.play(ANIM_WALK)
		_anim.seek(randf() * _anim.current_animation_length, true)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var r := _find_anim_player(child)
		if r:
			return r
	return null

# Parts that must keep their own GLB materials (not recolored).
const _KEEP_PARTS := ["crown", "eye", "mouth", "pupil", "iris", "white"]

func _recolor_mascot(node: Node, c: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var n := child.name.to_lower()
			var keep := false
			for kw in _KEEP_PARTS:
				if kw in n:
					keep = true
					break
			if not keep:
				var vivid := c
				vivid.v = clampf(vivid.v * 0.88, 0.0, 1.0)
				var mat := StandardMaterial3D.new()
				mat.albedo_color      = vivid
				mat.roughness         = 0.42   # soft matte-plastic, less harsh
				mat.metallic          = 0.0
				mat.specular_mode     = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				child.material_override = mat
				# Store as a ShaderMaterial-compatible ref so set_body_color still works
				_body_mats.append(mat)
		_recolor_mascot(child, c)

# ─────────────────────────────────────────── The Toy King regalia ──
# Crowns the avatar with a glowing gold crown + a flowing kingdom-colour cape so the
# PLAYER reads instantly as royalty amid the identical rival blobs. Procedural (a few
# tiny prims) so it works on the externally-authored mascot.glb without regenerating
# it. Parented to _visual → inherits facing, body-scale, death/revive squash for free.
func make_royal(accent: Color) -> void:
	if _visual == null:
		return
	var box := _visual_local_aabb()
	var top_y := box.position.y + box.size.y
	var r := maxf(box.size.x, box.size.z) * 0.5

	# ── Gold crown: a band ring + five points, emissive so it blooms ──
	var crown := Node3D.new()
	crown.name = "crown"
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.20)
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.78, 0.18)
	gold.emission_energy_multiplier = 1.7      # past the scene HDR bloom threshold
	var cr := r * 0.52
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = cr
	band_mesh.bottom_radius = cr
	band_mesh.height = r * 0.30
	band_mesh.radial_segments = 10
	band.mesh = band_mesh
	band.material_override = gold
	crown.add_child(band)
	for i in 5:
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = cr * 0.30
		sm.height = r * 0.42
		sm.radial_segments = 6
		spike.mesh = sm
		spike.material_override = gold
		var ang := TAU * float(i) / 5.0
		spike.position = Vector3(cos(ang) * cr * 0.92, r * 0.30, sin(ang) * cr * 0.92)
		crown.add_child(spike)
	crown.position = Vector3(0, top_y - r * 0.06, 0)
	_visual.add_child(crown)

	# ── Cape: a tapered cloth trapezoid draping down the back (back = local -X) ──
	# Narrow at the neck, wide at the hem → a real cape silhouette (a flat box read
	# as a slab). Built as one double-sided quad in the Y-Z plane facing backward.
	var cape := Node3D.new()
	cape.name = "cape"
	var h     := box.size.y * 0.85
	var wt    := r * 0.50          # neck width (narrow at top)
	var wb    := r * 1.25          # hem width (wide at bottom)
	var drape := r * 0.65          # hem trails this far behind in local -X
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Pivot at top (Y=0, X=0 = back surface). Hem extends backward (-X) and down (-Y)
	# so the cape is a tilted quad visible from any horizontal camera angle.
	var tl := Vector3(0.0,    0.0, -wt * 0.5)
	var tr := Vector3(0.0,    0.0,  wt * 0.5)
	var bl := Vector3(-drape, -h,  -wb * 0.5)
	var br := Vector3(-drape, -h,   wb * 0.5)
	for v in [tl, bl, br, tl, br, tr]:
		st.add_vertex(v)
	st.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.mesh = st.commit()
	var cmat := StandardMaterial3D.new()
	var deep := accent
	deep.v = clampf(deep.v * 0.80, 0.0, 1.0)
	cmat.albedo_color = deep
	cmat.roughness = 0.55
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = cmat
	cape.add_child(cloth)
	# Use the actual AABB back edge (box.position.x) so the cape sits flush regardless
	# of whether X or Z dominates the radius calculation.
	var back_x := box.position.x + r * 0.22   # inset so top edge overlaps body
	cape.position = Vector3(back_x, top_y - r * 0.30, 0)
	_visual.add_child(cape)
	_cape = cape

# Combined AABB of every mesh under _visual, in _visual-LOCAL space (body-scale
# cancels out via the inverse), so regalia is placed in the model's own units.
func _visual_local_aabb() -> AABB:
	var inv := _visual.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi in _all_meshes(_visual):
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box

func _all_meshes(node: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_all_meshes(c, out)
	return out

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
	# Bob is suppressed when the walk anim is running (the anim already moves the body)
	if not _anim or not _anim.is_playing():
		_bob_t += delta * 2.8
		_visual.position.y = sin(_bob_t) * 0.048
	# Royal cape: geometry handles the drape; sway adds cloth flutter.
	if _cape:
		_sway_t += delta * (2.5 + velocity.length() * 0.6)
		_cape.rotation.z = deg_to_rad(sin(_sway_t) * (5.0 + velocity.length()))
		_cape.rotation.x = deg_to_rad(sin(_sway_t * 0.65) * 3.0)

func _physics_process(_dt: float) -> void:
	if not auto_input:
		_set_walking(velocity.length() > 0.1)
		return
	if dead:
		return
	var mv     := InputManager.get_move(player_id)
	var target := Vector3(mv.x, 0.0, mv.y) * speed
	if momentum > 0.0:
		velocity = velocity.move_toward(target, acceleration * _dt)
	else:
		velocity = target
	move_and_slide()

	var moving := mv.length() > 0.1
	if moving:
		face(mv)
		_set_walking(true)
	else:
		_set_walking(false)

	# Dust puff while running
	_dust_t -= _dt
	if velocity.length() > 2.8 and _dust_t <= 0.0:
		_dust_t = 0.2
		_spawn_dust()

func _set_walking(walking: bool) -> void:
	if not _anim:
		return
	if walking:
		if not _anim.is_playing() or _anim.current_animation != ANIM_WALK:
			_anim.play(ANIM_WALK)
	else:
		if _anim.is_playing():
			_anim.stop(true)   # keep pose at last frame rather than snapping to rest

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
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = c
		elif mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("base_color", c)

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
	if player_id == 0:
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
	_death_tween = tw
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
	# Kill any in-flight death animation, else its pending callback (visible=false /
	# scale→0) fires after this and re-hides the revived avatar.
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
		_death_tween = null
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
