class_name Avatar3D
extends CharacterBody3D

# Generic 3D avatar for the 3D minigames. Moves on the XZ plane (top-down),
# reads InputManager by default, and turns its visual model to face movement.
# A flat coloured disc under the model shows the player's colour (the model
# itself stays neutral, like the tank).

@export var speed: float = 6.0
@export var momentum: float = 0.0        # 0 = snappy; >0 enables sliding (ice)
@export var acceleration: float = 40.0
var auto_input: bool = true
var data: PlayerData
var player_id: int = 0
var dead: bool = false

var _visual: Node3D          # rotates to face movement; holds the model
var _last_dir: Vector2 = Vector2.RIGHT
var _body_mat: StandardMaterial3D   # default mascot material (recolour/scale)

func setup(p: PlayerData) -> void:
	data = p
	player_id = p.id
	collision_layer = 1
	collision_mask = 2

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.7
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	add_child(col)

	# player-colour disc on the ground
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15
	cyl.bottom_radius = 1.15
	cyl.height = 0.08
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = p.color
	disc.material_override = dm
	disc.position = Vector3(0, 0.05, 0)
	add_child(disc)

	_visual = Node3D.new()
	add_child(_visual)
	_build_default_visual(p.color)

func set_model(scene: PackedScene, model_scale: float = 1.0, y: float = 0.0) -> void:
	for c in _visual.get_children():
		c.queue_free()
	var m := scene.instantiate()
	m.scale = Vector3.ONE * model_scale
	m.position = Vector3(0, y, 0)
	_visual.add_child(m)

func _build_default_visual(c: Color) -> void:
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	body.mesh = sm
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = c
	body.material_override = _body_mat
	body.position = Vector3(0, 0.9, 0)
	_visual.add_child(body)

func set_body_color(c: Color) -> void:
	if _body_mat:
		_body_mat.albedo_color = c

func set_body_scale(s: float) -> void:
	if _visual:
		_visual.scale = Vector3.ONE * s

func _physics_process(_dt: float) -> void:
	if dead or not auto_input:
		return
	var mv := InputManager.get_move(player_id)
	var target := Vector3(mv.x, 0.0, mv.y) * speed
	if momentum > 0.0:
		velocity = velocity.move_toward(target, acceleration * _dt)
	else:
		velocity = target
	move_and_slide()
	if mv.length() > 0.1:
		face(mv)

func face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	_last_dir = dir.normalized()
	# model forward = +X (Godot); yaw so +X points along the world XZ direction
	_visual.rotation.y = atan2(-dir.y, dir.x)

func facing_dir() -> Vector2:
	return _last_dir

func set_dead() -> void:
	dead = true
	visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

func revive(pos: Vector3) -> void:
	dead = false
	visible = true
	global_position = pos
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 2)

func pop() -> void:
	if not _visual:
		return
	_visual.scale = Vector3(1.2, 0.82, 1.2)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_visual, "scale", Vector3.ONE, 0.18)
